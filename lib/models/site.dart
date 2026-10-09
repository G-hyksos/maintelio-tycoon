import 'package:flutter/material.dart';

import 'equipment.dart';

enum SiteType { metro, hopital, centreCommercial, bureaux }

typedef CatalogEntry = ({String name, EquipmentType type});

extension SiteTypeInfo on SiteType {
  String get label => switch (this) {
        SiteType.metro => 'Métro',
        SiteType.hopital => 'Hôpital',
        SiteType.centreCommercial => 'Centre commercial',
        SiteType.bureaux => 'Bureaux',
      };

  String get defaultName => switch (this) {
        SiteType.metro => 'Station Nord',
        SiteType.hopital => 'Clinique des Lilas',
        SiteType.centreCommercial => 'Centre Les Arcades',
        SiteType.bureaux => 'Tour Horizon',
      };

  String get constraint => switch (this) {
        SiteType.metro =>
          'Ascenseurs et escalators très sollicités, pénalités ×1,5',
        SiteType.hopital =>
          'Disponibilité critique : pénalités et insatisfaction ×2',
        SiteType.centreCommercial => 'Froid et CVC très sollicités',
        SiteType.bureaux => 'Site standard',
      };

  IconData get icon => switch (this) {
        SiteType.metro => Icons.subway,
        SiteType.hopital => Icons.local_hospital,
        SiteType.centreCommercial => Icons.storefront,
        SiteType.bureaux => Icons.business,
      };

  double decayMultiplier(EquipmentType type) => switch (this) {
        SiteType.metro => type == EquipmentType.ascenseur ? 1.4 : 1.0,
        SiteType.hopital =>
          type == EquipmentType.cvc || type == EquipmentType.electricite ? 1.2 : 1.0,
        SiteType.centreCommercial => type == EquipmentType.froid
            ? 1.4
            : (type == EquipmentType.cvc ? 1.2 : 1.0),
        SiteType.bureaux => 1.0,
      };

  double get penaltyMultiplier => switch (this) {
        SiteType.metro => 1.5,
        SiteType.hopital => 2.0,
        _ => 1.0,
      };

  /// Multiplie la perte de satisfaction quand un équipement est dégradé.
  double get satisfactionWeight => this == SiteType.hopital ? 2.0 : 1.0;

  List<CatalogEntry> get catalog => switch (this) {
        SiteType.metro => const [
            (name: 'Escalator 1', type: EquipmentType.ascenseur),
            (name: 'Ascenseur quai', type: EquipmentType.ascenseur),
            (name: 'Ventilation', type: EquipmentType.cvc),
            (name: 'TGBT', type: EquipmentType.electricite),
            (name: 'Escalator 2', type: EquipmentType.ascenseur),
            (name: "Pompe d'exhaure", type: EquipmentType.plomberie),
            (name: 'GTB', type: EquipmentType.gtb),
            (name: 'Désenfumage', type: EquipmentType.cvc),
            (name: 'Ascenseur 2', type: EquipmentType.ascenseur),
            (name: 'Éclairage quai', type: EquipmentType.electricite),
          ],
        SiteType.hopital => const [
            (name: 'CTA bloc op.', type: EquipmentType.cvc),
            (name: 'Groupe froid', type: EquipmentType.froid),
            (name: 'TGBT', type: EquipmentType.electricite),
            (name: 'Ascenseur lits', type: EquipmentType.ascenseur),
            (name: 'Groupe élec.', type: EquipmentType.electricite),
            (name: 'GTB', type: EquipmentType.gtb),
            (name: 'Eau chaude', type: EquipmentType.plomberie),
            (name: 'CVC pavillon A', type: EquipmentType.cvc),
            (name: 'Ascenseur public', type: EquipmentType.ascenseur),
            (name: 'Chambre froide', type: EquipmentType.froid),
          ],
        SiteType.centreCommercial => const [
            (name: 'Groupe froid', type: EquipmentType.froid),
            (name: 'CVC galerie', type: EquipmentType.cvc),
            (name: 'Escalator', type: EquipmentType.ascenseur),
            (name: 'TGBT', type: EquipmentType.electricite),
            (name: 'Chambre froide', type: EquipmentType.froid),
            (name: 'Ascenseur', type: EquipmentType.ascenseur),
            (name: 'GTB', type: EquipmentType.gtb),
            (name: 'Surpresseur', type: EquipmentType.plomberie),
            (name: 'Désenfumage', type: EquipmentType.cvc),
            (name: 'Escalator 2', type: EquipmentType.ascenseur),
          ],
        SiteType.bureaux => const [
            (name: 'CVC niveau 1', type: EquipmentType.cvc),
            (name: 'Ascenseur 1', type: EquipmentType.ascenseur),
            (name: 'Groupe froid', type: EquipmentType.froid),
            (name: 'GTB', type: EquipmentType.gtb),
            (name: 'TGBT', type: EquipmentType.electricite),
            (name: 'Surpresseur', type: EquipmentType.plomberie),
            (name: 'CVC niveau 2', type: EquipmentType.cvc),
            (name: 'Ascenseur 2', type: EquipmentType.ascenseur),
            (name: 'CTA toiture', type: EquipmentType.cvc),
            (name: 'Escalator', type: EquipmentType.ascenseur),
          ],
      };
}

class Site {
  Site({
    required this.id,
    required this.name,
    required this.type,
    this.tierIndex = 0,
    this.satisfaction = 80,
    this.upSeconds = 0,
    this.totalSeconds = 0,
    this.lastNoteDay = 0,
    this.breakdownsToday = 0,
  });

  static const double openingCost = 15000;

  final String id;
  final String name;
  final SiteType type;
  int tierIndex;
  double satisfaction;
  double upSeconds;
  double totalSeconds;
  int lastNoteDay;
  int breakdownsToday;

  double get availability =>
      totalSeconds == 0 ? 100 : upSeconds / totalSeconds * 100;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'tierIndex': tierIndex,
        'satisfaction': satisfaction,
        'upSeconds': upSeconds,
        'totalSeconds': totalSeconds,
        'lastNoteDay': lastNoteDay,
        'breakdownsToday': breakdownsToday,
      };

  factory Site.fromJson(Map<String, dynamic> json) => Site(
        id: json['id'] as String,
        name: json['name'] as String,
        type: SiteType.values.byName(json['type'] as String),
        tierIndex: json['tierIndex'] as int? ?? 0,
        satisfaction: (json['satisfaction'] as num?)?.toDouble() ?? 80,
        upSeconds: (json['upSeconds'] as num?)?.toDouble() ?? 0,
        totalSeconds: (json['totalSeconds'] as num?)?.toDouble() ?? 0,
        lastNoteDay: json['lastNoteDay'] as int? ?? 0,
        breakdownsToday: json['breakdownsToday'] as int? ?? 0,
      );
}
