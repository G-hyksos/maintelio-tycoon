import 'dart:math';

import 'package:flutter/foundation.dart';

import '../utils/format.dart';
import 'achievement.dart';
import 'contract.dart';
import 'equipment.dart';
import 'fault.dart';
import 'game_event.dart';
import 'innovation.dart';
import 'role.dart';
import 'site.dart';
import 'technician.dart';

enum SignalType { panne, reparation, alerte, evenement, succes, info }

/// Événement à présenter au joueur (son, vibration, message).
class GameSignal {
  const GameSignal(this.type, this.message);
  final SignalType type;
  final String message;
}

/// Résumé d'une période d'absence simulée.
class AbsenceReport {
  const AbsenceReport({
    required this.seconds,
    required this.breakdowns,
    required this.repairs,
    required this.moneyDelta,
  });
  final double seconds;
  final int breakdowns;
  final int repairs;
  final double moneyDelta;
}

/// État complet d'une partie, une partie par rôle.
class GameState extends ChangeNotifier {
  GameState._(this.role);

  // Rythme : 1 journée = 60 s réelles, 1 mois = 10 journées.
  static const double dayLength = 60;
  static const int daysPerMonth = 10;

  static const int restockQuantity = 5;
  static const double partPrice = 120;
  static const int stockAlertThreshold = 5;
  static const int stockCapacity = 20;
  static const double restockDelay = 30;

  static const double recruitCost = 2000;
  static const double technicianSalary = 120;
  static const double trainingCost = 800;
  static const double trainingDuration = 20;
  static const double clearanceCost = 600;
  static const double clearanceDuration = 15;
  static const double sensorCost = 400;

  static const double baseTravelTime = 4;
  static const double baseRepairTime = 14;
  static const double lateBreakdownDelay = 30;
  static const double latePenaltyCost = 150;
  static const double clientPenaltyGain = 300;
  static const double auditBonus = 1000;
  static const double eventChance = 0.35;
  static const double adBoostCooldown = 120;

  /// Absence simulée au maximum (secondes de jeu).
  static const double maxAbsence = 900;

  static const List<String> _recruitNames = [
    'Inès', 'Mehdi', 'Clara', 'Yanis', 'Julie',
    'Thomas', 'Nadia', 'Hugo', 'Léa', 'Samir',
  ];

  final PlayerRole role;
  final Random _rng = Random();

  double clock = 0;
  double money = 0;
  int parts = 10;
  final List<Site> sites = [];
  String currentSiteId = '';
  final List<Equipment> equipments = [];
  final List<Technician> technicians = [];
  final List<String> journal = [];
  final List<MonthReport> reports = [];

  // Statistiques du mois en cours (la disponibilité est suivie par site).
  double responseSum = 0;
  int responseCount = 0;
  int interventions = 0;
  int totalInterventions = 0;
  int totalBreakdowns = 0;
  int perfectDiagnostics = 0;

  double? restockArrivesAt;
  bool pendingNote = false;
  double relanceUntil = 0;
  double adBoostReadyAt = 0;
  int innovationPoints = 0;
  final Set<Innovation> innovations = {};
  final Set<Achievement> achievements = {};
  ActiveEvent? activeEvent;
  bool tutorialDone = false;
  int lastSavedAt = 0;
  int _nextId = 1;

  // État transitoire (non sauvegardé).
  String? selectedTechId;
  double _dispatchTimer = 0;
  bool _simulating = false;
  final List<GameSignal> _signals = [];

  // ---------------------------------------------------------------------------
  // Création / sauvegarde
  // ---------------------------------------------------------------------------

  static SiteType startingSite(PlayerRole role) => switch (role) {
        PlayerRole.gestionnaire => SiteType.hopital,
        PlayerRole.dirigeant => SiteType.metro,
        PlayerRole.chefSite => SiteType.metro,
        PlayerRole.adjoint => SiteType.centreCommercial,
        PlayerRole.technicien => SiteType.bureaux,
      };

  factory GameState.newGame(PlayerRole role) {
    final state = GameState._(role);
    state.money = role == PlayerRole.gestionnaire ? 5000 : 10000;
    final site = state._createSite(startingSite(role));
    state.currentSiteId = site.id;
    if (role == PlayerRole.technicien) {
      state.technicians.add(Technician(
        id: state._newId('t'),
        name: 'Vous',
        specialty: EquipmentType.cvc,
        salary: 0,
        isPlayer: true,
      ));
    } else {
      state.technicians.addAll([
        Technician(id: state._newId('t'), name: 'Karim', specialty: EquipmentType.cvc, salary: technicianSalary),
        Technician(id: state._newId('t'), name: 'Sophie', specialty: EquipmentType.electricite, salary: technicianSalary),
        Technician(id: state._newId('t'), name: 'Lucas', specialty: EquipmentType.ascenseur, salary: technicianSalary),
      ]);
    }
    state._log('Prise de poste : ${state.info.label} · ${site.name}');
    return state;
  }

  Map<String, dynamic> toJson() => {
        'version': 2,
        'role': role.name,
        'clock': clock,
        'money': money,
        'parts': parts,
        'sites': sites.map((s) => s.toJson()).toList(),
        'currentSiteId': currentSiteId,
        'equipments': equipments.map((e) => e.toJson()).toList(),
        'technicians': technicians.map((t) => t.toJson()).toList(),
        'journal': journal,
        'reports': reports.map((r) => r.toJson()).toList(),
        'responseSum': responseSum,
        'responseCount': responseCount,
        'interventions': interventions,
        'totalInterventions': totalInterventions,
        'totalBreakdowns': totalBreakdowns,
        'perfectDiagnostics': perfectDiagnostics,
        'restockArrivesAt': restockArrivesAt,
        'pendingNote': pendingNote,
        'relanceUntil': relanceUntil,
        'adBoostReadyAt': adBoostReadyAt,
        'innovationPoints': innovationPoints,
        'innovations': innovations.map((i) => i.name).toList(),
        'achievements': achievements.map((a) => a.name).toList(),
        'activeEvent': activeEvent?.toJson(),
        'tutorialDone': tutorialDone,
        'lastSavedAt': lastSavedAt,
        'nextId': _nextId,
      };

