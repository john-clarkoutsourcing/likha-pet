import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../../battle/providers/battle_view_model.dart' show PvpMatchEndData;
import '../models/pvp_battle_result.dart';

class PvpResultArgs {
  final PvpMatchEndData result;
  final String opponentName;
  final String? opponentId;
  const PvpResultArgs({
    required this.result,
    required this.opponentName,
    this.opponentId,
  });
}

class EnhancedPvpResultScreen extends ConsumerWidget {
  final PvpResultArgs args;
  const EnhancedPvpResultScreen({super.key, required this.args});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myUserId = ref.watch(userIdProvider);
    final result = args.result;

    final isWin = !result.dispute && result.winnerUid == myUserId;
    final isLoss = !result.dispute && result.winnerUid != null && result.winnerUid != myUserId;
    final isDraw = result.dispute || result.winnerUid == null;

    // For now, assume battle is accepted (server would provide validation status)
    // TODO: Replace with actual validation status from server
    final validationStatus = isDraw ? ValidationStatus.pending : ValidationStatus.accepted;

    final battleResult = PvpBattleResult(
      isWin: isWin,
      isDraw: isDraw,
      isLoss: isLoss,
      opponentName: args.opponentName,
      opponentId: args.opponentId,
      validationStatus: validationStatus,
      mmrChange: result.mmrDelta,
      battleDurationMs: 0, // Would come from battle engine
      finalPlayerHp: 0, // Would come from final team state
      finalOpponentHp: 0, // Would come from final team state
    );

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 16),

                // ── Battle Outcome ────────────────────────────────────────
                _buildBattleOutcome(battleResult),

                const SizedBox(height: 32),

                // ── Validation Status Badge ───────────────────────────────
                _buildValidationStatus(battleResult),

                const SizedBox(height: 32),

                // ── MMR Change Card ───────────────────────────────────────
                if (battleResult.validationStatus != ValidationStatus.pending)
                  _buildMmrCard(battleResult)
                else
                  _buildValidatingCard(),

                const SizedBox(height: 24),

                // ── Help Message ──────────────────────────────────────────
                if (battleResult.validationStatus != ValidationStatus.accepted)
                  _buildHelpMessage(battleResult),

                const SizedBox(height: 40),

                // ── Action Buttons ────────────────────────────────────────
                _buildActionButtons(context, battleResult),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Helper Builders ────────────────────────────────────────────────────

  Widget _buildBattleOutcome(PvpBattleResult result) {
    final label = result.isDraw
        ? 'DRAW'
        : result.isWin
            ? 'VICTORY!'
            : 'DEFEAT';

    final color = result.isDraw
        ? AppColors.secondary
        : result.isWin
            ? const Color(0xFF4CAF50)
            : Colors.redAccent;

    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 48,
            fontWeight: FontWeight.bold,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'vs ${result.opponentName}',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 16),
        ),
      ],
    );
  }

  Widget _buildValidationStatus(PvpBattleResult result) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: result.validationStatusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: result.validationStatusColor,
          width: 2,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            result.validationStatusIcon,
            color: result.validationStatusColor,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              result.validationStatusText,
              style: TextStyle(
                color: result.validationStatusColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMmrCard(PvpBattleResult result) {
    final isPositive = result.mmrChange >= 0;
    final mmrText = isPositive ? '+${result.mmrChange}' : '${result.mmrChange}';
    final mmrColor = isPositive ? const Color(0xFF4CAF50) : Colors.redAccent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          const Text(
            'MMR Change',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$mmrText MMR',
            style: TextStyle(
              color: mmrColor,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildValidatingCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber),
      ),
      child: Column(
        children: [
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Validating your battle...',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'This may take a few seconds',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildHelpMessage(PvpBattleResult result) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: result.validationStatusColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: result.validationStatusColor.withOpacity(0.3),
        ),
      ),
      child: Text(
        result.helpMessage,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 13,
          height: 1.6,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, PvpBattleResult result) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => context.go(Routes.home),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.surface,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text(
              'Back to Home',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 15),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Optional: Add "View Battle Replay" or "Queue Again" buttons
        if (result.validationStatus == ValidationStatus.accepted)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                // TODO: Implement queue again
                context.go(Routes.pvpQueue);
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text(
                'Queue Again',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 15),
              ),
            ),
          ),
      ],
    );
  }
}
