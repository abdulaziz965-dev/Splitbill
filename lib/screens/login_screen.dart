import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'groups_home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _auth = AuthService();

  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; _errorMessage = null; });
    await Future.delayed(const Duration(milliseconds: 800));

    final success = _auth.login(
      _usernameController.text.trim(),
      _passwordController.text,
    );

    if (success) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (_, animation, __) => const GroupsHomeScreen(),
            transitionsBuilder: (_, animation, __, child) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.05, 0), end: Offset.zero,
                ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
                child: child,
              ),
            ),
            transitionDuration: const Duration(milliseconds: 400),
          ),
        );
      }
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Invalid username or password. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 48),
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 80, height: 80,
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [BoxShadow(
                              color: AppTheme.primaryPurple.withOpacity(0.35),
                              blurRadius: 24, offset: const Offset(0, 10),
                            )],
                          ),
                          child: const Icon(Icons.link_rounded, color: Colors.white, size: 38),
                        ).animate()
                          .fadeIn(duration: 500.ms)
                          .scale(begin: const Offset(0.7, 0.7), duration: 500.ms, curve: Curves.easeOutBack),
                        const SizedBox(height: 20),
                        Text('SplitChain', style: Theme.of(context).textTheme.displayMedium)
                          .animate().fadeIn(delay: 150.ms).slideY(begin: 0.2, duration: 400.ms),
                        const SizedBox(height: 6),
                        Text('Blockchain-powered bill splitting',
                          style: Theme.of(context).textTheme.bodyMedium)
                          .animate().fadeIn(delay: 200.ms),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryPurple.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppTheme.primaryPurple.withOpacity(0.2)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(width: 6, height: 6,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF10B981), shape: BoxShape.circle)),
                              const SizedBox(width: 6),
                              const Text('Algorand TestNet',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                                  color: AppTheme.primaryPurple)),
                            ],
                          ),
                        ).animate().fadeIn(delay: 250.ms),
                      ],
                    ),
                  ),

                  const SizedBox(height: 44),

                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(color: AppTheme.primaryPurple.withOpacity(0.07),
                          blurRadius: 32, offset: const Offset(0, 8)),
                        BoxShadow(color: Colors.black.withOpacity(0.04),
                          blurRadius: 12, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Welcome back', style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 4),
                        Text('Sign in to your account', style: Theme.of(context).textTheme.bodyMedium),
                        const SizedBox(height: 24),

                        Text('Username', style: Theme.of(context).textTheme.labelLarge!
                          .copyWith(fontSize: 13, color: AppTheme.textPrimary)),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _usernameController,
                          decoration: const InputDecoration(
                            hintText: 'Enter your username',
                            prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                          ),
                          textInputAction: TextInputAction.next,
                          validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Please enter username' : null,
                          onChanged: (_) {
                            if (_errorMessage != null) setState(() => _errorMessage = null);
                          },
                        ),

                        const SizedBox(height: 16),

                        Text('Password', style: Theme.of(context).textTheme.labelLarge!
                          .copyWith(fontSize: 13, color: AppTheme.textPrimary)),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            hintText: 'Enter your password',
                            prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                            suffixIcon: GestureDetector(
                              onTap: () => setState(() => _obscurePassword = !_obscurePassword),
                              child: Icon(
                                _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                                size: 20, color: AppTheme.textLight,
                              ),
                            ),
                          ),
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _login(),
                          validator: (v) =>
                            v == null || v.isEmpty ? 'Please enter password' : null,
                          onChanged: (_) {
                            if (_errorMessage != null) setState(() => _errorMessage = null);
                          },
                        ),

                        if (_errorMessage != null) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppTheme.error.withOpacity(0.07),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.error.withOpacity(0.25)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline_rounded,
                                  color: AppTheme.error, size: 16),
                                const SizedBox(width: 8),
                                Expanded(child: Text(_errorMessage!,
                                  style: const TextStyle(color: AppTheme.error,
                                    fontSize: 12, fontWeight: FontWeight.w500))),
                              ],
                            ),
                          ).animate().fadeIn(duration: 300.ms).shake(),
                        ],

                        const SizedBox(height: 22),

                        GestureDetector(
                          onTap: _isLoading ? null : _login,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: double.infinity, height: 54,
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [BoxShadow(
                                color: AppTheme.primaryPurple.withOpacity(0.3),
                                blurRadius: 16, offset: const Offset(0, 6),
                              )],
                            ),
                            child: Center(
                              child: _isLoading
                                ? const Row(mainAxisSize: MainAxisSize.min, children: [
                                    SizedBox(width: 18, height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation(Colors.white))),
                                    SizedBox(width: 10),
                                    Text('Signing in...',
                                      style: TextStyle(color: Colors.white,
                                        fontWeight: FontWeight.w700)),
                                  ])
                                : const Row(mainAxisSize: MainAxisSize.min, children: [
                                    Icon(Icons.login_rounded, color: Colors.white, size: 20),
                                    SizedBox(width: 8),
                                    Text('Sign In',
                                      style: TextStyle(color: Colors.white,
                                        fontWeight: FontWeight.w700, fontSize: 16)),
                                  ]),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1, duration: 500.ms,
                    curve: Curves.easeOutCubic),

                  const SizedBox(height: 32),
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.shield_outlined, size: 13, color: AppTheme.textLight),
                        const SizedBox(width: 5),
                        Text('Secured & recorded on Algorand blockchain',
                          style: Theme.of(context).textTheme.bodyMedium!.copyWith(fontSize: 11)),
                      ],
                    ),
                  ).animate().fadeIn(delay: 500.ms),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
