import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/game_state.dart';
import '../models/role.dart';

/// Une sauvegarde par rôle, le dernier rôle joué et les réglages.
class SaveService {
  static const String _lastRoleKey = 'last_role';
  static const String _soundKey = 'sound_enabled';
  static const String _pseudoKey = 'pseudo';
  static const String _premiumKey = 'premium';
  static const String _deviceIdKey = 'device_id';

  static String _saveKey(PlayerRole role) => 'save_${role.name}';

  Future<PlayerRole?> lastRole() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_lastRoleKey);
    if (name == null) return null;
    for (final role in PlayerRole.values) {
      if (role.name == name) return role;
    }
    return null;
  }

  Future<void> setLastRole(PlayerRole role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastRoleKey, role.name);
  }

  Future<Set<PlayerRole>> savedRoles() async {
    final prefs = await SharedPreferences.getInstance();
    return PlayerRole.values
        .where((role) => prefs.containsKey(_saveKey(role)))
        .toSet();
  }

  Future<GameState?> load(PlayerRole role) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_saveKey(role));
    if (raw == null) return null;
    try {
      return GameState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // Sauvegarde illisible : conservée à part, nouvelle partie.
      await prefs.setString('${_saveKey(role)}_corrupt', raw);
      await prefs.remove(_saveKey(role));
      return null;
    }
  }

  Future<void> save(GameState state) async {
    state.lastSavedAt = DateTime.now().millisecondsSinceEpoch;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_saveKey(state.role), jsonEncode(state.toJson()));
  }

  Future<bool> soundEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_soundKey) ?? true;
  }

  Future<void> setSoundEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_soundKey, enabled);
  }

  Future<String?> pseudo() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_pseudoKey);
  }

  Future<void> setPseudo(String pseudo) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pseudoKey, pseudo);
  }

  Future<bool> premium() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_premiumKey) ?? false;
  }

  Future<void> setPremium(bool premium) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_premiumKey, premium);
  }

  /// Identifiant anonyme de l'appareil, pour le classement.
  Future<String> deviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_deviceIdKey);
    if (existing != null) return existing;
    final rng = Random.secure();
    final id = List.generate(16, (_) => rng.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    await prefs.setString(_deviceIdKey, id);
    return id;
  }
}
