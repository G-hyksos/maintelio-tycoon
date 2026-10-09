import 'package:flutter/material.dart';

import '../models/game_state.dart';
import '../models/role.dart';
import '../services/save_service.dart';
import '../widgets/role_portrait.dart';
import 'game_screen.dart';

class RoleSelectScreen extends StatefulWidget {
  const RoleSelectScreen({super.key, required this.firstLaunch});

  final bool firstLaunch;

  @override
  State<RoleSelectScreen> createState() => _RoleSelectScreenState();
}

class _RoleSelectScreenState extends State<RoleSelectScreen> {
  final SaveService _save = SaveService();
  Set<PlayerRole> _saved = {};
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    _save.savedRoles().then((roles) {
      if (mounted) setState(() => _saved = roles);
    });
  }

  Future<void> _open(PlayerRole role) async {
    if (_opening) return;
    setState(() => _opening = true);
    final state = await _save.load(role) ?? GameState.newGame(role);
    await _save.setLastRole(role);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => GameScreen(state: state)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
          children: [
            Text(
              widget.firstLaunch ? 'Bienvenue sur Maintelio Tycoon' : 'Changer de rôle',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 6),
            Text(
              'Choisissez votre rôle. Chaque rôle a sa propre partie et ses propres objectifs.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            for (final info in allRoles)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _RoleCard(
                  info: info,
                  inProgress: _saved.contains(info.role),
                  onTap: _opening ? null : () => _open(info.role),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({required this.info, required this.inProgress, this.onTap});

  final RoleInfo info;
  final bool inProgress;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RolePortrait(role: info.role, size: 56),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(info.label, style: theme.textTheme.titleMedium),
                        ),
                        if (inProgress)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: scheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'En cours',
                              style: theme.textTheme.labelSmall
                                  ?.copyWith(color: scheme.onSecondaryContainer),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(info.description, style: theme.textTheme.bodySmall),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.flag_outlined, size: 16, color: scheme.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            info.objective,
                            style: theme.textTheme.labelMedium
                                ?.copyWith(color: scheme.primary),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
