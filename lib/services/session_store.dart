import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/session.dart';

/// Sessions live in `<documents>/sessions/<id>/`:
///   meta.json  - session metadata, BP readings, cuff reference readings
///   ppg.csv    - raw PPG samples as received (rx_ms,seq,i,value)
class SessionStore {
  Directory? _root;

  Future<Directory> root() async {
    if (_root != null) return _root!;
    final docs = await getApplicationDocumentsDirectory();
    _root = Directory('${docs.path}/sessions');
    await _root!.create(recursive: true);
    return _root!;
  }

  Future<Directory> dirFor(String id) async {
    final d = Directory('${(await root()).path}/$id');
    await d.create(recursive: true);
    return d;
  }

  Future<File> rawFile(String id) async =>
      File('${(await dirFor(id)).path}/ppg.csv');

  Future<void> save(Session s) async {
    final f = File('${(await dirFor(s.id)).path}/meta.json');
    await f.writeAsString(jsonEncode(s.toJson()));
  }

  Future<List<Session>> list() async {
    final r = await root();
    final sessions = <Session>[];
    await for (final e in r.list()) {
      if (e is! Directory) continue;
      final meta = File('${e.path}/meta.json');
      if (!await meta.exists()) continue;
      try {
        sessions.add(
          Session.fromJson(
            jsonDecode(await meta.readAsString()) as Map<String, dynamic>,
          ),
        );
      } catch (_) {
        // Skip unreadable sessions rather than failing the whole list.
      }
    }
    sessions.sort((a, b) => b.start.compareTo(a.start));
    return sessions;
  }

  Future<void> delete(String id) async {
    final d = Directory('${(await root()).path}/$id');
    if (await d.exists()) await d.delete(recursive: true);
  }

  /// Writes CSVs next to the session and returns every file worth sharing.
  Future<List<File>> exportFiles(Session s) async {
    final dir = await dirFor(s.id);
    final readings = File('${dir.path}/readings.csv');
    final sb = StringBuffer(
      'time,sbp_mmHg,dbp_mmHg,hr_bpm,quality,calibrated,motion\n',
    );
    for (final r in s.readings) {
      sb.writeln(
        '${r.time.toIso8601String()},${r.sbp.toStringAsFixed(1)},'
        '${r.dbp.toStringAsFixed(1)},${r.hr},${r.quality},'
        '${r.calibrated ? 1 : 0},${r.motion ? 1 : 0}',
      );
    }
    await readings.writeAsString(sb.toString());

    final refs = File('${dir.path}/cuff_references.csv');
    final rb = StringBuffer('time,sbp_mmHg,dbp_mmHg,used_for_calibration\n');
    for (final r in s.references) {
      rb.writeln(
        '${r.time.toIso8601String()},${r.sbp.toStringAsFixed(1)},'
        '${r.dbp.toStringAsFixed(1)},${r.usedForCalibration ? 1 : 0}',
      );
    }
    await refs.writeAsString(rb.toString());

    final files = [readings, refs, File('${dir.path}/meta.json')];
    final raw = File('${dir.path}/ppg.csv');
    if (await raw.exists()) files.add(raw);
    return files;
  }
}
