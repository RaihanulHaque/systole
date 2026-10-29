import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/session.dart';
import '../theme.dart';

/// SBP and DBP over time, with optional cuff reference points.
class TrendChart extends StatelessWidget {
  const TrendChart({
    super.key,
    required this.readings,
    this.references = const [],
    this.height = 180,
  });

  final List<Reading> readings;
  final List<ReferenceReading> references;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (readings.length < 2) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            'The trend appears after a few readings',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    final t0 = readings.first.time;
    double x(DateTime t) => t.difference(t0).inMilliseconds / 1000;

    final values = [
      ...readings.expand((r) => [r.sbp, r.dbp]),
      ...references.expand((r) => [r.sbp, r.dbp]),
    ];
    final minY = (values.reduce(math.min) / 10).floor() * 10.0 - 10;
    final maxY = (values.reduce(math.max) / 10).ceil() * 10.0 + 10;
    final maxX = math.max(x(readings.last.time), 1.0);
    final fmt = maxX > 3600 ? DateFormat.Hm() : DateFormat('H:mm:ss');

    LineChartBarData line(List<FlSpot> spots, Color c) => LineChartBarData(
      spots: spots,
      color: c,
      barWidth: 2.5,
      isCurved: true,
      preventCurveOverShooting: true,
      dotData: const FlDotData(show: false),
    );

    final refSpots = references
        .where((r) => !r.time.isBefore(t0))
        .expand((r) => [FlSpot(x(r.time), r.sbp), FlSpot(x(r.time), r.dbp)])
        .toList();

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minY: minY,
          maxY: maxY,
          minX: 0,
          maxX: maxX,
          gridData: FlGridData(
            drawVerticalLine: false,
            horizontalInterval: 20,
            getDrawingHorizontalLine: (_) => FlLine(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                interval: 20,
                getTitlesWidget: (v, meta) => SideTitleWidget(
                  meta: meta,
                  child: Text(
                    v.toInt().toString(),
                    style: theme.textTheme.labelSmall,
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                interval: maxX / 3,
                getTitlesWidget: (v, meta) => SideTitleWidget(
                  meta: meta,
                  fitInside: SideTitleFitInsideData.fromTitleMeta(meta),
                  child: Text(
                    fmt.format(
                      t0.add(Duration(milliseconds: (v * 1000).round())),
                    ),
                    style: theme.textTheme.labelSmall,
                  ),
                ),
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => spots
                  .map(
                    (s) => LineTooltipItem(
                      s.y.toStringAsFixed(0),
                      TextStyle(
                        color: s.bar.color ?? Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          lineBarsData: [
            line(
              readings.map((r) => FlSpot(x(r.time), r.sbp)).toList(),
              sbpColor,
            ),
            line(
              readings.map((r) => FlSpot(x(r.time), r.dbp)).toList(),
              dbpColor,
            ),
            if (refSpots.isNotEmpty)
              LineChartBarData(
                spots: refSpots,
                barWidth: 0,
                color: Colors.transparent,
                dotData: FlDotData(
                  getDotPainter: (s, p, b, i) => FlDotSquarePainter(
                    size: 9,
                    color: theme.colorScheme.onSurface,
                    strokeWidth: 0,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class TrendLegend extends StatelessWidget {
  const TrendLegend({super.key, this.showReference = false});

  final bool showReference;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall;
    Widget item(Color c, String label, {bool square = false}) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: square ? 8 : 14, height: square ? 8 : 3, color: c),
        const SizedBox(width: 6),
        Text(label, style: style),
      ],
    );
    return Wrap(
      spacing: 16,
      children: [
        item(sbpColor, 'Systolic'),
        item(dbpColor, 'Diastolic'),
        if (showReference)
          item(
            Theme.of(context).colorScheme.onSurface,
            'Cuff reference',
            square: true,
          ),
      ],
    );
  }
}
