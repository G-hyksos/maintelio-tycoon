import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../game/site_game.dart';
import '../../models/equipment.dart';
import '../../models/game_state.dart';
import '../../models/role.dart';
import '../../models/site.dart';
import '../../models/technician.dart';
import '../../services/audio_service.dart';

class MapTab extends StatefulWidget {
  const MapTab({
    super.key,
    required this.state,
    required this.game,
    required this.onMessage,
    required this.onAdBoost,
  });

  final GameState state;
  final SiteGame game;
  final void Function(String message) onMessage;
  final VoidCallback onAdBoost;

  @override
  State<MapTab> createState() => _MapTabState();
}

class _MapTabState extends State<MapTab> {
  final GlobalKey _gameKey = GlobalKey();

  GameState get state => widget.state;

  String get _hint {
    final info = state.info;
    if (info.isClient) {
      return 'Le prestataire intervient sur les pannes. Relancez-le, validez ses notes ou appliquez des pénalités.';
    }
    if (info.selfRepair) {
      final me = state.player;
      final eqId = me?.assignedEquipmentId;
      if (eqId != null) {
        final e = state.equipmentById(eqId);
        if (e != null && state.needsDiagnostic(e)) {
          return "Touchez l'équipement pour lancer le diagnostic.";
        }
        return "Touchez l'équipement à plusieurs reprises pour le réparer.";
      }
      return 'Touchez un équipement en panne ou usé pour intervenir.';
    }
    final selectedId = state.selectedTechId;
    if (selectedId != null) {
      final tech = state.technicianById(selectedId);
      return "Touchez l'équipement à confier à ${tech?.name ?? 'ce technicien'}.";
    }
    if (info.role == PlayerRole.dirigeant) {
      return 'Votre chef de site traite les pannes. Glissez un technicien sur un équipement pour intervenir vous-même.';
    }
    return 'Glissez un technicien sur un équipement en panne ou usé, ou touchez-le puis touchez l’équipement.';
  }

  void _onDrop(DragTargetDetails<String> details) {
    final box = _gameKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(details.offset);
    final equipmentId = widget.game.equipmentAt(Vector2(local.dx, local.dy));
    if (equipmentId == null) {
      state.clearSelection();
      return;
    }
    final message = state.assign(details.data, equipmentId);
    state.clearSelection();
    if (message != null) {
      widget.onMessage(message);
    } else {
      AudioService.instance.tap();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final info = state.info;

    return Column(
      children: [
        if (state.sites.length > 1) _SiteSelector(state: state),
        Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.lightbulb_outline,
                  size: 18, color: theme.colorScheme.onPrimaryContainer),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _hint,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onPrimaryContainer),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final needed = SiteGame.requiredHeight(state.currentEquipments.length);
              final height =
                  needed > constraints.maxHeight ? needed : constraints.maxHeight;
              return SingleChildScrollView(
                child: DragTarget<String>(
                  onWillAcceptWithDetails: (_) => true,
                  onAcceptWithDetails: _onDrop,
                  builder: (context, candidates, rejected) => SizedBox(
                    key: _gameKey,
                    height: height,
                    child: GameWidget(game: widget.game),
                  ),
                ),
              );
            },
          ),
        ),
        if (info.canDispatch) _TechStrip(state: state, onMessage: widget.onMessage),
        _RoleActions(state: state, onMessage: widget.onMessage, onAdBoost: widget.onAdBoost),
      ],
    );
  }
}

class _SiteSelector extends StatelessWidget {
  const _SiteSelector({required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
        itemCount: state.sites.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final site = state.sites[index];
          final broken = state
              .siteEquipments(site.id)
              .where((e) => e.status == EquipmentStatus.panne)
              .length;
          return ChoiceChip(
            avatar: Icon(site.type.icon, size: 16),
            label: Text(broken > 0 ? '${site.name} · $broken' : site.name),
            selected: site.id == state.currentSite.id,
            onSelected: (_) => state.switchSite(site.id),
          );
        },
      ),
    );
  }
}

