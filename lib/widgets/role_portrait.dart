import 'package:flutter/material.dart';

import '../models/role.dart';

/// Portrait 2D illustré de chaque rôle (buste dans un médaillon).
class RolePortrait extends StatelessWidget {
  const RolePortrait({super.key, required this.role, this.size = 56});

  final PlayerRole role;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _PortraitPainter(role)),
    );
  }
}

class _PortraitPainter extends CustomPainter {
  _PortraitPainter(this.role);

  final PlayerRole role;

  static const Color _ink = Color(0xFF2C2C2A);

  final Paint _fill = Paint()..isAntiAlias = true;
  final Paint _stroke = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  Color get _background => switch (role) {
        PlayerRole.gestionnaire => const Color(0xFFEEEDFE),
        PlayerRole.dirigeant => const Color(0xFFE6F1FB),
        PlayerRole.chefSite => const Color(0xFFCDE9DD),
        PlayerRole.adjoint => const Color(0xFFE1F5EE),
        PlayerRole.technicien => const Color(0xFFFAEEDA),
      };

  Color get _skin => switch (role) {
        PlayerRole.gestionnaire => const Color(0xFFF2C9A0),
        PlayerRole.dirigeant => const Color(0xFFE8B48E),
        PlayerRole.chefSite => const Color(0xFFD9A27A),
        PlayerRole.adjoint => const Color(0xFF8D5A3B),
        PlayerRole.technicien => const Color(0xFFF2C9A0),
      };

