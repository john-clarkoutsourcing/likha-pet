// Reusable battle HUD widgets shared between PvE (BattleScreen) and
// PvP (PvpBattleScreen). Any future mode (raid, tournament) also imports here.
//
// Public widgets: BattleTopHud, BattlefieldView, BattleBottomPanel,
//   BattleFeed, BattleSkillCard, BattleLoadingScreen, BattleEnergyDisplay,
//   BattleFloatingHpBar, BattleCardEntrance
//
// Public helpers: battleAnimFor, battleClassicImageNameFromPath,
//   battleClassicCardAttack, battleClassicCardDefense
//
// Shared catalog: kBattleCardCatalogByTraitId

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:likha_pet_battle_engine/energy_pool.dart';

import '../../../shared/widgets/hp_bar.dart';
import '../../../core/theme/app_colors.dart';
import '../data/trait_card_catalog.dart';
import '../providers/battle_view_model.dart';
import '../widgets/battle_background_widget.dart';
import '../widgets/classic_trait_card_widget.dart';
import '../widgets/dead_pet_effect.dart';
import '../widgets/pet_character_widget.dart';
import '../widgets/pet_renderer_widget.dart';
import '../widgets/pet_sprite_widget.dart';
import '../widgets/projectile_widget.dart';

// ── Shared constants ──────────────────────────────────────────────────────────

const double kBattlePanelH = 182.0;
const double kBattlePanelPeekH = 32.0;
const double kBattleSpriteBase = 130.0;
const _kScaleByPos = [1.50, 1.50, 1.50];
const _kOpacityByPos = [1.00, 1.00, 1.00];

// ── Lazy card catalog ─────────────────────────────────────────────────────────

final Map<String, TraitCardCatalogEntry> kBattleCardCatalogByTraitId = {
  for (final e in TraitCardCatalog.build()) e.traitId: e,
};

// ── Helper functions ──────────────────────────────────────────────────────────

String? battleClassicImageNameFromPath(String? path) {
  if (path == null || path.isEmpty) return null;
  final f = path.split('/').last;
  if (!f.endsWith('.png')) return null;
  return f.substring(0, f.length - 4);
}

int battleClassicCardAttack(
    TraitViewModel trait, TraitCardCatalogEntry? entry) {
  if (entry != null) return entry.attack;
  return switch (trait.effectIconKey) {
    'damage' || 'aoe' => trait.effectIconValue,
    _ => 0,
  };
}

int battleClassicCardDefense(
    TraitViewModel trait, TraitCardCatalogEntry? entry) {
  if (entry != null) return entry.defense;
  return switch (trait.effectIconKey) {
    'shield' || 'def_up' => trait.effectIconValue,
    _ => 0,
  };
}

String battleAnimFor(PetCharacterAnimState? state, {String? attackSlot}) {
  final isAttack = state == PetCharacterAnimState.attack ||
      state == PetCharacterAnimState.attackMelee ||
      state == PetCharacterAnimState.attackRanged;
  if (isAttack) {
    switch (attackSlot) {
      case 'horn':
        return 'attack/melee/horn-gore';
      case 'mouth':
        return 'attack/melee/mouth-bite';
      case 'tail':
        return 'attack/melee/tail-roll';
      case 'back':
        return 'attack/ranged/cast-fly';
    }
  }
  return switch (state) {
    PetCharacterAnimState.move => 'action/move-forward',
    PetCharacterAnimState.attack ||
    PetCharacterAnimState.attackMelee =>
      'attack/melee/normal-attack',
    PetCharacterAnimState.attackRanged => 'attack/ranged/cast-fly',
    PetCharacterAnimState.hit => 'defense/hit-by-normal',
    PetCharacterAnimState.buff ||
    PetCharacterAnimState.heal =>
      'battle/get-buff',
    PetCharacterAnimState.debuff => 'battle/get-debuff',
    PetCharacterAnimState.shield => 'defense/hit-with-shield',
    PetCharacterAnimState.faint => 'action/move-back',
    _ => 'action/idle/normal',
  };
}

// ── BattleTopHud ──────────────────────────────────────────────────────────────
//
// Layout (always opponent-left / player-right so the tag colour matches the
// side the sprites stand on):
//
//   playerOnRight: false (PvE) → [player LEFT] [centre] [opponent RIGHT]
//   playerOnRight: true  (PvP) → [opponent LEFT] [centre] [player RIGHT]

class BattleTopHud extends StatelessWidget {
  final PveBattleViewModel vm;
  final AnimationController timer;

  /// PvE: false  — player on left, opponent on right.
  /// PvP: true   — player on right, opponent on left.
  final bool playerOnRight;

  const BattleTopHud({
    super.key,
    required this.vm,
    required this.timer,
    this.playerOnRight = false,
  });

