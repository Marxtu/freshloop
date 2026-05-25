import 'package:flutter/material.dart';

/// A row of headline stats (e.g. distance / time / pace) — big Sora numbers
/// over small uppercased labels, separated by hairline dividers. Shared by the
/// live-tracking and post-run summary screens so the run metrics read the same.
class StatTrio extends StatelessWidget {
  /// Each item is (value, label), e.g. ('5.12', 'km').
  final List<(String, String)> items;
  const StatTrio(this.items, {super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              VerticalDivider(width: 1, indent: 4, endIndent: 4, color: t.colorScheme.outlineVariant),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    items[i].$1,
                    style: t.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, height: 1),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    items[i].$2.toUpperCase(),
                    style: t.textTheme.labelSmall?.copyWith(
                      color: t.colorScheme.onSurfaceVariant,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
