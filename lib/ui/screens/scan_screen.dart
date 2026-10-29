import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:provider/provider.dart';

import '../../ble/ble_bp_device.dart';
import '../../ble/bp_device.dart';
import '../../ble/demo_bp_device.dart';
import '../../ble/protocol.dart';
import '../../state/monitor_controller.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  BluetoothAdapterState _adapter = BluetoothAdapterState.unknown;
  List<ScanResult> _results = [];
  bool _scanning = false;
  bool _onlySystole = true;
  String? _connectingId;
  final _subs = <StreamSubscription>[];

  @override
  void initState() {
    super.initState();
    _subs.addAll([
      FlutterBluePlus.adapterState.listen((s) {
        setState(() => _adapter = s);
        if (s == BluetoothAdapterState.on) _scan();
      }),
      FlutterBluePlus.scanResults.listen((r) => setState(() => _results = r)),
      FlutterBluePlus.isScanning.listen((s) => setState(() => _scanning = s)),
    ]);
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  Future<void> _scan() async {
    try {
      await FlutterBluePlus.startScan(
        withServices: _onlySystole ? [SystoleUuids.service] : [],
        timeout: const Duration(seconds: 12),
      );
    } catch (e) {
      _snack('Scan failed: $e');
    }
  }

  Future<void> _connect(BpDevice device) async {
    final monitor = context.read<MonitorController>();
    setState(() => _connectingId = device.id);
    await FlutterBluePlus.stopScan();
    try {
      await monitor.connect(device);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _snack(e.toString());
      await monitor.disconnect();
    } finally {
      if (mounted) setState(() => _connectingId = null);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final results = _onlySystole
        ? [..._results]
        : _results.where((r) => _nameOf(r).isNotEmpty).toList();
    results.sort((a, b) => b.rssi.compareTo(a.rssi));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect sensor'),
        actions: [
          if (_scanning)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              onPressed: _adapter == BluetoothAdapterState.on ? _scan : null,
              icon: const Icon(Icons.refresh),
              tooltip: 'Scan again',
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          if (_adapter != BluetoothAdapterState.on &&
              _adapter != BluetoothAdapterState.unknown)
            _AdapterWarning(state: _adapter),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Only show Systole sensors'),
            value: _onlySystole,
            onChanged: (v) {
              setState(() => _onlySystole = v);
              if (_adapter == BluetoothAdapterState.on) _scan();
            },
          ),
          const SizedBox(height: 8),
          Text('Nearby', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          if (results.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                _scanning
                    ? 'Searching… Make sure the sensor is powered on and close by.'
                    : 'No sensors found.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          for (final r in results)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                child: ListTile(
                  leading: const Icon(Icons.sensors),
                  title: Text(_nameOf(r).isEmpty ? 'Unnamed' : _nameOf(r)),
                  subtitle: Text(r.device.remoteId.str),
                  trailing: _connectingId == r.device.remoteId.str
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : _Rssi(rssi: r.rssi),
                  onTap: _connectingId != null
                      ? null
                      : () => _connect(
                          BleBpDevice(
                            r.device,
                            advertisedName: r.advertisementData.advName,
                          ),
                        ),
                ),
              ),
            ),
          const SizedBox(height: 16),
          Text('No hardware?', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.science_outlined),
              title: const Text('Demo sensor'),
              subtitle: const Text('Simulated PPG and blood pressure'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _connectingId != null
                  ? null
                  : () => _connect(DemoBpDevice()),
            ),
          ),
        ],
      ),
    );
  }

  String _nameOf(ScanResult r) => r.advertisementData.advName.isNotEmpty
      ? r.advertisementData.advName
      : r.device.platformName;
}

class _AdapterWarning extends StatelessWidget {
  const _AdapterWarning({required this.state});

  final BluetoothAdapterState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final msg = switch (state) {
      BluetoothAdapterState.off => 'Bluetooth is off.',
      BluetoothAdapterState.unauthorized =>
        'Bluetooth permission was denied. Allow it in Settings.',
      BluetoothAdapterState.unavailable =>
        'Bluetooth is not available on this device. Use the demo sensor.',
      _ => 'Bluetooth is not ready.',
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            Icons.bluetooth_disabled,
            color: theme.colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              msg,
              style: TextStyle(color: theme.colorScheme.onErrorContainer),
            ),
          ),
          if (state == BluetoothAdapterState.off)
            TextButton(
              onPressed: () => FlutterBluePlus.turnOn().catchError((_) {}),
              child: const Text('Turn on'),
            ),
        ],
      ),
    );
  }
}

class _Rssi extends StatelessWidget {
  const _Rssi({required this.rssi});

  final int rssi;

  @override
  Widget build(BuildContext context) {
    final bars = rssi > -60
        ? Icons.signal_cellular_alt
        : rssi > -75
        ? Icons.signal_cellular_alt_2_bar
        : Icons.signal_cellular_alt_1_bar;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(bars, size: 18),
        const SizedBox(width: 4),
        Text('$rssi dBm', style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
