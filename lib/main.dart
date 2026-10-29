import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:provider/provider.dart';

import 'services/session_store.dart';
import 'state/history_controller.dart';
import 'state/monitor_controller.dart';
import 'state/profile_controller.dart';
import 'ui/home_shell.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterBluePlus.setLogLevel(LogLevel.warning, color: false);

  final store = SessionStore();
  final profile = ProfileController();
  await profile.load();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: profile),
        ChangeNotifierProvider(
          create: (_) =>
              MonitorController(store: store, profile: () => profile.profile),
        ),
        ChangeNotifierProvider(
          create: (_) => HistoryController(store)..refresh(),
        ),
      ],
      child: const SystoleApp(),
    ),
  );
}

class SystoleApp extends StatelessWidget {
  const SystoleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Systole',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      home: const HomeShell(),
    );
  }
}
