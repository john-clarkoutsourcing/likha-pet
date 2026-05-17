import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:likha_pet_battle_engine/energy_pool.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/hp_bar.dart';
import '../../battle/data/trait_card_catalog.dart';
import '../../battle/providers/battle_view_model.dart';
import '../../battle/services/battle_asset_warmup.dart';
import '../../battle/widgets/battle_background_widget.dart';
import '../../battle/widgets/classic_trait_card_widget.dart';
import '../../battle/widgets/dead_pet_effect.dart';
import '../../battle/widgets/pet_character_widget.dart';
import '../../battle/widgets/pet_renderer_widget.dart';
import '../../battle/widgets/pet_sprite_widget.dart';
import '../../battle/widgets/projectile_widget.dart';
import '../providers/pvp_battle_provider.dart';
import 'pvp_result_screen.dart';

// ── Layout constants ──────────────────────────────────────────────────────────
//
// PvP is the mirror of PvE:
//   PvE  → player LEFT  (x 0.10–0.30), enemy RIGHT (x 0.50–0.75)
//   PvP  → player RIGHT (x 0.55–0.75), enemy LEFT  (x 0.10–0.30)
//
// Sprites face their opponent, so flip logic is the inverse of PvE:
//   player  → flipHorizontal: false  (natural left-facing)
//   opponent → flipHorizontal: true  (mirror to face right)

const _kRoundSeconds = 30;
const _kPanelH = 182.0;
const _kPanelPeekH = 32.0;
const _kSpriteBase = 130.0;
const _kScaleByPos = [1.50, 1.50, 1.50];
const _kOpacityByPos = [1.00, 1.00, 1.00];

// Player on right — front nearest to centre.
const _kPlayerPos = [
  Offset(0.55, 0.22), // FRONT
  Offset(0.70, 0.03), // MID
  Offset(0.75, 0.35), // BACK
];
// Opponent on left — front nearest to centre.
const _kOpponentPos = [
  Offset(0.30, 0.22), // FRONT
  Offset(0.15, 0.03), // MID
  Offset(0.10, 0.35), // BACK
];

final Map<String, TraitCardCatalogEntry> _cardCatalogByTraitId = {
  for (final entry in TraitCardCatalog.build()) entry.traitId: entry,
};

// ── Screen ────────────────────────────────────────────────────────────────────

class PvpBattleScreen extends ConsumerStatefulWidget {
  const PvpBattleScreen({super.key});

  @override
  ConsumerState<PvpBattleScreen> createState() => _PvpBattleScreenState();
}

class _PvpBattleScreenState extends ConsumerState<PvpBattleScreen>
    with TickerProviderStateMixin {
  late final AnimationController _timer;
  bool _battleReady = false;
  bool _isDeckCollapsed = false;
  Future<void>? _warmupFuture;

  final List<Offset> _playerPos = List<Offset>.from(_kPlayerPos);
  final List<Offset> _opponentPos = List<Offset>.from(_kOpponentPos);

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(pvpBattleProvider.notifier).setBattlePositions(
            playerPos: _playerPos,
            enemyPos: _opponentPos,
          );
    });
  }

  @override
  void dispose() {
    _timer.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  void _autoEndTurn() {
    final vm = ref.read(pvpBattleProvider);
    if (vm.isBattleOver || vm.isResolving || vm.awaitingOpponent) return;
    ref.read(pvpBattleProvider.notifier).executeRound();
  }

  void _restartTimer() {
    _timer
      ..reset()
      ..forward();
  }

  void _ensureWarmup(PveBattleViewModel vm) {
    if (_battleReady || _warmupFuture != null) return;
    if (vm.playerTeam.isEmpty || vm.enemyTeam.isEmpty) return;
    _warmupFuture = BattleAssetWarmup.preload(
      context,
      pets: [...vm.playerTeam, ...vm.enemyTeam],
      hand: vm.hand,
    ).catchError((_) {}).whenComplete(() {
      if (!mounted) return;
      setState(() => _battleReady = true);
      _restartTimer();
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = ref.watch(pvpBattleProvider);
    _ensureWarmup(vm);

    if (!_battleReady) {
      return const _PvpLoadingScreen(message: 'Preparing battle assets…');
    }

    // Navigate to result when match ends.
    ref.listen(pvpBattleProvider, (prev, next) {
      if (next.pvpMatchEnd != null &&
          (prev == null || prev.pvpMatchEnd == null)) {
        context.go(
          Routes.pvpResult,
          extra: PvpResultArgs(
            result: next.pvpMatchEnd!,
            opponentName: next.enemyTeamName,
          ),
        );
      }
      if (next.isResolving) {
        _timer.stop();
        return;
      }
      final roundChanged = (prev?.currentRound ?? -1) != next.currentRound;
      final resolveFinished = (prev?.isResolving ?? false) && !next.isResolving;
      if ((roundChanged || resolveFinished) && !next.isBattleOver) {
        _restartTimer();
      }
    });

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
              Text('Rotate to landscape',
                  style: GoogleFonts.rajdhani(
                      color: Colors.white70,
                      fontSize: 20,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      );
    }

    final panelVisibleH = _isDeckCollapsed ? _kPanelPeekH : _kPanelH;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background
          const BattleBackgroundWidget(),

          // Battlefield
          Positioned.fill(
            child: _PvpBattlefield(
              vm: vm,
              playerPos: _playerPos,
              opponentPos: _opponentPos,
            ),
          ),

          // Top HUD
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              bottom: false,
              child: _TopHUD(vm: vm, timer: _timer),
            ),
          ),

          // Battle feed (above card panel)
          if (!vm.isResolving)
            Positioned(
              left: 0,
              right: 0,
              bottom: panelVisibleH,
              child: _BattleFeed(log: vm.roundLog),
            ),

          // Card panel
          AnimatedPositioned(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            left: 0, right: 0,
            bottom: _isDeckCollapsed ? -(_kPanelH - _kPanelPeekH) : 0,
            child: _BottomPanel(
              vm: vm,
              ref: ref,
              timer: _timer,
              isCollapsed: _isDeckCollapsed,
              onToggleCollapse: () =>
                  setState(() => _isDeckCollapsed = !_isDeckCollapsed),
            ),
          ),

          // Awaiting opponent overlay
          if (vm.awaitingOpponent)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: AppColors.accent),
                      SizedBox(height: 12),
                      Text('Waiting for opponent…',
                          style: TextStyle(
                              color: AppColors.textPrimary, fontSize: 16)),
                    ],
                  ),
                ),
              ),
            ),
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
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.82),
            Colors.black.withValues(alpha: 0.0),
          ],
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Opponent on left
          _TeamTag(name: vm.enemyTeamName, isPlayer: false),

          Expanded(
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'ROUND ${vm.currentRound}',
                          style: GoogleFonts.rajdhani(
                              color: Colors.white70,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2),
                        ),
                        const SizedBox(width: 8),
                        _RoundTimer(timer: timer),
                      ],
                    ),
                    const SizedBox(height: 3),
                    _AttackOrderStrip(vm: vm),
                  ],
                ),
              ),
            ),
          ),

          // Player on right
          _TeamTag(name: vm.playerTeamName, isPlayer: true),
        ],
      ),
    );
  }
}

