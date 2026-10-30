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
  List<Map<String, dynamic>> _allSchedules = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _days.length, vsync: this);
    _fetchSchedules();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchSchedules() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiService.get('/schedules');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['schedules'] != null) {
          final list = data['schedules'] as List<dynamic>;
          setState(() {
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
    } catch (_) {
      // Données locales
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> _getSchedulesForDay(String day) {
    final filtered = _allSchedules.where((s) => s['day']?.toLowerCase() == day.toLowerCase()).toList();
    if (filtered.isNotEmpty) return filtered;

    // Horaires par défaut pour la démonstration
    return [
      {'time': '08:00 - 10:00', 'subject': 'Mathématiques', 'class': '6ème A', 'teacher': 'Prof. Ali Oumarou', 'room': 'Salle 12'},
      {'time': '10:15 - 12:00', 'subject': 'Français & Expression', 'class': '6ème A', 'teacher': 'Mme Amina Hassane', 'room': 'Salle 12'},
      {'time': '15:00 - 17:00', 'subject': 'Histoire - Géographie', 'class': '6ème A', 'teacher': 'M. Boubacar Sani', 'room': 'Salle 12'},
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      appBar: AppBar(
        title: const Text('Emplois du Temps & Horaires', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textDark,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchSchedules,
            tooltip: 'Actualiser',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: AppTheme.accentGold,
          indicatorWeight: 3,
          labelColor: AppTheme.primaryPurple,
          unselectedLabelColor: AppTheme.textMuted,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: _days.map((d) => Tab(text: d)).toList(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryPurple))
          : TabBarView(
              controller: _tabController,
              children: _days.map((day) {
                final dayCourses = _getSchedulesForDay(day);
                return RefreshIndicator(
                  color: AppTheme.primaryPurple,
                  onRefresh: _fetchSchedules,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
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
                                  Text(
                                    c['subject'] ?? '',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textDark),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.school, size: 14, color: AppTheme.textMuted),
                                      const SizedBox(width: 4),
                                      Text(c['class'] ?? '', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                                      const SizedBox(width: 12),
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
    );
  }
}

