// ignore_for_file: avoid_print
import 'package:flutter/material.dart';
import 'package:freshloop/app/theme.dart';
import 'package:freshloop/domain/models/run_record.dart';
import 'package:freshloop/features/tracking/run_summary_screen.dart';
import 'mock_routes.dart';

void main() => runApp(MaterialApp(
      theme: freshLoopTheme,
      debugShowCheckedModeBanner: false,
      home: RunSummaryScreen(
        record: const RunRecord(points: loop, distanceM: 5120, durationS: 1875),
        planned: mockRoute,
      ),
    ));
