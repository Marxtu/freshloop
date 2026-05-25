import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/format.dart';
import '../../domain/models/scored_route.dart';
import '../../services/location_source.dart';
import '../../state/run_tracking_cubit.dart';
import '../../state/run_tracking_state.dart';
import '../common/route_map.dart';
import '../common/stat_trio.dart';
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
              SafeArea(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Card(
                    margin: const EdgeInsets.all(12),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(color: t.colorScheme.error, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 8),
                              Text('RECORDING',
                                  style: t.textTheme.labelSmall?.copyWith(
                                    color: t.colorScheme.onSurfaceVariant,
                                    letterSpacing: 1.4,
                                    fontWeight: FontWeight.w700,
                                  )),
                            ],
                          ),
                          const SizedBox(height: 14),
                          StatTrio([
                            ((distanceM / 1000).toStringAsFixed(2), 'km'),
                            (formatDuration(elapsed), 'time'),
                            (formatPace(distanceM, elapsed), 'pace'),
                          ]),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(backgroundColor: t.colorScheme.error),
                              onPressed: _cubit.stop,
                              icon: const Icon(Icons.stop_rounded),
                              label: const Text('Stop run'),
                            ),
                          ),
                        ],
                      ),
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
}
