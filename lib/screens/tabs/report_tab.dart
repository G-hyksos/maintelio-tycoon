import 'package:flutter/material.dart';

import '../../models/achievement.dart';
import '../../models/contract.dart';
import '../../models/game_state.dart';
import '../../models/site.dart';
import '../../services/leaderboard_service.dart';
import '../../services/save_service.dart';
import '../../utils/format.dart';

class ReportTab extends StatelessWidget {
  const ReportTab({super.key, required this.state, required this.onMessage});

  final GameState state;
  final void Function(String message) onMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dayInMonth = state.dayIndex % GameState.daysPerMonth + 1;
    final info = state.info;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Mois ${state.month} · jour $dayInMonth / ${GameState.daysPerMonth}',
            style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 2.4,
          children: [
            _Kpi('Health score', '${state.healthScore.round()} / 100'),
            _Kpi('Disponibilité', '${state.availability.round()} %'),
            _Kpi('Satisfaction', '${state.satisfaction.round()} %'),
            _Kpi('Réponse moyenne',
                state.responseCount == 0 ? '—' : '${state.averageResponse.round()} s'),
            _Kpi('Interventions', '${state.interventions}'),
            _Kpi('Score classement', '${state.leaderboardScore}'),
          ],
        ),
        const SizedBox(height: 16),
        _Section(
          title: info.canUpgradeContract ? 'Portefeuille de sites' : 'Contrat',
          children: [
            Text(
              info.canUpgradeContract
                  ? 'Signez le contrat suivant avec un health score de 70 ou plus au dernier rapport.'
                  : 'Un score de site de 80 ou plus en fin de mois fait évoluer le contrat. Sous 35, il est rétrogradé.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            for (final site in state.sites) _SiteRow(state: state, site: site, onMessage: onMessage),
            if (info.canUpgradeContract && state.nextSiteType != null) ...[
              const SizedBox(height: 8),
              FilledButton.icon(
                icon: Icon(state.nextSiteType!.icon),
                label: Text(
                    'Ouvrir ${state.nextSiteType!.defaultName} (${formatMoney(Site.openingCost)})'),
                onPressed: () => onMessage(state.openSite()),
              ),
            ],
          ],
        ),
        if (state.reports.isNotEmpty)
          _Section(
            title: 'Rapports mensuels',
            children: [
              for (final report in state.reports.reversed) _ReportRow(report),
            ],
          ),
        _Section(
          title: 'Succès · ${state.achievements.length} / ${Achievement.values.length}',
          children: [
            for (final achievement in Achievement.values)
              _AchievementRow(
                achievement: achievement,
                unlocked: state.achievements.contains(achievement),
              ),
          ],
        ),
        _LeaderboardSection(
          key: const ValueKey('leaderboard'),
          state: state,
          onMessage: onMessage,
        ),
        _Section(
          title: 'Journal',
          children: [
            for (final entry in state.journal.reversed.take(15))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text(entry, style: theme.textTheme.bodySmall),
              ),
          ],
        ),
      ],
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: theme.textTheme.labelSmall),
          const SizedBox(height: 2),
          Text(value, style: theme.textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

class _SiteRow extends StatelessWidget {
  const _SiteRow({required this.state, required this.site, required this.onMessage});

  final GameState state;
  final Site site;
  final void Function(String message) onMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tier = state.tierOf(site);
    final next = state.nextTierOf(site);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(site.type.icon, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(child: Text(site.name, style: theme.textTheme.titleSmall)),
              Text('${state.siteHealthScore(site).round()}', style: theme.textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${site.type.label} · contrat ${tier.name} · ${formatMoney(tier.dailyRevenue)} / jour\n'
            'Satisfaction ${site.satisfaction.round()} % · dispo ${site.availability.round()} %\n'
            '${site.type.constraint}',
            style: theme.textTheme.bodySmall,
          ),
          if (state.info.canUpgradeContract && next != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.trending_up, size: 18),
                label: Text('Signer ${next.name} (${formatMoney(next.upgradeCost)})'),
                onPressed: () => onMessage(state.upgradeContract(site.id)),
              ),
            ),
        ],
      ),
    );
  }
}

