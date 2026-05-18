import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/router/app_router.dart';
import '../../pets/providers/player_provider.dart';
import '../../pve/data/stage_registry.dart';
import 'battle_screen.dart';

// ── Args ──────────────────────────────────────────────────────────────────────

class BattleResultArgs {
  final String  outcome;       // 'teamAWins' | 'teamBWins' | 'draw'
  final int     totalRounds;
  final String  playerTeamName;
  final String  enemyTeamName;
  final String? stageId;       // non-null for PvE stage battles

  const BattleResultArgs({
    required this.outcome,
    required this.totalRounds,
    required this.playerTeamName,
    required this.enemyTeamName,
    this.stageId,
  });
}

// ── Reward table ──────────────────────────────────────────────────────────────

const _kWinCrystals   = 100;
const _kDrawCrystals  = 30;
const _kLossCrystals  = 20;

// ── Screen ────────────────────────────────────────────────────────────────────

class BattleResultScreen extends ConsumerStatefulWidget {
  final BattleResultArgs args;
  const BattleResultScreen({super.key, required this.args});

  @override
  ConsumerState<BattleResultScreen> createState() => _BattleResultState();
}

class _BattleResultState extends ConsumerState<BattleResultScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final Animation<double>   _scale;
  late final int                 _crystalsEarned;
  bool _rewarded = false;

  @override
  void initState() {
    super.initState();
    final outcome = widget.args.outcome;
    final stageReward = widget.args.stageId != null
        ? stageById(widget.args.stageId!)?.crystalReward
        : null;
    _crystalsEarned = outcome == 'teamAWins'
        ? (stageReward ?? _kWinCrystals)
        : outcome == 'draw'
            ? _kDrawCrystals
            : _kLossCrystals;

    _anim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _scale = CurvedAnimation(parent: _anim, curve: Curves.elasticOut);

    // Award crystals once on first build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_rewarded && mounted) {
        final notifier = ref.read(playerProvider.notifier);
        notifier.awardCrystals(_crystalsEarned);
        // Mark stage complete if this was a stage battle and player won
        if (widget.args.stageId != null && widget.args.outcome == 'teamAWins') {
          notifier.completeStage(widget.args.stageId!);
        }
        setState(() => _rewarded = true);
        _anim.forward();
      }
    });
  }

  @override
  void dispose() { _anim.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final outcome   = widget.args.outcome;
    final playerWon = outcome == 'teamAWins';
    final isDraw    = outcome == 'draw';

    final emoji  = isDraw ? '🤝' : (playerWon ? '🏆' : '💀');
    final title  = isDraw ? 'DRAW' : (playerWon ? 'VICTORY!' : 'DEFEAT');
    final color  = isDraw
        ? AppColors.textSecondary
        : (playerWon ? AppColors.secondary : AppColors.hpRed);
    final winner = isDraw
        ? 'No winner'
        : (playerWon ? widget.args.playerTeamName : widget.args.enemyTeamName);
    final totalCrystals = ref.watch(playerProvider).soulCrystals;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            const SizedBox(height: 16),

            // Outcome icon + title
            Text(emoji, style: const TextStyle(fontSize: 72)),
            const SizedBox(height: 12),
            Text(title,
              style: TextStyle(
                color: color, fontSize: 42,
                fontWeight: FontWeight.w900, letterSpacing: 3)),
            const SizedBox(height: 6),
            Text(winner,
              style: const TextStyle(
                color: AppColors.textPrimary, fontSize: 20,
                fontWeight: FontWeight.w600)),

            const SizedBox(height: 28),

            // ── Crystal reward card ──────────────────────────────────────────
            ScaleTransition(
              scale: _scale,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: playerWon
                        ? [const Color(0xFF1A3A2A), const Color(0xFF0E1A2B)]
                        : isDraw
                            ? [const Color(0xFF2A2A1A), const Color(0xFF0E1A2B)]
                            : [const Color(0xFF1A1A2A), const Color(0xFF0E1A2B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: playerWon
                        ? const Color(0xFF44FF88).withValues(alpha: 0.3)
                        : isDraw
                            ? const Color(0xFFFFCC44).withValues(alpha: 0.3)
                            : const Color(0xFF4488CC).withValues(alpha: 0.3),
                  ),
                ),
                child: Column(children: [
                  Text('Rewards',
                    style: GoogleFonts.rajdhani(
                      color: Colors.white54, fontSize: 12,
                      fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('💎',
                          style: TextStyle(fontSize: 28)),
                      const SizedBox(width: 8),
                      Text('+$_crystalsEarned',
                        style: GoogleFonts.rajdhani(
                          color: const Color(0xFF44BBFF),
                          fontSize: 36, fontWeight: FontWeight.w900)),
                      const SizedBox(width: 6),
                      Text('Soul Crystals',
                        style: GoogleFonts.rajdhani(
                          color: Colors.white54, fontSize: 14,
                          fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Total: 💎 $totalCrystals',
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 12)),
                  if (playerWon) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF44FF88).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Victory bonus! Breed at 💎 200 per pair',
                        style: TextStyle(
                            color: Color(0xFF44FF88), fontSize: 10)),
                    ),
                  ],
                ]),
              ),
            ),

            const SizedBox(height: 24),

            // Stats
            _StatRow(label: 'Rounds fought', value: '${widget.args.totalRounds}'),
            const SizedBox(height: 8),
            _StatRow(label: 'Your team', value: widget.args.playerTeamName),
            const SizedBox(height: 8),
            _StatRow(label: 'Enemy team', value: widget.args.enemyTeamName),
            const SizedBox(height: 28),

            // Action buttons
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.push(Routes.battle,
                    extra: const BattleScreenArgs()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('⚔  Battle Again',
                  style: GoogleFonts.rajdhani(
                    fontWeight: FontWeight.w800, fontSize: 16,
                    color: Colors.white)),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => context.push(Routes.breed),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFCE93D8),
                  side: const BorderSide(
                      color: Color(0xFF9C27B0), width: 1),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('🧬  Breed with Crystals',
                  style: GoogleFonts.rajdhani(
                    fontWeight: FontWeight.w800, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => context.go(Routes.home),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  side: const BorderSide(color: AppColors.divider),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Home',
                  style: GoogleFonts.rajdhani(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 16),
          ]),
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label, value;
  const _StatRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Row(children: [
    Text(label,
        style: const TextStyle(color: AppColors.textMuted, fontSize: 14)),
    const Spacer(),
    Text(value,
        style: const TextStyle(
            color: AppColors.textPrimary, fontSize: 14,
            fontWeight: FontWeight.w600)),
  ]);
}
