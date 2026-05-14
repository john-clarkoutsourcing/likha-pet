import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:likha_pet_battle_engine/energy_pool.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/widgets/hp_bar.dart';
import '../providers/pve_battle_provider.dart';
import '../providers/battle_view_model.dart';
import '../widgets/pet_character_widget.dart';
import '../widgets/battle_background_widget.dart';
import '../widgets/pet_sprite_widget.dart';
import '../widgets/projectile_widget.dart';
import 'battle_result_screen.dart';

// ── Route args ────────────────────────────────────────────────────────────────

class BattleScreenArgs {
  final String playerTeamName;
  final String enemyTeamName;
  const BattleScreenArgs({
    this.playerTeamName = 'Team Bayani',
    this.enemyTeamName  = 'Team Diwata',
  });
}

// ── Constants ─────────────────────────────────────────────────────────────────

const _kRoundSeconds  = 30;
const _kSpriteBase    = 58.0;

/// Depth scaling: front is biggest & brightest, back is smallest & dimmer.
const _kScaleByPos    = [1.00, 0.87, 0.75];
const _kOpacityByPos  = [1.00, 0.92, 0.78];

/// Battlefield positions as (left%, top%) fractions.
/// Player faces right — front pet is closest to the centre line.
/// Enemy mirrors.
const _kPlayerPos = [
  Offset(0.27, 0.36), // FRONT — centre height, closest to enemy
  Offset(0.13, 0.12), // MID   — upper-left (behind front)
  Offset(0.04, 0.60), // BACK  — lower-left (furthest from enemy)
];
const _kEnemyPos = [
  Offset(0.60, 0.36), // FRONT — mirrored
  Offset(0.73, 0.12), // MID
  Offset(0.83, 0.60), // BACK
];

// ── Screen ────────────────────────────────────────────────────────────────────

class BattleScreen extends ConsumerStatefulWidget {
  final BattleScreenArgs args;
  const BattleScreen({super.key, required this.args});

  @override
  ConsumerState<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends ConsumerState<BattleScreen>
    with TickerProviderStateMixin {
  late final AnimationController _timer;

  @override
  void initState() {
    super.initState();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _timer = AnimationController(
      vsync: this,
      duration: const Duration(seconds: _kRoundSeconds),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) _autoEndTurn();
      });
    _timer.forward();
  }

  @override
  void dispose() {
    _timer.dispose();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  void _autoEndTurn() {
    final vm = ref.read(pveBattleProvider);
    if (!vm.isBattleOver && !vm.isResolving) {
      ref.read(pveBattleProvider.notifier).executeRound();
    }
  }

  void _restartTimer() {
    _timer
      ..reset()
      ..forward();
  }

  @override
  Widget build(BuildContext context) {
    final vm = ref.watch(pveBattleProvider);

    // Listen for state changes to control the timer
    ref.listen<PveBattleViewModel>(pveBattleProvider, (prev, next) {
      // Navigate when battle ends
      if (next.isBattleOver && next.outcome != null) {
        _timer.stop();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            context.go(Routes.battleResult, extra: BattleResultArgs(
              outcome: next.outcome!,
              totalRounds: next.currentRound,
              playerTeamName: next.playerTeamName,
              enemyTeamName: next.enemyTeamName,
            ));
          }
        });
        return;
      }
      // Pause timer while round is resolving
      if (next.isResolving) {
        _timer.stop();
        return;
      }
      // Restart timer when a new round begins (round number changed
      // or resolution just finished)
      final roundChanged = (prev?.currentRound ?? -1) != next.currentRound;
      final resolveFinished = (prev?.isResolving ?? false) && !next.isResolving;
      if (roundChanged || resolveFinished) _restartTimer();
    });

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          const BattleBackgroundWidget(),
          SafeArea(
            child: Column(
              children: [
                _TopHUD(vm: vm, timer: _timer),
                Expanded(child: _Battlefield(vm: vm)),
                _BattleFeed(log: vm.roundLog),
                _BottomPanel(vm: vm, ref: ref, timer: _timer),
              ],
            ),
          ),
          // Discard popup — covers the screen when hand exceeds 10
          if (vm.needsDiscard)
            _DiscardPopup(vm: vm, ref: ref),
        ],
      ),
    );
  }
}


// ── Top HUD ───────────────────────────────────────────────────────────────────

