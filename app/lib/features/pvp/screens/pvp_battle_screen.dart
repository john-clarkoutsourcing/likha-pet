import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../battle/providers/battle_view_model.dart';
import '../../battle/services/battle_asset_warmup.dart';
import '../../battle/widgets/pet_character_widget.dart';
import '../../battle/widgets/pet_renderer_widget.dart';
import '../../battle/widgets/battle_background_widget.dart';
import '../../battle/widgets/dead_pet_effect.dart';
import '../../../shared/widgets/hp_bar.dart';
import '../providers/pvp_battle_provider.dart';
import 'pvp_result_screen.dart';

class PvpBattleScreen extends ConsumerStatefulWidget {
  const PvpBattleScreen({super.key});

  @override
  ConsumerState<PvpBattleScreen> createState() => _PvpBattleScreenState();
}

class _PvpBattleScreenState extends ConsumerState<PvpBattleScreen>
    with TickerProviderStateMixin {
  late final AnimationController _timer;
  bool _battleReady = false;
  Future<void>? _warmupFuture;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _timer = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          if (mounted && !ref.read(pvpBattleProvider).isResolving &&
              !ref.read(pvpBattleProvider).awaitingOpponent) {
            ref.read(pvpBattleProvider.notifier).executeRound();
          }
        }
      });
  }

  @override
  void dispose() {
    _timer.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = ref.watch(pvpBattleProvider);
    _ensureWarmup(vm);

    if (!_battleReady) {
      return const _PvpLoadingScreen(message: 'Preparing battle assets...');
    }

    // Navigate to result screen when match ends
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
      // Reset timer after each round
      if (prev != null && !prev.isResolving && next.isResolving) {
        // round started
      }
      if (prev != null && prev.isResolving && !next.isResolving && !next.isBattleOver) {
        _timer.reset();
        _timer.forward();
      }
    });

    final h = MediaQuery.sizeOf(context).height;
    const panelH = 180.0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background
          const Positioned.fill(child: BattleBackgroundWidget()),

          // Enemy team (top area)
          Positioned(
            top: 8, left: 0, right: 0,
            height: (h - panelH) / 2,
            child: _TeamRow(team: vm.enemyTeam, isPlayer: false, vm: vm),
          ),

          // Player team (middle area)
          Positioned(
            top: (h - panelH) / 2, left: 0, right: 0,
            height: (h - panelH) / 2,
            child: _TeamRow(team: vm.playerTeam, isPlayer: true, vm: vm),
          ),

          // Round + timer bar
          Positioned(
            top: 0, left: 0, right: 0,
            height: 3,
            child: AnimatedBuilder(
              animation: _timer,
              builder: (_, __) => LinearProgressIndicator(
                value: 1 - _timer.value,
                backgroundColor: Colors.transparent,
                color: _timer.value > 0.5
                    ? AppColors.accent
                    : _timer.value > 0.25
                        ? AppColors.secondary
                        : Colors.redAccent,
                minHeight: 3,
              ),
            ),
          ),

          // Round counter
          Positioned(
            top: 4, left: 0, right: 0,
            child: Center(
              child: Text(
                'Round ${vm.currentRound}  ·  Energy ${vm.playerTeamEnergy}',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
              ),
            ),
          ),

          // Card hand panel
          Positioned(
            bottom: 0, left: 0, right: 0,
            height: panelH,
            child: _CardPanel(vm: vm),
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
                          style: TextStyle(color: AppColors.textPrimary, fontSize: 16)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
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
      _timer
        ..reset()
        ..forward();
    });
  }
}

// ── Team row ──────────────────────────────────────────────────────────────────

class _TeamRow extends StatelessWidget {
  final List<PetViewModel> team;
  final bool isPlayer;
  final PveBattleViewModel vm;
  const _TeamRow({required this.team, required this.isPlayer, required this.vm});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: team.map((pet) => _PetSlot(pet: pet, isPlayer: isPlayer, vm: vm)).toList(),
    );
  }
}

