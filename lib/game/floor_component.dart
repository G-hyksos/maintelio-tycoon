import 'dart:ui' show Picture, PictureRecorder;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../models/site.dart';
import 'art/text_cache.dart';
import 'site_game.dart';

/// Sol du site, allée centrale et atelier (mis en cache dans une image).
class FloorComponent extends Component with HasGameReference<SiteGame> {
  FloorComponent() : super(priority: -10);

  static const TextStyle _atelierStyle = TextStyle(
    color: Color(0xFF5F6B70),
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.6,
  );

  final Paint _paint = Paint()..isAntiAlias = true;
  final Paint _line = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke;

  static Color floorOf(SiteType type) => switch (type) {
        SiteType.metro => const Color(0xFFE6ECEF),
        SiteType.hopital => const Color(0xFFEEF4F7),
        SiteType.centreCommercial => const Color(0xFFF2EEE8),
        SiteType.bureaux => const Color(0xFFECF0EA),
      };

  Picture? _picture;
  String _pictureKey = '';

  @override
  void onRemove() {
    _picture?.dispose();
    _picture = null;
    super.onRemove();
  }

  @override
  void render(Canvas canvas) {
    final layout = game.layout;
    if (layout == null) return;
    final w = game.size.x;
    final h = game.size.y;
    final type = game.state.currentSite.type;
    final key = '$w|$h|${type.name}|${layout.atelierTop}';
    var picture = _picture;
    if (picture == null || key != _pictureKey) {
      picture?.dispose();
      final recorder = PictureRecorder();
      _draw(Canvas(recorder), w, h, type, layout.aisleX, layout.atelierTop);
      picture = recorder.endRecording();
      _picture = picture;
      _pictureKey = key;
    }
    canvas.drawPicture(picture);
  }

  void _draw(Canvas canvas, double w, double h, SiteType type, double aisleX, double atelierTop) {
    // Sol et carrelage.
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), _paint..color = floorOf(type));
    _line
      ..color = const Color(0x14000000)
      ..strokeWidth = 1;
    for (var x = 0.0; x < w; x += 32) {
      canvas.drawLine(Offset(x, 0), Offset(x, atelierTop), _line);
    }
    for (var y = 0.0; y < atelierTop; y += 32) {
      canvas.drawLine(Offset(0, y), Offset(w, y), _line);
    }

    // Allée centrale.
    canvas.drawRect(
      Rect.fromLTWH(aisleX - 30, 0, 60, atelierTop),
      _paint..color = const Color(0x0F000000),
    );
    _line
      ..color = const Color(0xFFF2C230)
      ..strokeWidth = 2;
    for (var y = 8.0; y < atelierTop - 8; y += 18) {
      canvas.drawLine(Offset(aisleX, y), Offset(aisleX, y + 9), _line);
    }

    // Atelier : sol hachuré, bande de sécurité, établi.
    final top = atelierTop;
    canvas.drawRect(Rect.fromLTWH(0, top, w, h - top), _paint..color = const Color(0xFFDCE5E9));
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, top, w, h - top));
    _line
      ..color = const Color(0x12000000)
      ..strokeWidth = 6;
    for (var x = -h; x < w + h; x += 22) {
      canvas.drawLine(Offset(x, h), Offset(x + (h - top), top), _line);
    }
    canvas.restore();
    for (var x = 0.0; x < w; x += 16) {
      canvas.drawRect(
        Rect.fromLTWH(x, top, 8, 5),
        _paint..color = const Color(0xFF2C2C2A),
      );
      canvas.drawRect(
        Rect.fromLTWH(x + 8, top, 8, 5),
        _paint..color = const Color(0xFFF2C230),
      );
    }
    final bench = Rect.fromLTWH(12, top + 22, 54, 12);
    canvas.drawRRect(RRect.fromRectAndRadius(bench, const Radius.circular(2)), _paint..color = const Color(0xFF8B6F55));
    canvas.drawRect(Rect.fromLTWH(16, top + 34, 4, 22), _paint..color = const Color(0xFF6E5642));
    canvas.drawRect(Rect.fromLTWH(58, top + 34, 4, 22), _paint..color = const Color(0xFF6E5642));
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(20, top + 12, 18, 10), const Radius.circular(2)),
      _paint..color = const Color(0xFFD85A30),
    );
    canvas.drawRect(Rect.fromLTWH(w - 44, top + 14, 30, 42), _paint..color = const Color(0xFF9FB0B8));
    canvas.drawRect(Rect.fromLTWH(w - 40, top + 20, 22, 6), _paint..color = const Color(0xFF7D8E97));
    canvas.drawRect(Rect.fromLTWH(w - 40, top + 32, 22, 6), _paint..color = const Color(0xFF7D8E97));
    canvas.drawRect(Rect.fromLTWH(w - 40, top + 44, 22, 6), _paint..color = const Color(0xFF7D8E97));
    TextCache.drawCentered(canvas, 'ATELIER', _atelierStyle, Offset(w / 2, top + 94));
  }
}
