import 'dart:math';
import 'dart:ui';

import '../../models/equipment.dart';
import '../../models/technician.dart';

/// Postures des techniciens dessinés en 2D.
enum Pose { idle, walk, repair, think, tired, sit, celebrate }

/// Apparence d'un technicien : tenue selon la spécialité, peau et cheveux variés.
class CharacterLook {
  const CharacterLook({
    required this.body,
    required this.strap,
    required this.skin,
    required this.hair,
    required this.longHair,
  });

  final Color body;
  final Color strap;
  final Color skin;
  final Color hair;
  final bool longHair;

  static const List<Color> _skins = [
    Color(0xFFF2C9A0),
    Color(0xFFD9A27A),
    Color(0xFF8D5A3B),
    Color(0xFFE8B48E),
    Color(0xFFC68863),
  ];
  static const List<Color> _hairs = [
    Color(0xFF3A2F2A),
    Color(0xFF6B3E26),
    Color(0xFF1F1B18),
    Color(0xFFA0522D),
  ];
  static const Set<String> _longHairNames = {
    'Sophie', 'Inès', 'Clara', 'Julie', 'Nadia', 'Léa',
  };

  static (Color, Color) uniformOf(EquipmentType type) => switch (type) {
        EquipmentType.cvc => (const Color(0xFF185FA5), const Color(0xFF0C447C)),
        EquipmentType.ascenseur => (const Color(0xFFD85A30), const Color(0xFF993C1D)),
        EquipmentType.froid => (const Color(0xFF1D9E75), const Color(0xFF0F6E56)),
        EquipmentType.gtb => (const Color(0xFF534AB7), const Color(0xFF3C3489)),
        EquipmentType.electricite => (const Color(0xFFE0A21B), const Color(0xFFA8740C)),
        EquipmentType.plomberie => (const Color(0xFF2F7F96), const Color(0xFF1F5A6B)),
      };

  factory CharacterLook.of(Technician tech) {
    final seed = tech.id.codeUnits.fold<int>(0, (sum, c) => sum * 31 + c) & 0x7fffffff;
    final (body, strap) = uniformOf(tech.specialty);
    return CharacterLook(
      body: body,
      strap: strap,
      skin: _skins[seed % _skins.length],
      hair: _hairs[(seed ~/ 7) % _hairs.length],
      longHair: _longHairNames.contains(tech.name),
    );
  }
}

const Color _ink = Color(0xFF2C2C2A);
const Color _trousers = Color(0xFF33414B);
const Color _helmet = Color(0xFFF5C518);
const Color _helmetBrim = Color(0xFFC99A00);
const Color _shadow = Color(0x2E000000);
const Color _tool = Color(0xFF6F7D84);
const Color _sweat = Color(0xFF85B7EB);

final Paint _fill = Paint()..isAntiAlias = true;
final Paint _stroke = Paint()
  ..isAntiAlias = true
  ..style = PaintingStyle.stroke
  ..strokeCap = StrokeCap.round;

void _limb(Canvas canvas, Offset pivot, double angle, double length, double width, Color color) {
  canvas.save();
  canvas.translate(pivot.dx, pivot.dy);
  canvas.rotate(angle);
  canvas.drawRRect(
    RRect.fromRectAndRadius(Rect.fromLTWH(-width / 2, 0, width, length), Radius.circular(width / 2)),
    _fill..color = color,
  );
  canvas.restore();
}

