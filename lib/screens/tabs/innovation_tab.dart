import 'package:flutter/material.dart';

import '../../models/game_state.dart';
import '../../models/innovation.dart';

class InnovationTab extends StatelessWidget {
  const InnovationTab({super.key, required this.state, required this.onMessage});

  final GameState state;
  final void Function(String message) onMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(child: Text('Innovations', style: theme.textTheme.titleMedium)),
            Icon(Icons.lightbulb, size: 18, color: theme.colorScheme.tertiary),
            const SizedBox(width: 4),
            Text('${state.innovationPoints} point${state.innovationPoints > 1 ? 's' : ''}',
                style: theme.textTheme.titleSmall),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '+1 point toutes les 5 interventions, +1 par succès, +2 pour un rapport mensuel à 70 ou plus.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        for (final innovation in Innovation.values)
          _InnovationCard(state: state, innovation: innovation, onMessage: onMessage),
      ],
    );
  }
}

class _InnovationCard extends StatelessWidget {
  const _InnovationCard({
    required this.state,
    required this.innovation,
    required this.onMessage,
  });

  final GameState state;
  final Innovation innovation;
  final void Function(String message) onMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final unlocked = state.has(innovation);
    final prerequisite = innovation.requires;
    final missing = prerequisite != null && !state.has(prerequisite) ? prerequisite : null;

    return Card(
      elevation: 0,
      color: unlocked ? const Color(0xFFE1F5EE) : Colors.white,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: unlocked ? const Color(0xFF1D9E75) : scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: unlocked ? const Color(0xFF1D9E75) : scheme.primaryContainer,
              child: Icon(innovation.icon,
                  color: unlocked ? Colors.white : scheme.onPrimaryContainer),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(innovation.label, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(innovation.description, style: theme.textTheme.bodySmall),
                  if (missing != null) ...[
                    const SizedBox(height: 4),
                    Text('Nécessite : ${missing.label}',
                        style: theme.textTheme.labelSmall?.copyWith(color: scheme.outline)),
                  ],
                  const SizedBox(height: 8),
                  if (unlocked)
                    Text('Débloqué',
                        style: theme.textTheme.labelMedium
                            ?.copyWith(color: const Color(0xFF0F6E56)))
                  else
                    FilledButton.tonal(
                      onPressed: state.canUnlock(innovation)
                          ? () => onMessage(state.unlockInnovation(innovation))
                          : null,
                      child: Text('Débloquer · ${innovation.cost} pts'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
