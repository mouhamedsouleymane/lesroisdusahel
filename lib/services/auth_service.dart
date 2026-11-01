import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import 'api_service.dart';

class AuthService {
  static const String userKey = 'auth_user_data';
  static UserModel? _currentUser;

  static UserModel? get currentUser => _currentUser;
  static bool get isAuthenticated => _currentUser != null;

  // Restaurer la session existante et actualiser les droits depuis MySQL
  static Future<UserModel?> loadSavedUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJsonStr = prefs.getString(userKey);
      if (userJsonStr != null && userJsonStr.isNotEmpty) {
        final Map<String, dynamic> data = jsonDecode(userJsonStr);
        _currentUser = UserModel.fromJson(data);

        // Actualiser immédiatement le rôle et les permissions en temps réel depuis MySQL
        final fresh = await refreshCurrentUser();
        return fresh ?? _currentUser;
      }
    } catch (_) {}
    return null;
  }

  // Connexion via API Laravel (avec mode démonstration si l'API n'est pas encore connectée)
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await ApiService.post('/login', {
        'email': email,
        'password': password,
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['token'] ?? data['access_token'];
        final userData = data['user'] ?? data['data'];

        if (token != null) {
          await ApiService.saveToken(token.toString());
        }

        if (userData != null) {
          _currentUser = UserModel.fromJson(userData);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(userKey, jsonEncode(_currentUser!.toJson()));
          return {'success': true, 'user': _currentUser};
        }
      } else if (response.statusCode == 422 || response.statusCode == 403 || response.statusCode == 401) {
        final data = jsonDecode(response.body);
        return {'success': false, 'message': data['message'] ?? 'Identifiants invalides.'};
      }
    } catch (e) {
      // Si le serveur local n'a pas encore la route API configurée, on propose une connexion de démo instantanée
      // afin que l'utilisateur puisse immédiatement explorer les 4 dashboards !
    }

    return {'success': false, 'message': 'Impossible de joindre le serveur API. Vérifiez que php artisan serve est lancé sur le port 8000.'};
  }

  // Connexion directe avec les comptes officiels de la base de données
  static const Map<UserRole, Map<String, String>> officialRoleAccounts = {
    UserRole.admin: {
      'login': 'admin@roisdusahel.ne',
      'password': 'Admin@2025!',
    },
    UserRole.teacher: {
      'login': 'ali.oumarou@roisdusahel.ne',
      'password': 'password',
    },
    UserRole.parent: {
      'login': 'admin@admin.com',
      'password': 'password',
    },
    UserRole.student: {
      'login': 'RS-2025-0001',
      'password': 'password',
    },
  };

  static Future<UserModel?> loginAsDemoRole(UserRole role) async {
    final creds = officialRoleAccounts[role] ?? officialRoleAccounts[UserRole.admin]!;
    final result = await login(
      email: creds['login']!,
      password: creds['password']!,
    );

    if (result['success'] == true && result['user'] != null) {
      return result['user'] as UserModel;
    }

    return null;
  }

  // Synchroniser le profil et le rôle en temps réel avec la base de données
  static Future<UserModel?> refreshCurrentUser() async {
    try {
      final response = await ApiService.get('/user');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['user'] != null) {
          _currentUser = UserModel.fromJson(data['user']);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(userKey, jsonEncode(_currentUser!.toJson()));
          return _currentUser;
        }
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        await logout();
        return null;
      }
    } catch (_) {}
    return _currentUser;
  }

  static Future<void> logout() async {
    try {
      await ApiService.post('/logout', {});
    } catch (_) {}

    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(userKey);
    await ApiService.clearToken();
  }
}

