import 'package:flutter/material.dart';

import '../../models/equipment.dart';
import '../../models/game_state.dart';
import '../../models/technician.dart';
import '../../utils/format.dart';

class TeamTab extends StatelessWidget {
  const TeamTab({super.key, required this.state, required this.onMessage});

  final GameState state;
  final void Function(String message) onMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final info = state.info;
    final title = info.isClient
        ? 'Équipe du prestataire'
        : info.selfRepair
            ? 'Votre fiche'
            : 'Votre équipe';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(title, style: theme.textTheme.titleMedium),
        if (!info.isClient && !info.selfRepair)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Masse salariale : ${formatMoney(state.dailySalaries)} / jour',
              style: theme.textTheme.bodySmall,
            ),
          ),
        const SizedBox(height: 12),
        for (final tech in state.technicians)
          _TechCard(
            state: state,
            tech: tech,
            canTrain: info.canTrain && (!info.selfRepair || tech.isPlayer),
            onMessage: onMessage,
          ),
        if (info.canRecruit) ...[
          const SizedBox(height: 4),
          FilledButton.icon(
            icon: const Icon(Icons.person_add_alt),
            label: Text('Recruter un technicien (${formatMoney(GameState.recruitCost)})'),
            onPressed: () => onMessage(state.recruit()),
          ),
        ],
        if (info.canDispatch) ...[
          const SizedBox(height: 24),
          Text('Planning préventif · ${state.currentSite.name}', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Une visite planifiée est réalisée le lendemain par le premier technicien disponible et remet l’équipement à neuf.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          for (final e in state.currentEquipments) _PlanningRow(state: state, equipment: e, onMessage: onMessage),
        ],
      ],
    );
  }
}

class _TechCard extends StatelessWidget {
  const _TechCard({
    required this.state,
    required this.tech,
    required this.canTrain,
    required this.onMessage,
  });

  final GameState state;
  final Technician tech;
  final bool canTrain;
  final void Function(String message) onMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fatigue = tech.fatigue.round();
    final tired = tech.fatigue >= 80;
    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(tech.initials),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${tech.name} · niveau ${tech.level}', style: theme.textTheme.titleSmall),
                      Text(
                        '${tech.specialty.specialtyLabel} · ${state.technicianStatus(tech)}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (!state.info.isClient && !tech.isPlayer)
                  Text('${formatMoney(tech.salary)}/j', style: theme.textTheme.labelMedium),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text('Fatigue $fatigue %', style: theme.textTheme.labelSmall),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: (tech.fatigue / 100).clamp(0.0, 1.0),
                      minHeight: 5,
                      color: tired ? const Color(0xFFE24B4A) : const Color(0xFF1D9E75),
                      backgroundColor: const Color(0xFFE9ECEB),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _Tag(icon: Icons.build_outlined, text: '${tech.jobs} intervention${tech.jobs > 1 ? 's' : ''}'),
                if (tech.electricallyCleared)
                  const _Tag(icon: Icons.electric_bolt, text: 'Habilité électrique'),
                if (tired) const _Tag(icon: Icons.bedtime_outlined, text: 'Ralenti par la fatigue'),
              ],
            ),
            if (canTrain) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (tech.level < Technician.maxLevel)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.school_outlined, size: 18),
                      label: Text('Former (${formatMoney(GameState.trainingCost)})'),
                      onPressed: () => onMessage(state.train(tech.id)),
                    ),
                  if (!tech.electricallyCleared)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.electric_bolt, size: 18),
                      label: Text('Habilitation (${formatMoney(GameState.clearanceCost)})'),
                      onPressed: () => onMessage(state.grantClearance(tech.id)),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F4F3),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.outline),
          const SizedBox(width: 4),
          Text(text, style: theme.textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _PlanningRow extends StatelessWidget {
  const _PlanningRow({required this.state, required this.equipment, required this.onMessage});

  final GameState state;
  final Equipment equipment;
  final void Function(String message) onMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final planned = equipment.scheduledDay;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(equipment.type.icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(equipment.name, style: theme.textTheme.bodyMedium),
                Text(state.statusLabel(equipment), style: theme.textTheme.labelSmall),
              ],
            ),
          ),
          TextButton(
            onPressed: equipment.inIntervention && planned == null
                ? null
                : () => onMessage(state.schedulePreventive(equipment.id)),
            child: Text(planned == null ? 'Planifier' : 'Annuler J$planned'),
          ),
        ],
      ),
    );
  }
}