  factory GameState.fromJson(Map<String, dynamic> json) {
    final state = GameState._(PlayerRole.values.byName(json['role'] as String));
    state
      ..clock = (json['clock'] as num).toDouble()
      ..money = (json['money'] as num).toDouble()
      ..parts = json['parts'] as int? ?? 10
      ..responseSum = (json['responseSum'] as num?)?.toDouble() ?? 0
      ..responseCount = json['responseCount'] as int? ?? 0
      ..interventions = json['interventions'] as int? ?? 0
      ..totalInterventions = json['totalInterventions'] as int? ?? 0
      ..totalBreakdowns = json['totalBreakdowns'] as int? ?? 0
      ..perfectDiagnostics = json['perfectDiagnostics'] as int? ?? 0
      ..restockArrivesAt = (json['restockArrivesAt'] as num?)?.toDouble()
      ..pendingNote = json['pendingNote'] as bool? ?? false
      ..relanceUntil = (json['relanceUntil'] as num?)?.toDouble() ?? 0
      ..adBoostReadyAt = (json['adBoostReadyAt'] as num?)?.toDouble() ?? 0
      ..innovationPoints = json['innovationPoints'] as int? ?? 0
      ..tutorialDone = json['tutorialDone'] as bool? ?? false
      ..lastSavedAt = json['lastSavedAt'] as int? ?? 0
      .._nextId = json['nextId'] as int? ?? 100000;

    final rawSites = json['sites'] as List?;
    if (rawSites != null && rawSites.isNotEmpty) {
      state.sites.addAll(rawSites.map((s) => Site.fromJson(s as Map<String, dynamic>)));
    } else {
      // Sauvegarde de la première version : un seul site de bureaux.
      state.sites.add(Site(
        id: state._newId('s'),
        name: SiteType.bureaux.defaultName,
        type: SiteType.bureaux,
        tierIndex: json['tierIndex'] as int? ?? 0,
        satisfaction: (json['satisfaction'] as num?)?.toDouble() ?? 80,
      ));
    }
    final fallbackSiteId = state.sites.first.id;
    state.currentSiteId = json['currentSiteId'] as String? ?? fallbackSiteId;
    state.equipments.addAll((json['equipments'] as List).map((e) =>
        Equipment.fromJson(e as Map<String, dynamic>, fallbackSiteId: fallbackSiteId)));
    state.technicians.addAll((json['technicians'] as List)
        .map((t) => Technician.fromJson(t as Map<String, dynamic>)));
    state.journal.addAll((json['journal'] as List? ?? const []).cast<String>());
    state.reports.addAll((json['reports'] as List? ?? const [])
        .map((r) => MonthReport.fromJson(r as Map<String, dynamic>)));
    for (final name in (json['innovations'] as List?)?.cast<String>() ?? const <String>[]) {
      final match = Innovation.values.where((i) => i.name == name);
      if (match.isNotEmpty) state.innovations.add(match.first);
    }
    for (final name in (json['achievements'] as List?)?.cast<String>() ?? const <String>[]) {
      final match = Achievement.values.where((a) => a.name == name);
      if (match.isNotEmpty) state.achievements.add(match.first);
    }
    final rawEvent = json['activeEvent'];
    if (rawEvent is Map<String, dynamic>) {
      state.activeEvent = ActiveEvent.fromJson(rawEvent);
    }
    return state;
  }

  // ---------------------------------------------------------------------------
  // Lecture
  // ---------------------------------------------------------------------------

  RoleInfo get info => RoleInfo.of(role);

  Site get currentSite => siteById(currentSiteId) ?? sites.first;

  Site? siteById(String id) {
    for (final s in sites) {
      if (s.id == id) return s;
    }
    return null;
  }

  List<Equipment> siteEquipments(String siteId) =>
      equipments.where((e) => e.siteId == siteId).toList();

  List<Equipment> get currentEquipments => siteEquipments(currentSite.id);

  ContractTier tierOf(Site site) => contractTiers[site.tierIndex];
  ContractTier get tier => tierOf(currentSite);

  ContractTier? nextTierOf(Site site) => site.tierIndex + 1 < contractTiers.length
      ? contractTiers[site.tierIndex + 1]
      : null;

  double get dailyRevenue =>
      sites.fold<double>(0, (sum, s) => sum + tierOf(s).dailyRevenue);

  int get dayIndex => (clock / dayLength).floor();
  int get day => dayIndex + 1;
  int get month => dayIndex ~/ daysPerMonth + 1;

