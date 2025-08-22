import 'dart:async';
import 'dart:convert';
import 'models/user.dart';
import 'models/session.dart';
import 'models/organization.dart';
import 'services/clerk_service.dart';
import 'services/storage_helper.dart';
import 'flows/sign_in_flow.dart';
import 'flows/sign_up_flow.dart';

class ClerkSDK {
  final ClerkService _service;
  final StorageHelper _storage = StorageHelper();

  ClerkUser? _user;
  ClerkSession? _session;
  ClerkOrganization? _organization;
  List<ClerkOrganization> _organizations = [];
  
  bool _isLoaded = false;
  String? _lastError;

  // Event streams
  final StreamController<ClerkSession> _sessionCreatedController = 
      StreamController<ClerkSession>.broadcast();
  final StreamController<ClerkSession?> _sessionDestroyedController = 
      StreamController<ClerkSession?>.broadcast();
  final StreamController<ClerkUser> _userUpdatedController = 
      StreamController<ClerkUser>.broadcast();
  final StreamController<ClerkOrganization> _organizationUpdatedController = 
      StreamController<ClerkOrganization>.broadcast();
  final StreamController<String> _errorController = 
      StreamController<String>.broadcast();

  ClerkSDK(String domain) : _service = ClerkService(domain);

  // Getters
  bool get isLoaded => _isLoaded;
  bool get isSignedIn => _session?.isActive ?? false;
  bool get isSignedOut => !isSignedIn;
  ClerkUser? get user => _user;
  ClerkSession? get session => _session;
  ClerkOrganization? get organization => _organization;
  List<ClerkOrganization> get organizations => List.unmodifiable(_organizations);
  String? get lastError => _lastError;

  // Event streams
  Stream<ClerkSession> get onSessionCreated => _sessionCreatedController.stream;
  Stream<ClerkSession?> get onSessionDestroyed => _sessionDestroyedController.stream;
  Stream<ClerkUser> get onUserUpdated => _userUpdatedController.stream;
  Stream<ClerkOrganization> get onOrganizationUpdated => _organizationUpdatedController.stream;
  Stream<String> get onError => _errorController.stream;

  // Initialize the SDK
  Future<void> initialize() async {
    if (_isLoaded) return;

    try {
      print('🚀 Initializing Clerk Flutter SDK...');
      _lastError = null;

      // Setup development browser if needed
      await _service.setupDevBrowser();

      // Try to restore session from storage
      final storedSession = await _storage.getSession();
      if (storedSession != null) {
        _setSession(storedSession);
        print('✅ Session restored from storage');
      }

      _isLoaded = true;
      print('✅ Clerk Flutter SDK initialized successfully');
    } catch (e) {
      _lastError = e.toString();
      _errorController.add(_lastError!);
      print('❌ Failed to initialize Clerk SDK: $e');
      rethrow;
    }
  }

  // Authentication methods
  SignInFlow signIn() => SignInFlow(_service);
  SignUpFlow signUp() => SignUpFlow(_service);

  // Complete sign-in with session handling
  Future<void> completeSignIn(SignInFlow signInFlow) async {
    if (signInFlow.currentAttempt?.isComplete != true) {
      throw Exception('Sign-in attempt is not complete');
    }

    try {
      // Refresh client to get updated session data
      await _refreshClient();
    } catch (e) {
      print('❌ Failed to complete sign-in: $e');
      rethrow;
    }
  }

  // Complete sign-up with session handling
  Future<void> completeSignUp(SignUpFlow signUpFlow) async {
    if (signUpFlow.currentAttempt?.isComplete != true) {
      throw Exception('Sign-up attempt is not complete');
    }

    try {
      // Refresh client to get updated session data
      await _refreshClient();
    } catch (e) {
      print('❌ Failed to complete sign-up: $e');
      rethrow;
    }
  }

  // Sign out methods
  Future<void> signOut() async {
    if (_session == null) return;

    try {
      print('🔄 Signing out...');

      await _service.request(
        '/client/sessions/${_session!.id}',
        method: 'DELETE',
        params: {'_clerk_session_id': _session!.id},
      );

      await _clearSession();
      print('✅ Signed out successfully');
    } catch (e) {
      print('❌ Sign out failed: $e');
      _lastError = e.toString();
      _errorController.add(_lastError!);
      rethrow;
    }
  }

