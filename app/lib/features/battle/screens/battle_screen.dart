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
import '../data/creature_registry.dart';
import '../providers/pve_battle_provider.dart';
import '../providers/battle_view_model.dart';
import '../widgets/pet_character_widget.dart';
import '../widgets/battle_background_widget.dart';
import '../widgets/pet_sprite_widget.dart';
import '../widgets/projectile_widget.dart';
import 'battle_result_screen.dart';

// ── Route args ────────────────────────────────────────────────────────────────

class BattleScreenArgs {
  final String  playerTeamName;
  final String  enemyTeamName;
  final String? stageId; // non-null for PvE stage battles
  const BattleScreenArgs({
    this.playerTeamName = 'My Team',
    this.enemyTeamName  = 'Rivals',
    this.stageId,
  });
}

// ── Constants ─────────────────────────────────────────────────────────────────

const _kRoundSeconds  = 30;
const _kSpriteBase    = 58.0;

/// Slime chimera used as the floating-soul sprite for fainted pets.
const _kSoulConfig = PetCharacterConfig(
  texturePath:       'assets/sprites/aquatic_full.png', // Flame fallback (unused on native)
  spineAtlasPath:    'assets/spines/soul/slime.atlas',
  spineSkeletonPath: 'assets/spines/soul/slime.json',
);

/// Depth scaling: front is biggest & brightest, back is smallest & dimmer.
const _kScaleByPos    = [1.50, 1.50, 1.50];
const _kOpacityByPos  = [1.00, 1.00, 1.00];

/// Battlefield positions as (left%, top%) fractions.
/// Player faces right — front pet is closest to the centre line.
/// Enemy mirrors.
// Y capped at ~0.42 so the back pets don't overflow below the card panel
// or off the bottom of the screen in landscape on iPhone 17.
const _kPlayerPos = [
  Offset(0.23, 0.32), // FRONT
  Offset(0.10, 0.08), // MID
  Offset(0.02, 0.42), // BACK
];
const _kEnemyPos = [
  Offset(0.60, 0.32), // FRONT
  Offset(0.76, 0.08), // MID
  Offset(0.87, 0.42), // BACK
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
    // Publish args so pveBattleProvider can read stageId before building.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(battleArgsProvider.notifier).state = widget.args;
    });

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
              stageId: widget.args.stageId,
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

    // Battle screen is landscape-only. If the device hasn't rotated yet
    // (simulator: Cmd+← to rotate), show a hint instead of overflowing.
    final size = MediaQuery.sizeOf(context);
    if (size.width < size.height) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.screen_rotation, color: Colors.white54, size: 48),
              const SizedBox(height: 16),
              Text(
                'Rotate to landscape',
                style: GoogleFonts.rajdhani(
                  color: Colors.white70, fontSize: 20, fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Card panel height — cards float over the lower battlefield.
    const double panelH = 160;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Background ──────────────────────────────────────────────────────
          const BattleBackgroundWidget(),

          // ── HUD + full-height battlefield ──────────────────────────────────
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _TopHUD(vm: vm, timer: _timer),
                Expanded(child: _Battlefield(vm: vm)),
              ],
            ),
          ),

          // ── Battle feed — floats just above the card panel ─────────────────
          if (!vm.isResolving)
            Positioned(
              left: 0, right: 0,
              bottom: panelH,
              child: _BattleFeed(log: vm.roundLog),
            ),

          // ── Card panel — overlay at the bottom ─────────────────────────────
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: SafeArea(
              top: false,
              child: _BottomPanel(vm: vm, ref: ref, timer: _timer),
            ),
          ),

          // ── Discard popup ───────────────────────────────────────────────────
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
// Numbered creature icons matching the Axie reference UI style.

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
              padding: EdgeInsets.symmetric(horizontal: 1),
              child: Icon(Icons.chevron_right, size: 9, color: Colors.white24),
            ),
          _OrderBadge(entry: alive[i], number: i + 1, isFirst: i == 0),
        ],
      ],
    );
  }
}

class _OrderBadge extends StatelessWidget {
  final TurnOrderEntry entry;
  final int  number;
  final bool isFirst;
  const _OrderBadge({required this.entry, required this.number, required this.isFirst});