class _TeamTag extends StatelessWidget {
  final String name;
  final bool isPlayer;
  const _TeamTag({required this.name, required this.isPlayer});

  @override
  Widget build(BuildContext context) {
    final color = isPlayer ? AppColors.accent : AppColors.offensive;
    final avatar = Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.2),
        border: Border.all(color: color, width: 2),
      ),
      child: Center(
        child: Text(name[0],
            style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w900)),
      ),
    );
    final label = Text(name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.rajdhani(
            color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700));

    // Opponent tag: avatar | name (left side)
    // Player tag:   name | avatar (right side)
    return isPlayer
        ? Row(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(width: 72, child: label),
            const SizedBox(width: 5),
            avatar,
          ])
        : Row(mainAxisSize: MainAxisSize.min, children: [
            avatar,
            const SizedBox(width: 5),
            SizedBox(width: 72, child: label),
          ]);
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
                  backgroundColor: Colors.white12),
              Text('$seconds',
                  style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      shadows: const [
                        Shadow(blurRadius: 3, color: Colors.black)
                      ])),
            ],
          ),
        );
      },
    );
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
  final int number;
  final bool isFirst;
  const _OrderBadge(
      {required this.entry, required this.number, required this.isFirst});

  @override
  Widget build(BuildContext context) {
    final c = entry.isPlayer ? AppColors.accent : AppColors.offensive;
    final size = isFirst ? 32.0 : 26.0;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: size,
          height: size,
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
                ? Image.asset(entry.texturePath!,
                    width: size, height: size, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Center(
                      child: Text(entry.name[0],
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: isFirst ? 13 : 10,
                              fontWeight: FontWeight.w900)),
                    ))
                : Center(
                    child: Text(entry.name[0],
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: isFirst ? 13 : 10,
                            fontWeight: FontWeight.w900))),
          ),
        ),
        Positioned(
          top: -4,
          left: -4,
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c,
              border: Border.all(color: Colors.black, width: 1),
              boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 2)],
            ),
            child: Center(
              child: Text('$number',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 7,
                      fontWeight: FontWeight.w900)),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Battlefield ───────────────────────────────────────────────────────────────

class _PvpBattlefield extends ConsumerStatefulWidget {
  final PveBattleViewModel vm;
  final List<Offset> playerPos;
  final List<Offset> opponentPos;
  const _PvpBattlefield({
      required this.vm,
      required this.playerPos,
      required this.opponentPos});

  @override
  ConsumerState<_PvpBattlefield> createState() => _PvpBattlefieldState();
}

class _FloatNum {
  final String id;
  final String text;
  final Color color;
  final double x;
  final double y;
  final double jitter;
  const _FloatNum({
    required this.id,
    required this.text,
    required this.color,
    required this.x,
    required this.y,
    this.jitter = 0.0,
  });
}

