import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';
import '../services/algorand_service.dart';
import 'bill_details_screen.dart';

class CreateBillScreen extends StatefulWidget {
  final List<Expense> expenses;
  final double totalAmount;

  const CreateBillScreen({
    super.key,
    required this.expenses,
    required this.totalAmount,
  });

  @override
  State<CreateBillScreen> createState() => _CreateBillScreenState();
}

class _CreateBillScreenState extends State<CreateBillScreen> {
  final List<String> _participants = [];
  final _nameController = TextEditingController();
  bool _isGenerating = false;
  final _algorand = AlgorandService();

  double get _sharePerPerson =>
      _participants.isEmpty ? 0 : widget.totalAmount / _participants.length;

  void _addParticipant() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    if (_participants.contains(name)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Participant already added')),
      );
      return;
    }
    setState(() => _participants.add(name));
    _nameController.clear();
    FocusScope.of(context).unfocus();
  }

  void _removeParticipant(String name) {
    setState(() => _participants.remove(name));
  }

  Future<void> _generateBill() async {
    if (_participants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one participant')),
      );
      return;
    }

    setState(() => _isGenerating = true);

    // Build bill
    final participants = _participants
        .map((name) => Participant(name: name, share: _sharePerPerson))
        .toList();

    final bill = Bill(
      expenses: widget.expenses,
      participants: participants,
      totalAmount: widget.totalAmount, groupId: '',
    );

    // Submit to Algorand TestNet
    final record = await _algorand.recordBillOnChain(
      billId: bill.id,
      totalAmount: widget.totalAmount,
      participants: _participants,
    );

    final finalBill = bill.copyWith(blockchainRecord: record);

    setState(() => _isGenerating = false);

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BillDetailsScreen(bill: finalBill),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  children: [
                    // Back + title
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
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.arrow_back_rounded, size: 20),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Text(
                          'Create Bill',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ).animate().fadeIn().slideX(begin: -0.05, duration: 300.ms),
                    const SizedBox(height: 20),

                    // Summary card
                    GradientHeaderCard(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6D28D9), Color(0xFF2563EB)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Bill Summary',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '₹${widget.totalAmount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _InfoChip(
                                icon: Icons.receipt_rounded,
                                label: '${widget.expenses.length} expenses',
                              ),
                              const SizedBox(width: 10),
                              _InfoChip(
                                icon: Icons.people_rounded,
                                label: '${_participants.length} people',
                              ),
                              if (_participants.isNotEmpty) ...[
                                const SizedBox(width: 10),
                                _InfoChip(
                                  icon: Icons.person_rounded,
                                  label: '₹${_sharePerPerson.toStringAsFixed(2)}/each',
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: 100.ms),

                    const SizedBox(height: 20),

                    // Add participant
                    SurfaceCard(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Add Participants',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Add everyone who will split this bill',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _nameController,
                                  decoration: const InputDecoration(
                                    hintText: 'Participant name',
                                    prefixIcon: Icon(
                                        Icons.person_add_rounded,
                                        size: 18),
                                  ),
                                  textCapitalization: TextCapitalization.words,
                                  onFieldSubmitted: (_) => _addParticipant(),
                                ),
                              ),
                              const SizedBox(width: 10),
                              GestureDetector(
                                onTap: _addParticipant,
                                child: Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    gradient: AppTheme.primaryGradient,
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.primaryPurple.withOpacity(0.3),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(Icons.add_rounded,
                                      color: Colors.white, size: 24),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: 150.ms),

                    const SizedBox(height: 16),

                    // Participants list
                    if (_participants.isNotEmpty) ...[
                      Row(
                        children: [
                          Text(
                            'Participants',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const Spacer(),
                          Text(
                            '${_participants.length} added',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ..._participants.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final name = entry.value;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: SurfaceCard(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    gradient: AppTheme.cardGradient,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      name[0].toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(name,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium!
                                              .copyWith(fontSize: 14)),
                                      Text(
                                        'Owes ₹${_sharePerPerson.toStringAsFixed(2)}',
                                        style:
                                            Theme.of(context).textTheme.bodyMedium,
                                      ),
                                    ],
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => _removeParticipant(name),
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: AppTheme.error.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.close_rounded,
                                      size: 16,
                                      color: AppTheme.error,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ).animate().fadeIn(delay: (idx * 40).ms).slideX(begin: -0.05),
                        );
                      }),
                      const SizedBox(height: 8),
                    ],

                    if (_participants.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Column(
                          children: [
                            Icon(Icons.group_add_rounded,
                                size: 40, color: AppTheme.textLight),
                            const SizedBox(height: 8),
                            Text(
                              'Add participants to split with',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium!
                                  .copyWith(color: AppTheme.textLight),
                            ),
                          ],
                        ).animate().fadeIn(delay: 200.ms),
                      ),

                    const SizedBox(height: 8),

                    // Blockchain info banner
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1B4B).withOpacity(0.05),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppTheme.primaryPurple.withOpacity(0.15),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.verified_rounded,
                              color: AppTheme.primaryPurple, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Generating the bill will record it on Algorand TestNet blockchain for immutable proof.',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textPrimary.withOpacity(0.7),
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: 250.ms),

                    const SizedBox(height: 20),

                    GradientButton(
                      label: 'Generate Bill',
                      icon: Icons.bolt_rounded,
                      isLoading: _isGenerating,
                      onPressed: _isGenerating ? null : _generateBill,
                    ).animate().fadeIn(delay: 300.ms),

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

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
