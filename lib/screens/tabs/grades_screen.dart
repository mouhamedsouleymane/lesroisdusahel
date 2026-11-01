import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';
import '../features/report_cards_screen.dart';

class GradesScreen extends StatefulWidget {
  final UserModel user;
  final int? initialStudentId;

  const GradesScreen({
    super.key,
    required this.user,
    this.initialStudentId,
  });

  @override
  State<GradesScreen> createState() => _GradesScreenState();
}

class _GradesScreenState extends State<GradesScreen> {
  bool _isLoading = false;
  Timer? _syncTimer;
  int? _selectedStudentId;
  double? _generalAverage;
  List<Map<String, dynamic>> _children = [];
  List<Map<String, dynamic>> _subjectAverages = [];
  List<Map<String, dynamic>> _evaluations = [];

  @override
  void initState() {
    super.initState();
    _selectedStudentId = widget.initialStudentId;
    _fetchGrades(isInitial: true);
    // Synchronisation automatique toutes les 10 secondes
    _syncTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) _fetchGrades(isInitial: false);
    });
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchGrades({bool isInitial = false}) async {
    if (isInitial) setState(() => _isLoading = true);
    try {
      final endpoint = _selectedStudentId != null
          ? '/grades?student_id=$_selectedStudentId'
          : '/grades';
      final response = await ApiService.get(endpoint);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final list = (data['evaluations'] as List<dynamic>?) ?? [];
          final childrenList = data['children'] as List<dynamic>?;
          final subjectsList = (data['subject_averages'] as List<dynamic>?) ?? [];
          final avgNum = (data['general_average'] as num?)?.toDouble();

          if (mounted) {
            setState(() {
              if (childrenList != null) {
                _children = childrenList.map((c) => {
                  'id': c['id'] as int?,
                  'name': c['name']?.toString() ?? 'Élève',
                  'first_name': c['first_name']?.toString() ?? c['name']?.toString() ?? 'Élève',
                  'class': c['class']?.toString() ?? '',
                  'cycle': c['cycle']?.toString() ?? '',
                }).toList();

                // Si parent et aucun enfant sélectionné au départ, sélectionner le 1er enfant pour un affichage clair
                if (_selectedStudentId == null && _children.isNotEmpty) {
                  _selectedStudentId = _children.first['id'] as int?;
                  _fetchGrades(isInitial: false);
                  return;
                }
              }

              _generalAverage = avgNum;
              _subjectAverages = subjectsList.map((s) => {
                'subject': s['subject']?.toString() ?? 'Matière',
                'average': (s['average'] as num?)?.toDouble() ?? 0.0,
                'ratio': (s['ratio'] as num?)?.toDouble() ?? 0.0,
              }).toList();

              _evaluations = list.map((e) {
                final scoreVal = e['score'] != null ? '${e['score']}' : null;
                return {
                  'title': e['title'] ?? 'Évaluation',
                  'subject': e['subject'] ?? 'Matière',
                  'class': e['class'] ?? 'Classe',
                  'period': e['period'] ?? '1er Trimestre',
                  'date': e['date'] ?? '',
                  'max_score': e['max_score'] ?? 20,
                  'score': scoreVal ?? '-',
                  'student_id': e['student_id'],
                  'student_name': e['student_name']?.toString(),
                  'is_absent': e['is_absent'] == true,
                };
              }).toList();
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

  void _onSelectChild(int? studentId) {
    setState(() {
      _selectedStudentId = studentId;
    });
    _fetchGrades(isInitial: true);
  }

  String _getAppreciationLabel(double? avg) {
    if (avg == null) return 'En cours';
    if (avg >= 16) return 'Très Bien';
    if (avg >= 14) return 'Bien';
    if (avg >= 12) return 'Assez Bien';
    if (avg >= 10) return 'Passable';
    return 'Effort requis';
  }

  String _getTeacherRemark(double? avg) {
    if (avg == null) {
      return '« Les appréciations du conseil de classe apparaîtront dès la saisie complète des notes. »';
    }
    if (avg >= 14) {
      return '« Élève sérieux(se) et appliqué(e). Très bons résultats d\'ensemble, continuez ainsi ! »';
    }
    if (avg >= 12) {
      return '« Ensemble satisfaisant et régulier. Poursuivez vos efforts pour viser l\'excellence. »';
    }
    if (avg >= 10) {
      return '« Résultats convenables mais perfectibles. Plus de régularité dans le travail personnel est attendue. »';
    }
    return '« Des difficultés constatées ce trimestre. Un suivi soutenu et davantage de concentration sont nécessaires. »';
  }

  @override
  Widget build(BuildContext context) {
    final selectedChild = _selectedStudentId != null
        ? _children.where((c) => c['id'] == _selectedStudentId).firstOrNull
        : null;

    final String formattedAvg = _generalAverage != null
        ? _generalAverage!.toStringAsFixed(2).replaceAll('.', ',')
        : '--,--';

    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Notes & résultats',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppTheme.primaryPurple),
            ),
            if (selectedChild != null)
              Text(
                '${selectedChild['name']} - ${selectedChild['class']}',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppTheme.primaryPurple.withValues(alpha: 0.85)),
              ),
          ],
        ),
        backgroundColor: AppTheme.accentGold,
        foregroundColor: AppTheme.primaryPurple,
        elevation: 1,
      ),
      body: RefreshIndicator(
        color: AppTheme.primaryPurple,
        onRefresh: _fetchGrades,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 105),
          children: [
            // Sélecteur d'enfant si le parent a plusieurs enfants
            if (_children.length > 1) ...[
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  children: _children.map((c) {
                    final int? id = c['id'] as int?;
                    final String firstName = c['first_name'] ?? 'Élève';
                    final String className = c['class'] ?? '';
                    final bool isSelected = _selectedStudentId == id;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _StudentChip(
                        label: className.isNotEmpty ? '$firstName · $className' : firstName,
                        isSelected: isSelected,
                        onTap: () => _onSelectChild(id),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],

            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(color: AppTheme.primaryPurple),
                ),
              )
            else ...[
              // 1. CARTE MOYENNE GÉNÉRALE + ÉVOLUTION (Style Maquette Image 2)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.borderLight),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Moyenne générale',
                          style: TextStyle(fontSize: 12, color: AppTheme.textMuted, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              formattedAvg,
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF059669),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              '/20',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD1FAE5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _getAppreciationLabel(_generalAverage),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF059669),
                            ),
                          ),
                        ),
                      ],
                    ),
                    // Mini graphique d'évolution à 4 barres (Style Maquette Image 2)
                    Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _EvolutionBar(height: 24, isActive: false),
                            const SizedBox(width: 6),
                            _EvolutionBar(height: 36, isActive: false),
                            const SizedBox(width: 6),
                            _EvolutionBar(height: 46, isActive: false),
                            const SizedBox(width: 6),
                            _EvolutionBar(
                              height: _generalAverage != null
                                  ? (_generalAverage! / 20.0 * 64).clamp(18.0, 64.0)
                                  : 56,
                              isActive: true,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Évolution',
                          style: TextStyle(fontSize: 10, color: AppTheme.textMuted, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 2. SECTION "PAR MATIÈRE" AVEC BARRES DE PROGRESSION (Style Maquette Image 2)
              if (_subjectAverages.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.borderLight),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Par matière',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppTheme.textDark),
                      ),
                      const SizedBox(height: 14),
                      ..._subjectAverages.map((sub) {
                        final String subjectName = sub['subject'] ?? 'Matière';
                        final double avg = (sub['average'] as double?) ?? 0.0;
                        final double ratio = (sub['ratio'] as double?) ?? 0.0;
                        final Color barColor = avg >= 14
                            ? const Color(0xFF10B981)
                            : (avg >= 10 ? AppTheme.primaryPurple : AppTheme.accentGoldDark);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 4,
                                child: Text(
                                  subjectName,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textDark,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 5,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: LinearProgressIndicator(
                                    value: ratio,
                                    minHeight: 8,
                                    backgroundColor: const Color(0xFFE2E8F0),
                                    valueColor: AlwaysStoppedAnimation<Color>(barColor),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 36,
                                child: Text(
                                  avg.toStringAsFixed(1).replaceAll('.', ','),
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    color: AppTheme.textDark,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // 3. ENCADRÉ APPRÉCIATION DU PROFESSEUR PRINCIPAL (Style Maquette Image 2)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Appréciation du professeur principal',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppTheme.textMuted),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _getTeacherRemark(_generalAverage),
                      style: const TextStyle(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryPurple,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 4. BOUTON PLEINE LARGEUR "VOIR LE BULLETIN" (Style Maquette Image 2)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ReportCardsScreen(
                        initialStudentId: _selectedStudentId,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.description_outlined, size: 18),
                  label: const Text(
                    'Voir le bulletin du Semestre / Trimestre',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),

              const SizedBox(height: 22),

              // 5. HISTORIQUE DÉTAILLÉ DES DEVOIRS & COMPOSITIONS
              const Text(
                'Historique des évaluations',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppTheme.textDark),
              ),
              const SizedBox(height: 10),

              if (_evaluations.isNotEmpty)
                ..._evaluations.map((ev) => _EvaluationCard(
                      title: ev['title'],
                      subject: ev['subject'],
                      date: ev['date'],
                      score: '${ev['score']} / ${ev['max_score']}',
                      schoolClass: ev['class'],
                      studentName: ev['student_name'],
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
                  child: const Text(
                    'Aucune note enregistrée pour cet élève.',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EvolutionBar extends StatelessWidget {
  final double height;
  final bool isActive;

  const _EvolutionBar({required this.height, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: height,
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class _StudentChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _StudentChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
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
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: isSelected ? AppTheme.accentGold : AppTheme.textDark,
          ),
        ),
      ),
    );
  }
}

class _EvaluationCard extends StatelessWidget {
  final String title;
  final String subject;
  final String date;
  final String score;
  final String schoolClass;
  final String? studentName;

  const _EvaluationCard({
    required this.title,
    required this.subject,
    required this.date,
    required this.score,
    required this.schoolClass,
    this.studentName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.accentGold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.assignment_turned_in, color: AppTheme.accentGoldDark, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(subject, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textDark)),
                const SizedBox(height: 2),
                Text('$title · $date', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              score,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFF10B981)),
            ),
          ),
        ],
      ),
    );
  }
}