  @override
  Widget build(BuildContext context) {
    final leftName = playerOnRight ? vm.enemyTeamName : vm.playerTeamName;
    final rightName = playerOnRight ? vm.playerTeamName : vm.enemyTeamName;
    final leftIsPlayer = !playerOnRight;
    final rightIsPlayer = playerOnRight;

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
          _TeamTag(name: leftName, isPlayer: leftIsPlayer),
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
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _BattleRoundTimer(timer: timer),
                      ],
                    ),
                    const SizedBox(height: 3),
                    _BattleAttackOrderStrip(vm: vm),
                  ],
                ),
              ),
            ),
          ),
          _TeamTag(name: rightName, isPlayer: rightIsPlayer),
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

    // isPlayer on LEFT: avatar | label; isPlayer on RIGHT: label | avatar
    return isPlayer
        ? Row(mainAxisSize: MainAxisSize.min, children: [
            avatar,
            const SizedBox(width: 5),
            SizedBox(width: 72, child: label),
          ])
        : Row(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(width: 72, child: label),
            const SizedBox(width: 5),
            avatar,
          ]);
  }
}

class _BattleRoundTimer extends StatelessWidget {
  final AnimationController timer;
  const _BattleRoundTimer({required this.timer});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: timer,
      builder: (_, __) {
        final remaining = 1.0 - timer.value;
        final seconds = (timer.duration!.inSeconds * remaining).ceil();
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

class _BattleAttackOrderStrip extends StatelessWidget {
  final PveBattleViewModel vm;
  const _BattleAttackOrderStrip({required this.vm});

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
          _BattleOrderBadge(entry: alive[i], number: i + 1, isFirst: i == 0),
        ],
      ],
    );
  }
}

class _BattleOrderBadge extends StatelessWidget {
  final TurnOrderEntry entry;
  final int number;
  final bool isFirst;
  const _BattleOrderBadge(
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
                ? [
                    BoxShadow(
                        color: c.withValues(alpha: 0.6),
                        blurRadius: 8,
                        spreadRadius: 2)
                  ]
                : null,
          ),
          child: ClipOval(
            child: entry.texturePath != null
                ? Image.asset(entry.texturePath!,
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Center(
                        child: Text(entry.name[0],
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: isFirst ? 13 : 10,
                                fontWeight: FontWeight.w900))))
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
              boxShadow: const [
                BoxShadow(color: Colors.black54, blurRadius: 2)
              ],
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

// ── BattlefieldView ───────────────────────────────────────────────────────────
//
// Renders both teams at fractional positions, handles:
//   • Dash animations (melee lunge toward target)
//   • Projectile spawning and tracking
//   • Floating damage / heal numbers
//   • Per-pet tap/long-press callbacks (for info sheets, etc.)
//
// playerFlipHorizontal / opponentFlipHorizontal control which direction sprites
// face. Convention: the sprite asset faces LEFT by default.
//   PvE → player on left faces RIGHT  → playerFlipHorizontal: true
//   PvP → player on right faces LEFT  → playerFlipHorizontal: false

class BattlefieldView extends ConsumerStatefulWidget {
  final PveBattleViewModel vm;
  final List<Offset> playerPos;
  final List<Offset> opponentPos;
  final bool playerFlipHorizontal;
  final bool opponentFlipHorizontal;
  final void Function(PetViewModel)? onPlayerPetTap;
  final void Function(PetViewModel)? onPlayerPetLongPress;
  final void Function(PetViewModel)? onOpponentPetTap;
  // When provided, build() watches this directly so HP bars always reflect
  // the live Riverpod state — even when setState fires for internal overlays.
  final ProviderListenable<PveBattleViewModel>? liveProvider;
  final bool snapHpBars;

  const BattlefieldView({
    super.key,
    required this.vm,
    required this.playerPos,
    required this.opponentPos,
    required this.playerFlipHorizontal,
    required this.opponentFlipHorizontal,
    this.onPlayerPetTap,
    this.onPlayerPetLongPress,
    this.onOpponentPetTap,
    this.liveProvider,
    this.snapHpBars = false,
  });

  @override
  ConsumerState<BattlefieldView> createState() => _BattlefieldViewState();
}

class _BattleFloatNum {
  final String id;
  final String text;
  final Color color;
  final double x, y, jitter;
  const _BattleFloatNum({
    required this.id,
    required this.text,
    required this.color,
    required this.x,
    required this.y,
    this.jitter = 0.0,
  });
}

class _BattlefieldViewState extends ConsumerState<BattlefieldView> {
  final List<ProjectileInstance> _projectiles = [];
  final List<_BattleFloatNum> _floatNums = [];
  int _nextId = 0;
  Set<String> _lastAttackIds = {};

  @override
  void didUpdateWidget(BattlefieldView old) {
    super.didUpdateWidget(old);
    _maybeSpawnProjectiles(widget.vm);
    _maybeSpawnFloatNums(old.vm, widget.vm);
  }

  void _maybeSpawnFloatNums(
      PveBattleViewModel oldVm, PveBattleViewModel newVm) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      if (box == null) return;
      final w = box.size.width;
      final h = box.size.height;
      final rng = math.Random();
      final nums = <_BattleFloatNum>[];