  String get timeLabel {
    final progress = (clock % dayLength) / dayLength;
    final minutes = (8 * 60 + progress * 10 * 60).floor();
    final h = (minutes ~/ 60).toString().padLeft(2, '0');
    final m = (minutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  double get satisfaction => sites.isEmpty
      ? 0
      : sites.fold<double>(0, (sum, s) => sum + s.satisfaction) / sites.length;

  double get availability {
    var up = 0.0;
    var total = 0.0;
    for (final s in sites) {
      up += s.upSeconds;
      total += s.totalSeconds;
    }
    return total == 0 ? 100 : up / total * 100;
  }

  double get averageResponse =>
      responseCount == 0 ? 0 : responseSum / responseCount;

  double get responsiveness => responseCount == 0
      ? 100.0
      : (100 - averageResponse * 2).clamp(0, 100).toDouble();

  double siteHealthScore(Site site) =>
      site.availability * 0.4 + site.satisfaction * 0.3 + responsiveness * 0.3;

  double get healthScore => sites.isEmpty
      ? 0
      : sites.fold<double>(0, (sum, s) => sum + siteHealthScore(s)) / sites.length;

  double get dailySalaries =>
      technicians.fold<double>(0, (sum, t) => sum + t.salary);

  String get moneyLabel => info.isClient ? 'Budget' : 'Trésorerie';

  String get objectiveLabel => switch (role) {
        PlayerRole.gestionnaire => 'Disponibilité',
        PlayerRole.dirigeant => 'Marge / jour',
        PlayerRole.chefSite => 'Health score',
        PlayerRole.adjoint => 'Réponse moy.',
        PlayerRole.technicien => 'Interventions',
      };

  String get objectiveValue => switch (role) {
        PlayerRole.gestionnaire => '${availability.round()} %',
        PlayerRole.dirigeant => formatMoney(dailyRevenue - dailySalaries),
        PlayerRole.chefSite => '${healthScore.round()} / 100',
        PlayerRole.adjoint =>
          responseCount == 0 ? '—' : '${averageResponse.round()} s',
        PlayerRole.technicien => '$totalInterventions',
      };

  /// Score envoyé au classement en ligne.
  int get leaderboardScore {
    final reportPoints =
        reports.fold<double>(0, (sum, r) => sum + r.healthScore) * 10;
    return (reportPoints + totalInterventions * 5 + achievements.length * 100).round();
  }

  bool get stockLow => parts <= stockAlertThreshold;
  bool has(Innovation innovation) => innovations.contains(innovation);

  double get travelTime {
    var time = baseTravelTime;
    if (has(Innovation.qrNfc)) time *= 0.6;
    if (activeEvent?.type == GameEventType.greve) time *= 3;
    return time;
  }

  double decayMultiplier(Equipment e, {bool offline = false}) {
    final site = siteById(e.siteId);
    var multiplier = site?.type.decayMultiplier(e.type) ?? 1.0;
    final event = activeEvent;
    if (event?.type == GameEventType.canicule &&
        (e.type == EquipmentType.cvc || e.type == EquipmentType.froid)) {
      multiplier *= 2;
    }
    if (has(Innovation.digitalTwin)) multiplier *= 0.8;
    if (e.hasSensor) multiplier *= 0.9;
    if (offline) multiplier *= 0.5;
    return multiplier;
  }

  Equipment? equipmentById(String id) {
    for (final e in equipments) {
      if (e.id == id) return e;
    }
    return null;
  }

  Technician? technicianById(String id) {
    for (final t in technicians) {
      if (t.id == id) return t;
    }
    return null;
  }

  Technician? get player {
    for (final t in technicians) {
      if (t.isPlayer) return t;
    }
    return null;
  }

  bool isTraining(Technician t) => clock < t.trainingUntil;

  bool isAvailable(Technician t) =>
      t.assignedEquipmentId == null && !isTraining(t) && t.fatigue < 95;

  String? unavailableReason(Technician t) {
    final me = t.isPlayer;
    if (t.assignedEquipmentId != null) {
      return me ? 'Vous êtes déjà en intervention' : '${t.name} est déjà en intervention';
    }
    if (isTraining(t)) return me ? 'Vous êtes en formation' : '${t.name} est en formation';
    if (t.fatigue >= 95) {
      return me
          ? 'Vous êtes épuisé, reprenez votre souffle'
          : '${t.name} est épuisé, laissez-le récupérer';
    }
    return null;
  }

  bool canWorkOn(Technician t, Equipment e) =>
      !e.type.requiresElectricalClearance || t.electricallyCleared;

  bool needsDiagnostic(Equipment e) {
    if (!info.selfRepair || !e.onSite || e.diagnosed) return false;
    final me = player;
    return me != null && e.assignedTechId == me.id;
  }

  String statusLabel(Equipment e) {
    if (e.inIntervention) {
      if (e.travelRemaining > 0) return 'Technicien en route';
      if (needsDiagnostic(e)) return 'Diagnostic requis';
      final kind = e.preventive ? 'Préventif' : 'Réparation';
      return '$kind ${(e.repairProgress * 100).clamp(0, 100).round()} %';
    }
    final planned = e.scheduledDay;
    final base = switch (e.status) {
      EquipmentStatus.ok => 'Fonctionnel',
      EquipmentStatus.usure => 'Usure détectée',
      EquipmentStatus.panne => 'En panne',
    };
    if (planned != null && e.status != EquipmentStatus.panne) {
      return '$base · visite J$planned';
    }
    return base;
  }

  String technicianStatus(Technician t) {
    if (isTraining(t)) return 'En formation';
    final eqId = t.assignedEquipmentId;
    if (eqId != null) {
      final e = equipmentById(eqId);
      if (e != null) {
        return e.travelRemaining > 0 ? 'En route : ${e.name}' : 'Sur ${e.name}';
      }
    }
    if (t.fatigue >= 95) return 'Épuisé';
    return 'Libre';
  }

  double repairDuration(Technician tech, Equipment e) {
    final specialtyFactor = tech.specialty == e.type ? 1.6 : 1.0;
    final levelFactor = 1 + 0.15 * (tech.level - 1);
    var duration = baseRepairTime / specialtyFactor / levelFactor;
    if (has(Innovation.mobileTerrain)) duration /= 1.2;
    if (tech.fatigue >= 80) duration /= 0.6;
    return duration;
  }

  /// Secondes avant la prochaine panne (hors intervention), pour les alertes.
  ({String name, double seconds})? nextPredictedBreakdown({bool offline = false}) {
    ({String name, double seconds})? best;
    for (final e in equipments) {
      if (e.inIntervention || e.health <= 0) continue;
      final rate = e.decayRate * decayMultiplier(e, offline: offline);
      if (rate <= 0) continue;
      final seconds = e.health / rate;
      if (best == null || seconds < best.seconds) {
        best = (name: e.name, seconds: seconds);
      }
    }
    return best;
  }

  List<GameSignal> drainSignals() {
    final drained = List<GameSignal>.of(_signals);
    _signals.clear();
    return drained;
  }

  // ---------------------------------------------------------------------------
  // Boucle de jeu
  // ---------------------------------------------------------------------------

  /// [notify] : prévenir l'interface (la carte Flame lit l'état en continu).
  void tick(double dt, {bool offline = false, bool notify = true}) {
    final previousDay = dayIndex;
    clock += dt;

    final event = activeEvent;
    if (event != null && clock >= event.endsAt) activeEvent = null;

    for (final e in equipments) {
      final site = siteById(e.siteId);
      if (site == null) continue;
      site.totalSeconds += dt;
      if (e.status != EquipmentStatus.panne) site.upSeconds += dt;

      final techId = e.assignedTechId;
      if (techId == null) {
        if (e.health > 0) {
          e.health -= e.decayRate * decayMultiplier(e, offline: offline) * dt;
          if (e.hasSensor && !e.sensorAlerted && e.health < 50) {
            e.sensorAlerted = true;
            _signal(SignalType.alerte, 'Capteur IoT : ${e.name} à surveiller');
          }
          if (e.health <= 0) _breakDown(e, site);
        }
        continue;
      }

      final tech = technicianById(techId);
      if (tech == null) {
        e.assignedTechId = null;
        continue;
      }
      if (e.travelRemaining > 0) {
        e.travelRemaining = max(0.0, e.travelRemaining - dt);
      } else if (!tech.isPlayer) {
        e.repairProgress += dt / repairDuration(tech, e);
        if (e.repairProgress >= 1) _completeRepair(e, tech);
      }
    }

    for (final t in technicians) {
      if (t.assignedEquipmentId == null && t.fatigue > 0) {
        t.fatigue = max(0.0, t.fatigue - dt);
      }
    }

    _updateSatisfaction(dt);

    _dispatchTimer += dt;
    if (_dispatchTimer >= 1) {
      _dispatchTimer = 0;
      final delay = _autoDispatchDelay(offline);
      if (delay != null) _autoDispatch(delay, offline: offline);
      if (has(Innovation.predictif)) _predictiveDispatch();
      _runPlanning();
      _checkAchievements();
    }

    final arrival = restockArrivesAt;
    if (arrival != null && clock >= arrival) {
      restockArrivesAt = null;
      parts = min(stockCapacity, parts + restockQuantity);
      money -= restockQuantity * partPrice;
      _log('Livraison : +$restockQuantity pièces');
    }

    if (dayIndex != previousDay) {
      _endOfDay(previousDay + 1);
      if (dayIndex % daysPerMonth == 0) _endOfMonth();
      _startOfDay();
    }

    if (!_simulating && notify) notifyListeners();
  }

  /// Délai avant prise en charge automatique, ou null si pas d'automatisme.
  double? _autoDispatchDelay(bool offline) {
    if (info.isClient) return clock < relanceUntil ? 5.0 : 20.0;
    if (info.autoDispatch) return 10.0;
    if (offline) return 20.0; // équipe d'astreinte
    if (has(Innovation.commandCenter) && info.canDispatch) return 15.0;
    return null;
  }

  void _breakDown(Equipment e, Site site) {
    e
      ..health = 0
      ..brokenAt = clock
      ..faultIndex = _rng.nextInt(3)
      ..diagnosed = false
      ..diagnosticErrors = 0;
    site.breakdownsToday += 1;
    totalBreakdowns += 1;
    _log('Panne : ${e.name} (${site.name})');
    _signal(SignalType.panne, 'Panne : ${e.name}');
  }

  void _updateSatisfaction(double dt) {
    for (final site in sites) {
      var delta = 0.0;
      var allOk = true;
      for (final e in equipments) {
        if (e.siteId != site.id) continue;
        switch (e.status) {
          case EquipmentStatus.panne:
            delta -= 0.25 * site.type.satisfactionWeight;
            allOk = false;
          case EquipmentStatus.usure:
            delta -= 0.03 * site.type.satisfactionWeight;
            allOk = false;
          case EquipmentStatus.ok:
            break;
        }
      }
      if (allOk) delta += 0.1;
      site.satisfaction = (site.satisfaction + delta * dt).clamp(0, 100).toDouble();
    }
  }

  void _autoDispatch(double delay, {bool offline = false}) {
    for (final e in equipments) {
      if (e.inIntervention) continue;
      final brokenAt = e.brokenAt;
      final urgent = e.status == EquipmentStatus.panne &&
          brokenAt != null &&
          clock - brokenAt >= delay;
      final preventive = e.status == EquipmentStatus.usure && e.health < 20;
      if (!urgent && !preventive) continue;

      final tech = _bestAvailableTech(e);
      if (tech == null) continue;
      if (parts <= 0) {
        if (info.isClient) {
          parts += restockQuantity; // stock géré par le prestataire
        } else if (offline && money >= restockQuantity * partPrice) {
          parts += restockQuantity;
          money -= restockQuantity * partPrice;
        } else {
          return;
        }
      }
      _startIntervention(tech, e);
    }
  }

  void _predictiveDispatch() {
    for (final e in equipments) {
      if (!e.hasSensor || e.inIntervention || e.health <= 0 || e.health >= 30) continue;
      if (parts <= 0) return;
      final tech = _bestAvailableTech(e);
      if (tech == null) continue;
      _startIntervention(tech, e, preventive: true);
      _log('Prédictif : visite déclenchée sur ${e.name}');
    }
  }

  void _runPlanning() {
    for (final e in equipments) {
      final planned = e.scheduledDay;
      if (planned == null || planned > day || e.inIntervention) continue;
      if (parts <= 0) return;
      final tech = _bestAvailableTech(e);
      if (tech == null) continue;
      e.scheduledDay = null;
      _startIntervention(tech, e, preventive: e.status != EquipmentStatus.panne);
    }
  }

  Technician? _bestAvailableTech(Equipment e) {
    final candidates = technicians
        .where((t) => !t.isPlayer && isAvailable(t) && canWorkOn(t, e))
        .toList();
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) {
      final aMatch = a.specialty == e.type ? 1 : 0;
      final bMatch = b.specialty == e.type ? 1 : 0;
      if (aMatch != bMatch) return bMatch - aMatch;
      if (a.level != b.level) return b.level - a.level;
      return a.fatigue.compareTo(b.fatigue);
    });
    return candidates.first;
  }