class _TopHUD extends StatelessWidget {
  final PveBattleViewModel vm;
  final AnimationController timer;
  const _TopHUD({required this.vm, required this.timer});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.black.withValues(alpha: 0.72),
            Colors.black.withValues(alpha: 0.42),
            Colors.black.withValues(alpha: 0.72),
          ],
        ),
      ),
      child: Row(
        children: [
          // Player label
          _PlayerTag(name: vm.playerTeamName, isPlayer: true),
          const SizedBox(width: 8),

          // Centre: round + timer + attack order
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Round ${vm.currentRound}',
                      style: GoogleFonts.rajdhani(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                        shadows: const [Shadow(blurRadius: 6, color: Colors.black)],
                      ),
                    ),
                    const SizedBox(width: 10),
                    _RoundTimer(timer: timer),
                    const SizedBox(width: 10),
                    _DeckCounter(drawSize: vm.deckDrawSize, discardSize: vm.deckDiscardSize),
                  ],
                ),
                const SizedBox(height: 3),
                _AttackOrderStrip(vm: vm),
              ],
            ),
          ),

          const SizedBox(width: 8),
          // Enemy label
          _PlayerTag(name: vm.enemyTeamName, isPlayer: false),
        ],
      ),
    );
  }
}

// ── Round timer ───────────────────────────────────────────────────────────────

class _RoundTimer extends StatelessWidget {
  final AnimationController timer;
  const _RoundTimer({required this.timer});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: timer,
      builder: (_, __) {
        final remaining = 1.0 - timer.value;
        final seconds = (_kRoundSeconds * remaining).ceil();
        final color = remaining > 0.5
            ? const Color(0xFF66FF88)
            : remaining > 0.25
                ? const Color(0xFFFFDD44)
                : const Color(0xFFFF4444);

        return SizedBox(
          width: 34,
          height: 34,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: remaining,
                strokeWidth: 3,
                color: color,
                backgroundColor: Colors.white12,
              ),
              Text(
                '$seconds',
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  shadows: const [Shadow(blurRadius: 3, color: Colors.black)],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Deck counter ──────────────────────────────────────────────────────────────

class _DeckCounter extends StatelessWidget {
  final int drawSize;
  final int discardSize;
  const _DeckCounter({required this.drawSize, required this.discardSize});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _pill(Icons.style_outlined, '$drawSize', AppColors.accent),
        const SizedBox(width: 4),
        _pill(Icons.refresh_rounded, '$discardSize', Colors.white38),
      ],
    );
  }

  Widget _pill(IconData icon, String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 9, color: color),
            const SizedBox(width: 2),
            Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w700)),
          ],
        ),
      );
}

// ── Player tag ────────────────────────────────────────────────────────────────

class _PlayerTag extends StatelessWidget {
  final String name;
  final bool isPlayer;
  const _PlayerTag({required this.name, required this.isPlayer});

  @override
  Widget build(BuildContext context) {
    final color = isPlayer ? AppColors.accent : AppColors.offensive;
    final avatar = Container(
      width: 26, height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.2),
        border: Border.all(color: color, width: 2),
      ),
      child: Center(
        child: Text(name[0], style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
      ),
    );
    final label = Text(
      name,
      style: GoogleFonts.rajdhani(
        color: Colors.white70,
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    );
    return isPlayer
        ? Row(mainAxisSize: MainAxisSize.min, children: [label, const SizedBox(width: 5), avatar])
        : Row(mainAxisSize: MainAxisSize.min, children: [avatar, const SizedBox(width: 5), label]);
  }
}

// ── Attack order strip ────────────────────────────────────────────────────────

class _AttackOrderStrip extends StatelessWidget {
  final PveBattleViewModel vm;
  const _AttackOrderStrip({required this.vm});

  @override
  Widget build(BuildContext context) {
    final alive = vm.turnOrder.where((e) => !e.isFainted).toList();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < alive.length; i++) ...[
          if (i > 0)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 2),
              child: Icon(Icons.chevron_right, size: 10, color: Colors.white30),
            ),
          _OrderDot(entry: alive[i], isFirst: i == 0),
        ],
      ],
    );
  }
}

class _OrderDot extends StatelessWidget {
  final TurnOrderEntry entry;
  final bool isFirst;
  const _OrderDot({required this.entry, required this.isFirst});

