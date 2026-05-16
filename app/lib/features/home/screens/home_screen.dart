import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/router/app_router.dart';
import '../../battle/screens/battle_screen.dart';
import '../../auth/providers/auth_provider.dart';
import '../../pets/providers/player_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Redirect new players (no pets yet) to the starter pack screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final player = ref.read(playerProvider);
      if (player.roster.isEmpty && mounted) {
        context.go(Routes.starterPack);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final player = ref.watch(playerProvider);
    final userId = ref.watch(userIdProvider) ?? '—';
    final userEmail = ref.watch(userEmailProvider) ?? '—';

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Left panel: branding ────────────────────────────────────────
            SizedBox(
              width: 240,
              child: Container(
                decoration: const BoxDecoration(
                  border: Border(right: BorderSide(color: Color(0xFF1A1F35))),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Likha Pet',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
                          ),
                          const Text(
                            'Filipino-inspired Pet Strategy',
                            style: TextStyle(
                              color: AppColors.secondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.divider),
                            ),
                            child: Text(
                              'Phase 2  ·  ${player.roster.length} pets',
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 10,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1, color: Color(0xFF1A1F35)),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: Text(
                            'Use the main menu to manage your roster and start battles.',
                            style: TextStyle(
                              color: AppColors.textMuted.withValues(alpha: 0.9),
                              fontSize: 11,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Right panel: scrollable menu buttons ───────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                kDebugMode ? 'Profile (Debug)' : 'Profile',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _handleLogout,
                              icon: const Icon(
                                Icons.logout,
                                size: 14,
                                color: AppColors.textMuted,
                              ),
                              label: const Text(
                                'Logout',
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: TextButton.styleFrom(
                                minimumSize: const Size(0, 28),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          userEmail,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        SelectableText(
                          'UID: $userId',
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 10,
                          ),
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Main Menu',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _MenuButton(
                    icon: '🐾',
                    label: 'My Pets',
                    subtitle: 'Roster · Team builder',
                    color: const Color(0xFF9C27B0),
                    onTap: () => context.push(Routes.roster),
                  ),
                  const SizedBox(height: 8),
                  _MenuButton(
                    icon: '🤺',
                    label: 'Arena (PvP)',
                    subtitle: 'Real-time · MMR ladder',
                    color: const Color(0xFFEF5350),
                    onTap: () => context.push(Routes.pvpQueue),
                  ),
                  const SizedBox(height: 8),
                  _MenuButton(
                    icon: '⚔',
                    label: 'Quick Battle (PvE)',
                    subtitle: player.hasFullTeam
                        ? 'My Team  vs  Rivals'
                        : 'Set up a team first',
                    color:
                        player.hasFullTeam ? AppColors.primary : Colors.white24,
                    onTap: player.hasFullTeam
                        ? () => context.push(
                              Routes.battle,
                              extra: const BattleScreenArgs(
                                playerTeamName: 'My Team',
                                enemyTeamName: 'Rivals',
                              ),
                            )
                        : () => context.go(Routes.roster),
                  ),
                  const SizedBox(height: 8),
                  _MenuButton(
                    icon: '🗺',
                    label: 'Adventure Mode',
                    subtitle: 'PvE stages — Coming soon',
                    color: AppColors.accent,
                    onTap: () => context.push(Routes.worldMap),
                  ),
                  const SizedBox(height: 8),
                  _MenuButton(
                    icon: '📖',
                    label: 'Library',
                    subtitle: 'Parts · Classes · Skills',
                    color: const Color(0xFF26C6DA),
                    onTap: () => context.push(Routes.library),
                  ),
                  const SizedBox(height: 8),
                  if (kDebugMode)
                    _MenuButton(
                      icon: '🧪',
                      label: 'Test Battle Lab',
                      subtitle: 'Debug traits, body parts & animations',
                      color: const Color(0xFF7C3AED),
                      onTap: () => context.go(Routes.testBattle),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleLogout() async {
    await ref.read(authProvider.notifier).logout();
    if (!mounted) return;
    context.go(Routes.login);
  }
}

class _MenuButton extends StatelessWidget {
  final String icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _MenuButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(icon, style: const TextStyle(fontSize: 20)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right,
                  color: AppColors.textMuted, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