  @override
  Widget build(BuildContext context) {
    final c    = entry.isPlayer ? AppColors.accent : AppColors.offensive;
    final size = isFirst ? 32.0 : 26.0;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Creature class icon circle
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: size, height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: c.withValues(alpha: isFirst ? 0.30 : 0.15),
            border: Border.all(color: c, width: isFirst ? 2.0 : 1.5),
            boxShadow: isFirst
                ? [BoxShadow(color: c.withValues(alpha: 0.6), blurRadius: 8, spreadRadius: 2)]
                : null,
          ),
          child: ClipOval(
            child: entry.texturePath != null
                ? Image.asset(
                    entry.texturePath!,
                    width: size, height: size,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Center(
                      child: Text(entry.name[0],
                          style: TextStyle(color: Colors.white,
                              fontSize: isFirst ? 13 : 10,
                              fontWeight: FontWeight.w900)),
                    ),
                  )
                : Center(
                    child: Text(entry.name[0],
                        style: TextStyle(color: Colors.white,
                            fontSize: isFirst ? 13 : 10,
                            fontWeight: FontWeight.w900)),
                  ),
          ),
        ),
        // Turn number badge
        Positioned(
          top: -4, left: -4,
          child: Container(
            width: 14, height: 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c,
              border: Border.all(color: Colors.black, width: 1),
              boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 2)],
            ),
            child: Center(
              child: Text('$number',
                  style: const TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.w900)),
            ),
          ),
        ),
      ],
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

// ── Floating damage number data ───────────────────────────────────────────────

class _FloatNum {
  final String id;
  final String text;
  final Color  color;
  final double x;
  final double y;
  final double jitter; // horizontal drift so numbers don't stack
  const _FloatNum({required this.id, required this.text,
      required this.color, required this.x, required this.y,
      this.jitter = 0.0});
}

// ── Battlefield state ─────────────────────────────────────────────────────────

class _BattlefieldState extends ConsumerState<_Battlefield> {
  final List<ProjectileInstance> _projectiles = [];
  final List<_FloatNum>          _floatNums   = [];
  int _nextId = 0;
  Set<String> _lastAttackIds = {};

  @override
  void didUpdateWidget(_Battlefield old) {
    super.didUpdateWidget(old);
    _maybeSpawnProjectiles(widget.vm);
    _maybeSpawnFloatNums(old.vm, widget.vm);
  }

  void _maybeSpawnFloatNums(PveBattleViewModel oldVm, PveBattleViewModel newVm) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      if (box == null) return;
      final w = box.size.width;
      final h = box.size.height;
      final rng = math.Random();

      final nums = <_FloatNum>[];

      void check(List<PetViewModel> oldTeam, List<PetViewModel> newTeam,
          List<Offset> positions) {
        for (var i = 0; i < newTeam.length && i < oldTeam.length; i++) {
          final delta = newTeam[i].hp - oldTeam[i].hp;
          if (delta == 0) continue;
          final frac = positions[i.clamp(0, 2)];
          final x = w * frac.dx + 30;
          final y = h * frac.dy - 10;

          if (delta < 0) {
            final wasPoisoned = oldTeam[i].activeDebuffs.contains('poisoned');
            // Crit heuristic: damage > 70 (above normal single-hit max ~65 + class bonus)
            final isCrit = delta.abs() > 70 && !wasPoisoned;
            final Color dmgColor = wasPoisoned && (delta.abs() % 4 == 0)
                ? const Color(0xFFB44FD4)   // purple — poison tick
                : isCrit
                    ? const Color(0xFFFFAA00) // orange — critical hit
                    : const Color(0xFFFF3333); // red — normal damage
            final text = isCrit ? '★${delta}' : '$delta';
            nums.add(_FloatNum(
              id: '${_nextId++}', text: text, color: dmgColor,
              x: x, y: y, jitter: (rng.nextDouble() - 0.5) * 24,
            ));
          }
          if (delta > 0) {
            nums.add(_FloatNum(
              id: '${_nextId++}', text: '+$delta',
              color: const Color(0xFF44FF88),
              x: x, y: y, jitter: (rng.nextDouble() - 0.5) * 24,
            ));
          }
        }
      }

      check(oldVm.playerTeam, newVm.playerTeam, _kPlayerPos.toList());
      check(oldVm.enemyTeam,  newVm.enemyTeam,  _kEnemyPos.toList());

