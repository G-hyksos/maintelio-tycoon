import 'equipment.dart';

/// Panne à diagnostiquer : symptôme, pièce à remplacer et réglage à effectuer.
class Fault {
  const Fault({
    required this.symptom,
    required this.part,
    required this.measureLabel,
    required this.unit,
    required this.target,
    required this.tolerance,
    required this.min,
    required this.max,
  });

  final String symptom;
  final String part;
  final String measureLabel;
  final String unit;
  final double target;
  final double tolerance;
  final double min;
  final double max;

  bool isWithinTolerance(double value) => (value - target).abs() <= tolerance;
}

const Map<EquipmentType, List<Fault>> faultCatalog = {
  EquipmentType.cvc: [
    Fault(symptom: 'Soufflage tiède, débit faible', part: 'Courroie de ventilateur', measureLabel: "Débit d'air", unit: 'm³/h', target: 2400, tolerance: 150, min: 1000, max: 4000),
    Fault(symptom: 'Bruit de roulement au démarrage', part: 'Roulement moteur', measureLabel: 'Intensité moteur', unit: 'A', target: 12, tolerance: 1, min: 0, max: 30),
    Fault(symptom: 'Alarme filtre encrassé', part: 'Filtre F7', measureLabel: 'Perte de charge', unit: 'Pa', target: 150, tolerance: 15, min: 0, max: 400),
  ],
  EquipmentType.ascenseur: [
    Fault(symptom: 'La porte se rouvre sans cesse', part: 'Cellule de porte', measureLabel: 'Temps de fermeture', unit: 's', target: 3, tolerance: 0.5, min: 0, max: 10),
    Fault(symptom: 'Arrêt entre deux étages', part: 'Contacteur de sécurité', measureLabel: 'Tension de commande', unit: 'V', target: 48, tolerance: 3, min: 0, max: 100),
    Fault(symptom: 'Mise à niveau imprécise', part: 'Codeur de position', measureLabel: 'Écart de niveau', unit: 'mm', target: 5, tolerance: 2, min: 0, max: 30),
  ],
  EquipmentType.froid: [
    Fault(symptom: 'Température trop haute en chambre', part: 'Détendeur', measureLabel: 'Surchauffe', unit: 'K', target: 6, tolerance: 1, min: 0, max: 20),
    Fault(symptom: "Givre sur l'évaporateur", part: 'Résistance de dégivrage', measureLabel: 'Température évaporateur', unit: '°C', target: -8, tolerance: 1.5, min: -30, max: 10),
    Fault(symptom: 'Compresseur en sécurité HP', part: 'Pressostat HP', measureLabel: 'Haute pression', unit: 'bar', target: 18, tolerance: 1, min: 0, max: 30),
  ],
  EquipmentType.gtb: [
    Fault(symptom: 'Automate hors ligne', part: 'Carte réseau', measureLabel: 'Latence', unit: 'ms', target: 20, tolerance: 10, min: 0, max: 200),
    Fault(symptom: 'Sonde aux valeurs incohérentes', part: 'Sonde de température', measureLabel: 'Température lue', unit: '°C', target: 21, tolerance: 1, min: 0, max: 40),
    Fault(symptom: 'Supervision figée', part: 'Alimentation 24 V', measureLabel: 'Tension', unit: 'V', target: 24, tolerance: 1, min: 0, max: 48),
  ],
  EquipmentType.electricite: [
    Fault(symptom: 'Le différentiel déclenche', part: 'Disjoncteur différentiel', measureLabel: 'Courant de fuite', unit: 'mA', target: 10, tolerance: 5, min: 0, max: 100),
    Fault(symptom: "Échauffement d'un départ", part: 'Bornier', measureLabel: 'Température de borne', unit: '°C', target: 40, tolerance: 5, min: 0, max: 120),
    Fault(symptom: "Perte d'une phase", part: 'Fusible', measureLabel: 'Tension phase', unit: 'V', target: 230, tolerance: 8, min: 0, max: 400),
  ],
  EquipmentType.plomberie: [
    Fault(symptom: 'Pression insuffisante aux étages', part: 'Pompe', measureLabel: 'Pression', unit: 'bar', target: 3.5, tolerance: 0.3, min: 0, max: 10),
    Fault(symptom: 'Fuite au raccord', part: 'Joint', measureLabel: 'Pression de test', unit: 'bar', target: 3, tolerance: 0.3, min: 0, max: 10),
    Fault(symptom: 'La pompe démarre et s’arrête en boucle', part: "Vase d'expansion", measureLabel: 'Pression de gonflage', unit: 'bar', target: 1.5, tolerance: 0.2, min: 0, max: 5),
  ],
};

Fault faultOf(Equipment e) {
  final faults = faultCatalog[e.type]!;
  return faults[e.faultIndex % faults.length];
}

List<String> partOptionsFor(EquipmentType type) =>
    faultCatalog[type]!.map((f) => f.part).toList();
