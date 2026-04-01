import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';

class GcBillDetailsScreen extends StatefulWidget {
  final Bill bill;
  final GroupChat group;

  const GcBillDetailsScreen({
    super.key,
    required this.bill,
    required this.group,
  });

  @override
  State<GcBillDetailsScreen> createState() => _GcBillDetailsScreenState();
}

class _GcBillDetailsScreenState extends State<GcBillDetailsScreen> {
  final _fs = FirestoreService();

  // ── Payment QR modal ───────────────────────────────────────────────────────
  void _showPaymentQr(
      BuildContext ctx, Participant participant, Bill bill, GroupChat group) {
    final upiId = group.upiId;
    if (upiId == null || upiId.isEmpty) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: const Text('No UPI ID set. Go to group settings to add one.'),
          action: SnackBarAction(label: 'OK', onPressed: () {}),
        ),
      );
      return;
    }

    // UPI deep-link format
    final amount = participant.share.toStringAsFixed(2);
    final name = (group.upiName ?? '').isNotEmpty ? group.upiName! : 'SplitChain';
    final note = Uri.encodeComponent('SplitChain bill payment');
    final upiUrl =
        'upi://pay?pa=$upiId&pn=${Uri.encodeComponent(name)}&am=$amount&cu=INR&tn=$note';

    bool _confirming = false;

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (sheetCtx, setSheet) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                    color: AppTheme.divider,
                    borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 20),

              // Header
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                        gradient: AppTheme.cardGradient,
                        shape: BoxShape.circle),
                    child: Center(
                      child: Text(
                        participant.name.isNotEmpty
                            ? participant.name[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Pay ${participant.name}',
                            style: Theme.of(ctx).textTheme.titleMedium),
                        Text('Scan QR or tap to open UPI app',
                            style: Theme.of(ctx).textTheme.bodyMedium),
                      ],
                    ),
                  ),
                  Text(
                    '₹${participant.share.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primaryPurple),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // QR code
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF1E1B4B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    // QR
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16)),
                      child: QrImageView(
                        data: upiUrl,
                        version: QrVersions.auto,
                        size: 200,
                        backgroundColor: Colors.white,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: Color(0xFF1E1B4B),
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: Color(0xFF1E1B4B),
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // UPI ID
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.qr_code_rounded,
                            color: Colors.white54, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          upiId,
                          style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontFamily: 'monospace'),
                        ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    Text(
                      name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15),
                    ),

                    const SizedBox(height: 14),

                    // Open UPI app button
                    GestureDetector(
                      onTap: () async {
                        try {
                          final uri = Uri.parse(upiUrl);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri,
                                mode: LaunchMode.externalApplication);
                          } else {
                            // fallback: try gpay intent
                            await launchUrl(
                                Uri.parse('intent://upi/pay?pa=$upiId'
                                    '&am=$amount&cu=INR#Intent;'
                                    'scheme=upi;end'),
                                mode: LaunchMode.externalApplication);
                          }
                        } catch (_) {
                          if (sheetCtx.mounted) {
                            ScaffoldMessenger.of(sheetCtx).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Install a UPI app like GPay or PhonePe')),
                            );
                          }
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.2)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.open_in_new_rounded,
                                color: Colors.white, size: 16),
                            SizedBox(width: 8),
                            Text('Open UPI App',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // "I've paid" confirm button
              GestureDetector(
                onTap: _confirming
                    ? null
                    : () async {
                        setSheet(() => _confirming = true);
                        await _fs.markParticipantPaid(
                          groupId: bill.groupId,
                          billId: bill.id,
                          participantId: participant.id,
                          paid: true,
                        );
                        if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                      },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: double.infinity,
                  height: 54,
                  decoration: BoxDecoration(
                    gradient: _confirming
                        ? const LinearGradient(
                            colors: [Color(0xFF6EE7B7), Color(0xFF34D399)])
                        : AppTheme.successGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                          color: AppTheme.success.withOpacity(0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 6))
                    ],
                  ),
                  child: Center(
                    child: _confirming
                        ? const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation(
                                        Colors.white)),
                              ),
                              SizedBox(width: 10),
                              Text('Marking as paid...',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700)),
                            ],
                          )
                        : const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_rounded,
                                  color: Colors.white, size: 20),
                              SizedBox(width: 8),
                              Text("I've Paid!",
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16)),
                            ],
                          ),
                  ),
                ),
              ),

              const SizedBox(height: 8),
              Text("Tap after completing the payment",
                  style: Theme.of(ctx).textTheme.bodyMedium,
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openExplorer(AlgorandRecord record) async {
    final url = Uri.parse(record.explorerUrl);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        // Stream the bill live from Firestore so payment toggles update in real-time
        child: StreamBuilder<Bill?>(
          stream: _fs.streamBill(widget.bill.groupId, widget.bill.id),
          builder: (context, snap) {
            final bill = snap.data ?? widget.bill;
            final paid = bill.paidCount;
            final total = bill.totalCount;
            final progress = total == 0 ? 0.0 : paid / total;
            final allPaid = bill.isSettled;

            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Header row ─────────────────────────────────────
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                        color: Colors.black.withOpacity(0.06),
                                        blurRadius: 8)
                                  ],
                                ),
                                child:
                                    const Icon(Icons.arrow_back_rounded, size: 20),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Bill Details',
                                      style:
                                          Theme.of(context).textTheme.titleLarge),
                                  Text(widget.group.name,
                                      style:
                                          Theme.of(context).textTheme.bodyMedium),
                                ],
                              ),
                            ),
                            if (allPaid)
                              const StatusBadge(
                                  label: 'SETTLED', color: AppTheme.success),
                          ],
                        ).animate().fadeIn().slideX(begin: -0.05, duration: 300.ms),

                        const SizedBox(height: 20),

                        // ── Progress card ───────────────────────────────────
                        GradientHeaderCard(
                          gradient: allPaid
                              ? AppTheme.successGradient
                              : AppTheme.cardGradient,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text('Total Bill',
                                            style: TextStyle(
                                                color: Colors.white70,
                                                fontSize: 12)),
                                        const SizedBox(height: 4),
                                        Text(
                                          '₹${bill.totalAmount.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 30,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: -0.8),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '$paid / $total paid',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 20,
                                            fontWeight: FontWeight.w800),
                                      ),
                                      Text(
                                        '${(progress * 100).toInt()}% complete',
                                        style: const TextStyle(
                                            color: Colors.white60,
                                            fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  backgroundColor:
                                      Colors.white.withOpacity(0.2),
                                  valueColor:
                                      const AlwaysStoppedAnimation(Colors.white),
                                  minHeight: 6,
                                ),
                              ),
                              if (allPaid) ...[
                                const SizedBox(height: 10),
                                const Row(
                                  children: [
                                    Icon(Icons.celebration_rounded,
                                        color: Colors.white, size: 14),
                                    SizedBox(width: 6),
                                    Text('All settled! 🎉',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ).animate().fadeIn(delay: 100.ms),

                        const SizedBox(height: 20),

                        // ── UPI info if set ─────────────────────────────────
                        if (widget.group.upiId != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppTheme.success.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: AppTheme.success.withOpacity(0.25)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.qr_code_rounded,
                                    color: AppTheme.success, size: 18),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.group.upiName ??
                                            'Payment QR Ready',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                            color: AppTheme.success),
                                      ),
                                      Text(
                                        widget.group.upiId!,
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: AppTheme.textSecondary,
                                            fontFamily: 'monospace'),
                                      ),
                                    ],
                                  ),
                                ),
                                const Text('Tap PAY to scan',
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: AppTheme.textLight)),
                              ],
                            ),
                          ).animate().fadeIn(delay: 150.ms),
                          const SizedBox(height: 14),
                        ],

                        // ── Payment Status ──────────────────────────────────
                        Text('Payment Status',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 10),

                        ...bill.participants.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final p = entry.value;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _ParticipantPayRow(
                              participant: p,
                              group: widget.group,
                              onPay: () =>
                                  _showPaymentQr(context, p, bill, widget.group),
                              onToggle: () async {
                                await _fs.markParticipantPaid(
                                  groupId: bill.groupId,
                                  billId: bill.id,
                                  participantId: p.id,
                                  paid: !p.hasPaid,
                                );
                              },
                            )
                                .animate()
                                .fadeIn(delay: (180 + idx * 50).ms)
                                .slideX(begin: 0.04),
                          );
                        }),

                        const SizedBox(height: 20),

                        // ── Expense Breakdown ───────────────────────────────
                        Text('Expense Breakdown',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 10),

                        SurfaceCard(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            children: [
                              ...bill.expenses.map(
                                (e) => Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 7),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 7,
                                        height: 7,
                                        decoration: const BoxDecoration(
                                          gradient: AppTheme.primaryGradient,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                          child: Text(e.title,
                                              style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w500))),
                                      Text('₹${e.amount.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13)),
                                    ],
                                  ),
                                ),
                              ),
                              const Divider(height: 16),
                              Row(
                                children: [
                                  const Text('Total',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14)),
                                  const Spacer(),
                                  Text(
                                    '₹${bill.totalAmount.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                        color: AppTheme.primaryPurple),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ).animate().fadeIn(delay: 350.ms),

                        const SizedBox(height: 20),

                        // ── Blockchain Record ───────────────────────────────
                        if (bill.blockchainRecord != null) ...[
                          Text('Blockchain Record',
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 10),
                          BlockchainRecordCard(
                            txId: bill.blockchainRecord!.txId,
                            network: bill.blockchainRecord!.network,
                            status: bill.blockchainRecord!.status,
                            confirmedRound:
                                bill.blockchainRecord!.confirmedRound,
                            onViewExplorer: () =>
                                _openExplorer(bill.blockchainRecord!),
                          ),
                        ] else ...[
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppTheme.divider),
                            ),
                            child: const Row(
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation(
                                          AppTheme.primaryPurple)),
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'Recording on Algorand blockchain...',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: AppTheme.textSecondary),
                                ),
                              ],
                            ),
                          ).animate().fadeIn(),
                        ],

                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ── Participant Pay Row ────────────────────────────────────────────────────────
