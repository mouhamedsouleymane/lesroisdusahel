import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';
import '../features/attendance_screen.dart';
import '../features/grade_entry_screen.dart';
import '../features/messages_screen.dart';

class TeacherDashboard extends StatefulWidget {
  final UserModel user;
  const TeacherDashboard({super.key, required this.user});

  @override
  State<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard> {
  bool _isLoading = false;
  Timer? _syncTimer;
  String _speciality = 'Enseignant';
  String _matricule = '';
  int _classesCount = 0;
  int _coursesCount = 0;
  List<Map<String, dynamic>> _todayCourses = [];

  @override
  void initState() {
    super.initState();
    _fetchTeacherData(isInitial: true);
    // Synchronisation automatique toutes les 10 secondes
    _syncTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) _fetchTeacherData(isInitial: false);
    });
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchTeacherData({bool isInitial = false}) async {
    if (isInitial) setState(() => _isLoading = true);
    try {
      final response = await ApiService.get('/dashboard');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final teacher = data['teacher'];
          final stats = data['stats'];
          final schedules = data['schedules'] as List<dynamic>?;

          if (mounted) {
            setState(() {
              if (teacher != null) {
                _speciality = teacher['speciality'] ?? _speciality;
                _matricule = teacher['matricule'] ?? _matricule;
              }
              if (stats != null) {
                _classesCount = stats['classes_count'] ?? _classesCount;
                _coursesCount = stats['courses_count'] ?? _coursesCount;
              }
              if (schedules != null && schedules.isNotEmpty) {
                _todayCourses = schedules.map((s) => {
                  'time': s['time']?.toString() ?? '08:00 - 10:00',
                  'subject': s['subject']?.toString() ?? 'Matière',
                  'class': s['class']?.toString() ?? 'Classe',
                  'room': s['room']?.toString() ?? 'Salle',
                  'isCurrent': false,
                }).toList();
              }
            });
          }
        }
      }
    } catch (_) {
      // Données indisponibles
    } finally {
      if (isInitial && mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppTheme.primaryPurple,
      onRefresh: _fetchTeacherData,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          // En-tête Enseignant
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E1B4B), AppTheme.primaryPurpleLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.accentGold.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'ESPACE ENSEIGNANT',
                        style: TextStyle(color: AppTheme.accentGoldLight, fontSize: 10, fontWeight: FontWeight.w900),
                      ),
                    ),
                    Text(
                      widget.user.matricule ?? _matricule,
                      style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  widget.user.name,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(_speciality, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Résumé des affectations
          Row(
            children: [
              Expanded(
                child: _MetricBadge(
                  icon: Icons.meeting_room_rounded,
                  label: 'Classes',
                  value: '$_classesCount classes',
                  color: AppTheme.primaryPurple,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricBadge(
                  icon: Icons.menu_book_rounded,
                  label: 'Charges',
                  value: '$_coursesCount cours/sem',
                  color: AppTheme.accentGoldDark,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Actions rapides
          const Text('Actions rapides', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppTheme.textDark)),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _QuickButton(
                  icon: Icons.checklist_rtl,
                  label: 'Faire l\'appel',
                  color: Colors.blue.shade700,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceScreen())),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickButton(
                  icon: Icons.edit_note,
                  label: 'Saisir des notes',
                  color: AppTheme.primaryPurple,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GradeEntryScreen())),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickButton(
                  icon: Icons.forum_outlined,
                  label: 'Messagerie',
                  color: const Color(0xFF10B981),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MessagesScreen())),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Emploi du temps
          const Text(
            'Cours programmés',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 12),

          if (_todayCourses.isNotEmpty)
            ..._todayCourses.map((c) => _CourseCard(
              time: c['time'] ?? '08:00 - 10:00',
              subject: c['subject'] ?? 'Matière',
              schoolClass: c['class'] ?? 'Classe',
              room: c['room'] ?? 'Salle',
              isCurrent: c['isCurrent'] == true,
            ))
          else
            Container(
              padding: const EdgeInsets.all(24),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderLight),
              ),
              child: Column(
                children: [
                  Icon(Icons.event_available, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  const Text(
                    'Aucun cours programmé aujourd\'hui',
                    style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textMuted, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Consultez l\'onglet "Horaires" pour voir l\'ensemble de votre emploi du temps hebdomadaire.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MetricBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MetricBadge({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickButton({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: color)),
          ],
        ),
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  final String time;
  final String subject;
  final String schoolClass;
  final String room;
  final bool isCurrent;

  const _CourseCard({required this.time, required this.subject, required this.schoolClass, required this.room, required this.isCurrent});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isCurrent ? AppTheme.primaryPurple.withValues(alpha: 0.04) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isCurrent ? AppTheme.primaryPurple : AppTheme.borderLight, width: isCurrent ? 1.5 : 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isCurrent ? AppTheme.primaryPurple : AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              time,
              style: TextStyle(
                color: isCurrent ? Colors.white : AppTheme.textDark,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(subject, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textDark)),
                const SizedBox(height: 2),
                Text('$schoolClass · $room', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
              ],
            ),
          ),
          if (isCurrent)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: AppTheme.accentGold, borderRadius: BorderRadius.circular(6)),
              child: const Text('En cours', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87)),
            ),
        ],
      ),
    );
  }
}
