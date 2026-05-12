import 'package:flutter/material.dart';
import '../../domain/models/run_params.dart';
import '../../domain/models/score_weights.dart';
import 'terrain.dart';

/// Bottom-sheet form: target distance, three axis-weight sliders, a terrain
/// choice, and one primary "Generate" action. Keep-it-brief; no button grid.
class ParamsSheet extends StatefulWidget {
  final double startLat;
  final double startLng;
  final ValueChanged<RunParams> onGenerate;
  const ParamsSheet({
    super.key,
    required this.startLat,
    required this.startLng,
    required this.onGenerate,
  });

  @override
  State<ParamsSheet> createState() => _ParamsSheetState();
}

class _ParamsSheetState extends State<ParamsSheet> {
  double _distanceKm = 5;
  double _air = 1, _hills = 1, _scenery = 1;
  Terrain _terrain = Terrain.rolling;

  void _generate() {
    final distanceM = _distanceKm * 1000;
    widget.onGenerate(RunParams(
      startLat: widget.startLat,
      startLng: widget.startLng,
      targetDistanceM: distanceM,
      weights: ScoreWeights(air: _air, hills: _hills, scenery: _scenery),
      targetAscentM: targetAscentFor(_terrain, distanceM),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Design your run', style: t.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text('Distance: ${_distanceKm.toStringAsFixed(1)} km'),
          Slider(
            value: _distanceKm,
            min: 1,
            max: 21,
            divisions: 40,
            label: '${_distanceKm.toStringAsFixed(1)} km',
            onChanged: (v) => setState(() => _distanceKm = v),
          ),
          _weight('Clean air', _air, (v) => setState(() => _air = v)),
          _weight('Right hills', _hills, (v) => setState(() => _hills = v)),
          _weight('Scenery', _scenery, (v) => setState(() => _scenery = v)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final terrain in Terrain.values)
                ChoiceChip(
                  label: Text(terrain.name),
                  selected: _terrain == terrain,
                  onSelected: (_) => setState(() => _terrain = terrain),
                ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFF59E0B)),
              onPressed: _generate,
              icon: const Icon(Icons.route),
              label: const Text('Generate'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _weight(String label, double value, ValueChanged<double> onChanged) {
    return Row(
      children: [
        SizedBox(width: 96, child: Text(label)),
        Expanded(
          child: Slider(value: value, max: 3, divisions: 3, onChanged: onChanged),
        ),
      ],
    );
  }
}
