import 'package:flutter/material.dart';

/// Arbre technologique inspiré de la feuille de route Maintelio.
enum Innovation { qrNfc, mobileTerrain, gtbIot, predictif, digitalTwin, commandCenter }

extension InnovationInfo on Innovation {
  String get label => switch (this) {
        Innovation.qrNfc => 'QR codes et NFC',
        Innovation.mobileTerrain => 'Mobile terrain',
        Innovation.gtbIot => 'GTB et capteurs IoT',
        Innovation.predictif => 'Maintenance prédictive',
        Innovation.digitalTwin => 'Digital twin',
        Innovation.commandCenter => 'Command center',
      };

  String get description => switch (this) {
        Innovation.qrNfc =>
          'Déplacements 40 % plus rapides et scan automatique lors du diagnostic.',
        Innovation.mobileTerrain => 'Réparations 20 % plus rapides.',
        Innovation.gtbIot =>
          'Permet d’installer des capteurs : santé visible en permanence, alerte avant la panne, usure −10 %.',
        Innovation.predictif =>
          'Les équipements équipés de capteurs sont traités automatiquement avant la panne.',
        Innovation.digitalTwin => 'Usure de tous les équipements −20 %.',
        Innovation.commandCenter =>
          'Dispatch automatique des pannes pour le chef de site et l’adjoint.',
      };

  int get cost => switch (this) {
        Innovation.qrNfc => 2,
        Innovation.mobileTerrain => 3,
        Innovation.gtbIot => 3,
        Innovation.predictif => 4,
        Innovation.digitalTwin => 5,
        Innovation.commandCenter => 6,
      };

  Innovation? get requires => switch (this) {
        Innovation.qrNfc => null,
        Innovation.mobileTerrain => Innovation.qrNfc,
        Innovation.gtbIot => null,
        Innovation.predictif => Innovation.gtbIot,
        Innovation.digitalTwin => Innovation.predictif,
        Innovation.commandCenter => Innovation.mobileTerrain,
      };

  IconData get icon => switch (this) {
        Innovation.qrNfc => Icons.qr_code_scanner,
        Innovation.mobileTerrain => Icons.phone_android,
        Innovation.gtbIot => Icons.sensors,
        Innovation.predictif => Icons.insights,
        Innovation.digitalTwin => Icons.view_in_ar,
        Innovation.commandCenter => Icons.dashboard,
      };
}