/// Dessine un technicien « chibi », pieds à l'origine (hauteur ≈ 56 px).
void paintCharacter(
  Canvas canvas,
  CharacterLook look, {
  required Pose pose,
  required double time,
  bool facingLeft = false,
}) {
  canvas.save();
  if (facingLeft) canvas.scale(-1, 1);

  // Ombre au sol.
  canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 24, height: 6), _fill..color = _shadow);

  final sitting = pose == Pose.sit;
  final walk = pose == Pose.walk ? sin(time * 11) : 0.0;
  var lift = 0.0;
  switch (pose) {
    case Pose.walk:
      lift = -sin(time * 22).abs() * 1.6;
    case Pose.celebrate:
      lift = -sin(time * 9).abs() * 9;
    case Pose.idle:
    case Pose.think:
      lift = sin(time * 2.2) * 0.6;
    case Pose.tired:
      lift = 1.5;
    case Pose.sit:
      lift = 7;
    case Pose.repair:
      lift = sin(time * 12) * 0.5;
  }
  canvas.translate(0, lift);

  // Jambes.
  if (sitting) {
    _limb(canvas, const Offset(-4.5, -13), 0, 6, 5, _trousers);
    _limb(canvas, const Offset(4.5, -13), 0, 6, 5, _trousers);
  } else {
    _limb(canvas, const Offset(-4.5, -13), walk * 0.45, 13, 5, _trousers);
    _limb(canvas, const Offset(4.5, -13), -walk * 0.45, 13, 5, _trousers);
  }

  // Cheveux longs derrière la tête.
  if (look.longHair) {
    canvas.drawPath(
      Path()
        ..moveTo(-9, -48)
        ..quadraticBezierTo(-21, -38, -14, -26),
      _stroke
        ..color = look.hair
        ..strokeWidth = 5,
    );
  }

  // Bras (angle 0 = vers le bas, positif = vers la gauche de l'écran).
  var leftArm = 0.12;
  var rightArm = -0.12;
  switch (pose) {
    case Pose.walk:
      leftArm = -walk * 0.5;
      rightArm = walk * 0.5;
    case Pose.repair:
      rightArm = -1.9 + sin(time * 14) * 0.35;
    case Pose.think:
      rightArm = -2.6;
    case Pose.celebrate:
      leftArm = 2.5;
      rightArm = -2.5;
    case Pose.tired:
    case Pose.sit:
      leftArm = 0.05;
      rightArm = -0.05;
    case Pose.idle:
      break;
  }
  _limb(canvas, const Offset(-11.5, -29), leftArm, 14, 5, look.body);
  _limb(canvas, const Offset(11.5, -29), rightArm, 14, 5, look.body);

  // Outil dans la main droite pendant la réparation.
  if (pose == Pose.repair) {
    final hand = const Offset(11.5, -29) + Offset(-sin(rightArm) * 14, cos(rightArm) * 14);
    canvas.save();
    canvas.translate(hand.dx, hand.dy);
    canvas.rotate(rightArm + 0.6);
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-2, -1, 4, 11), const Radius.circular(1.5)),
      _fill..color = _tool,
    );
    canvas.restore();
  }

  // Buste et bretelles de la combinaison.
  canvas.drawRRect(
    RRect.fromRectAndRadius(const Rect.fromLTWH(-10, -31, 20, 20), const Radius.circular(6)),
    _fill..color = look.body,
  );
  canvas.drawRect(const Rect.fromLTWH(-6, -31, 3, 20), _fill..color = look.strap);
  canvas.drawRect(const Rect.fromLTWH(3, -31, 3, 20), _fill..color = look.strap);

  // Tête (légèrement penchée si fatigué).
  final headY = pose == Pose.tired || sitting ? -40.0 : -42.0;
  canvas.drawCircle(Offset(0, headY), 12, _fill..color = look.skin);

  // Casque.
  canvas.drawPath(
    Path()
      ..moveTo(-13, headY - 2)
      ..arcToPoint(Offset(13, headY - 2), radius: const Radius.circular(13))
      ..close(),
    _fill..color = _helmet,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(Rect.fromLTWH(-15, headY - 3, 30, 3), const Radius.circular(1.5)),
    _fill..color = _helmetBrim,
  );

  // Visage.
  final tiredFace = pose == Pose.tired || sitting;
  final blink = (time % 3.4) < 0.12;
  if (tiredFace || blink) {
    _stroke
      ..color = _ink
      ..strokeWidth = 1.4;
    canvas.drawLine(Offset(-6, headY + 3), Offset(-2, headY + 3), _stroke);
    canvas.drawLine(Offset(2, headY + 3), Offset(6, headY + 3), _stroke);
  } else {
    _fill.color = _ink;
    canvas.drawCircle(Offset(-4, headY + 3), 1.6, _fill);
    canvas.drawCircle(Offset(4, headY + 3), 1.6, _fill);
  }
  _stroke
    ..color = _ink
    ..strokeWidth = 1.2;
  if (tiredFace) {
    canvas.drawLine(Offset(-2.5, headY + 8.5), Offset(2.5, headY + 8.5), _stroke);
  } else {
    final open = pose == Pose.celebrate ? 2.5 : 1.5;
    canvas.drawPath(
      Path()
        ..moveTo(-3, headY + 8)
        ..quadraticBezierTo(0, headY + 8 + open, 3, headY + 8),
      _stroke,
    );
  }

  // Goutte de sueur.
  if (tiredFace) {
    canvas.drawPath(
      Path()
        ..moveTo(14, headY - 2)
        ..quadraticBezierTo(17, headY + 3, 14, headY + 6)
        ..quadraticBezierTo(11, headY + 3, 14, headY - 2),
      _fill..color = _sweat,
    );
  }

  canvas.restore();
}