  void _startIntervention(Technician tech, Equipment e, {bool preventive = false}) {
    parts -= 1;
    e
      ..assignedTechId = tech.id
      ..travelRemaining = travelTime
      ..travelTotal = travelTime
      ..repairProgress = 0
      ..preventive = preventive
      ..diagnosed = false
      ..diagnosticErrors = 0
      ..faultIndex = _rng.nextInt(3);
    tech.assignedEquipmentId = e.id;
    final brokenAt = e.brokenAt;
    if (brokenAt != null) {
      responseSum += clock - brokenAt;
      responseCount += 1;
    }
    _log('${preventive ? 'Préventif' : 'OT'} : ${tech.name} → ${e.name}');
  }

  void _completeRepair(Equipment e, Technician tech) {
    final site = siteById(e.siteId);
    e
      ..health = 100
      ..decayRate = _randomDecay()
      ..brokenAt = null
      ..penalized = false
      ..sensorAlerted = false
      ..assignedTechId = null
      ..travelRemaining = 0
      ..repairProgress = 0
      ..diagnosed = false
      ..preventive = false;
    final previousLevel = tech.level;
    tech
      ..assignedEquipmentId = null
      ..jobs += 1
      ..fatigue = min(100.0, tech.fatigue + (tech.specialty == e.type ? 15 : 25));
    interventions += 1;
    totalInterventions += 1;
    if (site != null) site.satisfaction = min(100.0, site.satisfaction + 2);
    if (totalInterventions % 5 == 0) innovationPoints += 1;
    _log('${e.name} remis en service par ${tech.name}');
    _signal(SignalType.reparation, '${e.name} remis en service');
    if (tech.level > previousLevel) {
      _log('${tech.name} passe au niveau ${tech.level}');
      _signal(SignalType.info, '${tech.name} passe au niveau ${tech.level}');
    }
  }

