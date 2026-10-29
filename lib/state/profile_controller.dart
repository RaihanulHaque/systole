import 'package:flutter/foundation.dart';

import '../models/user_profile.dart';

class ProfileController extends ChangeNotifier {
  UserProfile _profile = const UserProfile();
  bool _isSet = false;

  UserProfile get profile => _profile;

  /// False until the user saves a profile for the first time.
  bool get isSet => _isSet;

  Future<void> load() async {
    final p = await UserProfile.load();
    if (p != null) {
      _profile = p;
      _isSet = true;
      notifyListeners();
    }
  }

  Future<void> update(UserProfile p) async {
    _profile = p;
    _isSet = true;
    notifyListeners();
    await p.save();
  }
}
