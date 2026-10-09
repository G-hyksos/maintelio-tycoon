import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../models/equipment.dart';
import '../models/fault.dart';
import '../models/game_state.dart';
import '../models/innovation.dart';
import '../services/audio_service.dart';

/// Mini-jeu du technicien : scan QR/NFC, choix de la pièce, réglage.
/// Retourne le message de fin, ou null si le joueur ferme la feuille.
Future<String?> showDiagnosticSheet(
  BuildContext context,
  GameState state,
  Equipment equipment,
) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => DiagnosticSheet(state: state, equipment: equipment),
  );
}

class DiagnosticSheet extends StatefulWidget {
  const DiagnosticSheet({super.key, required this.state, required this.equipment});

  final GameState state;
  final Equipment equipment;

  @override
  State<DiagnosticSheet> createState() => _DiagnosticSheetState();
}

class _DiagnosticSheetState extends State<DiagnosticSheet> {
  static const Duration _scanDuration = Duration(milliseconds: 1200);

  late final Fault _fault = faultOf(widget.equipment);
  late final List<String> _options = partOptionsFor(widget.equipment.type)..shuffle();
  final Set<String> _wrong = {};
  int _step = 0;
  double _scanProgress = 0;
  Timer? _scanTimer;
  late double _value;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Valeur de départ éloignée de la consigne.
    final rng = Random();
    final span = _fault.max - _fault.min;
    var start = _fault.min + rng.nextDouble() * span;
    if ((start - _fault.target).abs() < span * 0.2) {
      start = _fault.target > _fault.min + span / 2 ? _fault.min + span * 0.1 : _fault.max - span * 0.1;
    }
    _value = start;
    if (widget.state.has(Innovation.qrNfc)) _step = 1;
  }

  @override
  void dispose() {
    _scanTimer?.cancel();
    super.dispose();
  }

  void _startScan() {
    if (_scanTimer != null) return;
    const tick = Duration(milliseconds: 60);
    var elapsed = Duration.zero;
    _scanTimer = Timer.periodic(tick, (timer) {
      elapsed += tick;
      setState(() => _scanProgress = elapsed.inMilliseconds / _scanDuration.inMilliseconds);
      if (elapsed >= _scanDuration) {
        timer.cancel();
        _scanTimer = null;
        AudioService.instance.tap();
        setState(() => _step = 1);
      }
    });
  }

  void _choosePart(String part) {
    final ok = widget.state.submitDiagnosticPart(widget.equipment.id, part);
    if (ok) {
      AudioService.instance.tap();
      setState(() {
        _error = null;
        _step = 2;
      });
    } else {
      AudioService.instance.react(SignalType.alerte);
      setState(() {
        _wrong.add(part);
        _error = 'Mauvaise pièce : une pièce du stock est perdue. Réessayez.';
      });
    }
  }

  void _validateMeasure() {
    final message = widget.state.completeDiagnostic(
      widget.equipment.id,
      measureOk: _fault.isWithinTolerance(_value),
    );
    Navigator.of(context).pop(message);
  }

  String _format(double value) {
    final decimals = _fault.tolerance < 1 ? 1 : 0;
    return value.toStringAsFixed(decimals).replaceAll('.', ',');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Diagnostic · ${widget.equipment.name}', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('Étape ${_step + 1} / 3', style: theme.textTheme.labelMedium),
            const SizedBox(height: 16),
            ...switch (_step) {
              0 => _scanStep(theme),
              1 => _partStep(theme),
              _ => _measureStep(theme),
            },
          ],
        ),
      ),
    );
  }

  List<Widget> _scanStep(ThemeData theme) => [
        Text("Scannez le QR code de l'équipement pour ouvrir sa fiche.",
            style: theme.textTheme.bodyMedium),
        const SizedBox(height: 16),
        Icon(Icons.qr_code_2, size: 72, color: theme.colorScheme.primary),
        const SizedBox(height: 12),
        LinearProgressIndicator(value: _scanProgress.clamp(0.0, 1.0)),
        const SizedBox(height: 16),
        FilledButton.icon(
          icon: const Icon(Icons.qr_code_scanner),
          label: Text(_scanTimer == null ? 'Scanner' : 'Lecture…'),
          onPressed: _scanTimer == null ? _startScan : null,
        ),
      ];

  List<Widget> _partStep(ThemeData theme) => [
        Text('Symptôme constaté', style: theme.textTheme.labelMedium),
        const SizedBox(height: 4),
        Text(_fault.symptom, style: theme.textTheme.titleSmall),
        const SizedBox(height: 12),
        Text('Quelle pièce remplacez-vous ?', style: theme.textTheme.bodyMedium),
        const SizedBox(height: 8),
        for (final part in _options)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: OutlinedButton(
              onPressed: _wrong.contains(part) ? null : () => _choosePart(part),
              child: Text(part),
            ),
          ),
        if (_error != null)
          Text(_error!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
      ];

  List<Widget> _measureStep(ThemeData theme) {
    final ok = _fault.isWithinTolerance(_value);
    return [
      Text('Réglage final', style: theme.textTheme.labelMedium),
      const SizedBox(height: 4),
      Text(
        '${_fault.measureLabel} : consigne ${_format(_fault.target)} ${_fault.unit} '
        '(± ${_format(_fault.tolerance)})',
        style: theme.textTheme.titleSmall,
      ),
      const SizedBox(height: 16),
      Center(
        child: Text(
          '${_format(_value)} ${_fault.unit}',
          style: theme.textTheme.headlineMedium?.copyWith(
            color: ok ? const Color(0xFF0F6E56) : theme.colorScheme.onSurface,
          ),
        ),
      ),
      Slider(
        value: _value.clamp(_fault.min, _fault.max),
        min: _fault.min,
        max: _fault.max,
        onChanged: (value) => setState(() => _value = value),
      ),
      const SizedBox(height: 8),
      FilledButton.icon(
        icon: Icon(ok ? Icons.check_circle : Icons.tune),
        label: Text(ok ? 'Valider le réglage' : 'Valider quand même'),
        onPressed: _validateMeasure,
      ),
    ];
  }
}