      void spawnAt({
        required String petId,
        required bool isPlayerTeam,
        required int index,
        required String text,
        required Color color,
      }) {
        final positions = isPlayerTeam ? widget.playerPos : widget.opponentPos;
        final frac = positions[index.clamp(0, 2)];
        final rawDash = newVm.petDashOffsets[petId] ?? Offset.zero;
        final dashPx = _dashPixelsForPet(
          vm: newVm,
          actorPetId: petId,
          isPlayerTeam: isPlayerTeam,
          actorIndex: index,
          rawDash: rawDash,
          w: w,
          h: h,
        );
        final pos = Offset(w * frac.dx + dashPx.dx, h * frac.dy + dashPx.dy);
        nums.add(_BattleFloatNum(
          id: '${_nextId++}',
          text: text,
          color: color,
          x: pos.dx + 30,
          y: pos.dy - 10,
          jitter: (rng.nextDouble() - 0.5) * 24,
        ));
      }

      final impact = newVm.lastImpactEvent;
      if (impact != null && oldVm.lastImpactEvent?.id != impact.id) {
        final petId =
            impact.targetId.isNotEmpty ? impact.targetId : impact.actorId;
        final isPlayerTeam = newVm.playerTeam.any((p) => p.id == petId);
        final team = isPlayerTeam ? newVm.playerTeam : newVm.enemyTeam;
        final index = team.indexWhere((p) => p.id == petId);
        if (index >= 0) {
          switch (impact.effectType) {
            case 'heal':
            case 'regen':
              if (impact.healAmount > 0) {
                spawnAt(
                  petId: petId,
                  isPlayerTeam: isPlayerTeam,
                  index: index,
                  text: '+${impact.healAmount}',
                  color: const Color(0xFF44FF88),
                );
              }
              break;
            case 'shield':
              if (impact.shieldAmount > 0) {
                spawnAt(
                  petId: petId,
                  isPlayerTeam: isPlayerTeam,
                  index: index,
                  text: '+${impact.shieldAmount}',
                  color: AppColors.shieldGold,
                );
              }
              break;
            default:
              if (impact.damage > 0) {
                final isPoison = impact.statusApplied == 'poisoned' ||
                    impact.effectType == 'poison';
                spawnAt(
                  petId: petId,
                  isPlayerTeam: isPlayerTeam,
                  index: index,
                  text: '-${impact.damage}',
                  color: isPoison
                      ? const Color(0xFFB44FD4)
                      : const Color(0xFFFF3333),
                );
              }
          }
        }
        if (nums.isNotEmpty) setState(() => _floatNums.addAll(nums));
        return;
      }

      void check(
        List<PetViewModel> oldTeam,
        List<PetViewModel> newTeam,
        List<Offset> positions,
        Map<String, Offset> dashOffsets,
        bool isPlayerTeam,
      ) {
        for (var i = 0; i < newTeam.length && i < oldTeam.length; i++) {
          final delta = newTeam[i].hp - oldTeam[i].hp;
          if (delta == 0) continue;
          final petId = newTeam[i].id;
          final frac = positions[i.clamp(0, 2)];
          final rawDash = dashOffsets[petId] ?? Offset.zero;
          final dashPx = _dashPixelsForPet(
            vm: newVm,
            actorPetId: petId,
            isPlayerTeam: isPlayerTeam,
            actorIndex: i,
            rawDash: rawDash,
            w: w,
            h: h,
          );
          final pos = Offset(w * frac.dx + dashPx.dx, h * frac.dy + dashPx.dy);
          final x = pos.dx + 30;
          final y = pos.dy - 10;

          if (delta < 0) {
            nums.add(_BattleFloatNum(
              id: '${_nextId++}',
              text: '$delta',
              color: const Color(0xFFFF3333),
              x: x,
              y: y,
              jitter: (rng.nextDouble() - 0.5) * 24,
            ));
          } else {
            nums.add(_BattleFloatNum(
              id: '${_nextId++}',
              text: '+$delta',
              color: const Color(0xFF44FF88),
              x: x,
              y: y,
              jitter: (rng.nextDouble() - 0.5) * 24,
            ));
          }
        }
      }

      check(oldVm.playerTeam, newVm.playerTeam, widget.playerPos,
          newVm.petDashOffsets, true);
      check(oldVm.enemyTeam, newVm.enemyTeam, widget.opponentPos,
          newVm.petDashOffsets, false);

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
        final attackerPositions =
            isPlayer ? widget.playerPos : widget.opponentPos;
        final team = isPlayer ? vm.playerTeam : vm.enemyTeam;
        final attackerIdx = team.indexWhere((p) => p.id == petId);
        if (attackerIdx < 0) continue;

        const spriteOffset = 29.0;
        final startFrac = attackerPositions[attackerIdx];
        final start = Offset(
            w * startFrac.dx + spriteOffset, h * startFrac.dy + spriteOffset);

        Offset end = start;
        if (!_isSelfCenteredEffect(effectType)) {
          final targetPositions =
              isPlayer ? widget.opponentPos : widget.playerPos;
          final targetTeam = isPlayer ? vm.enemyTeam : vm.playerTeam;
          final targetIdx = targetTeam.indexWhere((p) => !p.isFainted);
          if (targetIdx < 0) continue;
          final endFrac = targetPositions[targetIdx];
          end = Offset(
              w * endFrac.dx + spriteOffset, h * endFrac.dy + spriteOffset);
        }

