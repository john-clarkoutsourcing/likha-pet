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
const double kBattleSpriteBase = 142.0;
const _kScaleByPos = [1.55, 1.55, 1.55];
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
    'damage' => trait.effectIconValue,
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
    final screenW = MediaQuery.sizeOf(context).width;
    final compact = screenW < 900;

    return Container(
      height: compact ? 58 : 64,
      padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 10),
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
          _TeamTag(name: leftName, isPlayer: leftIsPlayer, compact: compact),
          SizedBox(width: compact ? 4 : 8),
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
                            fontSize: compact ? 9 : 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _BattleRoundTimer(timer: timer, compact: compact),
                      ],
                    ),
                    if (vm.isBloodMoon) ...[
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          color: const Color(0xFF6A0F16).withValues(alpha: 0.92),
                          border: Border.all(
                            color: const Color(0xFFFF5A67).withValues(alpha: 0.95),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  const Color(0xFFFF2D3F).withValues(alpha: 0.42),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Text(
                          'BLOOD MOON',
                          style: GoogleFonts.rajdhani(
                            color: const Color(0xFFFFD6DB),
                            fontSize: compact ? 8 : 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 3),
                    _BattleAttackOrderStrip(vm: vm, compact: compact),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(width: compact ? 4 : 8),
          _TeamTag(name: rightName, isPlayer: rightIsPlayer, compact: compact),
          if (!compact) ...[
            const SizedBox(width: 6),
            _TopHudUtilityCluster(deckCount: vm.deckDrawSize),
          ],
        ],
      ),
    );
  }
}

class _TeamTag extends StatelessWidget {
  final String name;
  final bool isPlayer;
  final bool compact;
  const _TeamTag({
    required this.name,
    required this.isPlayer,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isPlayer ? AppColors.accent : AppColors.offensive;
    final avatarSize = compact ? 22.0 : 26.0;
    final avatar = Container(
      width: avatarSize,
      height: avatarSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.22),
        border: Border.all(color: color.withValues(alpha: 0.9), width: 1.6),
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
        color: Colors.white70,
        fontSize: compact ? 10 : 11,
        fontWeight: FontWeight.w700));

    final labelWidth = compact ? 52.0 : 74.0;
    final content = isPlayer
        ? Row(mainAxisSize: MainAxisSize.min, children: [
            avatar,
            const SizedBox(width: 6),
            SizedBox(width: labelWidth, child: label),
          ])
        : Row(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(width: labelWidth, child: label),
            const SizedBox(width: 6),
            avatar,
          ]);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF8A5A2B), Color(0xFF5A3317)],
        ),
        border: Border.all(color: const Color(0xFFD5A26A).withValues(alpha: 0.9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: content,
    );
  }
}

class _TopHudUtilityCluster extends StatelessWidget {
  final int deckCount;
  const _TopHudUtilityCluster({required this.deckCount});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _UtilityCircleButton(
          icon: Icons.settings_rounded,
          tooltip: 'Settings',
        ),
        const SizedBox(width: 6),
        _UtilityCircleButton(
          icon: Icons.style_rounded,
          tooltip: 'Deck',
          badgeText: '$deckCount',
        ),
      ],
    );
  }
}

