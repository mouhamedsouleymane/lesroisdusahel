import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';

class _DiscussionThread {
  final String id;
  final String title;
  final String subtitle;
  final String participants;
  final String categoryFilter;
  final int? studentId;
  final int? guardianId;
  final bool isPinned;
  final bool isOfficialLogo;
  final IconData icon;
  final Color avatarBg;
  final List<Map<String, dynamic>> messages;
  final int unreadCount;

  const _DiscussionThread({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.participants,
    required this.categoryFilter,
    this.studentId,
    this.guardianId,
    this.isPinned = false,
    this.isOfficialLogo = false,
    required this.icon,
    required this.avatarBg,
    required this.messages,
    required this.unreadCount,
  });
}

class MessagesScreen extends StatefulWidget {
  final UserModel? user;
  final int? initialStudentId;
  final String? initialCategory;
  final String? initialSubject;
  final bool openComposerOnInit;

  const MessagesScreen({
    super.key,
    this.user,
    this.initialStudentId,
    this.initialCategory,
    this.initialSubject,
    this.openComposerOnInit = false,
  });

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  bool _isLoading = true;
  bool _isSending = false;
  Timer? _syncTimer;
  String _searchQuery = '';
  String _activeFilter = 'ALL'; // ALL, UNREAD, ANNONCE, CHILDREN
  List<Map<String, dynamic>> _children = [];
  List<Map<String, dynamic>> _messages = [];
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchMessages(isInitial: true).then((_) {
      if (widget.openComposerOnInit && mounted) {
        _showComposeModal(
          initialCategory: widget.initialCategory,
          initialSubject: widget.initialSubject,
          initialStudentId: widget.initialStudentId,
        );
      }
    });
    // Synchronisation silencieuse toutes les 10 secondes
    _syncTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) _fetchMessages(isInitial: false);
    });
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchMessages({bool isInitial = false}) async {
    if (isInitial) setState(() => _isLoading = true);
    try {
      final res = await ApiService.get('/messages');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) {
          final childrenList = (data['children'] as List<dynamic>?) ?? [];
          final msgList = (data['messages'] as List<dynamic>?) ?? [];

          if (mounted) {
            setState(() {
              _children = childrenList
                  .map((c) => Map<String, dynamic>.from(c as Map))
                  .toList();
              _messages = msgList
                  .map((m) => Map<String, dynamic>.from(m as Map))
                  .toList();
              _isLoading = false;
            });
          }
          return;
        }
      }
    } catch (_) {
      // Erreur réseau silencieuse
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markThreadMessagesRead(List<Map<String, dynamic>> threadMsgs) async {
    bool anyMarked = false;
    for (final m in threadMsgs) {
      if (m['is_from_school'] == true && m['is_read'] == false && m['id'] != null) {
        anyMarked = true;
        m['is_read'] = true;
        ApiService.post('/messages/${m['id']}/read', {});
      }
    }
    if (anyMarked && mounted) {
      setState(() {});
    }
  }

  List<_DiscussionThread> _buildDiscussionThreads() {
    final List<_DiscussionThread> threads = [];

    // 1. Canal Officiel Épinglé : Communiqués & Direction CSP Les Rois du Sahel
    final generalAnnouncements = _messages.where((m) {
      final cat = (m['category'] ?? '').toString().toUpperCase();
      return m['is_broadcast'] == true ||
          cat == 'ANNONCE' ||
          cat == 'REUNION' ||
          cat == 'EXAMEN' ||
          cat == 'CONVOCATION';
    }).toList();

    final unreadGeneral = generalAnnouncements
        .where((m) => m['is_from_school'] == true && m['is_read'] == false)
        .length;

    threads.add(
      _DiscussionThread(
        id: 'official_direction',
        title: 'CSP LES ROIS DU SAHEL • DIRECTION',
        subtitle: generalAnnouncements.isNotEmpty
            ? 'DIRECTION: 📢 ${generalAnnouncements.first['subject'] ?? generalAnnouncements.first['body'] ?? ''}'
            : 'DIRECTION: 📢 Canal officiel des communiqués, réunions et examens',
        participants: 'Direction Générale, Censeur, Secrétariat, Parents',
        categoryFilter: 'ANNONCE',
        isPinned: true,
        isOfficialLogo: true,
        icon: Icons.campaign_rounded,
        avatarBg: AppTheme.primaryPurple,
        messages: generalAnnouncements,
        unreadCount: unreadGeneral,
      ),
    );

    // 2. Un canal de discussion dédié par Enfant inscrit (si Parent)
    if (_children.isNotEmpty) {
      for (final child in _children) {
        final int? childId = child['id'] as int?;
        final String childName = child['name']?.toString() ?? 'Élève';
        final String className = child['class']?.toString() ?? '';
        final String cycleName = child['cycle']?.toString() ?? '';

        final childMsgs = _messages
            .where((m) => m['student_id'] == childId)
            .toList();
        final unreadChild = childMsgs
            .where((m) => m['is_from_school'] == true && m['is_read'] == false)
            .length;

        String preview = 'Démarrez une discussion concernant $childName';
        if (childMsgs.isNotEmpty) {
          final last = childMsgs.first;
          final bool fromSchool = last['is_from_school'] == true;
          final String prefix = fromSchool ? 'École: ' : '✓✓ Vous: ';
          preview = '$prefix${last['subject'] ?? ''} — ${last['body'] ?? ''}';
        }

        threads.add(
          _DiscussionThread(
            id: 'child_${childId ?? childName}',
            title: '$childName ${className.isNotEmpty ? "($className)" : ""}',
            subtitle: preview,
            participants: 'Administration, Professeur principal, Vie Scolaire · $cycleName',
            categoryFilter: 'MESSAGE',
            studentId: childId,
            isPinned: widget.initialStudentId != null && widget.initialStudentId == childId,
            icon: Icons.school_rounded,
            avatarBg: const Color(0xFF4C1D95),
            messages: childMsgs,
            unreadCount: unreadChild,
          ),
        );
      }
    }

    // 3. Canal Vie Scolaire & Assiduité (Absences, Retards & Justifications)
    final attendanceMsgs = _messages.where((m) {
      final cat = (m['category'] ?? '').toString().toUpperCase();
      return cat == 'ABSENCE' || cat == 'RETARD' || cat == 'PRESENCE';
    }).toList();
    final unreadAttendance = attendanceMsgs
        .where((m) => m['is_from_school'] == true && m['is_read'] == false)
        .length;

    threads.add(
      _DiscussionThread(
        id: 'vie_scolaire',
        title: 'VIE SCOLAIRE & ASSIDUITÉ',
        subtitle: attendanceMsgs.isNotEmpty
            ? '${attendanceMsgs.first['is_from_school'] == true ? "Surveillance:" : "✓✓ Vous:"} ${attendanceMsgs.first['subject'] ?? attendanceMsgs.first['body']}'
            : 'Alertes d\'absences, retards à l\'appel et envoi de justificatifs',
        participants: 'Surveillant Général, Vie Scolaire, Administration',
        categoryFilter: 'ABSENCE',
        studentId: _children.length == 1 ? _children.first['id'] as int? : null,
        icon: Icons.event_available_rounded,
        avatarBg: const Color(0xFF059669),
        messages: attendanceMsgs,
        unreadCount: unreadAttendance,
      ),
    );

    // 4. Canal Comptabilité & Scolarité (Paiements, Reçus & Échéances)
    final financeMsgs = _messages.where((m) {
      final cat = (m['category'] ?? '').toString().toUpperCase();
      return cat == 'SCOLARITE' || cat == 'FINANCE' || cat == 'PAIEMENT';
    }).toList();
    final unreadFinance = financeMsgs
        .where((m) => m['is_from_school'] == true && m['is_read'] == false)
        .length;

    threads.add(
      _DiscussionThread(
        id: 'comptabilite',
        title: 'COMPTABILITÉ & SCOLARITÉ',
        subtitle: financeMsgs.isNotEmpty
            ? '${financeMsgs.first['is_from_school'] == true ? "Caisse:" : "✓✓ Vous:"} ${financeMsgs.first['subject'] ?? financeMsgs.first['body']}'
            : 'Notifications de paiements, reçus PDF et questions sur les frais',
        participants: 'Service Comptabilité, Caisse, Direction',
        categoryFilter: 'SCOLARITE',
        studentId: _children.length == 1 ? _children.first['id'] as int? : null,
        icon: Icons.account_balance_wallet_rounded,
        avatarBg: const Color(0xFFD97706),
        messages: financeMsgs,
        unreadCount: unreadFinance,
      ),
    );

    // 5. Canal Bulletins & Pédagogie
    final bulletinMsgs = _messages.where((m) {
      final cat = (m['category'] ?? '').toString().toUpperCase();
      return cat == 'BULLETIN' || cat == 'NOTES';
    }).toList();
    final unreadBulletin = bulletinMsgs
        .where((m) => m['is_from_school'] == true && m['is_read'] == false)
        .length;

    threads.add(
      _DiscussionThread(
        id: 'pedagogie_bulletins',
        title: 'PÉDAGOGIE & BULLETINS SCOLAIRES',
        subtitle: bulletinMsgs.isNotEmpty
            ? 'Pédagogie: 📄 ${bulletinMsgs.first['subject'] ?? bulletinMsgs.first['body']}'
            : 'Publication des bulletins trimestriels/semestriels et résultats',
        participants: 'Direction des Études, Censeur, Enseignants',
        categoryFilter: 'BULLETIN',
        studentId: _children.length == 1 ? _children.first['id'] as int? : null,
        icon: Icons.workspace_premium_rounded,
        avatarBg: const Color(0xFF2563EB),
        messages: bulletinMsgs,
        unreadCount: unreadBulletin,
      ),
    );

    // Si l'utilisateur est Admin/Direction et qu'il y a des messages de parents spécifiques
    if (_children.isEmpty && _messages.isNotEmpty) {
      final Map<int, List<Map<String, dynamic>>> byGuardian = {};
      for (final m in _messages) {
        final int? gId = m['guardian_id'] as int?;
        if (gId != null) {
          byGuardian.putIfAbsent(gId, () => []).add(m);
        }
      }
      byGuardian.forEach((gId, gMsgs) {
        final first = gMsgs.first;
        final String gName = first['guardian_name']?.toString() ?? 'Parent d\'élève';
        final String sName = first['student_name']?.toString() ?? '';
        final int unread = gMsgs.where((m) => m['is_from_school'] == false && m['is_read'] == false).length;

        threads.add(
          _DiscussionThread(
            id: 'guardian_$gId',
            title: gName,
            subtitle: '${first['subject'] ?? ''} — ${first['body'] ?? ''}',
            participants: sName.isNotEmpty ? 'Parent de $sName' : 'Parent d\'élève',
            categoryFilter: 'MESSAGE',
            guardianId: gId,
            studentId: first['student_id'] as int?,
            icon: Icons.family_restroom_rounded,
            avatarBg: AppTheme.primaryPurpleLight,
            messages: gMsgs,
            unreadCount: unread,
          ),
        );
      });
    }

    // Appliquer les filtres (Toutes / Non lues / Annonces / Enfants)
    return threads.where((t) {
      if (_activeFilter == 'UNREAD' && t.unreadCount == 0) return false;
      if (_activeFilter == 'ANNONCE' && t.categoryFilter != 'ANNONCE') return false;
      if (_activeFilter == 'CHILDREN' && t.studentId == null) return false;

      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchTitle = t.title.toLowerCase().contains(q);
        final matchSub = t.subtitle.toLowerCase().contains(q);
        final matchMsg = t.messages.any((m) =>
            (m['subject'] ?? '').toString().toLowerCase().contains(q) ||
            (m['body'] ?? '').toString().toLowerCase().contains(q));
        return matchTitle || matchSub || matchMsg;
      }
      return true;
    }).toList();
  }

  void _openThread(_DiscussionThread thread) {
    _markThreadMessagesRead(thread.messages);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ChatConversationScreen(
          thread: thread,
          children: _children,
          onMessageSent: () => _fetchMessages(isInitial: false),
        ),
      ),
    );
  }

  void _showComposeModal({
    String? initialCategory,
    String? initialSubject,
    int? initialStudentId,
  }) {
    final subjectCtrl = TextEditingController(text: initialSubject ?? '');
    final bodyCtrl = TextEditingController();
    String selectedCategory = initialCategory ?? 'MESSAGE';
    int? modalStudentId = initialStudentId ??
        (_children.isNotEmpty ? _children.first['id'] as int? : null);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Nouvelle discussion avec l\'école',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.primaryPurple,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_children.length > 1) ...[
                const Text(
                  'Enfant concerné',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<int?>(
                  value: modalStudentId,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: _children.map((c) {
                    return DropdownMenuItem<int?>(
                      value: c['id'] as int?,
                      child: Text(
                        '${c['name']} (${c['class']})',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) => setModalState(() => modalStudentId = val),
                ),
                const SizedBox(height: 12),
              ],
              const Text(
                'Service destinataire',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textMuted,
                ),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: selectedCategory,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'MESSAGE',
                    child: Text('Direction & Secrétariat (Général)', style: TextStyle(fontSize: 13)),
                  ),
                  DropdownMenuItem(
                    value: 'ABSENCE',
                    child: Text('Vie Scolaire (Justification d\'absence / retard)', style: TextStyle(fontSize: 13)),
                  ),
                  DropdownMenuItem(
                    value: 'SCOLARITE',
                    child: Text('Comptabilité & Caisse (Scolarité / Reçus)', style: TextStyle(fontSize: 13)),
                  ),
                  DropdownMenuItem(
                    value: 'REUNION',
                    child: Text('Demande d\'audience / Rendez-vous enseignant', style: TextStyle(fontSize: 13)),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) setModalState(() => selectedCategory = val);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: subjectCtrl,
                decoration: InputDecoration(
                  labelText: 'Objet de la discussion',
                  hintText: 'Ex: Justification d\'absence / Question scolarité',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: bodyCtrl,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Votre message',
                  hintText: 'Entrez votre message...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSending
                      ? null
                      : () async {
                          final subj = subjectCtrl.text.trim();
                          final body = bodyCtrl.text.trim();
                          if (body.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Veuillez saisir votre message.')),
                            );
                            return;
                          }
                          setState(() => _isSending = true);
                          setModalState(() {});
                          try {
                            final res = await ApiService.post('/messages', {
                              'student_id': modalStudentId,
                              'category': selectedCategory,
                              'subject': subj.isEmpty ? 'Message parent' : subj,
                              'body': body,
                            });
                            if (!mounted) return;
                            Navigator.pop(ctx);
                            if (res.statusCode == 200 || res.statusCode == 201) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  backgroundColor: Color(0xFF059669),
                                  content: Text('Message envoyé dans la discussion.'),
                                ),
                              );
                              _fetchMessages(isInitial: false);
                            }
                          } finally {
                            if (mounted) setState(() => _isSending = false);
                          }
                        },
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: Text(
                    _isSending ? 'Envoi en cours...' : 'Envoyer le message',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryPurple,
                    foregroundColor: AppTheme.accentGold,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final threads = _buildDiscussionThreads();
    final totalUnread = _messages
        .where((m) => m['is_from_school'] == true && m['is_read'] == false)
        .length;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppTheme.accentGold,
        foregroundColor: AppTheme.primaryPurple,
        elevation: 0,
        title: const Text(
          'Discussions',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: AppTheme.primaryPurple,
            letterSpacing: 0.2,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: InkWell(
              onTap: () => _showComposeModal(),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: AppTheme.primaryPurple,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.add_comment_rounded,
                  color: AppTheme.accentGold,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryPurple))
          : Column(
              children: [
                // Barre de recherche + Filtres style messagerie moderne
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                  child: Column(
                    children: [
                      // Barre de recherche arrondie
                      Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: TextField(
                          controller: _searchCtrl,
                          onChanged: (v) => setState(() => _searchQuery = v),
                          style: const TextStyle(fontSize: 13.5, color: AppTheme.textDark),
                          decoration: InputDecoration(
                            hintText: 'Rechercher ou démarrer une discussion',
                            hintStyle: const TextStyle(
                              fontSize: 13.5,
                              color: AppTheme.textMuted,
                              fontWeight: FontWeight.w500,
                            ),
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              color: AppTheme.textMuted,
                              size: 20,
                            ),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      _searchCtrl.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                            contentPadding: const EdgeInsets.symmetric(vertical: 11),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Pilules de filtre (Toutes, Non lues, Annonces, Enfants)
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _FilterChipPill(
                              label: 'Toutes',
                              isSelected: _activeFilter == 'ALL',
                              onTap: () => setState(() => _activeFilter = 'ALL'),
                            ),
                            const SizedBox(width: 8),
                            _FilterChipPill(
                              label: totalUnread > 0 ? 'Non lues $totalUnread' : 'Non lues',
                              isSelected: _activeFilter == 'UNREAD',
                              onTap: () => setState(() => _activeFilter = 'UNREAD'),
                            ),
                            const SizedBox(width: 8),
                            _FilterChipPill(
                              label: 'Communiqués',
                              isSelected: _activeFilter == 'ANNONCE',
                              onTap: () => setState(() => _activeFilter = 'ANNONCE'),
                            ),
                            if (_children.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              _FilterChipPill(
                                label: 'Enfants ${_children.length}',
                                isSelected: _activeFilter == 'CHILDREN',
                                onTap: () => setState(() => _activeFilter = 'CHILDREN'),
                              ),
                            ],
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () => _showComposeModal(),
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: AppTheme.borderLight),
                                ),
                                child: const Icon(
                                  Icons.add_rounded,
                                  size: 18,
                                  color: AppTheme.primaryPurple,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1, color: AppTheme.borderLight),

                // Liste des discussions
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.only(bottom: 110, top: 4),
                    itemCount: threads.length,
                    separatorBuilder: (_, __) => const Divider(
                      height: 1,
                      indent: 78,
                      endIndent: 16,
                      color: Color(0xFFF1F5F9),
                    ),
                    itemBuilder: (context, index) {
                      final thread = threads[index];
                      final lastDate = thread.messages.isNotEmpty
                          ? _formatShortListDate(thread.messages.first['date']?.toString() ?? '')
                          : 'Actif';

                      return Material(
                        color: thread.isPinned
                            ? AppTheme.primaryPurple.withValues(alpha: 0.04)
                            : Colors.white,
                        child: InkWell(
                          onTap: () => _openThread(thread),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                // Avatar circulaire
                                _ThreadAvatar(
                                  isOfficialLogo: thread.isOfficialLogo,
                                  icon: thread.icon,
                                  bgColor: thread.avatarBg,
                                  title: thread.title,
                                ),
                                const SizedBox(width: 14),

                                // Titre + Aperçu du dernier message
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              thread.title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 14.5,
                                                fontWeight: thread.unreadCount > 0
                                                    ? FontWeight.w900
                                                    : FontWeight.w800,
                                                color: AppTheme.textDark,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            lastDate,
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: thread.unreadCount > 0
                                                  ? FontWeight.w900
                                                  : FontWeight.w600,
                                              color: thread.unreadCount > 0
                                                  ? const Color(0xFF10B981)
                                                  : AppTheme.textMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 5),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              thread.subtitle,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: thread.unreadCount > 0
                                                    ? FontWeight.w700
                                                    : FontWeight.w500,
                                                color: thread.unreadCount > 0
                                                    ? AppTheme.textDark
                                                    : AppTheme.textMuted,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          if (thread.unreadCount > 0)
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 7,
                                                vertical: 2.5,
                                              ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF10B981),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                '${thread.unreadCount}',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                            )
                                          else if (thread.isPinned)
                                            const Icon(
                                              Icons.push_pin_outlined,
                                              size: 16,
                                              color: AppTheme.textMuted,
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  String _formatShortListDate(String raw) {
    if (raw.isEmpty) return '';
    final parts = raw.split(' ');
    if (parts.length == 2) {
      return parts[1]; // HH:mm
    }
    return raw;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// VUE 2 : FIL DE CONVERSATION (CHAT TEMPS RÉEL STYLE MESSAGERIE)
// ─────────────────────────────────────────────────────────────────────────────
class _ChatConversationScreen extends StatefulWidget {
  final _DiscussionThread thread;
  final List<Map<String, dynamic>> children;
  final VoidCallback onMessageSent;

  const _ChatConversationScreen({
    required this.thread,
    required this.children,
    required this.onMessageSent,
  });

  @override
  State<_ChatConversationScreen> createState() => _ChatConversationScreenState();
}

class _ChatConversationScreenState extends State<_ChatConversationScreen> {
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  bool _isSending = false;
  late List<Map<String, dynamic>> _chatMessages;
  late String _selectedCategory;
  int? _selectedStudentId;
  Timer? _chatSyncTimer;

  @override
  void initState() {
    super.initState();
    // On affiche du plus ancien au plus récent (ordre chronologique de chat)
    _chatMessages = List<Map<String, dynamic>>.from(widget.thread.messages.reversed);
    _selectedCategory = widget.thread.categoryFilter;
    _selectedStudentId = widget.thread.studentId ??
        (widget.children.isNotEmpty ? widget.children.first['id'] as int? : null);

    _chatSyncTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted) _refreshThreadMessages();
    });
  }

  @override
  void dispose() {
    _chatSyncTimer?.cancel();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _refreshThreadMessages() async {
    try {
      final res = await ApiService.get('/messages');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) {
          final all = ((data['messages'] as List<dynamic>?) ?? [])
              .map((m) => Map<String, dynamic>.from(m as Map))
              .toList();

          List<Map<String, dynamic>> filtered;
          if (widget.thread.id == 'official_direction') {
            filtered = all.where((m) {
              final cat = (m['category'] ?? '').toString().toUpperCase();
              return m['is_broadcast'] == true ||
                  cat == 'ANNONCE' ||
                  cat == 'REUNION' ||
                  cat == 'EXAMEN' ||
                  cat == 'CONVOCATION';
            }).toList();
          } else if (widget.thread.studentId != null &&
              widget.thread.id.startsWith('child_')) {
            filtered = all
                .where((m) => m['student_id'] == widget.thread.studentId)
                .toList();
          } else if (widget.thread.id == 'vie_scolaire') {
            filtered = all.where((m) {
              final cat = (m['category'] ?? '').toString().toUpperCase();
              return cat == 'ABSENCE' || cat == 'RETARD' || cat == 'PRESENCE';
            }).toList();
          } else if (widget.thread.id == 'comptabilite') {
            filtered = all.where((m) {
              final cat = (m['category'] ?? '').toString().toUpperCase();
              return cat == 'SCOLARITE' || cat == 'FINANCE' || cat == 'PAIEMENT';
            }).toList();
          } else if (widget.thread.id == 'pedagogie_bulletins') {
            filtered = all.where((m) {
              final cat = (m['category'] ?? '').toString().toUpperCase();
              return cat == 'BULLETIN' || cat == 'NOTES';
            }).toList();
          } else if (widget.thread.guardianId != null) {
            filtered = all
                .where((m) => m['guardian_id'] == widget.thread.guardianId)
                .toList();
          } else {
            filtered = all;
          }

          if (mounted) {
            setState(() {
              _chatMessages = filtered.reversed.toList();
            });
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _sendQuickMessage() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    final subjectAuto = _selectedCategory == 'ABSENCE'
        ? 'Justification d\'absence / Assiduité'
        : (_selectedCategory == 'SCOLARITE'
            ? 'Question Scolarité & Paiement'
            : 'Message · ${widget.thread.title}');

    try {
      final res = await ApiService.post('/messages', {
        'student_id': _selectedStudentId,
        'guardian_id': widget.thread.guardianId,
        'category': _selectedCategory,
        'subject': subjectAuto,
        'body': text,
      });

      if (res.statusCode == 200 || res.statusCode == 201) {
        _inputCtrl.clear();
        widget.onMessageSent();
        await _refreshThreadMessages();
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(
            _scrollCtrl.position.maxScrollExtent + 120,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _showCategoryPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Objet du message',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.primaryPurple,
                ),
              ),
              const SizedBox(height: 10),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFEDE9FE),
                  child: Icon(Icons.chat_bubble_outline, color: AppTheme.primaryPurple, size: 18),
                ),
                title: const Text('Message général à l\'administration', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                onTap: () {
                  setState(() => _selectedCategory = 'MESSAGE');
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFD1FAE5),
                  child: Icon(Icons.event_available, color: Color(0xFF059669), size: 18),
                ),
                title: const Text('Justification d\'absence ou de retard', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                onTap: () {
                  setState(() => _selectedCategory = 'ABSENCE');
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFFEF3C7),
                  child: Icon(Icons.receipt_long, color: Color(0xFFD97706), size: 18),
                ),
                title: const Text('Question sur un paiement / Reçu de scolarité', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                onTap: () {
                  setState(() => _selectedCategory = 'SCOLARITE');
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFDBEAFE),
                  child: Icon(Icons.handshake_outlined, color: Color(0xFF2563EB), size: 18),
                ),
                title: const Text('Demande de rendez-vous / Audience', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                onTap: () {
                  setState(() => _selectedCategory = 'REUNION');
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEDE8F5),
      appBar: AppBar(
        backgroundColor: AppTheme.accentGold,
        foregroundColor: AppTheme.primaryPurple,
        elevation: 1,
        titleSpacing: 0,
        title: Row(
          children: [
            _ThreadAvatar(
              isOfficialLogo: widget.thread.isOfficialLogo,
              icon: widget.thread.icon,
              bgColor: widget.thread.avatarBg,
              title: widget.thread.title,
              radius: 19,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.thread.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.primaryPurple,
                    ),
                  ),
                  Text(
                    widget.thread.participants,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryPurple.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Fil des messages (Bulles de conversation)
          Expanded(
            child: _chatMessages.isEmpty
                ? Center(
                    child: Container(
                      margin: const EdgeInsets.all(24),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.forum_rounded,
                            size: 42,
                            color: AppTheme.primaryPurple,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            widget.thread.title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              color: AppTheme.primaryPurple,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Aucun message dans cette discussion pour le moment.\nÉcrivez votre message ci-dessous pour échanger directement avec l\'établissement.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(12, 14, 12, 16),
                    itemCount: _chatMessages.length,
                    itemBuilder: (context, index) {
                      final msg = _chatMessages[index];
                      final String rawDate = msg['date']?.toString() ?? '';
                      final String dayLabel = rawDate.split(' ').first;
                      final String prevDayLabel = index > 0
                          ? (_chatMessages[index - 1]['date']?.toString() ?? '')
                              .split(' ')
                              .first
                          : '';
                      final bool showDateHeader =
                          dayLabel.isNotEmpty && dayLabel != prevDayLabel;

                      return Column(
                        children: [
                          if (showDateHeader)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF260438).withValues(alpha: 0.82),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  dayLabel,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          _ChatMessageBubble(msg: msg),
                        ],
                      );
                    },
                  ),
          ),

          // Barre de saisie inférieure style messagerie instantanée
          Container(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
            decoration: BoxDecoration(
              color: const Color(0xFF260438),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  // Bouton pièce jointe / choix du motif
                  InkWell(
                    onTap: _showCategoryPicker,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.attach_file_rounded,
                        color: AppTheme.accentGold,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Champ de texte "Entrez un message"
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.18),
                        ),
                      ),
                      child: TextField(
                        controller: _inputCtrl,
                        minLines: 1,
                        maxLines: 4,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: const InputDecoration(
                          hintText: 'Entrez un message',
                          hintStyle: TextStyle(
                            color: Colors.white60,
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          contentPadding: EdgeInsets.symmetric(vertical: 10),
                        ),
                        onSubmitted: (_) => _sendQuickMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Bouton d'envoi direct
                  InkWell(
                    onTap: _isSending ? null : _sendQuickMessage,
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: AppTheme.accentGold,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: _isSending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppTheme.primaryPurple,
                                ),
                              )
                            : const Icon(
                                Icons.send_rounded,
                                color: AppTheme.primaryPurple,
                                size: 20,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMessageBubble extends StatelessWidget {
  final Map<String, dynamic> msg;

  const _ChatMessageBubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    final bool isFromSchool = msg['is_from_school'] == true;
    final String senderName = msg['sender_name']?.toString() ??
        (isFromSchool ? 'DIRECTION CSP LES ROIS DU SAHEL' : 'VOUS');
    final String subject = msg['subject']?.toString() ?? '';
    final String body = msg['body']?.toString() ?? '';
    final String category = (msg['category'] ?? 'MESSAGE').toString().toUpperCase();
    final String? studentName = msg['student_name']?.toString();
    final String className = msg['class_name']?.toString() ?? '';
    final String rawDate = msg['date']?.toString() ?? '';
    final String timeOnly = rawDate.contains(' ') ? rawDate.split(' ').last : rawDate;

    String iconPrefix = '📢';
    if (category == 'ABSENCE' || category == 'RETARD') {
      iconPrefix = '🕒';
    } else if (category == 'SCOLARITE') {
      iconPrefix = '💳';
    } else if (category == 'BULLETIN') {
      iconPrefix = '📄';
    } else if (!isFromSchool) {
      iconPrefix = '✉️';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment:
            isFromSchool ? MainAxisAlignment.start : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isFromSchool) ...[
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: 8, top: 2),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.accentGold, width: 1.5),
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/logo_roi.jpeg',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.school,
                    size: 16,
                    color: AppTheme.primaryPurple,
                  ),
                ),
              ),
            ),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.78,
              ),
              padding: const EdgeInsets.fromLTRB(14, 11, 14, 9),
              decoration: BoxDecoration(
                color: isFromSchool ? Colors.white : const Color(0xFF3B0764),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(isFromSchool ? 4 : 16),
                  topRight: Radius.circular(isFromSchool ? 16 : 4),
                  bottomLeft: const Radius.circular(16),
                  bottomRight: const Radius.circular(16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nom de l'expéditeur en haut de la bulle
                  Text(
                    senderName.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: isFromSchool
                          ? const Color(0xFF0284C7)
                          : AppTheme.accentGold,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 5),

                  // Objet en gras avec icône (style "📢 COMMUNIQUÉ DE SERVICE")
                  if (subject.isNotEmpty) ...[
                    Text(
                      '$iconPrefix ${subject.toUpperCase()}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: isFromSchool ? AppTheme.textDark : Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Corps du message
                  Text(
                    body,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.42,
                      color: isFromSchool
                          ? const Color(0xFF1E293B)
                          : Colors.white.withValues(alpha: 0.95),
                    ),
                  ),

                  // Badge élève concerné + Heure en bas à droite
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (studentName != null && studentName.isNotEmpty)
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isFromSchool
                                  ? AppTheme.primaryPurple.withValues(alpha: 0.08)
                                  : Colors.white.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '🎓 $studentName ${className.isNotEmpty ? "($className)" : ""}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: isFromSchool
                                    ? AppTheme.primaryPurple
                                    : AppTheme.accentGoldLight,
                              ),
                            ),
                          ),
                        )
                      else
                        const SizedBox.shrink(),
                      const SizedBox(width: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            timeOnly,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: isFromSchool
                                  ? AppTheme.textMuted
                                  : Colors.white70,
                            ),
                          ),
                          if (!isFromSchool) ...[
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.done_all_rounded,
                              size: 15,
                              color: AppTheme.accentGold,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThreadAvatar extends StatelessWidget {
  final bool isOfficialLogo;
  final IconData icon;
  final Color bgColor;
  final String title;
  final double radius;

  const _ThreadAvatar({
    required this.isOfficialLogo,
    required this.icon,
    required this.bgColor,
    required this.title,
    this.radius = 25,
  });

  @override
  Widget build(BuildContext context) {
    if (isOfficialLogo) {
      return Container(
        width: radius * 2,
        height: radius * 2,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: AppTheme.accentGold, width: 2),
        ),
        child: ClipOval(
          child: Image.asset(
            'assets/images/logo_roi.jpeg',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Icon(
              Icons.school,
              color: AppTheme.primaryPurple,
              size: radius,
            ),
          ),
        ),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: bgColor,
      child: Icon(
        icon,
        color: Colors.white,
        size: radius * 0.9,
      ),
    );
  }
}

class _FilterChipPill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChipPill({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryPurple.withValues(alpha: 0.12)
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.primaryPurple : AppTheme.borderLight,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
            color: isSelected ? AppTheme.primaryPurple : AppTheme.textMuted,
          ),
        ),
      ),
    );
  }
}