        newProjectiles.add(ProjectileInstance(
            id: '${_nextId++}', start: start, end: end, config: cfg));
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
    // If liveProvider is set, watch it directly so HP bars always reflect the
    // latest Riverpod state — even when internal setState fires (e.g. floating
    // damage numbers) before the parent has propagated the new vm prop.
    final vm = widget.liveProvider != null
        ? ref.watch(widget.liveProvider!)
        : widget.vm;
    return LayoutBuilder(builder: (_, constraints) {
      final w = constraints.maxWidth;
      final h = constraints.maxHeight;

      return Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // Ground line
          Positioned(
            top: h * 0.52,
            left: 0,
            right: 0,
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

          // Opponent pets
          for (var i = 0; i < vm.enemyTeam.length; i++)
            _placed(
              w,
              h,
              widget.opponentPos[i],
              _BattlePet(
                pet: vm.enemyTeam[i],
                flipHorizontal: widget.opponentFlipHorizontal,
                hasSkill: false,
                positionIndex: i,
                animState: vm.petAnimStates[vm.enemyTeam[i].id],
                attackSlot: vm.petAttackSlots[vm.enemyTeam[i].id],
                onTap: widget.onOpponentPetTap != null
                    ? () => widget.onOpponentPetTap!(vm.enemyTeam[i])
                    : null,
                snapHpBars: widget.snapHpBars,
                displayHp: _displayHpForPet(vm, vm.enemyTeam[i]).$1,
                displayShield: _displayHpForPet(vm, vm.enemyTeam[i]).$2,
                shieldPreview: _previewShieldForPet(vm, vm.enemyTeam[i]),
              ),
              dash: _dashPixelsForPet(
                vm: vm,
                actorPetId: vm.enemyTeam[i].id,
                isPlayerTeam: false,
                actorIndex: i,
                rawDash: vm.petDashOffsets[vm.enemyTeam[i].id] ?? Offset.zero,
                w: w,
                h: h,
              ),
            ),

          // Player pets
          for (var i = 0; i < vm.playerTeam.length; i++)
            _placed(
              w,
              h,
              widget.playerPos[i],
              _BattlePet(
                pet: vm.playerTeam[i],
                flipHorizontal: widget.playerFlipHorizontal,
                hasSkill:
                    vm.pendingSkills[vm.playerTeam[i].id]?.isNotEmpty ?? false,
                positionIndex: i,
                animState: vm.petAnimStates[vm.playerTeam[i].id],
                attackSlot: vm.petAttackSlots[vm.playerTeam[i].id],
                onTap: widget.onPlayerPetTap != null
                    ? () => widget.onPlayerPetTap!(vm.playerTeam[i])
                    : null,
                onLongPress: widget.onPlayerPetLongPress != null
                    ? () => widget.onPlayerPetLongPress!(vm.playerTeam[i])
                    : null,
                snapHpBars: widget.snapHpBars,
                displayHp: _displayHpForPet(vm, vm.playerTeam[i]).$1,
                displayShield: _displayHpForPet(vm, vm.playerTeam[i]).$2,
                shieldPreview: _previewShieldForPet(vm, vm.playerTeam[i]),
              ),
              dash: _dashPixelsForPet(
                vm: vm,
                actorPetId: vm.playerTeam[i].id,
                isPlayerTeam: true,
                actorIndex: i,
                rawDash: vm.petDashOffsets[vm.playerTeam[i].id] ?? Offset.zero,
                w: w,
                h: h,
              ),
            ),

          // Projectiles
          for (final p in _projectiles)
            ProjectileWidget(
                key: ValueKey(p.id),
                data: p,
                onDone: () => _removeProjectile(p.id)),

          // Floating numbers
          for (final n in _floatNums)
            _BattleFloatingNumberWidget(
                key: ValueKey(n.id),
                num: n,
                onDone: () => _removeFloatNum(n.id)),
        ],
      );
    });
  }

  Widget _placed(double w, double h, Offset pos, Widget child,
      {Offset dash = Offset.zero}) {
    final p = Offset(w * pos.dx + dash.dx, h * pos.dy + dash.dy);
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      left: p.dx,
      top: p.dy,
      child: child,
    );
  }

  Offset _dashPixelsForPet({
    required PveBattleViewModel vm,
    required String actorPetId,
    required bool isPlayerTeam,
    required int actorIndex,
    required Offset rawDash,
    required double w,
    required double h,
  }) {
    if (rawDash == Offset.zero) return Offset.zero;

    final actorPositions = isPlayerTeam ? widget.playerPos : widget.opponentPos;
    final targetPositions =
        isPlayerTeam ? widget.opponentPos : widget.playerPos;
    final targetTeam = isPlayerTeam ? vm.enemyTeam : vm.playerTeam;

    final explicitTargetId = vm.petDashTargets[actorPetId];
    int targetIndex = -1;
    if (explicitTargetId != null) {
      targetIndex = targetTeam
          .indexWhere((p) => p.id == explicitTargetId && !p.isFainted);
      if (targetIndex < 0) return Offset.zero;
    }
    if (targetIndex < 0) {
      targetIndex = targetTeam.indexWhere((p) => !p.isFainted);
    }
    if (targetIndex < 0) return Offset.zero;

    final actorSpriteSize =
        kBattleSpriteBase * _kScaleByPos[actorIndex.clamp(0, 2)];
    final targetSpriteSize =
        kBattleSpriteBase * _kScaleByPos[targetIndex.clamp(0, 2)];
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

    return Offset(
        toTarget.dx / distance * dashDist, toTarget.dy / distance * dashDist);
  }

  (int, int) _displayHpForPet(PveBattleViewModel vm, PetViewModel pet) {
    if (pet.isFainted) return (0, 0);
    final impact = vm.lastImpactEvent;
    if (impact == null || (!vm.isResolving && !vm.awaitingOpponent)) {
      return (pet.hp, pet.shield);
    }
    if (impact.targetId == pet.id) {
      final hp = impact.targetHpAfter >= 0 ? impact.targetHpAfter : pet.hp;
      return (hp, impact.targetShieldAfter);
    }
    if (impact.actorId == pet.id) {
      final hp = impact.actorHpAfter >= 0 ? impact.actorHpAfter : pet.hp;
      return (hp, impact.actorShieldAfter);
    }
    return (pet.hp, pet.shield);
  }

  int _previewShieldForPet(PveBattleViewModel vm, PetViewModel pet) {
    var total = 0;
    final assignedIds = vm.pendingSkills[pet.id] ?? const [];
    for (final cardId in assignedIds) {
      final card = vm.hand.firstWhere(
        (c) => c.instanceId == cardId,
        orElse: () => throw StateError('Assigned card missing from hand: $cardId'),
      );
      total += card.trait.shieldAmount;
    }
    return total;
  }
}

