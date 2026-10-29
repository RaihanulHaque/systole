import 'package:flutter/foundation.dart';

import '../models/session.dart';
import '../services/session_store.dart';

class HistoryController extends ChangeNotifier {
  HistoryController(this.store);

  final SessionStore store;
  List<Session> sessions = [];
  bool loading = false;

  Future<void> refresh() async {
    loading = true;
    notifyListeners();
    sessions = await store.list();
    loading = false;
    notifyListeners();
  }

  Future<void> delete(Session s) async {
    await store.delete(s.id);
    sessions.removeWhere((e) => e.id == s.id);
    notifyListeners();
  }
}
