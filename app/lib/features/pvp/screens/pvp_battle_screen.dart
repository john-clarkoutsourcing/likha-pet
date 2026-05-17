import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../battle/providers/battle_view_model.dart';
import '../../battle/services/battle_asset_warmup.dart';
import '../../battle/services/battle_audio_service.dart';
import '../../battle/widgets/battle_background_widget.dart';
import '../../battle/widgets/shared_battle_hud.dart';
import '../providers/pvp_battle_provider.dart';
import 'pvp_result_screen.dart';

// ── Position constants ────────────────────────────────────────────────────────
//
// Same POV as PvE: player on LEFT, opponent on RIGHT.
// From the player's perspective their team is always on the left side —
// the same convention used in Axie, Hearthstone, and most card battle games.
// Sprite flip: player faces right (flipHorizontal: true),
//              opponent faces left (flipHorizontal: false).

const _kPlayerPos = [
  Offset(0.30, 0.22), // FRONT — nearest to centre
  Offset(0.15, 0.03), // MID
  Offset(0.10, 0.35), // BACK
];
const _kOpponentPos = [
  Offset(0.50, 0.22), // FRONT — nearest to centre
  Offset(0.65, 0.03), // MID
  Offset(0.75, 0.35), // BACK
];

const _kRoundSeconds = 30;

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

  final List<Offset> _playerPos   = List<Offset>.from(_kPlayerPos);
  final List<Offset> _opponentPos = List<Offset>.from(_kOpponentPos);

  @override
  void initState() {
    super.initState();
    BattleAudioService.instance.init();
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

  void _restartTimer() => _timer..reset()..forward();

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
      return const BattleLoadingScreen(message: 'Preparing battle assets…');
    }

    ref.listen(pvpBattleProvider, (prev, next) {
      // Navigate to result when match ends.
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
      if (next.isResolving) { _timer.stop(); return; }
      final roundChanged = (prev?.currentRound ?? -1) != next.currentRound;
      final resolveFinished = (prev?.isResolving ?? false) && !next.isResolving;
      if ((roundChanged || resolveFinished) && !next.isBattleOver) _restartTimer();
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

    final panelVisibleH = _isDeckCollapsed ? kBattlePanelPeekH : kBattlePanelH;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background — same as PvE
          const BattleBackgroundWidget(),

          // Battlefield — player LEFT, opponent RIGHT (same POV as PvE)
          Positioned.fill(
            child: BattlefieldView(
              vm: vm,
              playerPos: _playerPos,
              opponentPos: _opponentPos,
              playerFlipHorizontal: true,     // player on left → faces right
              opponentFlipHorizontal: false,  // opponent on right → faces left
            ),
          ),

          // Top HUD — playerOnRight: false so player tag is on the left
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              bottom: false,
              child: BattleTopHud(vm: vm, timer: _timer),
            ),
          ),

          // Battle feed
          if (!vm.isResolving)
            Positioned(
              left: 0, right: 0, bottom: panelVisibleH,
              child: BattleFeed(log: vm.roundLog),
            ),

          // Card panel
          AnimatedPositioned(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            left: 0, right: 0,
            bottom: _isDeckCollapsed ? -(kBattlePanelH - kBattlePanelPeekH) : 0,
            child: BattleBottomPanel(
              vm: vm,
              onAssignSkill: (id) =>
                  ref.read(pvpBattleProvider.notifier).assignSkill(id),
              endButtonSlot: _LockInButton(vm: vm, ref: ref),
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

// ── PvP ready button ──────────────────────────────────────────────────────
// Rectangular style distinct from PvE's circle end-turn button.
// When both players click "Ready", the round executes simultaneously.

class _LockInButton extends StatelessWidget {
  final PveBattleViewModel vm;
  final WidgetRef ref;
  const _LockInButton({required this.vm, required this.ref});

  @override
  Widget build(BuildContext context) {
    final disabled = vm.isResolving || vm.awaitingOpponent || vm.isBattleOver;
    final label = vm.awaitingOpponent
        ? 'Waiting…'
        : vm.isResolving
            ? 'Resolving…'
            : 'Ready';

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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(label,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
      ),
    );
  }
}
