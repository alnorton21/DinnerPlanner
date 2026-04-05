import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final supabase = Supabase.instance.client;
  final emailController = TextEditingController();

  bool loading = false;
  bool emailSent = false;
  String? errorMessage;

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  Future<void> sendResetEmail() async {
    final email = emailController.text.trim();

    if (email.isEmpty) {
      setState(() => errorMessage = 'Please enter your email address.');
      return;
    }

    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      await supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: 'dinnerplanner://login-callback',
      );
      if (mounted) setState(() => emailSent = true);
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
    return Scaffold(
      appBar: AppBar(title: const Text('Reset Password')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_reset, size: 72, color: Colors.green),
            const SizedBox(height: 24),
            Text(
              'Forgot your password?',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            if (!emailSent) ...[
              const Text(
                'Enter your email address and we\'ll send you a link to reset your password.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
              ),
              if (errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: loading ? null : sendResetEmail,
                  child: loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Send Reset Link'),
                ),
              ),
            ] else ...[
              const SizedBox(height: 8),
              const Text(
                'Check your inbox for a password reset link. Follow the link to set a new password.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              const Icon(Icons.mark_email_read, size: 64, color: Colors.green),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Back to Sign In'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