class _PvpBattlefieldState extends ConsumerState<_PvpBattlefield> {
  final List<ProjectileInstance> _projectiles = [];
  final List<_FloatNum> _floatNums = [];
  int _nextId = 0;
  Set<String> _lastAttackIds = {};

  @override
  void didUpdateWidget(_PvpBattlefield old) {
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

      void check(
        List<PetViewModel> oldTeam,
        List<PetViewModel> newTeam,
        List<Offset> positions,
      ) {
        for (var i = 0; i < newTeam.length && i < oldTeam.length; i++) {
          final delta = newTeam[i].hp - oldTeam[i].hp;
          if (delta == 0) continue;
          final frac = positions[i.clamp(0, 2)];
          final pos = Offset(w * frac.dx, h * frac.dy);
          final x = pos.dx + 30;
          final y = pos.dy - 10;

          if (delta < 0) {
            final wasPoisoned = oldTeam[i].activeDebuffs.contains('poisoned');
            final isCrit = delta.abs() > 70 && !wasPoisoned;
            final dmgColor = wasPoisoned
                ? const Color(0xFFB44FD4)
                : isCrit
                    ? const Color(0xFFFFAA00)
                    : const Color(0xFFFF3333);
            nums.add(_FloatNum(
              id: '${_nextId++}',
              text: isCrit ? '★$delta' : '$delta',
              color: dmgColor,
              x: x, y: y,
              jitter: (rng.nextDouble() - 0.5) * 24,
            ));
          } else {
            nums.add(_FloatNum(
              id: '${_nextId++}',
              text: '+$delta',
              color: const Color(0xFF44FF88),
              x: x, y: y,
              jitter: (rng.nextDouble() - 0.5) * 24,
            ));
          }
        }
      }

      check(oldVm.playerTeam, newVm.playerTeam, widget.playerPos);
      check(oldVm.enemyTeam, newVm.enemyTeam, widget.opponentPos);

      if (nums.isNotEmpty) setState(() => _floatNums.addAll(nums));
    });
  }

  void _maybeSpawnProjectiles(PveBattleViewModel vm) {
    if (vm.petAnimStates.isEmpty) { _lastAttackIds = {}; return; }
    final attackIds = vm.petAnimStates.keys.toSet();
    if (attackIds == _lastAttackIds) return;
    _lastAttackIds = attackIds;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      if (box == null) return;
      final w = box.size.width;
      final h = box.size.height;
      final newProjectiles = <ProjectileInstance>[];

      for (final petId in vm.petAnimStates.keys) {
        final effectType = vm.petEffectVfx[petId];
        if (effectType == null) continue;
        final cfg = resolveProjectileConfig(effectType: effectType);
        if (cfg == null) continue;

        final isPlayer = vm.playerTeam.any((p) => p.id == petId);
        final attackerPositions = isPlayer ? widget.playerPos : widget.opponentPos;
        final team = isPlayer ? vm.playerTeam : vm.enemyTeam;
        final attackerIdx = team.indexWhere((p) => p.id == petId);
        if (attackerIdx < 0) continue;

        const spriteOffset = 29.0;
        final startFrac = attackerPositions[attackerIdx];
        final start = Offset(
            w * startFrac.dx + spriteOffset, h * startFrac.dy + spriteOffset);

        Offset end = start;
        if (!_isSelfCenteredEffect(effectType)) {
          final targetPositions = isPlayer ? widget.opponentPos : widget.playerPos;
          final targetTeam = isPlayer ? vm.enemyTeam : vm.playerTeam;
          final targetIdx = targetTeam.indexWhere((p) => !p.isFainted);
          if (targetIdx < 0) continue;
          final endFrac = targetPositions[targetIdx];
          end = Offset(
              w * endFrac.dx + spriteOffset, h * endFrac.dy + spriteOffset);
        }

        newProjectiles.add(ProjectileInstance(
          id: '${_nextId++}',
          start: start,
          end: end,
          config: cfg,
        ));
      }

      if (newProjectiles.isNotEmpty) {
        setState(() => _projectiles.addAll(newProjectiles));
      }
    });
  }

  bool _isSelfCenteredEffect(String? t) =>
      t == 'heal' || t == 'shield' || t == 'buff';

  void _removeProjectile(String id) =>
      setState(() => _projectiles.removeWhere((p) => p.id == id));

  void _removeFloatNum(String id) =>
      setState(() => _floatNums.removeWhere((n) => n.id == id));

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;

    return LayoutBuilder(builder: (_, constraints) {
      final w = constraints.maxWidth;
      final h = constraints.maxHeight;

      return Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // Ground line
          Positioned(
            top: h * 0.52, left: 0, right: 0,
            child: Container(
              height: 1.5,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  Colors.transparent,
                  Colors.brown.shade700.withValues(alpha: 0.5),
                  Colors.transparent,
                ]),
              ),
            ),
          ),

          // Opponent pets (left side) — flipHorizontal: true (face right)
          for (var i = 0; i < vm.enemyTeam.length; i++)
            _placed(w, h, widget.opponentPos[i],
              _BattlePet(
                pet: vm.enemyTeam[i],
                flipHorizontal: true,
                isPlayer: false,
                hasSkill: false,
                positionIndex: i,
                animState: vm.petAnimStates[vm.enemyTeam[i].id],
                attackSlot: vm.petAttackSlots[vm.enemyTeam[i].id],
              ),
              dash: _dashPixels(vm: vm, petId: vm.enemyTeam[i].id,
                  isPlayerTeam: false, actorIndex: i,
                  actorPositions: widget.opponentPos,
                  targetPositions: widget.playerPos,
                  targetTeam: vm.playerTeam, w: w, h: h),
            ),

          // Player pets (right side) — flipHorizontal: false (face left)
          for (var i = 0; i < vm.playerTeam.length; i++)
            _placed(w, h, widget.playerPos[i],
              _BattlePet(
                pet: vm.playerTeam[i],
                flipHorizontal: false,
                isPlayer: true,
                hasSkill: vm.pendingSkills[vm.playerTeam[i].id]?.isNotEmpty ?? false,
                positionIndex: i,
                animState: vm.petAnimStates[vm.playerTeam[i].id],
                attackSlot: vm.petAttackSlots[vm.playerTeam[i].id],
              ),
              dash: _dashPixels(vm: vm, petId: vm.playerTeam[i].id,
                  isPlayerTeam: true, actorIndex: i,
                  actorPositions: widget.playerPos,
                  targetPositions: widget.opponentPos,
                  targetTeam: vm.enemyTeam, w: w, h: h),
            ),

          // Projectiles
          for (final p in _projectiles)
            ProjectileWidget(key: ValueKey(p.id), data: p,
                onDone: () => _removeProjectile(p.id)),

          // Floating numbers
          for (final n in _floatNums)
            _FloatingNumberWidget(key: ValueKey(n.id), num: n,
                onDone: () => _removeFloatNum(n.id)),
        ],
      );
    });
  }

  Widget _placed(double w, double h, Offset pos, Widget child,
      {Offset dash = Offset.zero}) {
    final p = Offset(w * pos.dx + dash.dx, h * pos.dy + dash.dy);
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
      left: p.dx,
      top: p.dy,
      child: child,
    );
  }

  Offset _dashPixels({
    required PveBattleViewModel vm,
    required String petId,
    required bool isPlayerTeam,
    required int actorIndex,
    required List<Offset> actorPositions,
    required List<Offset> targetPositions,
    required List<PetViewModel> targetTeam,
    required double w,
    required double h,
  }) {
    final rawDash = vm.petDashOffsets[petId] ?? Offset.zero;
    if (rawDash == Offset.zero) return Offset.zero;

    final explicitTargetId = vm.petDashTargets[petId];
    int targetIndex = -1;
    if (explicitTargetId != null) {
      targetIndex = targetTeam.indexWhere(
          (p) => p.id == explicitTargetId && !p.isFainted);
      if (targetIndex < 0) return Offset.zero;
    }
    if (targetIndex < 0) {
      targetIndex = targetTeam.indexWhere((p) => !p.isFainted);
    }
    if (targetIndex < 0) return Offset.zero;

    final actorSpriteSize =
        _kSpriteBase * _kScaleByPos[actorIndex.clamp(0, _kScaleByPos.length - 1)];
    final targetSpriteSize =
        _kSpriteBase * _kScaleByPos[targetIndex.clamp(0, _kScaleByPos.length - 1)];

    final actorFrac = actorPositions[actorIndex.clamp(0, 2)];
    final targetFrac = targetPositions[targetIndex.clamp(0, 2)];
    final actorCenter = Offset(w * actorFrac.dx, h * actorFrac.dy) +
        Offset(actorSpriteSize * 0.5, actorSpriteSize * 0.5);
    final targetCenter = Offset(w * targetFrac.dx, h * targetFrac.dy) +
        Offset(targetSpriteSize * 0.5, targetSpriteSize * 0.5);

    final toTarget = targetCenter - actorCenter;
    final distance = toTarget.distance;
    if (distance < 1.0) return Offset.zero;

    final minGap = math.max(8.0, (actorSpriteSize + targetSpriteSize) * 0.06);
    final dashDist = math.max(0.0, distance - minGap);
    if (dashDist <= 0) return Offset.zero;

    return Offset(toTarget.dx / distance * dashDist,
                  toTarget.dy / distance * dashDist);
  }
}

