import 'package:flutter/material.dart';

import '../../services/waveform_buffer.dart';

/// Live PPG trace. Repaints straight from the buffer, without rebuilding
/// widgets, so a 100+ Hz stream stays smooth.
class WaveformView extends StatelessWidget {
  const WaveformView({super.key, required this.buffer, this.height = 160});

  final WaveformBuffer buffer;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _WaveformPainter(
            buffer,
            line: scheme.primary,
            grid: scheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter(this.buffer, {required this.line, required this.grid})
    : super(repaint: buffer);

  final WaveformBuffer buffer;
  final Color line;
  final Color grid;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    // One vertical line per second.
    for (var s = 1; s < buffer.seconds; s++) {
      final x = size.width * s / buffer.seconds;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      gridPaint,
    );

    final n = buffer.length;
    if (n < 2) return;

    var lo = double.infinity, hi = double.negativeInfinity;
    for (var i = 0; i < n; i++) {
      final v = buffer[i];
      if (v < lo) lo = v;
      if (v > hi) hi = v;
    }
    final span = (hi - lo).abs() < 1e-6 ? 1.0 : hi - lo;
    const pad = 0.1;

    final path = Path();
    final dx = size.width / (buffer.capacity - 1);
    for (var i = 0; i < n; i++) {
      final norm = (buffer[i] - lo) / span;
      final y = size.height * (1 - pad - norm * (1 - 2 * pad));
      final x = i * dx;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter old) =>
      old.line != line || old.grid != grid || old.buffer != buffer;
}
