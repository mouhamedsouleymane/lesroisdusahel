import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiConfig {
  static const String defaultLocalhostUrl = 'http://127.0.0.1:8000';
  static const String androidEmulatorUrl = 'http://10.0.2.2:8000';
  static const String prefCustomUrlKey = 'custom_api_base_url';

  static String _cachedBaseUrl = '';

  static Future<String> getBaseUrl() async {
    if (_cachedBaseUrl.isNotEmpty) {
      return _cachedBaseUrl;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final customUrl = prefs.getString(prefCustomUrlKey);
      if (customUrl != null && customUrl.trim().isNotEmpty) {
        _cachedBaseUrl = customUrl.trim();
        return _cachedBaseUrl;
      }
    } catch (_) {}

    if (kIsWeb) {
      _cachedBaseUrl = defaultLocalhostUrl;
      return _cachedBaseUrl;
    }

    try {
      if (Platform.isAndroid) {
        _cachedBaseUrl = androidEmulatorUrl;
        return _cachedBaseUrl;
      }
    } catch (_) {}

    _cachedBaseUrl = defaultLocalhostUrl;
    return _cachedBaseUrl;
  }

  static Future<void> setCustomBaseUrl(String newUrl) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefCustomUrlKey, newUrl.trim());
    _cachedBaseUrl = newUrl.trim();
  }

  static Future<String> getApiUrl(String endpoint) async {
    final base = await getBaseUrl();
    final cleanEndpoint = endpoint.startsWith('/') ? endpoint : '/$endpoint';
    return '$base/api/v1$cleanEndpoint';
  }
}

