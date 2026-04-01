import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/models.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';
import 'gc_create_bill_screen.dart';
import 'gc_bill_details_screen.dart';

class GroupDetailScreen extends StatefulWidget {
  final GroupChat group;
  const GroupDetailScreen({super.key, required this.group});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen>
    with SingleTickerProviderStateMixin {
  final _fs = FirestoreService();
  final _auth = AuthService();
  late TabController _tab;
  late GroupChat _group;

  @override
  void initState() {
    super.initState();
    _group = widget.group;
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  // ── Add Expense sheet ──────────────────────────────────────────────────────
  void _showAddExpense() {
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool loading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36, height: 4,
                      decoration: BoxDecoration(
                          color: AppTheme.divider,
                          borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('Add Expense', style: Theme.of(ctx).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text('This will be shared across the group',
                      style: Theme.of(ctx).textTheme.bodyMedium),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Expense title (e.g. Pizza)',
                      prefixIcon: Icon(Icons.receipt_long_rounded, size: 18),
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Enter a title' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: amountCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      hintText: 'Amount (₹)',
                      prefixIcon: Icon(Icons.currency_rupee_rounded, size: 18),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Enter amount';
                      if (double.tryParse(v.trim()) == null ||
                          double.parse(v.trim()) <= 0)
                        return 'Enter a valid amount';
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  GradientButton(
                    label: 'Add Expense',
                    icon: Icons.add_rounded,
                    isLoading: loading,
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      setModal(() => loading = true);
                      try {
                        final expense = Expense(
                          title: titleCtrl.text.trim(),
                          amount: double.parse(amountCtrl.text.trim()),
                          addedBy: _auth.currentUser ?? '',
                        );
                        await _fs.addExpense(_group.id, expense);
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (e) {
                        setModal(() => loading = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text('Error: $e')));
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Edit UPI sheet ─────────────────────────────────────────────────────────
  void _showEditUpi() {
    final upiCtrl = TextEditingController(text: _group.upiId ?? '');
    final nameCtrl = TextEditingController(text: _group.upiName ?? '');
    bool loading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36, height: 4,
                    decoration: BoxDecoration(
                        color: AppTheme.divider,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 20),
                Text('Payment QR Settings',
                    style: Theme.of(ctx).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text('Set the UPI ID that members will scan to pay',
                    style: Theme.of(ctx).textTheme.bodyMedium),
                const SizedBox(height: 20),
                TextFormField(
                  controller: upiCtrl,
                  decoration: const InputDecoration(
                    hintText: 'UPI ID (e.g. aziz@ybl)',
                    prefixIcon: Icon(Icons.qr_code_rounded, size: 18),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Payee display name',
                    prefixIcon: Icon(Icons.person_outline_rounded, size: 18),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 20),
                GradientButton(
                  label: 'Save QR Settings',
                  icon: Icons.save_rounded,
                  isLoading: loading,
                  onPressed: () async {
                    if (upiCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('Enter a UPI ID')));
                      return;
                    }
                    setModal(() => loading = true);
                    try {
                      await _fs.updateGroupUpi(
                          _group.id, upiCtrl.text.trim(), nameCtrl.text.trim());
                      setState(() {
                        _group = _group.copyWith(
                          upiId: upiCtrl.text.trim(),
                          upiName: nameCtrl.text.trim(),
                        );
                      });
                      if (ctx.mounted) Navigator.pop(ctx);
                    } catch (e) {
                      setModal(() => loading = false);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                children: [
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
                          child: const Icon(Icons.arrow_back_rounded, size: 20),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_group.name,
                                style: Theme.of(context).textTheme.titleLarge,
                                overflow: TextOverflow.ellipsis),
                            Row(
                              children: [
                                Icon(Icons.people_rounded,
                                    size: 12, color: AppTheme.textLight),
                                const SizedBox(width: 4),
                                Text(
                                  '${_group.members.length} members',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () {
                                    Clipboard.setData(
                                        ClipboardData(text: _group.joinCode));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text('Join code copied!')),
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryPurple.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      children: [
                                        Text(
                                          _group.joinCode,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            fontFamily: 'monospace',
                                            color: AppTheme.primaryPurple,
                                          ),
                                        ),
                                        const SizedBox(width: 3),
                                        const Icon(Icons.copy_rounded,
                                            size: 10,
                                            color: AppTheme.primaryPurple),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // QR settings button
                      GestureDetector(
                        onTap: _showEditUpi,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _group.upiId != null
                                ? AppTheme.success.withOpacity(0.1)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: _group.upiId != null
                                ? Border.all(
                                    color: AppTheme.success.withOpacity(0.3))
                                : null,
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.06),
                                  blurRadius: 8)
                            ],
                          ),
                          child: Icon(Icons.qr_code_rounded,
                              size: 20,
                              color: _group.upiId != null
                                  ? AppTheme.success
                                  : AppTheme.textSecondary),
                        ),
                      ),
                    ],
                  ).animate().fadeIn().slideX(begin: -0.05, duration: 300.ms),

                  const SizedBox(height: 16),

                  // Tab bar
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8)
                      ],
                    ),
                    child: TabBar(
                      controller: _tab,
                      indicator: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      labelColor: Colors.white,
                      unselectedLabelColor: AppTheme.textSecondary,
                      labelStyle: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700),
                      unselectedLabelStyle: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w500),
                      tabs: const [
                        Tab(text: 'Expenses'),
                        Tab(text: 'Bills'),
                        Tab(text: 'Members'),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Tab views ────────────────────────────────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tab,
                children: [
                  _ExpensesTab(group: _group, onAdd: _showAddExpense),
                  _BillsTab(group: _group),
                  _MembersTab(group: _group),
                ],
              ),
            ),
          ],
        ),
      ),

      // FAB — context-aware per tab
      floatingActionButton: AnimatedBuilder(
        animation: _tab,
        builder: (_, __) {
          if (_tab.index == 0) {
            return FloatingActionButton.extended(
              onPressed: _showAddExpense,
              backgroundColor: Colors.transparent,
              elevation: 0,
              label: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color: AppTheme.primaryPurple.withOpacity(0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 6))
                  ],
                ),
                child: const Row(
                  children: [
                    Icon(Icons.add_rounded, color: Colors.white),
                    SizedBox(width: 6),
                    Text('Add Expense',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            );
          }
          if (_tab.index == 1) {
            return FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GcCreateBillScreen(group: _group),
                ),
              ),
              backgroundColor: Colors.transparent,
              elevation: 0,
              label: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color: AppTheme.primaryPurple.withOpacity(0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 6))
                  ],
                ),
                child: const Row(
                  children: [
                    Icon(Icons.bolt_rounded, color: Colors.white),
                    SizedBox(width: 6),
                    Text('New Bill',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

// ── Expenses Tab ──────────────────────────────────────────────────────────────

class _ExpensesTab extends StatelessWidget {
  final GroupChat group;
  final VoidCallback onAdd;
  const _ExpensesTab({required this.group, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();
    return StreamBuilder<List<Expense>>(
      stream: fs.streamExpenses(group.id),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final expenses = snap.data ?? [];
        final total = expenses.fold(0.0, (s, e) => s + e.amount);

        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: GradientHeaderCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Total Expenses',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 12)),
                            const SizedBox(height: 4),
                            Text('₹${total.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.8)),
                            Text('${expenses.length} items',
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.6),
                                    fontSize: 12)),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: onAdd,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.add_rounded,
                                  color: Colors.white, size: 18),
                              SizedBox(width: 4),
                              Text('Add',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (expenses.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 60),
                  child: Column(
                    children: [
                      Icon(Icons.receipt_long_outlined,
                          size: 48, color: AppTheme.textLight),
                      const SizedBox(height: 12),
                      Text('No expenses yet',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium!
                              .copyWith(color: AppTheme.textSecondary)),
                      const SizedBox(height: 4),
                      Text('Tap + to add one',
                          style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ).animate().fadeIn(),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) {
                      final e = expenses[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: SurfaceCard(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  gradient: AppTheme.cardGradient,
                                  borderRadius: BorderRadius.circular(11),
                                ),
                                child: Center(
                                  child: Text(
                                    e.title.isNotEmpty
                                        ? e.title[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(e.title,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14)),
                                    Text(
                                      e.addedBy.isNotEmpty
                                          ? 'by ${e.addedBy}'
                                          : _timeAgo(e.createdAt),
                                      style: Theme.of(ctx).textTheme.bodyMedium,
                                    ),
                                  ],
                                ),
                              ),
                              Text('₹${e.amount.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15)),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () =>
                                    fs.deleteExpense(group.id, e.id),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppTheme.error.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                      Icons.delete_outline_rounded,
                                      size: 15,
                                      color: AppTheme.error),
                                ),
                              ),
                            ],
                          ),
                        ).animate().fadeIn(delay: (i * 40).ms).slideX(begin: -0.04),
                      );
                    },
                    childCount: expenses.length,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

// ── Bills Tab ─────────────────────────────────────────────────────────────────

class _BillsTab extends StatelessWidget {
  final GroupChat group;
  const _BillsTab({required this.group});

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();
    return StreamBuilder<List<Bill>>(
      stream: fs.streamBills(group.id),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final bills = snap.data ?? [];

        if (bills.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 60),
            child: Column(
              children: [
                Icon(Icons.receipt_outlined, size: 48, color: AppTheme.textLight),
                const SizedBox(height: 12),
                Text('No bills yet',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium!
                        .copyWith(color: AppTheme.textSecondary)),
                const SizedBox(height: 4),
                Text('Tap "New Bill" to generate one',
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ).animate().fadeIn(),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          physics: const BouncingScrollPhysics(),
          itemCount: bills.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (ctx, i) {
            final bill = bills[i];
            return SurfaceCard(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      GcBillDetailsScreen(bill: bill, group: group),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: bill.isSettled
                          ? AppTheme.successGradient
                          : AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      bill.isSettled
                          ? Icons.check_circle_rounded
                          : Icons.receipt_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('₹${bill.totalAmount.toStringAsFixed(2)}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 16)),
                        Text(
                          '${bill.paidCount}/${bill.totalCount} paid · ${_fmtDate(bill.createdAt)}',
                          style: Theme.of(ctx).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      StatusBadge(
                        label: bill.isSettled ? 'SETTLED' : 'PENDING',
                        color: bill.isSettled
                            ? AppTheme.success
                            : AppTheme.warning,
                      ),
                      if (bill.blockchainRecord != null) ...[
                        const SizedBox(height: 4),
                        Row(children: [
                          const Icon(Icons.link_rounded,
                              size: 11, color: AppTheme.primaryPurple),
                          const SizedBox(width: 2),
                          Text('On-chain',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: AppTheme.primaryPurple,
                                  fontWeight: FontWeight.w600)),
                        ]),
                      ],
                    ],
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.chevron_right_rounded,
                      color: AppTheme.textLight),
                ],
              ),
            ).animate().fadeIn(delay: (i * 60).ms).slideY(begin: 0.06);
          },
        );
      },
    );
  }

  String _fmtDate(DateTime dt) {
    const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${dt.day} ${m[dt.month - 1]}';
  }
}

