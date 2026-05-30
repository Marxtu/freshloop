import 'package:flutter/material.dart';

/// Placeholder home screen. The map and the "generate route" flow land later.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('FreshLoop')),
      body: const Center(
        child: Text('Design your run', key: Key('home-tagline')),
      ),
    );
  }
}
