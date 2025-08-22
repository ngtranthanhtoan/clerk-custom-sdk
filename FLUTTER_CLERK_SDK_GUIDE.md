# 📱 Flutter Clerk SDK Implementation Guide

> **Complete guide to implementing Clerk authentication in Flutter using REST API calls**

## 📋 Table of Contents

1. [Overview](#overview)
2. [Flutter Setup](#flutter-setup)
3. [SDK Architecture](#sdk-architecture)
4. [Core Implementation](#core-implementation)
5. [Usage Examples](#usage-examples)
6. [State Management Integration](#state-management-integration)
7. [UI Components](#ui-components)
8. [Best Practices](#best-practices)
9. [Troubleshooting](#troubleshooting)

---

## 🚀 Overview

### Why Flutter SDK for Clerk?

Flutter doesn't have an official Clerk SDK, so we'll build one using the same REST API principles from our web SDK. This approach gives us:

- **Full Control**: Customize authentication flows for mobile UX
- **Native Performance**: Direct HTTP calls without web wrapper overhead
- **Cross-Platform**: Works on both iOS and Android
- **Consistency**: Same API patterns as web SDK

### What We'll Build

```
┌─────────────────────────────────────────────────────────────────┐
│                    Flutter Clerk SDK                           │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │  Clerk Service  │  │  Auth Provider  │  │   Auth Flows    │  │
│  │   (Core API)    │  │ (State Mgmt)    │  │  (SignIn/Up)    │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │  Session Mgr    │  │   Token Mgr     │  │   User Mgr      │  │
│  │ (Lifecycle)     │  │ (JWT Caching)   │  │ (Profile)       │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │  UI Widgets     │  │  Storage Helper │  │  Org Manager    │  │
│  │ (Login/Signup)  │  │ (Persistence)   │  │ (Organizations) │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🛠️ Flutter Setup

### Dependencies

Add these to your `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  http: ^1.1.0                    # HTTP requests
  shared_preferences: ^2.2.2      # Local storage
  provider: ^6.1.1                # State management
  crypto: ^3.0.3                  # JWT decoding
  equatable: ^2.0.5               # Value equality

dev_dependencies:
  flutter_test:
    sdk: flutter
  mockito: ^5.4.2                 # Testing
  build_runner: ^2.4.7            # Code generation
```

### Project Structure

```
lib/
├── clerk/
│   ├── models/
│   │   ├── user.dart
│   │   ├── session.dart
│   │   ├── organization.dart
│   │   └── auth_attempt.dart
│   ├── services/
│   │   ├── clerk_service.dart
│   │   ├── session_manager.dart
│   │   ├── token_manager.dart
│   │   └── storage_helper.dart
│   ├── providers/
│   │   └── auth_provider.dart
│   ├── flows/
│   │   ├── sign_in_flow.dart
│   │   └── sign_up_flow.dart
│   ├── widgets/
│   │   ├── sign_in_form.dart
│   │   ├── sign_up_form.dart
│   │   └── auth_wrapper.dart
│   └── clerk_sdk.dart
├── screens/
│   ├── login_screen.dart
│   ├── home_screen.dart
│   └── profile_screen.dart
└── main.dart
```

---

## 🏗️ SDK Architecture

### Core Service Layer

The `ClerkService` handles all REST API communication:

```dart
// Core API client with CORS workarounds adapted for Flutter
class ClerkService {
  final String domain;
  final http.Client _client;
  String? _devBrowserJWT;

  ClerkService(this.domain) : _client = http.Client();

  // Build URL with Clerk parameters and CORS workarounds
  Uri buildUrl(String path, {
    Map<String, String>? params,
    String method = 'GET'
  });

  // Make authenticated requests
  Future<Map<String, dynamic>> request(String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
    Map<String, String>? params
  });
}
```

### State Management

The `AuthProvider` manages authentication state across the app:

```dart
class AuthProvider extends ChangeNotifier {
  bool _isLoaded = false;
  bool _isSignedIn = false;
  ClerkUser? _user;
  ClerkSession? _session;

  // Getters
  bool get isLoaded => _isLoaded;
  bool get isSignedIn => _isSignedIn;
  ClerkUser? get user => _user;
  ClerkSession? get session => _session;

  // Authentication methods
  Future<void> signIn(String email, String password);
  Future<void> signUp(String email, String password);
  Future<void> signOut();
}
```

### Authentication Flows

Separate classes handle complex multi-step authentication:

```dart
class SignInFlow {
  final ClerkService _service;
  SignInAttempt? _attempt;

  SignInFlow(this._service);

  Future<SignInAttempt> create(String identifier);
  Future<SignInAttempt> attemptPassword(String password);
  Future<SignInAttempt> prepareEmailCode();
  Future<SignInAttempt> submitEmailCode(String code);
}
```

---

## 💻 Core Implementation

### 1. Data Models

Create Dart models for Clerk data structures:

```dart
// lib/clerk/models/user.dart
import 'package:equatable/equatable.dart';

class ClerkUser extends Equatable {
  final String id;
  final String? firstName;
  final String? lastName;
  final List<EmailAddress> emailAddresses;
  final String? profileImageUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ClerkUser({
    required this.id,
    this.firstName,
    this.lastName,
    required this.emailAddresses,
    this.profileImageUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ClerkUser.fromJson(Map<String, dynamic> json) {
    return ClerkUser(
      id: json['id'],
      firstName: json['first_name'],
      lastName: json['last_name'],
      emailAddresses: (json['email_addresses'] as List)
          .map((e) => EmailAddress.fromJson(e))
          .toList(),
      profileImageUrl: json['profile_image_url'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  @override
  List<Object?> get props => [
    id,
    firstName,
    lastName,
    emailAddresses,
    profileImageUrl,
    createdAt,
    updatedAt,
  ];
}

class EmailAddress extends Equatable {
  final String id;
  final String emailAddress;
  final EmailVerification verification;

  const EmailAddress({
    required this.id,
    required this.emailAddress,
    required this.verification,
  });

  factory EmailAddress.fromJson(Map<String, dynamic> json) {
    return EmailAddress(
      id: json['id'],
      emailAddress: json['email_address'],
      verification: EmailVerification.fromJson(json['verification']),
    );
  }

  @override
  List<Object> get props => [id, emailAddress, verification];
}

class EmailVerification extends Equatable {
  final String status;
  final String? strategy;

  const EmailVerification({
    required this.status,
    this.strategy,
  });

  factory EmailVerification.fromJson(Map<String, dynamic> json) {
    return EmailVerification(
      status: json['status'],
      strategy: json['strategy'],
    );
  }

  bool get isVerified => status == 'verified';

  @override
  List<Object?> get props => [status, strategy];
}
```

```dart
// lib/clerk/models/session.dart
import 'package:equatable/equatable.dart';
import 'user.dart';

class ClerkSession extends Equatable {
  final String id;
  final String status;
  final ClerkUser user;
  final DateTime expireAt;
  final DateTime abandonAt;

  const ClerkSession({
    required this.id,
    required this.status,
    required this.user,
    required this.expireAt,
    required this.abandonAt,
  });

  factory ClerkSession.fromJson(Map<String, dynamic> json) {
    return ClerkSession(
      id: json['id'],
      status: json['status'],
      user: ClerkUser.fromJson(json['user']),
      expireAt: DateTime.parse(json['expire_at']),
      abandonAt: DateTime.parse(json['abandon_at']),
    );
  }

  bool get isActive => status == 'active' && DateTime.now().isBefore(expireAt);
  
  @override
  List<Object> get props => [id, status, user, expireAt, abandonAt];
}
```

### 2. Core Service

```dart
// lib/clerk/services/clerk_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class ClerkService {
  final String domain;
  final http.Client _client;
  final String _apiVersion = '2025-04-10';
  final String _jsVersion = '5.88.0';
  String? _devBrowserJWT;

  ClerkService(this.domain) : _client = http.Client();

  bool get _isDevInstance => domain.contains('.clerk.accounts.dev');

  Uri buildUrl(String path, {
    Map<String, String>? params,
    String method = 'GET',
  }) {
    final uri = Uri.https(domain, '/v1$path');
    final queryParams = <String, String>{
      '__clerk_api_version': _apiVersion,
      '_clerk_js_version': _jsVersion,
      ...?params,
    };

    // CORS workaround: Use _method parameter for non-GET/POST
    if (method != 'GET' && method != 'POST') {
      queryParams['_method'] = method;
    }

    // Add dev browser JWT for development instances
    if (_isDevInstance && _devBrowserJWT != null) {
      queryParams['__clerk_db_jwt'] = _devBrowserJWT!;
    }

    return uri.replace(queryParameters: queryParams);
  }

  Future<Map<String, dynamic>> request(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
    Map<String, String>? params,
  }) async {
    // Convert all methods to GET/POST to avoid CORS issues
    final actualMethod = method == 'GET' ? 'GET' : 'POST';
    final url = buildUrl(path, params: params, method: method);

    final headers = <String, String>{
      'Content-Type': 'application/x-www-form-urlencoded',
    };

    http.Response response;

    if (actualMethod == 'GET') {
      response = await _client.get(url, headers: headers);
    } else {
      final encodedBody = body != null 
          ? Uri(queryParameters: body.map((k, v) => MapEntry(k, v.toString())))
                .query
          : '';
      response = await _client.post(url, headers: headers, body: encodedBody);
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode >= 400) {
      throw ClerkException.fromJson(data, response.statusCode);
    }

    return data;
  }

  Future<void> setupDevBrowser() async {
    if (!_isDevInstance) return;

    try {
      // Try to get dev browser JWT
      final response = await _client.post(
        Uri.https(domain, '/v1/dev_browser'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        _devBrowserJWT = data['id'];
        print('✅ Dev browser JWT obtained');
      }
    } catch (e) {
      print('⚠️ Could not obtain dev browser JWT: $e');
    }
  }

  void dispose() {
    _client.close();
  }
}

class ClerkException implements Exception {
  final String message;
  final int statusCode;
  final List<ClerkError> errors;

  ClerkException(this.message, this.statusCode, this.errors);

  factory ClerkException.fromJson(Map<String, dynamic> json, int statusCode) {
    final errors = (json['errors'] as List?)
        ?.map((e) => ClerkError.fromJson(e))
        .toList() ?? [];

    final primaryError = errors.isNotEmpty ? errors.first : null;
    final message = primaryError?.longMessage ?? 
                   primaryError?.message ?? 
                   'Unknown error';

    return ClerkException(message, statusCode, errors);
  }

  @override
  String toString() => 'ClerkException: $message';
}

class ClerkError {
  final String code;
  final String message;
  final String? longMessage;

  ClerkError({
    required this.code,
    required this.message,
    this.longMessage,
  });

  factory ClerkError.fromJson(Map<String, dynamic> json) {
    return ClerkError(
      code: json['code'] ?? '',
      message: json['message'] ?? '',
      longMessage: json['long_message'],
    );
  }
}
```

### 3. Storage Helper

```dart
// lib/clerk/services/storage_helper.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/session.dart';

class StorageHelper {
  static const String _sessionKey = 'clerk_session';
  static const String _tokenCacheKey = 'clerk_token_cache';

  Future<void> saveSession(ClerkSession session) async {
    final prefs = await SharedPreferences.getInstance();
    final sessionJson = jsonEncode({
      'session': session.toJson(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    await prefs.setString(_sessionKey, sessionJson);
  }

  Future<ClerkSession?> getSession() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionJson = prefs.getString(_sessionKey);
    
    if (sessionJson == null) return null;

    try {
      final data = jsonDecode(sessionJson) as Map<String, dynamic>;
      final session = ClerkSession.fromJson(data['session']);
      
      // Check if session is still valid
      if (session.isActive) {
        return session;
      }
    } catch (e) {
      print('Error loading session: $e');
    }

    // Clear invalid session
    await clearSession();
    return null;
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
  }

  Future<void> saveToken(String sessionId, String template, String jwt) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = '${sessionId}_$template';
    
    // Decode JWT to get expiration
    final parts = jwt.split('.');
    if (parts.length == 3) {
      try {
        final payload = jsonDecode(
          utf8.decode(base64Url.decode(base64Url.normalize(parts[1])))
        ) as Map<String, dynamic>;
        
        final tokenData = {
          'jwt': jwt,
          'expiresAt': payload['exp'] * 1000,
          'cachedAt': DateTime.now().millisecondsSinceEpoch,
        };
        
        final cache = await _getTokenCache();
        cache[cacheKey] = tokenData;
        await prefs.setString(_tokenCacheKey, jsonEncode(cache));
      } catch (e) {
        print('Error caching token: $e');
      }
    }
  }

  Future<String?> getToken(String sessionId, String template) async {
    final cache = await _getTokenCache();
    final cacheKey = '${sessionId}_$template';
    final tokenData = cache[cacheKey];
    
    if (tokenData == null) return null;

    try {
      final expiresAt = tokenData['expiresAt'] as int;
      final now = DateTime.now().millisecondsSinceEpoch;
      
      // Return token if it expires more than 5 minutes from now
      if (expiresAt > now + (5 * 60 * 1000)) {
        return tokenData['jwt'] as String;
      }
    } catch (e) {
      print('Error checking cached token: $e');
    }

    // Remove expired token
    await _removeToken(cacheKey);
    return null;
  }

  Future<Map<String, dynamic>> _getTokenCache() async {
    final prefs = await SharedPreferences.getInstance();
    final cacheJson = prefs.getString(_tokenCacheKey);
    
    if (cacheJson == null) return {};
    
    try {
      return jsonDecode(cacheJson) as Map<String, dynamic>;
    } catch (e) {
      return {};
    }
  }

  Future<void> _removeToken(String cacheKey) async {
    final prefs = await SharedPreferences.getInstance();
    final cache = await _getTokenCache();
    cache.remove(cacheKey);
    await prefs.setString(_tokenCacheKey, jsonEncode(cache));
  }

  Future<void> clearAllTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenCacheKey);
  }
}

// Extension to add toJson to ClerkSession
extension ClerkSessionJson on ClerkSession {
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'status': status,
      'user': _userToJson(user),
      'expire_at': expireAt.toIso8601String(),
      'abandon_at': abandonAt.toIso8601String(),
    };
  }

  Map<String, dynamic> _userToJson(ClerkUser user) {
    return {
      'id': user.id,
      'first_name': user.firstName,
      'last_name': user.lastName,
      'email_addresses': user.emailAddresses.map((e) => {
        'id': e.id,
        'email_address': e.emailAddress,
        'verification': {
          'status': e.verification.status,
          'strategy': e.verification.strategy,
        }
      }).toList(),
      'profile_image_url': user.profileImageUrl,
      'created_at': user.createdAt.toIso8601String(),
      'updated_at': user.updatedAt.toIso8601String(),
    };
  }
}
```

### 4. Authentication Provider

```dart
// lib/clerk/providers/auth_provider.dart
import 'package:flutter/material.dart';
import '../models/user.dart';
import '../models/session.dart';
import '../services/clerk_service.dart';
import '../services/storage_helper.dart';
import '../flows/sign_in_flow.dart';
import '../flows/sign_up_flow.dart';

class AuthProvider extends ChangeNotifier {
  final ClerkService _service;
  final StorageHelper _storage = StorageHelper();

  bool _isLoaded = false;
  bool _isSignedIn = false;
  ClerkUser? _user;
  ClerkSession? _session;
  String? _error;

  AuthProvider(this._service);

  // Getters
  bool get isLoaded => _isLoaded;
  bool get isSignedIn => _isSignedIn;
  ClerkUser? get user => _user;
  ClerkSession? get session => _session;
  String? get error => _error;

  // Initialize the SDK
  Future<void> initialize() async {
    try {
      _error = null;
      
      // Setup dev browser for development instances
      await _service.setupDevBrowser();

      // Restore session from storage
      final storedSession = await _storage.getSession();
      if (storedSession != null) {
        _setSession(storedSession);
      }

      _isLoaded = true;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoaded = true;
      notifyListeners();
    }
  }

  // Sign in with email and password
  Future<void> signInWithPassword(String email, String password) async {
    try {
      _error = null;
      notifyListeners();

      final signInFlow = SignInFlow(_service);
      await signInFlow.create(email);
      final result = await signInFlow.attemptPassword(password);

      if (result.status == 'complete') {
        // Get the session from the client
        await _refreshClient();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // Sign in with email code
  Future<SignInFlow> signInWithEmailCode(String email) async {
    try {
      _error = null;
      notifyListeners();

      final signInFlow = SignInFlow(_service);
      await signInFlow.create(email);
      await signInFlow.prepareEmailCode();
      
      return signInFlow;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // Complete email code sign in
  Future<void> completeEmailCodeSignIn(SignInFlow signInFlow, String code) async {
    try {
      _error = null;
      notifyListeners();

      final result = await signInFlow.submitEmailCode(code);
      
      if (result.status == 'complete') {
        await _refreshClient();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // Sign up with email and password
  Future<SignUpFlow> signUpWithEmail(
    String email, 
    String password, {
    String? firstName,
    String? lastName,
  }) async {
    try {
      _error = null;
      notifyListeners();

      final signUpFlow = SignUpFlow(_service);
      await signUpFlow.create({
        'email_address': email,
        'password': password,
        if (firstName != null) 'first_name': firstName,
        if (lastName != null) 'last_name': lastName,
      });
      await signUpFlow.prepareEmailVerification();
      
      return signUpFlow;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // Complete email verification for sign up
  Future<void> completeSignUpVerification(SignUpFlow signUpFlow, String code) async {
    try {
      _error = null;
      notifyListeners();

      final result = await signUpFlow.verifyEmail(code);
      
      if (result.status == 'complete') {
        await _refreshClient();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      _error = null;
      
      if (_session != null) {
        await _service.request(
          '/client/sessions/${_session!.id}',
          method: 'DELETE',
          params: {'_clerk_session_id': _session!.id},
        );
      }

      await _clearSession();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // Get JWT token
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
      print('Error getting token: $e');
      return null;
    }
  }

  // Refresh user data
  Future<void> refreshUser() async {
    if (_session == null) return;

    try {
      final data = await _service.request(
        '/me',
        params: {'_clerk_session_id': _session!.id},
      );

      _user = ClerkUser.fromJson(data['response']);
      notifyListeners();
    } catch (e) {
      print('Error refreshing user: $e');
    }
  }

  // Private methods
  Future<void> _refreshClient() async {
    final data = await _service.request('/client');
    final client = data['response'];
    final sessions = client['sessions'] as List;
    
    final activeSessions = sessions
        .where((s) => s['status'] == 'active')
        .toList();

    if (activeSessions.isNotEmpty) {
      final sessionData = activeSessions.first;
      final session = ClerkSession.fromJson(sessionData);
      _setSession(session);
    }
  }

  void _setSession(ClerkSession session) {
    _session = session;
    _user = session.user;
    _isSignedIn = true;
    _storage.saveSession(session);
    notifyListeners();
  }

  Future<void> _clearSession() async {
    _session = null;
    _user = null;
    _isSignedIn = false;
    await _storage.clearSession();
    await _storage.clearAllTokens();
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }
}
```

---

## 📲 Usage Examples

### Basic App Setup

```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'clerk/services/clerk_service.dart';
import 'clerk/providers/auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(
            ClerkService('bright-newt-8.clerk.accounts.dev'), // Your domain
          ),
        ),
      ],
      child: MaterialApp(
        title: 'Clerk Flutter Demo',
        theme: ThemeData(primarySwatch: Colors.blue),
        home: AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  @override
  _AuthWrapperState createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    // Initialize Clerk SDK
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, child) {
        if (!auth.isLoaded) {
          return Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (auth.error != null) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, color: Colors.red, size: 64),
                  SizedBox(height: 16),
                  Text('Error: ${auth.error}'),
                  ElevatedButton(
                    onPressed: () => auth.initialize(),
                    child: Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        return auth.isSignedIn ? HomeScreen() : LoginScreen();
      },
    );
  }
}
```

### Login Screen

```dart
// lib/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../clerk/providers/auth_provider.dart';
import '../clerk/flows/sign_in_flow.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _codeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  bool _isLoading = false;
  bool _showCodeInput = false;
  SignInFlow? _signInFlow;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Sign In')),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'Please enter your email';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              
              if (!_showCodeInput) ...[
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return 'Please enter your password';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 24),
                
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _signInWithPassword,
                        child: _isLoading 
                          ? CircularProgressIndicator(color: Colors.white)
                          : Text('Sign In'),
                      ),
                    ),
                  ],
                ),
                
                SizedBox(height: 16),
                
                TextButton(
                  onPressed: _isLoading ? null : _signInWithEmailCode,
                  child: Text('Sign In with Email Code'),
                ),
              ] else ...[
                TextFormField(
                  controller: _codeController,
                  decoration: InputDecoration(
                    labelText: 'Email Code',
                    border: OutlineInputBorder(),
                    hintText: 'Enter 6-digit code',
                  ),
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return 'Please enter the verification code';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 24),
                
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _verifyEmailCode,
                        child: _isLoading 
                          ? CircularProgressIndicator(color: Colors.white)
                          : Text('Verify Code'),
                      ),
                    ),
                  ],
                ),
                
                SizedBox(height: 16),
                
                TextButton(
                  onPressed: _isLoading ? null : () {
                    setState(() {
                      _showCodeInput = false;
                      _signInFlow = null;
                    });
                  },
                  child: Text('Back to Password'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _signInWithPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await context.read<AuthProvider>().signInWithPassword(
        _emailController.text.trim(),
        _passwordController.text,
      );
    } catch (e) {
      _showErrorDialog(e.toString());
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _signInWithEmailCode() async {
    if (_emailController.text.trim().isEmpty) {
      _showErrorDialog('Please enter your email');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      _signInFlow = await context.read<AuthProvider>().signInWithEmailCode(
        _emailController.text.trim(),
      );
      
      setState(() {
        _showCodeInput = true;
      });
      
      _showSuccessDialog('Verification code sent to your email!');
    } catch (e) {
      _showErrorDialog(e.toString());
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _verifyEmailCode() async {
    if (!_formKey.currentState!.validate() || _signInFlow == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await context.read<AuthProvider>().completeEmailCodeSignIn(
        _signInFlow!,
        _codeController.text.trim(),
      );
    } catch (e) {
      _showErrorDialog(e.toString());
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Success'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _codeController.dispose();
    super.dispose();
  }
}
```

### Home Screen

```dart
// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../clerk/providers/auth_provider.dart';

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Home'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () => _signOut(context),
          ),
        ],
      ),
      body: Consumer<AuthProvider>(
        builder: (context, auth, child) {
          final user = auth.user;
          
          if (user == null) {
            return Center(child: Text('No user data'));
          }

          return Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome!',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        SizedBox(height: 8),
                        Text('Name: ${user.firstName ?? ''} ${user.lastName ?? ''}'),
                        Text('Email: ${user.emailAddresses.first.emailAddress}'),
                        Text('User ID: ${user.id}'),
                        Text('Created: ${user.createdAt.toLocal()}'),
                        if (user.emailAddresses.first.verification.isVerified)
                          Chip(
                            label: Text('Email Verified'),
                            backgroundColor: Colors.green[100],
                          ),
                      ],
                    ),
                  ),
                ),
                
                SizedBox(height: 20),
                
                ElevatedButton(
                  onPressed: () => _getToken(context),
                  child: Text('Get JWT Token'),
                ),
                
                SizedBox(height: 12),
                
                ElevatedButton(
                  onPressed: () => _refreshUser(context),
                  child: Text('Refresh User Data'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _signOut(BuildContext context) async {
    try {
      await context.read<AuthProvider>().signOut();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sign out failed: $e')),
      );
    }
  }

  Future<void> _getToken(BuildContext context) async {
    try {
      final token = await context.read<AuthProvider>().getToken();
      if (token != null) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('JWT Token'),
            content: SingleChildScrollView(
              child: Text(token),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to get token: $e')),
      );
    }
  }

  Future<void> _refreshUser(BuildContext context) async {
    try {
      await context.read<AuthProvider>().refreshUser();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('User data refreshed!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Refresh failed: $e')),
      );
    }
  }
}
```

---

## 🔄 Session Persistence and Auto-Login

### How Flutter Maintains User Sessions

One of the most critical features for mobile apps is keeping users logged in between app launches. Here's how our Flutter Clerk SDK handles session persistence.

### Session Restoration Flow

```dart
// When app launches, the SDK automatically:
// 1. Initializes the SDK
// 2. Attempts to restore session from SharedPreferences
// 3. Validates the session with Clerk's API
// 4. Updates UI based on authentication state

class AuthProvider extends ChangeNotifier {
  Future<void> initialize() async {
    try {
      setLoading(true);
      
      // Step 1: Setup dev browser for development
      await _clerkService.setupDevBrowser();
      
      // Step 2: Try to restore session from local storage
      final restoredSession = await _clerkService.restoreSessionFromStorage();
      
      if (restoredSession != null) {
        // Step 3: Validate the restored session with API
        final isValid = await _clerkService.validateSession();
        
        if (isValid) {
          _session = restoredSession;
          _user = restoredSession.user;
          _isSignedIn = true;
          
          // Step 4: Start automatic session refresh
          _startSessionRefreshTimer();
          
          print('✅ Session restored for: ${_user?.emailAddresses.first.emailAddress}');
        } else {
          // Session invalid, clear stored data
          await _clerkService.clearStoredSession();
          print('⚠️ Stored session was invalid, cleared');
        }
      } else {
        print('ℹ️ No stored session found');
      }
      
      _isLoaded = true;
      _error = null;
      
    } catch (e) {
      _error = 'Failed to initialize: $e';
      print('❌ SDK initialization failed: $e');
    } finally {
      setLoading(false);
      notifyListeners();
    }
  }
}
```

### Storage Implementation

The `StorageHelper` class handles session persistence using SharedPreferences:

```dart
// lib/clerk/services/storage_helper.dart
import 'package:shared_preferences/shared_preferences.dart';

class StorageHelper {
  static const String _sessionKey = 'clerk_session';
  static const String _tokenCacheKey = 'clerk_token_cache';
  static const String _devBrowserJWTKey = 'clerk_dev_browser_jwt';

  // Save session to persistent storage
  Future<void> saveSession(ClerkSession session) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionData = {
        'session': session.toJson(),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'expiresAt': session.expireAt.millisecondsSinceEpoch,
      };
      
      await prefs.setString(_sessionKey, jsonEncode(sessionData));
      print('✅ Session saved to storage');
    } catch (e) {
      print('❌ Error saving session: $e');
    }
  }

  // Restore session from persistent storage
  Future<ClerkSession?> getSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionJson = prefs.getString(_sessionKey);
      
      if (sessionJson == null) return null;
      
      final data = jsonDecode(sessionJson) as Map<String, dynamic>;
      final expiresAt = DateTime.fromMillisecondsSinceEpoch(data['expiresAt']);
      
      // Check if session is still valid
      if (expiresAt.isAfter(DateTime.now())) {
        final session = ClerkSession.fromJson(data['session']);
        print('✅ Valid session restored from storage');
        return session;
      } else {
        // Session expired, clear it
        await clearSession();
        print('⚠️ Stored session expired, cleared');
        return null;
      }
      
    } catch (e) {
      print('❌ Error loading session: $e');
      await clearSession();
      return null;
    }
  }

  // Clear session from storage
  Future<void> clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sessionKey);
      print('🗑️ Session cleared from storage');
    } catch (e) {
      print('❌ Error clearing session: $e');
    }
  }
}
```

### Automatic Session Refresh

The SDK maintains session validity by refreshing them periodically:

```dart
class AuthProvider extends ChangeNotifier {
  Timer? _refreshTimer;
  
