import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/models.dart';
import '../services/firestore_service.dart';
import '../services/algorand_service.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';
import 'gc_bill_details_screen.dart';

class GcCreateBillScreen extends StatefulWidget {
  final GroupChat group;
  const GcCreateBillScreen({super.key, required this.group});

  @override
  State<GcCreateBillScreen> createState() => _GcCreateBillScreenState();
}

class _GcCreateBillScreenState extends State<GcCreateBillScreen>
    with SingleTickerProviderStateMixin {
  final _fs = FirestoreService();
  final _algo = AlgorandService();

  List<Expense> _expenses = [];
  bool _loadingExpenses = true;
  bool _isGenerating = false;

  // Bill participants = group members (all selected by default)
  late List<String> _selectedMembers;
  // Custom split toggle
  bool _equalSplit = true;
  final Map<String, TextEditingController> _customAmounts = {};

  // Calculator state
  late TabController _tabCtrl;
  String _calcDisplay = '0';
  String _calcExpression = '';
  double? _calcResult;

  @override
  void initState() {
    super.initState();
    _selectedMembers = List.from(widget.group.members);
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadExpenses();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    for (final c in _customAmounts.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadExpenses() async {
    try {
      final snap = await _fs.streamExpenses(widget.group.id).first;
      setState(() {
        _expenses = snap;
        _loadingExpenses = false;
        // Init custom amount controllers per member
        for (final m in widget.group.members) {
          _customAmounts[m] = TextEditingController();
        }
      });
    } catch (_) {
      setState(() => _loadingExpenses = false);
    }
  }

  double get _total => _expenses.fold(0.0, (s, e) => s + e.amount);

  double get _sharePerPerson =>
      _selectedMembers.isEmpty ? 0 : _total / _selectedMembers.length;

  // ── Calculator logic ───────────────────────────────────────────────────────
  void _calcPress(String key) {
    setState(() {
      if (key == 'C') {
        _calcDisplay = '0';
        _calcExpression = '';
        _calcResult = null;
        return;
      }
      if (key == '⌫') {
        if (_calcExpression.isNotEmpty) {
          _calcExpression = _calcExpression.substring(0, _calcExpression.length - 1);
          if (_calcExpression.isEmpty) _calcExpression = '';
          _calcDisplay = _calcExpression.isEmpty ? '0' : _calcExpression;
        }
        return;
      }
      if (key == '=') {
        try {
          final result = _evalExpression(_calcExpression);
          _calcResult = result;
          _calcDisplay = _formatCalcNum(result);
          _calcExpression = _calcDisplay;
        } catch (_) {
          _calcDisplay = 'Error';
        }
        return;
      }
      if (key == '÷') {
        _calcExpression += '/';
      } else if (key == '×') {
        _calcExpression += '*';
      } else {
        _calcExpression += key;
      }
      _calcDisplay = _calcExpression;
    });
  }

  double _evalExpression(String expr) {
    // Simple recursive expression evaluator (handles +, -, *, /)
    expr = expr.replaceAll(' ', '');
    if (expr.isEmpty) return 0;

    // Find last + or - not inside parens
    for (int i = expr.length - 1; i >= 0; i--) {
      if (expr[i] == '+' && i > 0) {
        return _evalExpression(expr.substring(0, i)) +
            _evalExpression(expr.substring(i + 1));
      }
      if (expr[i] == '-' && i > 0) {
        return _evalExpression(expr.substring(0, i)) -
            _evalExpression(expr.substring(i + 1));
      }
    }
    // Find last * or /
    for (int i = expr.length - 1; i >= 0; i--) {
      if (expr[i] == '*' && i > 0) {
        return _evalExpression(expr.substring(0, i)) *
            _evalExpression(expr.substring(i + 1));
      }
      if (expr[i] == '/' && i > 0) {
        final b = _evalExpression(expr.substring(i + 1));
        if (b == 0) throw Exception('Division by zero');
        return _evalExpression(expr.substring(0, i)) / b;
      }
    }
    return double.parse(expr);
  }

  String _formatCalcNum(double n) {
    if (n == n.roundToDouble()) return n.round().toString();
    return n.toStringAsFixed(2);
  }

  void _useCalcResult() {
    if (_calcResult != null && _calcResult! > 0) {
      // Add as a new expense
      final expense = Expense(
        title: 'Calculator entry',
        amount: _calcResult!,
        addedBy: 'calc',
      );
      setState(() {
        _expenses = [expense, ..._expenses];
        _calcResult = null;
        _calcDisplay = '0';
        _calcExpression = '';
      });
      _tabCtrl.animateTo(0); // switch back to bill tab
    }
  }

  // ── Generate Bill ──────────────────────────────────────────────────────────
  Future<void> _generateBill() async {
    if (_expenses.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('No expenses to bill')));
      return;
    }
    if (_selectedMembers.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Select at least one member')));
      return;
    }

    setState(() => _isGenerating = true);

    try {
      // Build participants with shares
      final participants = _selectedMembers.map((name) {
        double share;
        if (_equalSplit) {
          share = _sharePerPerson;
        } else {
          final ctrl = _customAmounts[name];
          share = double.tryParse(ctrl?.text.trim() ?? '') ?? _sharePerPerson;
        }
        return Participant(name: name, share: share);
      }).toList();

      // Create bill object
      final bill = Bill(
        groupId: widget.group.id,
        expenses: _expenses,
        participants: participants,
        totalAmount: _total,
      );

      // Save to Firestore immediately (so user sees it fast)
      await _fs.createBill(bill);

      // Record on Algorand in background
      final record = await _algo.recordBillOnChain(
        billId: bill.id,
        totalAmount: _total,
        participants: _selectedMembers,
      );

      if (record != null) {
        await _fs.updateBillBlockchain(widget.group.id, bill.id, record);
      }

      final finalBill = bill.copyWith(blockchainRecord: record);

      setState(() => _isGenerating = false);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>
                GcBillDetailsScreen(bill: finalBill, group: widget.group),
          ),
        );
      }
    } catch (e) {
      setState(() => _isGenerating = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
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
                              ]),
                          child: const Icon(Icons.arrow_back_rounded, size: 20),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Generate Bill',
                                style: Theme.of(context).textTheme.titleLarge),
                            Text(widget.group.name,
                                style: Theme.of(context).textTheme.bodyMedium),
                          ],
                        ),
                      ),
                    ],
                  ).animate().fadeIn(duration: 300.ms),
                  const SizedBox(height: 14),
                  // Tabs: Bill Setup | Calculator
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8)
                        ]),
                    child: TabBar(
                      controller: _tabCtrl,
                      indicator: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(10)),
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      labelColor: Colors.white,
                      unselectedLabelColor: AppTheme.textSecondary,
                      labelStyle: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700),
                      tabs: const [
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.receipt_rounded, size: 14),
                              SizedBox(width: 5),
                              Text('Bill Setup'),
                            ],
                          ),
                        ),
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.calculate_rounded, size: 14),
                              SizedBox(width: 5),
                              Text('Calculator'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  _buildBillSetupTab(),
                  _buildCalculatorTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Bill Setup Tab ─────────────────────────────────────────────────────────
  Widget _buildBillSetupTab() {
    if (_loadingExpenses) {
      return const Center(child: CircularProgressIndicator());
    }

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary card
                GradientHeaderCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Bill Total',
                          style: TextStyle(color: Colors.white70, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text('₹${_total.toStringAsFixed(2)}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1)),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        children: [
                          _chip('${_expenses.length} expenses'),
                          _chip('${_selectedMembers.length} members'),
                          if (_selectedMembers.isNotEmpty)
                            _chip('₹${_sharePerPerson.toStringAsFixed(0)}/each'),
                        ],
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 100.ms),

                const SizedBox(height: 18),

                // Expenses list
                Text('Expenses', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),

                if (_expenses.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14)),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline_rounded,
                            color: AppTheme.textLight, size: 18),
                        SizedBox(width: 10),
                        Text('No expenses in this group yet',
                            style: TextStyle(color: AppTheme.textSecondary)),
                      ],
                    ),
                  )
                else
                  SurfaceCard(
                    padding: const EdgeInsets.all(0),
                    child: Column(
                      children: [
                        ..._expenses.asMap().entries.map((e) {
                          final i = e.key;
                          final exp = e.value;
                          return Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                child: Row(
                                  children: [
                                    Text(exp.title,
                                        style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500)),
                                    const Spacer(),
                                    Text('₹${exp.amount.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14)),
                                  ],
                                ),
                              ),
                              if (i < _expenses.length - 1)
                                const Divider(height: 1, indent: 14, endIndent: 14),
                            ],
                          );
                        }),
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          child: Row(
                            children: [
                              const Text('Total',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15)),
                              const Spacer(),
                              Text('₹${_total.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                      color: AppTheme.primaryPurple)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 18),

                // Split type
                Row(
                  children: [
                    Text('Split',
                        style: Theme.of(context).textTheme.titleMedium),
                    const Spacer(),
                    _SplitToggle(
                      isEqual: _equalSplit,
                      onChanged: (v) => setState(() => _equalSplit = v),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Members with amounts
                ...widget.group.members.map((name) {
                  final selected = _selectedMembers.contains(name);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          if (selected) {
                            _selectedMembers.remove(name);
                          } else {
                            _selectedMembers.add(name);
                          }
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppTheme.primaryPurple.withOpacity(0.06)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selected
                                ? AppTheme.primaryPurple.withOpacity(0.3)
                                : AppTheme.divider,
                          ),
                        ),
                        child: Row(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: selected
                                    ? AppTheme.primaryPurple
                                    : Colors.transparent,
                                border: Border.all(
                                  color: selected
                                      ? AppTheme.primaryPurple
                                      : AppTheme.textLight,
                                  width: 2,
                                ),
                              ),
                              child: selected
                                  ? const Icon(Icons.check_rounded,
                                      size: 12, color: Colors.white)
                                  : null,
                            ),
                            const SizedBox(width: 10),
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                gradient: AppTheme.cardGradient,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14)),
                            ),
                            if (!_equalSplit && selected)
                              SizedBox(
                                width: 90,
                                child: TextFormField(
                                  controller: _customAmounts[name],
                                  keyboardType: const TextInputType.numberWithOptions(
                                      decimal: true),
                                  decoration: const InputDecoration(
                                    hintText: '₹ amount',
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 8),
                                    isDense: true,
                                  ),
                                  style: const TextStyle(fontSize: 13),
                                ),
                              )
                            else if (selected)
                              Text(
                                '₹${_sharePerPerson.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: AppTheme.primaryPurple),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),

                const SizedBox(height: 16),

                // Algorand info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1B4B).withOpacity(0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppTheme.primaryPurple.withOpacity(0.12)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.verified_rounded,
                          color: AppTheme.primaryPurple, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Bill will be recorded on Algorand TestNet for immutable proof.',
                          style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textPrimary.withOpacity(0.65),
                              height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 200.ms),

                const SizedBox(height: 18),

                GradientButton(
                  label: 'Generate Bill',
                  icon: Icons.bolt_rounded,
                  isLoading: _isGenerating,
                  onPressed: _isGenerating ? null : _generateBill,
                ).animate().fadeIn(delay: 250.ms),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _chip(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20)),
        child: Text(label,
            style: const TextStyle(
                color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
      );

  // ── Calculator Tab ─────────────────────────────────────────────────────────
  Widget _buildCalculatorTab() {
    final keys = [
      ['C', '⌫', '÷', '×'],
      ['7', '8', '9', '-'],
      ['4', '5', '6', '+'],
      ['1', '2', '3', '='],
      ['0', '.', '→ Add to Bill', ''],
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        children: [
          // Display
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1E1B4B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (_calcExpression.isNotEmpty && _calcDisplay != _calcExpression)
                  Text(
                    _calcExpression,
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 14, fontFamily: 'monospace'),
                  ),
                Text(
                  _calcDisplay,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 42,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1),
                ),
                if (_calcResult != null)
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.success.withOpacity(0.3)),
                    ),
                    child: Text(
                      'Tap "→ Add to Bill" to use this amount',
                      style: TextStyle(
                          color: AppTheme.success,
                          fontSize: 11,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
              ],
            ),
          ).animate().fadeIn(delay: 100.ms),

          const SizedBox(height: 16),

          // Keypad
          Expanded(
            child: Column(
              children: keys.map((row) {
                return Expanded(
                  child: Row(
                    children: row.asMap().entries.map((e) {
                      final key = e.value;
                      if (key.isEmpty) return const Expanded(child: SizedBox());

                      final isOp = ['÷', '×', '-', '+'].contains(key);
                      final isAction = ['C', '⌫', '='].contains(key);
                      final isAddBill = key == '→ Add to Bill';
                      final isZero = key == '0';

                      Color bg;
                      Color textColor;
                      if (isAddBill) {
                        bg = AppTheme.success;
                        textColor = Colors.white;
                      } else if (key == '=') {
                        bg = AppTheme.primaryPurple;
                        textColor = Colors.white;
                      } else if (isOp) {
                        bg = AppTheme.primaryBlue.withOpacity(0.12);
                        textColor = AppTheme.primaryBlue;
                      } else if (isAction) {
                        bg = AppTheme.error.withOpacity(0.1);
                        textColor = AppTheme.error;
                      } else {
                        bg = Colors.white;
                        textColor = AppTheme.textPrimary;
                      }

                      return Expanded(
                        flex: isAddBill ? 2 : 1,
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: GestureDetector(
                            onTap: () {
                              if (isAddBill) {
                                _useCalcResult();
                              } else {
                                _calcPress(key);
                              }
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 80),
                              decoration: BoxDecoration(
                                color: bg,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2))
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  key,
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: isAddBill ? 12 : 20,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Split Toggle ──────────────────────────────────────────────────────────────
class _SplitToggle extends StatelessWidget {
  final bool isEqual;
  final ValueChanged<bool> onChanged;
  const _SplitToggle({required this.isEqual, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.divider)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _btn('Equal', isEqual, () => onChanged(true)),
          const SizedBox(width: 4),
          _btn('Custom', !isEqual, () => onChanged(false)),
        ],
      ),
    );
  }

  Widget _btn(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: active ? AppTheme.primaryGradient : null,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}
