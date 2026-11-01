import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../services/api_service.dart';
import '../../services/contact_service.dart';

class ReportCardsScreen extends StatefulWidget {
  final int? initialStudentId;

  const ReportCardsScreen({
    super.key,
    this.initialStudentId,
  });

  @override
  State<ReportCardsScreen> createState() => _ReportCardsScreenState();
}

class _ReportCardsScreenState extends State<ReportCardsScreen> {
  bool _isLoading = true;
  Timer? _syncTimer;
  int? _selectedStudentId;
  int _selectedCardIndex = 0;
  List<Map<String, dynamic>> _children = [];
  List<Map<String, dynamic>> _reportCards = [];

  @override
  void initState() {
    super.initState();
    _selectedStudentId = widget.initialStudentId;
    _fetchReportCards(isInitial: true);
    // Synchronisation automatique toutes les 10 secondes
    _syncTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) _fetchReportCards(isInitial: false);
    });
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchReportCards({bool isInitial = false}) async {
    if (isInitial) setState(() => _isLoading = true);
    try {
      final endpoint = _selectedStudentId != null
          ? '/report-cards?student_id=$_selectedStudentId'
          : '/report-cards';
      final res = await ApiService.get(endpoint);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) {
          final childrenList = (data['children'] as List<dynamic>?) ?? [];
          final cardsList = (data['report_cards'] as List<dynamic>?) ?? [];

          if (mounted) {
            setState(() {
              _children = childrenList.map((c) => Map<String, dynamic>.from(c as Map)).toList();
              if (_selectedStudentId == null && _children.isNotEmpty) {
                _selectedStudentId = _children.first['id'] as int?;
                _fetchReportCards(isInitial: false);
                return;
              }
              _reportCards = cardsList.map((rc) => Map<String, dynamic>.from(rc as Map)).toList();
              if (_selectedCardIndex >= _reportCards.length) {
                _selectedCardIndex = 0;
              }
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

    final activeCard = _reportCards.isNotEmpty ? _reportCards[_selectedCardIndex] : null;
    final List<dynamic> subjects = (activeCard?['subjects'] as List<dynamic>?) ?? [];

    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bulletins Scolaires',
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
                // Sélecteur d'enfant si le parent a plusieurs enfants
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
                              setState(() {
                                _selectedStudentId = id;
                                _selectedCardIndex = 0;
                              });
                              _fetchReportCards(isInitial: true);
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

                // Sélecteur de période si plusieurs bulletins pour cet enfant
                if (_reportCards.length > 1) ...[
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Row(
                      children: List.generate(_reportCards.length, (idx) {
                        final rc = _reportCards[idx];
                        final isSelected = idx == _selectedCardIndex;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(rc['period_name']?.toString() ?? 'Période'),
                            selected: isSelected,
                            selectedColor: AppTheme.accentGold,
                            labelStyle: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              color: isSelected ? AppTheme.primaryPurple : AppTheme.textDark,
                            ),
                            onSelected: (_) => setState(() => _selectedCardIndex = idx),
                          ),
                        );
                      }),
                    ),
                  ),
                ],

                if (activeCard == null)
                  Container(
                    padding: const EdgeInsets.all(28),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppTheme.borderLight),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.description_outlined, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        const Text(
                          'Aucun bulletin disponible pour le moment',
                          style: TextStyle(fontWeight: FontWeight.w800, color: AppTheme.textDark, fontSize: 14),
                        ),
                      ],
                    ),
                  )
                else ...[
                  // 1. EN-TÊTE DU BULLETIN OFFICIEL
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF260438), AppTheme.primaryPurple],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryPurple.withValues(alpha: 0.25),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
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
                                color: AppTheme.accentGold,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                (activeCard['period_name']?.toString() ?? 'BULLETIN').toUpperCase(),
                                style: const TextStyle(
                                  color: AppTheme.primaryPurple,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: activeCard['is_published'] == true
                                    ? const Color(0xFF10B981).withValues(alpha: 0.25)
                                    : Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                activeCard['is_published'] == true ? 'CERTIFIÉ OFFICIEL' : 'EN COURS',
                                style: TextStyle(
                                  color: activeCard['is_published'] == true ? const Color(0xFF34D399) : Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          activeCard['student_name']?.toString() ?? '',
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                        ),
                        Text(
                          'Matricule : ${activeCard['matricule'] ?? "-"} · Classe : ${activeCard['class_name'] ?? ""} (${activeCard['cycle'] ?? ""})',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        const Divider(color: Colors.white24, height: 26),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Moyenne Générale', style: TextStyle(color: Colors.white70, fontSize: 11)),
                                const SizedBox(height: 2),
                                Text(
                                  '${activeCard['general_average'] ?? 0} / 20',
                                  style: const TextStyle(color: AppTheme.accentGold, fontSize: 24, fontWeight: FontWeight.w900),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Text('Rang', style: TextStyle(color: Colors.white70, fontSize: 11)),
                                const SizedBox(height: 2),
                                Text(
                                  activeCard['rank'] != null
                                      ? '${activeCard['rank']} / ${activeCard['total_students'] ?? "-"}'
                                      : 'En attente',
                                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                                ),
                              ],
                            ),
                            if (activeCard['class_average'] != null)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text('Moy. Classe', style: TextStyle(color: Colors.white70, fontSize: 11)),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${activeCard['class_average']} / 20',
                                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // 2. DÉTAIL DES RÉSULTATS PAR MATIÈRE
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.borderLight),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Relevé détaillé par matière',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppTheme.textDark),
                        ),
                        const SizedBox(height: 12),
                        if (subjects.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Text(
                              'Aucune note saisie pour cette période.',
                              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                            ),
                          )
                        else
                          ...subjects.map((sub) {
                            final avg = sub['average'];
                            final double? avgNum = (avg as num?)?.toDouble();
                            final bool isGood = (avgNum ?? 0) >= 10;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceLight,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppTheme.borderLight),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          sub['subject']?.toString() ?? 'Matière',
                                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: AppTheme.textDark),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          'Coeff : ${sub['coefficient'] ?? 1} · Classe : ${sub['class_score'] ?? "-"} · Compo : ${sub['exam_score'] ?? "-"}',
                                          style: const TextStyle(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.w600),
                                        ),
                                        if ((sub['appreciation']?.toString() ?? '').isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            sub['appreciation'].toString(),
                                            style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppTheme.primaryPurple),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: isGood
                                          ? const Color(0xFFD1FAE5)
                                          : const Color(0xFFFEE2E2),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      avgNum != null ? '${avgNum.toStringAsFixed(2)} /20' : '-',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 13,
                                        color: isGood ? const Color(0xFF059669) : Colors.red.shade700,
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

                  // 3. APPRÉCIATION DU CONSEIL DE CLASSE
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
                          'Décision & Appréciation du Conseil de Classe',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppTheme.textMuted),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '« ${activeCard['appreciation'] ?? "Travail régulier."} »',
                          style: const TextStyle(
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primaryPurple,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 4. BOUTON TÉLÉCHARGER LE PDF OFFICIEL
                  if (activeCard['id'] != null)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          ContactService.openSchoolPortal(
                            path: '/report-cards/${activeCard['id']}/pdf?download=1',
                          );
                        },
                        icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                        label: const Text(
                          'Télécharger le Bulletin PDF Certifié',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                ],
              ],
            ),
    );
  }
}

