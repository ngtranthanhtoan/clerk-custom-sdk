import 'dart:async';
import 'package:flutter/foundation.dart';

import '../services/api_client.dart';
import '../services/storage_helper.dart';
import '../services/clerk_service.dart';
import '../flows/sign_in_flow.dart';
import '../flows/sign_up_flow.dart';
import '../models/user.dart';
import '../models/session.dart';
import '../models/environment.dart';
import '../models/client.dart';
import '../models/organization.dart';

/// Main Clerk SDK class that provides authentication functionality
class ClerkSDK with ChangeNotifier {
  final String domain;
  late final ApiClient _apiClient;
  late final StorageHelper _storage;
  late final ClerkService _service;
  
  // Core state
  bool _isLoaded = false;
  ClerkEnvironment? _environment;
  ClerkClient? _client;
  ClerkSession? _session;
  ClerkUser? _user;
  ClerkOrganization? _organization;
  
  // Event streams
  final StreamController<ClerkSession> _sessionCreatedController = StreamController<ClerkSession>.broadcast();
  final StreamController<ClerkSession> _sessionDestroyedController = StreamController<ClerkSession>.broadcast();
  final StreamController<ClerkUser> _userUpdatedController = StreamController<ClerkUser>.broadcast();
  
  ClerkSDK({required this.domain}) {
    _apiClient = ApiClient(domain: domain);
    _storage = StorageHelper();
    _service = ClerkService(domain);
  }
  
  // Getters
  bool get isLoaded => _isLoaded;
  bool get isSignedIn => _session != null && _session!.status == 'active';
  ClerkUser? get user => _user;
  ClerkSession? get session => _session;
  ClerkOrganization? get organization => _organization;
  ClerkEnvironment? get environment => _environment;
  ClerkClient? get client => _client;
  
  // Event streams
  Stream<ClerkSession> get onSessionCreated => _sessionCreatedController.stream;
  Stream<ClerkSession> get onSessionDestroyed => _sessionDestroyedController.stream;
  Stream<ClerkUser> get onUserUpdated => _userUpdatedController.stream;
  
  /// Initialize the SDK
  Future<void> load() async {
    if (_isLoaded) return;
    
    try {
      debugPrint('🚀 Loading Clerk SDK...');
      
      // Step 1: Setup development browser authentication if needed
      await _setupDevBrowser();
      
      // Step 2: Discover environment capabilities
      await _discoverEnvironment();
      
      // Step 3: Ensure client exists
      await _ensureClient();
      
      // Step 4: Restore existing session
      await _restoreSession();
      
      _isLoaded = true;
      notifyListeners();
      debugPrint('✅ Clerk SDK loaded successfully');
      
    } catch (error) {
      debugPrint('❌ Failed to load Clerk SDK: $error');
      rethrow;
    }
  }
  
  /// Create a sign-in flow
  SignInFlow signIn() {
    return SignInFlow(_service);
  }
  
  /// Create a sign-up flow
  SignUpFlow signUp() {
    return SignUpFlow(_service);
  }
  
  /// Sign out current session
  Future<void> signOut() async {
    if (_session == null) return;
    
    try {
      await _apiClient.delete('/client/sessions/${_session!.id}', queryParams: {
        '_clerk_session_id': _session!.id,
      });
      
      await _clearSession();
      debugPrint('✅ Signed out successfully');
      
    } catch (error) {
      debugPrint('❌ Sign out failed: $error');
      rethrow;
    }
  }
  
  /// Sign out all sessions
  Future<void> signOutAll() async {
    try {
      await _apiClient.delete('/client/sessions');
      await _clearSession();
      debugPrint('✅ Signed out all sessions');
      
    } catch (error) {
      debugPrint('❌ Sign out all failed: $error');
      rethrow;
    }
  }
  
  /// Get JWT token for API calls
  Future<String> getToken({String template = ''}) async {
    if (_session == null) {
      throw Exception('No active session');
    }
    
    try {
      final response = await _apiClient.post(
        '/client/sessions/${_session!.id}/tokens',
        data: {'template': template},
        queryParams: {'_clerk_session_id': _session!.id},
      );
      
      return response['jwt'] as String;
    } catch (error) {
      debugPrint('❌ Failed to get token: $error');
      rethrow;
    }
  }
  
  /// Get fresh user data
  Future<ClerkUser> getUser() async {
    if (_session == null) {
      throw Exception('No active session');
    }
    
    try {
      final response = await _apiClient.get('/me', queryParams: {
        '_clerk_session_id': _session!.id,
      });
      
      _user = ClerkUser.fromJson(response);
      notifyListeners();
      return _user!;
      
    } catch (error) {
      debugPrint('❌ Failed to get user: $error');
      rethrow;
    }
  }
  
  /// Update user profile
  Future<ClerkUser> updateUser(Map<String, dynamic> updates) async {
    if (_session == null) {
      throw Exception('No active session');
    }
    
    try {
      final response = await _apiClient.patch('/me',
        data: updates,
        queryParams: {'_clerk_session_id': _session!.id},
      );
      
      _user = ClerkUser.fromJson(response);
      _userUpdatedController.add(_user!);
      notifyListeners();
      return _user!;
      
    } catch (error) {
      debugPrint('❌ Failed to update user: $error');
      rethrow;
    }
  }
  