  void _startSessionRefreshTimer() {
    _refreshTimer?.cancel();
    
    // Refresh session every 5 minutes
    _refreshTimer = Timer.periodic(Duration(minutes: 5), (timer) async {
      if (_session != null && _isSignedIn) {
        try {
          final refreshed = await _clerkService.refreshSession();
          if (refreshed) {
            print('🔄 Session refreshed automatically');
          } else {
            print('⚠️ Session refresh failed, user may need to re-authenticate');
            await signOut();
          }
        } catch (e) {
          print('❌ Auto-refresh error: $e');
        }
      }
    });
  }
  
  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}
```

### Session State Management

The authentication state flows through the app using Provider:

```dart
// Widget that responds to authentication state changes
class AuthWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, child) {
        // Show loading while SDK initializes
        if (!auth.isLoaded) {
          return _buildLoadingScreen();
        }
        
        // Show error if initialization failed
        if (auth.error != null) {
          return _buildErrorScreen(auth.error!);
        }
        
        // Show appropriate screen based on auth state
        return auth.isSignedIn 
            ? HomeScreen()    // User has valid session
            : LoginScreen();  // User needs to authenticate
      },
    );
  }
  
  Widget _buildLoadingScreen() {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Initializing...'),
            SizedBox(height: 8),
            Text(
              'Checking for existing session',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
```

### Handling Session Expiry

When sessions expire, the SDK gracefully handles the transition:

```dart
class ClerkService {
  Future<bool> _handleApiResponse(http.Response response) async {
    if (response.statusCode == 401) {
      // Session invalid/expired
      print('🔐 Session expired, clearing stored data');
      
      await _storage.clearSession();
      await _storage.clearAllTokens();
      
      // Notify the app to update UI
      _authProvider.handleSessionExpired();
      
      return false;
    }
    return true;
  }
}

class AuthProvider extends ChangeNotifier {
  void handleSessionExpired() {
    _session = null;
    _user = null;
    _isSignedIn = false;
    _refreshTimer?.cancel();
    
    notifyListeners();
    
    // Optionally show a snackbar or dialog
    _showSessionExpiredMessage();
  }
  
  void _showSessionExpiredMessage() {
    // Implementation depends on your navigation setup
    // You might use a global navigator key or context
  }
}
```

### Token Caching for Performance

JWT tokens are cached to improve performance:

```dart
class StorageHelper {
  // Cache token with expiry check
  Future<void> saveToken(String sessionId, String template, String jwt) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cache = await _getTokenCache();
      
      // Decode JWT to get expiration
      final payload = _decodeJWT(jwt);
      final expiresAt = payload['exp'] * 1000;
      
      cache['${sessionId}_$template'] = {
        'jwt': jwt,
        'expiresAt': expiresAt,
        'cachedAt': DateTime.now().millisecondsSinceEpoch,
      };
      
      await prefs.setString(_tokenCacheKey, jsonEncode(cache));
    } catch (e) {
      print('❌ Error caching token: $e');
    }
  }
  
  // Get cached token if still valid
  Future<String?> getToken(String sessionId, String template) async {
    try {
      final cache = await _getTokenCache();
      final cacheKey = '${sessionId}_$template';
      final tokenData = cache[cacheKey];
      
      if (tokenData == null) return null;
      
      final expiresAt = tokenData['expiresAt'] as int;
      final now = DateTime.now().millisecondsSinceEpoch;
      
      // Return token if it expires more than 5 minutes from now
      if (expiresAt > now + (5 * 60 * 1000)) {
        return tokenData['jwt'] as String;
      } else {
        // Token expired, remove from cache
        cache.remove(cacheKey);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_tokenCacheKey, jsonEncode(cache));
        return null;
      }
    } catch (e) {
      print('❌ Error getting cached token: $e');
      return null;
    }
  }
}
```

### Best Practices for Session Management

1. **Always Handle Loading States**: Show appropriate UI while checking for existing sessions
2. **Graceful Fallback**: Clear invalid sessions and redirect to login
3. **Automatic Refresh**: Keep sessions valid without user interaction
4. **Secure Storage**: Use SharedPreferences for non-sensitive data only
5. **Network Error Handling**: Handle offline scenarios gracefully

```dart
class AuthProvider extends ChangeNotifier {
  // Handle network connectivity issues
  Future<void> handleNetworkError() async {
    // Try to use cached session if available
    final cachedSession = await _storage.getCachedSession();
    
    if (cachedSession != null && cachedSession.isActive) {
      _session = cachedSession;
      _user = cachedSession.user;
      _isSignedIn = true;
      
      print('📱 Using cached session during network issues');
    } else {
      // No valid cached session, user needs to authenticate when online
      _showNetworkErrorMessage();
    }
    
    notifyListeners();
  }
}
```

This approach ensures that users remain logged in across app launches, handles session expiry gracefully, and provides a smooth authentication experience on mobile devices.

---

## 🎯 Best Practices

### 1. Error Handling

```dart
class ClerkErrorHandler {
  static String getErrorMessage(ClerkException error) {
    switch (error.errors.first.code) {
      case 'form_password_incorrect':
        return 'Invalid password. Please try again.';
      case 'form_identifier_not_found':
        return 'Account not found. Please sign up first.';
      case 'form_code_incorrect':
        return 'Invalid code. Please check and try again.';
      case 'session_invalid':
        return 'Session expired. Please sign in again.';
      default:
        return error.message;
    }
  }
  
