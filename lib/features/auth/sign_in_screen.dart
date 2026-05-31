import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../app/theme.dart';
import '../../state/auth_cubit.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});
  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSignUp = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit(AuthCubit cubit) {
    if (!_formKey.currentState!.validate()) return;
    final email = _email.text.trim();
    final pw = _password.text;
    _isSignUp ? cubit.signUp(email: email, password: pw) : cubit.signIn(email: email, password: pw);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final state = context.watch<AuthCubit>().state;
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.brandGradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 16, offset: Offset(0, 6))],
                      ),
                      child: const Icon(Icons.directions_run_rounded, size: 40, color: AppColors.seed),
                    ),
                    const SizedBox(height: 16),
                    Text('FreshLoop',
                        style: t.textTheme.displaySmall?.copyWith(color: Colors.white)),
                    const SizedBox(height: 4),
                    Text(
                      'Design runs that feel good — clean air, the right hills, good views.',
                      style: t.textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.88)),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),
                    Container(
                      decoration: BoxDecoration(
                        color: t.colorScheme.surface,
                        borderRadius: BorderRadius.circular(kRadius),
                        boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 24, offset: Offset(0, 10))],
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(_isSignUp ? 'Create your account' : 'Welcome back',
                                style: t.textTheme.titleLarge),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _email,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                prefixIcon: Icon(Icons.mail_outline_rounded),
                              ),
                              validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _password,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: 'Password',
                                prefixIcon: Icon(Icons.lock_outline_rounded),
                              ),
                              validator: (v) => (v == null || v.length < 6) ? 'At least 6 characters' : null,
                            ),
                            if (state.error != null) ...[
                              const SizedBox(height: 12),
                              Semantics(
                                liveRegion: true,
                                child: Row(
                                  children: [
                                    Icon(Icons.error_outline_rounded, size: 18, color: t.colorScheme.error),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(state.error!, style: TextStyle(color: t.colorScheme.error)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
                            FilledButton(
                              style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
                              onPressed: state.submitting ? null : () => _submit(context.read<AuthCubit>()),
                              child: state.submitting
                                  ? const SizedBox(
                                      height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                  : Text(_isSignUp ? 'Create account' : 'Sign in'),
                            ),
                            TextButton(
                              onPressed: state.submitting ? null : () => setState(() => _isSignUp = !_isSignUp),
                              child: Text(_isSignUp ? 'Have an account? Sign in' : 'New here? Create an account'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
