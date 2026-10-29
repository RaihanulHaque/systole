import 'dart:async';

import 'package:flutter/material.dart';

import '../../ble/protocol.dart';
import '../../models/bp_category.dart';
import '../theme.dart';

/// The headline SBP/DBP readout with heart rate, quality and category.
class BpHeroCard extends StatefulWidget {
  const BpHeroCard({
    super.key,
    required this.result,
    required this.updatedAt,
    required this.calibrated,
  });

  final BpResult? result;
  final DateTime? updatedAt;
  final bool calibrated;

  @override
  State<BpHeroCard> createState() => _BpHeroCardState();
}

class _BpHeroCardState extends State<BpHeroCard> {
  late final Timer _tick;

  @override
  void initState() {
    super.initState();
    // Keeps the "updated Xs ago" label fresh.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  String _ago(DateTime t) {
    final s = DateTime.now().difference(t).inSeconds;
    if (s < 5) return 'just now';
    if (s < 60) return '${s}s ago';
    return '${s ~/ 60}m ago';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = widget.result;
    final category = r == null ? null : BpCategory.of(r.sbp, r.dbp);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Blood pressure',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                _Badge(
                  label: widget.calibrated ? 'Calibrated' : 'Not calibrated',
                  color: widget.calibrated
                      ? const Color(0xFF2E9E5B)
                      : theme.colorScheme.outline,
                  icon: widget.calibrated
                      ? Icons.verified_outlined
                      : Icons.tune_outlined,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  r == null ? '---' : r.sbp.round().toString(),
                  style: theme.textTheme.displayLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: sbpColor,
                    height: 1,
                  ),
                ),
                Text(
                  ' / ',
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
                Text(
                  r == null ? '--' : r.dbp.round().toString(),
                  style: theme.textTheme.displayMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: dbpColor,
                    height: 1,
                  ),
                ),
                const SizedBox(width: 6),
                Text('mmHg', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            if (category != null)
              _Badge(label: category.label, color: category.color),
            const SizedBox(height: 16),
            Row(
              children: [
                _Metric(
                  icon: Icons.favorite,
                  iconColor: sbpColor,
                  label: 'Heart rate',
                  value: r == null ? '--' : '${r.hr} bpm',
                ),
                _Metric(
                  icon: Icons.signal_cellular_alt,
                  iconColor: _qualityColor(r?.quality),
                  label: 'Signal',
                  value: r == null ? '--' : '${r.quality}%',
                ),
                _Metric(
                  icon: Icons.schedule,
                  iconColor: theme.colorScheme.outline,
                  label: 'Updated',
                  value: widget.updatedAt == null
                      ? '--'
                      : _ago(widget.updatedAt!),
                ),
              ],
            ),
            // Fixed-height slot so the layout below doesn't jump when the
            // warning comes and goes.
            const SizedBox(height: 12),
            SizedBox(
              height: 20,
              child: r != null && (r.motion || r.lowQuality)
                  ? Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 18,
                          color: theme.colorScheme.error,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            r.motion
                                ? 'Motion detected. Keep your arm still.'
                                : 'Weak signal. Check sensor contact.',
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.error,
                            ),
                          ),
                        ),
                      ],
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Color _qualityColor(int? q) {
    if (q == null) return Colors.grey;
    if (q >= 80) return const Color(0xFF2E9E5B);
    if (q >= 60) return const Color(0xFFC9A227);
    return const Color(0xFFD1453B);
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color, this.icon});

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