// ── Battle pet ────────────────────────────────────────────────────────────────

class _BattlePet extends StatelessWidget {
  final PetViewModel pet;
  final bool flipHorizontal;
  final bool isPlayer;
  final bool hasSkill;
  final int positionIndex;
  final PetCharacterAnimState? animState;
  final String? attackSlot;

  const _BattlePet({
    required this.pet,
    required this.flipHorizontal,
    required this.isPlayer,
    required this.hasSkill,
    required this.positionIndex,
    this.animState,
    this.attackSlot,
  });

  @override
  Widget build(BuildContext context) {
    final scale = _kScaleByPos[positionIndex.clamp(0, 2)];
    final opacity = _kOpacityByPos[positionIndex.clamp(0, 2)];
    final spriteSize = _kSpriteBase * scale;
    final barWidth = (spriteSize * 0.50).clamp(80.0, 108.0);
    final effectiveOpacity = pet.isFainted ? 0.88 : opacity;

    return Opacity(
      opacity: effectiveOpacity,
      child: SizedBox(
        width: spriteSize + 16,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.topCenter,
              clipBehavior: Clip.none,
              children: [
                IgnorePointer(
                  child: _PetSprite(
                    pet: pet,
                    size: spriteSize,
                    hasSkill: hasSkill,
                    flipHorizontal: flipHorizontal,
                    animState: animState,
                    attackSlot: attackSlot,
                  ),
                ),
                if (!pet.isFainted)
                  Positioned(
                    top: 22, left: 0, right: 0,
                    child: _FloatingHpBar(pet: pet, width: barWidth),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(pet.name,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    shadows: [Shadow(blurRadius: 4, color: Colors.black87)])),
          ],
        ),
      ),
    );
  }
}

