import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'reset_password_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final supabase = Supabase.instance.client;
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool isSignUp = false;
  bool loading = false;
  bool _obscurePassword = true;
  String? errorMessage;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    if (email.isEmpty || password.isEmpty) {
      setState(() => errorMessage = 'Please enter your email and password.');
      return;
    }
    setState(() {
      loading = true;
      errorMessage = null;
    });
    try {
      if (isSignUp) {
        await supabase.auth.signUp(email: email, password: password);
      } else {
        await supabase.auth.signInWithPassword(email: email, password: password);
      }
    } on AuthException catch (e) {
      setState(() => errorMessage = e.message);
    } catch (_) {
      setState(() => errorMessage = 'An unexpected error occurred.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // ── Header ──────────────────────────────────────────────────
              _Header(isDark: isDark),

              // ── Form ────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isSignUp ? 'Create account' : 'Welcome back',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isSignUp
                          ? 'Start planning your meals today'
                          : 'Sign in to continue',
                      style: TextStyle(
                          fontSize: 14,
                          color: cs.onSurface.withValues(alpha: 0.6)),
                    ),
                    const SizedBox(height: 28),

                    // Email
                    TextField(
                      controller: emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email address',
                        prefixIcon: Icon(Icons.email_outlined, size: 20),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 14),

                    // Password
                    TextField(
                      controller: passwordController,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon:
                            const Icon(Icons.lock_outline, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 20,
                          ),
                          onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => submit(),
                    ),

                    // Error
                    if (errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: cs.errorContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(children: [
                          Icon(Icons.error_outline,
                              size: 16, color: cs.onErrorContainer),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(errorMessage!,
                                style: TextStyle(
                                    fontSize: 13,
                                    color: cs.onErrorContainer)),
                          ),
                        ]),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Primary button
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: loading ? null : submit,
                        child: loading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white),
                              )
                            : Text(isSignUp ? 'Create Account' : 'Sign In'),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Toggle sign-in / sign-up
                    Center(
                      child: TextButton(
                        onPressed: () => setState(() {
                          isSignUp = !isSignUp;
                          errorMessage = null;
                        }),
                        child: RichText(
                          text: TextSpan(
                            style: TextStyle(
                                fontSize: 14,
                                color:
                                    cs.onSurface.withValues(alpha: 0.65)),
                            children: [
                              TextSpan(
                                text: isSignUp
                                    ? 'Already have an account? '
                                    : "Don't have an account? ",
                              ),
                              TextSpan(
                                text: isSignUp ? 'Sign in' : 'Sign up',
                                style: TextStyle(
                                    color: cs.primary,
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    if (!isSignUp)
                      Center(
                        child: TextButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    const ResetPasswordScreen()),
                          ),
                          child: Text('Forgot password?',
                              style: TextStyle(
                                  color:
                                      cs.onSurface.withValues(alpha: 0.55),
                                  fontSize: 13)),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final bool isDark;
  const _Header({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final gradientColors = isDark
        ? [const Color(0xFF1B5E20), const Color(0xFF2E7D32)]
        : [const Color(0xFF2E7D32), const Color(0xFF43A047)];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(28, 48, 28, 40),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.restaurant_menu,
                color: Colors.white, size: 30),
          ),
          const SizedBox(height: 16),
          const Text(
            'Dinner Planner',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Plan smarter. Eat better.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
