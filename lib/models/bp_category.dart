import 'package:flutter/material.dart';

/// AHA/ACC 2017 adult blood-pressure categories.
enum BpCategory {
  normal('Normal', Color(0xFF2E9E5B)),
  elevated('Elevated', Color(0xFFC9A227)),
  stage1('Hypertension stage 1', Color(0xFFE07B24)),
  stage2('Hypertension stage 2', Color(0xFFD1453B)),
  crisis('Hypertensive crisis', Color(0xFF8E1B3A));

  final String label;
  final Color color;
  const BpCategory(this.label, this.color);

  static BpCategory of(double sbp, double dbp) {
    if (sbp > 180 || dbp > 120) return crisis;
    if (sbp >= 140 || dbp >= 90) return stage2;
    if (sbp >= 130 || dbp >= 80) return stage1;
    if (sbp >= 120) return elevated;
    return normal;
  }
}
