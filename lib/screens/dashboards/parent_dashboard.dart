import 'dart:convert';
import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';
import '../../services/contact_service.dart';

class ParentDashboard extends StatefulWidget {
  final UserModel user;
  const ParentDashboard({super.key, required this.user});

  @override
  State<ParentDashboard> createState() => _ParentDashboardState();
}

class _ParentDashboardState extends State<ParentDashboard> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _children = [];

  @override
  void initState() {
    super.initState();
    _fetchParentData();
  }

  Future<void> _fetchParentData() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiService.get('/dashboard');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['children'] != null) {
          final list = data['children'] as List<dynamic>;
          if (list.isNotEmpty) {
            setState(() {
              _children = list.map((c) => {
                'name': c['name']?.toString() ?? 'Élève',
                'schoolClass': 'Classe : ${c['class'] ?? "Non assigné"}',
                'average': c['average']?.toString() ?? '15.0 / 20',
                'attendance': '${c['absences_count'] ?? 0} absence(s)',
                'unpaidAmount': c['unpaid_fcfa'] == 0 ? '0 FCFA (À jour)' : '${c['unpaid_fcfa']} FCFA',
                'isPaid': (c['unpaid_fcfa'] ?? 0) == 0,
              }).toList();
            });
          }
        }
      }
    } catch (_) {
      // Données locales si indisponible
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppTheme.primaryPurple,
      onRefresh: _fetchParentData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // En-tête Espace Parent
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF311042), AppTheme.primaryPurple],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.accentGold.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('ESPACE PARENT / TUTEUR', style: TextStyle(color: AppTheme.accentGoldLight, fontSize: 10, fontWeight: FontWeight.w900)),
                ),
                const SizedBox(height: 10),
                Text(widget.user.name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const Text('Suivi de scolarité de vos enfants · Année 2026-2027', style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Enfants scolarisés
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Mes enfants inscrits', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppTheme.textDark)),
              if (_isLoading)
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryPurple))
              else
                TextButton(
                  onPressed: _fetchParentData,
                  child: const Text('Actualiser', style: TextStyle(fontSize: 12, color: AppTheme.primaryPurple, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 8),

          if (_children.isNotEmpty)
            ..._children.map((c) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ChildCard(
                name: c['name'],
                schoolClass: c['schoolClass'],
                average: c['average'],
                attendance: c['attendance'],
                unpaidAmount: c['unpaidAmount'],
                isPaid: c['isPaid'],
              ),
            ))
          else ...const [
            _ChildCard(
              name: 'Ousmane Sani Abakar',
              schoolClass: 'Classe : 6ème A (Collège)',
              average: '15.75 / 20',
              attendance: '100 % présent',
              unpaidAmount: '0 FCFA (À jour)',
              isPaid: true,
            ),
            SizedBox(height: 10),
            _ChildCard(
              name: 'Ousmane Amina',
              schoolClass: 'Classe : CE2 A (Primaire)',
              average: '14.20 / 20',
              attendance: '1 absence justifiée',
              unpaidAmount: '15 000 FCFA (Tranche 2)',
              isPaid: false,
            ),
          ],

          const SizedBox(height: 20),

          // Services parents
          const Text('Services & Communication', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppTheme.textDark)),
          const SizedBox(height: 12),

          _ParentServiceTile(
            icon: Icons.article,
            title: 'Bulletins de notes officiels',
            subtitle: 'Consulter et télécharger les bulletins PDF',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Accès aux bulletins de notes ouvert.')),
              );
            },
          ),
          _ParentServiceTile(
            icon: Icons.payments,
            title: 'Frais scolaires & Reçus',
            subtitle: 'Historique des versements et solde dû',
            onTap: () {},
          ),
          _ParentServiceTile(
            icon: Icons.chat,
            title: 'Assistance WhatsApp Direct',
            subtitle: 'Échanger instantanément avec le secrétariat',
            onTap: () => ContactService.openWhatsApp(),
          ),
          _ParentServiceTile(
            icon: Icons.phone_in_talk,
            title: 'Ligne téléphonique directe',
            subtitle: 'Joindre l\'établissement au +227 90 00 11 22',
            onTap: () => ContactService.callSchool(),
          ),
          _ParentServiceTile(
            icon: Icons.notifications_active,
            title: 'Cahier de liaison & Alertes',
            subtitle: 'Messages de la direction et des professeurs',
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

class _ChildCard extends StatelessWidget {
  final String name;
  final String schoolClass;
  final String average;
  final String attendance;
  final String unpaidAmount;
  final bool isPaid;

  const _ChildCard({
    required this.name,
    required this.schoolClass,
    required this.average,
    required this.attendance,
    required this.unpaidAmount,
    required this.isPaid,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppTheme.primaryPurple.withValues(alpha: 0.1),
                radius: 22,
                child: const Text('🎓', style: TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: AppTheme.textDark)),
                    Text(schoolClass, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            children: [
              Expanded(
                child: _IndicatorMini(label: 'Moyenne', value: average, color: AppTheme.primaryPurple),
              ),
              Expanded(
                child: _IndicatorMini(label: 'Assiduité', value: attendance, color: Colors.blue.shade700),
              ),
              Expanded(
                child: _IndicatorMini(label: 'Scolarité', value: unpaidAmount, color: isPaid ? const Color(0xFF10B981) : Colors.red.shade700),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IndicatorMini extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _IndicatorMini({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color), maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    );
  }
}

class _ParentServiceTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ParentServiceTile({required this.icon, required this.title, required this.subtitle, required this.onTap});

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
