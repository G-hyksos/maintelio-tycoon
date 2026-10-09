import 'package:flutter/material.dart';

enum PlayerRole { gestionnaire, dirigeant, chefSite, adjoint, technicien }

class RoleInfo {
  const RoleInfo({
    required this.role,
    required this.label,
    required this.description,
    required this.objective,
    required this.icon,
    this.canDispatch = false,
    this.autoDispatch = false,
    this.selfRepair = false,
    this.canRestock = false,
    this.canWriteNote = false,
    this.canRecruit = false,
    this.canUpgradeContract = false,
    this.canTrain = false,
    this.isClient = false,
  });

  final PlayerRole role;
  final String label;
  final String description;
  final String objective;
  final IconData icon;

  /// Peut affecter manuellement un technicien à un équipement.
  final bool canDispatch;

  /// Les pannes sont prises en charge automatiquement (IA chef / prestataire).
  final bool autoDispatch;

  /// Le joueur est le technicien et répare lui-même (mini-jeu).
  final bool selfRepair;

  /// Commande directe de pièces (sinon : demande avec délai).
  final bool canRestock;

  final bool canWriteNote;
  final bool canRecruit;
  final bool canUpgradeContract;

  /// Peut financer formations et habilitations.
  final bool canTrain;

  /// Côté client : budget, pénalités, validation des notes.
  final bool isClient;

  static RoleInfo of(PlayerRole role) =>
      allRoles.firstWhere((info) => info.role == role);
}

const List<RoleInfo> allRoles = [
  RoleInfo(
    role: PlayerRole.gestionnaire,
    label: 'Gestionnaire de bâtiment',
    description:
        'Côté client : vous suivez la qualité du service, relancez le prestataire, validez ses notes et appliquez les pénalités.',
    objective: 'Disponibilité des équipements au meilleur coût',
    icon: Icons.apartment,
    autoDispatch: true,
    isClient: true,
  ),
  RoleInfo(
    role: PlayerRole.dirigeant,
    label: "Dirigeant d'entreprise",
    description:
        'Vous gérez la trésorerie, recrutez les techniciens et faites évoluer les contrats de Free à Enterprise.',
    objective: 'Rentabilité et croissance',
    icon: Icons.business_center,
    canDispatch: true,
    autoDispatch: true,
    canRestock: true,
    canRecruit: true,
    canUpgradeContract: true,
    canTrain: true,
  ),
  RoleInfo(
    role: PlayerRole.chefSite,
    label: 'Chef de site',
    description:
        "Vous pilotez l'équipe, le stock de pièces et rédigez les notes envoyées au client.",
    objective: 'Health score du site',
    icon: Icons.engineering,
    canDispatch: true,
    canRestock: true,
    canWriteNote: true,
    canTrain: true,
  ),
  RoleInfo(
    role: PlayerRole.adjoint,
    label: 'Adjoint',
    description:
        'Vous dispatchez les ordres de travail et gérez le terrain au quotidien.',
    objective: 'Temps de réponse aux pannes',
    icon: Icons.assignment_ind,
    canDispatch: true,
  ),
  RoleInfo(
    role: PlayerRole.technicien,
    label: 'Technicien',
    description:
        'Sur le terrain : vous vous déplacez sur les équipements et les réparez vous-même.',
    objective: 'Interventions réalisées',
    icon: Icons.build,
    selfRepair: true,
    canTrain: true,
  ),
];
