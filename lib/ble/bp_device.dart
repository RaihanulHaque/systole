import '../models/user_profile.dart';
import 'protocol.dart';

enum LinkState { disconnected, connecting, connected }

/// A source of PPG samples and BP estimates: real hardware or the simulator.
abstract class BpDevice {
  String get id;
  String get name;
  bool get isDemo;

  /// Available after [connect] completes.
  DeviceInfo? get info;

  Stream<LinkState> get linkState;
  Stream<PpgPacket> get ppg;
  Stream<BpResult> get results;
  Stream<int> get battery;

  Future<void> connect();
  Future<void> disconnect();

  Future<void> sendProfile(UserProfile profile);
  Future<void> sendCalibration(double sbp, double dbp);
  Future<void> sendControl(int op);

  void dispose();
}
