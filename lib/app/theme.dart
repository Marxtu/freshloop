import 'package:flutter/material.dart';

/// Centralized Material 3 theme (Color/Typography/Shape), built once.
/// A single seed colour drives the whole scheme so look & feel stays consistent.
final ThemeData freshLoopTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D32)),
);
