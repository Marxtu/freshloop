import 'package:flutter/material.dart';

/// Branded loading splash shown in Firebase mode while the first auth event is
/// still resolving (`AuthStatus.unknown`). It prevents the app from briefly
/// flashing the sign-in screen (or home) before auth state is known. Local mode
/// never builds this — there is no AuthCubit there.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('FreshLoop', style: t.textTheme.displaySmall),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
