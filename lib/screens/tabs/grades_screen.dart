import 'dart:convert';
import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';
import '../../services/contact_service.dart';

class GradesScreen extends StatefulWidget {
  final UserModel user;
  const GradesScreen({super.key, required this.user});

  @override
  State<GradesScreen> createState() => _GradesScreenState();
}

class _GradesScreenState extends State<GradesScreen> {
  bool _isLoading = false;
  String _selectedPeriod = '1er Trimestre';
  List<Map<String, dynamic>> _evaluations = [];

  @override
  void initState() {
    super.initState();
    _fetchGrades();
  }

  Future<void> _fetchGrades() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiService.get('/grades');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['evaluations'] != null) {
          final list = data['evaluations'] as List<dynamic>;
          setState(() {
            _evaluations = list.map((e) => {
              'title': e['title'] ?? 'Évaluation',
              'subject': e['subject'] ?? 'Matière',
              'class': e['class'] ?? 'Classe',
              'period': e['period'] ?? '1er Trimestre',
              'date': e['date'] ?? '29/10/2026',
              'max_score': e['max_score'] ?? 20,
              'score': '16.5',
            }).toList();
          });
        }
      }
    } catch (_) {
      // Données locales
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      appBar: AppBar(
        title: const Text('Notes & Bulletins Scolaires', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textDark,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchGrades,
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.primaryPurple,
        onRefresh: _fetchGrades,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Bannière Bulletins PDF
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primaryPurple, Color(0xFF581C87)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryPurple.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.accentGold.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.picture_as_pdf, color: AppTheme.accentGold, size: 28),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Bulletin Officiel PDF', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                        SizedBox(height: 2),
                        Text('Télécharger le bulletin trimestriel certifié', style: TextStyle(color: Colors.white70, fontSize: 11)),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      ContactService.openSchoolPortal();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentGold,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Ouvrir', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Sélecteur de période
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Détail des évaluations', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppTheme.textDark)),
                DropdownButton<String>(
                  value: _selectedPeriod,
                  underline: const SizedBox(),
                  icon: const Icon(Icons.keyboard_arrow_down, color: AppTheme.primaryPurple),
                  items: const [
                    DropdownMenuItem(value: '1er Trimestre', child: Text('1er Trimestre', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
                    DropdownMenuItem(value: '2ème Trimestre', child: Text('2ème Trimestre', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
                    DropdownMenuItem(value: '3ème Trimestre', child: Text('3ème Trimestre', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedPeriod = val);
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (_isLoading)
              const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: AppTheme.primaryPurple)))
            else if (_evaluations.isNotEmpty)
              ..._evaluations.map((ev) => _EvaluationCard(
                title: ev['title'],
                subject: ev['subject'],
                date: ev['date'],
                score: '${ev['score']} / ${ev['max_score']}',
                schoolClass: ev['class'],
              ))
            else ...const [
              _EvaluationCard(title: 'Devoir Surveillé N°1', subject: 'Mathématiques', date: '24/10/2026', score: '17.5 / 20', schoolClass: '6ème A'),
              _EvaluationCard(title: 'Composition Trimestrielle', subject: 'Français', date: '22/10/2026', score: '14.0 / 20', schoolClass: '6ème A'),
              _EvaluationCard(title: 'Contrôle Continu N°2', subject: 'Physique - Chimie', date: '19/10/2026', score: '16.0 / 20', schoolClass: '6ème A'),
              _EvaluationCard(title: 'Devoir de Synthèse', subject: 'Histoire - Géographie', date: '15/10/2026', score: '13.5 / 20', schoolClass: '6ème A'),
              _EvaluationCard(title: 'Interrogation Écrite', subject: 'Anglais', date: '12/10/2026', score: '15.0 / 20', schoolClass: '6ème A'),
            ],
          ],
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

  const _EvaluationCard({
    required this.title,
    required this.subject,
    required this.date,
    required this.score,
    required this.schoolClass,
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