  void _endOfDay(int finishedDay) {
    final event = activeEvent;
    if (event != null && event.type == GameEventType.audit) {
      final site = siteById(event.siteId ?? '');
      if (site != null) {
        if (siteHealthScore(site) >= 70) {
          if (info.isClient) {
            site.satisfaction = min(100.0, site.satisfaction + 5);
          } else {
            money += auditBonus;
          }
          _log('Audit réussi sur ${site.name}');
          _signal(SignalType.succes, 'Audit réussi sur ${site.name}');
        } else {
          site.satisfaction = max(0.0, site.satisfaction - 10);
          _log('Audit défavorable sur ${site.name}');
          _signal(SignalType.alerte, 'Audit défavorable sur ${site.name}');
        }
      }
    }
    activeEvent = null;

    if (finishedDay > 1 && sites.every((s) => s.breakdownsToday == 0)) {
      _unlock(Achievement.journeeSansPanne);
    }
    for (final s in sites) {
      s.breakdownsToday = 0;
    }

    if (info.isClient) {
      final allowance = dailyRevenue * 0.2;
      money += allowance;
      pendingNote = true;
      _log('Jour $finishedDay : +${formatMoney(allowance)} de budget, note du prestataire reçue');
      return;
    }
    var penalties = 0.0;
    for (final e in equipments) {
      final brokenAt = e.brokenAt;
      if (e.status == EquipmentStatus.panne &&
          brokenAt != null &&
          clock - brokenAt > lateBreakdownDelay) {
        final site = siteById(e.siteId);
        penalties += latePenaltyCost * (site?.type.penaltyMultiplier ?? 1);
      }
    }
    final net = dailyRevenue - dailySalaries - penalties;
    money += net;
    _log('Jour $finishedDay : ${net >= 0 ? '+' : ''}${formatMoney(net)}'
        '${penalties > 0 ? ' (dont ${formatMoney(penalties)} de pénalités)' : ''}');
  }

  void _startOfDay() {
    if (_rng.nextDouble() >= eventChance) return;
    final type = GameEventType.values[_rng.nextInt(GameEventType.values.length)];
    final site = sites[_rng.nextInt(sites.length)];
    // +1 s : l'événement reste actif jusqu'au bilan de fin de journée.
    final endsAt = type == GameEventType.coupure
        ? clock + 15
        : (dayIndex + 1) * dayLength + 1;
    activeEvent = ActiveEvent(type: type, endsAt: endsAt, siteId: site.id);
    if (type == GameEventType.coupure) {
      for (final e in equipments) {
        if (e.siteId == site.id &&
            e.type.requiresElectricalClearance &&
            !e.inIntervention &&
            e.health > 0) {
          _breakDown(e, site);
        }
      }
    }
    final where = type == GameEventType.coupure || type == GameEventType.audit
        ? ' · ${site.name}'
        : '';
    _log('Événement : ${type.label}$where');
    _signal(SignalType.evenement, '${type.label}$where : ${type.description}');
  }

  void _endOfMonth() {
    final siteScores = {for (final s in sites) s.id: siteHealthScore(s)};
    final report = MonthReport(
      month: dayIndex ~/ daysPerMonth,
      availability: availability,
      satisfaction: satisfaction,
      averageResponse: averageResponse,
      interventions: interventions,
      healthScore: healthScore,
    );
    reports.add(report);
    for (final s in sites) {
      s
        ..upSeconds = 0
        ..totalSeconds = 0;
    }
    responseSum = 0;
    responseCount = 0;
    interventions = 0;
    if (report.healthScore >= 70) innovationPoints += 2;
    _log('Rapport du mois ${report.month} : health score ${report.healthScore.round()}');
    _signal(SignalType.info,
        'Rapport du mois ${report.month} : health score ${report.healthScore.round()}');

    for (final s in sites) {
      final score = siteScores[s.id] ?? 0;
      if (score < 35 && s.tierIndex > 0) {
        _setSiteTier(s, s.tierIndex - 1);
        _log('Contrat rétrogradé (${s.name}) : ${tierOf(s).name}');
      } else if (!info.canUpgradeContract && score >= 80 && nextTierOf(s) != null) {
        _setSiteTier(s, s.tierIndex + 1);
        _log('Contrat promu (${s.name}) : ${tierOf(s).name}');
      }
    }
  }