class _TechStrip extends StatelessWidget {
  const _TechStrip({required this.state, required this.onMessage});

  final GameState state;
  final void Function(String message) onMessage;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: state.technicians.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final tech = state.technicians[index];
          final available = state.isAvailable(tech);
          final chip = _TechChip(
            tech: tech,
            status: state.technicianStatus(tech),
            selected: state.selectedTechId == tech.id,
            available: available,
            onTap: () {
              final message = state.selectTech(tech.id);
              if (message != null) onMessage(message);
            },
          );
          return Draggable<String>(
            data: tech.id,
            maxSimultaneousDrags: available ? 1 : 0,
            affinity: Axis.vertical,
            dragAnchorStrategy: pointerDragAnchorStrategy,
            onDragStarted: () {
              if (state.selectedTechId != tech.id) state.selectTech(tech.id);
            },
            onDraggableCanceled: (_, __) => state.clearSelection(),
            feedback: _DragAvatar(initials: tech.initials),
            childWhenDragging: Opacity(opacity: 0.4, child: chip),
            child: chip,
          );
        },
      ),
    );
  }
}

class _DragAvatar extends StatelessWidget {
  const _DragAvatar({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(-24, -24),
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Color(0xFF185FA5),
            shape: BoxShape.circle,
          ),
          child: Text(
            initials,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

class _TechChip extends StatelessWidget {
  const _TechChip({
    required this.tech,
    required this.status,
    required this.selected,
    required this.available,
    required this.onTap,
  });

  final Technician tech;
  final String status;
  final bool selected;
  final bool available;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fatigueColor = tech.fatigue >= 80 ? const Color(0xFFE24B4A) : const Color(0xFF1D9E75);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        width: 96,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          color: available ? const Color(0xFFF1F4F3) : const Color(0xFFE4E7E6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? const Color(0xFF185FA5) : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: scheme.primaryContainer,
              child: Text(
                tech.initials,
                style: theme.textTheme.labelSmall?.copyWith(color: scheme.onPrimaryContainer),
              ),
            ),
            const SizedBox(height: 4),
            Text(tech.name,
                style: theme.textTheme.labelMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(
              selected ? 'Sélectionné' : status,
              style: theme.textTheme.labelSmall?.copyWith(
                color: selected ? const Color(0xFF185FA5) : scheme.outline,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: (tech.fatigue / 100).clamp(0.0, 1.0),
                minHeight: 3,
                color: fatigueColor,
                backgroundColor: const Color(0xFFDDE2E0),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleActions extends StatelessWidget {
  const _RoleActions({
    required this.state,
    required this.onMessage,
    required this.onAdBoost,
  });

  final GameState state;
  final void Function(String message) onMessage;
  final VoidCallback onAdBoost;

  @override
  Widget build(BuildContext context) {
    final info = state.info;
    final boostWait = state.adBoostRemaining;
    return Container(
      color: Colors.white,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (info.canWriteNote)
            FilledButton.tonalIcon(
              icon: const Icon(Icons.edit_note),
              label: const Text('Note au client'),
              onPressed: () => onMessage(state.writeNote()),
            ),
          if (info.isClient) ...[
            FilledButton.tonalIcon(
              icon: const Icon(Icons.campaign_outlined),
              label: const Text('Relancer'),
              onPressed: () => onMessage(state.relance()),
            ),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.gavel),
              label: const Text('Pénalité'),
              onPressed: () => onMessage(state.applyPenalty()),
            ),
            FilledButton.tonalIcon(
              icon: Badge(
                isLabelVisible: state.pendingNote,
                child: const Icon(Icons.task_alt),
              ),
              label: const Text('Valider la note'),
              onPressed: () => onMessage(state.validateNote()),
            ),
          ] else
            OutlinedButton.icon(
              icon: const Icon(Icons.bolt),
              label: Text(boostWait > 0 ? 'Boost · ${boostWait.ceil()} s' : 'Boost'),
              onPressed: onAdBoost,
            ),
        ],
      ),
    );
  }
}