      if (nums.isNotEmpty) setState(() => _floatNums.addAll(nums));
    });
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
        final effectType = vm.petEffectVfx[petId];
        final cfg = resolveProjectileConfig(petId, effectType: effectType);

        // Determine start (actor center).
        final isPlayer = petId.startsWith('bayani');
        final attackerPositions = isPlayer ? _kPlayerPos : _kEnemyPos;

        // Find which slot the attacker is in
        final team = isPlayer ? vm.playerTeam : vm.enemyTeam;
        final attackerIdx = team.indexWhere((p) => p.id == petId);
        if (attackerIdx < 0) continue;

        final startFrac = attackerPositions[attackerIdx];

        final spriteOffset = 29.0; // half the sprite visual centre offset
        final start = Offset(w * startFrac.dx + spriteOffset, h * startFrac.dy + spriteOffset);

        // Support effects should feel self/ally-centered instead of attack-like.
        Offset end = start;
        if (!_isSelfCenteredEffect(effectType)) {
          final targetPositions = isPlayer ? _kEnemyPos : _kPlayerPos;
          final targetTeam      = isPlayer ? vm.enemyTeam : vm.playerTeam;
          final targetIdx = targetTeam.indexWhere((p) => !p.isFainted);
          if (targetIdx < 0) continue;
          final endFrac = targetPositions[targetIdx];
          end = Offset(w * endFrac.dx + spriteOffset, h * endFrac.dy + spriteOffset);
        }

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

  void _removeFloatNum(String id) {
    setState(() => _floatNums.removeWhere((n) => n.id == id));
  }

  bool _isSelfCenteredEffect(String? effectType) {
    return switch (effectType) {
      'heal' => true,
      'shield' => true,
      'buff' => true,
      _ => false,
    };
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

            // Enemy pets — tappable to inspect skills
            for (var i = 0; i < vm.enemyTeam.length; i++)
              _placed(w, h, _kEnemyPos[i], _BattlePet(
                pet: vm.enemyTeam[i],
                isPlayer: false,
                isSelected: false,
                hasSkill: false,
                positionIndex: i,
                animState:   vm.petAnimStates[vm.enemyTeam[i].id],
                attackSlot:  vm.petAttackSlots[vm.enemyTeam[i].id],
                onTap: () => _PetInfoSheet.show(context, vm.enemyTeam[i]),
              )),

            // Player pets — tappable to inspect skills
            for (var i = 0; i < vm.playerTeam.length; i++)
              _placed(w, h, _kPlayerPos[i], _BattlePet(
                pet: vm.playerTeam[i],
                isPlayer: true,
                isSelected: false,
                hasSkill: vm.pendingSkills[vm.playerTeam[i].id]?.isNotEmpty ?? false,
                positionIndex: i,
                animState:   vm.petAnimStates[vm.playerTeam[i].id],
                attackSlot:  vm.petAttackSlots[vm.playerTeam[i].id],
                onTap: () => _PetInfoSheet.show(context, vm.playerTeam[i]),
              )),

            // Flying projectiles
            for (final p in _projectiles)
              ProjectileWidget(
                key:    ValueKey(p.id),
                data:   p,
                onDone: () => _removeProjectile(p.id),
              ),

            // Floating damage / heal numbers
            for (final n in _floatNums)
              _FloatingNumberWidget(
                key:    ValueKey(n.id),
                num:    n,
                onDone: () => _removeFloatNum(n.id),
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

// ── Floating number widget ────────────────────────────────────────────────────

class _FloatingNumberWidget extends StatefulWidget {
  final _FloatNum   num;
  final VoidCallback onDone;
  const _FloatingNumberWidget({super.key, required this.num, required this.onDone});

  @override
  State<_FloatingNumberWidget> createState() => _FloatingNumberWidgetState();
}

class _FloatingNumberWidgetState extends State<_FloatingNumberWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _rise;
  late final Animation<double>   _fade;
  late final Animation<double>   _scale;

  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300));
    _rise  = Tween(begin: 0.0, end: -72.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _fade  = Tween(begin: 1.0, end: 0.0).animate(
        CurvedAnimation(parent: _ctrl, curve: const Interval(0.5, 1.0)));
    _scale = Tween(begin: 1.6, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl,
            curve: const Interval(0.0, 0.4, curve: Curves.easeOutBack)));
    _ctrl.forward().then((_) => widget.onDone());
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final n = widget.num;
    return Positioned(
      left: n.x + n.jitter,
      top:  n.y,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => Opacity(
          opacity: _fade.value,
          child: Transform.translate(
            offset: Offset(0, _rise.value),
            child: Transform.scale(
              scale: _scale.value,
              child: Stack(
                children: [
                  Text(n.text, style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w900,
                    foreground: Paint()
                      ..style = PaintingStyle.stroke
                      ..strokeWidth = 3
                      ..color = Colors.black87,
                  )),
                  Text(n.text, style: TextStyle(
                    color: n.color, fontSize: 22, fontWeight: FontWeight.w900,
                  )),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
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
  final String? attackSlot;

  const _BattlePet({
    required this.pet,
    required this.isPlayer,
    required this.isSelected,
    required this.hasSkill,
    required this.positionIndex,
    this.onTap,
    this.animState,
    this.attackSlot,
  });

  @override
  Widget build(BuildContext context) {
    final scale   = _kScaleByPos[positionIndex.clamp(0, 2)];
    final opacity = _kOpacityByPos[positionIndex.clamp(0, 2)];
    final spriteSize = _kSpriteBase * scale;

    // Fainted pets show the floating soul — give it good visibility.
    final effectiveOpacity = pet.isFainted ? 0.88 : opacity;

    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: effectiveOpacity,
        child: Transform.scale(
          scale: scale,
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: spriteSize + 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Hide HP bar for fainted souls — show it for living pets only.
                if (!pet.isFainted)
                  _FloatingHpBar(pet: pet, width: spriteSize + 14),
                if (!pet.isFainted) const SizedBox(height: 3),
                _Sprite(
                  pet: pet,
                  size: spriteSize,
                  isSelected: isSelected,
                  hasSkill: hasSkill,
                  isPlayer: isPlayer,
                  animState:  animState,
                  attackSlot: attackSlot,
                ),
                const SizedBox(height: 2),
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
    final statusIcons = _buildStatusIcons();

    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── HP + Shield row ─────────────────────────────────────
          Row(
            children: [
              const Icon(Icons.favorite, size: 9, color: Color(0xFF66FF88)),
              const SizedBox(width: 2),
              Text('${pet.hp}',
                  style: const TextStyle(
                      color: Color(0xFF66FF88), fontSize: 9, fontWeight: FontWeight.w800)),
              const Spacer(),
              if (pet.shield > 0) ...[
                const Icon(Icons.shield, size: 9, color: AppColors.shieldGold),
                const SizedBox(width: 1),
                Text('${pet.shield}',
                    style: const TextStyle(
                        color: AppColors.shieldGold, fontSize: 9, fontWeight: FontWeight.w800)),
              ],
            ],
          ),
          const SizedBox(height: 2),
          HpBar(current: pet.hp, max: pet.maxHp, height: 4),

          // ── Status effects row (only when active) ───────────────
          if (statusIcons.isNotEmpty) ...[
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: statusIcons
                  .map((s) => Padding(
                        padding: const EdgeInsets.only(right: 3),
                        child: s,
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildStatusIcons() {
    final icons = <Widget>[];

    // Buffs — text chips (no sprite assets for these)
    if (pet.activeBuffs.contains('attackUp'))  { icons.add(_textChip('ATK+', const Color(0xFFFF6B35))); }
    if (pet.activeBuffs.contains('defenseUp')) { icons.add(_textChip('DEF+', const Color(0xFF4FC3F7))); }
    if (pet.activeBuffs.contains('speedUp'))   { icons.add(_textChip('SPD+', const Color(0xFF81D4FA))); }
    if (pet.activeBuffs.contains('energized')) { icons.add(_spriteChip('assets/images/status/energy.png')); }
    if (pet.activeBuffs.contains('regen'))     { icons.add(_spriteChip('assets/images/status/regen.png')); }

    // Debuffs — sprite chips where available
    if (pet.activeDebuffs.contains('stunned'))     { icons.add(_spriteChip('assets/images/status/stun.png')); }
    if (pet.activeDebuffs.contains('poisoned'))    { icons.add(_textChip('☠×${pet.poisonStacks}', const Color(0xFF7CFC00))); }
    if (pet.activeDebuffs.contains('burned'))      { icons.add(_spriteChip('assets/images/status/burn.png')); }
    if (pet.activeDebuffs.contains('attackDown'))  { icons.add(_textChip('ATK-', Colors.red.shade300)); }
    if (pet.activeDebuffs.contains('defenseDown')) { icons.add(_spriteChip('assets/images/status/def_down.png')); }
    if (pet.activeDebuffs.contains('speedDown'))   { icons.add(_spriteChip('assets/images/status/slow.png')); }

    return icons;
  }

  static Widget _spriteChip(String assetPath) => SizedBox(
        width: 14, height: 14,
        child: Image.asset(assetPath, fit: BoxFit.contain),
      );

  static Widget _textChip(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: color.withValues(alpha: 0.65), width: 0.8),
        ),
        child: Text(label,
            style: TextStyle(
                color: color, fontSize: 6, fontWeight: FontWeight.w800,
                letterSpacing: 0.3)),
      );
}

// ── Pet sprite ────────────────────────────────────────────────────────────────

class _Sprite extends StatelessWidget {
  final PetViewModel pet;
  final double size;
  final bool isSelected;
  final bool hasSkill;
  final bool isPlayer;
  final PetCharacterAnimState? animState;
  final String? attackSlot;

  const _Sprite({
    required this.pet,
    required this.size,
    required this.isSelected,
    required this.hasSkill,
    required this.isPlayer,
    this.animState,
    this.attackSlot,
  });

  @override
  Widget build(BuildContext context) {
    final color = _petColor(pet.name);

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        // Ground shadow
        Positioned(
          bottom: -8,
          child: Container(
            width: size * 1.2,
            height: 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.3),
            ),
          ),
        ),

        // Sprite body
        // Priority: Spine animation (native only) → 384×384 portrait texture (Flame)
        //           → spritesheet → placeholder circle.
        // Fainted → floating soul (slime chimera Spine animation).
        if (pet.isFainted)
          PetCharacterWidget(
            config:         _kSoulConfig,
            size:           size,
            animState:      PetCharacterAnimState.idle,
            flipHorizontal: isPlayer,
          )
        else if (pet.characterConfig != null)
          PetCharacterWidget(
            config:         pet.characterConfig!,
            size:           size,
            flipHorizontal: isPlayer,
            animState:      animState ?? PetCharacterAnimState.idle,
            attackSlot:     attackSlot,
          )
        else
          PetSpriteWidget(
            config:         pet.spriteConfig,
            size:           size,
            flipHorizontal: isPlayer,
            petName:        pet.name,
            petColor:       color,
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
    // Hide the deck during round resolution — gives the battlefield full screen.
    if (vm.isResolving) return const SizedBox.shrink();

    return SizedBox(
      height: 160,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Translucent dark tray — no wood background so the battlefield shows through
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.0),
                  Colors.black.withValues(alpha: 0.75),
                ],
              ),
            ),
          ),
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
    final living = vm.playerTeam.where((p) => !p.isFainted).toList();

    // Build a flat ordered list of (pet, card) pairs grouped by character.
    final entries = <(PetViewModel, CardViewModel)>[];
    for (final pet in living) {
      for (final card in vm.hand.where((c) => c.ownerPetId == pet.id)) {
        entries.add((pet, card));
      }
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(width: 8),
        Center(child: _EnergyOrb(energy: vm.playerTeamEnergy, maxEnergy: kTeamEnergyCap)),
        const SizedBox(width: 6),

        if (!vm.isBattleOver)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Single unified card scroll ──────────────────────────────
                Expanded(
                  child: entries.isEmpty
                      ? const Center(
                          child: Text('No cards drawn',
                              style: TextStyle(color: Colors.white30, fontSize: 11)),
                        )
                      : ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.only(left: 6, top: 4),
                          itemCount: entries.length,
                          itemBuilder: (_, i) {
                            final (pet, card) = entries[i];
                            final assigned    = vm.pendingSkills[pet.id] ?? [];
                            final isAssigned  = assigned.contains(card.instanceId);
                            final isNew       = vm.newCardIds.contains(card.instanceId);

                            // Thin group separator before the first card of each
                            // new character (except the very first card).
                            final prevPet = i > 0 ? entries[i - 1].$1 : null;
                            final needsSep = prevPet != null && prevPet.id != pet.id;

                            Widget w = Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (needsSep)
                                  Container(
                                    width: 1, height: 100,
                                    margin: const EdgeInsets.only(right: 6),
                                    color: Colors.white.withValues(alpha: 0.18),
                                  ),
                                _SkillCard(
                                  trait:       card.trait,
                                  petName:     card.ownerPetName,
                                  isSelected:  isAssigned,
                                  isPity:      card.isPity,
                                  cardArtPath: card.cardArtPath,
                                  onTap: () {
                                    final n = ref.read(pveBattleProvider.notifier);
                                    n.selectPet(pet.id);
                                    n.assignSkill(card.instanceId);
                                  },
                                ),
                                const SizedBox(width: 5),
                              ],
                            );

                            if (isNew) {
                              w = _CardEntrance(
                                key:   ValueKey(card.instanceId),
                                delay: Duration(milliseconds: i * 80),
                                child: w,
                              );
                            }
                            return w;
                          },
                        ),
                ),

                // ── Character labels — one per living pet ───────────────────
                SizedBox(
                  height: 22,
                  child: Row(
                    children: [
                      for (final pet in living)
                        Expanded(
                          child: GestureDetector(
                            onTap: () =>
                                ref.read(pveBattleProvider.notifier).selectPet(pet.id),
                            child: _CharacterLabel(pet: pet, vm: vm),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
              ],
            ),
          ),

        const SizedBox(width: 8),
        Center(child: _EndTurnButton(vm: vm, ref: ref)),
        const SizedBox(width: 8),
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

    final cardW = discardMode ? 100.0 : 90.0;
    final cardH = discardMode ? 148.0 : 128.0;
    const lift  = -10.0;

    return GestureDetector(
      onTap: usable ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 110),
        width:  cardW,
        height: cardH,
        transform: isSelected
            ? (Matrix4.identity()..translateByDouble(0, lift, 0, 1))
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
                      ? Image.asset(
                          cardArtPath!,
                          fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
                          errorBuilder: (_, __, ___) => Container(color: _cardBgColor(trait.typeName)),
                        )
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
                          _EffectBadge(trait: trait),
                          const SizedBox(width: 2),
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
                    child: Text(
                      '${_typeIcon(trait.typeName)} ${_partIcon(trait.partName)}',
                      style: const TextStyle(fontSize: 9),
                    ),
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
  static String _partIcon(String p) => switch (p) {
    'horn' => '🦏',
    'back' => '🎒',
    'tail' => '🦚',
    'mouth' => '👄',
    'body' => '🧬',
    _ => '🧩',
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

// ── Character label (bottom of card panel) ────────────────────────────────────

class _CharacterLabel extends StatelessWidget {
  final PetViewModel       pet;
  final PveBattleViewModel vm;
  const _CharacterLabel({required this.pet, required this.vm});

  @override
  Widget build(BuildContext context) {
    final assigned = vm.pendingSkills[pet.id] ?? [];
    final isDone   = assigned.isNotEmpty;
    final isActive = vm.selectedPetId == pet.id;
    final cardCount = vm.hand.where((c) => c.ownerPetId == pet.id).length;
    final color    = _petColor(pet.name);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: isDone
            ? AppColors.accent.withValues(alpha: 0.22)
            : isActive
                ? color.withValues(alpha: 0.18)
                : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDone
              ? AppColors.accent.withValues(alpha: 0.65)
              : isActive
                  ? color.withValues(alpha: 0.55)
                  : Colors.transparent,
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              pet.name,
              style: TextStyle(
                color: isDone ? AppColors.accent
                     : isActive ? Colors.white
                     : Colors.white38,
                fontSize: 9, fontWeight: FontWeight.w700,
              ),
              maxLines: 1, overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            isDone ? '✓${assigned.length}' : '$cardCount',
            style: TextStyle(
              color: isDone ? AppColors.accent
                   : isActive ? Colors.white54
                   : Colors.white24,
              fontSize: 9, fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
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

// ── Pet info sheet ────────────────────────────────────────────────────────────

// ── Pet info sheet — Axie-style layout ───────────────────────────────────────
//
// Layout mirrors the Axie "My Axies" panel:
//   • Stats bar  (Health / Speed / Shield / Energy)
//   • Left col   — pet name + class icon + parts list with part-icon sprites
//   • Right area — 2×2 card grid (card art + energy badge + name + effect + desc)

class _PetInfoSheet {
  static void show(BuildContext context, PetViewModel pet) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _PetInfoContent(pet: pet),
    );
  }
}

class _PetInfoContent extends StatelessWidget {
  final PetViewModel pet;
  const _PetInfoContent({required this.pet});

  @override
  Widget build(BuildContext context) {
    final def      = kCreatureRegistry[pet.id];
    final cls      = def?.className ?? 'plant';
    final clsColor = _clsColor(cls);
    final traitMap = {for (final t in pet.traits) t.partName: t};

    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.50,
      maxChildSize: 0.96,
      expand: false,
      builder: (_, ctrl) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF2C1F14),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          border: Border(top: BorderSide(color: clsColor, width: 2)),
        ),
        child: Column(children: [
          // Drag handle
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            decoration: BoxDecoration(
              color: Colors.white24, borderRadius: BorderRadius.circular(2)),
          ),
          // Stats bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.black38,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _statCol(Icons.favorite,    '${pet.hp}/${pet.maxHp}', 'HEALTH', const Color(0xFF66FF88)),
                  _statCol(Icons.bolt,        '${pet.speed}',           'SPEED',  const Color(0xFFFFCC44)),
                  _statCol(Icons.auto_awesome,'${pet.skill}',           'SKILL',  const Color(0xFF88CCFF)),
                  _statCol(Icons.local_fire_department, '${pet.morale}','MORALE', const Color(0xFFFF9944)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Main body
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Left: pet name + class icon + parts list ─────────────────
                SizedBox(
                  width: 138,
                  child: ListView(
                    controller: ctrl,
                    padding: const EdgeInsets.fromLTRB(12, 2, 8, 16),
                    children: [
                      Row(children: [
                        Expanded(
                          child: Text(pet.name,
                            style: GoogleFonts.rajdhani(
                              color: Colors.white, fontSize: 20,
                              fontWeight: FontWeight.w800),
                            overflow: TextOverflow.ellipsis),
                        ),
                        Image.asset(
                          'assets/images/icons/mini-$cls.png',
                          width: 22, height: 22,
                          errorBuilder: (_, __, ___) => const SizedBox(),
                        ),
                      ]),
                      const SizedBox(height: 10),
                      Text('PARTS',
                        style: GoogleFonts.rajdhani(
                          color: Colors.white38, fontSize: 10,
                          fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                      const SizedBox(height: 6),
                      if (def != null)
                        for (final part in def.parts)
                          _PartRow(part: part,
                              traitName: traitMap[part.partType]?.name ?? part.id),
                    ],
                  ),
                ),
                // Divider
                Container(
                  width: 1,
                  color: Colors.white10,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                ),
                // ── Right: 2×2 card grid (LayoutBuilder for responsive sizing) ──
                Expanded(
                  child: def == null
                      ? const SizedBox.shrink()
                      : LayoutBuilder(
                          builder: (ctx, constraints) {
                            // Fit 2 cards per row; height fills available space
                            // divided by 2 rows. Respect portrait aspect ratio (0.62)
                            // but never overflow vertically.
                            final availW = constraints.maxWidth - 28.0; // left+right padding + gap
                            final availH = constraints.maxHeight - 22.0; // top+bottom padding + gap
                            final cardWByRatio = availW / 2;
                            final cardHByRatio = cardWByRatio / 0.62;
                            final cardHBySpace = availH / 2;
                            final cardH = math.min(cardHByRatio, cardHBySpace);
                            final cardW = cardH * 0.62;

                            Widget card(int i) => SizedBox(
                              width: cardW, height: cardH,
                              child: _InfoCard(
                                part: def.parts[i],
                                trait: traitMap[def.parts[i].partType],
                              ),
                            );

                            return Padding(
                              padding: const EdgeInsets.fromLTRB(6, 4, 10, 12),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                    card(0), const SizedBox(width: 6), card(1),
                                  ]),
                                  const SizedBox(height: 6),
                                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                    card(2), const SizedBox(width: 6), card(3),
                                  ]),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  static Widget _statCol(IconData icon, String val, String label, Color c) =>
      Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: c),
        const SizedBox(height: 2),
        Text(val,  style: TextStyle(color: c, fontSize: 13, fontWeight: FontWeight.w900)),
        Text(label, style: const TextStyle(
            color: Colors.white38, fontSize: 7, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
      ]);

  static Color _clsColor(String cls) => switch (cls) {
    'plant'   => const Color(0xFF4CAF50),
    'aquatic' => const Color(0xFF29B6F6),
    'beast'   => const Color(0xFFFF9800),
    'reptile' => const Color(0xFF66BB6A),
    'bird'    => const Color(0xFFFF80AB),
    'bug'     => const Color(0xFFFF5252),
    _         => const Color(0xFF9C27B0),
  };
}

// ── Parts list row ────────────────────────────────────────────────────────────

class _PartRow extends StatelessWidget {
  final PartDefinition part;
  final String traitName;
  const _PartRow({required this.part, required this.traitName});

  static const _kPartColor = {
    'horn':  Color(0xFFFF5533),
    'back':  Color(0xFF4488CC),
    'tail':  Color(0xFF44BB88),
    'mouth': Color(0xFFCC8844),
  };

  @override
  Widget build(BuildContext context) {
    final color    = _kPartColor[part.partType] ?? Colors.white54;
    final iconPath = 'assets/images/part-icons/${part.className}-${part.partType}.png';

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(children: [
        Container(
          width: 30, height: 30,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 1.2),
          ),
          child: ClipOval(
            child: Image.asset(
              iconPath, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Icon(Icons.category, size: 14, color: color),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(traitName,
            style: GoogleFonts.rajdhani(
              color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
            overflow: TextOverflow.ellipsis),
        ),
      ]),
    );
  }
}

// ── Skill card (Axie card style) ──────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final PartDefinition  part;
  final TraitViewModel? trait;
  const _InfoCard({required this.part, this.trait});

  static Color _borderColor(String? typeName) => switch (typeName) {
    'offensive' => const Color(0xFFCC4433),
    'defensive' => const Color(0xFF3388CC),
    'support'   => const Color(0xFF33AA66),
    'utility'   => const Color(0xFF8833CC),
    _           => const Color(0xFF555555),
  };

  @override
  Widget build(BuildContext context) {
    final border = _borderColor(trait?.typeName);
    final cost   = trait?.energyCost ?? 0;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border, width: 1.5),
        color: Colors.black,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(fit: StackFit.expand, children: [

        // ── Card art background ─────────────────────────────────────
        Image.asset(part.cardArtPath, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(color: Colors.black38)),

        // ── Top gradient (name visibility) ────────────────────────
        Positioned(
          top: 0, left: 0, right: 0, height: 36,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Colors.black87, Colors.transparent],
              ),
            ),
          ),
        ),

        // ── Bottom gradient (description visibility) ───────────────
        Positioned(
          bottom: 0, left: 0, right: 0, height: 64,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter, end: Alignment.topCenter,
                colors: [Colors.black, Colors.black54, Colors.transparent],
                stops: [0.0, 0.6, 1.0],
              ),
            ),
          ),
        ),

        // ── Energy cost badge ─────────────────────────────────────
        Positioned(
          top: 5, left: 5,
          child: Container(
            width: 22, height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFF9800),
              border: Border.all(color: Colors.white70, width: 1),
              boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 3)],
            ),
            child: Center(
              child: Text('$cost',
                style: const TextStyle(
                  color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
            ),
          ),
        ),

        // ── Skill name (top, after energy badge) ─────────────────
        Positioned(
          top: 6, left: 30, right: 5,
          child: Text(trait?.name ?? '',
            style: GoogleFonts.rajdhani(
              color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w800,
              shadows: const [Shadow(blurRadius: 3, color: Colors.black)]),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        ),

        // ── Effect badge (damage / shield / heal value) ───────────
        if (trait != null && trait!.effectIconValue > 0)
          Positioned(
            bottom: 24, left: 5,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(4),
              ),
              child: _EffectBadge(trait: trait!),
            ),
          ),

        // ── Description ───────────────────────────────────────────
        if (trait != null)
          Positioned(
            bottom: 4, left: 5, right: 5,
            child: Text(trait!.description,
              style: const TextStyle(
                color: Colors.white70, fontSize: 6.5, height: 1.25),
              maxLines: 3, overflow: TextOverflow.ellipsis),
          ),
      ]),
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

