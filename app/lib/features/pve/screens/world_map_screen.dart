import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../pets/providers/player_provider.dart';
import '../data/stage_registry.dart';

class WorldMapScreen extends ConsumerWidget {
  const WorldMapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);
    final completed = player.completedStages.length;
    final total     = kStageRegistry.length;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Left info panel ────────────────────────────────────────────────
            SizedBox(
              width: 180,
              child: Container(
                decoration: const BoxDecoration(
                  border: Border(right: BorderSide(color: Color(0xFF1A1F35))),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Back
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: const Row(children: [
                        Icon(Icons.arrow_back_ios,
                            color: Colors.white38, size: 14),
                        Text(' Back',
                            style: TextStyle(
                                color: Colors.white38, fontSize: 12)),
                      ]),
                    ),
                    const SizedBox(height: 20),

                    Text('Adventure',
                        style: GoogleFonts.rajdhani(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w900)),
                    Text('PvE Stages',
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 12)),

                    const SizedBox(height: 20),

                    // Progress
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('$completed / $total',
                            style: GoogleFonts.rajdhani(
                                color: AppColors.primary,
                                fontSize: 22,
                                fontWeight: FontWeight.w900)),
                        const Text('Stages',
                            style: TextStyle(
                                color: Colors.white38, fontSize: 11)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: total == 0 ? 0 : completed / total,
                        backgroundColor: Colors.white12,
                        valueColor: const AlwaysStoppedAnimation(
                            AppColors.primary),
                        minHeight: 6,
                      ),
                    ),

                    const SizedBox(height: 20),
                    const Divider(color: Color(0xFF1A1F35)),
                    const SizedBox(height: 12),

                    // Crystals earned
                    const Text('CRYSTALS EARNED',
                        style: TextStyle(
                            color: Colors.white24,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1)),
                    const SizedBox(height: 4),
                    Text('💎 ${player.soulCrystals}',
                        style: GoogleFonts.rajdhani(
                            color: const Color(0xFF44BBFF),
                            fontSize: 18,
                            fontWeight: FontWeight.w800)),

                    const Spacer(),

                    if (!player.hasFullTeam)
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.orangeAccent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: Colors.orangeAccent.withValues(
                                  alpha: 0.3)),
                        ),
                        child: const Text(
                          '⚠ Set a team of 3 in My Pets first',
                          style: TextStyle(
                              color: Colors.orangeAccent, fontSize: 10),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // ── Stage list ─────────────────────────────────────────────────────
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: kStageRegistry.length,
                itemBuilder: (_, i) {
                  final stage    = kStageRegistry[i];
                  final done     = player.isStageCompleted(stage.id);
                  final unlocked = i == 0 ||
                      player.isStageCompleted(kStageRegistry[i - 1].id);
                  final isCurrent = !done && unlocked;

                  return _StageCard(
                    stage:     stage,
                    done:      done,
                    unlocked:  unlocked,
                    isCurrent: isCurrent,
                    onTap:     unlocked
                        ? () => context.push(
                            Routes.stagePreview
                                .replaceFirst(':stageId', stage.id))
                        : null,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Stage card ────────────────────────────────────────────────────────────────

class _StageCard extends StatelessWidget {
  final StageConfig stage;
  final bool done, unlocked, isCurrent;
  final VoidCallback? onTap;
  const _StageCard({
    required this.stage, required this.done,
    required this.unlocked, required this.isCurrent, this.onTap,
  });

  static Color _diffColor(String d) => switch (d) {
    'Beginner' => const Color(0xFF44FF88),
    'Easy'     => const Color(0xFF88CCFF),
    'Medium'   => const Color(0xFFFFCC44),
    'Hard'     => const Color(0xFFFF8844),
    _          => const Color(0xFFFF4444),
  };

  @override
  Widget build(BuildContext context) {
    final locked      = !unlocked;
    final accentColor = done
        ? const Color(0xFF44FF88)
        : isCurrent ? AppColors.primary : Colors.white24;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: locked
                  ? const Color(0xFF0A0F18)
                  : const Color(0xFF111A28),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isCurrent
                    ? AppColors.primary.withValues(alpha: 0.6)
                    : accentColor.withValues(alpha: 0.2),
                width: isCurrent ? 1.5 : 1,
              ),
              boxShadow: isCurrent
                  ? [BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      blurRadius: 8)]
                  : null,
            ),
            child: Row(children: [
              // Icon
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: locked
                      ? Colors.white.withValues(alpha: 0.04)
                      : accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: locked
                          ? Colors.white12
                          : accentColor.withValues(alpha: 0.3)),
                ),
                child: Center(
                  child: Text(locked ? '🔒' : stage.emoji,
                      style: const TextStyle(fontSize: 20))),
              ),
              const SizedBox(width: 12),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text('Stage ${stage.id}',
                          style: TextStyle(
                              color: locked
                                  ? Colors.white24
                                  : Colors.white38,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1)),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: _diffColor(stage.difficultyLabel)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(stage.difficultyLabel,
                            style: TextStyle(
                                color: locked
                                    ? Colors.white24
                                    : _diffColor(stage.difficultyLabel),
                                fontSize: 7,
                                fontWeight: FontWeight.w800)),
                      ),
                    ]),
                    const SizedBox(height: 2),
                    Text(stage.name,
                        style: GoogleFonts.rajdhani(
                            color: locked
                                ? Colors.white24
                                : Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w800)),
                    Text(stage.description,
                        style: TextStyle(
                            color: locked
                                ? Colors.white12
                                : Colors.white38,
                            fontSize: 10),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),

              // Status + reward
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (done)
                    const Icon(Icons.check_circle,
                        color: Color(0xFF44FF88), size: 18)
                  else if (isCurrent)
                    const Icon(Icons.play_circle_fill,
                        color: AppColors.primary, size: 18)
                  else if (locked)
                    const Icon(Icons.lock_outline,
                        color: Colors.white24, size: 16),
                  const SizedBox(height: 4),
                  Text('💎 ${stage.crystalReward}',
                      style: TextStyle(
                          color: locked
                              ? Colors.white24
                              : done
                                  ? Colors.white38
                                  : const Color(0xFF44BBFF),
                          fontSize: 10,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
