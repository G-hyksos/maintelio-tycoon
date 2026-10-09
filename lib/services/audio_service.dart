import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/game_state.dart';

/// Sons et vibrations du jeu. Un pool de lecteurs par effet, réutilisé.
class AudioService {
  AudioService._();
  static final AudioService instance = AudioService._();

  static const String panne = 'panne.wav';
  static const String reparation = 'reparation.wav';
  static const String alerte = 'alerte.wav';
  static const String succes = 'succes.wav';
  static const String clic = 'clic.wav';
  static const List<String> _files = [panne, reparation, alerte, succes, clic];

  bool enabled = true;
  final Map<String, AudioPool> _pools = {};

  Future<void> preload() async {
    for (final file in _files) {
      try {
        _pools[file] = await FlameAudio.createPool(file, maxPlayers: 3);
      } catch (error) {
        debugPrint('Son indisponible ($file) : $error');
      }
    }
  }

  Future<void> play(String file) async {
    if (!enabled) return;
    final pool = _pools[file];
    if (pool == null) return;
    try {
      await pool.start(volume: 0.6);
    } catch (error) {
      debugPrint('Lecture du son impossible : $error');
    }
  }

  /// Son et vibration associés à un signal de jeu.
  void react(SignalType type) {
    switch (type) {
      case SignalType.panne:
        play(panne);
        HapticFeedback.mediumImpact();
      case SignalType.reparation:
        play(reparation);
        HapticFeedback.lightImpact();
      case SignalType.alerte:
        play(alerte);
        HapticFeedback.mediumImpact();
      case SignalType.evenement:
        play(alerte);
        HapticFeedback.heavyImpact();
      case SignalType.succes:
        play(succes);
        HapticFeedback.lightImpact();
      case SignalType.info:
        break;
    }
  }

  void tap() {
    play(clic);
    HapticFeedback.selectionClick();
  }
}
