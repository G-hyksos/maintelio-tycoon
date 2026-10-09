import 'dart:async';

import 'package:flutter/material.dart';

import '../game/site_game.dart';
import '../models/game_state.dart';
import '../services/audio_service.dart';
import '../services/monetization_service.dart';
import '../services/notification_service.dart';
import '../services/save_service.dart';
import '../widgets/diagnostic_sheet.dart';
import '../widgets/dialogs.dart';
import '../widgets/hud.dart';
import '../widgets/tutorial_overlay.dart';
import 'role_select_screen.dart';
import 'tabs/innovation_tab.dart';
import 'tabs/map_tab.dart';
import 'tabs/report_tab.dart';
import 'tabs/stock_tab.dart';
import 'tabs/team_tab.dart';

enum _MenuAction { sound, tutorial, premium, role }

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.state});

  final GameState state;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  static const Duration _tickInterval = Duration(milliseconds: 100);
  static const double _autosaveEvery = 10;
  static const int _minAbsenceMs = 5000;
  static const double _absenceDialogFrom = 30;

  late final SiteGame _game = SiteGame(widget.state);
  final SaveService _save = SaveService();
  final Stopwatch _watch = Stopwatch();
  Timer? _timer;
  double _sinceSave = 0;
  int _tab = 0;
  int _modalDepth = 0;
  int _tickCount = 0;
  bool _showTutorial = false;
  DateTime? _pausedAt;

  GameState get state => widget.state;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _game.onEquipmentTap = _onEquipmentTap;
    _showTutorial = !state.tutorialDone;
    NotificationService.instance.cancelAll();
    _start();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final last = state.lastSavedAt;
      if (last > 0) {
        _catchUp(DateTime.now().millisecondsSinceEpoch - last);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stop();
    _save.save(state);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    if (lifecycle == AppLifecycleState.resumed) {
      NotificationService.instance.cancelAll();
      final pausedAt = _pausedAt;
      _pausedAt = null;
      if (pausedAt != null) {
        _catchUp(DateTime.now().difference(pausedAt).inMilliseconds);
      }
      _start();
    } else if (lifecycle == AppLifecycleState.paused ||
        lifecycle == AppLifecycleState.detached) {
      if (_pausedAt != null) return;
      _pausedAt = DateTime.now();
      _stop();
      _save.save(state);
      _scheduleBreakdownNotification();
    } else {
      _stop();
    }
  }

  void _scheduleBreakdownNotification() {
    if (!state.tutorialDone) return;
    final next = state.nextPredictedBreakdown(offline: true);
    if (next == null || next.seconds > GameState.maxAbsence) return;
    NotificationService.instance.scheduleBreakdown(
      equipmentName: next.name,
      delay: Duration(seconds: next.seconds.ceil()),
    );
  }

  /// Rattrape le temps passé hors de l'application.
  Future<void> _catchUp(int elapsedMs) async {
    if (elapsedMs < _minAbsenceMs || !state.tutorialDone) return;
    final report = state.simulateAbsence(elapsedMs / 1000);
    await _save.save(state);
    if (!mounted || report.seconds < _absenceDialogFrom) return;
    await _modal(() => showAbsenceDialog(context, report));
  }

  /// La logique avance via ce timer, indépendamment de l'onglet affiché.
  void _start() {
    if (_timer != null) return;
    _watch
      ..reset()
      ..start();
    _timer = Timer.periodic(_tickInterval, (_) {
      final dt = (_watch.elapsedMicroseconds / 1e6).clamp(0, 0.5).toDouble();
      _watch.reset();
      if (_modalDepth > 0 || _showTutorial) return;
      // L'interface est rafraîchie 3 à 4 fois par seconde ; la carte Flame en continu.
      state.tick(dt, notify: _tickCount++ % 3 == 0);
      _handleSignals();
      _sinceSave += dt;
      if (_sinceSave >= _autosaveEvery) {
        _sinceSave = 0;
        _save.save(state);
      }
    });
  }

  /// Met le jeu en pause pendant une fenêtre modale.
  Future<T> _modal<T>(Future<T> Function() open) async {
    _modalDepth += 1;
    try {
      return await open();
    } finally {
      _modalDepth -= 1;
    }
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    _watch.stop();
  }

  void _handleSignals() {
    for (final signal in state.drainSignals()) {
      AudioService.instance.react(signal.type);
      if (signal.type != SignalType.panne && signal.type != SignalType.reparation) {
        _showMessage(signal.message);
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted || message.isEmpty) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ));
  }

  Future<void> _onEquipmentTap(String equipmentId) async {
    final e = state.equipmentById(equipmentId);
    if (e == null) return;
    if (state.needsDiagnostic(e)) {
      final message = await _modal(() => showDiagnosticSheet(context, state, e));
      if (message != null) _showMessage(message);
      _handleSignals();
      return;
    }
    final message = state.tapEquipment(equipmentId);
    if (message != null) {
      _showMessage(message);
    } else {
      AudioService.instance.tap();
    }
    _handleSignals();
  }

  Future<void> _adBoost() async {
    if (state.adBoostRemaining > 0) {
      _showMessage('Boost disponible dans ${state.adBoostRemaining.ceil()} s');
      return;
    }
    final rewarded = await _modal(() => MonetizationService.instance
        .showRewardedAd(() => showDemoAd(context)));
    if (!rewarded) return;
    _showMessage(state.applyAdBoost());
    _handleSignals();
  }

  Future<void> _onMenu(_MenuAction action) async {
    switch (action) {
      case _MenuAction.sound:
        final audio = AudioService.instance;
        audio.enabled = !audio.enabled;
        await _save.setSoundEnabled(audio.enabled);
        if (mounted) setState(() {});
      case _MenuAction.tutorial:
        setState(() => _showTutorial = true);
      case _MenuAction.premium:
        await _modal(() => showPremiumSheet(context));
        if (mounted) setState(() {});
      case _MenuAction.role:
        await _changeRole();
    }
  }

  void _finishTutorial() {
    state.finishTutorial();
    _save.save(state);
    setState(() => _showTutorial = false);
  }

  Future<void> _changeRole() async {
    _stop();
    await _save.save(state);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const RoleSelectScreen(firstLaunch: false)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ListenableBuilder(
          listenable: state,
          builder: (context, _) => _buildScaffold(context),
        ),
        if (_showTutorial)
          Positioned.fill(
            child: TutorialOverlay(info: state.info, onFinish: _finishTutorial),
          ),
      ],
    );
  }

  Widget _buildScaffold(BuildContext context) {
    final theme = Theme.of(context);
    final soundOn = AudioService.instance.enabled;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Maintelio Tycoon'),
            Text(
              '${state.info.label} · Contrat ${state.tier.name}',
              style: theme.textTheme.labelMedium,
            ),
          ],
        ),
        actions: [
          PopupMenuButton<_MenuAction>(
            onSelected: _onMenu,
            itemBuilder: (_) => [
              PopupMenuItem(
                value: _MenuAction.sound,
                child: ListTile(
                  leading: Icon(soundOn ? Icons.volume_up : Icons.volume_off),
                  title: Text(soundOn ? 'Couper le son' : 'Activer le son'),
                ),
              ),
              const PopupMenuItem(
                value: _MenuAction.tutorial,
                child: ListTile(leading: Icon(Icons.school_outlined), title: Text('Revoir le tutoriel')),
              ),
              PopupMenuItem(
                value: _MenuAction.premium,
                child: ListTile(
                  leading: const Icon(Icons.workspace_premium_outlined),
                  title: Text(MonetizationService.instance.premium ? 'Premium actif' : 'Premium'),
                ),
              ),
              const PopupMenuItem(
                value: _MenuAction.role,
                child: ListTile(leading: Icon(Icons.switch_account), title: Text('Changer de rôle')),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Hud(state: state),
          Expanded(
            child: IndexedStack(
              index: _tab,
              children: [
                MapTab(
                  state: state,
                  game: _game,
                  onMessage: _showMessage,
                  onAdBoost: _adBoost,
                ),
                TeamTab(state: state, onMessage: _showMessage),
                StockTab(state: state, onMessage: _showMessage),
                InnovationTab(state: state, onMessage: _showMessage),
                ReportTab(state: state, onMessage: _showMessage),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) => setState(() => _tab = index),
        destinations: [
          const NavigationDestination(icon: Icon(Icons.map_outlined), label: 'Carte'),
          const NavigationDestination(icon: Icon(Icons.groups_outlined), label: 'Équipe'),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: !state.info.isClient && state.stockLow,
              child: const Icon(Icons.inventory_2_outlined),
            ),
            label: 'Stock',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: state.innovationPoints > 0,
              label: Text('${state.innovationPoints}'),
              child: const Icon(Icons.lightbulb_outline),
            ),
            label: 'Innovation',
          ),
          const NavigationDestination(icon: Icon(Icons.bar_chart), label: 'Rapport'),
        ],
      ),
    );
  }
}