class _UtilityCircleButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final String? badgeText;

  const _UtilityCircleButton({
    required this.icon,
    required this.tooltip,
    this.badgeText,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF1C2438).withValues(alpha: 0.9),
              border: Border.all(color: Colors.white24),
            ),
            child: Icon(icon, size: 15, color: Colors.white70),
          ),
          if (badgeText != null)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFFE89A32),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.black54),
                ),
                child: Text(
                  badgeText!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BattleRoundTimer extends StatelessWidget {
  final AnimationController timer;
  final bool compact;
  const _BattleRoundTimer({required this.timer, this.compact = false});

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
        final timerSize = compact ? 30.0 : 34.0;
        return SizedBox(
          width: timerSize,
          height: timerSize,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                  value: remaining,
                  strokeWidth: compact ? 2.5 : 3,
                  color: color,
                  backgroundColor: Colors.white12),
              Text('$seconds',
                  style: TextStyle(
                      color: color,
                      fontSize: compact ? 10 : 11,
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
  final bool compact;
  const _BattleAttackOrderStrip({required this.vm, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final alive = vm.turnOrder.where((e) => !e.isFainted).toList();
    final visible = compact && alive.length > 4 ? alive.take(4).toList() : alive;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < visible.length; i++) ...[
          if (i > 0)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 1),
              child: Icon(Icons.chevron_right, size: 9, color: Colors.white24),
            ),
          _BattleOrderBadge(
            entry: visible[i],
            number: i + 1,
            isFirst: i == 0,
            compact: compact,
          ),
        ],
        if (visible.length < alive.length)
          const Padding(
            padding: EdgeInsets.only(left: 3),
            child: Text(
              '…',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
      ],
    );
  }
}

class _BattleOrderBadge extends StatelessWidget {
  final TurnOrderEntry entry;
  final int number;
  final bool isFirst;
  final bool compact;
  const _BattleOrderBadge(
      {required this.entry,
      required this.number,
      required this.isFirst,
      this.compact = false});

  @override
  Widget build(BuildContext context) {
    final c = entry.isPlayer ? AppColors.accent : AppColors.offensive;
    final size = compact
        ? (isFirst ? 38.0 : 30.0)
        : (isFirst ? 46.0 : 36.0);
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
                                fontSize: compact
                                    ? (isFirst ? 11 : 9)
                                    : (isFirst ? 13 : 10),
                                fontWeight: FontWeight.w900))))
                : Center(
                    child: Text(entry.name[0],
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: compact
                                ? (isFirst ? 11 : 9)
                                : (isFirst ? 13 : 10),
                            fontWeight: FontWeight.w900))),
          ),
        ),
        Positioned(
          top: compact ? -3 : -4,
          left: compact ? -3 : -4,
          child: Container(
            width: compact ? 12 : 14,
            height: compact ? 12 : 14,
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
  // Used for coalescing: shield floats for the same pet are merged.
  final bool isShield;
  final String petId;
  const _BattleFloatNum({
    required this.id,
    required this.text,
    required this.color,
    required this.x,
    required this.y,
    this.jitter   = 0.0,
    this.isShield = false,
    this.petId    = '',
  });
}

class _BattlefieldViewState extends ConsumerState<BattlefieldView> {
  final List<ProjectileInstance> _projectiles = [];
  final List<_BattleFloatNum> _floatNums = [];
  int _nextId = 0;
  int _lastProjectileToken = -1;

  // Accumulated shield amounts per petId since the last non-shield event.
  // Lets consecutive shield floats for the same pet merge into one display.
  final Map<String, int> _shieldAccum = {};

  @override
  void didUpdateWidget(BattlefieldView old) {
    super.didUpdateWidget(old);
    if (old.vm.lastImpactEvent != null && widget.vm.lastImpactEvent == null) {
      _shieldAccum.clear();
    }
    // Float nums compare old vs new vm — must stay in didUpdateWidget.
    // Projectile spawning is handled in build() so it fires for both
    // prop-driven and Riverpod-driven rebuilds.
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
        bool isShield = false,
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
          id:       '${_nextId++}',
          text:     text,
          color:    color,
          x:        pos.dx + 30,
          y:        pos.dy - 10,
          jitter:   (rng.nextDouble() - 0.5) * 24,
          isShield: isShield,
          petId:    petId,
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
                // Accumulate shield for this pet and remove any previous
                // shield float so we show a single total, not "20 20 20".
                _shieldAccum[petId] =
                    (_shieldAccum[petId] ?? 0) + impact.shieldAmount;
                setState(() {
                  _floatNums.removeWhere(
                      (n) => n.isShield && n.petId == petId);
                });
                spawnAt(
                  petId:        petId,
                  isPlayerTeam: isPlayerTeam,
                  index:        index,
                  text:         '+${_shieldAccum[petId]}',
                  color:        AppColors.shieldGold,
                  isShield:     true,
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
    final token = vm.pendingProjectileToken;
    final actorId = vm.pendingProjectileActorId;
    final targetId = vm.pendingProjectileTargetId;
    if (actorId == null || targetId == null || targetId.isEmpty) return;
    if (token == _lastProjectileToken) return;
    _lastProjectileToken = token;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      if (box == null) return;
      final w = box.size.width;
      final h = box.size.height;

      final isPlayerActor = vm.playerTeam.any((p) => p.id == actorId);
      final actorTeam = isPlayerActor ? vm.playerTeam : vm.enemyTeam;
      final targetTeam = isPlayerActor ? vm.enemyTeam : vm.playerTeam;
      final actorPositions = isPlayerActor ? widget.playerPos : widget.opponentPos;
      final targetPositions = isPlayerActor ? widget.opponentPos : widget.playerPos;

      final actorIdx = actorTeam.indexWhere((p) => p.id == actorId);
      final targetIdx = targetTeam.indexWhere((p) => p.id == targetId);
      // Fall back to first alive enemy if target not found.
      final resolvedTargetIdx = targetIdx >= 0
          ? targetIdx
          : targetTeam.indexWhere((p) => !p.isFainted);
      if (actorIdx < 0 || resolvedTargetIdx < 0) return;

      const spriteOffset = 29.0;
      final startFrac = actorPositions[actorIdx.clamp(0, actorPositions.length - 1)];
      final endFrac = targetPositions[resolvedTargetIdx.clamp(0, targetPositions.length - 1)];
      final start = Offset(w * startFrac.dx + spriteOffset, h * startFrac.dy + spriteOffset);
      final end   = Offset(w * endFrac.dx   + spriteOffset, h * endFrac.dy   + spriteOffset);

      final cfg = configForCreatureClass(vm.pendingProjectileClass ?? '');
      setState(() => _projectiles.add(
            ProjectileInstance(id: '${_nextId++}', start: start, end: end, config: cfg),
          ));
    });
  }


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

    // Always check for pending projectiles here — didUpdateWidget only fires
    // for prop changes, missing Riverpod-driven rebuilds when liveProvider is set.
    _maybeSpawnProjectiles(vm);

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

          // Opponent pets — use pet.position (= pet.row) for visual slot
          for (var i = 0; i < vm.enemyTeam.length; i++) ...[
            if (i < widget.opponentPos.length) () {
              final pet = vm.enemyTeam[i];
              final posIdx = pet.position.clamp(0, widget.opponentPos.length - 1);
              final base  = widget.opponentPos[posIdx];
              final pos   = _laneAdjust(base, pet.lane);
              final anim  = vm.petAnimStates[pet.id];
              final isAttacking = anim == PetCharacterAnimState.attackMelee ||
                  anim == PetCharacterAnimState.attackRanged;
              return _placed(w, h, pos,
                AnimatedScale(
                  scale: isAttacking ? 1.10 : 1.0,
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOutBack,
                  child: _BattlePet(
                    pet: pet,
                    flipHorizontal: widget.opponentFlipHorizontal,
                    hasSkill: false,
                    positionIndex: posIdx,
                    animState: anim,
                    attackSlot: vm.petAttackSlots[pet.id],
                    onTap: widget.onOpponentPetTap != null
                        ? () => widget.onOpponentPetTap!(pet) : null,
                    snapHpBars: widget.snapHpBars,
                    displayHp: _displayHpForPet(vm, pet).$1,
                    displayShield: _displayHpForPet(vm, pet).$2,
                    shieldPreview: _previewShieldForPet(vm, pet),
                  ),
                ),
                dash: _dashPixelsForPet(
                  vm: vm, actorPetId: pet.id, isPlayerTeam: false,
                  actorIndex: posIdx,
                  rawDash: vm.petDashOffsets[pet.id] ?? Offset.zero,
                  w: w, h: h,
                ),
              );
            }(),
          ],

          // Player pets — use pet.position (= pet.row) for visual slot
          for (var i = 0; i < vm.playerTeam.length; i++) ...[
            if (i < widget.playerPos.length) () {
              final pet = vm.playerTeam[i];
              final posIdx = pet.position.clamp(0, widget.playerPos.length - 1);
              final base  = widget.playerPos[posIdx];
              final pos   = _laneAdjust(base, pet.lane);
              final anim  = vm.petAnimStates[pet.id];
              final isAttacking = anim == PetCharacterAnimState.attackMelee ||
                  anim == PetCharacterAnimState.attackRanged;
              return _placed(w, h, pos,
                AnimatedScale(
                  scale: isAttacking ? 1.10 : 1.0,
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOutBack,
                  child: _BattlePet(
                    pet: pet,
                    flipHorizontal: widget.playerFlipHorizontal,
                    hasSkill: vm.pendingSkills[pet.id]?.isNotEmpty ?? false,
                    positionIndex: posIdx,
                    animState: anim,
                    attackSlot: vm.petAttackSlots[pet.id],
                    onTap: widget.onPlayerPetTap != null
                        ? () => widget.onPlayerPetTap!(pet) : null,
                    onLongPress: widget.onPlayerPetLongPress != null
                        ? () => widget.onPlayerPetLongPress!(pet) : null,
                    snapHpBars: widget.snapHpBars,
                    displayHp: _displayHpForPet(vm, pet).$1,
                    displayShield: _displayHpForPet(vm, pet).$2,
                    shieldPreview: _previewShieldForPet(vm, pet),
                  ),
                ),
                dash: _dashPixelsForPet(
                  vm: vm, actorPetId: pet.id, isPlayerTeam: true,
                  actorIndex: posIdx,
                  rawDash: vm.petDashOffsets[pet.id] ?? Offset.zero,
                  w: w, h: h,
                ),
              );
            }(),
          ],

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

  // Offset y by lane so pets in the same row don't overlap.
  // lane=0 upper, lane=1 center (no shift), lane=2 lower.
  static Offset _laneAdjust(Offset base, int lane) {
    const kLaneSpacing = 0.07; // fraction of screen height per lane step
    return Offset(base.dx, base.dy + (lane - 1) * kLaneSpacing);
  }

  Widget _placed(double w, double h, Offset pos, Widget child,
      {Offset dash = Offset.zero}) {
    final p = Offset(w * pos.dx + dash.dx, h * pos.dy + dash.dy);
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeInOutCubic,
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
    final barWidth = (spriteSize * 0.40).clamp(60.0, 74.0);
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
                      top: -4,
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
                          : const Duration(milliseconds: 620),
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
    final coreSprite = pet.isFainted
        ? SizedBox(
            width: size,
            height: size,
            child: DeadPetEffect(size: size, flipHorizontal: flipHorizontal),
          )
        : pet.creatureDef != null
            ? SizedBox(
                width: size,
                height: size,
                child: PetRendererWidget(
                  def: pet.creatureDef!,
                  size: size,
                  flipHorizontal: flipHorizontal,
                  animation: battleAnimFor(animState, attackSlot: attackSlot),
                  figScale: 0.26,
                  yOff: 0.70,
                ),
              )
            : PetSpriteWidget(
                config: pet.spriteConfig,
                size: size,
                flipHorizontal: flipHorizontal,
                petName: pet.name,
                petColor: color,
              );

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        Positioned(
          bottom: -2,
          child: Container(
            width: size * 0.58,
            height: 12,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(50),
              gradient: RadialGradient(colors: [
                Colors.black.withValues(alpha: 0.42),
                Colors.black.withValues(alpha: 0.0),
              ], radius: 0.85),
            ),
          ),
        ),
        _BattleReactionMotion(
          animState: animState,
          seedKey: pet.id,
          child: coreSprite,
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

class _BattleReactionMotion extends StatefulWidget {
  final Widget child;
  final PetCharacterAnimState? animState;
  final String seedKey;

  const _BattleReactionMotion({
    required this.child,
    required this.animState,
    required this.seedKey,
  });

  @override
  State<_BattleReactionMotion> createState() => _BattleReactionMotionState();
}

class _BattleReactionMotionState extends State<_BattleReactionMotion>
    with TickerProviderStateMixin {
  late final AnimationController _idleCtrl;
  late final AnimationController _hitCtrl;

  @override
  void initState() {
    super.initState();
    final variance = widget.seedKey.codeUnits.fold<int>(0, (a, b) => a + b) % 450;
    _idleCtrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1800 + variance),
    )..repeat();
    _hitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
  }

  @override
  void didUpdateWidget(covariant _BattleReactionMotion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animState != PetCharacterAnimState.hit &&
        widget.animState == PetCharacterAnimState.hit) {
      _hitCtrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _idleCtrl.dispose();
    _hitCtrl.dispose();
    super.dispose();
  }

  bool get _idleEnabled {
    return switch (widget.animState) {
      PetCharacterAnimState.hit ||
      PetCharacterAnimState.faint ||
      PetCharacterAnimState.move ||
      PetCharacterAnimState.attack ||
      PetCharacterAnimState.attackMelee ||
      PetCharacterAnimState.attackRanged => false,
      _ => true,
    };
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_idleCtrl, _hitCtrl]),
      builder: (_, __) {
        final idlePhase = _idleCtrl.value * math.pi * 2;
        final idleY = _idleEnabled ? math.sin(idlePhase) * 2.0 : 0.0;
        final idleScale = _idleEnabled ? 1.0 + math.sin(idlePhase) * 0.008 : 1.0;

        final hitT = _hitCtrl.value;
        final hitX = hitT > 0 ? math.sin(hitT * math.pi * 6) * (1.0 - hitT) * 7.0 : 0.0;

        return Transform.translate(
          offset: Offset(hitX, idleY),
          child: Transform.scale(
            scale: idleScale,
            child: widget.child,
          ),
        );
      },
    );
  }
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

  // Last Stand gold color — matches Axie Infinity classic orange-gold Last Stand bar
  static const _kLastStandColor = Color(0xFFFFAA00);

  @override
  Widget build(BuildContext context) {
    final inLastStand = pet.isInLastStand;
    final hpRatio = pet.maxHp > 0
        ? (currentHp / pet.maxHp).clamp(0.0, 1.0)
        : 0.0;
    final className = pet.creatureDef?.bodyClass.name.toLowerCase() ?? '';
    final classColor = _classColor(className);

    // Axie classic HP color: green → yellow → red.
    // Last Stand overrides to gold regardless of HP (HP is 0 but pet still fights).
    final hpColor = inLastStand
        ? _kLastStandColor
        : hpRatio > 0.5
            ? const Color(0xFFC0EB4B)
            : hpRatio > 0.25
                ? const Color(0xFFF59E0B)
                : const Color(0xFFE53935);

    final statuses = _allStatuses(pet);
    final showShield = currentShield > 0;
    final effectiveHpDuration = hpBarDuration == Duration.zero
        ? const Duration(milliseconds: 260)
        : hpBarDuration;

    return SizedBox(
      width: width.clamp(60.0, 74.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Status icons row ──────────────────────────────────────────────
          if (statuses.isNotEmpty)
            SizedBox(
              height: 16,
              child: Align(
                alignment: Alignment.center,
                child: Wrap(
                  spacing: 3,
                  runSpacing: 0,
                  alignment: WrapAlignment.center,
                  children: statuses.map((status) {
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Image.asset(
                          status.assetPath,
                          width: 14,
                          height: 14,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.bolt_rounded,
                            size: 10,
                            color: Colors.white,
                          ),
                        ),
                        if (status.stacksOrRounds > 1)
                          Positioned(
                            right: -5,
                            top: -3,
                            child: Text(
                              '${status.stacksOrRounds}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                height: 1,
                                fontWeight: FontWeight.w900,
                                shadows: [
                                  Shadow(color: Colors.black87, blurRadius: 2),
                                ],
                              ),
                            ),
                          ),
                      ],
                    );
                  }).toList(growable: false),
                ),
              ),
            )
          else
            const SizedBox(height: 2),

          // ── HP row ────────────────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (showShield)
                CustomPaint(
                  size: const Size(20, 20),
                  painter: _ShieldPainter(shieldValue: currentShield),
                )
              else
                const SizedBox(width: 20, height: 20),
              const SizedBox(width: 3),
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: inLastStand ? _kLastStandColor : classColor,
                  borderRadius: BorderRadius.circular(3),
                ),
                alignment: Alignment.center,
                child: inLastStand
                    ? Text(
                        '${pet.lastStandTicks}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      )
                    : Icon(_classIcon(className), size: 11, color: Colors.white),
              ),
              const SizedBox(width: 3),
              Expanded(
                child: Container(
                  height: 22,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: inLastStand
                        ? _kLastStandColor.withValues(alpha: 0.18)
                        : const Color(0xFF111111).withValues(alpha: 0.58),
                    borderRadius: BorderRadius.circular(3),
                    border: inLastStand
                        ? Border.all(
                            color: _kLastStandColor.withValues(alpha: 0.7),
                            width: 1)
                        : null,
                  ),
                  child: Row(
                    children: [
                      // HP number or Last Stand label
                      if (inLastStand)
                        const Text(
                          'LAST STAND',
                          style: TextStyle(
                            color: _kLastStandColor,
                            fontSize: 7,
                            fontWeight: FontWeight.w900,
                            height: 1,
                            letterSpacing: 0.3,
                            shadows: [
                              Shadow(color: Colors.black87, blurRadius: 2),
                            ],
                          ),
                        )
                      else
                        Text(
                          '$currentHp',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            height: 1,
                            shadows: [
                              Shadow(color: Colors.black87, blurRadius: 2),
                            ],
                          ),
                        ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Stack(
                          children: [
                            Container(
                              height: 6,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.55),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                // In Last Stand, bar pulses at full width in gold
                                final barWidth = inLastStand
                                    ? constraints.maxWidth
                                    : constraints.maxWidth * hpRatio;
                                return AnimatedContainer(
                                  duration: effectiveHpDuration,
                                  curve: Curves.easeOutCubic,
                                  width: barWidth,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: hpColor,
                                    borderRadius: BorderRadius.circular(2),
                                    boxShadow: inLastStand
                                        ? [
                                            BoxShadow(
                                              color: _kLastStandColor
                                                  .withValues(alpha: 0.6),
                                              blurRadius: 4,
                                            )
                                          ]
                                        : null,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // ── Morale badge (Axie classic — drives Last Stand + crit chance) ─
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.favorite,
                          size: 7, color: Color(0xFFFF6B8A)),
                      const SizedBox(width: 2),
                      Text(
                        '${pet.morale}',
                        style: const TextStyle(
                          color: Color(0xFFFF6B8A),
                          fontSize: 7,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.auto_fix_high,
                          size: 7, color: Color(0xFF93C5FD)),
                      const SizedBox(width: 2),
                      Text(
                        '${pet.skill}',
                        style: const TextStyle(
                          color: Color(0xFF93C5FD),
                          fontSize: 7,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Color _classColor(String className) => switch (className) {
        'plant' => const Color(0xFF56A54A),
        'aquatic' => const Color(0xFF2699F1),
        'beast' => const Color(0xFFDA8A2A),
        'reptile' => const Color(0xFF5DA468),
        'bird' => const Color(0xFFE85D8A),
        'bug' => const Color(0xFFCC4F4F),
        _ => const Color(0xFF6B7280),
      };

  static List<_HudStatus> _allStatuses(PetViewModel pet) {
    const base = 'assets/images/status/classic/';
    final out = <_HudStatus>[];

    if (pet.isStunned) {
      out.add(const _HudStatus(assetPath: '${base}stun-stroke.png', stacksOrRounds: 1));
    }
    if (pet.poisonStacks > 0) {
      out.add(_HudStatus(
        assetPath: '${base}poison-stroke.png',
        stacksOrRounds: pet.poisonStacks,
      ));
    }

    for (final d in pet.activeDebuffs) {
      final map = {
        'burned': '${base}critical-stroke.png',
        'stench': '${base}stench-stroke.png',
        'attackDown': '${base}attack-down-stroke.png',
        'attack_down': '${base}attack-down-stroke.png',
        'defenseDown': '${base}fragile-stroke.png',
        'defense_down': '${base}fragile-stroke.png',
        'speedDown': '${base}speed-down-stroke.png',
        'speed_down': '${base}speed-down-stroke.png',
      };
      final icon = map[d] ?? '${base}debuff-stroke.png';
      out.add(_HudStatus(
        assetPath: icon,
        stacksOrRounds: pet.debuffRoundsFor(d).clamp(1, 99),
      ));
    }

    for (final b in pet.activeBuffs) {
      final map = {
        'attackUp': '${base}attack-up-stroke.png',
        'attack_up': '${base}attack-up-stroke.png',
        'defenseUp': '${base}raise-shield-stroke.png',
        'defense_up': '${base}raise-shield-stroke.png',
        'speedUp': '${base}speed-up-stroke.png',
        'speed_up': '${base}speed-up-stroke.png',
        'regen': '${base}self-heal-stroke.png',
        'energized': '${base}gain-energy-stroke.png',
      };
      out.add(_HudStatus(
        assetPath: map[b] ?? '${base}buff-stroke.png',
        stacksOrRounds: 1,
      ));
    }

    return out;
  }

  static IconData _classIcon(String className) => switch (className) {
        'plant' => Icons.local_florist_rounded,
        'aquatic' => Icons.water_drop_rounded,
        'beast' => Icons.pets_rounded,
        'reptile' => Icons.forest_rounded,
        'bird' => Icons.flutter_dash_rounded,
        'bug' => Icons.bug_report_rounded,
        _ => Icons.adjust_rounded,
      };
}

class _HudStatus {
  final String assetPath;
  final int stacksOrRounds;

  const _HudStatus({required this.assetPath, required this.stacksOrRounds});
}

// ── _ShieldPainter ───────────────────────────────────────────────────────────
// Custom painter to draw a shield shape with the shield value inside

class _ShieldPainter extends CustomPainter {
  final int shieldValue;
  _ShieldPainter({required this.shieldValue});

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    
    // Shield path (diamond-like shape)
    final path = Path();
    path.moveTo(width / 2, 0); // top point
    path.lineTo(width, height * 0.4); // right upper
    path.lineTo(width * 0.85, height); // right lower
    path.lineTo(width / 2, height * 0.85); // bottom point
    path.lineTo(width * 0.15, height); // left lower
    path.lineTo(0, height * 0.4); // left upper
    path.close();

    // Draw shield fill
    final paint = Paint()
      ..color = const Color(0xFF2B6CB0)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, paint);

    // Draw shield border
    final borderPaint = Paint()
      ..color = const Color(0xFF4A9FD8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(path, borderPaint);

    // Draw shield value text
    final textPainter = TextPainter(
      text: TextSpan(
        text: '$shieldValue',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        (width - textPainter.width) / 2,
        (height - textPainter.height) / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(_ShieldPainter oldDelegate) {
    return oldDelegate.shieldValue != shieldValue;
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
                    Builder(builder: (context) {
                      final compact = MediaQuery.sizeOf(context).width < 900;
                      return Icon(
                          isCollapsed
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          size: compact ? 13 : 15,
                          color: Colors.white70);
                    }),
                    const SizedBox(width: 4),
                    Builder(builder: (context) {
                      final compact = MediaQuery.sizeOf(context).width < 900;
                      final label = compact
                          ? 'Deck'
                          : (isCollapsed ? 'Show Deck' : 'Hide Deck');
                      return Text(label,
                          style: TextStyle(
                              color: Colors.white70,
                              fontSize: compact ? 9 : 10,
                              fontWeight: FontWeight.w700));
                    }),
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 900;
        final energySlotW = compact ? 62.0 : 76.0;
        final endSlotW = compact ? 90.0 : 102.0;
        final listPadding = compact
            ? const EdgeInsets.fromLTRB(2, 6, 2, 6)
            : const EdgeInsets.fromLTRB(4, 6, 4, 6);

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Energy orb
            SizedBox(
              width: energySlotW,
              child: Center(
                child: BattleEnergyDisplay(
                    energy: previewEnergy, max: kTeamEnergyCap),
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
                              padding: listPadding,
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
                                final petColor =
                                    _clsColor(pet.creatureDef?.bodyClass.name ?? '');
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
                                                color: petColor.withValues(alpha: 0.18),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                border: Border.all(
                                                    color: petColor.withValues(
                                                        alpha: 0.55)),
                                              ),
                                              child: Text(clsLabel,
                                                  style: TextStyle(
                                                      color: petColor,
                                                      fontSize: compact ? 8 : 9,
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
                                    if (compact) const SizedBox(height: 1),
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
                                      left: isNewPet && i > 0 ? (compact ? 8 : 14) : 3,
                                      right: 3),
                                  child: w,
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),

            // End-turn button slot
            SizedBox(
              width: endSlotW,
              child: Center(
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 4 : 6,
                    vertical: compact ? 5 : 6,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x26FFB347), Color(0x10FF8C1A)],
                    ),
                    border: Border.all(color: const Color(0x66FFB347)),
                  ),
                  child: endButtonSlot,
                ),
              ),
            ),
          ],
        );
      },
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
    const c = Color(0xFFFF9F1A);
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
                      energy > 0 ? const Color(0xFF7A3B00) : Colors.black45,
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
        Text(
          '$energy/$max',
          style: GoogleFonts.rajdhani(
            color: const Color(0xFFFFD9A1),
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.3,
          ),
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
//
// Default:        part-card art + energy cost badge
// Hover / hold:   full classic card template (name, stats, description)
// discardMode:    always shows classic card (user needs to see what to discard)

class BattleSkillCard extends StatefulWidget {
  final TraitViewModel trait;
  final String petName;
  final bool isSelected;
  final bool isPity;
  final bool discardMode;
  final bool isFizzled;
  final String? cardArtPath;
  final String? cardTemplatePath;
  final int? comboIndex;
  final Color? petColor;
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
  State<BattleSkillCard> createState() => _BattleSkillCardState();

  static Color typeColor(String t) => switch (t) {
        'offensive' => AppColors.offensive,
        'defensive' => AppColors.defensive,
        'support' => AppColors.support,
        'utility' => AppColors.utility,
        _ => AppColors.primary,
      };
}

class _BattleSkillCardState extends State<BattleSkillCard> {
  OverlayEntry? _overlay;

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  void _insertOverlay(
    BuildContext context, {
    required String imagePath,
    required String imageName,
    required int attack,
    required int defense,
  }) {
    _removeOverlay();
    _overlay = OverlayEntry(
      builder: (_) => _HoverCardOverlay(
        trait: widget.trait,
        imagePath: imagePath,
        imageName: imageName,
        attack: attack,
        defense: defense,
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(_overlay!);
  }

  void _removeOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.trait;
    final usable = widget.discardMode || t.isUsable;
    final tc = widget.discardMode
        ? const Color(0xFFFF6060)
        : BattleSkillCard.typeColor(t.typeName);

    final cardEntry = kBattleCardCatalogByTraitId[t.id];
    final resolvedTemplatePath = widget.cardTemplatePath ??
        cardEntry?.templatePath ??
        widget.cardArtPath ??
        'assets/images/part-cards/default-card-art.png';
    final resolvedImageName = cardEntry?.imageName ??
        battleClassicImageNameFromPath(widget.cardTemplatePath) ??
        battleClassicImageNameFromPath(widget.cardArtPath) ??
        battleClassicImageNameFromPath(resolvedTemplatePath) ??
        '';
    final attack = battleClassicCardAttack(t, cardEntry);
    final defense = battleClassicCardDefense(t, cardEntry);

    final cardW = widget.discardMode ? 108.0 : 96.0;
    final cardH = widget.discardMode ? 148.0 : 134.0;
    const lift = -14.0;

    return MouseRegion(
      onEnter: (_) => _insertOverlay(context,
          imagePath: resolvedTemplatePath,
          imageName: resolvedImageName,
          attack: attack,
          defense: defense),
      onExit: (_) => _removeOverlay(),
      child: GestureDetector(
        onTap: usable && !widget.isFizzled ? widget.onTap : null,
        onLongPressStart: (_) => _insertOverlay(context,
            imagePath: resolvedTemplatePath,
            imageName: resolvedImageName,
            attack: attack,
            defense: defense),
        onLongPressEnd: (_) => _removeOverlay(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 110),
          width: cardW,
          height: cardH,
          transform: widget.isSelected
              ? (Matrix4.identity()..translateByDouble(0, lift, 0, 1))
              : Matrix4.identity(),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            boxShadow: [
              if (widget.isSelected) ...[
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
              if (widget.discardMode)
                const BoxShadow(
                    color: Color(0xFFCC2020), blurRadius: 14, spreadRadius: 3),
              const BoxShadow(
                  color: Colors.black, blurRadius: 10, offset: Offset(0, 4)),
            ],
          ),
          child: Opacity(
            opacity: widget.isFizzled ? 0.3 : (usable ? 1.0 : 0.38),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // ── Card face: always part-card art (classic shown in overlay) ──
                  Positioned.fill(
                    child: widget.discardMode
                        ? ClassicTraitCardWidget(
                            imagePath: resolvedTemplatePath,
                            imageName: resolvedImageName,
                            name: t.name,
                            energy: t.energyCost,
                            attack: attack,
                            defense: defense,
                            description: t.description,
                            showDescription: true,
                          )
                        : _PartCardFace(
                            artPath: widget.cardArtPath,
                            energyCost: t.energyCost,
                            canAfford: t.canAfford,
                            frameColor: tc,
                          ),
                  ),

                  // ── Shared overlays ────────────────────────────────────────
                  if (widget.isSelected)
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
                  if (!t.isReady)
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
                        child: Text('CD ${t.cooldownRemaining}',
                            style: const TextStyle(
                                color: AppColors.utility,
                                fontSize: 7,
                                fontWeight: FontWeight.w700)),
                      ),
                    ),
                  if (widget.petColor != null)
                    Positioned(
                      top: 4,
                      left: 4,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: widget.petColor,
                          border:
                              Border.all(color: Colors.white70, width: 0.5),
                          boxShadow: [
                            BoxShadow(
                                color:
                                    widget.petColor!.withValues(alpha: 0.5),
                                blurRadius: 4)
                          ],
                        ),
                      ),
                    ),
                  if (widget.comboIndex != null)
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
                                color: tc.withValues(alpha: 0.6),
                                blurRadius: 6)
                          ],
                        ),
                        child: Center(
                          child: Text('${widget.comboIndex}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900)),
                        ),
                      ),
                    ),
                  if (widget.isPity && !widget.discardMode)
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
                            style:
                                TextStyle(color: Colors.amber, fontSize: 7)),
                      ),
                    ),
                  if (widget.discardMode) ...[
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
                      bottom: 5,
                      right: 5,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color:
                              const Color(0xFFCC2020).withValues(alpha: 0.9),
                          boxShadow: const [
                            BoxShadow(color: Colors.black54, blurRadius: 4)
                          ],
                        ),
                        child: const Icon(Icons.close,
                            size: 13, color: Colors.white),
                      ),
                    ),
                  ],
                  if (widget.isFizzled)
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
      ),
    );
  }
}

