import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/models.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';
import 'group_detail_screen.dart';
import 'login_screen.dart';

class GroupsHomeScreen extends StatefulWidget {
  const GroupsHomeScreen({super.key});

  @override
  State<GroupsHomeScreen> createState() => _GroupsHomeScreenState();
}

class _GroupsHomeScreenState extends State<GroupsHomeScreen> {
  final _fs = FirestoreService();
  final _auth = AuthService();

  void _showCreateGroup() {
    final nameCtrl = TextEditingController();
    final upiIdCtrl = TextEditingController();
    final upiNameCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool loading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom),
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
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppTheme.divider,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('Create Group',
                      style: Theme.of(ctx).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text('Create a new expense group',
                      style: Theme.of(ctx).textTheme.bodyMedium),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Group name (e.g. Goa Trip)',
                      prefixIcon: Icon(Icons.group_rounded, size: 18),
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Enter group name' : null,
                  ),
                  const SizedBox(height: 12),
                  const _SectionLabel(label: 'Payment UPI (optional)'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: upiIdCtrl,
                    decoration: const InputDecoration(
                      hintText: 'UPI ID (e.g. aziz@upi)',
                      prefixIcon: Icon(Icons.qr_code_rounded, size: 18),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: upiNameCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Payee name (displayed on QR)',
                      prefixIcon: Icon(Icons.person_outline_rounded, size: 18),
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 20),
                  GradientButton(
                    label: 'Create Group',
                    icon: Icons.add_rounded,
                    isLoading: loading,
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      setModal(() => loading = true);
                      try {
                        final group = await _fs.createGroup(
                          name: nameCtrl.text.trim(),
                          createdBy: _auth.currentUser!,
                          upiId: upiIdCtrl.text.trim().isEmpty
                              ? null
                              : upiIdCtrl.text.trim(),
                          upiName: upiNameCtrl.text.trim().isEmpty
                              ? null
                              : upiNameCtrl.text.trim(),
                        );
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          _showJoinCode(group);
                        }
                      } catch (e) {
                        setModal(() => loading = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
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

  void _showJoinCode(GroupChat group) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: AppTheme.successGradient,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded, color: Colors.white, size: 32),
              ),
              const SizedBox(height: 16),
              Text('Group Created!',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text('Share this code so others can join',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      group.joinCode,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 38,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: group.joinCode));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Code copied!')),
                        );
                      },
                      child: const Icon(Icons.copy_rounded,
                          color: Colors.white70, size: 20),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              GradientButton(
                label: 'Open Group',
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GroupDetailScreen(group: group),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showJoinGroup() {
    final codeCtrl = TextEditingController();
    bool loading = false;
    String? error;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom),
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
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text('Join Group', style: Theme.of(ctx).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text('Enter the 4-digit code',
                    style: Theme.of(ctx).textTheme.bodyMedium),
                const SizedBox(height: 20),
                TextFormField(
                  controller: codeCtrl,
                  decoration: InputDecoration(
                    hintText: '0000',
                    prefixIcon: const Icon(Icons.tag_rounded, size: 18),
                    errorText: error,
                  ),
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 10,
                  ),
                  textAlign: TextAlign.center,
                  onChanged: (_) {
                    if (error != null) setModal(() => error = null);
                  },
                ),
                const SizedBox(height: 16),
                GradientButton(
                  label: 'Join Group',
                  icon: Icons.login_rounded,
                  isLoading: loading,
                  onPressed: () async {
                    if (codeCtrl.text.length != 4) {
                      setModal(() => error = 'Enter a 4-digit code');
                      return;
                    }
                    setModal(() {
                      loading = true;
                      error = null;
                    });
                    try {
                      final group = await _fs.joinGroup(
                        code: codeCtrl.text,
                        username: _auth.currentUser!,
                      );
                      if (group == null) {
                        setModal(() {
                          loading = false;
                          error = 'Group not found. Check the code.';
                        });
                      } else {
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => GroupDetailScreen(group: group),
                            ),
                          );
                        }
                      }
                    } catch (e) {
                      setModal(() {
                        loading = false;
                        error = 'Error: $e';
                      });
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
    final username = _auth.currentUser ?? 'User';

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
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Hey, $username 👋',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium),
                              Text('Your Groups',
                                  style: Theme.of(context)
                                      .textTheme
                                      .displayMedium),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            _auth.logout();
                            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
                          },
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withOpacity(0.06),
                                    blurRadius: 8),
                              ],
                            ),
                            child: const Icon(Icons.logout_rounded,
                                size: 20, color: AppTheme.textSecondary),
                          ),
                        ),
                      ],
                    ).animate().fadeIn().slideY(begin: -0.1, duration: 400.ms),

                    const SizedBox(height: 20),

                    // Create / Join buttons
                    Row(
                      children: [
                        Expanded(
                          child: _ActionCard(
                            icon: Icons.add_rounded,
                            label: 'Create Group',
                            sub: 'Start a new GC',
                            gradient: AppTheme.primaryGradient,
                            onTap: _showCreateGroup,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ActionCard(
                            icon: Icons.tag_rounded,
                            label: 'Join Group',
                            sub: 'Enter 4-digit code',
                            gradient: const LinearGradient(
                              colors: [Color(0xFF059669), Color(0xFF06B6D4)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            onTap: _showJoinGroup,
                          ),
                        ),
                      ],
                    ).animate().fadeIn(delay: 100.ms),

                    const SizedBox(height: 24),
                    Text('My Groups',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),

            // Groups stream
            StreamBuilder<List<GroupChat>>(
              stream: _fs.streamUserGroups(username),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const SliverToBoxAdapter(
                    child: Center(
                        child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(),
                    )),
                  );
                }

                final groups = snap.data ?? [];

                if (groups.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 48),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryPurple.withOpacity(0.08),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.group_outlined,
                                size: 40, color: AppTheme.primaryPurple),
                          ),
                          const SizedBox(height: 16),
                          Text('No groups yet',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium!
                                  .copyWith(
                                      color: AppTheme.textSecondary)),
                          const SizedBox(height: 4),
                          Text('Create or join a group to get started',
                              style: Theme.of(context).textTheme.bodyMedium),
                        ],
                      ).animate().fadeIn(delay: 200.ms),
                    ),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) {
                        final g = groups[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _GroupCard(
                            group: g,
                            currentUser: username,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => GroupDetailScreen(group: g),
                              ),
                            ),
                          ).animate().fadeIn(delay: (i * 60).ms).slideY(begin: 0.08),
                        );
                      },
                      childCount: groups.length,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sub-widgets ────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});
  @override
  Widget build(BuildContext context) => Text(label,
      style: Theme.of(context)
          .textTheme
          .labelLarge!
          .copyWith(fontSize: 12, color: AppTheme.textSecondary));
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sub;
  final LinearGradient gradient;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.sub,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7C3AED).withOpacity(0.2),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(height: 10),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14)),
            Text(sub,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.7), fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  final GroupChat group;
  final String currentUser;
  final VoidCallback onTap;

  const _GroupCard({
    required this.group,
    required this.currentUser,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isCreator = group.createdBy == currentUser;
    return SurfaceCard(
      padding: const EdgeInsets.all(16),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: AppTheme.cardGradient,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                group.name.isNotEmpty ? group.name[0].toUpperCase() : 'G',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 20),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(group.name,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium!
                        .copyWith(fontSize: 15)),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(Icons.people_rounded,
                        size: 12, color: AppTheme.textLight),
                    const SizedBox(width: 4),
                    Text('${group.members.length} members',
                        style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.divider,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        group.joinCode,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'monospace',
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (isCreator)
                StatusBadge(
                    label: 'CREATOR', color: AppTheme.primaryPurple),
              if (group.upiId != null) ...[
                const SizedBox(height: 4),
                const Icon(Icons.qr_code_rounded,
                    size: 16, color: AppTheme.success),
              ],
              const SizedBox(height: 4),
              const Icon(Icons.chevron_right_rounded,
                  color: AppTheme.textLight),
            ],
          ),
        ],
      ),
    );
  }
}
