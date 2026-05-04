import 'package:flutter/material.dart';
import 'router.dart';
import 'theme.dart';

/// Root widget: wires the Material 3 theme and the go_router config.
class FreshLoopApp extends StatelessWidget {
  const FreshLoopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'FreshLoop',
      theme: freshLoopTheme,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