class _PetSprite extends StatelessWidget {
  final PetViewModel pet;
  final double size;
  final bool hasSkill;
  final bool flipHorizontal;
  final PetCharacterAnimState? animState;
  final String? attackSlot;

  const _PetSprite({
    required this.pet,
    required this.size,
    required this.hasSkill,
    required this.flipHorizontal,
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
        Positioned(
          bottom: -4,
          child: Container(
            width: size * 0.72,
            height: 16,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(50),
              gradient: RadialGradient(colors: [
                Colors.black.withValues(alpha: 0.55),
                Colors.black.withValues(alpha: 0.0),
              ], radius: 0.85),
            ),
          ),
        ),
        if (pet.isFainted)
          SizedBox(
            width: size, height: size,
            child: DeadPetEffect(size: size, flipHorizontal: flipHorizontal),
          )
        else if (pet.creatureDef != null)
          SizedBox(
            width: size, height: size,
            child: PetRendererWidget(
              def: pet.creatureDef!,
              size: size,
              flipHorizontal: flipHorizontal,
              animation: _animFor(animState, attackSlot: attackSlot),
            ),
          )
        else
          PetSpriteWidget(
            config: pet.spriteConfig,
            size: size,
            flipHorizontal: flipHorizontal,
            petName: pet.name,
            petColor: color,
          ),
        if (hasSkill && !pet.isFainted)
          Positioned(
            top: 0, right: 0,
            child: Container(
              width: 16, height: 16,
              decoration: const BoxDecoration(
                  shape: BoxShape.circle, color: AppColors.accent),
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

// ── Floating HP bar ───────────────────────────────────────────────────────────

class _FloatingHpBar extends StatelessWidget {
  final PetViewModel pet;
  final double width;
  const _FloatingHpBar({required this.pet, required this.width});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.favorite, size: 8, color: Color(0xFF66FF88)),
              const SizedBox(width: 1),
              Text('${pet.hp}',
                  style: const TextStyle(
                      color: Color(0xFF66FF88),
                      fontSize: 8,
                      fontWeight: FontWeight.w800)),
              const Spacer(),
              if (pet.shield > 0) ...[
                const Icon(Icons.shield, size: 8, color: AppColors.shieldGold),
                const SizedBox(width: 1),
                Text('${pet.shield}',
                    style: const TextStyle(
                        color: AppColors.shieldGold,
                        fontSize: 8,
                        fontWeight: FontWeight.w800)),
              ],
            ],
          ),
          const SizedBox(height: 1),
          HpBar(current: pet.hp, max: pet.maxHp, height: 3),
        ],
      ),
    );
  }
}

// ── Battle feed ───────────────────────────────────────────────────────────────

class _BattleFeed extends StatelessWidget {
  final String log;
  const _BattleFeed({required this.log});

  @override
  Widget build(BuildContext context) {
    if (log.isEmpty) return const SizedBox.shrink();
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
      child: Text(display,
          style: const TextStyle(
              color: Colors.white70, fontSize: 10, fontFamily: 'monospace'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis),
    );
  }
}

// ── Bottom panel ──────────────────────────────────────────────────────────────

class _BottomPanel extends StatelessWidget {
  final PveBattleViewModel vm;
  final WidgetRef ref;
  final AnimationController timer;
  final bool isCollapsed;
  final VoidCallback onToggleCollapse;

  const _BottomPanel({
    required this.vm,
    required this.ref,
    required this.timer,
    required this.isCollapsed,
    required this.onToggleCollapse,
  });

