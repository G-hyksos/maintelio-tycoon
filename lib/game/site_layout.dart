import 'dart:math';
import 'dart:ui';

/// Plan du site : deux rangées d'équipements de part et d'autre d'une allée
/// centrale, et l'atelier en bas où attendent les techniciens.
class SiteLayout {
  SiteLayout({required this.width, required this.height, required this.count});

  static const double top = 14;
  static const double rowHeight = 118;
  static const double slotWidth = 96;
  static const double slotHeight = 112;
  static const double atelierHeight = 104;
  static const double spotOffset = 58;

  final double width;
  final double height;
  final int count;

  static int rowsFor(int count) => (count / 2).ceil();

  static double requiredHeight(int count) =>
      top + rowsFor(count) * rowHeight + atelierHeight;

  int get rows => rowsFor(count);

  double get aisleX => width / 2;

  double get atelierTop => max(top + rows * rowHeight, height - atelierHeight);

  double _columnCenter(int index) => index.isEven ? width * 0.27 : width * 0.73;

  Rect slotRect(int index) {
    final cx = _columnCenter(index);
    final y = top + (index ~/ 2) * rowHeight;
    return Rect.fromLTWH(cx - slotWidth / 2, y, slotWidth, slotHeight);
  }

  /// Centre du dessin de l'équipement.
  Offset artCenter(int index) {
    final slot = slotRect(index);
    return Offset(slot.center.dx, slot.top + 35);
  }

  /// Point où se tient le technicien pendant l'intervention (dans l'allée).
  Offset workSpot(int index) {
    final slot = slotRect(index);
    final dx = index.isEven ? spotOffset : -spotOffset;
    return Offset(slot.center.dx + dx, slot.top + 66);
  }

  /// Place du technicien dans l'atelier.
  Offset home(int index, int total) {
    final n = max(total, 1);
    final spacing = min(46.0, (width - 60) / n);
    final x = aisleX + (index - (n - 1) / 2) * spacing;
    return Offset(x, atelierTop + 72);
  }

  /// Trajet par l'allée centrale.
  List<Offset> route(Offset from, Offset to) {
    // Même rangée : déplacement direct, sans repasser par l'allée.
    if ((from.dy - to.dy).abs() < 0.5) return [from, to];
    final points = <Offset>[
      from,
      Offset(aisleX, from.dy),
      Offset(aisleX, to.dy),
      to,
    ];
    final cleaned = <Offset>[points.first];
    for (final p in points.skip(1)) {
      if ((p - cleaned.last).distance > 0.5) cleaned.add(p);
    }
    return cleaned;
  }

  static double length(List<Offset> path) {
    var total = 0.0;
    for (var i = 1; i < path.length; i++) {
      total += (path[i] - path[i - 1]).distance;
    }
    return total;
  }

  /// Point situé à [distance] du début du trajet.
  static Offset pointAtDistance(List<Offset> path, double distance) {
    if (path.length == 1 || distance <= 0) return path.first;
    var remaining = distance;
    for (var i = 1; i < path.length; i++) {
      final segment = path[i] - path[i - 1];
      final len = segment.distance;
      if (remaining <= len) {
        return path[i - 1] + segment * (len == 0 ? 0.0 : remaining / len);
      }
      remaining -= len;
    }
    return path.last;
  }

  static Offset pointAtFraction(List<Offset> path, double fraction) =>
      pointAtDistance(path, length(path) * fraction.clamp(0.0, 1.0));
}
