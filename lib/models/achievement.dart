import 'package:flutter/material.dart';

enum Achievement {
  premiereReparation,
  dixReparations,
  cinquanteReparations,
  journeeSansPanne,
  premierMois,
  scoreExcellence,
  contratEnterprise,
  equipeComplete,
  deuxiemeSite,
  premierCapteur,
  diagnosticParfait,
  innovateur,
}

extension AchievementInfo on Achievement {
  String get label => switch (this) {
        Achievement.premiereReparation => 'Première réparation',
        Achievement.dixReparations => 'Main sûre',
        Achievement.cinquanteReparations => 'Vétéran du terrain',
        Achievement.journeeSansPanne => 'Journée parfaite',
        Achievement.premierMois => 'Premier rapport',
        Achievement.scoreExcellence => 'Excellence',
        Achievement.contratEnterprise => 'Enterprise',
        Achievement.equipeComplete => 'Grande équipe',
        Achievement.deuxiemeSite => 'Multi-sites',
        Achievement.premierCapteur => 'Connecté',
        Achievement.diagnosticParfait => 'Œil d’expert',
        Achievement.innovateur => 'Innovateur',
      };

  String get description => switch (this) {
        Achievement.premiereReparation => 'Terminer une intervention.',
        Achievement.dixReparations => 'Terminer 10 interventions.',
        Achievement.cinquanteReparations => 'Terminer 50 interventions.',
        Achievement.journeeSansPanne => 'Finir une journée sans aucune panne.',
        Achievement.premierMois => 'Recevoir le premier rapport mensuel.',
        Achievement.scoreExcellence => 'Obtenir un health score de 85 sur un mois.',
        Achievement.contratEnterprise => 'Atteindre un contrat Enterprise.',
        Achievement.equipeComplete => 'Compter 6 techniciens.',
        Achievement.deuxiemeSite => 'Gérer un deuxième site.',
        Achievement.premierCapteur => 'Installer un capteur IoT.',
        Achievement.diagnosticParfait => 'Réussir 5 diagnostics parfaits.',
        Achievement.innovateur => 'Débloquer toutes les innovations.',
      };

  IconData get icon => switch (this) {
        Achievement.premiereReparation => Icons.build_circle_outlined,
        Achievement.dixReparations => Icons.handyman,
        Achievement.cinquanteReparations => Icons.military_tech,
        Achievement.journeeSansPanne => Icons.wb_sunny_outlined,
        Achievement.premierMois => Icons.description_outlined,
        Achievement.scoreExcellence => Icons.star_outline,
        Achievement.contratEnterprise => Icons.workspace_premium,
        Achievement.equipeComplete => Icons.groups,
        Achievement.deuxiemeSite => Icons.location_city,
        Achievement.premierCapteur => Icons.sensors,
        Achievement.diagnosticParfait => Icons.biotech,
        Achievement.innovateur => Icons.rocket_launch,
      };
}
