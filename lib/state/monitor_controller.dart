import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../ble/bp_device.dart';
import '../ble/protocol.dart';
import '../models/session.dart';
import '../models/user_profile.dart';
import '../services/session_store.dart';
import '../services/waveform_buffer.dart';

/// Owns the active device connection, live data and the current recording.
class MonitorController extends ChangeNotifier {
  MonitorController({required this.store, required this.profile});

  final SessionStore store;
  final UserProfile Function() profile;

  static const _recentCap = 120;

  final waveform = WaveformBuffer();

  BpDevice? device;
  LinkState link = LinkState.disconnected;
  bool reconnecting = false;
  String? error;
  int? battery;

  BpResult? latest;
  DateTime? latestAt;
  final List<Reading> recent = [];
  bool calibrated = false;

  int packetsReceived = 0;
  int packetsDropped = 0;
  int? _lastSeq;

  Session? recording;
  IOSink? _rawSink;
  Timer? _checkpoint;

  bool _manualDisconnect = false;
  Timer? _reconnectTimer;
  final _subs = <StreamSubscription>[];

  bool get connected => link == LinkState.connected;
  int get sampleRate => device?.info?.sampleRateHz ?? waveform.sampleRate;

  double get lossPercent {
    final total = packetsReceived + packetsDropped;
    return total == 0 ? 0 : 100 * packetsDropped / total;
  }

  Future<void> connect(BpDevice d) async {
    await disconnect();
    device = d;
    _manualDisconnect = false;
    error = null;
    _resetLiveStats();

    _subs.addAll([
      d.linkState.listen(_onLink),
      d.ppg.listen(_onPpg),
      d.results.listen(_onResult),
      d.battery.listen((b) {
        battery = b;
        notifyListeners();
      }),
    ]);

    try {
      await d.connect();
      _afterConnect();
    } catch (e) {
      error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  void _afterConnect() {
    final d = device;
    if (d == null) return;
    final fs = d.info?.sampleRateHz;
    if (fs != null && fs != waveform.sampleRate) waveform.setSampleRate(fs);
    calibrated = d.info?.calibrated ?? calibrated;
    syncProfile();
  }

  void _onLink(LinkState s) {
    link = s;
    if (s == LinkState.connected) {
      reconnecting = false;
      _reconnectTimer?.cancel();
    } else if (s == LinkState.disconnected &&
        !_manualDisconnect &&
        device != null) {
      _scheduleReconnect();
    }
    notifyListeners();
  }

  void _scheduleReconnect() {
    if (_reconnectTimer?.isActive ?? false) return;
    reconnecting = true;
    _reconnectTimer = Timer(const Duration(seconds: 3), () async {
      final d = device;
      if (d == null || _manualDisconnect) return;
      try {
        await d.connect();
        _lastSeq = null;
        _afterConnect();
      } catch (_) {
        if (!_manualDisconnect) _scheduleReconnect();
      }
    });
  }

  void _onPpg(PpgPacket p) {
    final last = _lastSeq;
    if (last != null) {
      final gap = (p.seq - last - 1) & 0xFFFF;
      // Large gaps are a device restart, not loss.
      if (gap > 0 && gap < 1000) packetsDropped += gap;
    }
    _lastSeq = p.seq;
    packetsReceived++;
    waveform.addAll(p.samples);

    final rec = recording;
    final sink = _rawSink;
    if (rec != null && sink != null) {
      final rx = DateTime.now().millisecondsSinceEpoch;
      final sb = StringBuffer();
      for (var i = 0; i < p.samples.length; i++) {
        sb.writeln('$rx,${p.seq},$i,${p.samples[i]}');
      }
      sink.write(sb.toString());
      rec.samplesRecorded += p.samples.length;
      rec.packetsDropped = packetsDropped;
    }
  }

  void _onResult(BpResult r) {
    latest = r;
    latestAt = DateTime.now();
    calibrated = r.calibrated;
    final reading = Reading(
      time: latestAt!,
      sbp: r.sbp,
      dbp: r.dbp,
      hr: r.hr,
      quality: r.quality,
      calibrated: r.calibrated,
      motion: r.motion,
    );
    recent.add(reading);
    if (recent.length > _recentCap) recent.removeAt(0);
    recording?.readings.add(reading);
    notifyListeners();
  }

  Future<void> syncProfile() async {
    try {
      await device?.sendProfile(profile());
    } catch (e) {
      error = 'Could not send profile: $e';
      notifyListeners();
    }
  }

  /// Records a cuff reading; optionally sends it to the device as calibration.
  Future<void> addReference(
    double sbp,
    double dbp, {
    required bool calibrate,
  }) async {
    if (calibrate) {
      await device?.sendCalibration(sbp, dbp);
      calibrated = true;
    }
    recording?.references.add(
      ReferenceReading(
        time: DateTime.now(),
        sbp: sbp,
        dbp: dbp,
        usedForCalibration: calibrate,
      ),
    );
    notifyListeners();
  }

  Future<void> clearCalibration() async {
    await device?.sendControl(ControlOp.clearCalibration);
    calibrated = false;
    notifyListeners();
  }

  Future<void> startRecording() async {
    if (recording != null) return;
    final now = DateTime.now();
    final id = now.toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
    final s = Session(
      id: id,
      start: now,
      deviceName: device?.name ?? 'Unknown',
      sampleRateHz: sampleRate,
      profile: profile(),
      packetsDropped: 0,
    );
    final raw = await store.rawFile(id);
    _rawSink = raw.openWrite()..writeln('rx_ms,seq,i,value');
    packetsDropped = 0;
    packetsReceived = 0;
    recording = s;
    await store.save(s);
    // Checkpoint so a crash or kill loses at most a few seconds.
    _checkpoint = Timer.periodic(const Duration(seconds: 15), (_) async {
      await _rawSink?.flush();
      final r = recording;
      if (r != null) await store.save(r);
    });
    await WakelockPlus.enable();
    notifyListeners();
  }

  Future<Session?> stopRecording() async {
    final s = recording;
    if (s == null) return null;
    recording = null;
    _checkpoint?.cancel();
    s.end = DateTime.now();
    final sink = _rawSink;
    _rawSink = null;
    await sink?.flush();
    await sink?.close();
    await store.save(s);
    await WakelockPlus.disable();
    notifyListeners();
    return s;
  }

  Future<void> disconnect() async {
    _manualDisconnect = true;
    _reconnectTimer?.cancel();
    reconnecting = false;
    await stopRecording();
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    final d = device;
    device = null;
    if (d != null) {
      try {
        await d.disconnect();
      } catch (_) {}
      d.dispose();
    }
    link = LinkState.disconnected;
    notifyListeners();
  }

  void _resetLiveStats() {
    latest = null;
    latestAt = null;
    recent.clear();
    calibrated = false;
    battery = null;
    packetsReceived = 0;
    packetsDropped = 0;
    _lastSeq = null;
    waveform.clear();
  }

  bool _disposed = false;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    disconnect();
    super.dispose();
  }
}
