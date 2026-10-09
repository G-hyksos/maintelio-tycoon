import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

import '../models/equipment.dart';
import '../models/innovation.dart';
import 'art/equipment_painter.dart';
import 'art/text_cache.dart';
import 'site_game.dart';

class _Palette {
  const _Palette(this.background, this.border, this.foreground, this.nameStyle, this.statusStyle);
  final Color background;
  final Color border;
  final Color foreground;
  final TextStyle nameStyle;
  final TextStyle statusStyle;
}

const _okPalette = _Palette(
  Color(0xFFE1F5EE),
  Color(0xFF1D9E75),
  Color(0xFF085041),
  TextStyle(color: Color(0xFF085041), fontSize: 11, fontWeight: FontWeight.w600),
  TextStyle(color: Color(0xFF085041), fontSize: 10),
);
const _wearPalette = _Palette(
  Color(0xFFFAEEDA),
  Color(0xFFBA7517),
  Color(0xFF633806),
  TextStyle(color: Color(0xFF633806), fontSize: 11, fontWeight: FontWeight.w600),
  TextStyle(color: Color(0xFF633806), fontSize: 10),
);
const _brokenPalette = _Palette(
  Color(0xFFFCEBEB),
  Color(0xFFE24B4A),
  Color(0xFF791F1F),
  TextStyle(color: Color(0xFF791F1F), fontSize: 11, fontWeight: FontWeight.w600),
  TextStyle(color: Color(0xFF791F1F), fontSize: 10),
);
const _accent = Color(0xFF185FA5);
const _track = Color(0x22000000);
const _sensor = Color(0xFF534AB7);

