class ContractTier {
  const ContractTier({
    required this.name,
    required this.equipmentCount,
    required this.dailyRevenue,
    required this.upgradeCost,
  });

  final String name;
  final int equipmentCount;
  final double dailyRevenue;

  /// Coût pour signer ce niveau de contrat depuis le niveau précédent.
  final double upgradeCost;
}

const List<ContractTier> contractTiers = [
  ContractTier(name: 'Free', equipmentCount: 4, dailyRevenue: 1200, upgradeCost: 0),
  ContractTier(name: 'Pro', equipmentCount: 6, dailyRevenue: 2000, upgradeCost: 5000),
  ContractTier(name: 'Business', equipmentCount: 8, dailyRevenue: 3200, upgradeCost: 12000),
  ContractTier(name: 'Enterprise', equipmentCount: 10, dailyRevenue: 4800, upgradeCost: 25000),
];

class MonthReport {
  const MonthReport({
    required this.month,
    required this.availability,
    required this.satisfaction,
    required this.averageResponse,
    required this.interventions,
    required this.healthScore,
  });

  final int month;
  final double availability;
  final double satisfaction;
  final double averageResponse;
  final int interventions;
  final double healthScore;

  Map<String, dynamic> toJson() => {
        'month': month,
        'availability': availability,
        'satisfaction': satisfaction,
        'averageResponse': averageResponse,
        'interventions': interventions,
        'healthScore': healthScore,
      };

  factory MonthReport.fromJson(Map<String, dynamic> json) => MonthReport(
        month: json['month'] as int,
        availability: (json['availability'] as num).toDouble(),
        satisfaction: (json['satisfaction'] as num).toDouble(),
        averageResponse: (json['averageResponse'] as num).toDouble(),
        interventions: json['interventions'] as int,
        healthScore: (json['healthScore'] as num).toDouble(),
      );
}
