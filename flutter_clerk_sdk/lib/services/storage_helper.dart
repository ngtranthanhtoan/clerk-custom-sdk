import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/session.dart';

class StorageHelper {
  static const String _sessionKey = 'clerk_session';
  static const String _tokenCacheKey = 'clerk_token_cache';

  Future<void> saveSession(ClerkSession session) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionJson = jsonEncode({
        'session': session.toJson(),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      await prefs.setString(_sessionKey, sessionJson);
      print('✅ Session saved to storage');
    } catch (e) {
      print('❌ Error saving session: $e');
    }
  }

  Future<ClerkSession?> getSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionJson = prefs.getString(_sessionKey);
      
      if (sessionJson == null) {
        print('ℹ️ No stored session found');
        return null;
      }

      final data = jsonDecode(sessionJson) as Map<String, dynamic>;
      final session = ClerkSession.fromJson(data['session']);
      
      // Check if session is still valid
      if (session.isActive) {
        print('✅ Valid session restored from storage');
        return session;
      } else {
        print('⚠️ Stored session expired, clearing...');
        await clearSession();
        return null;
      }
    } catch (e) {
      print('❌ Error loading session: $e');
      // Clear corrupted session data
      await clearSession();
      return null;
    }
  }

  Future<void> clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sessionKey);
      print('🗑️ Session cleared from storage');
    } catch (e) {
      print('❌ Error clearing session: $e');
    }
  }

  Future<void> saveToken(String sessionId, String template, String jwt) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '${sessionId}_$template';
      
      // Decode JWT to get expiration
      final parts = jwt.split('.');
      if (parts.length == 3) {
        final payload = jsonDecode(
          utf8.decode(base64Url.decode(_normalizeBase64(parts[1])))
        ) as Map<String, dynamic>;
        
        final tokenData = {
          'jwt': jwt,
          'expiresAt': payload['exp'] * 1000,
          'cachedAt': DateTime.now().millisecondsSinceEpoch,
        };
        
        final cache = await _getTokenCache();
        cache[cacheKey] = tokenData;
        await prefs.setString(_tokenCacheKey, jsonEncode(cache));
        print('🎟️ Token cached for session $sessionId');
      }
    } catch (e) {
      print('❌ Error caching token: $e');
    }
  }

  Future<String?> getToken(String sessionId, String template) async {
    try {
      final cache = await _getTokenCache();
      final cacheKey = '${sessionId}_$template';
      final tokenData = cache[cacheKey];
      
      if (tokenData == null) {
        print('ℹ️ No cached token found for $cacheKey');
        return null;
      }

      final expiresAt = tokenData['expiresAt'] as int;
      final now = DateTime.now().millisecondsSinceEpoch;
      
      // Return token if it expires more than 5 minutes from now
      if (expiresAt > now + (5 * 60 * 1000)) {
        print('✅ Using cached token for $cacheKey');
        return tokenData['jwt'] as String;
      } else {
        print('⚠️ Cached token expired for $cacheKey');
        await _removeToken(cacheKey);
        return null;
      }
    } catch (e) {
      print('❌ Error checking cached token: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> _getTokenCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheJson = prefs.getString(_tokenCacheKey);
      
      if (cacheJson == null) return {};
      
      return jsonDecode(cacheJson) as Map<String, dynamic>;
    } catch (e) {
      print('❌ Error reading token cache: $e');
      return {};
    }
  }

  Future<void> _removeToken(String cacheKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cache = await _getTokenCache();
      cache.remove(cacheKey);
      await prefs.setString(_tokenCacheKey, jsonEncode(cache));
    } catch (e) {
      print('❌ Error removing token: $e');
    }
  }

  Future<void> clearAllTokens() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenCacheKey);
      print('🗑️ All tokens cleared from cache');
    } catch (e) {
      print('❌ Error clearing tokens: $e');
    }
  }

  // Helper method to normalize base64 padding
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

  // Dev browser JWT storage
  Future<void> saveDevBrowserJWT(String jwt) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('clerk_dev_browser_jwt', jwt);
      print('✅ Dev browser JWT saved');
    } catch (e) {
      print('❌ Error saving dev browser JWT: $e');
    }
  }

  Future<String?> getDevBrowserJWT() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('clerk_dev_browser_jwt');
    } catch (e) {
      print('❌ Error getting dev browser JWT: $e');
      return null;
    }
  }

  Future<void> clearDevBrowserJWT() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('clerk_dev_browser_jwt');
      print('🗑️ Dev browser JWT cleared');
    } catch (e) {
      print('❌ Error clearing dev browser JWT: $e');
    }
  }

  // Generic storage methods for compatibility
  Future<String?> getString(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(key);
    } catch (e) {
      print('❌ Error getting string for key $key: $e');
      return null;
    }
  }

  Future<void> setString(String key, String value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
    } catch (e) {
      print('❌ Error setting string for key $key: $e');
    }
  }

  Future<void> remove(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    } catch (e) {
      print('❌ Error removing key $key: $e');
    }
  }
}