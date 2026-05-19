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
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('FreshLoop', style: t.textTheme.displaySmall, textAlign: TextAlign.center),
                  const SizedBox(height: 4),
                  Text(_isSignUp ? 'Create your account' : 'Welcome back',
                      style: t.textTheme.bodyLarge, textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                    validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _password,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
                    validator: (v) => (v == null || v.length < 6) ? 'At least 6 characters' : null,
                  ),
                  if (state.error != null) ...[
                    const SizedBox(height: 12),
                    Text(state.error!, style: TextStyle(color: t.colorScheme.error)),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
                    onPressed: state.submitting ? null : () => _submit(context.read<AuthCubit>()),
                    child: state.submitting
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(_isSignUp ? 'Create account' : 'Sign in'),
                  ),
                  TextButton(
                    onPressed: state.submitting ? null : () => setState(() => _isSignUp = !_isSignUp),
                    child: Text(_isSignUp ? 'Have an account? Sign in' : "New here? Create an account"),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
