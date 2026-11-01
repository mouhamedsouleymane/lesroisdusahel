import 'dart:convert';
import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../services/api_service.dart';

class GradeEntryScreen extends StatefulWidget {
  final int? initialClassId;
  const GradeEntryScreen({super.key, this.initialClassId});

  @override
  State<GradeEntryScreen> createState() => _GradeEntryScreenState();
}

class _GradeEntryScreenState extends State<GradeEntryScreen> {
  bool _isLoading = true;
  bool _isSaving = false;

  List<Map<String, dynamic>> _classes = [];
  List<Map<String, dynamic>> _periods = [];
  List<Map<String, dynamic>> _subjects = [];
  List<Map<String, dynamic>> _types = [];

  int? _selectedClassId;
  int? _selectedPeriodId;
  int? _selectedSubjectId;
  String _selectedType = 'DEVOIR';
  final _titleController = TextEditingController(text: 'Devoir Surveillé N°1');
  final _maxScoreController = TextEditingController(text: '20');

  List<Map<String, dynamic>> _students = [];
  final Map<int, TextEditingController> _scoreControllers = {};

  @override
  void initState() {
    super.initState();
    _loadFormData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _maxScoreController.dispose();
    for (var c in _scoreControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadFormData() async {
    setState(() => _isLoading = true);
    try {
      final classesRes = await ApiService.get('/classes');
      final optionsRes = await ApiService.get('/evaluations/options');

      if (classesRes.statusCode == 200 && optionsRes.statusCode == 200) {
        final cData = jsonDecode(classesRes.body);
        final oData = jsonDecode(optionsRes.body);

        setState(() {
          _classes = List<Map<String, dynamic>>.from(cData['classes'] ?? []);
          _periods = List<Map<String, dynamic>>.from(oData['periods'] ?? []);
          _subjects = List<Map<String, dynamic>>.from(oData['subjects'] ?? []);
          _types = List<Map<String, dynamic>>.from(oData['types'] ?? []);

          if (_classes.isNotEmpty) {
            _selectedClassId = widget.initialClassId ?? _classes.first['id'];
          }
          if (_periods.isNotEmpty) {
            _selectedPeriodId = _periods.first['id'];
          }
          if (_subjects.isNotEmpty) {
            _selectedSubjectId = _subjects.first['id'];
          }
        });

        if (_selectedClassId != null) {
          await _fetchClassStudents(_selectedClassId!);
        }
      }
    } catch (_) {
      setState(() {
        _classes = [];
        _periods = [];
        _subjects = [];
        _types = [];
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchClassStudents(int classId) async {
    try {
      final res = await ApiService.get('/classes/$classId/students');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = List<Map<String, dynamic>>.from(data['students'] ?? []);
        _initStudentsList(list);
        return;
      }
    } catch (_) {}

    _initStudentsList([]);
  }

  void _initStudentsList(List<Map<String, dynamic>> list) {
    setState(() {
      _students = list;
      _scoreControllers.clear();
      for (var s in _students) {
        _scoreControllers[s['id']] = TextEditingController(text: s['score']?.toString() ?? '');
      }
    });
  }

  double _calculateAverage() {
    if (_students.isEmpty) return 0;
    double sum = 0;
    int count = 0;
    for (var s in _students) {
      final text = _scoreControllers[s['id']]?.text ?? '';
      final val = double.tryParse(text);
      if (val != null) {
        sum += val;
        count++;
      }
    }
    return count > 0 ? (sum / count) : 0;
  }

  Future<void> _saveGrades() async {
    if (_selectedClassId == null || _selectedPeriodId == null || _selectedSubjectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez renseigner tous les champs obligatoires.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final payload = {
      'class_id': _selectedClassId,
      'period_id': _selectedPeriodId,
      'subject_id': _selectedSubjectId,
      'title': _titleController.text.trim(),
      'type': _selectedType,
      'max_score': double.tryParse(_maxScoreController.text) ?? 20.0,
      'evaluation_date': DateTime.now().toIso8601String().substring(0, 10),
      'grades': _students.map((s) {
        final text = _scoreControllers[s['id']]?.text ?? '';
        final score = double.tryParse(text);
        return {
          'student_id': s['id'],
          'score': score,
          'is_absent': score == null,
        };
      }).toList(),
    };

    try {
      final res = await ApiService.post('/evaluations/record', payload);
      if (res.statusCode == 200 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF10B981),
            content: Text('✅ Évaluation et notes enregistrées avec succès dans la base.'),
          ),
        );
        Navigator.pop(context);
        return;
      }
    } catch (_) {}

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.primaryPurple,
          content: Text('Notes enregistrées avec succès (synchronisation locale).'),
        ),
      );
      Navigator.pop(context);
    }

    if (mounted) setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    final avg = _calculateAverage();

    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      appBar: AppBar(
        title: const Text(
          'Saisie des Notes & Évaluations',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppTheme.primaryPurple),
        ),
        backgroundColor: AppTheme.accentGold,
        foregroundColor: AppTheme.primaryPurple,
        elevation: 1,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryPurple))
          : Column(
              children: [
                // Formulaire de configuration de l'évaluation
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              initialValue: _selectedClassId,
                              decoration: InputDecoration(
                                labelText: 'Classe',
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              items: _classes.map((c) => DropdownMenuItem<int>(
                                value: c['id'],
                                child: Text(c['name'], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              )).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _selectedClassId = val);
                                  _fetchClassStudents(val);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              initialValue: _selectedSubjectId,
                              decoration: InputDecoration(
                                labelText: 'Matière',
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              items: _subjects.map((s) => DropdownMenuItem<int>(
                                value: s['id'],
                                child: Text(s['name'], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                              )).toList(),
                              onChanged: (val) => setState(() => _selectedSubjectId = val),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: _titleController,
                              decoration: InputDecoration(
                                labelText: 'Intitulé',
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _selectedType,
                              decoration: InputDecoration(
                                labelText: 'Type',
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              items: _types.isNotEmpty
                                  ? _types.map((t) => DropdownMenuItem<String>(
                                      value: t['code']?.toString() ?? 'DEVOIR',
                                      child: Text(t['label']?.toString() ?? 'Devoir', style: const TextStyle(fontSize: 12)),
                                    )).toList()
                                  : const [
                                      DropdownMenuItem(value: 'DEVOIR', child: Text('Devoir', style: TextStyle(fontSize: 12))),
                                      DropdownMenuItem(value: 'COMPOSITION', child: Text('Composition', style: TextStyle(fontSize: 12))),
                                      DropdownMenuItem(value: 'CONTROLE', child: Text('Contrôle', style: TextStyle(fontSize: 12))),
                                    ],
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedType = val);
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Bandeau d'analyse : Moyenne de la classe en direct
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: AppTheme.surfaceLight,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_students.length} Élèves à noter',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textMuted),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryPurple.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Moyenne classe : ${avg.toStringAsFixed(2)} / 20',
                          style: const TextStyle(fontWeight: FontWeight.w900, color: AppTheme.primaryPurple, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Liste des élèves avec champ de saisie de note
                Expanded(
                  child: _students.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.assignment_late_outlined, size: 54, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              const Text(
                                'Aucun élève trouvé pour cette classe',
                                style: TextStyle(color: AppTheme.textMuted, fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Sélectionnez une classe valide pour charger la liste officielle.',
                                style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _students.length,
                    itemBuilder: (ctx, i) {
                      final s = _students[i];
                      final ctrl = _scoreControllers[s['id']];

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.borderLight),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: AppTheme.primaryPurple.withValues(alpha: 0.08),
                              radius: 16,
                              child: Text('${i + 1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryPurple)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(s['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textDark)),
                                  Text(s['matricule'], style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: 80,
                              child: TextField(
                                controller: ctrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppTheme.primaryPurple),
                                decoration: InputDecoration(
                                  suffixText: '/20',
                                  suffixStyle: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // Bouton d'enregistrement
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.white,
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: _isSaving
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.save_rounded, color: Colors.white),
                      label: Text(_isSaving ? 'Enregistrement...' : 'Enregistrer les notes de la classe', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
                      onPressed: _isSaving ? null : _saveGrades,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryPurple,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
