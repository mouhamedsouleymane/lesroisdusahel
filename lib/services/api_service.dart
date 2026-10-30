import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class ApiService {
  static const String tokenKey = 'auth_token';

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(tokenKey);
  }

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(tokenKey, token);
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(tokenKey);
  }

  static Future<Map<String, String>> _headers() async {
    final token = await getToken();
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  // Vérifier la connexion avec le serveur Laravel
  static Future<bool> testConnection() async {
    try {
      final url = await ApiConfig.getApiUrl('/health');
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 4));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<http.Response> get(String endpoint) async {
    final url = await ApiConfig.getApiUrl(endpoint);
    final headers = await _headers();
    return await http.get(Uri.parse(url), headers: headers).timeout(const Duration(seconds: 10));
  }

  static Future<http.Response> post(String endpoint, Map<String, dynamic> data) async {
    final url = await ApiConfig.getApiUrl(endpoint);
    final headers = await _headers();
    return await http.post(
      Uri.parse(url),
      headers: headers,
      body: jsonEncode(data),
    ).timeout(const Duration(seconds: 10));
  }
}