/// Un équipement dessiné en 2D sur le plan du site.
class EquipmentComponent extends PositionComponent
    with TapCallbacks, HasGameReference<SiteGame> {
  EquipmentComponent(this.equipmentId);

  final String equipmentId;

  static const double _shakeDuration = 0.6;
  static const double _smokeEvery = 0.45;

  final Paint _paint = Paint()..isAntiAlias = true;
  final Paint _outline = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke;

  EquipmentStatus? _lastStatus;
  double _shake = 0;
  double _smokeTimer = 0;

  Vector2 get _artTop => Vector2(position.x + (size.x - equipmentArtSize.width) / 2, position.y + 4);

  @override
  void update(double dt) {
    super.update(dt);
    if (_shake > 0) _shake = max(0.0, _shake - dt);

    final e = game.state.equipmentById(equipmentId);
    if (e == null) return;
    final status = e.status;
    if (_lastStatus != null && status == EquipmentStatus.panne && _lastStatus != EquipmentStatus.panne) {
      _shake = _shakeDuration;
    }
    _lastStatus = status;

    if (status == EquipmentStatus.panne && !e.inIntervention) {
      _smokeTimer += dt;
      if (_smokeTimer >= _smokeEvery) {
        _smokeTimer = 0;
        game.spawnSmoke(_artTop + Vector2(equipmentArtSize.width / 2, 8));
      }
    } else {
      _smokeTimer = 0;
    }
  }

  String _compactStatus(Equipment e) {
    final state = game.state;
    if (e.inIntervention) {
      if (e.travelRemaining > 0) return 'En route';
      if (state.needsDiagnostic(e)) return 'Diagnostic requis';
      final percent = (e.repairProgress * 100).clamp(0, 100).round();
      return '${e.preventive ? 'Préventif' : 'Réparation'} $percent %';
    }
    if (e.hasSensor && state.has(Innovation.predictif) && e.health > 0) {
      final rate = e.decayRate * state.decayMultiplier(e);
      if (rate > 0) return 'Panne dans ~${(e.health / rate).round()} s';
    }
    final planned = e.scheduledDay;
    return switch (e.status) {
      EquipmentStatus.panne => 'En panne',
      EquipmentStatus.usure => planned != null ? 'Usure · visite J$planned' : 'Usure détectée',
      EquipmentStatus.ok => planned != null
          ? 'Visite J$planned'
          : (e.hasSensor ? 'Santé ${e.health.round()} %' : 'Fonctionnel'),
    };
  }

  @override
  void render(Canvas canvas) {
    final state = game.state;
    final e = state.equipmentById(equipmentId);
    if (e == null) return;
    final t = game.time;
    final palette = switch (e.status) {
      EquipmentStatus.ok => _okPalette,
      EquipmentStatus.usure => _wearPalette,
      EquipmentStatus.panne => _brokenPalette,
    };

    canvas.save();
    if (_shake > 0) {
      canvas.translate(sin(t * 60) * 3 * (_shake / _shakeDuration), 0);
    }

    // Cadre de sélection : cible possible pour le technicien sélectionné.
    final targetable = state.selectedTechId != null &&
        !e.inIntervention &&
        e.status != EquipmentStatus.ok;
    if (targetable) {
      final pulse = (sin(t * 6) + 1) / 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(size.toRect(), const Radius.circular(14)),
        _paint..color = _accent.withValues(alpha: 0.08 + pulse * 0.06),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(size.toRect().deflate(1), const Radius.circular(14)),
        _outline
          ..color = _accent
          ..strokeWidth = 2,
      );
    }

    // Équipement dessiné.
    final artLeft = (size.x - equipmentArtSize.width) / 2;
    canvas.save();
    canvas.translate(artLeft, 4);
    paintEquipment(
      canvas,
      e,
      time: t,
      running: e.status != EquipmentStatus.panne && !e.inIntervention,
      open: e.onSite,
    );
    canvas.restore();

    // Badges : panne, diagnostic, capteur IoT.
    final diagnostic = state.needsDiagnostic(e);
    if ((e.status == EquipmentStatus.panne && !e.inIntervention) || diagnostic) {
      final pulse = 9 + (sin(t * 6) + 1) * 1.2;
      final center = Offset(artLeft + equipmentArtSize.width - 2, 8);
      canvas.drawCircle(center, pulse, _paint..color = diagnostic ? _accent : const Color(0xFFE24B4A));
      TextCache.drawIcon(
        canvas,
        diagnostic ? Icons.search : Icons.priority_high,
        13,
        Colors.white,
        center,
      );
    }
    if (e.hasSensor) {
      final center = Offset(artLeft + 2, 8);
      canvas.drawCircle(center, 8, _paint..color = _sensor);
      TextCache.drawIcon(canvas, Icons.sensors, 11, Colors.white, center);
    }

    // Étiquette avec le nom.
    final pill = RRect.fromRectAndRadius(Rect.fromLTWH(4, 70, size.x - 8, 18), const Radius.circular(9));
    canvas.drawRRect(pill, _paint..color = palette.background);
    canvas.drawRRect(
      pill,
      _outline
        ..color = palette.border.withValues(alpha: 0.5)
        ..strokeWidth = 1,
    );
    TextCache.drawCentered(
      canvas,
      e.name,
      palette.nameStyle,
      pill.center,
      maxWidth: size.x - 16,
    );

    // Barre : réparation en cours, ou santé quand elle est connue.
    final showHealth = e.hasSensor || e.status != EquipmentStatus.ok;
    if (e.onSite || showHealth) {
      final bar = Rect.fromLTWH(10, 92, size.x - 20, 5);
      canvas.drawRRect(RRect.fromRectAndRadius(bar, const Radius.circular(3)), _paint..color = _track);
      final ratio = e.onSite ? e.repairProgress.clamp(0.0, 1.0) : (e.health / 100).clamp(0.0, 1.0);
      if (ratio > 0) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(bar.left, bar.top, bar.width * ratio, bar.height),
            const Radius.circular(3),
          ),
          _paint..color = e.inIntervention ? _accent : palette.border,
        );
      }
    }

    TextCache.drawCentered(
      canvas,
      _compactStatus(e),
      palette.statusStyle,
      Offset(size.x / 2, 105),
      maxWidth: size.x,
    );

    canvas.restore();
  }

  // onTapUp : un défilement qui part d'un équipement n'est pas pris pour un toucher.
  @override
  void onTapUp(TapUpEvent event) {
    game.tapEquipment(equipmentId);
  }
}
