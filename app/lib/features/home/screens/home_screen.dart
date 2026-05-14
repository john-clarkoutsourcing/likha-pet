import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/router/app_router.dart';
import '../../battle/screens/battle_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),

              // ── Title ──────────────────────────────────────────────────────
              const Text(
                'Likha Pet',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
              const Text(
                'Filipino-inspired AI Pet Strategy',
                style: TextStyle(
                  color: AppColors.secondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 48),

              // ── Menu ───────────────────────────────────────────────────────
              _MenuButton(
                icon: '⚔',
                label: 'Quick Battle (PvE)',
                subtitle: 'Team Bayani vs Team Diwata',
                color: AppColors.primary,
                onTap: () => context.go(
                  Routes.battle,
                  extra: const BattleScreenArgs(
                    playerTeamName: 'Team Bayani',
                    enemyTeamName: 'Team Diwata',
                  ),
                ),
              ),
              const SizedBox(height: 12),

              _MenuButton(
                icon: '🗺',
                label: 'Adventure Mode',
                subtitle: 'PvE stages — Coming soon',
                color: AppColors.accent,
                onTap: () => context.go(Routes.worldMap),
              ),
              const SizedBox(height: 12),

              _MenuButton(
                icon: '🏆',
                label: 'PvP Arena',
                subtitle: 'Real-time battles — Phase 2',
                color: AppColors.secondary,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('PvP coming in Phase 2 (Firebase)'),
                      backgroundColor: AppColors.surface,
                    ),
                  );
                },
              ),
              const Spacer(),

              // ── Phase label ────────────────────────────────────────────────
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: const Text(
                    'Phase 1  —  Offline Battle Engine',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
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
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(icon, style: const TextStyle(fontSize: 24)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right,
                  color: AppColors.textMuted, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
