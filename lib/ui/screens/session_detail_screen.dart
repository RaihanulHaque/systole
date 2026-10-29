import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/session.dart';
import '../../state/history_controller.dart';
import '../widgets/trend_chart.dart';
import 'history_screen.dart';

class SessionDetailScreen extends StatelessWidget {
  const SessionDetailScreen({super.key, required this.session});

  final Session session;

  Future<void> _export(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    final files = await context.read<HistoryController>().store.exportFiles(
      session,
    );
    await SharePlus.instance.share(
      ShareParams(
        files: files.map((f) => XFile(f.path)).toList(),
        subject: 'Systole session ${session.id}',
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  }

  Future<void> _delete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete session?'),
        content: const Text(
          'This removes the readings and the raw signal from this phone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await context.read<HistoryController>().delete(session);
    if (context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final s = session;
    final theme = Theme.of(context);
    final time = DateFormat('HH:mm:ss');
    String f(double? v) => v == null ? '--' : v.round().toString();

    return Scaffold(
      appBar: AppBar(
        title: Text(DateFormat('d MMM yyyy, HH:mm').format(s.start)),
        actions: [
          IconButton(
            onPressed: () => _export(context),
            icon: const Icon(Icons.ios_share),
            tooltip: 'Export CSV',
          ),
          IconButton(
            onPressed: () => _delete(context),
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.35,
            children: [
              _Stat('Average', '${f(s.avgSbp)}/${f(s.avgDbp)}', 'mmHg'),
              _Stat('Systolic range', '${f(s.minSbp)}–${f(s.maxSbp)}', 'mmHg'),
              _Stat('Heart rate', f(s.avgHr), 'bpm avg'),
              _Stat('Duration', formatDuration(s.duration), ''),
              _Stat('Readings', '${s.readings.length}', ''),
              _Stat(
                'Packet loss',
                s.samplesRecorded == 0 ? '--' : s.packetsDropped.toString(),
                'packets',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 14, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: TrendLegend(showReference: s.references.isNotEmpty),
                  ),
                  const SizedBox(height: 12),
                  TrendChart(
                    readings: s.readings,
                    references: s.references,
                    height: 220,
                  ),
                ],
              ),
            ),
          ),
          if (s.references.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Cuff readings', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  for (final r in s.references)
                    ListTile(
                      dense: true,
                      leading: Icon(
                        r.usedForCalibration
                            ? Icons.tune
                            : Icons.fact_check_outlined,
                      ),
                      title: Text('${r.sbp.round()}/${r.dbp.round()} mmHg'),
                      subtitle: Text(
                        r.usedForCalibration ? 'Calibration' : 'Reference',
                      ),
                      trailing: Text(time.format(r.time)),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Text('Readings', style: theme.textTheme.titleMedium),
              const Spacer(),
              Text(
                '${s.sampleRateHz} Hz · ${s.samplesRecorded} samples',
                style: theme.textTheme.labelSmall,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                for (final r in s.readings.reversed.take(200))
                  ListTile(
                    dense: true,
                    title: Text(
                      '${r.sbp.round()}/${r.dbp.round()} mmHg · ${r.hr} bpm',
                    ),
                    subtitle: Text(
                      'Signal ${r.quality}%${r.calibrated ? ' · calibrated' : ''}${r.motion ? ' · motion' : ''}',
                    ),
                    trailing: Text(time.format(r.time)),
                  ),
                if (s.readings.length > 200)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'Showing latest 200. Export for all ${s.readings.length}.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                if (s.readings.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No readings in this session'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, this.unit);

  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(unit, style: theme.textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}