// ── _BattlePet ────────────────────────────────────────────────────────────────

class _BattlePet extends StatelessWidget {
  final PetViewModel pet;
  final bool flipHorizontal;
  final bool hasSkill;
  final int positionIndex;
  final PetCharacterAnimState? animState;
  final String? attackSlot;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool snapHpBars;
  final int displayHp;
  final int displayShield;
  final int shieldPreview;

  const _BattlePet({
    required this.pet,
    required this.flipHorizontal,
    required this.hasSkill,
    required this.positionIndex,
    this.animState,
    this.attackSlot,
    this.onTap,
    this.onLongPress,
    this.snapHpBars = false,
    required this.displayHp,
    required this.displayShield,
    this.shieldPreview = 0,
  });

  @override
  Widget build(BuildContext context) {
    final scale = _kScaleByPos[positionIndex.clamp(0, 2)];
    final opacity = _kOpacityByPos[positionIndex.clamp(0, 2)];
    final spriteSize = kBattleSpriteBase * scale;
    final barWidth = (spriteSize * 0.50).clamp(80.0, 108.0);
    final hp = displayHp;
    final shield = displayShield;
    final isFainted = pet.isFainted || hp <= 0;
    final effectiveOpacity = isFainted ? 0.88 : opacity;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: onTap,
      onLongPress: onLongPress,
      child: Opacity(
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
                    child: _BattlePetSprite(
                      pet: pet,
                      size: spriteSize,
                      hasSkill: hasSkill,
                      flipHorizontal: flipHorizontal,
                      animState: animState,
                      attackSlot: attackSlot,
                    ),
                  ),
                  if (!isFainted)
                    Positioned(
                      top: 22,
                      left: 0,
                      right: 0,
                      child: BattleFloatingHpBar(
                        pet: pet,
                        currentHp: hp,
                        currentShield: shield,
                        shieldPreview: shieldPreview,
                        width: barWidth,
                        hpBarDuration: snapHpBars
                            ? Duration.zero
                            : const Duration(milliseconds: 500),
                      ),
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
      ),
    );
  }
}

class _BattlePetSprite extends StatelessWidget {
  final PetViewModel pet;
  final double size;
  final bool hasSkill;
  final bool flipHorizontal;
  final PetCharacterAnimState? animState;
  final String? attackSlot;

  const _BattlePetSprite({
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
              width: size,
              height: size,
              child: DeadPetEffect(size: size, flipHorizontal: flipHorizontal))
        else if (pet.creatureDef != null)
          SizedBox(
            width: size,
            height: size,
            child: PetRendererWidget(
              def: pet.creatureDef!,
              size: size,
              flipHorizontal: flipHorizontal,
              animation: battleAnimFor(animState, attackSlot: attackSlot),
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
            top: 0,
            right: 0,
            child: Container(
              width: 16,
              height: 16,
              decoration: const BoxDecoration(
                  shape: BoxShape.circle, color: AppColors.accent),
              child: const Icon(Icons.check, size: 10, color: Colors.white),
            ),
          ),

        // Status stroke icons — floats at bottom of sprite, above ground shadow
        if (!pet.isFainted)
          Positioned(
            bottom: 4,
            left: 0,
            right: 0,
            child: Center(child: _PetStatusIconRow(pet: pet)),
          ),
      ],
    );
  }

  static Color _petColor(String name) {
    const c = [
      Color(0xFF6C3FA1),
      Color(0xFF3FCFA1),
      Color(0xFFE8A838),
      Color(0xFFE53935),
      Color(0xFF1E88E5),
      Color(0xFF43A047),
    ];
    return c[name.codeUnits.first % c.length];
  }
}