  @override
  Widget build(BuildContext context) {
    if (vm.isResolving) return const SizedBox.shrink();

    return SizedBox(
      height: _kPanelH,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xB80A0E1A), Color(0xF80A0E1A)],
              ),
              border: Border(
                  top: BorderSide(color: Color(0xFF2A3860), width: 2)),
            ),
          ),
          Positioned(
            top: 2, left: 0, right: 0,
            child: Container(
              height: 18,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withValues(alpha: 0.28), Colors.transparent],
                ),
              ),
            ),
          ),
          Positioned.fill(
            top: 20,
            child: _BottomPanelContent(vm: vm, ref: ref),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: GestureDetector(
              onTap: onToggleCollapse,
              child: Container(
                margin: const EdgeInsets.only(top: 3),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A243A),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isCollapsed
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 15,
                      color: Colors.white70,
                    ),
                    const SizedBox(width: 4),
                    Text(isCollapsed ? 'Show Deck' : 'Hide Deck',
                        style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomPanelContent extends StatelessWidget {
  final PveBattleViewModel vm;
  final WidgetRef ref;
  const _BottomPanelContent({required this.vm, required this.ref});

  @override
  Widget build(BuildContext context) {
    final living = vm.playerTeam.where((p) => !p.isFainted).toList();
    final previewEnergy = vm.plannedRemainingEnergy;

    final entries = <(PetViewModel, CardViewModel)>[];
    for (final pet in living) {
      for (final card in vm.hand.where((c) => c.ownerPetId == pet.id)) {
        entries.add((pet, card));
      }
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Energy orb
        SizedBox(
          width: 76,
          child: Center(
            child: _EnergyDisplay(energy: previewEnergy, max: kTeamEnergyCap),
          ),
        ),

        // Card hand
        if (!vm.isBattleOver)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: entries.isEmpty
                      ? const Center(
                          child: Text('No cards',
                              style: TextStyle(
                                  color: Colors.white38, fontSize: 12)))
                      : ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
                          itemCount: entries.length,
                          itemBuilder: (_, i) {
                            final (pet, card) = entries[i];
                            final assigned = vm.pendingSkills[pet.id] ?? [];
                            final isAssigned = assigned.contains(card.instanceId);
                            final comboIdx = isAssigned
                                ? assigned.indexOf(card.instanceId) + 1
                                : null;
                            final isNew = vm.newCardIds.contains(card.instanceId);

                            final prevPet = i > 0 ? entries[i - 1].$1 : null;
                            final isNewPet =
                                prevPet == null || prevPet.id != pet.id;
                            final petColor = _clsColor(
                                pet.creatureDef?.bodyClass.name ?? '');
                            final clsName =
                                pet.creatureDef?.bodyClass.name ?? '';
                            final clsLabel = clsName.isEmpty
                                ? ''
                                : clsName[0].toUpperCase() +
                                    clsName.substring(1);

                            Widget w = Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                SizedBox(
                                  height: 20,
                                  child: isNewPet && clsLabel.isNotEmpty
                                      ? Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 7, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: petColor.withValues(alpha: 0.18),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                                color: petColor.withValues(alpha: 0.55)),
                                          ),
                                          child: Text(clsLabel,
                                              style: TextStyle(
                                                  color: petColor,
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w800,
                                                  letterSpacing: 0.3)),
                                        )
                                      : const SizedBox.shrink(),
                                ),
                                const SizedBox(height: 3),
                                _SkillCard(
                                  trait: card.trait,
                                  petName: card.ownerPetName,
                                  isSelected: isAssigned,
                                  isPity: card.isPity,
                                  isFizzled: false,
                                  cardArtPath: card.cardArtPath,
                                  cardTemplatePath: card.cardTemplatePath,
                                  comboIndex: comboIdx,
                                  onTap: () => ref
                                      .read(pvpBattleProvider.notifier)
                                      .assignSkill(card.instanceId),
                                ),
                              ],
                            );

                            if (isNew) {
                              w = _CardEntrance(
                                key: ValueKey(card.instanceId),
                                delay: Duration(milliseconds: i * 55),
                                child: w,
                              );
                            }

                            return Padding(
                              padding: EdgeInsets.only(
                                  left: isNewPet && i > 0 ? 14 : 3, right: 3),
                              child: w,
                            );
                          },
                        ),
                ),
              ],
            ),
          ),

        // Lock-in button
        SizedBox(
          width: 88,
          child: Center(
            child: _LockInButton(vm: vm, ref: ref),
          ),
        ),
      ],
    );
  }

  static Color _clsColor(String name) => switch (name.toLowerCase()) {
        'beast' => const Color(0xFFFF9800),
        'plant' => const Color(0xFF4CAF50),
        'aquatic' => const Color(0xFF29B6F6),
        'reptile' => const Color(0xFF66BB6A),
        'bird' => const Color(0xFFFF80AB),
        'bug' => const Color(0xFFFF5252),
        _ => const Color(0xFF9C27B0),
      };
}

// ── Energy display ────────────────────────────────────────────────────────────

class _EnergyDisplay extends StatelessWidget {
  final int energy;
  final int max;
  const _EnergyDisplay({required this.energy, required this.max});

