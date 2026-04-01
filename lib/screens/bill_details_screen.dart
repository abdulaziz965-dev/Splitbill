import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';

class BillDetailsScreen extends StatefulWidget {
  final Bill bill;

  const BillDetailsScreen({super.key, required this.bill});

  @override
  State<BillDetailsScreen> createState() => _BillDetailsScreenState();
}

class _BillDetailsScreenState extends State<BillDetailsScreen>
    with TickerProviderStateMixin {
  late Bill _bill;
  late AnimationController _celebrateController;

  @override
  void initState() {
    super.initState();
    _bill = widget.bill;
    _celebrateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    // Animate in
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _celebrateController.forward();
    });
  }

  void _togglePayment(String participantId) {
    setState(() {
      final updatedParticipants = _bill.participants.map((p) {
        if (p.id == participantId) {
          return Participant(
            id: p.id,
            name: p.name,
            share: p.share,
            hasPaid: !p.hasPaid,
          );
        }
        return p;
      }).toList();
      _bill = _bill.copyWith(participants: updatedParticipants);
    });
  }

  Future<void> _openExplorer() async {
    final record = _bill.blockchainRecord;
    if (record == null) return;

    final url = Uri.parse(record.explorerUrl);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Opening: ${record.explorerUrl}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final paid = _bill.paidCount;
    final total = _bill.totalCount;
    final progress = total == 0 ? 0.0 : paid / total;
    final allPaid = paid == total && total > 0;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
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
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: const Icon(Icons.arrow_back_rounded, size: 20),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Bill Details',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            Text(
                              _formatDate(_bill.createdAt),
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                        const Spacer(),
                        if (allPaid)
                          const StatusBadge(
                            label: 'SETTLED',
                            color: AppTheme.success,
                          ),
                      ],
                    ).animate().fadeIn().slideX(begin: -0.05, duration: 300.ms),

                    const SizedBox(height: 20),

                    // Main card with total + progress
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Total Bill',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '₹${_bill.totalAmount.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 30,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.8,
                                      ),
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
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    '${(progress * 100).toInt()}% complete',
                                    style: const TextStyle(
                                      color: Colors.white60,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: progress,
                              backgroundColor: Colors.white.withOpacity(0.2),
                              valueColor: const AlwaysStoppedAnimation(Colors.white),
                              minHeight: 6,
                            ),
                          ),
                          if (allPaid) ...[
                            const SizedBox(height: 12),
                            const Row(
                              children: [
                                Icon(Icons.celebration_rounded,
                                    color: Colors.white, size: 16),
                                SizedBox(width: 6),
                                Text(
                                  'All settled! Bill is complete 🎉',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ).animate().fadeIn(delay: 100.ms),

                    const SizedBox(height: 20),

                    // Participants
                    Text(
                      'Payment Status',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),

                    ..._bill.participants.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final p = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: AnimatedCheckmark(
                          checked: p.hasPaid,
                          onChanged: (_) => _togglePayment(p.id),
                          label: p.name,
                          amount: p.share,
                        )
                            .animate()
                            .fadeIn(delay: (150 + idx * 60).ms)
                            .slideX(begin: 0.05),
                      );
                    }),

                    const SizedBox(height: 20),

                    // Expense breakdown
                    Text(
                      'Expense Breakdown',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),

                    SurfaceCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          ..._bill.expenses.map((e) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        gradient: AppTheme.primaryGradient,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        e.title,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '₹${e.amount.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              )),
                          const Divider(),
                          Row(
                            children: [
                              const Text(
                                'Total',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '₹${_bill.totalAmount.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  color: AppTheme.primaryPurple,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: 400.ms),

                    const SizedBox(height: 20),

                    // Blockchain Record
                    if (_bill.blockchainRecord != null) ...[
                      Text(
                        'Blockchain Record',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      BlockchainRecordCard(
                        txId: _bill.blockchainRecord!.txId,
                        network: _bill.blockchainRecord!.network,
                        status: _bill.blockchainRecord!.status,
                        confirmedRound: _bill.blockchainRecord!.confirmedRound,
                        onViewExplorer: _openExplorer,
                      ),
                    ],

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  @override
  void dispose() {
    _celebrateController.dispose();
    super.dispose();
  }
}
