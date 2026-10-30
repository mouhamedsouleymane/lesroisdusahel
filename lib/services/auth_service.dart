import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import 'api_service.dart';

class AuthService {
  static const String userKey = 'auth_user_data';
  static UserModel? _currentUser;

  static UserModel? get currentUser => _currentUser;
  static bool get isAuthenticated => _currentUser != null;

  // Restaurer la session existante depuis SharedPreferences
  static Future<UserModel?> loadSavedUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJsonStr = prefs.getString(userKey);
      if (userJsonStr != null && userJsonStr.isNotEmpty) {
        final Map<String, dynamic> data = jsonDecode(userJsonStr);
        _currentUser = UserModel.fromJson(data);
        return _currentUser;
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
      } else if (response.statusCode == 422) {
        final data = jsonDecode(response.body);
        return {'success': false, 'message': data['message'] ?? 'Identifiants invalides.'};
      }
    } catch (e) {
      // Si le serveur local n'a pas encore la route API configurée, on propose une connexion de démo instantanée
      // afin que l'utilisateur puisse immédiatement explorer les 4 dashboards !
    }

    return {'success': false, 'message': 'Impossible de joindre le serveur API. Vérifiez que php artisan serve est lancé sur le port 8000.'};
  }

  // Connexion rapide pour démonstration de chaque rôle
  static Future<UserModel> loginAsDemoRole(UserRole role) async {
    final demoUsers = {
      UserRole.admin: UserModel(
        id: 1,
        name: 'M. Le Proviseur',
        email: 'admin@roisdusahel.com',
        role: UserRole.admin,
        matricule: 'DIR-001',
      ),
      UserRole.teacher: UserModel(
        id: 2,
        name: 'M. Mahamadou Issa',
        email: 'm.issa@roisdusahel.com',
        role: UserRole.teacher,
        matricule: 'ENS-2025-0001',
      ),
      UserRole.parent: UserModel(
        id: 3,
        name: 'Mme Ousmane Fatouma',
        email: 'parent.fatouma@gmail.com',
        role: UserRole.parent,
        phone: '+227 90 00 11 22',
      ),
      UserRole.student: UserModel(
        id: 4,
        name: 'Ousmane Sani Abakar',
        email: 'eleve.sani@roisdusahel.com',
        role: UserRole.student,
        matricule: '2025-00862',
      ),
    };

    final user = demoUsers[role] ?? demoUsers[UserRole.admin]!;
    _currentUser = user;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(userKey, jsonEncode(user.toJson()));
    await ApiService.saveToken('demo-token-${role.name}');

    return user;
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

