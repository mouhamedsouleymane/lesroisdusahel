import 'dart:convert';
import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';

class AdminDashboard extends StatefulWidget {
  final UserModel user;
  const AdminDashboard({super.key, required this.user});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  bool _isLoading = false;
  String _studentsCount = '875';
  String _classesCount = '25';
  String _teachersCount = '24';
  String _recoveryRate = '56.1 %';
  String _academicYear = '2026-2027';

  @override
  void initState() {
    super.initState();
    _fetchLiveStats();
  }

  Future<void> _fetchLiveStats() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiService.get('/dashboard');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['stats'] != null) {
          final stats = data['stats'];
          setState(() {
            _studentsCount = stats['students_count']?.toString() ?? _studentsCount;
            _classesCount = stats['classes_count']?.toString() ?? _classesCount;
            _teachersCount = stats['teachers_count']?.toString() ?? _teachersCount;
            _recoveryRate = '${stats['recovery_rate'] ?? 56.1} %';
            _academicYear = data['academic_year'] ?? _academicYear;
          });
        }
      }
    } catch (_) {
      // Garde les valeurs par défaut si hors-ligne
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppTheme.primaryPurple,
      onRefresh: _fetchLiveStats,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Carte de bienvenue
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primaryPurple, AppTheme.primaryPurpleLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryPurple.withValues(alpha: 0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.accentGold, width: 2),
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/logo_roi.jpeg',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.school, color: AppTheme.primaryPurple),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.accentGold.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'ESPACE DIRECTION',
                          style: TextStyle(
                            color: AppTheme.accentGoldLight,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.user.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Année scolaire $_academicYear',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (_isLoading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(color: AppTheme.accentGold, strokeWidth: 2),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Grille des statistiques clés (KPIs)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Vue d\'ensemble de l\'établissement',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppTheme.textDark),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 18, color: AppTheme.primaryPurple),
                tooltip: 'Actualiser les données',
                onPressed: _fetchLiveStats,
              ),
            ],
          ),
          const SizedBox(height: 8),

          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.4,
            children: [
              _StatCard(title: 'Élèves Inscrits', value: _studentsCount, icon: Icons.people_alt, color: Colors.blue),
              _StatCard(title: 'Classes Actives', value: _classesCount, icon: Icons.meeting_room, color: AppTheme.primaryPurple),
              _StatCard(title: 'Enseignants', value: _teachersCount, icon: Icons.person_pin, color: Colors.indigo),
              _StatCard(title: 'Recouvrement', value: _recoveryRate, icon: Icons.account_balance_wallet, color: const Color(0xFF10B981)),
            ],
          ),

          const SizedBox(height: 24),

          // Raccourcis d'administration
          const Text(
            'Modules de gestion',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppTheme.textDark),
          ),
          const SizedBox(height: 12),

          _ActionTile(
            icon: Icons.calendar_month,
            title: 'Emplois du temps & Plages horaires',
            subtitle: 'Consulter et configurer les plannings par classe',
            onTap: () {},
          ),
          _ActionTile(
            icon: Icons.grade,
            title: 'Évaluations & Notes',
            subtitle: 'Suivi de la saisie des notes et moyennes',
            onTap: () {},
          ),
          _ActionTile(
            icon: Icons.check_circle_outline,
            title: 'Pointage des Présences',
            subtitle: 'Feuilles d\'appel et statistiques d\'absentéisme',
            onTap: () {},
          ),
          _ActionTile(
            icon: Icons.receipt_long,
            title: 'Finances & Scolarité',
            subtitle: 'Factures impayées, encaissements et dépenses',
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textMuted)),
              Icon(icon, size: 20, color: color),
            ],
          ),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionTile({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.primaryPurple.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppTheme.primaryPurple, size: 22),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textDark)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.textMuted),
        onTap: onTap,
      ),
    );
  }
}