  void _checkAchievements() {
    if (totalInterventions >= 1) _unlock(Achievement.premiereReparation);
    if (totalInterventions >= 10) _unlock(Achievement.dixReparations);
    if (totalInterventions >= 50) _unlock(Achievement.cinquanteReparations);
    if (reports.isNotEmpty) _unlock(Achievement.premierMois);
    if (reports.any((r) => r.healthScore >= 85)) _unlock(Achievement.scoreExcellence);
    if (sites.any((s) => s.tierIndex == contractTiers.length - 1)) {
      _unlock(Achievement.contratEnterprise);
    }
    if (technicians.length >= 6) _unlock(Achievement.equipeComplete);
    if (sites.length >= 2) _unlock(Achievement.deuxiemeSite);
    if (equipments.any((e) => e.hasSensor)) _unlock(Achievement.premierCapteur);
    if (perfectDiagnostics >= 5) _unlock(Achievement.diagnosticParfait);
    if (innovations.length == Innovation.values.length) _unlock(Achievement.innovateur);
  }

  void _unlock(Achievement achievement) {
    if (!achievements.add(achievement)) return;
    innovationPoints += 1;
    _log('Succès : ${achievement.label}');
    _signal(SignalType.succes, 'Succès débloqué : ${achievement.label} (+1 point)');
  }

  /// Simule une absence (application fermée) avec l'équipe d'astreinte.
  AbsenceReport simulateAbsence(double seconds) {
    final duration = seconds.clamp(0, maxAbsence).toDouble();
    final breakdownsBefore = totalBreakdowns;
    final repairsBefore = totalInterventions;
    final moneyBefore = money;
    _simulating = true;
    var remaining = duration;
    while (remaining > 0) {
      final step = min(1.0, remaining);
      tick(step, offline: true);
      remaining -= step;
    }
    _simulating = false;
    _signals.clear();
    notifyListeners();
    return AbsenceReport(
      seconds: duration,
      breakdowns: totalBreakdowns - breakdownsBefore,
      repairs: totalInterventions - repairsBefore,
      moneyDelta: money - moneyBefore,
    );
  }

  // ---------------------------------------------------------------------------
  // Actions du joueur (retournent un message à afficher, ou null)
  // ---------------------------------------------------------------------------

  void switchSite(String siteId) {
    if (siteById(siteId) == null) return;
    currentSiteId = siteId;
    selectedTechId = null;
    notifyListeners();
  }

  String? selectTech(String techId) {
    final tech = technicianById(techId);
    if (tech == null) return null;
    final reason = unavailableReason(tech);
    if (reason != null) return reason;
    selectedTechId = selectedTechId == techId ? null : techId;
    notifyListeners();
    return null;
  }

  void clearSelection() {
    if (selectedTechId == null) return;
    selectedTechId = null;
    notifyListeners();
  }

  String? tapEquipment(String equipmentId) {
    final e = equipmentById(equipmentId);
    if (e == null) return null;

    if (info.isClient) return '${e.name} : ${statusLabel(e)}';

    if (info.selfRepair) {
      final me = player;
      if (me == null) return null;
      if (me.assignedEquipmentId == e.id) {
        if (e.travelRemaining > 0) return 'Vous êtes en route vers ${e.name}';
        if (!e.diagnosed) return 'Diagnostic requis';
        var step = (me.specialty == e.type ? 0.14 : 0.1) * (1 + 0.1 * (me.level - 1));
        if (has(Innovation.mobileTerrain)) step *= 1.2;
        if (me.fatigue >= 80) step *= 0.6;
        e.repairProgress += step;
        if (e.repairProgress >= 1) {
          _completeRepair(e, me);
          notifyListeners();
          return null;
        }
        notifyListeners();
        return null;
      }
      if (me.assignedEquipmentId != null) return "Terminez d'abord votre intervention en cours";
      final reason = unavailableReason(me);
      if (reason != null) return reason;
      return assign(me.id, e.id);
    }

    if (!info.canDispatch) return null;
    final techId = selectedTechId;
    if (techId == null) return "Sélectionnez ou glissez d'abord un technicien";
    final error = assign(techId, e.id);
    if (error == null) selectedTechId = null;
    notifyListeners();
    return error;
  }

  /// Crée un ordre de travail. Retourne un message d'erreur, ou null si OK.
  String? assign(String techId, String equipmentId) {
    final tech = technicianById(techId);
    final e = equipmentById(equipmentId);
    if (tech == null || e == null) return null;
    if (e.status == EquipmentStatus.ok) {
      return '${e.name} est en bon état : planifiez plutôt une visite préventive';
    }
    if (e.inIntervention) return 'Intervention déjà en cours sur ${e.name}';
    final reason = unavailableReason(tech);
    if (reason != null) return reason;
    if (!canWorkOn(tech, e)) {
      return "${tech.name} n'a pas l'habilitation électrique pour ${e.name}";
    }
    if (parts <= 0) return 'Stock de pièces vide';
    _startIntervention(tech, e);
    notifyListeners();
    return null;
  }

  /// Étape « pièce » du diagnostic. Retourne true si la pièce est la bonne.
  bool submitDiagnosticPart(String equipmentId, String part) {
    final e = equipmentById(equipmentId);
    if (e == null) return false;
    if (faultOf(e).part == part) return true;
    e.diagnosticErrors += 1;
    if (parts > 0) parts -= 1;
    _log('Mauvaise pièce posée sur ${e.name}');
    notifyListeners();
    return false;
  }