  @override
  Widget build(BuildContext context) {
    final c = entry.isPlayer ? AppColors.accent : AppColors.offensive;
    final size = isFirst ? 26.0 : 20.0;
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: c.withValues(alpha: 0.22),
        border: Border.all(color: c, width: isFirst ? 2.0 : 1.5),
        boxShadow: isFirst
            ? [BoxShadow(color: c.withValues(alpha: 0.55), blurRadius: 6, spreadRadius: 1)]
            : null,
      ),
      child: Center(
        child: Text(
          entry.name[0],
          style: TextStyle(color: Colors.white, fontSize: isFirst ? 11 : 8, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

// ── Battlefield ───────────────────────────────────────────────────────────────

class _Battlefield extends ConsumerStatefulWidget {
  final PveBattleViewModel vm;
  const _Battlefield({required this.vm});

  @override
  ConsumerState<_Battlefield> createState() => _BattlefieldState();
}

class _BattlefieldState extends ConsumerState<_Battlefield> {
  final List<ProjectileInstance> _projectiles = [];
  int _nextId = 0;
  // Last anim states we already spawned projectiles for (avoid re-spawning on rebuild)
  Set<String> _lastAttackIds = {};

  @override
  void didUpdateWidget(_Battlefield old) {
    super.didUpdateWidget(old);
    _maybeSpawnProjectiles(widget.vm);
  }

  void _maybeSpawnProjectiles(PveBattleViewModel vm) {
    if (vm.petAnimStates.isEmpty) {
      _lastAttackIds = {};
      return;
    }
    final attackIds = vm.petAnimStates.keys.toSet();
    if (attackIds == _lastAttackIds) return;
    _lastAttackIds = attackIds;

    // Compute screen-space positions from fractional constants.
    // We don't have a BuildContext with size here, so defer to next frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final RenderBox? box = context.findRenderObject() as RenderBox?;
      if (box == null) return;
      final w = box.size.width;
      final h = box.size.height;

      final newProjectiles = <ProjectileInstance>[];

      for (final petId in vm.petAnimStates.keys) {
        final cfg = kPetProjectiles[petId];
        if (cfg == null) continue;

        // Determine start (attacker centre) and end (first living target centre).
        final isPlayer = petId.startsWith('bayani');
        final attackerPositions = isPlayer ? _kPlayerPos : _kEnemyPos;
        final targetPositions   = isPlayer ? _kEnemyPos  : _kPlayerPos;
        final targetTeam        = isPlayer ? vm.enemyTeam : vm.playerTeam;

        // Find which slot the attacker is in
        final team = isPlayer ? vm.playerTeam : vm.enemyTeam;
        final attackerIdx = team.indexWhere((p) => p.id == petId);
        if (attackerIdx < 0) continue;

        // Front alive target
        final targetIdx = targetTeam.indexWhere((p) => !p.isFainted);
        if (targetIdx < 0) continue;

        final startFrac = attackerPositions[attackerIdx];
        final endFrac   = targetPositions[targetIdx];

        final spriteOffset = 29.0; // half the sprite visual centre offset
        final start = Offset(w * startFrac.dx + spriteOffset, h * startFrac.dy + spriteOffset);
        final end   = Offset(w * endFrac.dx   + spriteOffset, h * endFrac.dy   + spriteOffset);

        newProjectiles.add(ProjectileInstance(
          id:     '${_nextId++}',
          start:  start,
          end:    end,
          config: cfg,
        ));
      }

      if (newProjectiles.isNotEmpty) {
        setState(() => _projectiles.addAll(newProjectiles));
      }
    });
  }

  void _removeProjectile(String id) {
    setState(() => _projectiles.removeWhere((p) => p.id == id));
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;

    return LayoutBuilder(
      builder: (_, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // Ground line
            Positioned(
              top: h * 0.52,
              left: 0, right: 0,
              child: Container(
                height: 1.5,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.brown.shade700.withValues(alpha: 0.5),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Enemy pets
            for (var i = 0; i < vm.enemyTeam.length; i++)
              _placed(w, h, _kEnemyPos[i], _BattlePet(
                pet: vm.enemyTeam[i],
                isPlayer: false,
                isSelected: false,
                hasSkill: false,
                positionIndex: i,
                animState: vm.petAnimStates[vm.enemyTeam[i].id],
              )),

            // Player pets
            for (var i = 0; i < vm.playerTeam.length; i++)
              _placed(w, h, _kPlayerPos[i], _BattlePet(
                pet: vm.playerTeam[i],
                isPlayer: true,
                isSelected: vm.selectedPetId == vm.playerTeam[i].id,
                hasSkill: vm.pendingSkills[vm.playerTeam[i].id]?.isNotEmpty ?? false,
                positionIndex: i,
                animState: vm.petAnimStates[vm.playerTeam[i].id],
                onTap: vm.playerTeam[i].isFainted
                    ? null
                    : () => ref.read(pveBattleProvider.notifier)
                        .selectPet(vm.playerTeam[i].id),
              )),

            // Flying projectiles
            for (final p in _projectiles)
              ProjectileWidget(
                key:    ValueKey(p.id),
                data:   p,
                onDone: () => _removeProjectile(p.id),
              ),
          ],
        );
      },
    );
  }

  Widget _placed(double w, double h, Offset pos, Widget child) => Positioned(
        left: w * pos.dx,
        top:  h * pos.dy,
        child: child,
      );
}

// ── Battle pet ────────────────────────────────────────────────────────────────

class _BattlePet extends StatelessWidget {
  final PetViewModel pet;
  final bool isPlayer;
  final bool isSelected;
  final bool hasSkill;
  final int positionIndex;
  final VoidCallback? onTap;
  final PetCharacterAnimState? animState;

  const _BattlePet({
    required this.pet,
    required this.isPlayer,
    required this.isSelected,
    required this.hasSkill,
    required this.positionIndex,
    this.onTap,
    this.animState,
  });

  @override
  Widget build(BuildContext context) {
    final scale   = _kScaleByPos[positionIndex.clamp(0, 2)];
    final opacity = _kOpacityByPos[positionIndex.clamp(0, 2)];
    final spriteSize = _kSpriteBase * scale;

    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: pet.isFainted ? 0.18 : opacity,
        child: Transform.scale(
          scale: scale,
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: spriteSize + 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _FloatingHpBar(pet: pet, width: spriteSize + 14),
                const SizedBox(height: 3),
                _Sprite(
                  pet: pet,
                  size: spriteSize,
                  isSelected: isSelected,
                  hasSkill: hasSkill,
                  isPlayer: isPlayer,
                  animState: animState,
                ),
                const SizedBox(height: 2),
                // Name only — no position label needed (depth is visual)
                _PetName(pet: pet),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Floating HP bar ───────────────────────────────────────────────────────────

class _FloatingHpBar extends StatelessWidget {
  final PetViewModel pet;
  final double width;
  const _FloatingHpBar({required this.pet, required this.width});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.favorite, size: 8, color: Color(0xFF66FF88)),
              const SizedBox(width: 2),
              Text(
                '${pet.hp}',
                style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              if (pet.shield > 0)
                const Icon(Icons.shield, size: 8, color: AppColors.shieldGold),
              if (pet.isStunned)
                const Padding(
                  padding: EdgeInsets.only(left: 2),
                  child: Text('⚡', style: TextStyle(fontSize: 7)),
                ),
              if (pet.isPoisoned)
                const Padding(
                  padding: EdgeInsets.only(left: 2),
                  child: Text('☠', style: TextStyle(fontSize: 7)),
                ),
            ],
          ),
          const SizedBox(height: 2),
          HpBar(current: pet.hp, max: pet.maxHp, height: 4),
        ],
      ),
    );
  }
}

