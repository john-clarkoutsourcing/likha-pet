import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:likha_pet_battle_engine/trait.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../battle/data/creature_registry.dart';
import '../../battle/screens/battle_screen.dart';
import '../../battle/widgets/pet_renderer_widget.dart';
import '../../pets/models/owned_pet.dart' show OwnedPet;
import '../../pets/providers/player_provider.dart';
import '../data/stage_registry.dart';

Color _clsColor(CreatureClass cls) => switch (cls) {
  CreatureClass.plant   => const Color(0xFF4CAF50),
  CreatureClass.aquatic => const Color(0xFF29B6F6),
  CreatureClass.beast   => const Color(0xFFFF9800),
  CreatureClass.reptile => const Color(0xFF66BB6A),
  CreatureClass.bird    => const Color(0xFFFF80AB),
  CreatureClass.bug     => const Color(0xFFFF5252),
};

Color _diffColor(String d) => switch (d) {
  'Beginner' => const Color(0xFF44FF88),
  'Easy'     => const Color(0xFF88CCFF),
  'Medium'   => const Color(0xFFFFCC44),
  'Hard'     => const Color(0xFFFF8844),
  _          => const Color(0xFFFF4444),
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
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Left: Stage info ───────────────────────────────────────────────
            SizedBox(
              width: 220,
              child: Container(
                decoration: const BoxDecoration(
                  border: Border(right: BorderSide(color: Color(0xFF1A1F35))),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Back
                      GestureDetector(
                        onTap: () => context.pop(),
                        child: const Row(children: [
                          Icon(Icons.arrow_back_ios,
                              color: Colors.white38, size: 14),
                          Text(' Adventure',
                              style: TextStyle(
                                  color: Colors.white38, fontSize: 12)),
                        ]),
                      ),
                      const SizedBox(height: 16),

                      // Stage header
                      Row(children: [
                        Text(stage.emoji,
                            style: const TextStyle(fontSize: 26)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Stage ${stage.id}',
                                  style: const TextStyle(
                                      color: Colors.white38,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1)),
                              Text(stage.name,
                                  style: GoogleFonts.rajdhani(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900)),
                            ],
                          ),
                        ),
                      ]),

                      const SizedBox(height: 8),

                      // Difficulty + done badges
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _diffColor(stage.difficultyLabel)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(stage.difficultyLabel,
                              style: TextStyle(
                                  color: _diffColor(stage.difficultyLabel),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800)),
                        ),
                        if (done) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF44FF88)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                  color: const Color(0xFF44FF88)
                                      .withValues(alpha: 0.4)),
                            ),
                            child: const Text('✓ Cleared',
                                style: TextStyle(
                                    color: Color(0xFF44FF88),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800)),
                          ),
                        ],
                      ]),

                      const SizedBox(height: 10),

                      Text(stage.description,
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 11,
                              height: 1.4)),

                      const SizedBox(height: 16),
                      const Divider(color: Color(0xFF1A1F35)),
                      const SizedBox(height: 12),

                      // Reward
                      _Label('REWARD'),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A2535),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Row(children: [
                          const Text('💎',
                              style: TextStyle(fontSize: 16)),
                          const SizedBox(width: 6),
                          Text('${stage.crystalReward} Crystals',
                              style: GoogleFonts.rajdhani(
                                  color: const Color(0xFF44BBFF),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800)),
                          if (done) ...[
                            const Spacer(),
                            const Text('Claimed',
                                style: TextStyle(
                                    color: Colors.white38, fontSize: 9)),
                          ],
                        ]),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Right: Teams + Battle ──────────────────────────────────────────
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Enemy team
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _Label('ENEMY TEAM'),
                                const SizedBox(height: 8),
                                ...stage.enemyDefs.map((def) =>
                                    _EnemyCard(def: def)),
                              ],
                            ),
                          ),
                        ),

                        // Your team
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _Label('YOUR TEAM'),
                                const SizedBox(height: 8),
                                if (!player.hasFullTeam)
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.orangeAccent
                                          .withValues(alpha: 0.1),
                                      borderRadius:
                                          BorderRadius.circular(8),
                                      border: Border.all(
                                          color: Colors.orangeAccent
                                              .withValues(alpha: 0.3)),
                                    ),
                                    child: const Text(
                                      '⚠ Set a team of 3 pets first',
                                      style: TextStyle(
                                          color: Colors.orangeAccent,
                                          fontSize: 11)),
                                  )
                                else
                                  ...player.activeRoster.map(
                                    (pet) => _PlayerPetCard(pet: pet),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Battle button
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: player.hasFullTeam
                            ? () => context.push(Routes.battle,
                                extra: BattleScreenArgs(
                                  playerTeamName: 'My Team',
                                  enemyTeamName:  stage.name,
                                  stageId:        stageId,
                                ))
                            : () => context.push(Routes.roster),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: player.hasFullTeam
                              ? AppColors.primary
                              : Colors.white12,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          player.hasFullTeam
                              ? done ? '⚔  Challenge Again' : '⚔  Battle'
                              : '🐾  Set Up Team First',
                          style: GoogleFonts.rajdhani(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Enemy card ────────────────────────────────────────────────────────────────

class _EnemyCard extends StatelessWidget {
  final CreatureDefinition def;
  const _EnemyCard({required this.def});

  @override
  Widget build(BuildContext context) {
    final color = _clsColor(def.bodyClass);
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
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.15),
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Center(
              child: Text(def.bodyClass.displayName[0],
                  style: TextStyle(
                      color: color,
                      fontSize: 14,
                      fontWeight: FontWeight.w900)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(def.name,
                    style: GoogleFonts.rajdhani(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
                Text(def.bodyClass.displayName,
                    style: TextStyle(
                        color: color, fontSize: 9,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          // Part dots
          Row(children: [
            for (final part in def.parts)
              Padding(
                padding: const EdgeInsets.only(left: 3),
                child: Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _clsColor(part.partClass).withValues(alpha: 0.8),
                  ),
                ),
              ),
          ]),
          const SizedBox(width: 8),
          Text('❤ ${stats.hp}',
              style: const TextStyle(
                  color: Colors.white38, fontSize: 10)),
        ]),
      ),
    );
  }
}

// ── Player pet card ───────────────────────────────────────────────────────────

class _PlayerPetCard extends StatelessWidget {
  final OwnedPet pet;
  const _PlayerPetCard({required this.pet});

  @override
  Widget build(BuildContext context) {
    final def   = pet.toCreatureDefinition();
    final color = _clsColor(def.bodyClass);
    final stats = def.computedStats;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(children: [
          SizedBox(
            width: 72, height: 72,
            child: PetRendererWidget.fromOwned(pet, size: 72),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(def.bodyClass.displayName,
                    style: TextStyle(
                        color: color, fontSize: 9,
                        fontWeight: FontWeight.w700)),
                Text(pet.purityLabel,
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 9)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('❤ ${stats.hp}',
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 10)),
                Text('⚡ ${stats.speed}',
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 10)),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _Label extends StatelessWidget {
  final String label;
  const _Label(this.label);

  @override
  Widget build(BuildContext context) => Text(label,
      style: GoogleFonts.rajdhani(
          color: Colors.white38,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5));
}