  Color get _jacket => switch (role) {
        PlayerRole.gestionnaire => const Color(0xFF6B4E9B),
        PlayerRole.dirigeant => const Color(0xFF26334A),
        PlayerRole.chefSite => const Color(0xFF2E4A62),
        PlayerRole.adjoint => const Color(0xFF1D9E75),
        PlayerRole.technicien => const Color(0xFF185FA5),
      };

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.shortestSide / 2;
    canvas.translate(size.width / 2, size.height / 2);
    canvas.drawCircle(Offset.zero, radius, _fill..color = _background);
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: radius)));
    // Le buste est dessiné dans un médaillon de rayon 30, puis mis à l'échelle.
    canvas.scale(radius / 30);

    // Épaules et veste.
    canvas.drawPath(
      Path()
        ..moveTo(-30, 34)
        ..lineTo(-26, 15)
        ..quadraticBezierTo(-20, 6, 0, 5)
        ..quadraticBezierTo(20, 6, 26, 15)
        ..lineTo(30, 34)
        ..close(),
      _fill..color = _jacket,
    );
    switch (role) {
      case PlayerRole.chefSite:
        _fill.color = const Color(0xFFF5C518);
        canvas.drawRect(const Rect.fromLTWH(-30, 17, 60, 3), _fill);
        canvas.drawRect(const Rect.fromLTWH(-30, 24, 60, 3), _fill);
      case PlayerRole.gestionnaire:
        canvas.drawPath(Path()..addPolygon(const [Offset(-6, 6), Offset(0, 16), Offset(6, 6)], true),
            _fill..color = Colors.white);
      case PlayerRole.dirigeant:
        canvas.drawPath(Path()..addPolygon(const [Offset(-7, 6), Offset(0, 20), Offset(7, 6)], true),
            _fill..color = Colors.white);
        canvas.drawPath(
          Path()
            ..addPolygon(const [Offset(-2, 7), Offset(2, 7), Offset(3, 18), Offset(0, 21), Offset(-3, 18)], true),
          _fill..color = const Color(0xFFC0392B),
        );
      case PlayerRole.adjoint:
        canvas.drawPath(Path()..addPolygon(const [Offset(-5, 6), Offset(0, 12), Offset(5, 6)], true),
            _fill..color = const Color(0xFF0F6E56));
      case PlayerRole.technicien:
        _fill.color = const Color(0xFF0C447C);
        canvas.drawRect(const Rect.fromLTWH(-9, 5, 4, 30), _fill);
        canvas.drawRect(const Rect.fromLTWH(5, 5, 4, 30), _fill);
    }

    // Cou et tête.
    canvas.drawRect(const Rect.fromLTWH(-4, -2, 8, 8), _fill..color = _skin);
    if (role == PlayerRole.gestionnaire) {
      canvas.drawCircle(const Offset(0, -24), 5, _fill..color = const Color(0xFF5A3A2A));
    }
    canvas.drawCircle(const Offset(0, -10), 11, _fill..color = _skin);

    // Coiffe selon le rôle.
    switch (role) {
      case PlayerRole.gestionnaire:
        canvas.drawPath(
          Path()
            ..moveTo(-11.5, -10)
            ..quadraticBezierTo(-12, -22, 0, -22)
            ..quadraticBezierTo(12, -22, 11.5, -10)
            ..quadraticBezierTo(8, -17, 0, -17)
            ..quadraticBezierTo(-8, -17, -11.5, -10)
            ..close(),
          _fill..color = const Color(0xFF5A3A2A),
        );
      case PlayerRole.dirigeant:
        canvas.drawPath(
          Path()
            ..moveTo(-11.5, -11)
            ..quadraticBezierTo(-10, -23, 0, -22)
            ..quadraticBezierTo(10, -23, 11.5, -11)
            ..quadraticBezierTo(6, -16, -2, -15)
            ..quadraticBezierTo(-8, -15, -11.5, -11)
            ..close(),
          _fill..color = const Color(0xFF3A2F2A),
        );
      case PlayerRole.chefSite:
        _helmet(canvas, const Color(0xFFFFFFFF), const Color(0xFFE4E9EB));
      case PlayerRole.technicien:
        _helmet(canvas, const Color(0xFFF5C518), const Color(0xFFC99A00));
      case PlayerRole.adjoint:
        canvas.drawPath(
          Path()
            ..moveTo(-12, -12)
            ..arcToPoint(const Offset(12, -12), radius: const Radius.elliptical(12, 11))
            ..close(),
          _fill..color = const Color(0xFF0F6E56),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(const Rect.fromLTWH(-2, -14, 18, 3), const Radius.circular(1.5)),
          _fill,
        );
    }

    // Visage.
    _fill.color = _ink;
    canvas.drawCircle(const Offset(-4, -8), 1.3, _fill);
    canvas.drawCircle(const Offset(4, -8), 1.3, _fill);
    canvas.drawPath(
      Path()
        ..moveTo(-3, -3.5)
        ..quadraticBezierTo(0, -1.5, 3, -3.5),
      _stroke
        ..color = _ink
        ..strokeWidth = 1,
    );

    // Accessoire.
    switch (role) {
      case PlayerRole.gestionnaire:
        canvas.drawRRect(
          RRect.fromRectAndRadius(const Rect.fromLTWH(10, 12, 12, 16), const Radius.circular(2)),
          _fill..color = _ink,
        );
        canvas.drawRect(const Rect.fromLTWH(11.5, 13.5, 9, 12), _fill..color = const Color(0xFF85B7EB));
      case PlayerRole.chefSite:
        canvas.drawRRect(
          RRect.fromRectAndRadius(const Rect.fromLTWH(13, 8, 5, 9), const Radius.circular(1)),
          _fill..color = _ink,
        );
        canvas.drawRect(const Rect.fromLTWH(16, 3, 1.5, 6), _fill);
      case PlayerRole.adjoint:
        canvas.drawRRect(
          RRect.fromRectAndRadius(const Rect.fromLTWH(-22, 12, 13, 17), const Radius.circular(1.5)),
          _fill..color = const Color(0xFFB08A5E),
        );
        canvas.drawRect(const Rect.fromLTWH(-20, 15, 9, 12), _fill..color = Colors.white);
      case PlayerRole.technicien:
        canvas.save();
        canvas.translate(16, 13);
        canvas.rotate(0.44);
        canvas.drawRRect(
          RRect.fromRectAndRadius(const Rect.fromLTWH(-2, -11, 4, 22), const Radius.circular(1.5)),
          _fill..color = const Color(0xFF6F7D84),
        );
        canvas.restore();
        canvas.drawCircle(
          const Offset(21, 3),
          4,
          _stroke
            ..color = const Color(0xFF6F7D84)
            ..strokeWidth = 2.5,
        );
      case PlayerRole.dirigeant:
        break;
    }
  }

  void _helmet(Canvas canvas, Color shell, Color brim) {
    canvas.drawPath(
      Path()
        ..moveTo(-12, -13)
        ..arcToPoint(const Offset(12, -13), radius: const Radius.circular(12))
        ..close(),
      _fill..color = shell,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-14, -14, 28, 3), const Radius.circular(1.5)),
      _fill..color = brim,
    );
  }

  @override
  bool shouldRepaint(_PortraitPainter oldDelegate) => oldDelegate.role != role;
}