  /// Fin du diagnostic : bonus d'avancement selon la qualité du travail.
  String completeDiagnostic(String equipmentId, {required bool measureOk}) {
    final e = equipmentById(equipmentId);
    final me = player;
    if (e == null || me == null) return '';
    e.diagnosed = true;
    final firstTry = e.diagnosticErrors == 0;
    e.repairProgress += (firstTry ? 0.35 : 0.15) + (measureOk ? 0.15 : 0);
    if (firstTry && measureOk) perfectDiagnostics += 1;
    if (e.repairProgress >= 1) {
      _completeRepair(e, me);
    }
    notifyListeners();
    if (firstTry && measureOk) return 'Diagnostic parfait : touchez pour finir la réparation';
    if (!measureOk) return 'Réglage approximatif : touchez pour finir la réparation';
    return 'Diagnostic terminé : touchez pour finir la réparation';
  }

  String restock() {
    if (info.isClient) return 'Le stock est géré par le prestataire';
    const cost = restockQuantity * partPrice;
    if (parts + restockQuantity > stockCapacity) return 'Stock plein';
    if (info.canRestock) {
      if (money < cost) return 'Trésorerie insuffisante';
      money -= cost;
      parts += restockQuantity;
      _log('Commande : +$restockQuantity pièces');
      notifyListeners();
      return '+$restockQuantity pièces en stock';
    }
    if (restockArrivesAt != null) return 'Une commande est déjà en cours';
    restockArrivesAt = clock + restockDelay;
    _log('Demande de réapprovisionnement envoyée');
    notifyListeners();
    return 'Demande envoyée, livraison dans ${restockDelay.round()} s';
  }

  String recruit() {
    if (!info.canRecruit) return 'Action réservée au dirigeant';
    if (money < recruitCost) return 'Trésorerie insuffisante';
    final used = technicians.map((t) => t.name).toSet();
    final name = _recruitNames.firstWhere(
      (n) => !used.contains(n),
      orElse: () => 'Technicien ${technicians.length + 1}',
    );
    final specialty =
        EquipmentType.values[_rng.nextInt(EquipmentType.values.length)];
    technicians.add(Technician(
      id: _newId('t'),
      name: name,
      specialty: specialty,
      salary: technicianSalary,
    ));
    money -= recruitCost;
    _log('Recrutement : $name (${specialty.specialtyLabel})');
    notifyListeners();
    return "$name rejoint l'équipe";
  }

  String train(String techId) {
    final tech = technicianById(techId);
    if (tech == null) return '';
    if (!info.canTrain) return 'Action non disponible pour ce rôle';
    if (tech.level >= Technician.maxLevel) return '${tech.name} a atteint le niveau maximal';
    final reason = unavailableReason(tech);
    if (reason != null) return reason;
    if (money < trainingCost) return 'Trésorerie insuffisante';
    money -= trainingCost;
    tech
      ..trainingLevels += 1
      ..trainingUntil = clock + trainingDuration;
    _log('Formation : ${tech.name} (niveau ${tech.level})');
    notifyListeners();
    return '${tech.name} part en formation ${trainingDuration.round()} s';
  }

  String grantClearance(String techId) {
    final tech = technicianById(techId);
    if (tech == null) return '';
    if (!info.canTrain) return 'Action non disponible pour ce rôle';
    if (tech.electricallyCleared) return '${tech.name} est déjà habilité';
    final reason = unavailableReason(tech);
    if (reason != null) return reason;
    if (money < clearanceCost) return 'Trésorerie insuffisante';
    money -= clearanceCost;
    tech
      ..habilitationElec = true
      ..trainingUntil = clock + clearanceDuration;
    _log('Habilitation électrique : ${tech.name}');
    notifyListeners();
    return '${tech.name} passe son habilitation électrique';
  }

  String schedulePreventive(String equipmentId) {
    final e = equipmentById(equipmentId);
    if (e == null) return '';
    if (!info.canDispatch) return 'Action réservée au pilotage';
    if (e.scheduledDay != null) {
      e.scheduledDay = null;
      notifyListeners();
      return 'Visite annulée : ${e.name}';
    }
    if (e.inIntervention) return 'Intervention déjà en cours sur ${e.name}';
    e.scheduledDay = day + 1;
    _log('Visite préventive planifiée J${day + 1} : ${e.name}');
    notifyListeners();
    return 'Visite planifiée demain : ${e.name}';
  }

  String installSensor(String equipmentId) {
    final e = equipmentById(equipmentId);
    if (e == null) return '';
    if (!has(Innovation.gtbIot)) return "Débloquez d'abord l'innovation GTB et capteurs IoT";
    if (e.hasSensor) return '${e.name} est déjà équipé';
    if (money < sensorCost) return '$moneyLabel insuffisant${info.isClient ? '' : 'e'}';
    money -= sensorCost;
    e.hasSensor = true;
    _log('Capteur IoT installé : ${e.name}');
    notifyListeners();
    return 'Capteur installé sur ${e.name}';
  }

  bool canUnlock(Innovation innovation) {
    if (has(innovation)) return false;
    final prerequisite = innovation.requires;
    if (prerequisite != null && !has(prerequisite)) return false;
    return innovationPoints >= innovation.cost;
  }

  String unlockInnovation(Innovation innovation) {
    if (has(innovation)) return 'Déjà débloqué';
    final prerequisite = innovation.requires;
    if (prerequisite != null && !has(prerequisite)) {
      return 'Débloquez d’abord ${prerequisite.label}';
    }
    if (innovationPoints < innovation.cost) return 'Points d’innovation insuffisants';
    innovationPoints -= innovation.cost;
    innovations.add(innovation);
    _log('Innovation : ${innovation.label}');
    _signal(SignalType.succes, 'Innovation débloquée : ${innovation.label}');
    _checkAchievements();
    notifyListeners();
    return '${innovation.label} débloqué';
  }

