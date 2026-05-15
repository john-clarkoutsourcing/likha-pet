import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/router/app_router.dart';
import 'battle_screen.dart';

class BattleResultArgs {
  final String outcome;     // 'teamAWins' | 'teamBWins' | 'draw'
  final int totalRounds;
  final String playerTeamName;
  final String enemyTeamName;

  const BattleResultArgs({
    required this.outcome,
    required this.totalRounds,
    required this.playerTeamName,
    required this.enemyTeamName,
  });
}

class BattleResultScreen extends StatelessWidget {
  final BattleResultArgs args;
  const BattleResultScreen({super.key, required this.args});

  @override
  Widget build(BuildContext context) {
    final playerWon = args.outcome == 'teamAWins';
    final isDraw = args.outcome == 'draw';

    final emoji  = isDraw ? '🤝' : (playerWon ? '🏆' : '💀');
    final title  = isDraw ? 'DRAW' : (playerWon ? 'VICTORY!' : 'DEFEAT');
    final color  = isDraw
        ? AppColors.textSecondary
        : (playerWon ? AppColors.secondary : AppColors.hpRed);
    final winner = isDraw
        ? 'No winner'
        : (playerWon ? args.playerTeamName : args.enemyTeamName);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 16),
              Text(emoji, style: const TextStyle(fontSize: 72)),
              const SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                winner,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 32),
              _StatRow(label: 'Rounds fought', value: '${args.totalRounds}'),
              const SizedBox(height: 8),
              _StatRow(label: 'Your team', value: args.playerTeamName),
              const SizedBox(height: 8),
              _StatRow(label: 'Enemy team', value: args.enemyTeamName),
              const SizedBox(height: 32),

              // Buttons
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => context.go(Routes.battle,
                      extra: const BattleScreenArgs()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    '⚔  Battle Again',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => context.go(Routes.home),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.divider),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    'Home',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  const _StatRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 14)),
        const Spacer(),
        Text(value,
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600)),
      ],
    );
  }
}

