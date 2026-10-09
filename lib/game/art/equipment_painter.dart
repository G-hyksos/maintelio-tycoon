import 'dart:math';
import 'dart:ui';

import '../../models/equipment.dart';

/// Taille de la zone de dessin d'un équipement.
const Size equipmentArtSize = Size(84, 62);

final Paint _fill = Paint()..isAntiAlias = true;
final Paint _stroke = Paint()
  ..isAntiAlias = true
  ..style = PaintingStyle.stroke
  ..strokeCap = StrokeCap.round;

RRect _rr(double x, double y, double w, double h, double r) =>
    RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r));

Color _ledColor(EquipmentStatus status, double time) => switch (status) {
      EquipmentStatus.ok => const Color(0xFF3CCB8B),
      EquipmentStatus.usure => const Color(0xFFF2A93B),
      EquipmentStatus.panne =>
        (time * 3).floor().isEven ? const Color(0xFFE24B4A) : const Color(0xFF7A2A2A),
    };

/// Dessine l'équipement dans un cadre de 84 × 62 à l'origine.
/// [running] : l'équipement fonctionne (ventilateurs et marches animés).
/// [open] : un technicien intervient (portes et capots ouverts).
void paintEquipment(
  Canvas canvas,
  Equipment e, {
  required double time,
  required bool running,
  required bool open,
}) {
  final led = _ledColor(e.status, time);
  switch (e.type) {
    case EquipmentType.ascenseur:
      if (e.name.startsWith('Escalator')) {
        _escalator(canvas, time, running, led);
      } else {
        _elevator(canvas, open, led);
      }
    case EquipmentType.cvc:
      _airUnit(canvas, time, running, open, led, frost: false);
    case EquipmentType.froid:
      _airUnit(canvas, time, running, open, led, frost: true);
    case EquipmentType.gtb:
      _gtb(canvas, time, running, led);
    case EquipmentType.electricite:
      _cabinet(canvas, open, led);
    case EquipmentType.plomberie:
      _pump(canvas, time, running, led);
  }
}

void _escalator(Canvas canvas, double time, bool running, Color led) {
  final band = Path()
    ..moveTo(4, 60)
    ..lineTo(30, 60)
    ..lineTo(82, 6)
    ..lineTo(56, 6)
    ..close();
  canvas.drawPath(band, _fill..color = const Color(0xFF8FA3AD));
  canvas.save();
  canvas.clipPath(band);
  _stroke
    ..color = const Color(0xFF6F848E)
    ..strokeWidth = 2;
  final shift = running ? (time * 0.8) % 1.0 : 0.0;
  for (var i = 0; i < 7; i++) {
    final f = (i + shift) / 7;
    final y = 60 - f * 54;
    final x = 4 + f * 52;
    canvas.drawLine(Offset(x, y), Offset(x + 30, y), _stroke);
  }
  canvas.restore();
  _stroke
    ..color = const Color(0xFF53656E)
    ..strokeWidth = 3;
  canvas.drawLine(const Offset(30, 60), const Offset(82, 6), _stroke);
  canvas.drawCircle(const Offset(10, 50), 3, _fill..color = led);
}

void _elevator(Canvas canvas, bool open, Color led) {
  canvas.drawRRect(_rr(12, 0, 60, 62, 4), _fill..color = const Color(0xFF97A9B1));
  canvas.drawRect(const Rect.fromLTWH(18, 9, 48, 53), _fill..color = const Color(0xFF41515A));
  final door = _fill..color = const Color(0xFFD3DCE0);
  if (open) {
    canvas.drawRect(const Rect.fromLTWH(18, 9, 11, 53), door);
    canvas.drawRect(const Rect.fromLTWH(55, 9, 11, 53), door);
  } else {
    canvas.drawRect(const Rect.fromLTWH(18, 9, 23.5, 53), door);
    canvas.drawRect(const Rect.fromLTWH(42.5, 9, 23.5, 53), door);
  }
  canvas.drawRRect(_rr(34, 2, 16, 5, 2), _fill..color = led);
}

