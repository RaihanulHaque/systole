import 'dart:math' as math;

import 'user_profile.dart';

/// A BP estimate as stored in a session (phone time, not device time).
class Reading {
  final DateTime time;
  final double sbp;
  final double dbp;
  final int hr;
  final int quality;
  final bool calibrated;
  final bool motion;

  const Reading({
    required this.time,
    required this.sbp,
    required this.dbp,
    required this.hr,
    required this.quality,
    this.calibrated = false,
    this.motion = false,
  });

  Map<String, dynamic> toJson() => {
    't': time.toIso8601String(),
    'sbp': sbp,
    'dbp': dbp,
    'hr': hr,
    'q': quality,
    'cal': calibrated,
    'mot': motion,
  };

  factory Reading.fromJson(Map<String, dynamic> j) => Reading(
    time: DateTime.parse(j['t'] as String),
    sbp: (j['sbp'] as num).toDouble(),
    dbp: (j['dbp'] as num).toDouble(),
    hr: (j['hr'] as num).toInt(),
    quality: (j['q'] as num).toInt(),
    calibrated: j['cal'] as bool? ?? false,
    motion: j['mot'] as bool? ?? false,
  );
}

/// A reading taken with a real cuff, entered by hand. Either used to
/// calibrate the device or kept only as ground truth for validation.
class ReferenceReading {
  final DateTime time;
  final double sbp;
  final double dbp;
  final bool usedForCalibration;

  const ReferenceReading({
    required this.time,
    required this.sbp,
    required this.dbp,
    required this.usedForCalibration,
  });

  Map<String, dynamic> toJson() => {
    't': time.toIso8601String(),
    'sbp': sbp,
    'dbp': dbp,
    'cal': usedForCalibration,
  };

  factory ReferenceReading.fromJson(Map<String, dynamic> j) => ReferenceReading(
    time: DateTime.parse(j['t'] as String),
    sbp: (j['sbp'] as num).toDouble(),
    dbp: (j['dbp'] as num).toDouble(),
    usedForCalibration: j['cal'] as bool? ?? false,
  );
}

class Session {
  final String id;
  final DateTime start;
  DateTime? end;
  final String deviceName;
  final int sampleRateHz;
  final UserProfile? profile;
  final List<Reading> readings;
  final List<ReferenceReading> references;
  int samplesRecorded;
  int packetsDropped;

  Session({
    required this.id,
    required this.start,
    this.end,
    required this.deviceName,
    required this.sampleRateHz,
    this.profile,
    List<Reading>? readings,
    List<ReferenceReading>? references,
    this.samplesRecorded = 0,
    this.packetsDropped = 0,
  }) : readings = readings ?? [],
       references = references ?? [];

  Duration get duration => (end ?? DateTime.now()).difference(start);

  double? get avgSbp => readings.isEmpty
      ? null
      : readings.map((r) => r.sbp).reduce((a, b) => a + b) / readings.length;
  double? get avgDbp => readings.isEmpty
      ? null
      : readings.map((r) => r.dbp).reduce((a, b) => a + b) / readings.length;
  double? get avgHr => readings.isEmpty
      ? null
      : readings.map((r) => r.hr).reduce((a, b) => a + b) / readings.length;
  double? get maxSbp =>
      readings.isEmpty ? null : readings.map((r) => r.sbp).reduce(math.max);
  double? get minSbp =>
      readings.isEmpty ? null : readings.map((r) => r.sbp).reduce(math.min);

  Map<String, dynamic> toJson() => {
    'id': id,
    'start': start.toIso8601String(),
    'end': end?.toIso8601String(),
    'deviceName': deviceName,
    'sampleRateHz': sampleRateHz,
    'profile': profile?.toJson(),
    'readings': readings.map((r) => r.toJson()).toList(),
    'references': references.map((r) => r.toJson()).toList(),
    'samplesRecorded': samplesRecorded,
    'packetsDropped': packetsDropped,
  };

  factory Session.fromJson(Map<String, dynamic> j) => Session(
    id: j['id'] as String,
    start: DateTime.parse(j['start'] as String),
    end: j['end'] == null ? null : DateTime.parse(j['end'] as String),
    deviceName: j['deviceName'] as String? ?? 'Unknown',
    sampleRateHz: (j['sampleRateHz'] as num?)?.toInt() ?? 100,
    profile: j['profile'] == null
        ? null
        : UserProfile.fromJson(j['profile'] as Map<String, dynamic>),
    readings: (j['readings'] as List? ?? [])
        .map((e) => Reading.fromJson(e as Map<String, dynamic>))
        .toList(),
    references: (j['references'] as List? ?? [])
        .map((e) => ReferenceReading.fromJson(e as Map<String, dynamic>))
        .toList(),
    samplesRecorded: (j['samplesRecorded'] as num?)?.toInt() ?? 0,
    packetsDropped: (j['packetsDropped'] as num?)?.toInt() ?? 0,
  );
}
