import 'package:flutter/foundation.dart';

/// Ring buffer of display-filtered PPG samples for the live waveform.
///
/// The raw signal has a large DC offset and slow drift, so for display only
/// it is band-limited with a one-pole high-pass (~0.5 Hz) followed by a
/// one-pole low-pass (~8 Hz). Recording always stores the raw samples.
class WaveformBuffer extends ChangeNotifier {
  WaveformBuffer({int sampleRate = 100, this.seconds = 8}) {
    setSampleRate(sampleRate);
  }

  final int seconds;
  late int sampleRate;
  late Float32List _data;
  int _head = 0;
  int _count = 0;

  double _hpA = 0, _lpB = 0;
  double? _prevX;
  double _hpY = 0, _lpY = 0;

  int get capacity => _data.length;
  int get length => _count;

  void setSampleRate(int fs) {
    sampleRate = fs <= 0 ? 100 : fs;
    _data = Float32List(sampleRate * seconds);
    final dt = 1 / sampleRate;
    const hpFc = 0.5, lpFc = 8.0;
    final hpRc = 1 / (2 * 3.141592653589793 * hpFc);
    final lpRc = 1 / (2 * 3.141592653589793 * lpFc);
    _hpA = hpRc / (hpRc + dt);
    _lpB = dt / (lpRc + dt);
    clear();
  }

  void clear() {
    _head = 0;
    _count = 0;
    _prevX = null;
    _hpY = 0;
    _lpY = 0;
    notifyListeners();
  }

  void addAll(List<int> samples) {
    for (final s in samples) {
      final x = s.toDouble();
      final prev = _prevX ?? x;
      _hpY = _hpA * (_hpY + x - prev);
      _prevX = x;
      _lpY += _lpB * (_hpY - _lpY);
      _data[_head] = _lpY;
      _head = (_head + 1) % _data.length;
      if (_count < _data.length) _count++;
    }
    notifyListeners();
  }

  /// Sample [i] in chronological order, 0 = oldest.
  double operator [](int i) {
    final start = (_head - _count + _data.length) % _data.length;
    return _data[(start + i) % _data.length];
  }
}
