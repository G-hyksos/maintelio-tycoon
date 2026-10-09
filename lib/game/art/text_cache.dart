import 'package:flutter/painting.dart';
import 'package:flutter/widgets.dart' show IconData;

/// Mise en cache des textes dessinés à chaque image sur la carte Flame.
class TextCache {
  TextCache._();

  static const int _maxEntries = 400;
  static final Map<(String, TextStyle, double), TextPainter> _cache = {};

  static TextPainter get(String text, TextStyle style, {double maxWidth = double.infinity}) {
    final key = (text, style, maxWidth);
    final cached = _cache[key];
    if (cached != null) return cached;
    if (_cache.length > _maxEntries) {
      for (final painter in _cache.values) {
        painter.dispose();
      }
      _cache.clear();
    }
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);
    _cache[key] = painter;
    return painter;
  }

  static void drawCentered(
    Canvas canvas,
    String text,
    TextStyle style,
    Offset center, {
    double maxWidth = double.infinity,
  }) {
    final painter = get(text, style, maxWidth: maxWidth);
    painter.paint(canvas, center - Offset(painter.width / 2, painter.height / 2));
  }

  /// Glyphe d'une icône Material dessiné au centre donné.
  static void drawIcon(Canvas canvas, IconData icon, double size, Color color, Offset center) {
    drawCentered(
      canvas,
      String.fromCharCode(icon.codePoint),
      TextStyle(
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
        fontSize: size,
        color: color,
        height: 1,
      ),
      center,
    );
  }
}