// ── Pet sprite ────────────────────────────────────────────────────────────────

class _Sprite extends StatelessWidget {
  final PetViewModel pet;
  final double size;
  final bool isSelected;
  final bool hasSkill;
  final bool isPlayer;
  final PetCharacterAnimState? animState;

  const _Sprite({
    required this.pet,
    required this.size,
    required this.isSelected,
    required this.hasSkill,
    required this.isPlayer,
    this.animState,
  });

  @override
  Widget build(BuildContext context) {
    final color = _petColor(pet.name);

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        // Selection glow
        if (isSelected)
          Container(
            width: size + 12, height: size + 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.75),
                  blurRadius: 16, spreadRadius: 5,
                ),
              ],
            ),
          ),

        // Ground shadow
        Positioned(
          bottom: -6,
          child: Container(
            width: size * 0.75,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.25),
            ),
          ),
        ),

        // Sprite body
        // Priority: Axie Spine animation > Flame spritesheet > Flame placeholder.
        // Fainted pets → simple circle with ✕.
        if (!pet.isFainted && pet.characterConfig != null)
          PetCharacterWidget(
            config:         pet.characterConfig!,
            size:           size,
            flipHorizontal: isPlayer,
            animState:      animState ?? PetCharacterAnimState.idle,
          )
        else if (!pet.isFainted)
          PetSpriteWidget(
            config:         pet.spriteConfig,
            size:           size,
            flipHorizontal: isPlayer,
            petName:        pet.name,
            petColor:       color,
          )
        else
          Container(
            width: size, height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  color.withValues(alpha: 0.95),
                  color.withValues(alpha: 0.65),
                ],
                center: const Alignment(-0.3, -0.3),
                radius: 0.85,
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.25),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 8, spreadRadius: 1,
                ),
              ],
            ),
            child: Center(
              child: Text(
                pet.isFainted ? '✕' : pet.name[0],
                style: TextStyle(
                  color: Colors.white,
                  fontSize: pet.isFainted ? size * 0.3 : size * 0.42,
                  fontWeight: FontWeight.w900,
                  shadows: const [Shadow(blurRadius: 4, color: Colors.black45)],
                ),
              ),
            ),
          ),

        // Skill-assigned checkmark
        if (hasSkill && !pet.isFainted)
          Positioned(
            top: 0, right: 0,
            child: Container(
              width: 16, height: 16,
              decoration: const BoxDecoration(
                shape: BoxShape.circle, color: AppColors.accent,
              ),
              child: const Icon(Icons.check, size: 10, color: Colors.white),
            ),
          ),

      ],
    );
  }

  static Color _petColor(String name) {
    const c = [
      Color(0xFF6C3FA1), Color(0xFF3FCFA1), Color(0xFFE8A838),
      Color(0xFFE53935), Color(0xFF1E88E5), Color(0xFF43A047),
    ];
    return c[name.codeUnits.first % c.length];
  }
}

class _PetName extends StatelessWidget {
  final PetViewModel pet;
  const _PetName({required this.pet});

  @override
  Widget build(BuildContext context) => Text(
        pet.name,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          shadows: [Shadow(blurRadius: 4, color: Colors.black87)],
        ),
      );
}

// ── Battle feed (compact last-round summary) ──────────────────────────────────