// Default card face: part-card art + compact energy badge top-right.
class _PartCardFace extends StatelessWidget {
  final String? artPath;
  final int energyCost;
  final bool canAfford;
  final Color frameColor;

  const _PartCardFace({
    required this.artPath,
    required this.energyCost,
    required this.canAfford,
    required this.frameColor,
  });

  @override
  Widget build(BuildContext context) {
    final energyColor =
        canAfford ? AppColors.energyBlue : Colors.grey.shade500;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Part-card art
        if (artPath != null)
          Image.asset(
            artPath!,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            errorBuilder: (_, __, ___) => Container(
              color: Color.alphaBlend(
                  frameColor.withValues(alpha: 0.35), const Color(0xFF101623)),
            ),
          )
        else
          Container(
            color: Color.alphaBlend(
                frameColor.withValues(alpha: 0.35), const Color(0xFF101623)),
          ),

        // Energy badge — top-right, away from pet-color dot (top-left)
        Positioned(
          top: 5,
          right: 5,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: energyColor.withValues(alpha: 0.8)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bolt_rounded, size: 10, color: energyColor),
                const SizedBox(width: 2),
                Text(
                  '$energyCost',
                  style: TextStyle(
                    color: energyColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── _HoverCardOverlay ─────────────────────────────────────────────────────────
// Full-screen overlay that shows the classic card centered + scaled up.
// Rendered via OverlayEntry so it floats above the entire battle HUD.

class _HoverCardOverlay extends StatefulWidget {
  final TraitViewModel trait;
  final String imagePath;
  final String imageName;
  final int attack;
  final int defense;

  const _HoverCardOverlay({
    required this.trait,
    required this.imagePath,
    required this.imageName,
    required this.attack,
    required this.defense,
  });

  @override
  State<_HoverCardOverlay> createState() => _HoverCardOverlayState();
}

class _HoverCardOverlayState extends State<_HoverCardOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    )..forward();
    _scale = Tween<double>(begin: 0.72, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack),
    );
    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.trait;
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, child) => Opacity(
          opacity: _fade.value,
          child: Center(
            child: Transform.scale(
              scale: _scale.value,
              child: child,
            ),
          ),
        ),
        child: SizedBox(
          width: 210,
          height: 286, // 210 × (300/220) ≈ 286
          child: ClassicTraitCardWidget(
            imagePath: widget.imagePath,
            imageName: widget.imageName,
            name: t.name,
            energy: t.energyCost,
            attack: widget.attack,
            defense: widget.defense,
            description: t.description,
            showDescription: true,
          ),
        ),
      ),
    );
  }
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
