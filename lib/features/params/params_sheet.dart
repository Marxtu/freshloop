import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../domain/models/run_params.dart';
import '../../domain/models/score_weights.dart';
import 'terrain.dart';

/// Bottom-sheet form: target distance, three axis-weight sliders, a terrain
/// choice, and one primary "Generate" action. Every control uses the same
/// row shape — a `label … value` header above a full-width slider — so the
/// controls line up on a single left/right grid (no mixed inset widths).
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
    final muted = t.textTheme.labelLarge?.copyWith(color: t.colorScheme.onSurfaceVariant);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Design your run', style: t.textTheme.titleLarge),
          const SizedBox(height: 2),
          Text('Pick a distance, then tell us what matters.',
              style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 14),
          _sliderRow(
            t,
            'Distance',
            '${_distanceKm.toStringAsFixed(1)} km',
            Slider(
              value: _distanceKm,
              min: 1,
              max: 21,
              divisions: 40,
              label: '${_distanceKm.toStringAsFixed(1)} km',
              onChanged: (v) => setState(() => _distanceKm = v),
            ),
          ),
          const SizedBox(height: 6),
          Text('What matters most', style: muted),
          const SizedBox(height: 2),
          _sliderRow(t, 'Clean air', _weightLabel(_air),
              _weightSlider(_air, (v) => setState(() => _air = v))),
          _sliderRow(t, 'Right hills', _weightLabel(_hills),
              _weightSlider(_hills, (v) => setState(() => _hills = v))),
          _sliderRow(t, 'Scenery', _weightLabel(_scenery),
              _weightSlider(_scenery, (v) => setState(() => _scenery = v))),
          const SizedBox(height: 12),
          Text('Terrain', style: muted),
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
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _generate,
              icon: const Icon(Icons.route),
              label: const Text('Generate routes'),
            ),
          ),
        ],
      ),
    );
  }

  /// Uniform control: a `label … value` header over a full-width slider.
  Widget _sliderRow(ThemeData t, String label, String value, Widget slider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: t.textTheme.bodyMedium),
            const Spacer(),
            Text(value,
                style: t.textTheme.labelMedium
                    ?.copyWith(color: AppColors.seed, fontWeight: FontWeight.w700)),
          ],
        ),
        SizedBox(height: 36, child: slider),
      ],
    );
  }

  Widget _weightSlider(double value, ValueChanged<double> onChanged) =>
      Slider(value: value, max: 3, divisions: 3, onChanged: onChanged);

  static String _weightLabel(double value) {
    if (value <= 0) return 'off';
    if (value <= 1) return 'low';
    if (value <= 2) return 'medium';
    return 'high';
  }
}