// ── _PetStatusIconRow ─────────────────────────────────────────────────────────
//
// Shows up to 4 status-effect stroke icons overlaid at the bottom of the
// pet sprite. Debuffs are shown first (higher urgency), then buffs.
// Icon filenames match assets/images/status/classic/*.png.

class _PetStatusIconRow extends StatelessWidget {
  final PetViewModel pet;
  const _PetStatusIconRow({required this.pet});

  static const _kBase = 'assets/images/status/classic/';

  // Debuffs ordered by severity — most impactful shown first.
  static const _kDebuffIcons = {
      'stunned': 'stun-stroke.png',
      'poisoned': 'poison-stroke.png',
      'burned': 'critical-stroke.png',
      'stench': 'stench-stroke.png',
      'attackDown': 'attack-down-stroke.png',
      'attack_down': 'attack-down-stroke.png',
      'defenseDown': 'fragile-stroke.png',
    'defense_down': 'fragile-stroke.png',
    'speedDown': 'speed-down-stroke.png',
    'speed_down': 'speed-down-stroke.png',
  };

  // Buffs ordered by importance.
  static const _kBuffIcons = {
    'attackUp': 'attack-up-stroke.png',
    'attack_up': 'attack-up-stroke.png',
    'defenseUp': 'raise-shield-stroke.png',
    'defense_up': 'raise-shield-stroke.png',
    'speedUp': 'speed-up-stroke.png',
    'speed_up': 'speed-up-stroke.png',
    'regen': 'self-heal-stroke.png',
    'energized': 'gain-energy-stroke.png',
  };

