import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../ble/bp_device.dart';
import '../../ble/demo_bp_device.dart';
import '../../state/monitor_controller.dart';
import '../../state/profile_controller.dart';
import '../widgets/bp_hero_card.dart';
import '../widgets/reference_dialog.dart';
import '../widgets/trend_chart.dart';
import '../widgets/waveform_view.dart';
import 'scan_screen.dart';
import 'session_detail_screen.dart';

class MonitorScreen extends StatelessWidget {
  const MonitorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<MonitorController>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Systole'),
        actions: [
          if (c.device != null) _DeviceMenu(controller: c),
          const SizedBox(width: 8),
        ],
      ),
      body: c.device == null ? const _NotConnected() : _LiveView(controller: c),
    );
  }
}

class _NotConnected extends StatelessWidget {
  const _NotConnected();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.monitor_heart,
                size: 56,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No sensor connected',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Wear the sensor and turn it on, then connect over Bluetooth to '
              'see your blood pressure continuously.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ScanScreen()),
              ),
              icon: const Icon(Icons.bluetooth_searching),
              label: const Text('Connect sensor'),
              style: FilledButton.styleFrom(minimumSize: const Size(220, 52)),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () =>
                  context.read<MonitorController>().connect(DemoBpDevice()),
              child: const Text('Try with a demo sensor'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveView extends StatelessWidget {
  const _LiveView({required this.controller});

  final MonitorController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final theme = Theme.of(context);
    final profileSet = context.watch<ProfileController>().isSet;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        _StatusRow(controller: c),
        const SizedBox(height: 12),
        if (!profileSet) ...[
          _Hint(
            icon: Icons.person_outline,
            text:
                'Add your age, height and weight in Profile. The model uses '
                'them to estimate blood pressure.',
          ),
          const SizedBox(height: 12),
        ],
        if (!c.calibrated && c.connected) ...[
          _Hint(
            icon: Icons.tune,
            text: 'Calibrate with one cuff reading for better accuracy.',
            action: 'Calibrate',
            onAction: () => _addReference(context, calibrate: true),
          ),
          const SizedBox(height: 12),
        ],
        if (c.recording != null) ...[
          _RecordingBanner(controller: c),
          const SizedBox(height: 12),
        ],
        BpHeroCard(
          result: c.latest,
          updatedAt: c.latestAt,
          calibrated: c.calibrated,
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Pulse waveform', style: theme.textTheme.titleSmall),
                    const Spacer(),
                    Text(
                      '${c.sampleRate} Hz · PPG',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                WaveformView(buffer: c.waveform),
              ],
            ),
          ),
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
                  child: Row(
                    children: [
                      Text('Trend', style: theme.textTheme.titleSmall),
                      const Spacer(),
                      const TrendLegend(),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TrendChart(readings: c.recent),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: c.connected
                    ? () => _addReference(context, calibrate: !c.calibrated)
                    : null,
                icon: const Icon(Icons.add_chart),
                label: const Text('Cuff reading'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: c.recording == null
                  ? FilledButton.icon(
                      onPressed: c.connected ? c.startRecording : null,
                      icon: const Icon(Icons.fiber_manual_record),
                      label: const Text('Record'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                    )
                  : FilledButton.tonalIcon(
                      onPressed: () => _stop(context),
                      icon: const Icon(Icons.stop),
                      label: const Text('Stop'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                    ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          'Research prototype. Estimates are not a medical diagnosis. '
          'Confirm readings with a validated cuff.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Future<void> _addReference(
    BuildContext context, {
    required bool calibrate,
  }) async {
    final input = await showReferenceDialog(
      context,
      calibrateByDefault: calibrate,
    );
    if (input == null || !context.mounted) return;
    try {
      await controller.addReference(
        input.sbp,
        input.dbp,
        calibrate: input.calibrate,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            input.calibrate
                ? 'Calibration sent to sensor'
                : 'Reference reading saved',
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Future<void> _stop(BuildContext context) async {
    final s = await controller.stopRecording();
    if (s == null || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Session saved · ${s.readings.length} readings'),
        action: SnackBarAction(
          label: 'View',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => SessionDetailScreen(session: s)),
          ),
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.controller});

  final MonitorController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final theme = Theme.of(context);
    final (label, color) = switch (c.link) {
      LinkState.connected => ('Connected', const Color(0xFF2E9E5B)),
      LinkState.connecting => (
        c.reconnecting ? 'Reconnecting…' : 'Connecting…',
        const Color(0xFFC9A227),
      ),
      LinkState.disconnected => (
        c.reconnecting ? 'Reconnecting…' : 'Disconnected',
        theme.colorScheme.error,
      ),
    };
    final muted = theme.textTheme.labelMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '${c.device!.name} · $label',
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelLarge,
          ),
        ),
        if (c.packetsReceived > 0) ...[
          Tooltip(
            message: 'Packets lost over Bluetooth',
            child: Text(
              'Loss ${c.lossPercent.toStringAsFixed(1)}%',
              style: muted,
            ),
          ),
          const SizedBox(width: 12),
        ],
        if (c.battery != null) ...[
          Icon(_batteryIcon(c.battery!), size: 18, color: muted?.color),
          Text('${c.battery}%', style: muted),
        ],
      ],
    );
  }

  IconData _batteryIcon(int b) {
    if (b > 80) return Icons.battery_full;
    if (b > 50) return Icons.battery_5_bar;
    if (b > 20) return Icons.battery_3_bar;
    return Icons.battery_alert;
  }
}

class _RecordingBanner extends StatefulWidget {
  const _RecordingBanner({required this.controller});

  final MonitorController controller;

  @override
  State<_RecordingBanner> createState() => _RecordingBannerState();
}

class _RecordingBannerState extends State<_RecordingBanner> {
  late final Timer _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.controller.recording!;
    final d = s.duration;
    final hh = d.inHours.toString().padLeft(2, '0');
    final mm = (d.inMinutes % 60).toString().padLeft(2, '0');
    final ss = (d.inSeconds % 60).toString().padLeft(2, '0');
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            Icons.fiber_manual_record,
            color: theme.colorScheme.error,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            'Recording  $hh:$mm:$ss',
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onErrorContainer,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const Spacer(),
          Text(
            '${s.readings.length} readings',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onErrorContainer,
            ),
          ),
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({
    required this.icon,
    required this.text,
    this.action,
    this.onAction,
  });

  final IconData icon;
  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.onSecondaryContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
          ),
          if (action != null)
            TextButton(onPressed: onAction, child: Text(action!)),
        ],
      ),
    );
  }
}

class _DeviceMenu extends StatelessWidget {
  const _DeviceMenu({required this.controller});

  final MonitorController controller;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      onSelected: (v) async {
        switch (v) {
          case 'sync':
            await controller.syncProfile();
          case 'clear':
            await controller.clearCalibration();
          case 'disconnect':
            await controller.disconnect();
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'sync',
          child: Text('Send profile to sensor'),
        ),
        if (controller.calibrated)
          const PopupMenuItem(value: 'clear', child: Text('Clear calibration')),
        const PopupMenuItem(value: 'disconnect', child: Text('Disconnect')),
      ],
    );
  }
}