class _BattleFeed extends StatelessWidget {
  final String log;
  const _BattleFeed({required this.log});

  @override
  Widget build(BuildContext context) {
    if (log.isEmpty) return const SizedBox.shrink();

    // Extract only action/damage lines from the latest round
    final lines = log
        .split('\n')
        .where((l) =>
            l.contains('→') ||
            l.contains('⚔') ||
            l.contains('FAINTED') ||
            l.contains('STUNNED'))
        .map((l) => l.trim().replaceAll('  ', ' '))
        .where((l) => l.isNotEmpty)
        .toList();

    final display = lines.isEmpty
        ? ''
        : lines.length <= 2
            ? lines.join('  ·  ')
            : '${lines[lines.length - 2]}  ·  ${lines.last}';

    if (display.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 28,
      width: double.infinity,
      color: Colors.black.withValues(alpha: 0.55),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Text(
        display,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 10,
          fontFamily: 'monospace',
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

// ── Bottom panel ──────────────────────────────────────────────────────────────

class _BottomPanel extends StatelessWidget {
  final PveBattleViewModel vm;
  final WidgetRef ref;
  final AnimationController timer;
  const _BottomPanel({required this.vm, required this.ref, required this.timer});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 148,
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFF7A5030), width: 2)),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Wood-texture tray background
          Image.asset('assets/images/ui/wood-background.png',
              fit: BoxFit.cover, alignment: Alignment.topCenter),
          // Dark overlay so text stays readable
          Container(color: Colors.black.withValues(alpha: 0.45)),
          _BottomPanelContent(vm: vm, ref: ref, timer: timer),
        ],
      ),
    );
  }
}

class _BottomPanelContent extends StatelessWidget {
  final PveBattleViewModel vm;
  final WidgetRef ref;
  final AnimationController timer;
  const _BottomPanelContent({required this.vm, required this.ref, required this.timer});

  @override
  Widget build(BuildContext context) {
    final selectedPet  = vm.playerTeam.where((p) => p.id == vm.selectedPetId).firstOrNull;
    final visibleCards = vm.selectedPetCards;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(width: 10),
        _EnergyOrb(energy: vm.playerTeamEnergy, maxEnergy: kTeamEnergyCap),
        const SizedBox(width: 10),

        if (!vm.isBattleOver)
          if (visibleCards.isEmpty)
            _NoCardsHint(selectedPetName: selectedPet?.name)
          else
            Expanded(
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: visibleCards.length,
                itemBuilder: (_, i) {
                  final card       = visibleCards[i];
                  final isAssigned = vm.pendingSkills[card.ownerPetId]?.contains(card.instanceId) ?? false;
                  final isNew      = vm.newCardIds.contains(card.instanceId);

                  Widget cardWidget = Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _SkillCard(
                      trait:       card.trait,
                      petName:     card.ownerPetName,
                      isSelected:  isAssigned,
                      isPity:      card.isPity,
                      cardArtPath: card.cardArtPath,
                      onTap: () => ref
                          .read(pveBattleProvider.notifier)
                          .assignSkill(card.instanceId),
                    ),
                  );

                  if (isNew) {
                    final delay = Duration(milliseconds: i * 80);
                    cardWidget = _CardEntrance(
                      key: ValueKey(card.instanceId),
                      delay: delay,
                      child: cardWidget,
                    );
                  }
                  return cardWidget;
                },
              ),
            ),

        const SizedBox(width: 8),
        if (!vm.isBattleOver) _AssignmentDots(vm: vm),
        const SizedBox(width: 12),
        _EndTurnButton(vm: vm, ref: ref),
        const SizedBox(width: 10),
      ],
    );
  }
}

// ── Energy orb ────────────────────────────────────────────────────────────────

class _EnergyOrb extends StatelessWidget {
  final int energy;
  final int maxEnergy;
  const _EnergyOrb({required this.energy, required this.maxEnergy});

