import 'package:flutter/material.dart';

enum EquipmentType { cvc, ascenseur, froid, gtb, electricite, plomberie }

extension EquipmentTypeInfo on EquipmentType {
  String get specialtyLabel => switch (this) {
        EquipmentType.cvc => 'Thermique',
        EquipmentType.ascenseur => 'Ascenseurs',
        EquipmentType.froid => 'Froid',
        EquipmentType.gtb => 'Automatisme',
        EquipmentType.electricite => 'Électricité',
        EquipmentType.plomberie => 'Plomberie',
      };

  IconData get icon => switch (this) {
        EquipmentType.cvc => Icons.air,
        EquipmentType.ascenseur => Icons.elevator,
        EquipmentType.froid => Icons.ac_unit,
        EquipmentType.gtb => Icons.memory,
        EquipmentType.electricite => Icons.electrical_services,
        EquipmentType.plomberie => Icons.plumbing,
      };

  /// Les interventions sur ces équipements exigent l'habilitation électrique.
  bool get requiresElectricalClearance =>
      this == EquipmentType.electricite || this == EquipmentType.gtb;
}

enum EquipmentStatus { ok, usure, panne }

class Equipment {
  Equipment({
    required this.id,
    required this.siteId,
    required this.name,
    required this.type,
    required this.decayRate,
    this.health = 100,
    this.assignedTechId,
    this.travelRemaining = 0,
    this.travelTotal = 0,
    this.repairProgress = 0,
    this.brokenAt,
    this.penalized = false,
    this.hasSensor = false,
    this.sensorAlerted = false,
    this.faultIndex = 0,
    this.diagnosed = false,
    this.diagnosticErrors = 0,
    this.scheduledDay,
    this.preventive = false,
  });

  static const double wearThreshold = 40;

  final String id;
  final String siteId;
  final String name;
  final EquipmentType type;
  double health;
  double decayRate;
  String? assignedTechId;
  double travelRemaining;

  /// Durée totale du trajet en cours (sert à synchroniser l'animation de marche).
  double travelTotal;
  double repairProgress;
  double? brokenAt;
  bool penalized;

  /// Capteur IoT installé (GTB) : santé visible en permanence et alerte précoce.
  bool hasSensor;
  bool sensorAlerted;

  /// Panne à diagnostiquer (mini-jeu technicien).
  int faultIndex;
  bool diagnosed;
  int diagnosticErrors;

  /// Visite préventive planifiée pour ce jour.
  int? scheduledDay;

  /// L'intervention en cours est une visite préventive.
  bool preventive;

  EquipmentStatus get status {
    if (health <= 0) return EquipmentStatus.panne;
    if (health < wearThreshold) return EquipmentStatus.usure;
    return EquipmentStatus.ok;
  }

  bool get inIntervention => assignedTechId != null;
  bool get onSite => inIntervention && travelRemaining <= 0;

  Map<String, dynamic> toJson() => {
        'id': id,
        'siteId': siteId,
        'name': name,
        'type': type.name,
        'health': health,
        'decayRate': decayRate,
        'assignedTechId': assignedTechId,
        'travelRemaining': travelRemaining,
        'travelTotal': travelTotal,
        'repairProgress': repairProgress,
        'brokenAt': brokenAt,
        'penalized': penalized,
        'hasSensor': hasSensor,
        'sensorAlerted': sensorAlerted,
        'faultIndex': faultIndex,
        'diagnosed': diagnosed,
        'diagnosticErrors': diagnosticErrors,
        'scheduledDay': scheduledDay,
        'preventive': preventive,
      };

  factory Equipment.fromJson(Map<String, dynamic> json, {required String fallbackSiteId}) =>
      Equipment(
        id: json['id'] as String,
        siteId: json['siteId'] as String? ?? fallbackSiteId,
        name: json['name'] as String,
        type: EquipmentType.values.byName(json['type'] as String),
        health: (json['health'] as num).toDouble(),
        decayRate: (json['decayRate'] as num).toDouble(),
        assignedTechId: json['assignedTechId'] as String?,
        travelRemaining: (json['travelRemaining'] as num?)?.toDouble() ?? 0,
        travelTotal: (json['travelTotal'] as num?)?.toDouble() ?? 0,
        repairProgress: (json['repairProgress'] as num?)?.toDouble() ?? 0,
        brokenAt: (json['brokenAt'] as num?)?.toDouble(),
        penalized: json['penalized'] as bool? ?? false,
        hasSensor: json['hasSensor'] as bool? ?? false,
        sensorAlerted: json['sensorAlerted'] as bool? ?? false,
        faultIndex: json['faultIndex'] as int? ?? 0,
        diagnosed: json['diagnosed'] as bool? ?? false,
        diagnosticErrors: json['diagnosticErrors'] as int? ?? 0,
        scheduledDay: json['scheduledDay'] as int?,
        preventive: json['preventive'] as bool? ?? false,
      );
}
