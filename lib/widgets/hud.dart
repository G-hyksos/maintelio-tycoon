import 'package:flutter/material.dart';

import '../models/game_event.dart';
import '../models/game_state.dart';
import '../models/site.dart';
import '../utils/format.dart';

class Hud extends StatelessWidget {
  const Hud({super.key, required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final site = state.currentSite;
    final satisfaction = site.satisfaction.round();
    final satisfactionColor = satisfaction >= 70
        ? const Color(0xFF0F6E56)
        : satisfaction >= 40
            ? const Color(0xFF854F0B)
            : const Color(0xFFA32D2D);
    final event = state.activeEvent;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        children: [
          Row(
            children: [
              Icon(site.type.icon, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${site.name} · Jour ${state.day} · ${state.timeLabel}',
                  style: theme.textTheme.labelMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (state.innovationPoints > 0)
                Row(
                  children: [
                    Icon(Icons.lightbulb, size: 14, color: theme.colorScheme.tertiary),
                    const SizedBox(width: 2),
                    Text('${state.innovationPoints}', style: theme.textTheme.labelMedium),
                  ],
                ),
            ],
          ),
          if (event != null) ...[
            const SizedBox(height: 8),
            _EventBanner(state: state, event: event),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              _Metric(label: state.moneyLabel, value: formatMoney(state.money)),
              const SizedBox(width: 8),
              _Metric(
                label: 'Satisfaction',
                value: '$satisfaction %',
                valueColor: satisfactionColor,
              ),
              const SizedBox(width: 8),
              _Metric(label: state.objectiveLabel, value: state.objectiveValue),
            ],
          ),
        ],
      ),
    );
  }
}

class _EventBanner extends StatelessWidget {
  const _EventBanner({required this.state, required this.event});

  final GameState state;
  final ActiveEvent event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final siteName = event.siteId == null ? null : state.siteById(event.siteId!)?.name;
    final scoped = event.type == GameEventType.coupure || event.type == GameEventType.audit;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFAEEDA),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(event.type.icon, size: 18, color: const Color(0xFF854F0B)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${event.type.label}${scoped && siteName != null ? ' · $siteName' : ''} — ${event.type.description}',
              style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFF633806)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F4F3),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: theme.textTheme.labelSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: theme.textTheme.titleSmall?.copyWith(color: valueColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
