import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';
import '../features/child_attendance_screen.dart';
import '../features/finances_screen.dart';
import '../features/messages_screen.dart';
import '../features/parent_notifications_screen.dart';
import '../features/report_cards_screen.dart';
import '../tabs/grades_screen.dart';

class ParentDashboard extends StatefulWidget {
  final UserModel user;
  const ParentDashboard({super.key, required this.user});

  @override
  State<ParentDashboard> createState() => _ParentDashboardState();
}

class _ParentDashboardState extends State<ParentDashboard> {
  bool _isLoading = false;
  Timer? _syncTimer;
  List<Map<String, dynamic>> _children = [];
  int _selectedChildIndex = 0;

  @override
  void initState() {
    super.initState();
    _fetchParentData(isInitial: true);
    // Synchronisation automatique toutes les 10 secondes
    _syncTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) _fetchParentData(isInitial: false);
    });
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchParentData({bool isInitial = false}) async {
    if (isInitial) setState(() => _isLoading = true);
    try {
      final response = await ApiService.get('/dashboard');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['children'] != null) {
          final list = data['children'] as List<dynamic>;
          if (mounted && list.isNotEmpty) {
            setState(() {
              _children = list.map((c) => {
                'id': c['id'] as int?,
                'name': c['name']?.toString() ?? 'Élève',
                'firstName': c['first_name']?.toString() ?? c['name']?.toString().split(' ').first ?? 'Élève',
                'className': c['class']?.toString() ?? 'Non assigné',
                'level': c['level']?.toString() ?? '',
                'cycle': c['cycle']?.toString() ?? 'Général',
                'averageShort': c['average_short']?.toString() ?? '-',
                'average': c['average']?.toString() ?? 'En attente',
                'absencesCount': (c['absences_count'] as num?)?.toInt() ?? 0,
                'latesCount': (c['lates_count'] as num?)?.toInt() ?? 0,
                'presentToday': c['present_today'] != false,
                'messagesCount': (c['messages_count'] as num?)?.toInt() ?? (c['alerts_count'] as num?)?.toInt() ?? 0,
                'alertsCount': (c['alerts_count'] as num?)?.toInt() ?? 0,
                'unpaidFcfa': (c['unpaid_fcfa'] as num?)?.toInt() ?? 0,
                'isPaid': (c['unpaid_fcfa'] ?? 0) == 0,
              }).toList();

              if (_selectedChildIndex >= _children.length) {
                _selectedChildIndex = 0;
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
    final activeChild = _children.isNotEmpty ? _children[_selectedChildIndex] : null;
    final int? activeChildId = activeChild?['id'] as int?;

    return RefreshIndicator(
      color: AppTheme.primaryPurple,
      onRefresh: _fetchParentData,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 105),
        children: [
          // 1. EN-TÊTE PORTAIL PARENT + ONGLETS ENFANTS (Style Maquette Image 1)
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF260438), AppTheme.primaryPurple],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryPurple.withValues(alpha: 0.25),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
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
                          const Text(
                            'Bonjour,',
                            style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.user.name,
                            style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    CircleAvatar(
                      radius: 21,
                      backgroundColor: AppTheme.accentGold,
                      child: Text(
                        widget.user.initials,
                        style: const TextStyle(
                          color: AppTheme.primaryPurple,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),

                // Barre d'onglets horizontale des enfants (1 à 5+ enfants)
                if (_children.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: List.generate(_children.length, (idx) {
                        final child = _children[idx];
                        final isSelected = idx == _selectedChildIndex;
                        final firstName = child['firstName']?.toString() ?? 'Enfant';
                        return Padding(
                          padding: EdgeInsets.only(right: idx < _children.length - 1 ? 8 : 0),
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedChildIndex = idx),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              constraints: const BoxConstraints(minWidth: 92),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                                border: isSelected
                                    ? Border.all(color: AppTheme.accentGold, width: 1.5)
                                    : null,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                firstName,
                                style: TextStyle(
                                  color: isSelected ? AppTheme.primaryPurple : Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 14),

          // 2. CARTE DE SYNTHÈSE DE L'ENFANT SÉLECTIONNÉ (Style Maquette Image 1)
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(color: AppTheme.primaryPurple),
              ),
            )
          else if (activeChild != null) ...[
            _ActiveChildSummaryCard(child: activeChild),

            const SizedBox(height: 16),

            // 3. GRILLE DE 6 TUILES DE NAVIGATION RAPIDE (2 lignes × 3 colonnes - Style Image 1)
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.04,
              children: [
                _QuickMenuTile(
                  icon: Icons.bar_chart_rounded,
                  label: 'Notes',
                  bgColor: const Color(0xFFEDE9FE),
                  iconColor: AppTheme.primaryPurple,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GradesScreen(
                        user: widget.user,
                        initialStudentId: activeChildId,
                      ),
                    ),
                  ),
                ),
                _QuickMenuTile(
                  icon: Icons.calendar_month_rounded,
                  label: 'Présences',
                  bgColor: const Color(0xFFD1FAE5),
                  iconColor: const Color(0xFF059669),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChildAttendanceScreen(
                        initialStudentId: activeChildId,
                      ),
                    ),
                  ),
                ),
                _QuickMenuTile(
                  icon: Icons.credit_card_rounded,
                  label: 'Scolarité',
                  bgColor: const Color(0xFFE0E7FF),
                  iconColor: const Color(0xFF2563EB),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FinancesScreen(
                        initialStudentId: activeChildId,
                      ),
                    ),
                  ),
                ),
                _QuickMenuTile(
                  icon: Icons.chat_bubble_rounded,
                  label: 'Messages',
                  bgColor: const Color(0xFFD1FAE5),
                  iconColor: const Color(0xFF10B981),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MessagesScreen(
                        initialStudentId: activeChildId,
                      ),
                    ),
                  ),
                ),
                _QuickMenuTile(
                  icon: Icons.notifications_active_rounded,
                  label: 'Alertes',
                  bgColor: const Color(0xFFFEF3C7),
                  iconColor: AppTheme.accentGoldDark,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ParentNotificationsScreen(
                        initialStudentId: activeChildId,
                        initialFilter: 'all',
                      ),
                    ),
                  ),
                ),
                _QuickMenuTile(
                  icon: Icons.description_rounded,
                  label: 'Bulletins',
                  bgColor: const Color(0xFFD1FAE5),
                  iconColor: AppTheme.primaryPurple,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ReportCardsScreen(
                        initialStudentId: activeChildId,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // 4. BANNIÈRE D'INFORMATION ÉTABLISSEMENT EN BAS (Style Maquette Image 1)
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ParentNotificationsScreen(
                    initialStudentId: activeChildId,
                    initialFilter: 'all',
                  ),
                ),
              ),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF260438), AppTheme.primaryPurple],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.accentGold.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.campaign_rounded, color: AppTheme.accentGold, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Réunion de parents & Annonces',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            activeChild['isPaid'] == true
                                ? 'Vous serez informé en direct des réunions, examens et bulletins de ${activeChild['firstName']}.'
                                : 'Rappel : Solde scolarité de ${activeChild['unpaidFcfa']} FCFA pour ${activeChild['firstName']}.',
                            style: const TextStyle(color: Colors.white70, fontSize: 11.5),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: AppTheme.accentGold),
                  ],
                ),
              ),
            ),
          ] else
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
                  Icon(Icons.family_restroom, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  const Text(
                    'Aucun élève rattaché à ce compte parent',
                    style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textMuted, fontSize: 14),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ActiveChildSummaryCard extends StatelessWidget {
  final Map<String, dynamic> child;

  const _ActiveChildSummaryCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final String name = child['name']?.toString() ?? 'Élève';
    final String firstName = child['firstName']?.toString() ?? 'E';
    final String initial = firstName.isNotEmpty ? firstName[0].toUpperCase() : 'E';
    final String className = child['className']?.toString() ?? 'Non assigné';
    final String cycle = child['cycle']?.toString() ?? '';
    final bool presentToday = child['presentToday'] != false;
    final String averageShort = child['averageShort']?.toString() ?? '-';
    final int absencesCount = (child['absencesCount'] as int?) ?? 0;
    final int messagesCount = (child['messagesCount'] as int?) ?? 0;

    return Container(
      padding: const EdgeInsets.all(18),
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
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: AppTheme.primaryPurple,
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      cycle.isNotEmpty ? '$className - $cycle' : className,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppTheme.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: presentToday ? const Color(0xFF10B981) : Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          presentToday ? 'Présent(e) aujourd\'hui' : 'Absent(e) aujourd\'hui',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: presentToday ? const Color(0xFF059669) : Colors.red.shade700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _MetricColumn(
                value: averageShort,
                label: 'Moyenne /20',
              ),
              Container(width: 1, height: 28, color: AppTheme.borderLight),
              _MetricColumn(
                value: '$absencesCount',
                label: absencesCount > 1 ? 'Absences' : 'Absence',
              ),
              Container(width: 1, height: 28, color: AppTheme.borderLight),
              _MetricColumn(
                value: '$messagesCount',
                label: 'Messages',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricColumn extends StatelessWidget {
  final String value;
  final String label;

  const _MetricColumn({
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: AppTheme.textDark,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppTheme.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _QuickMenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color bgColor;
  final Color iconColor;
  final VoidCallback onTap;

  const _QuickMenuTile({
    required this.icon,
    required this.label,
    required this.bgColor,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bgColor.withValues(alpha: 0.65),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: iconColor.withValues(alpha: 0.15)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: iconColor.withValues(alpha: 0.12),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.textDark,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
