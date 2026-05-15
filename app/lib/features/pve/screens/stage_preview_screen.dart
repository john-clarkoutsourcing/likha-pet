import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:likha_pet_battle_engine/trait.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../battle/data/creature_registry.dart';
import '../../battle/screens/battle_screen.dart';
import '../../pets/providers/player_provider.dart';
import '../data/stage_registry.dart';

Color _clsColor(String cls) => switch (cls) {
  'plant'   => const Color(0xFF4CAF50),
  'aquatic' => const Color(0xFF29B6F6),
  'beast'   => const Color(0xFFFF9800),
  'reptile' => const Color(0xFF66BB6A),
  'bird'    => const Color(0xFFFF80AB),
  'bug'     => const Color(0xFFFF5252),
  _         => const Color(0xFF9C27B0),
};

class StagePreviewScreen extends ConsumerWidget {
  final String stageId;
  const StagePreviewScreen({super.key, required this.stageId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stage  = stageById(stageId);
    final player = ref.watch(playerProvider);

    if (stage == null) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(
          child: Text('Stage not found',
              style: const TextStyle(color: Colors.white54))),
      );
    }

    final done = player.isStageCompleted(stageId);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Back + header ──────────────────────────────────────────────
              Row(children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white70),
                  onPressed: () => context.pop(),
                  padding: EdgeInsets.zero,
                ),
                const SizedBox(width: 4),
                Text(stage.emoji, style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Stage ${stage.id}  ·  ${stage.difficultyLabel}',
                        style: const TextStyle(
                          color: Colors.white38, fontSize: 11,
                          fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                      Text(stage.name,
                        style: GoogleFonts.rajdhani(
                          color: Colors.white, fontSize: 22,
                          fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
                if (done)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF44FF88).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: const Color(0xFF44FF88).withValues(alpha: 0.4)),
                    ),
                    child: const Text('✓ Cleared',
                      style: TextStyle(
                        color: Color(0xFF44FF88), fontSize: 11,
                        fontWeight: FontWeight.w800)),
                  ),
              ]),

              const SizedBox(height: 8),
              Text(stage.description,
                style: const TextStyle(color: Colors.white54, fontSize: 13,
                    height: 1.4)),

              const SizedBox(height: 20),

              // ── Reward ─────────────────────────────────────────────────────
              _SectionLabel('REWARD'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A2535),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(children: [
                  const Text('💎', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Text('${stage.crystalReward} Soul Crystals',
                    style: GoogleFonts.rajdhani(
                      color: const Color(0xFF44BBFF),
                      fontSize: 16, fontWeight: FontWeight.w800)),
                  const Spacer(),
                  if (done)
                    const Text('Already claimed',
                      style: TextStyle(color: Colors.white38, fontSize: 11)),
                ]),
              ),

              const SizedBox(height: 20),

              // ── Enemy team ─────────────────────────────────────────────────
              _SectionLabel('ENEMY TEAM'),
              const SizedBox(height: 8),
              ...stage.enemyDefs.map((def) => _EnemyRow(def: def)),

              const SizedBox(height: 20),

              // ── Your team ──────────────────────────────────────────────────
              _SectionLabel('YOUR TEAM'),
              const SizedBox(height: 8),
              if (!player.hasFullTeam)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orangeAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: Colors.orangeAccent.withValues(alpha: 0.3)),
                  ),
                  child: const Text(
                    '⚠ Set up a team of 3 pets before battling',
                    style: TextStyle(color: Colors.orangeAccent, fontSize: 12)),
                )
              else
                ...player.activeRoster.map((pet) {
                  final body  = kBodyCatalogue[pet.bodyId];
                  final cls   = body?.className ?? 'beast';
                  final color = _clsColor(cls);
                  final stats = pet.toCreatureDefinition().computedStats;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: color.withValues(alpha: 0.25)),
                      ),
                      child: Row(children: [
                        Image.asset(
                          'assets/images/icons/mini-$cls.png',
                          width: 28, height: 28,
                          errorBuilder: (_, __, ___) =>
                              Icon(Icons.pets, size: 22, color: color)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(pet.name,
                            style: GoogleFonts.rajdhani(
                              color: Colors.white, fontSize: 14,
                              fontWeight: FontWeight.w700)),
                        ),
                        Text('❤ ${stats.hp}  ⚡ ${stats.speed}',
                          style: const TextStyle(
                            color: Colors.white38, fontSize: 11)),
                      ]),
                    ),
                  );
                }),

              const SizedBox(height: 28),

              // ── Battle button ──────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: player.hasFullTeam
                      ? () => context.push(
                          Routes.battle,
                          extra: BattleScreenArgs(
                            playerTeamName: 'My Team',
                            enemyTeamName:  stage.name,
                            stageId:        stageId,
                          ),
                        )
                      : () => context.push(Routes.roster),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: player.hasFullTeam
                        ? AppColors.primary
                        : Colors.white12,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    player.hasFullTeam
                        ? done ? '⚔  Challenge Again' : '⚔  Battle'
                        : '🐾  Set Up Team First',
                    style: GoogleFonts.rajdhani(
                      color: Colors.white, fontSize: 18,
                      fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Enemy row ─────────────────────────────────────────────────────────────────

class _EnemyRow extends StatelessWidget {
  final CreatureDefinition def;
  const _EnemyRow({required this.def});

  @override
  Widget build(BuildContext context) {
    final cls   = def.bodyClass.name;
    final color = _clsColor(cls);
    final stats = def.computedStats;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(children: [
          Image.asset(
            'assets/images/icons/$cls.png',
            width: 32, height: 32,
            errorBuilder: (_, __, ___) =>
                Icon(Icons.pets, size: 26, color: color)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(def.name,
                  style: GoogleFonts.rajdhani(
                    color: Colors.white, fontSize: 14,
                    fontWeight: FontWeight.w700)),
                Text(def.bodyClass.displayName,
                  style: TextStyle(color: color, fontSize: 10,
                      fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          // Part class dots
          Row(children: [
            for (final part in def.parts)
              Padding(
                padding: const EdgeInsets.only(left: 3),
                child: Container(
                  width: 10, height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _clsColor(part.className)
                        .withValues(alpha: 0.8),
                  ),
                ),
              ),
          ]),
          const SizedBox(width: 10),
          Text('❤ ${stats.hp}',
            style: const TextStyle(
              color: Colors.white38, fontSize: 11)),
        ]),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) => Text(label,
    style: GoogleFonts.rajdhani(
      color: Colors.white38, fontSize: 11,
      fontWeight: FontWeight.w800, letterSpacing: 1.5));
}
