import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models/game_state.dart';
import 'screens/game_screen.dart';
import 'screens/role_select_screen.dart';
import 'services/audio_service.dart';
import 'services/monetization_service.dart';
import 'services/notification_service.dart';
import 'services/save_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Maintelio Tycoon',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F6E56)),
        scaffoldBackgroundColor: const Color(0xFFF6F8F7),
      ),
      home: const BootScreen(),
    );
  }
}

/// Premier lancement : choix du rôle. Ensuite : reprise du dernier rôle joué.
class BootScreen extends StatefulWidget {
  const BootScreen({super.key});

  @override
  State<BootScreen> createState() => _BootScreenState();
}

class _BootScreenState extends State<BootScreen> {
  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final save = SaveService();
    AudioService.instance.enabled = await save.soundEnabled();
    await Future.wait([
      AudioService.instance.preload(),
      NotificationService.instance.init(),
      MonetizationService.instance.load(),
    ]);

    final role = await save.lastRole();
    final Widget next;
    if (role == null) {
      next = const RoleSelectScreen(firstLaunch: true);
    } else {
      final state = await save.load(role) ?? GameState.newGame(role);
      next = GameScreen(state: state);
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => next));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.precision_manufacturing, size: 56, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text('Maintelio Tycoon', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text('La maintenance, simplement pilotée.', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
