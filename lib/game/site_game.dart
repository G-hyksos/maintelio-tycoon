import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/particles.dart';
import 'package:flutter/foundation.dart';

import '../models/game_state.dart';
import 'equipment_component.dart';
import 'floor_component.dart';
import 'site_layout.dart';
import 'technician_component.dart';

/// Plan 2D du site courant : équipements et techniciens animés.
/// La logique tourne dans [GameState] ; ce jeu ne fait que l'afficher.
class SiteGame extends FlameGame {
  SiteGame(this.state);

  final GameState state;

  /// Appelé quand le joueur touche un équipement.
  void Function(String equipmentId)? onEquipmentTap;

  SiteLayout? layout;

  /// Horloge d'animation (fluide, indépendante du rythme de la logique).
  double time = 0;
  bool _dirty = true;

  final Map<String, EquipmentComponent> _cards = {};
  final Map<String, TechnicianComponent> _techs = {};
  List<String> _equipmentIds = const [];
  List<String> _techIds = const [];
  String _siteId = '';
  final Random _rng = Random();

  /// Hauteur minimale du plan pour [count] équipements.
  static double requiredHeight(int count) => SiteLayout.requiredHeight(count);

  @override
  Color backgroundColor() => const Color(0xFFE6ECEF);

  @override
  Future<void> onLoad() async {
    add(FloorComponent());
    _sync(force: true);
  }

  @override
  void onMount() {
    super.onMount();
    state.addListener(_markDirty);
    _dirty = true;
  }

  @override
  void onRemove() {
    state.removeListener(_markDirty);
    super.onRemove();
  }

  void _markDirty() => _dirty = true;

  @override
  void update(double dt) {
    time += dt;
    if (_dirty) _sync();
    super.update(dt);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _layout();
  }

  void tapEquipment(String equipmentId) => onEquipmentTap?.call(equipmentId);

  /// Équipement situé au point donné (coordonnées locales du jeu).
  String? equipmentAt(Vector2 point) {
    for (final entry in _cards.entries) {
      final card = entry.value;
      if (point.x >= card.position.x &&
          point.x <= card.position.x + card.size.x &&
          point.y >= card.position.y &&
          point.y <= card.position.y + card.size.y) {
        return entry.key;
      }
    }
    return null;
  }

  /// Place à l'atelier, parmi les techniciens présents sur ce site.
  Offset homeOf(String techId) {
    final current = layout;
    if (current == null) return Offset.zero;
    final present = <String>[];
    for (final tech in state.technicians) {
      final eqId = tech.assignedEquipmentId;
      final e = eqId == null ? null : state.equipmentById(eqId);
      if (e != null && e.siteId != state.currentSite.id) continue;
      present.add(tech.id);
    }
    final index = max(0, present.indexOf(techId));
    return current.home(index, present.length);
  }

  Offset? workSpotOf(String equipmentId) {
    final current = layout;
    final index = _equipmentIds.indexOf(equipmentId);
    if (current == null || index < 0) return null;
    return current.workSpot(index);
  }

  Offset? artCenterOf(String equipmentId) {
    final current = layout;
    final index = _equipmentIds.indexOf(equipmentId);
    if (current == null || index < 0) return null;
    return current.artCenter(index);
  }

  // ---------------------------------------------------------------------------
  // Effets
  // ---------------------------------------------------------------------------

  void spawnSmoke(Vector2 at) {
    add(
      ParticleSystemComponent(
        position: at,
        priority: 10,
        particle: Particle.generate(
          count: 3,
          lifespan: 1.4,
          generator: (i) => AcceleratedParticle(
            acceleration: Vector2(0, -6),
            speed: Vector2((_rng.nextDouble() - 0.5) * 18, -22 - _rng.nextDouble() * 18),
            child: CircleParticle(
              radius: 4 + _rng.nextDouble() * 4,
              paint: Paint()..color = const Color(0x6E5A6268),
            ),
          ),
        ),
      ),
    );
  }

  void spawnSparks(Vector2 at) {
    add(
      ParticleSystemComponent(
        position: at,
        priority: 10,
        particle: Particle.generate(
          count: 7,
          lifespan: 0.45,
          generator: (i) {
            final angle = _rng.nextDouble() * 2 * pi;
            return AcceleratedParticle(
              acceleration: Vector2(0, 160),
              speed: Vector2(cos(angle), sin(angle)) * (50 + _rng.nextDouble() * 60),
              child: CircleParticle(
                radius: 1.2 + _rng.nextDouble() * 1.2,
                paint: Paint()..color = const Color(0xFFF5B301),
              ),
            );
          },
        ),
      ),
    );
  }

  void spawnConfetti(Vector2 at) {
    const colors = [Color(0xFF1D9E75), Color(0xFFF5C518), Color(0xFF185FA5), Color(0xFFD85A30)];
    add(
      ParticleSystemComponent(
        position: at,
        priority: 10,
        particle: Particle.generate(
          count: 16,
          lifespan: 0.9,
          generator: (i) {
            final angle = -pi / 2 + (_rng.nextDouble() - 0.5) * 2.2;
            return AcceleratedParticle(
              acceleration: Vector2(0, 220),
              speed: Vector2(cos(angle), sin(angle)) * (70 + _rng.nextDouble() * 70),
              child: CircleParticle(
                radius: 2,
                paint: Paint()..color = colors[i % colors.length],
              ),
            );
          },
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Synchronisation avec l'état du jeu
  // ---------------------------------------------------------------------------

  void _sync({bool force = false}) {
    final equipmentIds = state.currentEquipments.map((e) => e.id).toList();
    final techIds = state.technicians.map((t) => t.id).toList();
    final siteChanged = state.currentSite.id != _siteId;
    final equipmentChanged = !listEquals(equipmentIds, _equipmentIds);
    final techChanged = !listEquals(techIds, _techIds);
    _dirty = false;
    if (!force && !siteChanged && !equipmentChanged && !techChanged) return;

    for (final id in _cards.keys.toList()) {
      if (!equipmentIds.contains(id)) _cards.remove(id)!.removeFromParent();
    }
    for (final id in equipmentIds) {
      if (!_cards.containsKey(id)) {
        final card = EquipmentComponent(id);
        _cards[id] = card;
        add(card);
      }
    }
    for (final id in _techs.keys.toList()) {
      if (!techIds.contains(id)) _techs.remove(id)!.removeFromParent();
    }
    for (final id in techIds) {
      if (!_techs.containsKey(id)) {
        final tech = TechnicianComponent(id);
        _techs[id] = tech;
        add(tech);
      }
    }
    if (siteChanged) {
      for (final tech in _techs.values) {
        tech.snapHome();
      }
    }
    _siteId = state.currentSite.id;
    _equipmentIds = equipmentIds;
    _techIds = techIds;
    _layout();
  }

  void _layout() {
    if (size.x <= 0 || size.y <= 0) return;
    final current = SiteLayout(width: size.x, height: size.y, count: _equipmentIds.length);
    layout = current;
    for (var i = 0; i < _equipmentIds.length; i++) {
      final card = _cards[_equipmentIds[i]];
      if (card == null) continue;
      final rect = current.slotRect(i);
      card
        ..position = Vector2(rect.left, rect.top)
        ..size = Vector2(rect.width, rect.height);
    }
  }
}
