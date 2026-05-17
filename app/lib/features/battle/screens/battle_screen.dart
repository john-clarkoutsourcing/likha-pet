import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/router/app_router.dart';
import '../data/creature_registry.dart';
import '../data/trait_card_catalog.dart';
import '../providers/pve_battle_provider.dart';
import '../providers/battle_view_model.dart';
import '../services/battle_asset_warmup.dart';
import '../services/battle_audio_service.dart';
import '../widgets/battle_background_widget.dart';
import '../widgets/classic_trait_card_widget.dart';
import '../widgets/pet_renderer_widget.dart';
import '../widgets/shared_battle_hud.dart';
import 'battle_result_screen.dart';

// ── Route args ────────────────────────────────────────────────────────────────

class BattleScreenArgs {
  final String playerTeamName;
  final String enemyTeamName;
  final String? stageId; // non-null for PvE stage battles
  const BattleScreenArgs({
    this.playerTeamName = 'My Team',
    this.enemyTeamName = 'Rivals',
    this.stageId,
  });
}

// ── Constants ─────────────────────────────────────────────────────────────────

const _kRoundSeconds = 30;

/// Battlefield positions as (left%, top%) fractions.
/// Battlefield = full SafeArea height (~331 px).
/// Card panel overlays bottom 168 px → pets above y < (331-168)/331 ≈ 0.49 are clear.
// Positions = fractions of FULL screen (no SafeArea inset).
// Full screen ~375px tall, card panel 168px → y < 0.45 visible above panel.
const _kPlayerPos = [
  Offset(0.30, 0.22), // FRONT
  Offset(0.15, 0.03), // MID
  Offset(0.10, 0.35), // BACK
];
const _kEnemyPos = [
  Offset(0.50, 0.22), // FRONT
  Offset(0.65, 0.03), // MID
  Offset(0.75, 0.35), // BACK
];