// ── Effect icon badge shown on skill cards ────────────────────────────────────

class _EffectBadge extends StatelessWidget {
  final TraitViewModel trait;
  const _EffectBadge({required this.trait});

  static const _kS = 'assets/images/status/';

  @override
  Widget build(BuildContext context) {
    final key   = trait.effectIconKey;
    final val   = trait.effectIconValue;
    final icon  = _icon(key);
    final color = _color(key);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        if (val > 0) ...[
          const SizedBox(width: 2),
          Text('$val', style: TextStyle(
            color: color, fontSize: 11, fontWeight: FontWeight.w900,
            shadows: const [Shadow(blurRadius: 3, color: Colors.black)],
          )),
        ],
      ],
    );
  }

  static Color _color(String key) => switch (key) {
    'damage' || 'aoe'            => const Color(0xFFFF5533),
    'heal'   || 'regen'          => const Color(0xFF44FF88),
    'shield' || 'def_up'         => const Color(0xFFFFD700),
    'shield_break'               => const Color(0xFFFFAA00),
    'poison'                     => const Color(0xFF66DD44),
    'burn'                       => const Color(0xFFFF6600),
    'stun'                       => const Color(0xFFBBDDFF),
    'atk_up'                     => const Color(0xFFFF8844),
    'atk_down' || 'def_down'     => const Color(0xFFFF4444),
    'spd_up'   || 'spd_down'     => const Color(0xFF88DDFF),
    'energized'                  => const Color(0xFF88CCFF),
    _                            => Colors.white70,
  };

  static Widget _icon(String key) {
    const s = 12.0;
    // burn.png = knight armor sprite  →  shield / def_up / shield_break
    // shield.png = dark teal potion   →  poison
    // regen.png = red round potion    →  heal / regen
    // stun.png = blue jellyfish       →  stun
    // slow.png = snowman              →  spd_down / freeze
    // def_down.png = cracked creature →  def_down / atk_down
    // energy.png = blue flask         →  energized
    return switch (key) {
      'damage'       => const Icon(Icons.flash_on,        size: s, color: Color(0xFFFF5533)),
      'aoe'          => const Icon(Icons.all_out,         size: s, color: Color(0xFFFF5533)),
      'heal'         => Image.asset('${_kS}regen.png',    width: s, height: s),
      'shield'       => Image.asset('${_kS}burn.png',     width: s, height: s),
      'shield_break' => Image.asset('${_kS}burn.png',     width: s, height: s,
                          color: const Color(0xFFFFAA00), colorBlendMode: BlendMode.modulate),
      'poison'       => Image.asset('${_kS}shield.png',   width: s, height: s),
      'burn'         => const Icon(Icons.local_fire_department, size: s, color: Color(0xFFFF6600)),
      'stun'         => Image.asset('${_kS}stun.png',     width: s, height: s),
      'regen'        => Image.asset('${_kS}regen.png',    width: s, height: s),
      'atk_up'       => const Icon(Icons.trending_up,    size: s, color: Color(0xFFFF8844)),
      'atk_down'     => Image.asset('${_kS}def_down.png', width: s, height: s),
      'def_up'       => Image.asset('${_kS}burn.png',     width: s, height: s,
                          color: const Color(0xFF88CCFF), colorBlendMode: BlendMode.modulate),
      'def_down'     => Image.asset('${_kS}def_down.png', width: s, height: s),
      'spd_up'       => const Icon(Icons.electric_bolt,  size: s, color: Color(0xFF88DDFF)),
      'spd_down'     => Image.asset('${_kS}slow.png',     width: s, height: s),
      'energized'    => Image.asset('${_kS}energy.png',   width: s, height: s),
      _              => const SizedBox(width: s),
    };
  }
}