  /// List user's organizations
  Future<List<ClerkOrganization>> listOrganizations() async {
    if (_session == null) {
      throw Exception('No active session');
    }
    
    try {
      final response = await _apiClient.get('/organizations', queryParams: {
        '_clerk_session_id': _session!.id,
      });
      
      return (response as List)
          .map((org) => ClerkOrganization.fromJson(org))
          .toList();
          
    } catch (error) {
      debugPrint('❌ Failed to list organizations: $error');
      rethrow;
    }
  }
  
  /// Create new organization
  Future<ClerkOrganization> createOrganization(String name, String slug) async {
    if (_session == null) {
      throw Exception('No active session');
    }
    
    try {
      final response = await _apiClient.post('/organizations',
        data: {'name': name, 'slug': slug},
        queryParams: {'_clerk_session_id': _session!.id},
      );
      
      return ClerkOrganization.fromJson(response);
      
    } catch (error) {
      debugPrint('❌ Failed to create organization: $error');
      rethrow;
    }
  }
  
  /// Set active organization
  Future<void> setActiveOrganization(String organizationId) async {
    if (_session == null) {
      throw Exception('No active session');
    }
    
    try {
      final response = await _apiClient.post('/client/sessions/${_session!.id}/touch',
        data: {'active_organization_id': organizationId},
        queryParams: {'_clerk_session_id': _session!.id},
      );
      
      _session = ClerkSession.fromJson(response);
      _organization = _session!.organization;
      notifyListeners();
      
    } catch (error) {
      debugPrint('❌ Failed to set active organization: $error');
      rethrow;
    }
  }
  
  // Private methods
  
  Future<void> _setupDevBrowser() async {
    if (!domain.contains('.clerk.accounts.dev')) {
      return; // Production instance
    }
    
    debugPrint('🔧 Setting up development browser authentication...');
    
    try {
      // Try to get dev browser token from storage first
      final storedToken = await _storage.getString('__clerk_db_jwt');
      if (storedToken != null) {
        _apiClient.setDevBrowserJWT(storedToken);
        return;
      }
      
      // Request new dev browser token
      final response = await _apiClient.post('/dev_browser');
      final token = response['id'] as String;
      
      await _storage.setString('__clerk_db_jwt', token);
      _apiClient.setDevBrowserJWT(token);
      debugPrint('✅ Dev browser JWT obtained');
      
    } catch (error) {
      debugPrint('⚠️ Dev browser authentication failed: $error');
      // Continue without dev browser token
    }
  }
  
  Future<void> _discoverEnvironment() async {
    try {
      final response = await _apiClient.get('/environment');
      _environment = ClerkEnvironment.fromJson(response);
      debugPrint('✅ Environment discovered');
      
    } catch (error) {
      debugPrint('❌ Environment discovery failed: $error');
      rethrow;
    }
  }
  
  Future<void> _ensureClient() async {
    try {
      // Try to get existing client first
      final response = await _apiClient.get('/client');
      _client = ClerkClient.fromJson(response);
      debugPrint('✅ Client retrieved: ${_client!.id}');
      
    } catch (error) {
      try {
        // Create new client if getting existing one fails
        final response = await _apiClient.put('/client');
        _client = ClerkClient.fromJson(response);
        debugPrint('✅ Client created: ${_client!.id}');
        
      } catch (createError) {
        debugPrint('❌ Failed to create client: $createError');
        rethrow;
      }
    }
  }
  
  Future<void> _restoreSession() async {
    if (_client == null) return;
    
    // Look for active sessions in the client
    final activeSessions = _client!.sessions
        .where((session) => session.status == 'active')
        .toList();
    
    if (activeSessions.isNotEmpty) {
      // Use the last active session or first available
      final session = activeSessions.firstWhere(
        (s) => s.id == _client!.lastActiveSessionId,
        orElse: () => activeSessions.first,
      );
      
      await _setSession(session);
      debugPrint('✅ Session restored: ${session.user.emailAddresses.first.emailAddress}');
    }
  }
  
  Future<void> _setSession(ClerkSession session) async {
    _session = session;
    _user = session.user;
    _organization = session.organization;
    
    // Cache session data
    await _storage.setString('clerk_session_cache', _session!.toJsonString());
    
    notifyListeners();
    debugPrint('✅ Session set: ${_user!.emailAddresses.first.emailAddress}');
  }
  
  Future<void> _clearSession() async {
    final oldSession = _session;
    
    _session = null;
    _user = null;
    _organization = null;
    
    await _storage.remove('clerk_session_cache');
    
    if (oldSession != null) {
      _sessionDestroyedController.add(oldSession);
    }
    
    notifyListeners();
    debugPrint('✅ Session cleared');
  }
  
  /// Dispose resources
  @override
  void dispose() {
    _sessionCreatedController.close();
    _sessionDestroyedController.close();
    _userUpdatedController.close();
    super.dispose();
  }
}