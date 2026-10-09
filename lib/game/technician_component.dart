import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/painting.dart';

import '../models/equipment.dart';
import 'art/character_painter.dart';
import 'art/text_cache.dart';
import 'site_game.dart';
import 'site_layout.dart';

/// Technicien animé : marche dans l'allée, répare, se repose à l'atelier.
/// Sa position suit l'état du jeu ; il ne fait qu'afficher.
class TechnicianComponent extends Component with HasGameReference<SiteGame> {
  TechnicianComponent(this.techId) : super(priority: 5);

  final String techId;

  static const double _walkSpeed = 80;
  static const double _tiredWalkSpeed = 45;
  static const double _celebrateDuration = 0.9;
  static const double _sparkEvery = 0.35;
  static const Color _accent = Color(0xFF185FA5);

  final Paint _paint = Paint()..isAntiAlias = true;
  final Paint _ring = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;

  Offset _pos = Offset.zero;
  bool _placed = false;
  bool _visible = true;
  Offset? _from;
  String? _targetId;
  Pose _pose = Pose.idle;
  bool _facingLeft = false;
  double _anim = 0;
  double _celebrate = 0;
  double _sparkTimer = 0;
  double _shown = 0;
  CharacterLook? _look;

  /// Replace le technicien à l'atelier (changement de site).
  void snapHome() {
    _placed = false;
    _targetId = null;
    _from = null;
  }

  @override
  void update(double dt) {
    super.update(dt);
    final state = game.state;
    final tech = state.technicianById(techId);
    final layout = game.layout;
    if (tech == null) {
      removeFromParent();
      return;
    }
    if (layout == null) return;
    _look ??= CharacterLook.of(tech);
    _anim += dt;

    final home = game.homeOf(techId);
    if (!_placed) {
      _pos = home;
      _placed = true;
    }
    final previous = _pos;

    final eqId = tech.assignedEquipmentId;
    final e = eqId == null ? null : state.equipmentById(eqId);
    if (e != null && e.siteId != state.currentSite.id) {
      // Intervention sur un autre site : absent de ce plan.
      _visible = false;
      _pos = home;
      _targetId = e.id;
      return;
    }
    _visible = true;

    if (e != null) {
      final spot = game.workSpotOf(e.id) ?? home;
      if (_targetId != e.id) {
        _targetId = e.id;
        _from = _pos;
        _shown = 0;
      }
      if (e.travelRemaining > 0) {
        final total = e.travelTotal > 0 ? e.travelTotal : max(e.travelRemaining, state.travelTime);
        // La logique avance par pas de 0,1 s : on lisse l'avancée affichée.
        final target = (1 - e.travelRemaining / total).clamp(0.0, 1.0);
        _shown = max(target, min(_shown + dt / total, target + 0.1 / total));
        _pos = SiteLayout.pointAtFraction(layout.route(_from ?? home, spot), _shown);
        _pose = Pose.walk;
      } else {
        _pos = spot;
        _pose = state.needsDiagnostic(e) ? Pose.think : Pose.repair;
        final art = game.artCenterOf(e.id);
        if (art != null) _facingLeft = art.dx < _pos.dx;
        if (_pose == Pose.repair) _spawnSparks(dt);
      }
    } else {
      final finishedId = _targetId;
      if (finishedId != null) {
        final finished = state.equipmentById(finishedId);
        if (finished != null && finished.status == EquipmentStatus.ok && finished.siteId == state.currentSite.id) {
          _celebrate = _celebrateDuration;
          game.spawnConfetti(Vector2(_pos.dx, _pos.dy - 60));
        }
        _targetId = null;
        _from = null;
      }
      if (_celebrate > 0) {
        _celebrate -= dt;
        _pose = Pose.celebrate;
      } else if ((_pos - home).distance > 1) {
        final speed = tech.fatigue >= 80 ? _tiredWalkSpeed : _walkSpeed;
        _pos = SiteLayout.pointAtDistance(layout.route(_pos, home), speed * dt);
        _pose = Pose.walk;
      } else {
        _pos = home;
        if (tech.fatigue >= 95) {
          _pose = Pose.sit;
        } else if (tech.fatigue >= 80) {
          _pose = Pose.tired;
        } else if (state.isTraining(tech)) {
          _pose = Pose.think;
        } else {
          _pose = Pose.idle;
        }
      }
    }

    final dx = _pos.dx - previous.dx;
    if (_pose == Pose.walk && dx.abs() > 0.05) _facingLeft = dx < 0;
  }

  void _spawnSparks(double dt) {
    _sparkTimer += dt;
    if (_sparkTimer < _sparkEvery) return;
    _sparkTimer = 0;
    final side = _facingLeft ? -1.0 : 1.0;
    game.spawnSparks(Vector2(_pos.dx + side * 20, _pos.dy - 40));
  }

  @override
  void render(Canvas canvas) {
    final look = _look;
    if (!_visible || look == null) return;
    final state = game.state;
    final tech = state.technicianById(techId);
    if (tech == null) return;

    canvas.save();
    canvas.translate(_pos.dx, _pos.dy);

    if (state.selectedTechId == techId) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: 34, height: 12),
        _ring..color = _accent,
      );
    }

    paintCharacter(canvas, look, pose: _pose, time: _anim, facingLeft: _facingLeft);

    // Nom au-dessus de la tête, aux couleurs de la spécialité.
    final label = tech.isPlayer ? 'Vous' : tech.name;
    final textPainter = TextCache.get(
      label,
      const TextStyle(color: Color(0xFFFFFFFF), fontSize: 10, fontWeight: FontWeight.w600),
    );
    final labelRect = Rect.fromCenter(
      center: const Offset(0, -66),
      width: textPainter.width + 10,
      height: 15,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(labelRect, const Radius.circular(7.5)),
      _paint..color = look.body,
    );
    textPainter.paint(canvas, labelRect.center - Offset(textPainter.width / 2, textPainter.height / 2));

    // Bulles d'état.
    if (_pose == Pose.sit) {
      final z = (_anim * 1.5) % 1;
      TextCache.drawCentered(
        canvas,
        'z',
        const TextStyle(color: Color(0xFF5F6B70), fontSize: 12, fontWeight: FontWeight.w700),
        Offset(16, -54 - z * 8),
      );
    } else if (_pose == Pose.think) {
      canvas.drawCircle(const Offset(17, -58), 8, _paint..color = const Color(0xFFFFFFFF));
      if (state.isTraining(tech) && tech.assignedEquipmentId == null) {
        TextCache.drawIcon(canvas, Icons.menu_book, 11, _accent, const Offset(17, -58));
      } else {
        TextCache.drawCentered(
          canvas,
          '?',
          const TextStyle(color: _accent, fontSize: 11, fontWeight: FontWeight.w700),
          const Offset(17, -58),
        );
      }
    }

    canvas.restore();
  }
}