void _airUnit(Canvas canvas, double time, bool running, bool open, Color led, {required bool frost}) {
  final body = frost ? const Color(0xFFCFE3EA) : const Color(0xFFC5D2D8);
  final fan = frost ? const Color(0xFFA9C9D6) : const Color(0xFFA3B3BA);
  canvas.drawRRect(_rr(0, 8, 84, 54, 6), _fill..color = body);
  if (frost) canvas.drawRRect(_rr(0, 8, 84, 7, 6), _fill..color = const Color(0xFFE8F4F8));
  const center = Offset(24, 37);
  canvas.drawCircle(center, 17, _fill..color = fan);
  canvas.save();
  canvas.translate(center.dx, center.dy);
  canvas.rotate(running ? time * 7 : 0.4);
  _fill.color = const Color(0xFF7E9099);
  for (var i = 0; i < 4; i++) {
    canvas.drawOval(const Rect.fromLTWH(-4, -15, 8, 13), _fill);
    canvas.rotate(pi / 2);
  }
  canvas.restore();
  canvas.drawCircle(center, 3.5, _fill..color = const Color(0xFF53656E));
  if (open) {
    canvas.drawRect(const Rect.fromLTWH(48, 16, 30, 40), _fill..color = const Color(0xFF46545C));
    _stroke
      ..color = const Color(0xFF2C2C2A)
      ..strokeWidth = 2.5;
    canvas.drawOval(const Rect.fromLTWH(54, 24, 18, 24), _stroke);
  } else if (frost) {
    _stroke
      ..color = const Color(0xFF5BA7C9)
      ..strokeWidth = 2;
    const c = Offset(63, 37);
    for (var i = 0; i < 3; i++) {
      final a = i * pi / 3;
      canvas.drawLine(c + Offset(cos(a) * 11, sin(a) * 11), c - Offset(cos(a) * 11, sin(a) * 11), _stroke);
    }
  } else {
    _stroke
      ..color = const Color(0xFFA9B8BF)
      ..strokeWidth = 2;
    for (var y = 20.0; y <= 54; y += 8) {
      canvas.drawLine(Offset(50, y), Offset(78, y), _stroke);
    }
  }
  canvas.drawCircle(const Offset(76, 14), 3, _fill..color = led);
}

void _gtb(Canvas canvas, double time, bool running, Color led) {
  canvas.drawRRect(_rr(14, 0, 56, 62, 4), _fill..color = const Color(0xFF5E6E77));
  canvas.drawRRect(_rr(20, 7, 44, 26, 2), _fill..color = const Color(0xFF1D2B33));
  final graph = Path();
  for (var i = 0; i <= 8; i++) {
    final x = 23 + i * 4.75;
    final wave = running ? sin(time * 3 + i * 0.9) : (i.isEven ? 0.6 : -0.6);
    final y = 20 + wave * 6;
    if (i == 0) {
      graph.moveTo(x, y);
    } else {
      graph.lineTo(x, y);
    }
  }
  canvas.drawPath(
    graph,
    _stroke
      ..color = running ? const Color(0xFF3CCB8B) : const Color(0xFFE24B4A)
      ..strokeWidth = 1.6,
  );
  for (var i = 0; i < 4; i++) {
    canvas.drawCircle(Offset(26 + i * 10.5, 44), 2.6, _fill..color = i == 0 ? led : const Color(0xFF3B4A52));
  }
  canvas.drawRect(const Rect.fromLTWH(22, 52, 40, 3), _fill..color = const Color(0xFF4A5961));
}

void _cabinet(Canvas canvas, bool open, Color led) {
  canvas.drawRRect(_rr(18, 0, 48, 62, 4), _fill..color = const Color(0xFF7D8E97));
  if (open) {
    canvas.drawRect(const Rect.fromLTWH(22, 6, 40, 52), _fill..color = const Color(0xFF3B4A52));
    _stroke
      ..color = const Color(0xFFE0A21B)
      ..strokeWidth = 2;
    for (var y = 14.0; y <= 50; y += 9) {
      canvas.drawLine(Offset(28, y), Offset(56, y), _stroke);
    }
  } else {
    _stroke
      ..color = const Color(0xFF66767F)
      ..strokeWidth = 1.5;
    canvas.drawLine(const Offset(42, 4), const Offset(42, 58), _stroke);
    final bolt = Path()
      ..moveTo(50, 18)
      ..lineTo(43, 33)
      ..lineTo(49, 33)
      ..lineTo(44, 46)
      ..lineTo(57, 28)
      ..lineTo(51, 28)
      ..lineTo(56, 18)
      ..close();
    canvas.drawPath(bolt, _fill..color = const Color(0xFFF5C518));
  }
  canvas.drawCircle(const Offset(26, 8), 2.6, _fill..color = led);
  canvas.drawCircle(const Offset(34, 8), 2.6, _fill..color = led);
}

void _pump(Canvas canvas, double time, bool running, Color led) {
  canvas.drawRect(const Rect.fromLTWH(0, 42, 84, 9), _fill..color = const Color(0xFF7FA7B5));
  canvas.drawRRect(_rr(26, 4, 32, 48, 9), _fill..color = const Color(0xFF5F8E9F));
  canvas.drawCircle(const Offset(66, 46), 10, _fill..color = const Color(0xFF4F7180));
  const gauge = Offset(42, 20);
  canvas.drawCircle(gauge, 8, _fill..color = const Color(0xFFFFFFFF));
  final angle = running ? -0.6 + sin(time * 2) * 0.15 : 1.2;
  _stroke
    ..color = const Color(0xFFE24B4A)
    ..strokeWidth = 1.6;
  canvas.drawLine(gauge, gauge + Offset(sin(angle) * 6, -cos(angle) * 6), _stroke);
  canvas.drawCircle(const Offset(42, 38), 3, _fill..color = led);
}
