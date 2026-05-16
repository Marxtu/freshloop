import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/format.dart';
import '../../domain/models/scored_route.dart';
import '../../services/location_source.dart';
import '../../state/run_tracking_cubit.dart';
import '../../state/run_tracking_state.dart';
import '../common/route_map.dart';
import 'run_summary_screen.dart';

/// Live run tracking: the map follows the user, live distance/time/pace, and a
/// Stop control. Owns a [RunTrackingCubit] built from [locationSource].
class TrackingScreen extends StatefulWidget {
  final LocationSource locationSource;
  final ScoredRoute? planned;
  const TrackingScreen({super.key, required this.locationSource, this.planned});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  late final RunTrackingCubit _cubit = RunTrackingCubit(widget.locationSource);
  final Stopwatch _watch = Stopwatch();
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _watch.start();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _cubit.start();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _watch.stop();
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return BlocConsumer<RunTrackingCubit, RunTrackingState>(
      bloc: _cubit,
      listener: (context, state) {
        if (state is RunFinished) {
          Navigator.of(context).pushReplacement(MaterialPageRoute(
            builder: (_) => RunSummaryScreen(record: state.record, planned: widget.planned),
          ));
        }
      },
      builder: (context, state) {
        if (state is RunPermissionDenied) {
          return Scaffold(
            appBar: AppBar(title: const Text('Run')),
            body: const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Location permission is needed to track your run.',
                    textAlign: TextAlign.center),
              ),
            ),
          );
        }
        final live = state is RunInProgress ? state : null;
        final distanceM = live?.distanceM ?? 0;
        final points = live?.points ?? const [];
        final elapsed = _watch.elapsed.inSeconds;
        return Scaffold(
          body: Stack(
            children: [
              Positioned.fill(
                child: RouteMap(
                  points: widget.planned?.geometry.points ?? points,
                  currentLocation: points.isNotEmpty ? points.last : null,
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Card(
                  margin: const EdgeInsets.all(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _stat(t, (distanceM / 1000).toStringAsFixed(2), 'km'),
                            _stat(t, formatDuration(elapsed), 'time'),
                            _stat(t, formatPace(distanceM, elapsed), 'pace'),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(backgroundColor: t.colorScheme.error),
                            onPressed: _cubit.stop,
                            icon: const Icon(Icons.stop),
                            label: const Text('Stop run'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _stat(ThemeData t, String value, String label) => Column(
        children: [
          Text(value, style: t.textTheme.headlineSmall),
          Text(label, style: t.textTheme.bodySmall),
        ],
      );
}
