import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';
import '../features/messages_screen.dart';
import '../features/report_cards_screen.dart';
import '../tabs/schedules_screen.dart';

class StudentDashboard extends StatefulWidget {
  final UserModel user;
  const StudentDashboard({super.key, required this.user});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  bool _isLoading = false;
  Timer? _syncTimer;
  String _className = '-';
  String _average = '-';
  String _rank = '-';
  String _attendance = '-';
  List<Map<String, dynamic>> _grades = [];

  @override
  void initState() {
    super.initState();
    _fetchStudentData(isInitial: true);
    // Synchronisation automatique toutes les 10 secondes
    _syncTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) _fetchStudentData(isInitial: false);
    });
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchStudentData({bool isInitial = false}) async {
    if (isInitial) setState(() => _isLoading = true);
    try {
      final response = await ApiService.get('/dashboard');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final student = data['student'];
          final stats = data['stats'];
          if (mounted) {
            setState(() {
              if (student != null) {
                _className = student['class'] ?? _className;
              }
              if (stats != null) {
                _average = stats['average'] ?? _average;
                _rank = stats['rank'] != null ? '${stats['rank']} de la classe' : '-';
                _attendance = stats['attendance_rate'] ?? _attendance;
              }
            });
          }
        }
      }

      // Récupérer également les notes réelles
      final gradesRes = await ApiService.get('/grades');
      if (gradesRes.statusCode == 200) {
        final gData = jsonDecode(gradesRes.body);
        if (gData['success'] == true && gData['evaluations'] != null) {
          final list = gData['evaluations'] as List<dynamic>;
          if (mounted) {
            setState(() {
              _grades = list.map((g) {
                final scoreVal = (g['score'] as num?)?.toDouble();
                final maxScore = g['max_score'] ?? 20;
                return {
                  'subject': g['subject'] ?? 'Matière',
                  'type': '${g['title'] ?? "Évaluation"} (${g['period'] ?? ""})',
                  'score': scoreVal != null ? '$scoreVal / $maxScore' : '- / $maxScore',
                  'coeff': 'Coeff ${g['coefficient'] ?? 1}',
                  'isGood': scoreVal != null ? scoreVal >= 10 : true,
                };
              }).toList();
            });
          }
        }
      }
    } catch (_) {
      // Erreur API
    } finally {
      if (isInitial && mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppTheme.primaryPurple,
      onRefresh: _fetchStudentData,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          // Carte Élève
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F172A), AppTheme.primaryPurple],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.accentGold.withValues(alpha: 0.2),
                  radius: 26,
                  child: const Icon(Icons.school, color: AppTheme.accentGold, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: AppTheme.accentGold, borderRadius: BorderRadius.circular(6)),
                        child: const Text('ESPACE ÉLÈVE', style: TextStyle(color: Colors.black87, fontSize: 9, fontWeight: FontWeight.w900)),
                      ),
                      const SizedBox(height: 4),
                      Text(widget.user.name, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                      Text('Matricule : ${widget.user.matricule ?? "2025-00862"} · $_className', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    ],
                  ),
                ),
                if (_isLoading)
                  const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentGold)),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Résumé académique
          Row(
            children: [
              Expanded(
                child: _AcademicBox(title: 'Moyenne Actuelle', value: _average, color: AppTheme.primaryPurple, subtitle: _rank),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _AcademicBox(title: 'Assiduité', value: _attendance, color: const Color(0xFF10B981), subtitle: '0 absence non justifiée'),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Dernières notes obtenues
          const Text(
            'Dernières notes enregistrées',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 12),

          if (_grades.isNotEmpty)
            ..._grades.take(6).map((g) => _GradeRow(
              subject: g['subject'],
              type: g['type'],
              score: g['score'],
              coeff: g['coeff'],
              isGood: g['isGood'],
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
                  Icon(Icons.assignment_outlined, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  const Text(
                    'Aucune note enregistrée',
                    style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textMuted, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Vos notes officielles saisies par vos professeurs apparaîtront ici.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // Raccourci Emploi du Temps & Bulletins
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ReportCardsScreen()),
                  ),
                  icon: const Icon(Icons.description_outlined, color: Colors.white, size: 18),
                  label: const Text('Mes Bulletins', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MessagesScreen()),
                  ),
                  icon: const Icon(Icons.forum_outlined, color: Colors.white, size: 18),
                  label: const Text('Messagerie', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryPurple,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Raccourci Emploi du Temps
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.accentGold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.accentGold.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.schedule, color: AppTheme.primaryPurple, size: 28),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Emploi du temps de la classe', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textDark)),
                      Text('Consulter le planning complet par jour et matière', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => SchedulesScreen(user: widget.user)),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryPurple,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Voir', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AcademicBox extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final String subtitle;

  const _AcademicBox({required this.title, required this.value, required this.color, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textMuted)),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
        ],
      ),
    );
  }
}

class _GradeRow extends StatelessWidget {
  final String subject;
  final String type;
  final String score;
  final String coeff;
  final bool isGood;

  const _GradeRow({required this.subject, required this.type, required this.score, required this.coeff, required this.isGood});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(subject, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textDark)),
                Text('$type · $coeff', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isGood ? const Color(0xFF10B981).withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              score,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 13,
                color: isGood ? const Color(0xFF10B981) : Colors.red.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