// Card catalog and helpers are now in shared_battle_hud.dart.
// Local aliases keep internal references in this file working unchanged.
final _cardCatalogByTraitId = kBattleCardCatalogByTraitId;
String? _classicImageNameFromPath(String? p) => battleClassicImageNameFromPath(p);
int _classicCardAttack(TraitViewModel t, TraitCardCatalogEntry? e) => battleClassicCardAttack(t, e);
int _classicCardDefense(TraitViewModel t, TraitCardCatalogEntry? e) => battleClassicCardDefense(t, e);

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
  late List<Offset> _playerPos;
  late List<Offset> _enemyPos;
  bool _showPositionTuner = false;
  bool _isDeckCollapsed = false;
  bool _battleReady = false;
  Future<void>? _warmupFuture;

  @override
  void initState() {
    super.initState();
    BattleAudioService.instance.init();
    _playerPos = List<Offset>.from(_kPlayerPos);
    _enemyPos = List<Offset>.from(_kEnemyPos);
    // Publish args so pveBattleProvider can read stageId before building.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(battleArgsProvider.notifier).state = widget.args;
      ref.read(pveBattleProvider.notifier).setBattlePositions(
            playerPos: _playerPos,
            enemyPos: _enemyPos,
          );
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
  }

  @override
  void dispose() {
    _timer.dispose();
    super.dispose();
  }

  void _autoEndTurn() {
    final vm = ref.read(pveBattleProvider);
    if (vm.isBattleOver || vm.isResolving) return;

    // If the player assigned no cards at all, skip the round — no combat fires.
    final hasAnyCard = vm.pendingSkills.values.any((list) => list.isNotEmpty);
    if (!hasAnyCard) {
      // Restart the timer so the player gets another chance.
      _restartTimer();
      return;
    }

    ref.read(pveBattleProvider.notifier).executeRound();
  }

  void _restartTimer() {
    _timer
      ..reset()
      ..forward();
  }

  void _setPos({
    required bool isPlayer,
    required int index,
    double? dx,
    double? dy,
  }) {
    setState(() {
      final list = isPlayer ? _playerPos : _enemyPos;
      final cur = list[index];
      list[index] = Offset(dx ?? cur.dx, dy ?? cur.dy);
    });
    ref.read(pveBattleProvider.notifier).setBattlePositions(
          playerPos: _playerPos,
          enemyPos: _enemyPos,
        );
  }

  void _resetPositions() {
    setState(() {
      _playerPos = List<Offset>.from(_kPlayerPos);
      _enemyPos = List<Offset>.from(_kEnemyPos);
    });
    ref.read(pveBattleProvider.notifier).setBattlePositions(
          playerPos: _playerPos,
          enemyPos: _enemyPos,
        );
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
    final vm = ref.watch(pveBattleProvider);
    _ensureWarmup(vm);

    if (!_battleReady) {
      return const BattleLoadingScreen(message: 'Preparing battle assets...');
    }

    // Listen for state changes to control the timer
    ref.listen<PveBattleViewModel>(pveBattleProvider, (prev, next) {
      // Navigate when battle ends
      if (next.isBattleOver && next.outcome != null) {
        _timer.stop();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            context.go(Routes.battleResult,
                extra: BattleResultArgs(
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
              const Icon(Icons.screen_rotation,
                  color: Colors.white54, size: 48),
              const SizedBox(height: 16),
              Text(
                'Rotate to landscape',
                style: GoogleFonts.rajdhani(
                  color: Colors.white70,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final panelVisibleH = _isDeckCollapsed ? kBattlePanelPeekH : kBattlePanelH;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand, // fill edge-to-edge, no implicit margins
        children: [
          // ── Background (full screen) ─────────────────────────────────────
          const BattleBackgroundWidget(),

          // ── Battlefield fills full safe area ────────────────────────────
          // PvE: player on left (flipHorizontal: true = faces right),
          //       enemy on right (flipHorizontal: false = faces left).
          Positioned.fill(
            child: BattlefieldView(
              vm: vm,
              playerPos: _playerPos,
              opponentPos: _enemyPos,
              playerFlipHorizontal: true,
              opponentFlipHorizontal: false,
              onPlayerPetTap: (pet) => _PetInfoSheet.show(context, pet),
              onPlayerPetLongPress: (pet) => _PetInfoSheet.show(context, pet),
              onOpponentPetTap: (pet) => _PetInfoSheet.show(context, pet),
            ),
          ),

          // ── HUD overlays the top ─────────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              // PvE: player on left (playerOnRight: false)
              child: BattleTopHud(vm: vm, timer: _timer),
            ),
          ),

          // ── Battle feed just above the card panel ────────────────────────
          if (!vm.isResolving)
            Positioned(
              left: 0,
              right: 0,
              bottom: panelVisibleH,
              child: BattleFeed(log: vm.roundLog),
            ),

          // ── Card panel at bottom ─────────────────────────────────────────
          AnimatedPositioned(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            left: 0,
            right: 0,
            bottom: _isDeckCollapsed ? -(kBattlePanelH - kBattlePanelPeekH) : 0,
            child: BattleBottomPanel(
              vm: vm,
              onAssignSkill: (id) =>
                  ref.read(pveBattleProvider.notifier).assignSkill(id),
              endButtonSlot: _EndTurnButton(vm: vm, ref: ref),
              isCollapsed: _isDeckCollapsed,
              onToggleCollapse: () =>
                  setState(() => _isDeckCollapsed = !_isDeckCollapsed),
            ),
          ),

          if (kDebugMode)
            Positioned(
              top: 56,
              left: 8,
              child: _PositionTuner(
                visible: _showPositionTuner,
                onToggle: () => setState(
                  () => _showPositionTuner = !_showPositionTuner,
                ),
                onReset: _resetPositions,
                playerPos: _playerPos,
                enemyPos: _enemyPos,
                onChange: _setPos,
              ),
            ),

          // ── Discard popup ────────────────────────────────────────────────
          if (vm.needsDiscard) _DiscardPopup(vm: vm, ref: ref),
        ],
      ),
    );
  }
}

// ── Debug battlefield position tuner ──────────────────────────────────────────

class _PositionTuner extends StatelessWidget {
  final bool visible;
  final VoidCallback onToggle;
  final VoidCallback onReset;
  final List<Offset> playerPos;
  final List<Offset> enemyPos;
  final void Function({
    required bool isPlayer,
    required int index,
    double? dx,
    double? dy,
  }) onChange;

  const _PositionTuner({
    required this.visible,
    required this.onToggle,
    required this.onReset,
    required this.playerPos,
    required this.enemyPos,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible) {
      return FilledButton.tonal(
        onPressed: onToggle,
        child: const Text('Tune Pos'),
      );
    }

    return Container(
      width: 360,
      constraints: const BoxConstraints(maxHeight: 320),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Battlefield Position Tuner',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              TextButton(onPressed: onReset, child: const Text('Reset')),
              IconButton(
                onPressed: onToggle,
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ],
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildTeam('Player', true, playerPos),
                  const SizedBox(height: 10),
                  _buildTeam('Enemy', false, enemyPos),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeam(String label, bool isPlayer, List<Offset> pos) {
    const slotNames = ['Front', 'Mid', 'Back'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70)),
        for (var i = 0; i < pos.length && i < 3; i++)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${slotNames[i]}  x:${pos[i].dx.toStringAsFixed(2)} y:${pos[i].dy.toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              Slider(
                value: pos[i].dx.clamp(0.0, 1.0),
                min: 0,
                max: 1,
                divisions: 100,
                label: 'x',
                onChanged: (v) => onChange(isPlayer: isPlayer, index: i, dx: v),
              ),
              Slider(
                value: pos[i].dy.clamp(0.0, 1.0),
                min: 0,
                max: 1,
                divisions: 100,
                label: 'y',
                onChanged: (v) => onChange(isPlayer: isPlayer, index: i, dy: v),
              ),
            ],
          ),
      ],
    );
  }
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
  late final Animation<Offset> _slide;
  late final _ticker =
      Stream.periodic(const Duration(seconds: 1), (i) => _kSeconds - 1 - i)
          .take(_kSeconds)
          .listen((s) {
    if (mounted) setState(() => _remaining = s);
  });

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 320));
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

  PveBattleViewModel get vm => widget.vm;
  WidgetRef get ref => widget.ref;

  Color get _timerColor =>
      _remaining <= 3 ? const Color(0xFFFF4444) : const Color(0xFFFF9933);

  @override
  Widget build(BuildContext context) {
    final needed = vm.excessDiscards;

    // Build pet-id → class color from player team for pet label colors.
    Color clsColor(String name) => switch (name.toLowerCase()) {
          'beast' => const Color(0xFFFF9800),
          'plant' => const Color(0xFF4CAF50),
          'aquatic' => const Color(0xFF29B6F6),
          'reptile' => const Color(0xFF66BB6A),
          'bird' => const Color(0xFFFF80AB),
          'bug' => const Color(0xFFFF5252),
          _ => const Color(0xFF9C27B0),
        };
    final petColors = {
      for (final p in vm.playerTeam)
        p.id: clsColor(p.creatureDef?.bodyClass.name ?? ''),
    };

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
          left: 0,
          right: 0,
          bottom: 0,
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
                    blurRadius: 20,
                    spreadRadius: 2,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Header bar ───────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
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
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFFAA3030).withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFAA3030)),
                          ),
                          child: Text(
                            'Discard $needed card${needed > 1 ? "s" : ""}',
                            style: GoogleFonts.rajdhani(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const Spacer(),
                        // Countdown ring
                        SizedBox(
                          width: 36,
                          height: 36,
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
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
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
                    height: 182,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      itemCount: vm.hand.length,
                      itemBuilder: (_, i) {
                        final card = vm.hand[i];
                        final prevPetId =
                            i > 0 ? vm.hand[i - 1].ownerPetId : null;
                        final isNewPet = prevPetId != card.ownerPetId;
                        final petColor =
                            petColors[card.ownerPetId] ?? AppColors.primary;

                        return Padding(
                          padding: EdgeInsets.only(
                            left: isNewPet && i > 0 ? 14 : 0,
                            right: 10,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              SizedBox(
                                height: 20,
                                child: isNewPet
                                    ? Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color:
                                              petColor.withValues(alpha: 0.18),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                          border: Border.all(
                                              color: petColor.withValues(
                                                  alpha: 0.55),
                                              width: 1),
                                        ),
                                        child: Text(
                                          card.ownerPetName,
                                          style: TextStyle(
                                              color: petColor,
                                              fontSize: 9,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 0.3),
                                        ),
                                      )
                                    : const SizedBox.shrink(),
                              ),
                              const SizedBox(height: 3),
                              BattleSkillCard(
                                trait: card.trait,
                                petName: card.ownerPetName,
                                isSelected: false,
                                isPity: card.isPity,
                                discardMode: true,
                                cardArtPath: card.cardArtPath,
                                cardTemplatePath: card.cardTemplatePath,
                                 petColor: card.petColor,
                                onTap: () => ref
                                    .read(pveBattleProvider.notifier)
                                    .discardCard(card.instanceId),
                              ),
                            ],
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



// ── Pet info sheet ────────────────────────────────────────────────────────────

// ── Pet info sheet — Axie-style layout ───────────────────────────────────────
//
// Layout mirrors the Axie "My Axies" panel:
//   • Stats bar  (Health / Speed / Shield / Energy)
//   • Left col   — pet name + class icon + parts list with part-icon sprites
//   • Right area — 2×2 card grid (card art + energy badge + name + effect + desc)

class _PetInfoSheet {
  static void show(BuildContext context, PetViewModel pet) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (_) => _PetInfoDialog(pet: pet),
    );
  }
}

class _PetInfoDialog extends StatelessWidget {
  final PetViewModel pet;
  const _PetInfoDialog({required this.pet});

  static Color _clsColor(String cls) => switch (cls) {
        'plant' => const Color(0xFF4CAF50),
        'aquatic' => const Color(0xFF29B6F6),
        'beast' => const Color(0xFFFF9800),
        'reptile' => const Color(0xFF66BB6A),
        'bird' => const Color(0xFFFF80AB),
        'bug' => const Color(0xFFFF5252),
        _ => const Color(0xFF9C27B0),
      };

  @override
  Widget build(BuildContext context) {
    final def = pet.creatureDef ?? kCreatureRegistry[pet.id];
    final cls = def?.className ?? pet.creatureDef?.className ?? 'plant';
    final color = _clsColor(cls);
    final traitMap = {for (final t in pet.traits) t.partName: t};
    const partOrder = ['horn', 'back', 'tail', 'mouth'];
    final displayParts = <({String partType, String cardArtPath})>[
      if (def != null)
        for (final part in def.parts)
          (partType: part.partType, cardArtPath: part.cardArtPath)
      else
        for (final partType in partOrder)
          (
            partType: partType,
            cardArtPath: pet.partCardArt[partType] ??
                'assets/images/part-cards/default-card-art.png',
          ),
    ];
    final hpFrac = pet.maxHp > 0 ? (pet.hp / pet.maxHp).clamp(0.0, 1.0) : 0.0;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0D1220),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Left: pet renderer + name + stats ────────────────────────
            SizedBox(
              width: 200,
              child: Container(
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.06),
                  borderRadius:
                      const BorderRadius.horizontal(left: Radius.circular(15)),
                  border: Border(
                      right: BorderSide(color: color.withValues(alpha: 0.2))),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Pet renderer
                    if (pet.creatureDef != null)
                      SizedBox(
                        width: 160,
                        height: 160,
                        child: PetRendererWidget(
                          def: pet.creatureDef!,
                          size: 160,
                        ),
                      )
                    else
                      const Icon(Icons.pets, size: 80, color: Colors.white24),

                    const SizedBox(height: 8),

                    // Class badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: color.withValues(alpha: 0.6)),
                      ),
                      child: Text(
                        cls.isEmpty
                            ? 'Unknown'
                            : cls[0].toUpperCase() + cls.substring(1),
                        style: TextStyle(
                            color: color,
                            fontSize: 11,
                            fontWeight: FontWeight.w800),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // HP bar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Icon(Icons.favorite,
                                  size: 10, color: Color(0xFF66FF88)),
                              Text('${pet.hp} / ${pet.maxHp}',
                                  style: const TextStyle(
                                      color: Color(0xFF66FF88),
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700)),
                            ],
                          ),
                          const SizedBox(height: 3),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: SizedBox(
                              height: 5,
                              width: double.infinity,
                              child: LinearProgressIndicator(
                                value: hpFrac,
                                backgroundColor: Colors.white10,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                    Color(0xFF66FF88)),
                                minHeight: 5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Stats row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _stat('⚡', '${pet.speed}', 'SPD',
                            const Color(0xFFFFCC44)),
                        _stat('🏅', '${pet.skill}', 'SKL',
                            const Color(0xFF88CCFF)),
                        _stat('🔥', '${pet.morale}', 'MOR',
                            const Color(0xFFFF9944)),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── Right: 4 skill cards in a row ────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Text('SKILLS',
                            style: GoogleFonts.rajdhani(
                                color: Colors.white54,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 2)),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.08),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: const Icon(Icons.close,
                                size: 14, color: Colors.white54),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // 4 cards in a row
                    Expanded(
                      child: pet.traits.isEmpty
                          ? const Center(
                              child: Text('No skill data',
                                  style: TextStyle(
                                      color: Colors.white38, fontSize: 12)))
                          : LayoutBuilder(
                              builder: (_, constraints) {
                                final availW = constraints.maxWidth;
                                final availH = constraints.maxHeight;
                                // 4 cards in a row, gap 8px between
                                final cardW = (availW - 24) / 4;
                                final cardH =
                                    math.min(cardW / (220 / 300), availH);
                                final cW = cardH * (220 / 300);

                                return Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    for (final part in displayParts)
                                      SizedBox(
                                        width: cW,
                                        height: cardH,
                                        child: _InfoCard(
                                          partType: part.partType,
                                          cardArtPath: part.cardArtPath,
                                          trait: traitMap[part.partType],
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _stat(String icon, String val, String label, Color c) =>
      Column(mainAxisSize: MainAxisSize.min, children: [
        Text(icon, style: const TextStyle(fontSize: 12)),
        Text(val,
            style:
                TextStyle(color: c, fontSize: 13, fontWeight: FontWeight.w900)),
        Text(label,
            style: const TextStyle(
                color: Colors.white38,
                fontSize: 7,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5)),
      ]);
}


// ── Skill card (Axie card style) ──────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final String partType;
  final String cardArtPath;
  final TraitViewModel? trait;
  const _InfoCard({
    required this.partType,
    required this.cardArtPath,
    this.trait,
  });

  @override
  Widget build(BuildContext context) {
    final cardEntry = trait == null ? null : _cardCatalogByTraitId[trait!.id];
    final imageName = cardEntry?.imageName ??
        _classicImageNameFromPath(cardArtPath) ??
        '$partType-card';
    final imagePath = cardEntry?.templatePath ??
        (imageName.isNotEmpty
            ? 'assets/images/classic-cards/$imageName.png'
            : cardArtPath);

    return ClassicTraitCardWidget(
      imagePath: imagePath,
      imageName: imageName,
      name: trait?.name ?? partType.toUpperCase(),
      energy: trait?.energyCost ?? 0,
      attack: trait == null ? 0 : _classicCardAttack(trait!, cardEntry),
      defense: trait == null ? 0 : _classicCardDefense(trait!, cardEntry),
      description: trait?.description ?? '',
      showDescription: trait != null,
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
        onTap: () => context.go(Routes.battleResult,
            extra: BattleResultArgs(
              outcome: vm.outcome ?? 'draw',
              totalRounds: vm.currentRound,
              playerTeamName: vm.playerTeamName,
              enemyTeamName: vm.enemyTeamName,
            )),
      );
    }

    final allDone = vm.allSkillsAssigned;
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
    final bgColor = gold
        ? const Color(0xFFE03030) // red circle like reference
        : active
            ? const Color(0xFF2A3A5A)
            : const Color(0xFF1A1F2E);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: bgColor,
          border: Border.all(
            color: gold
                ? const Color(0xFFFF6060).withValues(alpha: 0.6)
                : active
                    ? Colors.white.withValues(alpha: 0.15)
                    : Colors.white.withValues(alpha: 0.05),
            width: 2.5,
          ),
          boxShadow: gold
              ? [
                  BoxShadow(
                      color: const Color(0xFFE03030).withValues(alpha: 0.6),
                      blurRadius: 20,
                      spreadRadius: 3)
                ]
              : null,
        ),
        child: Center(
          child: loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: Colors.white70),
                )
              : Text(
                  label.replaceAll(' ', '\n'),
                  style: GoogleFonts.rajdhani(
                    color: gold
                        ? Colors.white
                        : active
                            ? Colors.white70
                            : Colors.white24,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
                    height: 1.2,
                  ),
                  textAlign: TextAlign.center,
                ),
        ),
      ),
    );
  }
}