  Future<void> signOutAll() async {
    try {
      print('🔄 Signing out from all sessions...');

      await _service.request(
        '/client/sessions',
        method: 'DELETE',
      );

      await _clearSession();
      print('✅ Signed out from all sessions');
    } catch (e) {
      print('❌ Sign out all failed: $e');
      _lastError = e.toString();
      _errorController.add(_lastError!);
      rethrow;
    }
  }

  // Token management
  Future<String?> getToken({String template = ''}) async {
    if (_session == null) return null;

    try {
      // Check cache first
      final cachedToken = await _storage.getToken(_session!.id, template);
      if (cachedToken != null) return cachedToken;

      // Request new token
      final data = await _service.request(
        '/client/sessions/${_session!.id}/tokens',
        method: 'POST',
        body: {'template': template},
        params: {'_clerk_session_id': _session!.id},
      );

      final jwt = data['response']['jwt'] as String;
      
      // Cache the token
      await _storage.saveToken(_session!.id, template, jwt);
      
      return jwt;
    } catch (e) {
      print('❌ Error getting token: $e');
      _lastError = e.toString();
      _errorController.add(_lastError!);
      return null;
    }
  }

  // JWT utilities
  Map<String, dynamic>? decodeToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;

      final payload = base64Url.decode(_normalizeBase64(parts[1]));
      return jsonDecode(utf8.decode(payload)) as Map<String, dynamic>;
    } catch (e) {
      print('❌ Error decoding token: $e');
      return null;
    }
  }

  bool isTokenExpired(String token) {
    final decoded = decodeToken(token);
    if (decoded == null) return true;

    final exp = decoded['exp'] as int?;
    if (exp == null) return true;

    return DateTime.now().millisecondsSinceEpoch > (exp * 1000);
  }

  // User management
  Future<ClerkUser?> getUser() async {
    if (_session == null) return null;

    try {
      final data = await _service.request(
        '/me',
        params: {'_clerk_session_id': _session!.id},
      );

      _user = ClerkUser.fromJson(data['response']);
      _userUpdatedController.add(_user!);
      
      // Update session user data
      if (_session != null) {
        _session = ClerkSession(
          id: _session!.id,
          status: _session!.status,
          user: _user!,
          organization: _session!.organization,
          expireAt: _session!.expireAt,
          abandonAt: _session!.abandonAt,
          createdAt: _session!.createdAt,
          updatedAt: _session!.updatedAt,
        );
        await _storage.saveSession(_session!);
      }

      return _user;
    } catch (e) {
      print('❌ Failed to get user: $e');
      _lastError = e.toString();
      _errorController.add(_lastError!);
      
      if (e.toString().contains('session_invalid')) {
        await _clearSession();
      }
      
      return null;
    }
  }

  Future<ClerkUser?> updateUser(Map<String, dynamic> updates) async {
    if (_session == null) {
      throw Exception('No active session');
    }

    try {
      final data = await _service.request(
        '/me',
        method: 'PATCH',
        body: updates,
        params: {'_clerk_session_id': _session!.id},
      );

      _user = ClerkUser.fromJson(data['response']);
      _userUpdatedController.add(_user!);

      // Update session user data
      if (_session != null) {
        _session = ClerkSession(
          id: _session!.id,
          status: _session!.status,
          user: _user!,
          organization: _session!.organization,
          expireAt: _session!.expireAt,
          abandonAt: _session!.abandonAt,
          createdAt: _session!.createdAt,
          updatedAt: _session!.updatedAt,
        );
        await _storage.saveSession(_session!);
      }

      print('✅ User updated successfully');
      return _user;
    } catch (e) {
      print('❌ Failed to update user: $e');
      _lastError = e.toString();
      _errorController.add(_lastError!);
      rethrow;
    }
  }

  // Session management
  Future<bool> validateSession() async {
    if (_session == null) return false;

    try {
      final data = await _service.request(
        '/client/sessions/${_session!.id}',
        params: {'_clerk_session_id': _session!.id},
      );

      final sessionData = data['response'];
      final isValid = sessionData['status'] == 'active' && 
                     DateTime.parse(sessionData['expire_at']).isAfter(DateTime.now());

      if (!isValid) {
        await _clearSession();
      }

      return isValid;
    } catch (e) {
      print('❌ Session validation failed: $e');
      await _clearSession();
      return false;
    }
  }

  Future<bool> refreshSession() async {
    if (_session == null) return false;

    try {
      await _service.request(
        '/client/sessions/${_session!.id}/touch',
        method: 'POST',
        params: {'_clerk_session_id': _session!.id},
      );

      print('✅ Session refreshed');
      return true;
    } catch (e) {
      print('❌ Session refresh failed: $e');
      _lastError = e.toString();
      _errorController.add(_lastError!);
      
      if (e.toString().contains('session_invalid')) {
        await _clearSession();
      }
      
      return false;
    }
  }

  // Organization management
  Future<List<ClerkOrganization>> listOrganizations() async {
    if (_session == null) {
      throw Exception('No active session');
    }

    try {
      final data = await _service.request(
        '/organizations',
        params: {'_clerk_session_id': _session!.id},
      );

      _organizations = (data['response'] as List)
          .map((org) => ClerkOrganization.fromJson(org))
          .toList();

      print('✅ Organizations loaded: ${_organizations.length}');
      return _organizations;
    } catch (e) {
      print('❌ Failed to list organizations: $e');
      _lastError = e.toString();
      _errorController.add(_lastError!);
      rethrow;
    }
  }

  Future<ClerkOrganization> createOrganization(String name, String slug) async {
    if (_session == null) {
      throw Exception('No active session');
    }

    try {
      final data = await _service.request(
        '/organizations',
        method: 'POST',
        body: {'name': name, 'slug': slug},
        params: {'_clerk_session_id': _session!.id},
      );

      final organization = ClerkOrganization.fromJson(data['response']);
      _organizations.add(organization);
      
      print('✅ Organization created: ${organization.name}');
      return organization;
    } catch (e) {
      print('❌ Failed to create organization: $e');
      _lastError = e.toString();
      _errorController.add(_lastError!);
      rethrow;
    }
  }

  Future<void> setActiveOrganization(String organizationId) async {
    if (_session == null) {
      throw Exception('No active session');
    }

    try {
      final data = await _service.request(
        '/client/sessions/${_session!.id}/touch',
        method: 'POST',
        body: {'active_organization_id': organizationId},
        params: {'_clerk_session_id': _session!.id},
      );

      // Update session with new organization context
      final updatedSession = ClerkSession.fromJson(data['response']);
      _setSession(updatedSession);
      
      _organization = updatedSession.organization;
      if (_organization != null) {
        _organizationUpdatedController.add(_organization!);
      }

      print('✅ Active organization set: ${_organization?.name ?? 'None'}');
    } catch (e) {
      print('❌ Failed to set active organization: $e');
      _lastError = e.toString();
      _errorController.add(_lastError!);
      rethrow;
    }
  }

  // Private methods
  Future<void> _refreshClient() async {
    try {
      final data = await _service.request('/client');
      final client = data['response'];
      final sessions = client['sessions'] as List;
      
      final activeSessions = sessions
          .where((s) => s['status'] == 'active')
          .toList();

      if (activeSessions.isNotEmpty) {
        // Find the most recent active session or last active session
        final sessionData = activeSessions.firstWhere(
          (s) => s['id'] == client['last_active_session_id'],
          orElse: () => activeSessions.first,
        );
        
        final session = ClerkSession.fromJson(sessionData);
        _setSession(session);
      } else {
        await _clearSession();
      }
    } catch (e) {
      print('❌ Failed to refresh client: $e');
      _lastError = e.toString();
      _errorController.add(_lastError!);
      rethrow;
    }
  }

  void _setSession(ClerkSession session) {
    _session = session;
    _user = session.user;
    _organization = session.organization;
    _storage.saveSession(session);
    _sessionCreatedController.add(session);
  }

  Future<void> _clearSession() async {
    final oldSession = _session;
    _session = null;
    _user = null;
    _organization = null;
    _organizations.clear();
    
    await _storage.clearSession();
    await _storage.clearAllTokens();
    
    _sessionDestroyedController.add(oldSession);
  }

  // Helper method for base64 normalization
  String _normalizeBase64(String base64) {
    switch (base64.length % 4) {
      case 0:
        return base64;
      case 2:
        return base64 + '==';
      case 3:
        return base64 + '=';
      default:
        throw Exception('Invalid base64 string');
    }
  }

  // Dispose method
  void dispose() {
    _service.dispose();
    _sessionCreatedController.close();
    _sessionDestroyedController.close();
    _userUpdatedController.close();
    _organizationUpdatedController.close();
    _errorController.close();
  }
}