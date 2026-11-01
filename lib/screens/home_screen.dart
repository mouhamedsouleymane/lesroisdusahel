import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/app_theme.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/contact_service.dart';
import '../widgets/curved_nav_bar.dart';
import 'dashboards/admin_dashboard.dart';
import 'dashboards/parent_dashboard.dart';
import 'dashboards/student_dashboard.dart';
import 'dashboards/teacher_dashboard.dart';
import 'login_screen.dart';
import 'tabs/grades_screen.dart';
import 'tabs/profile_screen.dart';
import 'tabs/schedules_screen.dart';
import 'features/attendance_screen.dart';
import 'features/finances_screen.dart';
import 'features/grade_entry_screen.dart';
import 'features/messages_screen.dart';
import 'features/parent_notifications_screen.dart';

class HomeScreen extends StatefulWidget {
  final UserModel user;
  const HomeScreen({super.key, required this.user});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late UserModel _currentUser;
  int _currentTabIndex = 0;
  Timer? _autoSyncTimer;
  bool _isSyncing = false;
  int _unreadMessagesCount = 0;
  int? _lastNotifiedMessageId;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
    _checkLiveRole();
    _checkIncomingMessages(isInitial: true);
    _startAutoSync();
  }

  void _startAutoSync() {
    _autoSyncTimer?.cancel();
    // Synchronisation automatique toutes les 5 secondes (rôle + détection de nouveaux messages)
    _autoSyncTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) {
        _checkLiveRole(silent: true);
        _checkIncomingMessages(isInitial: false);
      }
    });
  }

  Future<void> _checkIncomingMessages({bool isInitial = false}) async {
    try {
      final res = await ApiService.get('/messages');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) {
          final int unread = (data['unread_count'] as num?)?.toInt() ?? 0;
          final List<dynamic> list = (data['messages'] as List<dynamic>?) ?? [];

          int? newestIncomingId;
          Map<String, dynamic>? newestIncomingMsg;
          for (final item in list) {
            final map = Map<String, dynamic>.from(item as Map);
            final bool isIncoming = (_currentUser.role == UserRole.parent ||
                    _currentUser.role == UserRole.student)
                ? map['is_from_school'] == true
                : map['is_from_school'] == false;
            if (isIncoming) {
              newestIncomingId = map['id'] as int?;
              newestIncomingMsg = map;
              break;
            }
          }

          if (mounted) {
            setState(() {
              _unreadMessagesCount = unread;
            });
          }

          if (isInitial) {
            _lastNotifiedMessageId = newestIncomingId ?? 0;
          } else if (newestIncomingId != null &&
              _lastNotifiedMessageId != null &&
              newestIncomingId > _lastNotifiedMessageId!) {
            _lastNotifiedMessageId = newestIncomingId;
            if (mounted && newestIncomingMsg != null) {
              _triggerInstantNotificationBanner(newestIncomingMsg);
            }
          }
        }
      }
    } catch (_) {}
  }

  void _triggerInstantNotificationBanner(Map<String, dynamic> msg) {
    SystemSound.play(SystemSoundType.alert);
    HapticFeedback.mediumImpact();

    final String subject = msg['subject']?.toString() ?? 'Nouveau message';
    final String body = msg['body']?.toString() ?? '';

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 90),
        duration: const Duration(seconds: 6),
        backgroundColor: const Color(0xFF260438),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppTheme.accentGold, width: 1.5),
        ),
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.accentGold.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_active_rounded,
                color: AppTheme.accentGold,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '📢 $subject',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.accentGoldLight,
                      fontWeight: FontWeight.w900,
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'LIRE',
          textColor: AppTheme.accentGold,
          onPressed: () {
            setState(() => _currentTabIndex = 3);
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _autoSyncTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkLiveRole({bool silent = false}) async {
    if (!silent) setState(() => _isSyncing = true);
    final updated = await AuthService.refreshCurrentUser();
    if (!mounted) return;
    if (!silent) setState(() => _isSyncing = false);

    if (updated == null && !AuthService.isAuthenticated) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
      return;
    }
    if (updated != null && (updated.role != _currentUser.role || updated.name != _currentUser.name)) {
      setState(() {
        _currentUser = updated;
      });
    }
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
        return AdminDashboard(
          key: ValueKey('admin_${_currentUser.id}'),
          user: _currentUser,
        );
      case UserRole.teacher:
        return TeacherDashboard(
          key: ValueKey('teacher_${_currentUser.id}'),
          user: _currentUser,
        );
      case UserRole.parent:
        return ParentDashboard(
          key: ValueKey('parent_${_currentUser.id}'),
          user: _currentUser,
        );
      case UserRole.student:
        return StudentDashboard(
          key: ValueKey('student_${_currentUser.id}'),
          user: _currentUser,
        );
      default:
        return Center(child: Text('Bienvenue, ${_currentUser.name} !'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      appBar: _currentTabIndex == 0
          ? AppBar(
              backgroundColor: AppTheme.accentGold,
              foregroundColor: AppTheme.primaryPurple,
              elevation: 1,
              title: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 1.5,
                      ),
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/logo_roi.jpeg',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(
                              Icons.school,
                              size: 18,
                              color: AppTheme.primaryPurple,
                            ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'CSP LES ROIS DU SAHEL',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          color: AppTheme.primaryPurple,
                          letterSpacing: 0.4,
                        ),
                      ),
                      Text(
                        _currentUser.role.label,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                          color: AppTheme.primaryPurple.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.notifications_none_rounded,
                        color: AppTheme.primaryPurple,
                      ),
                      tooltip: 'Notifications & Alertes',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => (_currentUser.role == UserRole.parent ||
                                    _currentUser.role == UserRole.student)
                                ? const ParentNotificationsScreen()
                                : const MessagesScreen(),
                          ),
                        );
                      },
                    ),
                    if (_unreadMessagesCount > 0)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.shade700,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white, width: 1.2),
                          ),
                          child: Text(
                            _unreadMessagesCount > 99
                                ? '99+'
                                : '$_unreadMessagesCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            )
          : null,

      drawer: Drawer(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  // En-tête officiel personnalisé
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 44, 16, 20),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF26023F), AppTheme.primaryPurple],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 58,
                              height: 58,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                border: Border.all(
                                  color: AppTheme.accentGold,
                                  width: 2.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.25),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: Image.asset(
                                  'assets/images/logo_roi.jpeg',
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.school,
                                    color: AppTheme.primaryPurple,
                                    size: 30,
                                  ),
                                ),
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.accentGold.withValues(
                                  alpha: 0.2,
                                ),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: AppTheme.accentGold,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.verified,
                                    size: 12,
                                    color: AppTheme.accentGoldLight,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _currentUser.role.label,
                                    style: const TextStyle(
                                      color: AppTheme.accentGoldLight,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          _currentUser.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _currentUser.email.isNotEmpty
                              ? _currentUser.email
                              : (_currentUser.phone ?? ''),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Section 1: Navigation principale
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 6),
                    child: Text(
                      'NAVIGATION PRINCIPALE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.textMuted,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),

                  ListTile(
                    leading: const Icon(
                      Icons.dashboard_rounded,
                      color: AppTheme.primaryPurple,
                    ),
                    title: const Text(
                      'Tableau de bord',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    selected: _currentTabIndex == 0,
                    selectedTileColor: AppTheme.primaryPurple.withValues(
                      alpha: 0.08,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _currentTabIndex = 0);
                    },
                  ),

                  ListTile(
                    leading: const Icon(
                      Icons.calendar_today_rounded,
                      color: Colors.blue,
                    ),
                    title: const Text(
                      'Emplois du temps & Horaires',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    selected: _currentTabIndex == 1,
                    selectedTileColor: AppTheme.primaryPurple.withValues(
                      alpha: 0.08,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _currentTabIndex = 1);
                    },
                  ),

                  ListTile(
                    leading: const Icon(
                      Icons.assignment_turned_in_rounded,
                      color: Colors.indigo,
                    ),
                    title: const Text(
                      'Notes & Bulletins scolaires',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    selected: _currentTabIndex == 2,
                    selectedTileColor: AppTheme.primaryPurple.withValues(
                      alpha: 0.08,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _currentTabIndex = 2);
                    },
                  ),

                  // Modules spécifiques aux permissions
                  if (_currentUser.role == UserRole.admin ||
                      _currentUser.role == UserRole.teacher) ...[
                    ListTile(
                      leading: const Icon(
                        Icons.checklist_rtl_rounded,
                        color: Color(0xFF10B981),
                      ),
                      title: const Text(
                        'Feuille d\'appel & Présences',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AttendanceScreen(),
                          ),
                        );
                      },
                    ),
                    ListTile(
                      leading: const Icon(
                        Icons.edit_note_rounded,
                        color: Colors.deepPurple,
                      ),
                      title: const Text(
                        'Saisie des Évaluations',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const GradeEntryScreen(),
                          ),
                        );
                      },
                    ),
                  ],

                  if (_currentUser.role == UserRole.admin ||
                      _currentUser.role == UserRole.parent ||
                      _currentUser.role == UserRole.student)
                    ListTile(
                      leading: const Icon(
                        Icons.receipt_long_rounded,
                        color: AppTheme.accentGoldDark,
                      ),
                      title: const Text(
                        'Finances & Scolarité',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const FinancesScreen(),
                          ),
                        );
                      },
                    ),

                  ListTile(
                    leading: const Icon(
                      Icons.forum_rounded,
                      color: AppTheme.primaryPurple,
                    ),
                    title: const Text(
                      'Discussion (Messagerie)',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    selected: _currentTabIndex == 3,
                    selectedTileColor: AppTheme.primaryPurple.withValues(
                      alpha: 0.08,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _currentTabIndex = 3);
                    },
                  ),

                  ListTile(
                    leading: const Icon(
                      Icons.settings_outlined,
                      color: Colors.blueGrey,
                    ),
                    title: const Text(
                      'Mon Profil & Réglages',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => Scaffold(
                            body: ProfileScreen(user: _currentUser),
                          ),
                        ),
                      );
                    },
                  ),

                  const Divider(height: 24),

                  // Section 2: Contact & Assistance
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 4, 16, 6),
                    child: Text(
                      'ASSISTANCE & CONTACT',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.textMuted,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),

                  ListTile(
                    dense: true,
                    leading: const Icon(
                      Icons.forum_rounded,
                      color: AppTheme.primaryPurple,
                    ),
                    title: const Text(
                      'Messagerie Interne',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    subtitle: const Text(
                      'Échanges directs avec l\'administration',
                      style: TextStyle(fontSize: 11),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _currentTabIndex = 3);
                    },
                  ),
                  ListTile(
                    dense: true,
                    leading: const Icon(
                      Icons.phone_in_talk,
                      color: AppTheme.primaryPurple,
                    ),
                    title: const Text(
                      'Appeler l\'établissement',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    subtitle: const Text(
                      '+227 90 00 11 22',
                      style: TextStyle(fontSize: 11),
                    ),
                    onTap: () => ContactService.callSchool(),
                  ),
                ],
              ),
            ),

            // Pied de Sidebar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border(top: BorderSide(color: AppTheme.borderLight)),
              ),
              child: Material(
                color: Colors.transparent,
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.logout,
                          color: Colors.red,
                          size: 20,
                        ),
                      ),
                      title: const Text(
                        'Se déconnecter',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      subtitle: const Text(
                        'Fermer la session actuelle',
                        style: TextStyle(fontSize: 11),
                      ),
                      onTap: _handleLogout,
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'CSP Les Rois du Sahel • Niamey, Niger\nVersion 1.1',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        color: AppTheme.textMuted,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),

      body: IndexedStack(
        index: _currentTabIndex,
        children: [
          _buildRoleDashboard(),
          SchedulesScreen(
            key: ValueKey('sched_${_currentUser.id}'),
            user: _currentUser,
          ),
          GradesScreen(
            key: ValueKey('grades_${_currentUser.id}'),
            user: _currentUser,
          ),
          MessagesScreen(
            key: ValueKey('msg_${_currentUser.id}'),
            user: _currentUser,
          ),
        ],
      ),

      extendBody: true,
      bottomNavigationBar: CurvedFloatingNavBar(
        currentIndex: _currentTabIndex,
        onTap: (index) => setState(() => _currentTabIndex = index),
        items: [
          const CurvedNavItem(
            icon: Icons.home_rounded,
            label: 'Accueil',
          ),
          const CurvedNavItem(
            icon: Icons.access_time_rounded,
            label: 'Horaires',
          ),
          const CurvedNavItem(
            icon: Icons.pie_chart_outline_rounded,
            label: 'Notes',
          ),
          CurvedNavItem(
            icon: Icons.forum_rounded,
            label: 'Discussion',
            badgeCount: _unreadMessagesCount,
          ),
        ],
      ),
    );
  }
}
