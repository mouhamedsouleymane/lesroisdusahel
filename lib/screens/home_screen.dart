import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/contact_service.dart';
import 'dashboards/admin_dashboard.dart';
import 'dashboards/parent_dashboard.dart';
import 'dashboards/student_dashboard.dart';
import 'dashboards/teacher_dashboard.dart';
import 'login_screen.dart';
import 'tabs/grades_screen.dart';
import 'tabs/profile_screen.dart';
import 'tabs/schedules_screen.dart';

class HomeScreen extends StatefulWidget {
  final UserModel user;
  const HomeScreen({super.key, required this.user});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late UserModel _currentUser;
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
  }

  void _switchRole(UserRole newRole) async {
    Navigator.pop(context); // fermer drawer
    final updatedUser = await AuthService.loginAsDemoRole(newRole);
    setState(() {
      _currentUser = updatedUser;
      _currentTabIndex = 0;
    });
  }

  void _handleLogout() async {
    await AuthService.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Widget _buildRoleDashboard() {
    switch (_currentUser.role) {
      case UserRole.admin:
        return AdminDashboard(user: _currentUser);
      case UserRole.teacher:
        return TeacherDashboard(user: _currentUser);
      case UserRole.parent:
        return ParentDashboard(user: _currentUser);
      case UserRole.student:
        return StudentDashboard(user: _currentUser);
      default:
        return Center(
          child: Text('Bienvenue, ${_currentUser.name} !'),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      appBar: _currentTabIndex == 0
          ? AppBar(
              backgroundColor: Colors.white,
              foregroundColor: AppTheme.textDark,
              elevation: 0,
              title: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/logo_roi.jpeg',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.school, size: 18, color: AppTheme.primaryPurple),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text('ROIS DU SAHEL', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.notifications_none_rounded),
                  tooltip: 'Notifications',
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Aucune nouvelle alerte pour le moment.')),
                    );
                  },
                ),
              ],
            )
          : null,

      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF2E0249), AppTheme.primaryPurple],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              currentAccountPicture: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.accentGold, width: 2),
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/logo_roi.jpeg',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.person, color: Colors.white, size: 36),
                  ),
                ),
              ),
              accountName: Text(_currentUser.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              accountEmail: Text('${_currentUser.email} • ${_currentUser.role.label}', style: const TextStyle(fontSize: 12, color: AppTheme.accentGoldLight)),
            ),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Changer d\'espace (Option C Multi-rôles)',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textMuted),
              ),
            ),

            ListTile(
              leading: const Icon(Icons.admin_panel_settings, color: AppTheme.primaryPurple),
              title: const Text('Direction / Administration'),
              selected: _currentUser.role == UserRole.admin,
              onTap: () => _switchRole(UserRole.admin),
            ),
            ListTile(
              leading: const Icon(Icons.person_pin, color: Colors.indigo),
              title: const Text('Enseignant'),
              selected: _currentUser.role == UserRole.teacher,
              onTap: () => _switchRole(UserRole.teacher),
            ),
            ListTile(
              leading: const Icon(Icons.family_restroom, color: Colors.purple),
              title: const Text('Parent d\'Élève'),
              selected: _currentUser.role == UserRole.parent,
              onTap: () => _switchRole(UserRole.parent),
            ),
            ListTile(
              leading: const Icon(Icons.school, color: Colors.amber),
              title: const Text('Élève'),
              selected: _currentUser.role == UserRole.student,
              onTap: () => _switchRole(UserRole.student),
            ),

            const Divider(),

            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Se déconnecter', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              onTap: _handleLogout,
            ),
          ],
        ),
      ),

      body: IndexedStack(
        index: _currentTabIndex,
        children: [
          _buildRoleDashboard(),
          SchedulesScreen(user: _currentUser),
          GradesScreen(user: _currentUser),
          ProfileScreen(user: _currentUser),
        ],
      ),

      floatingActionButton: (_currentUser.role == UserRole.parent || _currentUser.role == UserRole.student)
          ? FloatingActionButton.extended(
              backgroundColor: const Color(0xFF25D366),
              icon: const Icon(Icons.chat_bubble, color: Colors.white, size: 20),
              label: const Text('WhatsApp École', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              onPressed: () => ContactService.openWhatsApp(),
            )
          : null,

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTabIndex,
        selectedItemColor: AppTheme.primaryPurple,
        unselectedItemColor: AppTheme.textMuted,
        type: BottomNavigationBarType.fixed,
        onTap: (index) => setState(() => _currentTabIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Accueil'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today_rounded), label: 'Horaires'),
          BottomNavigationBarItem(icon: Icon(Icons.insert_chart_outlined_rounded), label: 'Notes'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline_rounded), label: 'Profil'),
        ],
      ),
    );
  }
}
