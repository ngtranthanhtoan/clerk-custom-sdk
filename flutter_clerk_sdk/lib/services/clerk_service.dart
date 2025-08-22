import 'dart:convert';
import 'package:http/http.dart' as http;

class ClerkService {
  final String domain;
  final http.Client _client;
  final String _apiVersion = '2025-04-10';
  final String _jsVersion = '5.88.0';
  String? _devBrowserJWT;

  ClerkService(this.domain) : _client = http.Client();

  bool get _isDevInstance => domain.contains('.clerk.accounts.dev') ||
                           domain.contains('.lclclerk.com') ||
                           domain.contains('clerk.dev');

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

    try {
      if (actualMethod == 'GET') {
        response = await _client.get(url, headers: headers);
      } else {
        final encodedBody = body != null 
            ? Uri(queryParameters: body.map((k, v) => MapEntry(k, v.toString())))
                  .query
            : '';
        response = await _client.post(url, headers: headers, body: encodedBody);
      }
    } catch (e) {
      throw ClerkException('Network error: ${e.toString()}', 0, []);
    }

    Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      throw ClerkException('Invalid JSON response', response.statusCode, []);
    }

    if (response.statusCode >= 400) {
      throw ClerkException.fromJson(data, response.statusCode);
    }

    return data;
  }

  Future<void> setupDevBrowser() async {
    if (!_isDevInstance) {
      print('📝 Production instance - skipping dev browser setup');
      return;
    }

    print('🔧 Setting up development browser authentication...');

    try {
      // Try to get dev browser JWT
      final response = await _client.post(
        Uri.https(domain, '/v1/dev_browser'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        _devBrowserJWT = data['id'];
        print('✅ Dev browser JWT obtained');
      } else {
        print('⚠️ Could not obtain dev browser JWT: ${response.statusCode}');
      }
    } catch (e) {
      print('⚠️ Could not obtain dev browser JWT: $e');
      print('💡 You may need to visit your Clerk Dashboard to authenticate this browser');
    }
  }

  Future<Map<String, dynamic>> getEnvironment() async {
    return await request('/environment');
  }

  Future<Map<String, dynamic>> getClient() async {
    return await request('/client');
  }

  Future<Map<String, dynamic>> createClient() async {
    return await request('/client', method: 'PUT');
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
                   json['message'] ??
                   'Unknown error';

    return ClerkException(message, statusCode, errors);
  }

  @override
  String toString() => 'ClerkException: $message (Status: $statusCode)';

  String get userFriendlyMessage {
    if (errors.isEmpty) return message;

    final error = errors.first;
    switch (error.code) {
      case 'form_password_incorrect':
        return 'Invalid password. Please try again.';
      case 'form_identifier_not_found':
        return 'Account not found. Please sign up first.';
      case 'form_code_incorrect':
        return 'Invalid code. Please check and try again.';
      case 'session_invalid':
        return 'Session expired. Please sign in again.';
      case 'dev_browser_unauthenticated':
        return 'Development browser not authenticated. Please visit Clerk Dashboard.';
      default:
        return error.longMessage ?? error.message;
    }
  }
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

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'message': message,
      'long_message': longMessage,
    };
  }
}