import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:systole/main.dart';
import 'package:systole/services/session_store.dart';
import 'package:systole/state/history_controller.dart';
import 'package:systole/state/monitor_controller.dart';
import 'package:systole/state/profile_controller.dart';

void main() {
  testWidgets('shows the connect screen and navigates tabs', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = SessionStore();
    final profile = ProfileController();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: profile),
          ChangeNotifierProvider(
            create: (_) =>
                MonitorController(store: store, profile: () => profile.profile),
          ),
          ChangeNotifierProvider(create: (_) => HistoryController(store)),
        ],
        child: const SystoleApp(),
      ),
    );

    expect(find.text('No sensor connected'), findsOneWidget);
    expect(find.text('Connect sensor'), findsOneWidget);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Save profile'), findsOneWidget);
  });
}
