import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/role.dart';

class LeaderboardEntry {
  const LeaderboardEntry({required this.pseudo, required this.score});
  final String pseudo;
  final int score;
}

class LeaderboardException implements Exception {
  const LeaderboardException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Classement en ligne, servi par l'API Laravel (dossier backend_laravel).
/// URL fournie au build : --dart-define=LEADERBOARD_URL=https://exemple.fr
class LeaderboardService {
  static const String baseUrl = String.fromEnvironment('LEADERBOARD_URL');
  static const Duration _timeout = Duration(seconds: 10);
  static const Map<String, String> _headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  bool get configured => baseUrl.isNotEmpty;

  Uri _uri(String path, [Map<String, String>? query]) {
    final root = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    return Uri.parse('$root$path').replace(queryParameters: query);
  }

  Future<void> submit({
    required String deviceId,
    required String pseudo,
    required PlayerRole role,
    required int score,
  }) async {
    if (!configured) throw const LeaderboardException('Classement en ligne non configuré');
    try {
      final response = await http
          .post(
            _uri('/api/tycoon/scores'),
            headers: _headers,
            body: jsonEncode({
              'device_id': deviceId,
              'pseudo': pseudo,
              'role': role.name,
              'score': score,
            }),
          )
          .timeout(_timeout);
      if (response.statusCode >= 300) {
        throw LeaderboardException('Envoi refusé (${response.statusCode})');
      }
    } on LeaderboardException {
      rethrow;
    } catch (_) {
      throw const LeaderboardException('Serveur de classement injoignable');
    }
  }

  Future<List<LeaderboardEntry>> top(PlayerRole role) async {
    if (!configured) throw const LeaderboardException('Classement en ligne non configuré');
    try {
      final response = await http
          .get(_uri('/api/tycoon/leaderboard', {'role': role.name}), headers: _headers)
          .timeout(_timeout);
      if (response.statusCode >= 300) {
        throw LeaderboardException('Classement indisponible (${response.statusCode})');
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final rows = body['data'] as List? ?? const [];
      return rows
          .map((row) => row as Map<String, dynamic>)
          .map((row) => LeaderboardEntry(
                pseudo: row['pseudo'] as String,
                score: (row['score'] as num).toInt(),
              ))
          .toList();
    } on LeaderboardException {
      rethrow;
    } catch (_) {
      throw const LeaderboardException('Serveur de classement injoignable');
    }
  }
}
