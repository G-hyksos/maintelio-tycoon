import 'package:flutter/material.dart';

import '../../models/equipment.dart';
import '../../models/game_state.dart';
import '../../models/innovation.dart';
import '../../utils/format.dart';

class StockTab extends StatelessWidget {
  const StockTab({super.key, required this.state, required this.onMessage});

  final GameState state;
  final void Function(String message) onMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final info = state.info;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Stock de pièces', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        if (info.isClient)
          _Panel(
            child: Text('Le stock de pièces est géré par votre prestataire.',
                style: theme.textTheme.bodyMedium),
          )
        else
          _PartsPanel(state: state, onMessage: onMessage),
        const SizedBox(height: 24),
        Text('Capteurs IoT · ${state.currentSite.name}', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Un capteur affiche la santé en continu, alerte sous 50 % et réduit l’usure de 10 %.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        if (!state.has(Innovation.gtbIot))
          _Panel(
            child: Row(
              children: [
                Icon(Icons.lock_outline, color: theme.colorScheme.outline),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Débloquez « ${Innovation.gtbIot.label} » dans l’onglet Innovation.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          )
        else
          for (final e in state.currentEquipments)
            _SensorRow(state: state, equipment: e, onMessage: onMessage),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: child,
    );
  }
}

class _PartsPanel extends StatelessWidget {
  const _PartsPanel({required this.state, required this.onMessage});

  final GameState state;
  final void Function(String message) onMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const orderCost = GameState.restockQuantity * GameState.partPrice;
    final low = state.stockLow;
    final ratio = (state.parts / GameState.stockCapacity).clamp(0.0, 1.0);
    final arrival = state.restockArrivesAt;
    final barColor = low ? const Color(0xFFBA7517) : const Color(0xFF1D9E75);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${state.parts} / ${GameState.stockCapacity}',
                  style: theme.textTheme.headlineMedium),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 8,
                  color: barColor,
                  backgroundColor: const Color(0xFFE9ECEB),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                low
                    ? "Seuil d'alerte atteint (${GameState.stockAlertThreshold} pièces)"
                    : 'Chaque intervention consomme 1 pièce. Une mauvaise pièce posée est perdue.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: low ? const Color(0xFF854F0B) : null,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (state.info.canRestock)
          FilledButton.icon(
            icon: const Icon(Icons.add_shopping_cart),
            label: Text(
                'Commander ${GameState.restockQuantity} pièces (${formatMoney(orderCost)})'),
            onPressed: () => onMessage(state.restock()),
          )
        else
          FilledButton.icon(
            icon: const Icon(Icons.local_shipping_outlined),
            label: Text(arrival == null
                ? 'Demander un réapprovisionnement'
                : 'Livraison dans ${(arrival - state.clock).ceil()} s'),
            onPressed: arrival == null ? () => onMessage(state.restock()) : null,
          ),
      ],
    );
  }
}

class _SensorRow extends StatelessWidget {
  const _SensorRow({required this.state, required this.equipment, required this.onMessage});

  final GameState state;
  final Equipment equipment;
  final void Function(String message) onMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                Text(
                  equipment.hasSensor
                      ? 'Santé ${equipment.health.round()} %'
                      : 'Sans capteur',
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
          ),
          if (equipment.hasSensor)
            const Icon(Icons.sensors, color: Color(0xFF534AB7))
          else
            TextButton(
              onPressed: () => onMessage(state.installSensor(equipment.id)),
              child: Text('Installer (${formatMoney(GameState.sensorCost)})'),
            ),
        ],
      ),
    );
  }
}