class _PetSlot extends StatelessWidget {
  final PetViewModel pet;
  final bool isPlayer;
  final PveBattleViewModel vm;
  const _PetSlot({required this.pet, required this.isPlayer, required this.vm});

  @override
  Widget build(BuildContext context) {
    final animState = vm.petAnimStates[pet.id] ?? PetCharacterAnimState.idle;
    final attackSlot = vm.petAttackSlots[pet.id];
    final animName = _animFor(animState, attackSlot: attackSlot);

    return Opacity(
      opacity: pet.isFainted ? 0.3 : 1.0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 90,
            height: 90,
            child: pet.isFainted
                ? DeadPetEffect(
                    size: 90,
                    flipHorizontal: !isPlayer,
                  )
                : pet.creatureDef != null
                ? PetRendererWidget(
                    def: pet.creatureDef!,
                    size: 90,
                    flipHorizontal: !isPlayer,
                    animation: animName,
                  )
                : pet.characterConfig != null
                ? PetCharacterWidget(
                    config: pet.characterConfig!,
                    size: 90,
                    animState: animState,
                    flipHorizontal: !isPlayer,
                  )
                : const Icon(Icons.pets, color: AppColors.textMuted, size: 60),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 80,
            child: HpBar(current: pet.hp, max: pet.maxHp),
          ),
          Text(pet.name,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

}

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
                    Text(
                      message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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

String _animFor(PetCharacterAnimState state, {String? attackSlot}) {
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
    PetCharacterAnimState.attack || PetCharacterAnimState.attackMelee =>
      'attack/melee/normal-attack',
    PetCharacterAnimState.attackRanged => 'attack/ranged/cast-fly',
    PetCharacterAnimState.hit => 'defense/hit-by-normal',
    PetCharacterAnimState.buff || PetCharacterAnimState.heal =>
      'battle/get-buff',
    PetCharacterAnimState.debuff => 'battle/get-debuff',
    PetCharacterAnimState.shield => 'defense/hit-with-shield',
    PetCharacterAnimState.faint => 'action/move-back',
    PetCharacterAnimState.idle => 'action/idle/normal',
  };
}

// ── Card panel ────────────────────────────────────────────────────────────────

class _CardPanel extends ConsumerWidget {
  final PveBattleViewModel vm;
  const _CardPanel({required this.vm});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: AppColors.bg.withValues(alpha: 0.92),
      child: Column(
        children: [
          // Card scroll row
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: vm.hand.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final card = vm.hand[i];
                final isAssigned = vm.pendingSkills.values
                    .any((ids) => ids.contains(card.instanceId));
                return GestureDetector(
                  onTap: () => ref.read(pvpBattleProvider.notifier).assignSkill(card.instanceId),
                  child: _CardTile(card: card, isAssigned: isAssigned),
                );
              },
            ),
          ),

          // Lock-in button
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: vm.isResolving || vm.awaitingOpponent || vm.isBattleOver
                    ? null
                    : () => ref.read(pvpBattleProvider.notifier).executeRound(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF5350),
                  disabledBackgroundColor: AppColors.surface,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(
                  vm.awaitingOpponent ? 'Waiting…'
                      : vm.isResolving  ? 'Resolving…'
                      : 'Lock In & Fight',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardTile extends StatelessWidget {
  final CardViewModel card;
  final bool isAssigned;
  const _CardTile({required this.card, required this.isAssigned});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 70,
      decoration: BoxDecoration(
        color: isAssigned ? AppColors.accent.withValues(alpha: 0.25) : AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isAssigned ? AppColors.accent : AppColors.divider,
          width: isAssigned ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(card.trait.name,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 9),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text('${card.trait.energyCost}⚡',
                style: const TextStyle(color: AppColors.energyBlue, fontSize: 11,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