  String upgradeContract(String siteId) {
    final site = siteById(siteId);
    if (site == null) return '';
    final next = nextTierOf(site);
    if (!info.canUpgradeContract) return 'Action réservée au dirigeant';
    if (next == null) return 'Contrat maximal atteint';
    if (reports.isEmpty || reports.last.healthScore < 70) {
      return "Un health score d'au moins 70 au dernier rapport est requis";
    }
    if (money < next.upgradeCost) return 'Trésorerie insuffisante';
    money -= next.upgradeCost;
    _setSiteTier(site, site.tierIndex + 1);
    _log('Contrat ${next.name} signé (${site.name})');
    notifyListeners();
    return 'Contrat ${next.name} signé pour ${site.name}';
  }

  SiteType? get nextSiteType {
    final owned = sites.map((s) => s.type).toSet();
    for (final type in SiteType.values) {
      if (!owned.contains(type)) return type;
    }
    return null;
  }

  String openSite() {
    if (!info.canUpgradeContract) return 'Action réservée au dirigeant';
    final type = nextSiteType;
    if (type == null) return 'Tous les sites sont déjà ouverts';
    if (money < Site.openingCost) return 'Trésorerie insuffisante';
    money -= Site.openingCost;
    final site = _createSite(type);
    _log('Nouveau site : ${site.name}');
    _signal(SignalType.succes, 'Nouveau site : ${site.name}');
    notifyListeners();
    return '${site.name} rejoint votre portefeuille';
  }

  String writeNote() {
    if (!info.canWriteNote) return 'Action réservée au chef de site';
    final site = currentSite;
    if (site.lastNoteDay == day) return "Une note a déjà été envoyée aujourd'hui";
    site.lastNoteDay = day;
    site.satisfaction = min(100.0, site.satisfaction + 6);
    _log('Note envoyée au client (${site.name})');
    notifyListeners();
    return 'Note envoyée au client';
  }

  String validateNote() {
    if (!info.isClient) return 'Action réservée au gestionnaire';
    if (!pendingNote) return 'Aucune note en attente';
    pendingNote = false;
    final site = currentSite;
    site.satisfaction = min(100.0, site.satisfaction + 3);
    _log('Note du prestataire validée');
    notifyListeners();
    return 'Note validée';
  }

  String relance() {
    if (!info.isClient) return 'Action réservée au gestionnaire';
    if (clock < relanceUntil) return 'Relance déjà en cours';
    relanceUntil = clock + 30;
    _log('Prestataire relancé');
    notifyListeners();
    return 'Prestataire relancé : interventions accélérées pendant 30 s';
  }

  String applyPenalty() {
    if (!info.isClient) return 'Action réservée au gestionnaire';
    for (final e in equipments) {
      final brokenAt = e.brokenAt;
      if (e.status == EquipmentStatus.panne &&
          brokenAt != null &&
          !e.penalized &&
          clock - brokenAt > lateBreakdownDelay) {
        e.penalized = true;
        final site = siteById(e.siteId);
        final gain = clientPenaltyGain * (site?.type.penaltyMultiplier ?? 1);
        money += gain;
        _log('Pénalité appliquée : ${e.name}');
        notifyListeners();
        return 'Pénalité de ${formatMoney(gain)} appliquée : ${e.name}';
      }
    }
    return 'Aucune panne de plus de ${lateBreakdownDelay.round()} s à pénaliser';
  }

  double get adBoostRemaining => max(0.0, adBoostReadyAt - clock);

  /// Récompense publicitaire : termine l'intervention la plus avancée.
  String applyAdBoost() {
    if (adBoostRemaining > 0) {
      return 'Boost disponible dans ${adBoostRemaining.ceil()} s';
    }
    Equipment? target;
    for (final e in equipments) {
      if (!e.inIntervention) continue;
      if (target == null || e.repairProgress > target.repairProgress) target = e;
    }
    if (target == null) return 'Aucune intervention en cours à accélérer';
    final tech = technicianById(target.assignedTechId!);
    if (tech == null) return '';
    adBoostReadyAt = clock + adBoostCooldown;
    _completeRepair(target, tech);
    notifyListeners();
    return '${target.name} réparé instantanément';
  }

  void finishTutorial() {
    tutorialDone = true;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Outils internes
  // ---------------------------------------------------------------------------

  Site _createSite(SiteType type) {
    final site = Site(id: _newId('s'), name: type.defaultName, type: type);
    sites.add(site);
    _fillSite(site, tierOf(site).equipmentCount);
    return site;
  }

  void _setSiteTier(Site site, int index) {
    site.tierIndex = index;
    final target = tierOf(site).equipmentCount;
    final current = siteEquipments(site.id);
    if (current.length < target) {
      _fillSite(site, target);
      return;
    }
    for (final removed in current.skip(target)) {
      equipments.remove(removed);
      final techId = removed.assignedTechId;
      if (techId != null) technicianById(techId)?.assignedEquipmentId = null;
    }
  }

  void _fillSite(Site site, int count) {
    final catalog = site.type.catalog;
    var existing = siteEquipments(site.id).length;
    while (existing < count && existing < catalog.length) {
      final def = catalog[existing];
      equipments.add(Equipment(
        id: _newId('e'),
        siteId: site.id,
        name: def.name,
        type: def.type,
        health: 60 + _rng.nextDouble() * 40,
        decayRate: _randomDecay(),
      ));
      existing += 1;
    }
  }

  double _randomDecay() => 0.5 + _rng.nextDouble() * 0.7;

  String _newId(String prefix) => '$prefix${_nextId++}';

  void _signal(SignalType type, String message) {
    if (_simulating) return;
    _signals.add(GameSignal(type, message));
  }

  void _log(String message) {
    journal.add('J$day $timeLabel · $message');
    if (journal.length > 60) journal.removeAt(0);
  }
}