  @override
  Widget build(BuildContext context) {
    const c = AppColors.energyBlue;
    final frac = max > 0 ? (energy / max).clamp(0.0, 1.0) : 0.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 52,
          height: 52,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    c.withValues(alpha: frac * 0.5),
                    c.withValues(alpha: 0.0),
                  ]),
                ),
              ),
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    center: const Alignment(-0.3, -0.3),
                    colors: [
                      energy > 0
                          ? c.withValues(alpha: 0.9)
                          : Colors.white.withValues(alpha: 0.1),
                      energy > 0
                          ? const Color(0xFF0A3A6A)
                          : Colors.black45,
                    ],
                  ),
                  border: Border.all(
                      color: energy > 0 ? c.withValues(alpha: 0.8) : Colors.white12,
                      width: 2),
                ),
                child: Center(
                  child: Text('$energy',
                      style: TextStyle(
                          color: energy > 0 ? Colors.white : Colors.white38,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          shadows: energy > 0
                              ? [
                                  Shadow(
                                      color: c.withValues(alpha: 0.8),
                                      blurRadius: 6)
                                ]
                              : null)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Text('Energy',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 8,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5)),
      ],
    );
  }
}

// ── Lock-in button ────────────────────────────────────────────────────────────

class _LockInButton extends StatelessWidget {
  final PveBattleViewModel vm;
  final WidgetRef ref;
  const _LockInButton({required this.vm, required this.ref});

  @override
  Widget build(BuildContext context) {
    final disabled =
        vm.isResolving || vm.awaitingOpponent || vm.isBattleOver;
    final label = vm.awaitingOpponent
        ? 'Waiting…'
        : vm.isResolving
            ? 'Resolving…'
            : 'Lock In';

    return SizedBox(
      width: 76,
      child: ElevatedButton(
        onPressed: disabled
            ? null
            : () => ref.read(pvpBattleProvider.notifier).executeRound(),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFEF5350),
          disabledBackgroundColor: AppColors.surface,
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(label,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12)),
      ),
    );
  }
}

// ── Skill card (identical rules to PvE) ──────────────────────────────────────

int _classicCardAttack(TraitViewModel trait, TraitCardCatalogEntry? entry) {
  if (entry != null) return entry.attack;
  return switch (trait.effectIconKey) {
    'damage' || 'aoe' => trait.effectIconValue,
    _ => 0,
  };
}

int _classicCardDefense(TraitViewModel trait, TraitCardCatalogEntry? entry) {
  if (entry != null) return entry.defense;
  return switch (trait.effectIconKey) {
    'shield' || 'def_up' => trait.effectIconValue,
    _ => 0,
  };
}

class _SkillCard extends StatelessWidget {
  final TraitViewModel trait;
  final String petName;
  final bool isSelected;
  final bool isPity;
  final bool isFizzled;
  final String? cardArtPath;
  final String? cardTemplatePath;
  final int? comboIndex;
  final VoidCallback? onTap;

  const _SkillCard({
    required this.trait,
    required this.petName,
    required this.isSelected,
    this.isPity = false,
    this.isFizzled = false,
    this.cardArtPath,
    this.cardTemplatePath,
    this.comboIndex,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final usable = trait.isUsable;
    final tc = _typeColor(trait.typeName);
    final cardEntry = _cardCatalogByTraitId[trait.id];
    final resolvedTemplatePath = cardTemplatePath ??
        cardEntry?.templatePath ??
        cardArtPath ??
        'assets/images/part-cards/default-card-art.png';
    final resolvedImageName = cardEntry?.imageName ??
        _classicImageNameFromPath(cardTemplatePath) ??
        _classicImageNameFromPath(cardArtPath) ??
        _classicImageNameFromPath(resolvedTemplatePath) ??
        '';

    const cardW = 96.0;
    const cardH = 134.0;
    const lift = -14.0;

    return GestureDetector(
      onTap: usable && !isFizzled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 110),
        width: cardW,
        height: cardH,
        transform: isSelected
            ? (Matrix4.identity()..translateByDouble(0, lift, 0, 1))
            : Matrix4.identity(),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(11),
          boxShadow: [
            if (isSelected) ...[
              BoxShadow(
                  color: tc.withValues(alpha: 0.85),
                  blurRadius: 20,
                  spreadRadius: 2,
                  offset: const Offset(0, -2)),
              BoxShadow(
                  color: tc.withValues(alpha: 0.4),
                  blurRadius: 36,
                  spreadRadius: 4),
            ],
            const BoxShadow(
                color: Colors.black, blurRadius: 10, offset: Offset(0, 4)),
          ],
        ),
        child: Opacity(
          opacity: isFizzled ? 0.3 : (usable ? 1.0 : 0.38),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: ClassicTraitCardWidget(
                    imagePath: resolvedTemplatePath,
                    imageName: resolvedImageName,
                    name: trait.name,
                    energy: trait.energyCost,
                    attack: _classicCardAttack(trait, cardEntry),
                    defense: _classicCardDefense(trait, cardEntry),
                    description: trait.description,
                    showDescription: true,
                  ),
                ),
                if (isSelected)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: tc.withValues(alpha: 0.9), width: 2.5),
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.14),
                            Colors.transparent,
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.center,
                        ),
                      ),
                    ),
                  ),
                if (!trait.isReady)
                  Positioned(
                    bottom: 4, left: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                            color: AppColors.utility.withValues(alpha: 0.6)),
                      ),
                      child: Text('CD ${trait.cooldownRemaining}',
                          style: TextStyle(
                              color: AppColors.utility,
                              fontSize: 7,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                if (comboIndex != null)
                  Positioned(
                    top: 22, right: 4,
                    child: Container(
                      width: 18, height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: tc,
                        border: Border.all(color: Colors.white70, width: 1),
                        boxShadow: [
                          BoxShadow(
                              color: tc.withValues(alpha: 0.6), blurRadius: 6)
                        ],
                      ),
                      child: Center(
                        child: Text('$comboIndex',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w900)),
                      ),
                    ),
                  ),
                if (isPity)
                  Positioned(
                    bottom: 5, left: 5,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 3, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                            color: Colors.amber.withValues(alpha: 0.6)),
                      ),
                      child: const Text('★',
                          style: TextStyle(
                              color: Colors.amber, fontSize: 7)),
                    ),
                  ),
                if (isFizzled)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.6),
                      child: const Center(
                        child: Text('✗',
                            style: TextStyle(
                                color: Colors.white54,
                                fontSize: 20,
                                fontWeight: FontWeight.w900)),
                      ),
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
        'offensive' => AppColors.offensive,
        'defensive' => AppColors.defensive,
        'support' => AppColors.support,
        'utility' => AppColors.utility,
        _ => AppColors.primary,
      };
}

