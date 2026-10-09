import 'equipment.dart';

class Technician {
  Technician({
    required this.id,
    required this.name,
    required this.specialty,
    required this.salary,
    this.jobs = 0,
    this.trainingLevels = 0,
    this.habilitationElec = false,
    this.fatigue = 0,
    this.trainingUntil = 0,
    this.assignedEquipmentId,
    this.isPlayer = false,
  });

  static const int maxLevel = 5;
  static const int jobsPerLevel = 5;

  final String id;
  final String name;
  final EquipmentType specialty;
  final double salary;
  int jobs;

  /// Niveaux gagnés en formation.
  int trainingLevels;

  /// Habilitation électrique (obligatoire sur TGBT et GTB hors électriciens).
  bool habilitationElec;

  /// 0 à 100 : au-delà de 80 le technicien ralentit, à 95 il est indisponible.
  double fatigue;

  /// Horloge de jeu jusqu'à laquelle le technicien est en formation.
  double trainingUntil;

  String? assignedEquipmentId;
  final bool isPlayer;

  int get level {
    final computed = 1 + jobs ~/ jobsPerLevel + trainingLevels;
    return computed > maxLevel ? maxLevel : computed;
  }

  bool get isFree => assignedEquipmentId == null;

  bool get electricallyCleared =>
      habilitationElec || specialty == EquipmentType.electricite;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    final single = parts.first;
    return single.substring(0, single.length >= 2 ? 2 : 1).toUpperCase();
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'specialty': specialty.name,
        'salary': salary,
        'jobs': jobs,
        'trainingLevels': trainingLevels,
        'habilitationElec': habilitationElec,
        'fatigue': fatigue,
        'trainingUntil': trainingUntil,
        'assignedEquipmentId': assignedEquipmentId,
        'isPlayer': isPlayer,
      };

  factory Technician.fromJson(Map<String, dynamic> json) => Technician(
        id: json['id'] as String,
        name: json['name'] as String,
        specialty: EquipmentType.values.byName(json['specialty'] as String),
        salary: (json['salary'] as num).toDouble(),
        jobs: json['jobs'] as int? ?? 0,
        trainingLevels: json['trainingLevels'] as int? ?? 0,
        habilitationElec: json['habilitationElec'] as bool? ?? false,
        fatigue: (json['fatigue'] as num?)?.toDouble() ?? 0,
        trainingUntil: (json['trainingUntil'] as num?)?.toDouble() ?? 0,
        assignedEquipmentId: json['assignedEquipmentId'] as String?,
        isPlayer: json['isPlayer'] as bool? ?? false,
      );
}
