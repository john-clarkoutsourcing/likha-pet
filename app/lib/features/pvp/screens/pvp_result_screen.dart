import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../../battle/providers/battle_view_model.dart' show PvpMatchEndData;

class PvpResultArgs {
  final PvpMatchEndData result;
  final String opponentName;
  const PvpResultArgs({required this.result, required this.opponentName});
}

class PvpResultScreen extends ConsumerWidget {
  final PvpResultArgs args;
  const PvpResultScreen({super.key, required this.args});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myUserId = ref.watch(userIdProvider);
    final result   = args.result;

    final isWin    = !result.dispute && result.winnerUid == myUserId;
    final isLoss   = !result.dispute && result.winnerUid != null && result.winnerUid != myUserId;
    final isDraw   = result.dispute || result.winnerUid == null;

    final label = isDraw  ? 'DRAW'
                : isWin   ? 'VICTORY!'
                :           'DEFEAT';

    final color = isDraw  ? AppColors.secondary
                : isWin   ? const Color(0xFF4CAF50)
                :           Colors.redAccent;

    final mmrText = result.mmrDelta == 0
        ? 'No MMR change'
        : result.mmrDelta > 0
            ? '+${result.mmrDelta} MMR'
            : '${result.mmrDelta} MMR';

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label,
                    style: TextStyle(
                      color: color,
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 3,
                    )),
                const SizedBox(height: 8),
                Text('vs ${args.opponentName}',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 16)),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Text(mmrText,
                      style: TextStyle(
                        color: result.mmrDelta >= 0 ? const Color(0xFF4CAF50) : Colors.redAccent,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      )),
                ),
                if (isDraw) ...[
                  const SizedBox(height: 12),
                  const Text('Result disputed — no MMR change.',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                      textAlign: TextAlign.center),
                ],
                const SizedBox(height: 48),
                ElevatedButton(
                  onPressed: () => context.go(Routes.home),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.surface,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Back to Home',
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 15)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