  static void handleError(BuildContext context, dynamic error) {
    String message;
    
    if (error is ClerkException) {
      message = getErrorMessage(error);
    } else {
      message = error.toString();
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}
```

### 2. Loading States

```dart
class LoadingButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback? onPressed;
  final String text;
  
  const LoadingButton({
    Key? key,
    required this.isLoading,
    required this.onPressed,
    required this.text,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      child: isLoading 
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
        : Text(text),
    );
  }
}
```

### 3. Form Validation

```dart
class EmailValidator {
  static String? validate(String? value) {
    if (value?.isEmpty ?? true) {
      return 'Please enter your email';
    }
    
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    if (!emailRegex.hasMatch(value!)) {
      return 'Please enter a valid email';
    }
    
    return null;
  }
}

class PasswordValidator {
  static String? validate(String? value) {
    if (value?.isEmpty ?? true) {
      return 'Please enter a password';
    }
    
    if (value!.length < 8) {
      return 'Password must be at least 8 characters';
    }
    
    return null;
  }
}
```

### 4. Token Usage

```dart
class ApiService {
  final AuthProvider _authProvider;
  
  ApiService(this._authProvider);
  
  Future<http.Response> authenticatedRequest(String url) async {
    final token = await _authProvider.getToken();
    
    if (token == null) {
      throw Exception('No authentication token available');
    }
    
    return http.get(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
  }
}
```

---

## 🔧 Troubleshooting

### Common Issues

1. **Development Instance Authentication**
   ```dart
   // Make sure domain is correct
   ClerkService('your-instance.clerk.accounts.dev')
   