class _ParticipantPayRow extends StatelessWidget {
  final Participant participant;
  final GroupChat group;
  final VoidCallback onPay;
  final VoidCallback onToggle;

  const _ParticipantPayRow({
    required this.participant,
    required this.group,
    required this.onPay,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final p = participant;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: p.hasPaid
            ? AppTheme.success.withOpacity(0.05)
            : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: p.hasPaid
              ? AppTheme.success.withOpacity(0.3)
              : AppTheme.divider,
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          // Tap-to-toggle checkbox
          GestureDetector(
            onTap: onToggle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: p.hasPaid ? AppTheme.success : Colors.transparent,
                border: Border.all(
                  color: p.hasPaid ? AppTheme.success : AppTheme.textLight,
                  width: 2,
                ),
              ),
              child: p.hasPaid
                  ? const Icon(Icons.check_rounded,
                      size: 14, color: Colors.white)
                  : null,
            ),
          ),

          const SizedBox(width: 10),

          // Avatar
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              gradient: p.hasPaid
                  ? AppTheme.successGradient
                  : AppTheme.cardGradient,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13),
              ),
            ),
          ),

          const SizedBox(width: 10),

          // Name + status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: p.hasPaid
                            ? AppTheme.textSecondary
                            : AppTheme.textPrimary)),
                if (p.hasPaid && p.paidAt != null)
                  Text(
                    'Paid · ${_timeAgo(p.paidAt!)}',
                    style: const TextStyle(
                        fontSize: 10,
                        color: AppTheme.success,
                        fontWeight: FontWeight.w500),
                  ),
              ],
            ),
          ),

          // Amount
          Text(
            '₹${p.share.toStringAsFixed(2)}',
            style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color:
                    p.hasPaid ? AppTheme.success : AppTheme.textPrimary),
          ),

          const SizedBox(width: 8),

          // PAY button (only if not paid)
          if (!p.hasPaid && group.upiId != null)
            GestureDetector(
              onTap: onPay,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                        color: AppTheme.primaryPurple.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3))
                  ],
                ),
                child: const Text('PAY',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5)),
              ),
            )
          else if (p.hasPaid)
            StatusBadge(label: 'PAID', color: AppTheme.success)
          else
            StatusBadge(label: 'PENDING', color: AppTheme.warning),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}
