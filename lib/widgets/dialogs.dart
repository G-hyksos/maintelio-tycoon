import 'dart:async';

import 'package:flutter/material.dart';

import '../models/game_state.dart';
import '../services/monetization_service.dart';
import '../utils/format.dart';

/// Résumé de ce qui s'est passé pendant l'absence du joueur.
Future<void> showAbsenceDialog(BuildContext context, AbsenceReport report) {
  final minutes = (report.seconds / 60).round();
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.nightlight_round),
      title: const Text('Pendant votre absence'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$minutes min de jeu simulées, usure ralentie, équipe d’astreinte active.'),
          const SizedBox(height: 12),
          _line(Icons.warning_amber, '${report.breakdowns} panne${report.breakdowns > 1 ? 's' : ''}'),
          _line(Icons.build_circle_outlined,
              '${report.repairs} intervention${report.repairs > 1 ? 's' : ''} terminée${report.repairs > 1 ? 's' : ''}'),
          _line(Icons.account_balance_wallet_outlined,
              '${report.moneyDelta >= 0 ? '+' : ''}${formatMoney(report.moneyDelta)}'),
        ],
      ),
      actions: [
        FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Reprendre')),
      ],
    ),
  );
}

Widget _line(IconData icon, String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [Icon(icon, size: 18), const SizedBox(width: 8), Text(text)]),
    );

/// Publicité récompensée simulée (version de démonstration).
Future<bool> showDemoAd(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _DemoAdDialog(),
  );
  return result ?? false;
}

class _DemoAdDialog extends StatefulWidget {
  const _DemoAdDialog();

  @override
  State<_DemoAdDialog> createState() => _DemoAdDialogState();
}

class _DemoAdDialogState extends State<_DemoAdDialog> {
  late int _remaining = MonetizationService.demoAdDuration.inSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remaining <= 1) timer.cancel();
      setState(() => _remaining -= 1);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final done = _remaining <= 0;
    return AlertDialog(
      title: const Text('Publicité'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 120,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F4F3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(done ? 'Récompense disponible' : 'Publicité de démonstration · $_remaining s'),
          ),
          const SizedBox(height: 8),
          const Text('Version de démonstration : aucune régie publicitaire n’est branchée.',
              style: TextStyle(fontSize: 12)),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Fermer')),
        FilledButton(
          onPressed: done ? () => Navigator.of(context).pop(true) : null,
          child: const Text('Récupérer'),
        ),
      ],
    );
  }
}

/// Offre Premium (achat simulé en version de démonstration).
Future<void> showPremiumSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => const _PremiumSheet(),
  );
}

class _PremiumSheet extends StatefulWidget {
  const _PremiumSheet();

  @override
  State<_PremiumSheet> createState() => _PremiumSheetState();
}

class _PremiumSheetState extends State<_PremiumSheet> {
  final MonetizationService _service = MonetizationService.instance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final premium = _service.premium;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Maintelio Tycoon Premium', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(MonetizationService.premiumPrice, style: theme.textTheme.titleSmall),
            const SizedBox(height: 12),
            _line(Icons.block, 'Aucune publicité'),
            _line(Icons.bolt, 'Boost de réparation sans publicité'),
            _line(Icons.favorite_outline, 'Soutien au développement du jeu'),
            const SizedBox(height: 8),
            if (MonetizationService.isDemo)
              Text('Version de démonstration : aucun paiement n’est effectué.',
                  style: theme.textTheme.bodySmall),
            const SizedBox(height: 16),
            if (premium)
              OutlinedButton(
                onPressed: () async {
                  await _service.cancelSubscription();
                  if (mounted) setState(() {});
                },
                child: const Text('Résilier'),
              )
            else
              FilledButton(
                onPressed: () async {
                  await _service.subscribe();
                  if (mounted) setState(() {});
                },
                child: const Text('S’abonner'),
              ),
          ],
        ),
      ),
    );
  }
}