  @override
  Widget build(BuildContext context) {
    final max  = maxEnergy;
    final frac = max > 0 ? energy / max : 0.0;

    return SizedBox(
      width: 60, height: 60,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.energyBlue.withValues(alpha: 0.45),
                  AppColors.energyBlue.withValues(alpha: 0.08),
                ],
              ),
            ),
          ),
          CustomPaint(
            size: const Size(54, 54),
            painter: _ArcPainter(fraction: frac),
          ),
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF0C2540),
              border: Border.all(color: AppColors.energyBlue.withValues(alpha: 0.55), width: 1.5),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$energy',
                    style: GoogleFonts.rajdhani(
                      color: AppColors.energyBlue,
                      fontSize: 15, fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '/$max',
                    style: const TextStyle(color: Colors.white30, fontSize: 7),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  final double fraction;
  const _ArcPainter({required this.fraction});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawArc(
      Rect.fromLTWH(2, 2, size.width - 4, size.height - 4),
      -math.pi / 2,
      math.pi * 2 * fraction,
      false,
      Paint()
        ..color = AppColors.energyBlue
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.fraction != fraction;
}

// ── Discard popup ─────────────────────────────────────────────────────────────

class _DiscardPopup extends StatefulWidget {
  final PveBattleViewModel vm;
  final WidgetRef ref;
  const _DiscardPopup({required this.vm, required this.ref});

  @override
  State<_DiscardPopup> createState() => _DiscardPopupState();
}

class _DiscardPopupState extends State<_DiscardPopup>
    with SingleTickerProviderStateMixin {
  static const _kSeconds = 8;
  int _remaining = _kSeconds;

  late final AnimationController _slideCtrl;
  late final Animation<Offset>   _slide;
  late final _ticker = Stream.periodic(const Duration(seconds: 1), (i) => _kSeconds - 1 - i)
      .take(_kSeconds)
      .listen((s) { if (mounted) setState(() => _remaining = s); });

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 320));
    _slide = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut));
    _slideCtrl.forward();
  }

  @override
  void dispose() {
    _ticker.cancel();
    _slideCtrl.dispose();
    super.dispose();
  }

  PveBattleViewModel get vm  => widget.vm;
  WidgetRef          get ref => widget.ref;

  Color get _timerColor => _remaining <= 3
      ? const Color(0xFFFF4444)
      : const Color(0xFFFF9933);

  @override
  Widget build(BuildContext context) {
    final needed = vm.excessDiscards;

    return Stack(
      children: [
        // Dimmed backdrop (only top portion — bottom stays visible)
        Positioned.fill(
          bottom: 190,
          child: GestureDetector(
            onTap: () {}, // absorb taps
            child: Container(color: Colors.black.withValues(alpha: 0.6)),
          ),
        ),

        // Slide-up panel from the bottom
        Positioned(
          left: 0, right: 0, bottom: 0,
          child: SlideTransition(
            position: _slide,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1A0A0A),
                border: const Border(
                  top: BorderSide(color: Color(0xFFCC3030), width: 2),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFCC3030).withValues(alpha: 0.3),
                    blurRadius: 20, spreadRadius: 2, offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [

                  // ── Header bar ───────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    color: const Color(0xFF2E0808),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            color: Color(0xFFFF6060), size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'HAND FULL',
                          style: GoogleFonts.rajdhani(
                            color: const Color(0xFFFF6060),
                            fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFAA3030).withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFAA3030)),
                          ),
                          child: Text(
                            'Discard $needed card${needed > 1 ? "s" : ""}',
                            style: GoogleFonts.rajdhani(
                              color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const Spacer(),
                        // Countdown ring
                        SizedBox(
                          width: 36, height: 36,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CircularProgressIndicator(
                                value: _remaining / _kSeconds,
                                strokeWidth: 3,
                                color: _timerColor,
                                backgroundColor: Colors.white12,
                              ),
                              Text(
                                '$_remaining',
                                style: TextStyle(
                                  color: _timerColor,
                                  fontSize: 12, fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Subtitle ─────────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.only(top: 8, left: 16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Tap a card to discard it  ·  ★ pity cards are auto-protected',
                        style: TextStyle(color: Colors.white38, fontSize: 10),
                      ),
                    ),
                  ),

                  // ── Card row ─────────────────────────────────────────────
                  SizedBox(
                    height: 160,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      itemCount: vm.hand.length,
                      itemBuilder: (_, i) {
                        final card = vm.hand[i];
                        return Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: _SkillCard(
                            trait:       card.trait,
                            petName:     card.ownerPetName,
                            isSelected:  false,
                            isPity:      card.isPity,
                            discardMode: true,
                            cardArtPath: card.cardArtPath,
                            onTap: () => ref
                                .read(pveBattleProvider.notifier)
                                .discardCard(card.instanceId),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── No cards hint ─────────────────────────────────────────────────────────────

// ── Card entrance animation ───────────────────────────────────────────────────

class _CardEntrance extends StatefulWidget {
  final Widget   child;
  final Duration delay;
  const _CardEntrance({super.key, required this.child, required this.delay});

  @override
  State<_CardEntrance> createState() => _CardEntranceState();
}

class _CardEntranceState extends State<_CardEntrance>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _opacity;
  late Animation<Offset>   _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
    _opacity = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _slide = Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    Future.delayed(widget.delay, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _opacity,
        child: SlideTransition(position: _slide, child: widget.child),
      );
}

// ── No-cards hint ─────────────────────────────────────────────────────────────

class _NoCardsHint extends StatelessWidget {
  final String? selectedPetName;
  const _NoCardsHint({this.selectedPetName});

  @override
  Widget build(BuildContext context) {
    final name = selectedPetName ?? 'This pet';
    return SizedBox(
      width: 160,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No cards drawn',
            style: GoogleFonts.rajdhani(
              color: Colors.white38,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$name will use\nAI fallback this turn',
            style: const TextStyle(color: Colors.white24, fontSize: 9),
          ),
        ],
      ),
    );
  }
}

// ── Skill card ────────────────────────────────────────────────────────────────

class _SkillCard extends StatelessWidget {
  final TraitViewModel trait;
  final String         petName;
  final bool           isSelected;
  final bool           isPity;
  final bool           discardMode;
  final String?        cardArtPath;
  final VoidCallback?  onTap;

  const _SkillCard({
    required this.trait,
    required this.petName,
    required this.isSelected,
    this.isPity      = false,
    this.discardMode = false,
    this.cardArtPath,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final usable     = discardMode || trait.isUsable;
    final tc         = discardMode ? const Color(0xFFFF6060) : _typeColor(trait.typeName);
    final borderCol  = discardMode
        ? const Color(0xFFCC3030)
        : isSelected ? Colors.white
        : usable     ? tc.withValues(alpha: 0.8)
        : Colors.white12;

    return GestureDetector(
      onTap: usable ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 110),
        width:  discardMode ? 100 : 90,
        height: discardMode ? 148 : 128,
        transform: isSelected
            ? (Matrix4.identity()..translateByDouble(0, -10, 0, 1))
            : Matrix4.identity(),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderCol, width: isSelected || discardMode ? 2.5 : 1.5),
          boxShadow: [
            if (isSelected)
              BoxShadow(color: tc.withValues(alpha: 0.7), blurRadius: 14, spreadRadius: 2),
            if (discardMode)
              const BoxShadow(color: Color(0xFFCC2020), blurRadius: 10, spreadRadius: 1),
            const BoxShadow(color: Colors.black87, blurRadius: 6, offset: Offset(0, 2)),
          ],
        ),
        child: Opacity(
          opacity: usable ? 1.0 : 0.35,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // ── Art area (top ~65%) ──────────────────────────────────────
                Positioned.fill(
                  child: cardArtPath != null
                      ? Image.asset(cardArtPath!, fit: BoxFit.cover, alignment: Alignment.topCenter)
                      : Container(color: _cardBgColor(trait.typeName)),
                ),

                // Gradient fade into info strip
                Positioned(
                  left: 0, right: 0, bottom: 0,
                  child: Container(
                    height: 72,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter, end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.72),
                          Colors.black.withValues(alpha: 0.92),
                        ],
                        stops: const [0.0, 0.45, 1.0],
                      ),
                    ),
                  ),
                ),

                // ── Info strip (bottom) ──────────────────────────────────────
                Positioned(
                  left: 6, right: 6, bottom: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Skill name
                      Text(
                        trait.name,
                        style: GoogleFonts.rajdhani(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                          shadows: const [Shadow(blurRadius: 4, color: Colors.black)],
                        ),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      // Effect + cost row
                      Row(
                        children: [
                          Text(
                            trait.effectSummary,
                            style: GoogleFonts.rajdhani(
                              color: tc,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              shadows: const [Shadow(blurRadius: 3, color: Colors.black)],
                            ),
                          ),
                          const Spacer(),
                          // Energy cost dots
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(trait.energyCost, (_) => Container(
                              width: 7, height: 7,
                              margin: const EdgeInsets.only(left: 2),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: trait.canAfford
                                    ? AppColors.energyBlue
                                    : Colors.white.withValues(alpha: 0.15),
                                boxShadow: trait.canAfford
                                    ? [BoxShadow(color: AppColors.energyBlue.withValues(alpha: 0.6), blurRadius: 4)]
                                    : null,
                              ),
                            )),
                          ),
                        ],
                      ),
                      // Cooldown warning
                      if (!trait.isReady)
                        Text('CD ${trait.cooldownRemaining}',
                            style: TextStyle(color: AppColors.utility, fontSize: 7, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),

                // ── Top badges ───────────────────────────────────────────────
                Positioned(
                  top: 5, left: 5,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: tc.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(_typeIcon(trait.typeName),
                        style: const TextStyle(fontSize: 9)),
                  ),
                ),
                Positioned(
                  top: 5, right: 5,
                  child: _PetDot(name: petName),
                ),

                // Selected shimmer
                if (isSelected)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.white.withValues(alpha: 0.18), Colors.transparent],
                          begin: Alignment.topCenter, end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),

                // Discard mode: red vignette edge + corner badge (art stays visible)
                if (discardMode) ...[
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(9),
                        gradient: RadialGradient(
                          center: Alignment.center,
                          radius: 1.1,
                          colors: [
                            Colors.transparent,
                            const Color(0xFFCC2020).withValues(alpha: 0.35),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 5, right: 5,
                    child: Container(
                      width: 22, height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFCC2020).withValues(alpha: 0.9),
                        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 4)],
                      ),
                      child: const Icon(Icons.close, size: 13, color: Colors.white),
                    ),
                  ),
                ],

                // Pity star
                if (isPity && !discardMode)
                  Positioned(
                    bottom: 5, left: 5,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.amber.withValues(alpha: 0.6)),
                      ),
                      child: const Text('★', style: TextStyle(color: Colors.amber, fontSize: 7)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Color _typeColor(String t) => switch (t) {
    'offensive' => AppColors.offensive, 'defensive' => AppColors.defensive,
    'support'   => AppColors.support,   'utility'   => AppColors.utility,
    _ => AppColors.primary,
  };
  static Color _cardBgColor(String t) => switch (t) {
    'offensive' => const Color(0xFF5A0A0A), 'defensive' => const Color(0xFF0A1A5A),
    'support'   => const Color(0xFF0A3A15), 'utility'   => const Color(0xFF4A2E05),
    _ => const Color(0xFF1A0F3A),
  };
  static String _typeIcon(String t) => switch (t) {
    'offensive' => '⚔', 'defensive' => '🛡', 'support' => '💚', 'utility' => '⚡', _ => '✦',
  };
}

