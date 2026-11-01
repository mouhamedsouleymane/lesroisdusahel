import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../services/api_service.dart';
import 'messages_screen.dart';

class FinancesScreen extends StatefulWidget {
  final int? initialStudentId;

  const FinancesScreen({
    super.key,
    this.initialStudentId,
  });

  @override
  State<FinancesScreen> createState() => _FinancesScreenState();
}

class _FinancesScreenState extends State<FinancesScreen> {
  bool _isLoading = true;
  Timer? _syncTimer;
  int? _selectedStudentId;
  List<Map<String, dynamic>> _children = [];
  double _totalDue = 0;
  double _totalPaid = 0;
  double _totalRemaining = 0;
  double _recoveryRate = 0;
  List<Map<String, dynamic>> _invoices = [];
  List<Map<String, dynamic>> _payments = [];

  @override
  void initState() {
    super.initState();
    _selectedStudentId = widget.initialStudentId;
    _fetchFinances(isInitial: true);
    // Synchronisation automatique toutes les 10 secondes
    _syncTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) _fetchFinances(isInitial: false);
    });
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchFinances({bool isInitial = false}) async {
    if (isInitial) setState(() => _isLoading = true);
    try {
      final endpoint = _selectedStudentId != null
          ? '/finances?student_id=$_selectedStudentId'
          : '/finances';
      final res = await ApiService.get(endpoint);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) {
          final summary = data['summary'] ?? {};
          final list = List<Map<String, dynamic>>.from(data['invoices'] ?? []);
          final payList = List<Map<String, dynamic>>.from(data['payments'] ?? []);
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
              _totalDue = (summary['total_due'] as num?)?.toDouble() ?? 0;
              _totalPaid = (summary['total_paid'] as num?)?.toDouble() ?? 0;
              _totalRemaining = (summary['total_remaining'] as num?)?.toDouble() ?? 0;
              _recoveryRate = (summary['recovery_rate'] as num?)?.toDouble() ?? 0;
              _invoices = list;
              _payments = payList;
              _isLoading = false;
            });
          }
          return;
        }
      }
    } catch (e) {
      debugPrint('Erreur finances: $e');
    }

    if (mounted) {
      setState(() {
        if (isInitial) {
          _totalDue = 0;
          _totalPaid = 0;
          _totalRemaining = 0;
          _recoveryRate = 0;
          _invoices = [];
          _payments = [];
        }
        _isLoading = false;
      });
    }
  }

  void _onSelectChild(int? studentId) {
    setState(() {
      _selectedStudentId = studentId;
    });
    _fetchFinances(isInitial: true);
  }

  void _showReceiptDialog(Map<String, dynamic> receiptData) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.verified_rounded, color: Color(0xFF059669)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Reçu Officiel ${receiptData['receipt_number'] ?? receiptData['invoice_number'] ?? ""}',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppTheme.primaryPurple),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('COMPLEXE SCOLAIRE PRIVÉ LES ROIS DU SAHEL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppTheme.accentGoldDark)),
            const Divider(height: 20),
            _ReceiptRow(label: 'Élève', value: receiptData['student_name']?.toString() ?? '-'),
            _ReceiptRow(label: 'Classe', value: receiptData['class_name']?.toString() ?? '-'),
            _ReceiptRow(label: 'Libellé', value: receiptData['fee_name']?.toString() ?? 'Frais de scolarité'),
            _ReceiptRow(label: 'Montant réglé', value: '${(receiptData['amount'] ?? receiptData['amount_paid'] ?? 0).toInt()} FCFA'),
            _ReceiptRow(label: 'Date', value: (receiptData['payment_date'] ?? receiptData['created_at'] ?? '').toString()),
            _ReceiptRow(label: 'Statut', value: 'CERTIFIÉ PAYÉ'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fermer', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryPurple)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedChild = _selectedStudentId != null
        ? _children.where((c) => c['id'] == _selectedStudentId).firstOrNull
        : null;

    final double progressRatio = _totalDue > 0
        ? (_totalPaid / _totalDue).clamp(0.0, 1.0)
        : 1.0;

    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Scolarité',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppTheme.primaryPurple),
            ),
            if (selectedChild != null)
              Text(
                '${selectedChild['name']} - ${selectedChild['class']}',
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
          : RefreshIndicator(
              color: AppTheme.primaryPurple,
              onRefresh: _fetchFinances,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 105),
                children: [
                  if (_children.length > 1) ...[
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Row(
                        children: [
                          _FinanceStudentChip(
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
                              child: _FinanceStudentChip(
                                label: className.isNotEmpty ? '$firstName · $className' : firstName,
                                isSelected: _selectedStudentId == id,
                                onTap: () => _onSelectChild(id),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],

                  // 1. CARTE SYNTHÈSE FRAIS DE SCOLARITÉ AVEC BARRE DE PROGRESSION (Style Maquette Image 4)
                  Container(
                    padding: const EdgeInsets.all(20),
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              selectedChild != null
                                  ? 'Frais de scolarité (${selectedChild['first_name']})'
                                  : 'Frais de scolarité',
                              style: const TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.accentGold.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '$_recoveryRate % réglé',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 11,
                                  color: AppTheme.primaryPurple,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '${_totalDue.toInt()}',
                              style: const TextStyle(
                                color: AppTheme.textDark,
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'FCFA',
                              style: TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: progressRatio,
                            minHeight: 11,
                            backgroundColor: const Color(0xFFE2E8F0),
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Déjà payé', style: TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 2),
                                Text(
                                  '${_totalPaid.toInt()} FCFA',
                                  style: const TextStyle(
                                    color: Color(0xFF059669),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text('Solde restant', style: TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 2),
                                Text(
                                  '${_totalRemaining.toInt()} FCFA',
                                  style: TextStyle(
                                    color: _totalRemaining == 0 ? const Color(0xFF059669) : AppTheme.primaryPurple,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                          decoration: BoxDecoration(
                            color: _totalRemaining == 0
                                ? const Color(0xFFD1FAE5)
                                : const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _totalRemaining == 0 ? Icons.check_circle_outline : Icons.alarm_rounded,
                                size: 16,
                                color: _totalRemaining == 0 ? const Color(0xFF059669) : AppTheme.accentGoldDark,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  _totalRemaining == 0
                                      ? 'Scolarité intégralement réglée (À jour)'
                                      : 'Prochaine échéance : Solde de ${_totalRemaining.toInt()} FCFA à régulariser',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: _totalRemaining == 0 ? const Color(0xFF059669) : AppTheme.accentGoldDark,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  // 2. HISTORIQUE DES PAIEMENTS (Style Maquette Image 4)
                  const Text(
                    'Historique des paiements',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppTheme.textDark),
                  ),
                  const SizedBox(height: 12),

                  if (_invoices.isEmpty)
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
                          Icon(Icons.verified_outlined, size: 42, color: const Color(0xFF10B981).withValues(alpha: 0.8)),
                          const SizedBox(height: 10),
                          const Text(
                            'Aucun reste à payer facturé sur ce dossier',
                            style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textDark, fontSize: 13.5),
                          ),
                        ],
                      ),
                    )
                  else
                    ..._invoices.map((inv) {
                      final isPaid = inv['is_paid'] == true;
                      final String? studentName = inv['student_name']?.toString();
                      final String className = inv['class_name']?.toString() ?? '';
                      return InkWell(
                        onTap: isPaid ? () => _showReceiptDialog(inv) : null,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppTheme.borderLight),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isPaid ? const Color(0xFFD1FAE5) : const Color(0xFFFEF3C7),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isPaid ? Icons.check : Icons.schedule,
                                  size: 18,
                                  color: isPaid ? const Color(0xFF059669) : AppTheme.accentGoldDark,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      inv['fee_name'] ?? 'Frais de scolarité',
                                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: AppTheme.textDark),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      studentName != null && studentName.isNotEmpty
                                          ? '${isPaid ? "Reçu disponible" : "Émis le ${inv['created_at']}"} · $studentName ($className)'
                                          : (isPaid ? 'Reçu disponible' : 'Émis le ${inv['created_at']}'),
                                      style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${(inv['amount_due'] as num?)?.toInt()} FCFA',
                                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5, color: AppTheme.textDark),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isPaid ? 'Payé' : 'Reste dû',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11,
                                      color: isPaid ? const Color(0xFF059669) : Colors.red.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),

                  const SizedBox(height: 16),

                  // 3. BOUTON "TÉLÉCHARGER UN REÇU" (Style Maquette Image 4)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (_payments.isNotEmpty) {
                          _showReceiptDialog(_payments.first);
                        } else if (_invoices.any((i) => i['is_paid'] == true)) {
                          _showReceiptDialog(_invoices.firstWhere((i) => i['is_paid'] == true));
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Aucun reçu de paiement réglé disponible pour le moment.')),
                          );
                        }
                      },
                      icon: const Icon(Icons.receipt_long_rounded, size: 18),
                      label: const Text(
                        'Télécharger un reçu',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // 4. ENCADRÉ D'AIDE MESSAGERIE INTERNE (Style Maquette Image 4)
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MessagesScreen(
                          initialStudentId: _selectedStudentId,
                          initialCategory: 'SCOLARITE',
                          initialSubject: 'Question sur les frais de scolarité',
                          openComposerOnInit: true,
                        ),
                      ),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: const Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Une question sur un paiement ? Écrivez à l\'administration depuis la messagerie.',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textMuted,
                                fontWeight: FontWeight.w600,
                                height: 1.35,
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.primaryPurple),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  final String label;
  final String value;

  const _ReceiptRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted, fontWeight: FontWeight.w600)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12.5, color: AppTheme.textDark, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _FinanceStudentChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FinanceStudentChip({
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
