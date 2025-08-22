import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiClient {
  final String domain;
  final http.Client _client;
  String? _devBrowserJWT;

  ApiClient({required this.domain}) : _client = http.Client();

  bool get _isDevInstance => domain.contains('.clerk.accounts.dev') ||
                           domain.contains('.lclclerk.com') ||
                           domain.contains('clerk.dev');

  void setDevBrowserJWT(String jwt) {
    _devBrowserJWT = jwt;
  }

  Uri _buildUrl(String path, {Map<String, String>? queryParams}) {
    final uri = Uri.https(domain, '/v1$path');
    final params = <String, String>{
      '__clerk_api_version': '2025-04-10',
      '_clerk_js_version': '5.88.0',
      ...?queryParams,
    };

    if (_isDevInstance && _devBrowserJWT != null) {
      params['__clerk_db_jwt'] = _devBrowserJWT!;
    }

    return uri.replace(queryParameters: params);
  }

  Future<Map<String, dynamic>> get(String path, {Map<String, String>? queryParams}) async {
    final url = _buildUrl(path, queryParams: queryParams);
    final response = await _client.get(url);
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> post(String path, {
    Map<String, dynamic>? data,
    Map<String, String>? queryParams,
  }) async {
    final url = _buildUrl(path, queryParams: queryParams);
    final response = await _client.post(
      url,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: data != null 
          ? Uri(queryParameters: data.map((k, v) => MapEntry(k, v.toString()))).query
          : '',
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> patch(String path, {
    Map<String, dynamic>? data,
    Map<String, String>? queryParams,
  }) async {
    final url = _buildUrl(path, queryParams: {
      '_method': 'PATCH',
      ...?queryParams,
    });
    final response = await _client.post(
      url,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: data != null 
          ? Uri(queryParameters: data.map((k, v) => MapEntry(k, v.toString()))).query
          : '',
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> put(String path, {
    Map<String, dynamic>? data,
    Map<String, String>? queryParams,
  }) async {
    final url = _buildUrl(path, queryParams: {
      '_method': 'PUT',
      ...?queryParams,
    });
    final response = await _client.post(
      url,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: data != null 
          ? Uri(queryParameters: data.map((k, v) => MapEntry(k, v.toString()))).query
          : '',
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> delete(String path, {Map<String, String>? queryParams}) async {
    final url = _buildUrl(path, queryParams: {
      '_method': 'DELETE',
      ...?queryParams,
    });
    final response = await _client.post(url);
    return _handleResponse(response);
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Invalid JSON response');
    }

    if (response.statusCode >= 400) {
      final errors = (data['errors'] as List?)
          ?.map((e) => e['message'] ?? e.toString())
          .join(', ') ?? data['message'] ?? 'Unknown error';
      throw Exception(errors);
    }

    return data['response'] ?? data;
  }

  void dispose() {
    _client.close();
  }
}