// ── Members Tab ───────────────────────────────────────────────────────────────

class _MembersTab extends StatelessWidget {
  final GroupChat group;
  const _MembersTab({required this.group});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      physics: const BouncingScrollPhysics(),
      children: [
        // Join code banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              const Text('Share Join Code',
                  style: TextStyle(
                      color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    group.joinCode,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 40,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 14),
                  ),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: group.joinCode));
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Code copied!')));
                    },
                    child: const Icon(Icons.copy_rounded,
                        color: Colors.white60, size: 20),
                  ),
                ],
              ),
              const Text('Others can join with this 4-digit code',
                  style: TextStyle(color: Colors.white60, fontSize: 11)),
            ],
          ),
        ).animate().fadeIn(),
        const SizedBox(height: 20),
        Text('${group.members.length} Members',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        ...group.members.asMap().entries.map((e) {
          final idx = e.key;
          final name = e.value;
          final isCreator = name == group.createdBy;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SurfaceCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: AppTheme.cardGradient,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                  ),
                  if (isCreator)
                    StatusBadge(label: 'CREATOR', color: AppTheme.primaryPurple),
                ],
              ),
            ).animate().fadeIn(delay: (idx * 50).ms).slideX(begin: -0.04),
          );
        }),
      ],
    );
  }
}