  @override
  Widget build(BuildContext context) {
    final seen = <String>{};
    final icons = <_StatusIconEntry>[];

    for (final d in pet.activeDebuffs) {
      final icon = _kDebuffIcons[d];
      if (icon != null && seen.add(icon)) {
        icons.add(_StatusIconEntry(
          assetPath: '$_kBase$icon',
          roundsRemaining: d == 'stench' ? pet.debuffRoundsFor(d) : 0,
        ));
      }
    }
    for (final b in pet.activeBuffs) {
      final icon = _kBuffIcons[b];
      if (icon != null && seen.add(icon)) {
        icons.add(_StatusIconEntry(
          assetPath: '$_kBase$icon',
        ));
      }
    }

    if (icons.isEmpty) return const SizedBox.shrink();

    final display = icons.take(4).toList();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: display
          .map(
            (entry) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Image.asset(
                    entry.assetPath,
                    width: 22,
                    height: 22,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                  if (entry.roundsRemaining > 0)
                    Positioned(
                      right: -2,
                      top: -3,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.82),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFB44FD4), width: 1),
                        ),
                        child: Text(
                          '${entry.roundsRemaining}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 8,
                            height: 1,
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _StatusIconEntry {
  final String assetPath;
  final int roundsRemaining;

  const _StatusIconEntry({
    required this.assetPath,
    this.roundsRemaining = 0,
  });
}

// ── BattleFloatingHpBar ───────────────────────────────────────────────────────
// Public so PvE screen's _PetInfoSheet can reuse it if needed.

class BattleFloatingHpBar extends StatelessWidget {
  final PetViewModel pet;
  final int currentHp;
  final int currentShield;
  final int shieldPreview;
  final double width;
  final Duration hpBarDuration;
  const BattleFloatingHpBar({
    super.key,
    required this.pet,
    required this.currentHp,
    required this.currentShield,
    this.shieldPreview = 0,
    required this.width,
    this.hpBarDuration = const Duration(milliseconds: 500),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width.clamp(80.0, 108.0),
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
              Text('$currentHp',
                  style: const TextStyle(
                      color: Color(0xFF66FF88),
                      fontSize: 8,
                      fontWeight: FontWeight.w800)),
              const Spacer(),
              if (currentShield > 0) ...[
                const Icon(Icons.shield, size: 8, color: AppColors.shieldGold),
                const SizedBox(width: 1),
                Text('$currentShield',
                    style: const TextStyle(
                        color: AppColors.shieldGold,
                        fontSize: 8,
                        fontWeight: FontWeight.w800)),
              ],
              if (shieldPreview > 0) ...[
                if (currentShield > 0) const SizedBox(width: 2),
                Text(
                  '+$shieldPreview',
                  style: const TextStyle(
                    color: AppColors.shieldGold,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 1),
          HpBar(
            current: currentHp,
            max: pet.maxHp,
            height: 3,
            duration: hpBarDuration,
          ),
        ],
      ),
    );
  }
}

// ── _BattleFloatingNumberWidget ───────────────────────────────────────────────

class _BattleFloatingNumberWidget extends StatefulWidget {
  final _BattleFloatNum num;
  final VoidCallback onDone;
  const _BattleFloatingNumberWidget(
      {super.key, required this.num, required this.onDone});

  @override
  State<_BattleFloatingNumberWidget> createState() =>
      _BattleFloatingNumberWidgetState();
}

class _BattleFloatingNumberWidgetState
    extends State<_BattleFloatingNumberWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _rise, _fade, _scale;

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
              child: Stack(children: [
                Text(n.text,
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        foreground: Paint()
                          ..style = PaintingStyle.stroke
                          ..strokeWidth = 3
                          ..color = Colors.black87)),
                Text(n.text,
                    style: TextStyle(
                        color: n.color,
                        fontSize: 22,
                        fontWeight: FontWeight.w900)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

// ── BattleBottomPanel ─────────────────────────────────────────────────────────
//
// [energy orb] [card hand — grouped by pet] [endButtonSlot]
//
// endButtonSlot is provided by each screen so PvE and PvP can have different
// button styles (circle vs rectangle).

class BattleBottomPanel extends StatelessWidget {
  final PveBattleViewModel vm;
  final void Function(String instanceId) onAssignSkill;

  /// The end-turn or lock-in button. Wrapped internally in a fixed 88 px column.
  final Widget endButtonSlot;

  final bool isCollapsed;
  final VoidCallback onToggleCollapse;

  const BattleBottomPanel({
    super.key,
    required this.vm,
    required this.onAssignSkill,
    required this.endButtonSlot,
    required this.isCollapsed,
    required this.onToggleCollapse,
  });

  @override
  Widget build(BuildContext context) {
    if (vm.isResolving) return const SizedBox.shrink();

    return SizedBox(
      height: kBattlePanelH,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Tray background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xB80A0E1A), Color(0xF80A0E1A)],
              ),
              border:
                  Border(top: BorderSide(color: Color(0xFF2A3860), width: 2)),
            ),
          ),
          // Inner shadow
          Positioned(
            top: 2,
            left: 0,
            right: 0,
            child: Container(
              height: 18,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.28),
                    Colors.transparent
                  ],
                ),
              ),
            ),
          ),
          // Content
          Positioned.fill(
            top: 20,
            child: _BattleBottomPanelContent(
              vm: vm,
              onAssignSkill: onAssignSkill,
              endButtonSlot: endButtonSlot,
            ),
          ),
          // Show/hide toggle
          Align(
            alignment: Alignment.topCenter,
            child: GestureDetector(
              onTap: onToggleCollapse,
              child: Container(
                margin: const EdgeInsets.only(top: 3),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
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
                        color: Colors.white70),
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

class _BattleBottomPanelContent extends StatelessWidget {
  final PveBattleViewModel vm;
  final void Function(String) onAssignSkill;
  final Widget endButtonSlot;

  const _BattleBottomPanelContent({
    required this.vm,
    required this.onAssignSkill,
    required this.endButtonSlot,
  });

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
            child:
                BattleEnergyDisplay(energy: previewEnergy, max: kTeamEnergyCap),
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
                            final isAssigned =
                                assigned.contains(card.instanceId);
                            final comboIdx = isAssigned
                                ? assigned.indexOf(card.instanceId) + 1
                                : null;
                            final isNew =
                                vm.newCardIds.contains(card.instanceId);
                            final isFizzled =
                                vm.fizzledCardIds.contains(card.instanceId);

                            final prevPet = i > 0 ? entries[i - 1].$1 : null;
                            final isNewPet =
                                prevPet == null || prevPet.id != pet.id;
                            final petColor = _clsColor(
                                pet.creatureDef?.bodyClass.name ?? '');
                            final clsName =
                                pet.creatureDef?.bodyClass.name ?? '';
                            final clsLabel = clsName.isEmpty
                                ? ''
                                : '${clsName[0].toUpperCase()}${clsName.substring(1)}';

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
                                            color: petColor.withValues(
                                                alpha: 0.18),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            border: Border.all(
                                                color: petColor.withValues(
                                                    alpha: 0.55)),
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
                                BattleSkillCard(
                                  trait: card.trait,
                                  petName: card.ownerPetName,
                                  isSelected: isAssigned,
                                  isPity: card.isPity,
                                  isFizzled: isFizzled,
                                  cardArtPath: card.cardArtPath,
                                  cardTemplatePath: card.cardTemplatePath,
                                  comboIndex: comboIdx,
                                  petColor: card.petColor,
                                  onTap: () => onAssignSkill(card.instanceId),
                                ),
                              ],
                            );

                            if (isNew) {
                              w = BattleCardEntrance(
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

        // End-turn button slot
        SizedBox(width: 88, child: Center(child: endButtonSlot)),
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

// ── BattleEnergyDisplay ───────────────────────────────────────────────────────

class BattleEnergyDisplay extends StatelessWidget {
  final int energy;
  final int max;
  const BattleEnergyDisplay(
      {super.key, required this.energy, required this.max});

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
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    c.withValues(alpha: frac * 0.5),
                    c.withValues(alpha: 0.0),
                  ]),
                ),
              ),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    center: const Alignment(-0.3, -0.3),
                    colors: [
                      energy > 0
                          ? c.withValues(alpha: 0.9)
                          : Colors.white.withValues(alpha: 0.1),
                      energy > 0 ? const Color(0xFF0A3A6A) : Colors.black45,
                    ],
                  ),
                  border: Border.all(
                      color: energy > 0
                          ? c.withValues(alpha: 0.8)
                          : Colors.white12,
                      width: 2),
                  boxShadow: energy > 0
                      ? [
                          BoxShadow(
                              color: c.withValues(alpha: 0.6),
                              blurRadius: 12,
                              spreadRadius: 1)
                        ]
                      : null,
                ),
                child: Center(
                  child: Text('$energy',
                      style: GoogleFonts.rajdhani(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          height: 1)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        // Gem row
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
              max,
              (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 7,
                    height: 7,
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < energy ? c : Colors.white12,
                      boxShadow: i < energy
                          ? [
                              BoxShadow(
                                  color: c.withValues(alpha: 0.7),
                                  blurRadius: 4)
                            ]
                          : null,
                    ),
                  )),
        ),
      ],
    );
  }
}