class _ReportRow extends StatelessWidget {
  const _ReportRow(this.report);

  final MonthReport report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final score = report.healthScore.round();
    final color = score >= 80
        ? const Color(0xFF0F6E56)
        : score >= 35
            ? const Color(0xFF854F0B)
            : const Color(0xFFA32D2D);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Mois ${report.month} · dispo ${report.availability.round()} % · '
              '${report.interventions} interv.',
              style: theme.textTheme.bodySmall,
            ),
          ),
          Text('$score', style: theme.textTheme.titleSmall?.copyWith(color: color)),
        ],
      ),
    );
  }
}

class _AchievementRow extends StatelessWidget {
  const _AchievementRow({required this.achievement, required this.unlocked});

  final Achievement achievement;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = unlocked ? const Color(0xFFBA7517) : theme.colorScheme.outlineVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(achievement.icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(achievement.label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: unlocked ? null : theme.colorScheme.outline,
                    )),
                Text(achievement.description, style: theme.textTheme.labelSmall),
              ],
            ),
          ),
          if (unlocked) const Icon(Icons.check_circle, size: 18, color: Color(0xFF1D9E75)),
        ],
      ),
    );
  }
}

class _LeaderboardSection extends StatefulWidget {
  const _LeaderboardSection({super.key, required this.state, required this.onMessage});

  final GameState state;
  final void Function(String message) onMessage;

  @override
  State<_LeaderboardSection> createState() => _LeaderboardSectionState();
}

class _LeaderboardSectionState extends State<_LeaderboardSection> {
  final LeaderboardService _service = LeaderboardService();
  final SaveService _save = SaveService();
  final TextEditingController _pseudo = TextEditingController();
  List<LeaderboardEntry> _entries = const [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _save.pseudo().then((value) {
      if (mounted && value != null) _pseudo.text = value;
    });
    if (_service.configured) _refresh();
  }

  @override
  void dispose() {
    _pseudo.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final entries = await _service.top(widget.state.role);
      if (mounted) setState(() => _entries = entries);
    } on LeaderboardException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    final pseudo = _pseudo.text.trim();
    if (pseudo.length < 3 || pseudo.length > 20) {
      setState(() => _error = 'Choisissez un pseudo de 3 à 20 caractères.');
      return;
    }
    await _save.setPseudo(pseudo);
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _service.submit(
        deviceId: await _save.deviceId(),
        pseudo: pseudo,
        role: widget.state.role,
        score: widget.state.leaderboardScore,
      );
      widget.onMessage('Score envoyé');
      await _refresh();
    } on LeaderboardException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _Section(
      title: 'Classement · ${widget.state.info.label}',
      children: [
        if (!_service.configured)
          Text(
            'Classement en ligne non configuré pour cette version.',
            style: theme.textTheme.bodySmall,
          )
        else ...[
          TextField(
            controller: _pseudo,
            maxLength: 20,
            decoration: const InputDecoration(
              labelText: 'Pseudo',
              hintText: 'TechnoPierre',
              isDense: true,
            ),
          ),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.upload),
                  label: Text('Envoyer ${widget.state.leaderboardScore} pts'),
                  onPressed: _loading ? null : _submit,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Actualiser',
                icon: const Icon(Icons.refresh),
                onPressed: _loading ? null : _refresh,
              ),
            ],
          ),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(_error!,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
            ),
          const SizedBox(height: 6),
          for (var i = 0; i < _entries.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  SizedBox(width: 28, child: Text('${i + 1}.', style: theme.textTheme.labelMedium)),
                  Expanded(child: Text(_entries[i].pseudo, style: theme.textTheme.bodyMedium)),
                  Text('${_entries[i].score}', style: theme.textTheme.titleSmall),
                ],
              ),
            ),
        ],
      ],
    );
  }
}
