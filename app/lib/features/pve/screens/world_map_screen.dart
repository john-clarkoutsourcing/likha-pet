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

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(children: [
          // ── Header ──────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 16, 4),
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white70),
                onPressed: () => context.pop(),
              ),
              Text('Adventure',
                style: GoogleFonts.rajdhani(
                  color: Colors.white, fontSize: 22,
                  fontWeight: FontWeight.w800)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A2535),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: Text(
                  '${player.completedStages.length} / ${kStageRegistry.length} Stages',
                  style: const TextStyle(
                    color: Colors.white70, fontSize: 11,
                    fontWeight: FontWeight.w700)),
              ),
            ]),
          ),

          // Progress bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: kStageRegistry.isEmpty
                    ? 0
                    : player.completedStages.length / kStageRegistry.length,
                backgroundColor: Colors.white12,
                valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                minHeight: 4,
              ),
            ),
          ),

          // ── Stage list ───────────────────────────────────────────────────────
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
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
                  onTap: unlocked
                      ? () => context.push(Routes.stagePreview
                          .replaceFirst(':stageId', stage.id))
                      : null,
                );
              },
            ),
          ),
        ]),
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
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: locked ? const Color(0xFF0A0F18) : const Color(0xFF111A28),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isCurrent
                    ? AppColors.primary.withValues(alpha: 0.6)
                    : accentColor.withValues(alpha: 0.25),
                width: isCurrent ? 1.5 : 1,
              ),
              boxShadow: isCurrent ? [
                BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    blurRadius: 12),
              ] : null,
            ),
            child: Row(children: [
              // Emoji / lock
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: locked
                      ? Colors.white.withValues(alpha: 0.04)
                      : accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: locked
                          ? Colors.white12
                          : accentColor.withValues(alpha: 0.3)),
                ),
                child: Center(
                  child: Text(locked ? '🔒' : stage.emoji,
                      style: const TextStyle(fontSize: 24))),
              ),
              const SizedBox(width: 14),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text('Stage ${stage.id}',
                        style: TextStyle(
                          color: locked ? Colors.white24 : Colors.white54,
                          fontSize: 10, fontWeight: FontWeight.w700,
                          letterSpacing: 1)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: _diffColor(stage.difficultyLabel)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(stage.difficultyLabel,
                          style: TextStyle(
                            color: locked
                                ? Colors.white24
                                : _diffColor(stage.difficultyLabel),
                            fontSize: 8, fontWeight: FontWeight.w800)),
                      ),
                    ]),
                    const SizedBox(height: 3),
                    Text(stage.name,
                      style: GoogleFonts.rajdhani(
                        color: locked ? Colors.white24 : Colors.white,
                        fontSize: 16, fontWeight: FontWeight.w800)),
                    Text(stage.description,
                      style: TextStyle(
                        color: locked ? Colors.white12 : Colors.white38,
                        fontSize: 11),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),

              // Status + reward
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (done)
                    const Icon(Icons.check_circle,
                        color: Color(0xFF44FF88), size: 22)
                  else if (isCurrent)
                    const Icon(Icons.play_circle_fill,
                        color: AppColors.primary, size: 22)
                  else if (locked)
                    const Icon(Icons.lock_outline,
                        color: Colors.white24, size: 18),
                  const SizedBox(height: 4),
                  Text('💎 ${stage.crystalReward}',
                    style: TextStyle(
                      color: locked
                          ? Colors.white24
                          : done
                              ? Colors.white38
                              : const Color(0xFF44BBFF),
                      fontSize: 11, fontWeight: FontWeight.w700)),
                ],
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