// ── BattleFeed ────────────────────────────────────────────────────────────────

class BattleFeed extends StatelessWidget {
  final String log;
  const BattleFeed({super.key, required this.log});

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

// ── BattleSkillCard ───────────────────────────────────────────────────────────
//
// The Axie-style card tile. Works in the hand and in the discard popup.
// discardMode: shows red vignette + close icon, locks selection.

class BattleSkillCard extends StatelessWidget {
  final TraitViewModel trait;
  final String petName;
  final bool isSelected;
  final bool isPity;
  final bool discardMode;
  final bool isFizzled;
  final String? cardArtPath;
  final String? cardTemplatePath;
  final int? comboIndex;
  final Color? petColor; // Pet class color for badge
  final VoidCallback? onTap;

  const BattleSkillCard({
    super.key,
    required this.trait,
    required this.petName,
    required this.isSelected,
    this.isPity = false,
    this.discardMode = false,
    this.isFizzled = false,
    this.cardArtPath,
    this.cardTemplatePath,
    this.comboIndex,
    this.petColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final usable = discardMode || trait.isUsable;
    final tc =
        discardMode ? const Color(0xFFFF6060) : _typeColor(trait.typeName);
    final cardEntry = kBattleCardCatalogByTraitId[trait.id];
    final resolvedTemplatePath = cardTemplatePath ??
        cardEntry?.templatePath ??
        cardArtPath ??
        'assets/images/part-cards/default-card-art.png';
    final resolvedImageName = cardEntry?.imageName ??
        battleClassicImageNameFromPath(cardTemplatePath) ??
        battleClassicImageNameFromPath(cardArtPath) ??
        battleClassicImageNameFromPath(resolvedTemplatePath) ??
        '';

    final cardW = discardMode ? 108.0 : 96.0;
    final cardH = discardMode ? 148.0 : 134.0;
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
            if (discardMode)
              const BoxShadow(
                  color: Color(0xFFCC2020), blurRadius: 14, spreadRadius: 3),
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
                    name: '$petName - ${trait.name}',
                    energy: trait.energyCost,
                    attack: battleClassicCardAttack(trait, cardEntry),
                    defense: battleClassicCardDefense(trait, cardEntry),
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
                            Colors.transparent
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.center,
                        ),
                      ),
                    ),
                  ),
                if (!trait.isReady)
                  Positioned(
                    bottom: 4,
                    left: 4,
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
                // Pet class color badge (top-left corner)
                if (petColor != null)
                  Positioned(
                    top: 4,
                    left: 4,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: petColor,
                        border: Border.all(color: Colors.white70, width: 0.5),
                        boxShadow: [
                          BoxShadow(
                              color: petColor!.withValues(alpha: 0.5),
                              blurRadius: 4)
                        ],
                      ),
                    ),
                  ),
                if (comboIndex != null)
                  Positioned(
                    top: 22,
                    right: 4,
                    child: Container(
                      width: 18,
                      height: 18,
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
                if (isPity && !discardMode)
                  Positioned(
                    bottom: 5,
                    left: 5,
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
                          style: TextStyle(color: Colors.amber, fontSize: 7)),
                    ),
                  ),
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
                            const Color(0xFFCC2020).withValues(alpha: 0.35)
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 5,
                    right: 5,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFCC2020).withValues(alpha: 0.9),
                        boxShadow: const [
                          BoxShadow(color: Colors.black54, blurRadius: 4)
                        ],
                      ),
                      child: const Icon(Icons.close,
                          size: 13, color: Colors.white),
                    ),
                  ),
                ],
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

// ── BattleCardEntrance ────────────────────────────────────────────────────────

class BattleCardEntrance extends StatefulWidget {
  final Widget child;
  final Duration delay;
  const BattleCardEntrance(
      {super.key, required this.child, required this.delay});

  @override
  State<BattleCardEntrance> createState() => _BattleCardEntranceState();
}

class _BattleCardEntranceState extends State<BattleCardEntrance>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 380));
    _opacity = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _slide = Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero)
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
  Widget build(BuildContext context) => FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _slide, child: widget.child));
}

// ── BattleLoadingScreen ───────────────────────────────────────────────────────

class BattleLoadingScreen extends StatelessWidget {
  final String message;
  const BattleLoadingScreen({super.key, required this.message});

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