   // Check console for dev browser JWT messages
   ```

2. **Session Persistence Issues**

   **Issue 2a: Session Stored in SharedPreferences but User Not Restored**
   
   **Symptoms:**
   ```dart
   // Debug output shows session exists
   ✅ Valid session restored from storage
   // But AuthProvider.isSignedIn is still false
   ```
   
   **Root Cause:** Session restoration not updating state management properly.
   
   **Solution:**
   ```dart
   class AuthProvider extends ChangeNotifier {
     Future<void> initialize() async {
       try {
         setLoading(true);
         
         // CRITICAL: Setup dev browser first
         await _clerkService.setupDevBrowser();
         
         // Try to restore session from SharedPreferences
         print('🔍 Checking SharedPreferences for stored session...');
         final restoredSession = await _clerkService.getStoredSession();
         
         if (restoredSession != null) {
           print('📦 Found stored session, validating...');
           
           // Check if session hasn't expired
           if (restoredSession.expireAt.isAfter(DateTime.now())) {
             // CRITICAL: Update state management
             _session = restoredSession;
             _user = restoredSession.user;
             _isSignedIn = true;
             
             // Try to validate with server, but don't require it
             try {
               final isValid = await _clerkService.validateSession();
               if (!isValid) {
                 print('⚠️ Server validation failed, clearing session');
                 await signOut();
                 return;
               }
               print('✅ Session validated with server');
             } catch (e) {
               print('🔄 Server validation failed, using cached session: $e');
               // Continue with cached session in offline mode
             }
             
             print('🎉 Session restored for: ${_user?.emailAddresses.first.emailAddress}');
           } else {
             print('⚠️ Stored session expired, clearing');
             await _clerkService.clearStoredSession();
           }
         } else {
           print('ℹ️ No stored session found');
         }
         
         _isLoaded = true;
         _error = null;
         
       } catch (e) {
         _error = 'Failed to initialize: $e';
         print('❌ AuthProvider initialization failed: $e');
       } finally {
         setLoading(false);
         notifyListeners(); // CRITICAL: Notify UI of changes
       }
     }
   }
   ```

   **Issue 2b: SharedPreferences Not Working Properly**
   
   **Debugging Steps:**
   ```dart
   // Test SharedPreferences directly
   Future<void> debugSharedPreferences() async {
     final prefs = await SharedPreferences.getInstance();
     
     // Test write
     await prefs.setString('test_key', 'test_value');
     final testValue = prefs.getString('test_key');
     print('SharedPreferences test: $testValue');
     
     // Check session data
     final sessionJson = prefs.getString('clerk_session');
     if (sessionJson != null) {
       final data = jsonDecode(sessionJson);
       print('Session data structure: ${data.keys}');
       print('Session expires: ${data['session']['expire_at']}');
     } else {
       print('No session data in SharedPreferences');
     }
   }
   ```

   **Issue 2c: Mobile App Lifecycle Issues**
   
   **Root Cause:** App state not properly handled during backgrounding/foregrounding.
   
   **Solution:**
   ```dart
   class AuthProvider extends ChangeNotifier with WidgetsBindingObserver {
     @override
     void initState() {
       super.initState();
       WidgetsBinding.instance.addObserver(this);
     }
     
