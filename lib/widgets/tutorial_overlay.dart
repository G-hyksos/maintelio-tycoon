import 'package:flutter/material.dart';

import '../models/role.dart';
import 'role_portrait.dart';

class _TutorialStep {
  const _TutorialStep(this.title, this.text, this.alignment, this.icon);
  final String title;
  final String text;
  final Alignment alignment;
  final IconData icon;
}

List<_TutorialStep> _stepsFor(RoleInfo info) {
  const hud = Alignment(0, -0.55);
  const map = Alignment(0, 0.1);
  const bottom = Alignment(0, 0.75);
  final intro = _TutorialStep('Bienvenue, ${info.label.toLowerCase()}', info.description, map, info.icon);
  const innovation = _TutorialStep(
    'Innovations',
    'Gagnez des points avec les interventions, les succès et les bons rapports, puis débloquez QR codes, capteurs IoT, prédictif… dans l’onglet Innovation.',
    bottom,
    Icons.lightbulb_outline,
  );
  final specific = switch (info.role) {
    PlayerRole.gestionnaire => const [
        _TutorialStep('Votre tableau de bord',
            'Budget, satisfaction et disponibilité de votre site. Les événements du jour s’affichent ici.', hud, Icons.dashboard_outlined),
        _TutorialStep('Le prestataire intervient',
            'Il prend en charge les pannes avec un délai. Relancez-le, validez ses notes et appliquez des pénalités sur les pannes trop longues.', bottom, Icons.campaign_outlined),
        _TutorialStep('Capteurs IoT',
            'Après l’innovation GTB, installez des capteurs depuis l’onglet Stock pour voir l’usure en temps réel.', bottom, Icons.sensors),
      ],
    PlayerRole.dirigeant => const [
        _TutorialStep('Pilotez la rentabilité',
            'Trésorerie, satisfaction et marge quotidienne. Votre chef de site traite les pannes automatiquement.', hud, Icons.trending_up),
        _TutorialStep('Intervenez si besoin',
            'Glissez un technicien depuis le bas de l’écran sur un équipement en panne pour accélérer.', map, Icons.pan_tool_alt_outlined),
        _TutorialStep('Développez l’entreprise',
            'Recrutez et formez dans Équipe, ouvrez de nouveaux sites et signez de meilleurs contrats dans Rapport.', bottom, Icons.business_center_outlined),
      ],
    PlayerRole.chefSite => const [
        _TutorialStep('Votre site en un coup d’œil',
            'Trésorerie, satisfaction client et health score, l’indicateur de votre rapport mensuel.', hud, Icons.dashboard_outlined),
        _TutorialStep('Créez des ordres de travail',
            'Glissez un technicien sur un équipement en panne ou usé. Attention aux habilitations et à la fatigue.', map, Icons.pan_tool_alt_outlined),
        _TutorialStep('Stock, notes et planning',
            'Chaque intervention consomme une pièce. Envoyez une note au client chaque jour et planifiez le préventif dans Équipe.', bottom, Icons.edit_note),
      ],
    PlayerRole.adjoint => const [
        _TutorialStep('Votre objectif : la réactivité',
            'Le temps de réponse moyen aux pannes est votre indicateur principal.', hud, Icons.timer_outlined),
        _TutorialStep('Dispatchez vite',
            'Glissez un technicien sur chaque panne dès qu’elle apparaît. Choisissez la bonne spécialité.', map, Icons.pan_tool_alt_outlined),
        _TutorialStep('Pièces détachées',
            'Demandez un réapprovisionnement dans l’onglet Stock avant la rupture.', bottom, Icons.inventory_2_outlined),
      ],
    PlayerRole.technicien => const [
        _TutorialStep('À vous le terrain',
            'Touchez un équipement en panne ou usé : vous vous y rendez.', map, Icons.directions_walk),
        _TutorialStep('Diagnostiquez',
            'Sur place, scannez le QR code, choisissez la bonne pièce puis faites le réglage. Un diagnostic parfait accélère la réparation.', map, Icons.biotech),
        _TutorialStep('Réparez et récupérez',
            'Touchez l’équipement pour terminer. La fatigue ralentit vos gestes : laissez-vous souffler entre deux interventions.', bottom, Icons.handyman),
      ],
  };
  return [intro, ...specific, innovation];
}

/// Bulles explicatives affichées au premier lancement de chaque rôle.
class TutorialOverlay extends StatefulWidget {
  const TutorialOverlay({super.key, required this.info, required this.onFinish});

  final RoleInfo info;
  final VoidCallback onFinish;

  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<TutorialOverlay> {
  late final List<_TutorialStep> _steps = _stepsFor(widget.info);
  int _index = 0;

  void _next() {
    if (_index + 1 >= _steps.length) {
      widget.onFinish();
    } else {
      setState(() => _index += 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final step = _steps[_index];
    final last = _index + 1 == _steps.length;
    return Material(
      color: const Color(0x99000000),
      child: SafeArea(
        child: Align(
          alignment: step.alignment,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (_index == 0)
                        RolePortrait(role: widget.info.role, size: 44)
                      else
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: theme.colorScheme.primaryContainer,
                          child: Icon(step.icon, size: 20, color: theme.colorScheme.onPrimaryContainer),
                        ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(step.title, style: theme.textTheme.titleMedium)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(step.text, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (var i = 0; i < _steps.length; i++)
                        Container(
                          width: 7,
                          height: 7,
                          margin: const EdgeInsets.only(right: 5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i == _index
                                ? theme.colorScheme.primary
                                : theme.colorScheme.outlineVariant,
                          ),
                        ),
                      const Spacer(),
                      if (!last)
                        TextButton(onPressed: widget.onFinish, child: const Text('Passer')),
                      FilledButton(
                        onPressed: _next,
                        child: Text(last ? 'Commencer' : 'Suivant'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
