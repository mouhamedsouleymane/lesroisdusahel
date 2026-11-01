import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../services/api_service.dart';
import 'messages_screen.dart';

class ChildAttendanceScreen extends StatefulWidget {
  final int? initialStudentId;

  const ChildAttendanceScreen({
    super.key,
    this.initialStudentId,
  });

  @override
  State<ChildAttendanceScreen> createState() => _ChildAttendanceScreenState();
}

class _ChildAttendanceScreenState extends State<ChildAttendanceScreen> {
  bool _isLoading = true;
  Timer? _syncTimer;
  int? _selectedStudentId;
  List<Map<String, dynamic>> _children = [];
  Map<String, dynamic> _summary = {};
  List<Map<String, dynamic>> _attendances = [];

  @override
  void initState() {
    super.initState();
    _selectedStudentId = widget.initialStudentId;
    _fetchAttendances(isInitial: true);
    // Synchronisation automatique toutes les 10 secondes
    _syncTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) _fetchAttendances(isInitial: false);
    });
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchAttendances({bool isInitial = false}) async {
    if (isInitial) setState(() => _isLoading = true);
    try {
      final endpoint = _selectedStudentId != null
          ? '/student-attendances?student_id=$_selectedStudentId'
          : '/student-attendances';
      final res = await ApiService.get(endpoint);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) {
          final childrenList = (data['children'] as List<dynamic>?) ?? [];
          final attList = (data['attendances'] as List<dynamic>?) ?? [];

          if (mounted) {
            setState(() {
              _children = childrenList.map((c) => Map<String, dynamic>.from(c as Map)).toList();
              if (_selectedStudentId == null && _children.isNotEmpty) {
                _selectedStudentId = _children.first['id'] as int?;
                _fetchAttendances(isInitial: false);
                return;
              }
              _summary = Map<String, dynamic>.from((data['summary'] as Map?) ?? {});
              _attendances = attList.map((a) => Map<String, dynamic>.from(a as Map)).toList();
              _isLoading = false;
            });
          }
          return;
        }
      }
    } catch (_) {
      // Erreur réseau
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedChild = _selectedStudentId != null
        ? _children.where((c) => c['id'] == _selectedStudentId).firstOrNull
        : null;

    final bool presentToday = _summary['present_today'] != false;
    final int absencesCount = (_summary['absences_count'] as num?)?.toInt() ?? 0;
    final int latesCount = (_summary['lates_count'] as num?)?.toInt() ?? 0;
    final int justifiedCount = (_summary['justified_count'] as num?)?.toInt() ?? 0;

    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Présences & Absences',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppTheme.primaryPurple),
            ),
            if (selectedChild != null)
              Text(
                '${selectedChild['name']} · ${selectedChild['class']}',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppTheme.primaryPurple.withValues(alpha: 0.85)),
              ),
          ],
        ),
        backgroundColor: AppTheme.accentGold,
        foregroundColor: AppTheme.primaryPurple,
        elevation: 1,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryPurple))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 105),
              children: [
                // Sélecteur d'enfant
                if (_children.length > 1) ...[
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Row(
                      children: _children.map((c) {
                        final int? id = c['id'] as int?;
                        final String firstName = c['first_name']?.toString() ?? 'Élève';
                        final String className = c['class']?.toString() ?? '';
                        final bool isSelected = _selectedStudentId == id;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () {
                              setState(() => _selectedStudentId = id);
                              _fetchAttendances(isInitial: true);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? AppTheme.primaryPurple : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected ? AppTheme.accentGold : AppTheme.borderLight,
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: Text(
                                className.isNotEmpty ? '$firstName · $className' : firstName,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: isSelected ? AppTheme.accentGold : AppTheme.textDark,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],

                // 1. BANNIÈRE STATUT DU JOUR
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF260438), AppTheme.primaryPurple],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: (presentToday ? const Color(0xFF10B981) : Colors.red).withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          presentToday ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                          color: presentToday ? const Color(0xFF34D399) : Colors.redAccent,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              presentToday
                                  ? 'Présent(e) en classe aujourd\'hui'
                                  : 'Déclaré(e) absent(e) aujourd\'hui',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15),
                            ),
                            const SizedBox(height: 3),
                            const Text(
                              'Informé en direct dès l\'enregistrement de l\'appel',
                              style: TextStyle(color: Colors.white70, fontSize: 11.5),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // 2. COMPTEURS D'ASSIDUITÉ (Absences, Retards, Justifiées)
                Row(
                  children: [
                    Expanded(
                      child: _AttendanceCounterCard(
                        value: '$absencesCount',
                        label: 'Absence(s)',
                        bgColor: const Color(0xFFFEE2E2),
                        textColor: Colors.red.shade700,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _AttendanceCounterCard(
                        value: '$latesCount',
                        label: 'Retard(s)',
                        bgColor: const Color(0xFFFEF3C7),
                        textColor: AppTheme.accentGoldDark,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _AttendanceCounterCard(
                        value: '$justifiedCount',
                        label: 'Justifiée(s)',
                        bgColor: const Color(0xFFD1FAE5),
                        textColor: const Color(0xFF059669),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 22),

                // 3. HISTORIQUE DES APPELS
                const Text(
                  'Historique des feuilles d\'appel',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppTheme.textDark),
                ),
                const SizedBox(height: 10),

                if (_attendances.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.borderLight),
                    ),
                    child: const Text(
                      'Aucun événement d\'appel enregistré pour cet élève.',
                      style: TextStyle(fontSize: 13, color: AppTheme.textMuted, fontWeight: FontWeight.w600),
                    ),
                  )
                else
                  ..._attendances.map((att) {
                    final String status = att['status']?.toString() ?? 'PRESENT';
                    final bool isAbsent = status == 'ABSENT';
                    final bool isLate = status == 'RETARD';
                    final bool isJustified = att['is_justified'] == true;
                    final String date = att['date']?.toString() ?? '';
                    final String subject = att['subject']?.toString() ?? 'Appel général';

                    Color badgeBg = const Color(0xFFD1FAE5);
                    Color badgeText = const Color(0xFF059669);
                    if (isAbsent) {
                      badgeBg = const Color(0xFFFEE2E2);
                      badgeText = Colors.red.shade700;
                    } else if (isLate) {
                      badgeBg = const Color(0xFFFEF3C7);
                      badgeText = AppTheme.accentGoldDark;
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.borderLight),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '$date — ${att['session'] ?? "Journée"}',
                                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5, color: AppTheme.textDark),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      subject,
                                      style: const TextStyle(fontSize: 12, color: AppTheme.textMuted, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: badgeBg,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  status,
                                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: badgeText),
                                ),
                              ),
                            ],
                          ),
                          if ((att['reason']?.toString() ?? '').isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Motif : ${att['reason']}',
                              style: const TextStyle(fontSize: 11.5, color: AppTheme.primaryPurple, fontWeight: FontWeight.w600),
                            ),
                          ],
                          if ((isAbsent || isLate) && !isJustified) ...[
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => MessagesScreen(
                                      initialStudentId: _selectedStudentId,
                                      initialCategory: 'ABSENCE',
                                      initialSubject: 'Justification ${isLate ? "retard" : "absence"} du $date',
                                      openComposerOnInit: true,
                                    ),
                                  ),
                                ),
                                icon: const Icon(Icons.edit_note_rounded, size: 16, color: AppTheme.primaryPurple),
                                label: const Text(
                                  'Justifier auprès de l\'administration',
                                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppTheme.primaryPurple),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
              ],
            ),
    );
  }
}

class _AttendanceCounterCard extends StatelessWidget {
  final String value;
  final String label;
  final Color bgColor;
  final Color textColor;

  const _AttendanceCounterCard({
    required this.value,
    required this.label,
    required this.bgColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: textColor),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: textColor),
          ),
        ],
      ),
    );
  }
}

