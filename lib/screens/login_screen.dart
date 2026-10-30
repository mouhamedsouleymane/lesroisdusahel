import 'package:flutter/material.dart';
import '../config/api_config.dart';
import '../config/app_theme.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController(text: 'admin@roisdusahel.com');
  final _passwordController = TextEditingController(text: 'password');
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool? _isApiConnected;
  String _currentApiUrl = '';

  @override
  void initState() {
    super.initState();
    _checkServerStatus();
  }

  Future<void> _checkServerStatus() async {
    final url = await ApiConfig.getBaseUrl();
    final connected = await ApiService.testConnection();
    if (mounted) {
      setState(() {
        _currentApiUrl = url;
        _isApiConnected = connected;
      });
    }
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez renseigner votre email et mot de passe.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final result = await AuthService.login(email: email, password: password);

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (result['success'] == true && result['user'] != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => HomeScreen(user: result['user'] as UserModel)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Erreur de connexion.'),
          backgroundColor: Colors.red.shade800,
          action: SnackBarAction(
            label: 'Mode Démo',
            textColor: AppTheme.accentGold,
            onPressed: () => _handleDemoLogin(UserRole.admin),
          ),
        ),
      );
    }
  }

  Future<void> _handleDemoLogin(UserRole role) async {
    setState(() => _isLoading = true);
    final user = await AuthService.loginAsDemoRole(role);
    setState(() => _isLoading = false);

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => HomeScreen(user: user)),
    );
  }

  void _showApiSettingsDialog() {
    final ipController = TextEditingController(text: _currentApiUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Configuration Serveur API', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Adresse du serveur Laravel (ex: http://127.0.0.1:8000 ou l\'IP de votre PC sur Wi-Fi pour un vrai smartphone) :',
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ipController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.dns),
                hintText: 'http://192.168.1.100:8000',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              final navigator = Navigator.of(ctx);
              await ApiConfig.setCustomBaseUrl(ipController.text.trim());
              navigator.pop();
              _checkServerStatus();
            },
            child: const Text('Sauvegarder'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Bouton réglages serveur API
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  InkWell(
                    onTap: _showApiSettingsDialog,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderLight),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.circle,
                            size: 10,
                            color: _isApiConnected == true ? Colors.green : (_isApiConnected == false ? Colors.red : Colors.amber),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _isApiConnected == true ? 'Serveur en ligne' : 'Serveur local',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.settings, size: 14, color: AppTheme.textMuted),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // En-tête avec logo
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.accentGold, width: 2.5),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryPurple.withValues(alpha: 0.15),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/logo_roi.jpeg',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Icon(
                            Icons.school,
                            size: 46,
                            color: AppTheme.primaryPurple,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'LES ROIS DU SAHEL',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.primaryPurple,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const Text(
                      'Portail Mobile Multi-Rôles',
                      style: TextStyle(fontSize: 13, color: AppTheme.textMuted, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Formulaire de connexion
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppTheme.borderLight),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Connexion au compte',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppTheme.textDark),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Adresse Email ou Matricule',
                        prefixIcon: Icon(Icons.mail_outline),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Mot de passe',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: AppTheme.textMuted),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleLogin,
                        child: _isLoading
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('Se connecter'),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Option C : Sélecteur de rôle instantané (Démo & Exploration)
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'OU EXPLORER PAR RÔLE (OPTION C)',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey.shade600, letterSpacing: 0.8),
                    ),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),

              const SizedBox(height: 14),

              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 2.3,
                children: [
                  _RoleQuickCard(
                    icon: Icons.admin_panel_settings,
                    title: 'Admin / Direction',
                    color: AppTheme.primaryPurple,
                    onTap: () => _handleDemoLogin(UserRole.admin),
                  ),
                  _RoleQuickCard(
                    icon: Icons.person_pin,
                    title: 'Enseignant',
                    color: Colors.indigo.shade800,
                    onTap: () => _handleDemoLogin(UserRole.teacher),
                  ),
                  _RoleQuickCard(
                    icon: Icons.family_restroom,
                    title: 'Parent d\'Élève',
                    color: Colors.purple.shade900,
                    onTap: () => _handleDemoLogin(UserRole.parent),
                  ),
                  _RoleQuickCard(
                    icon: Icons.school,
                    title: 'Élève',
                    color: Colors.amber.shade900,
                    onTap: () => _handleDemoLogin(UserRole.student),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleQuickCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  const _RoleQuickCard({required this.icon, required this.title, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
