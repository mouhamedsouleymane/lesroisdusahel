import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';

class SchedulesScreen extends StatefulWidget {
  final UserModel user;
  const SchedulesScreen({super.key, required this.user});

  @override
  State<SchedulesScreen> createState() => _SchedulesScreenState();
}

class _SchedulesScreenState extends State<SchedulesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _days = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi'];
  bool _isLoading = false;
  Timer? _syncTimer;
  int? _selectedStudentId;
  List<Map<String, dynamic>> _children = [];
  List<Map<String, dynamic>> _allSchedules = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _days.length, vsync: this);
    _fetchSchedules(isInitial: true);
    // Synchronisation automatique toutes les 10 secondes
    _syncTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) _fetchSchedules(isInitial: false);
    });
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchSchedules({bool isInitial = false}) async {
    if (isInitial) setState(() => _isLoading = true);
    try {
      final endpoint = _selectedStudentId != null
          ? '/schedules?student_id=$_selectedStudentId'
          : '/schedules';
      final response = await ApiService.get(endpoint);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['schedules'] != null) {
          final list = data['schedules'] as List<dynamic>;
          final childrenList = data['children'] as List<dynamic>?;
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
              }
              _allSchedules = list.map((e) => {
                'day': e['day_of_week']?.toString() ?? 'Lundi',
                'time': (e['start_time'] != null && e['end_time'] != null)
                    ? '${e['start_time'].toString().substring(0, 5)} - ${e['end_time'].toString().substring(0, 5)}'
                    : '08:00 - 10:00',
                'subject': e['subject_name']?.toString() ?? 'Matière',
                'class': e['class_name']?.toString() ?? 'Classe',
                'teacher': e['teacher_name']?.toString() ?? 'Enseignant',
                'room': e['room']?.toString() ?? 'Salle',
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
    _fetchSchedules(isInitial: true);
  }

  List<Map<String, dynamic>> _getSchedulesForDay(String day) {
    return _allSchedules.where((s) => s['day']?.toLowerCase() == day.toLowerCase()).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      appBar: AppBar(
        title: const Text(
          'Emplois du Temps & Horaires',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppTheme.primaryPurple),
        ),
        backgroundColor: AppTheme.accentGold,
        foregroundColor: AppTheme.primaryPurple,
        elevation: 1,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: AppTheme.primaryPurple,
          indicatorWeight: 3.5,
          labelColor: AppTheme.primaryPurple,
          unselectedLabelColor: AppTheme.primaryPurple.withValues(alpha: 0.65),
          labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
          tabs: _days.map((d) => Tab(text: d)).toList(),
        ),
      ),
      body: Column(
        children: [
          if (_children.length > 1)
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _ScheduleStudentChip(
                      label: 'Tous (${_children.length})',
                      isSelected: _selectedStudentId == null,
                      onTap: () => _onSelectChild(null),
                    ),
                    ..._children.map((c) {
                      final int? id = c['id'] as int?;
                      final String firstName = c['first_name'] ?? 'Élève';
                      final String className = c['class'] ?? '';
                      return Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: _ScheduleStudentChip(
                          label: className.isNotEmpty ? '$firstName · $className' : firstName,
                          isSelected: _selectedStudentId == id,
                          onTap: () => _onSelectChild(id),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryPurple))
                : TabBarView(
                    controller: _tabController,
                    children: _days.map((day) {
                      final dayCourses = _getSchedulesForDay(day);
                      return RefreshIndicator(
                        color: AppTheme.primaryPurple,
                        onRefresh: _fetchSchedules,
                        child: dayCourses.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.event_busy, size: 54, color: Colors.grey.shade400),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Aucun cours programmé le $day',
                                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 14, fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Les horaires sont synchronisés en direct depuis la base de données.',
                                      style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                                itemCount: dayCourses.length,
                                itemBuilder: (ctx, i) {
                                  final c = dayCourses[i];
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: AppTheme.borderLight),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.02),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: AppTheme.primaryPurple.withValues(alpha: 0.08),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: AppTheme.primaryPurple.withValues(alpha: 0.2)),
                                          ),
                                          child: Text(
                                            c['time'] ?? '',
                                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: AppTheme.primaryPurple),
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      c['subject'] ?? '',
                                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textDark),
                                                    ),
                                                  ),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: AppTheme.accentGold.withValues(alpha: 0.2),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: Text(
                                                      c['class'] ?? '',
                                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppTheme.primaryPurple),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              Row(
                                                children: [
                                                  const Icon(Icons.meeting_room, size: 14, color: AppTheme.textMuted),
                                                  const SizedBox(width: 4),
                                                  Text(c['room'] ?? '', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                c['teacher'] ?? '',
                                                style: const TextStyle(fontSize: 12, color: AppTheme.accentGoldDark, fontWeight: FontWeight.w600),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleStudentChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ScheduleStudentChip({
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryPurple : AppTheme.surfaceLight,
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