String? _classicImageNameFromPath(String? path) {
  if (path == null || path.isEmpty) return null;
  final filename = path.split('/').last;
  if (!filename.endsWith('.png')) return null;
  return filename.substring(0, filename.length - 4);
}

// ── Card entrance animation ───────────────────────────────────────────────────

class _CardEntrance extends StatefulWidget {
  final Widget child;
  final Duration delay;
  const _CardEntrance({super.key, required this.child, required this.delay});

  @override
  State<_CardEntrance> createState() => _CardEntranceState();
}

class _CardEntranceState extends State<_CardEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _slide = Tween(begin: 24.0, end: 0.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _fade = Tween(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    Future.delayed(widget.delay, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) => Opacity(
        opacity: _fade.value,
        child: Transform.translate(
            offset: Offset(0, _slide.value), child: child),
      ),
      child: widget.child,
    );
  }
}

// ── Floating number widget ────────────────────────────────────────────────────

class _FloatingNumberWidget extends StatefulWidget {
  final _FloatNum num;
  final VoidCallback onDone;
  const _FloatingNumberWidget(
      {super.key, required this.num, required this.onDone});

  @override
  State<_FloatingNumberWidget> createState() => _FloatingNumberWidgetState();
}

class _FloatingNumberWidgetState extends State<_FloatingNumberWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _rise;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1300));
    _rise = Tween(begin: 0.0, end: -72.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _fade = Tween(begin: 1.0, end: 0.0).animate(
        CurvedAnimation(parent: _ctrl, curve: const Interval(0.5, 1.0)));
    _scale = Tween(begin: 1.6, end: 1.0).animate(CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOutBack)));
    _ctrl.forward().then((_) => widget.onDone());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.num;
    return Positioned(
      left: n.x + n.jitter,
      top: n.y,
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
                  Text(n.text,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        foreground: Paint()
                          ..style = PaintingStyle.stroke
                          ..strokeWidth = 3
                          ..color = Colors.black87,
                      )),
                  Text(n.text,
                      style: TextStyle(
                          color: n.color,
                          fontSize: 22,
                          fontWeight: FontWeight.w900)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Animation name helper ─────────────────────────────────────────────────────

String _animFor(PetCharacterAnimState? state, {String? attackSlot}) {
  final isAttack = state == PetCharacterAnimState.attack ||
      state == PetCharacterAnimState.attackMelee ||
      state == PetCharacterAnimState.attackRanged;
  if (isAttack) {
    switch (attackSlot) {
      case 'horn':  return 'attack/melee/horn-gore';
      case 'mouth': return 'attack/melee/mouth-bite';
      case 'tail':  return 'attack/melee/tail-roll';
      case 'back':  return 'attack/ranged/cast-fly';
    }
  }
  return switch (state) {
    PetCharacterAnimState.move => 'action/move-forward',
    PetCharacterAnimState.attack ||
    PetCharacterAnimState.attackMelee => 'attack/melee/normal-attack',
    PetCharacterAnimState.attackRanged => 'attack/ranged/cast-fly',
    PetCharacterAnimState.hit => 'defense/hit-by-normal',
    PetCharacterAnimState.buff ||
    PetCharacterAnimState.heal => 'battle/get-buff',
    PetCharacterAnimState.debuff => 'battle/get-debuff',
    PetCharacterAnimState.shield => 'defense/hit-with-shield',
    PetCharacterAnimState.faint => 'action/move-back',
    _ => 'action/idle/normal',
  };
}

// ── Loading screen ────────────────────────────────────────────────────────────

class _PvpLoadingScreen extends StatelessWidget {
  final String message;
  const _PvpLoadingScreen({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          const Positioned.fill(child: BattleBackgroundWidget()),
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.55),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: AppColors.accent),
                    const SizedBox(height: 14),
                    Text(message,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