class _PetDot extends StatelessWidget {
  final String name;
  const _PetDot({required this.name});

  @override
  Widget build(BuildContext context) => Container(
        width: 18, height: 18,
        decoration: BoxDecoration(
          shape: BoxShape.circle, color: Colors.black38,
          border: Border.all(color: Colors.white30, width: 1),
        ),
        child: Center(
          child: Text(name[0], style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900)),
        ),
      );
}

// ── Assignment dots ───────────────────────────────────────────────────────────

class _AssignmentDots extends StatelessWidget {
  final PveBattleViewModel vm;
  const _AssignmentDots({required this.vm});

  @override
  Widget build(BuildContext context) {
    final living = vm.playerTeam.where((p) => !p.isFainted).toList();
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Text('CARDS', style: TextStyle(color: Colors.white30, fontSize: 7, letterSpacing: 1)),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: living.map((p) {
            final assigned  = vm.pendingSkills[p.id] ?? [];
            final done      = assigned.isNotEmpty;
            final cardCount = vm.cardsInHandFor(p.id);
            final isSelected = vm.selectedPetId == p.id;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(left: 4),
              width: 24, height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done
                    ? AppColors.accent.withValues(alpha: 0.25)
                    : cardCount == 0
                        ? Colors.white.withValues(alpha: 0.04)
                        : Colors.white10,
                border: Border.all(
                  color: isSelected
                      ? AppColors.accent
                      : done
                          ? AppColors.accent.withValues(alpha: 0.55)
                          : cardCount == 0
                              ? Colors.white12
                              : Colors.white.withValues(alpha: 0.18),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: done
                    // Show number of assigned cards (×N)
                    ? Text('×${assigned.length}',
                        style: const TextStyle(color: AppColors.accent, fontSize: 9, fontWeight: FontWeight.w900))
                    : cardCount == 0
                        ? const Text('–', style: TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.w700))
                        : Text(
                            '$cardCount',
                            style: TextStyle(
                              color: isSelected ? AppColors.accent : Colors.white54,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ── End Turn button ───────────────────────────────────────────────────────────

class _EndTurnButton extends StatelessWidget {
  final PveBattleViewModel vm;
  final WidgetRef ref;
  const _EndTurnButton({required this.vm, required this.ref});

  @override
  Widget build(BuildContext context) {
    if (vm.isBattleOver) {
      return _btn(
        label: 'Results',
        active: true,
        gold: false,
        onTap: () => context.go(Routes.battleResult, extra: BattleResultArgs(
          outcome: vm.outcome ?? 'draw',
          totalRounds: vm.currentRound,
          playerTeamName: vm.playerTeamName,
          enemyTeamName: vm.enemyTeamName,
        )),
      );
    }

    final allDone   = vm.allSkillsAssigned;
    final resolving = vm.isResolving;

    return _btn(
      label: 'End Turn',
      active: !resolving,
      gold: allDone,
      loading: resolving,
      onTap: resolving
          ? null
          : () => ref.read(pveBattleProvider.notifier).executeRound(),
    );
  }

  Widget _btn({
    required String label,
    required bool active,
    required bool gold,
    VoidCallback? onTap,
    bool loading = false,
  }) {
    final bg = gold
        ? const Color(0xFFD4A020)
        : active
            ? const Color(0xFF5A4510)
            : const Color(0xFF2E2008);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 94,
        height: 46,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: gold
                ? Colors.white.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.15),
            width: 1.5,
          ),
          boxShadow: gold
              ? [BoxShadow(color: const Color(0xFFD4A020).withValues(alpha: 0.5),
                  blurRadius: 10, spreadRadius: 1, offset: const Offset(0, 2))]
              : null,
        ),
        child: Center(
          child: loading
              ? const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white60),
                )
              : Text(
                  label,
                  style: GoogleFonts.rajdhani(
                    color: active ? Colors.white : Colors.white30,
                    fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 0.5,
                  ),
                ),
        ),
      ),
    );
  }
}
