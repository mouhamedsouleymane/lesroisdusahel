import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../services/api_service.dart';
import 'messages_screen.dart';

class ParentNotificationsScreen extends StatefulWidget {
  final int? initialStudentId;
  final String initialFilter; // 'all' ou 'absences'

  const ParentNotificationsScreen({
    super.key,
    this.initialStudentId,
    this.initialFilter = 'all',
  });

  @override
  State<ParentNotificationsScreen> createState() => _ParentNotificationsScreenState();
}

class _ParentNotificationsScreenState extends State<ParentNotificationsScreen> {
  bool _isLoading = true;
  Timer? _syncTimer;
  int? _selectedStudentId;
  late String _activeFilter;
  List<Map<String, dynamic>> _children = [];
  List<Map<String, dynamic>> _notifications = [];

  @override
  void initState() {
    super.initState();
    _selectedStudentId = widget.initialStudentId;
    _activeFilter = widget.initialFilter;
    _fetchNotifications(isInitial: true);
    _syncTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) _fetchNotifications(isInitial: false);
    });
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchNotifications({bool isInitial = false}) async {
    if (isInitial) setState(() => _isLoading = true);
    try {
      final dashRes = await ApiService.get('/dashboard');
      final msgEndpoint = _selectedStudentId != null
          ? '/messages?student_id=$_selectedStudentId'
          : '/messages';
      final msgRes = await ApiService.get(msgEndpoint);

      final List<Map<String, dynamic>> items = [];
      List<Map<String, dynamic>> parsedChildren = [];

      // 1. Alertes et annonces issues de la table school_messages (Réunions, Examens, Bulletins, Convocations, Absences)
      if (msgRes.statusCode == 200) {
        final msgData = jsonDecode(msgRes.body);
        if (msgData['success'] == true && msgData['messages'] != null) {
          final msgs = (msgData['messages'] as List<dynamic>).where((m) => m['is_from_school'] == true);
          for (final m in msgs) {
            final cat = (m['category']?.toString() ?? 'ANNONCE').toUpperCase();
            IconData icon = Icons.campaign_rounded;
            Color iconBg = const Color(0xFFD1FAE5);
            Color iconColor = const Color(0xFF059669);
            String typeKey = 'announcement';

            if (cat == 'ABSENCE' || cat == 'RETARD') {
              icon = Icons.event_busy;
              iconBg = const Color(0xFFFEE2E2);
              iconColor = const Color(0xFFDC2626);
              typeKey = 'absence';
            } else if (cat == 'EXAMEN') {
              icon = Icons.edit_calendar_rounded;
              iconBg = const Color(0xFFEDE9FE);
              iconColor = AppTheme.primaryPurple;
            } else if (cat == 'BULLETIN') {
              icon = Icons.description_rounded;
              iconBg = const Color(0xFFD1FAE5);
              iconColor = const Color(0xFF10B981);
            } else if (cat == 'CONVOCATION') {
              icon = Icons.mail_outline_rounded;
              iconBg = const Color(0xFFE0E7FF);
              iconColor = const Color(0xFF2563EB);
            } else if (cat == 'SCOLARITE') {
              icon = Icons.notifications_active_rounded;
              iconBg = const Color(0xFFFEF3C7);
              iconColor = AppTheme.accentGoldDark;
            }

            items.add({
              'type': typeKey,
              'icon': icon,
              'iconBg': iconBg,
              'iconColor': iconColor,
              'title': m['subject']?.toString() ?? 'Notification',
              'subtitle': m['body']?.toString() ?? '',
              'isUnread': m['is_read'] == false,
            });
          }
        }
      }

      if (dashRes.statusCode == 200) {
        final dashData = jsonDecode(dashRes.body);
        if (dashData['success'] == true && dashData['children'] != null) {
          final childrenRaw = dashData['children'] as List<dynamic>;
          parsedChildren = childrenRaw.map((c) => Map<String, dynamic>.from(c as Map)).toList();

          final targetChildren = _selectedStudentId == null
              ? parsedChildren
              : parsedChildren.where((c) => c['id'] == _selectedStudentId).toList();

          for (final child in targetChildren) {
            final childName = child['name']?.toString() ?? 'Élève';
            final className = child['class']?.toString() ?? '';
            final unpaid = (child['unpaid_fcfa'] as num?)?.toInt() ?? 0;

            // Absences récentes si non déjà listées
            final recentAttendances = (child['recent_attendances'] as List<dynamic>?) ?? [];
            for (final att in recentAttendances) {
              final isLate = att['status'] == 'RETARD';
              final date = att['date']?.toString() ?? '';
              final reason = att['reason']?.toString() ?? 'Enregistré lors de l\'appel';
              final justified = att['is_justified'] == true;
              items.add({
                'type': 'absence',
                'icon': isLate ? Icons.access_time_filled : Icons.event_busy,
                'iconBg': isLate ? const Color(0xFFFEF3C7) : const Color(0xFFFEE2E2),
                'iconColor': isLate ? AppTheme.accentGoldDark : const Color(0xFFDC2626),
                'title': isLate ? 'Retard signalé · $childName' : 'Absence enregistrée · $childName',
                'subtitle': '$date ($className) — $reason',
                'isUnread': !justified,
              });
            }

            if (unpaid > 0) {
              items.add({
                'type': 'finance',
                'icon': Icons.notifications_active,
                'iconBg': const Color(0xFFFEF3C7),
                'iconColor': AppTheme.accentGoldDark,
                'title': 'Rappel administratif · Scolarité',
                'subtitle': 'Solde restant de $unpaid FCFA pour $childName ($className)',
                'isUnread': true,
              });
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _children = parsedChildren;
          _notifications = items;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = _activeFilter == 'absences'
        ? _notifications.where((n) => n['type'] == 'absence').toList()
        : _notifications;

    final selectedChild = _selectedStudentId != null
        ? _children.where((c) => c['id'] == _selectedStudentId).firstOrNull
        : null;

    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _activeFilter == 'absences' ? 'Présences & Absences' : 'Notifications',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppTheme.primaryPurple),
            ),
            Text(
              selectedChild != null
                  ? '${selectedChild['name']} · ${selectedChild['class']}'
                  : 'Les informations importantes de l\'école',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.primaryPurple.withValues(alpha: 0.8)),
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
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                if (_children.length > 1) ...[
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        _FilterPill(
                          label: 'Tous (${_children.length})',
                          isSelected: _selectedStudentId == null,
                          onTap: () {
                            setState(() => _selectedStudentId = null);
                            _fetchNotifications(isInitial: true);
                          },
                        ),
                        ..._children.map((c) {
                          final int? id = c['id'] as int?;
                          final String firstName = c['first_name']?.toString() ?? 'Élève';
                          final String className = c['class']?.toString() ?? '';
                          return Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: _FilterPill(
                              label: className.isNotEmpty ? '$firstName · $className' : firstName,
                              isSelected: _selectedStudentId == id,
                              onTap: () {
                                setState(() => _selectedStudentId = id);
                                _fetchNotifications(isInitial: true);
                              },
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],

                // Onglets Tout / Absences & Retards
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _activeFilter = 'all'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _activeFilter == 'all' ? AppTheme.primaryPurple : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _activeFilter == 'all' ? AppTheme.primaryPurple : AppTheme.borderLight),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Toutes les alertes',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: _activeFilter == 'all' ? AppTheme.accentGold : AppTheme.textDark,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _activeFilter = 'absences'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _activeFilter == 'absences' ? AppTheme.primaryPurple : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _activeFilter == 'absences' ? AppTheme.primaryPurple : AppTheme.borderLight),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Absences & Retards',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: _activeFilter == 'absences' ? AppTheme.accentGold : AppTheme.textDark,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                if (filteredItems.isEmpty)
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
                        Icon(
                          _activeFilter == 'absences' ? Icons.verified_user_outlined : Icons.notifications_none_rounded,
                          size: 48,
                          color: const Color(0xFF10B981),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _activeFilter == 'absences'
                              ? 'Aucune absence ni retard signalé'
                              : 'Aucune notification en attente',
                          style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.textDark, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Les informations importantes de l\'école (réunions, examens, bulletins, appels) arrivent directement ici.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  )
                else
                  ...filteredItems.map((item) => Container(
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
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: item['iconBg'] as Color,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                item['icon'] as IconData,
                                color: item['iconColor'] as Color,
                                size: 22,
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
                                          item['title']?.toString() ?? '',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 13.5,
                                            color: AppTheme.textDark,
                                          ),
                                        ),
                                      ),
                                      if (item['isUnread'] == true)
                                        Container(
                                          width: 9,
                                          height: 9,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFF10B981),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item['subtitle']?.toString() ?? '',
                                    style: const TextStyle(fontSize: 12, color: AppTheme.textMuted, height: 1.3),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )),

                const SizedBox(height: 16),

                // Encadré contact administration via Messagerie Interne
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryPurple.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.primaryPurple.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.forum_outlined, color: AppTheme.primaryPurple, size: 28),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Besoin de justifier une absence ou de contacter l\'administration ?',
                          style: TextStyle(fontSize: 12, color: AppTheme.textDark, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MessagesScreen(
                              initialStudentId: _selectedStudentId,
                              openComposerOnInit: true,
                            ),
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryPurple,
                          foregroundColor: AppTheme.accentGold,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Messagerie', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterPill({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