     @override
     void dispose() {
       WidgetsBinding.instance.removeObserver(this);
       super.dispose();
     }
     
     @override
     void didChangeAppLifecycleState(AppLifecycleState state) {
       super.didChangeAppLifecycleState(state);
       
       switch (state) {
         case AppLifecycleState.resumed:
           // App came to foreground - validate session
           if (_isSignedIn) {
             _validateSessionInBackground();
           }
           break;
         case AppLifecycleState.paused:
           // App going to background - save current state
           if (_session != null) {
             _clerkService.saveSession(_session!);
           }
           break;
         default:
           break;
       }
     }
     
     Future<void> _validateSessionInBackground() async {
       try {
         final isValid = await _clerkService.validateSession();
         if (!isValid && _isSignedIn) {
           print('🔐 Session invalid after app resume, signing out');
           await signOut();
         }
       } catch (e) {
         print('⚠️ Background session validation failed: $e');
       }
     }
   }
   ```

   **Flutter Session Debugging Checklist:**
   
   When session persistence isn't working in your Flutter app, check these in order:
   
   1. **SharedPreferences Content**:
      ```dart
      Future<void> debugSessionStorage() async {
        final prefs = await SharedPreferences.getInstance();
        final keys = prefs.getKeys();
        print('All SharedPreferences keys: $keys');
        
        final sessionData = prefs.getString('clerk_session');
        if (sessionData != null) {
          final parsed = jsonDecode(sessionData);
          print('Session data: ${parsed['session']['id']}');
          print('Expires: ${parsed['session']['expire_at']}');
          print('User: ${parsed['session']['user']['email_addresses']}');
        } else {
          print('No session data found');
        }
      }
      ```

   2. **AuthProvider State**:
      ```dart
      // After initialization
      print('AuthProvider State:');
      print('- isLoaded: ${authProvider.isLoaded}');
      print('- isSignedIn: ${authProvider.isSignedIn}');
      print('- hasSession: ${authProvider.session != null}');
      print('- hasUser: ${authProvider.user != null}');
      print('- error: ${authProvider.error}');
      ```

   3. **Network Connectivity**:
      ```dart
      Future<void> testNetworkConnection() async {
        try {
          final response = await http.get(
            Uri.parse('https://your-instance.clerk.accounts.dev/v1/environment'),
          );
          print('Network test: ${response.statusCode}');
        } catch (e) {
          print('Network error: $e');
        }
      }
      ```

   4. **App Lifecycle Integration**:
      ```dart
      // Make sure your AuthWrapper properly handles state changes
      class AuthWrapper extends StatelessWidget {
        @override
        Widget build(BuildContext context) {
          return Consumer<AuthProvider>(
            builder: (context, auth, child) {
              print('AuthWrapper rebuild - isLoaded: ${auth.isLoaded}, isSignedIn: ${auth.isSignedIn}');
              
              if (!auth.isLoaded) {
                return LoadingScreen();
              }
              
              if (auth.error != null) {
                return ErrorScreen(error: auth.error!);
              }
              
              return auth.isSignedIn ? HomeScreen() : LoginScreen();
            },
          );
        }
      }
      ```

3. **CORS Issues** (Should not occur in Flutter, but if using webview):
   ```dart
   // Flutter HTTP client handles this automatically
   // No CORS workarounds needed like in web browsers
   ```

4. **Token Expiry**
   ```dart
   // Always check token validity
   final token = await authProvider.getToken();
   if (token == null) {
     // Redirect to login
   }
   ```

This Flutter implementation provides a complete Clerk authentication SDK that mirrors the functionality of the web SDK while being optimized for mobile development patterns and Flutter's reactive architecture.