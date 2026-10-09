import 'package:flutter/material.dart';

enum GameEventType { canicule, coupure, audit, greve }

extension GameEventInfo on GameEventType {
  String get label => switch (this) {
        GameEventType.canicule => 'Canicule',
        GameEventType.coupure => 'Coupure électrique',
        GameEventType.audit => 'Audit client',
        GameEventType.greve => 'Grève des transports',
      };

  String get description => switch (this) {
        GameEventType.canicule => 'CVC et froid s’usent deux fois plus vite aujourd’hui.',
        GameEventType.coupure => 'TGBT et GTB sont tombés en panne.',
        GameEventType.audit =>
          'Health score de 70 ou plus en fin de journée : prime. Sinon, satisfaction en baisse.',
        GameEventType.greve => 'Déplacements trois fois plus longs aujourd’hui.',
      };

  IconData get icon => switch (this) {
        GameEventType.canicule => Icons.wb_sunny,
        GameEventType.coupure => Icons.power_off,
        GameEventType.audit => Icons.fact_check,
        GameEventType.greve => Icons.directions_bus_filled,
      };
}

class ActiveEvent {
  const ActiveEvent({required this.type, required this.endsAt, this.siteId});

  final GameEventType type;
  final double endsAt;
  final String? siteId;

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'endsAt': endsAt,
        'siteId': siteId,
      };

  factory ActiveEvent.fromJson(Map<String, dynamic> json) => ActiveEvent(
        type: GameEventType.values.byName(json['type'] as String),
        endsAt: (json['endsAt'] as num).toDouble(),
        siteId: json['siteId'] as String?,
      );
}
