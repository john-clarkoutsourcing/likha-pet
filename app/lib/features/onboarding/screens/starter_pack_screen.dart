import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:likha_pet_battle_engine/trait.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../pets/models/owned_pet.dart';
import '../../pets/providers/player_provider.dart';
import '../../pets/services/starter_pack_service.dart';
import '../../battle/data/creature_registry.dart';
import '../../battle/widgets/pet_renderer_widget.dart';
import '../widgets/pet_reveal_sheet.dart';

// ── StarterPackScreen ──────────────────────────────────────────────────────────

class StarterPackScreen extends ConsumerStatefulWidget {
  const StarterPackScreen({super.key});

  @override
  ConsumerState<StarterPackScreen> createState() => _StarterPackScreenState();
}

class _StarterPackScreenState extends ConsumerState<StarterPackScreen>
    with TickerProviderStateMixin {

  late final List<OwnedPet> _pets;
  final List<_EggState> _eggStates = [
    _EggState.idle, _EggState.idle, _EggState.idle,
  ];
  late final List<AnimationController> _shakeCtrl;
  late final List<AnimationController> _revealCtrl;
  bool _allHatched = false;

  @override
  void initState() {
    super.initState();
    _pets = StarterPackService.generate();
    _shakeCtrl = List.generate(3, (_) => AnimationController(
      vsync: this, duration: const Duration(milliseconds: 500),
    ));
    _revealCtrl = List.generate(3, (_) => AnimationController(
      vsync: this, duration: const Duration(milliseconds: 700),
    ));
  }

  @override
  void dispose() {
    for (final c in _shakeCtrl) { c.dispose(); }
    for (final c in _revealCtrl) { c.dispose(); }
    super.dispose();
  }

  Future<void> _hatch(int i) async {
    if (_eggStates[i] != _EggState.idle) return;
    setState(() => _eggStates[i] = _EggState.hatching);
    HapticFeedback.mediumImpact();

    await _shakeCtrl[i].forward();
    _shakeCtrl[i].reset();
    await Future.delayed(const Duration(milliseconds: 100));

    setState(() => _eggStates[i] = _EggState.hatched);
    await _revealCtrl[i].forward();

    if (mounted) await PetRevealSheet.show(context, _pets[i]);

    final allDone = _eggStates.every((s) => s == _EggState.hatched);
    if (allDone && mounted) setState(() => _allHatched = true);
  }

  Future<void> _finish() async {
    HapticFeedback.lightImpact();
    final notifier = ref.read(playerProvider.notifier);
    for (final pet in _pets) {
      notifier.addPet(pet);
    }
    notifier.setActiveTeam(_pets.map((p) => p.uid).toList());
    if (mounted) context.go(Routes.home);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: Stack(children: [
        // ── Gradient background ──────────────────────────────────────────
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0D1117),
                Color(0xFF1A1F35),
                Color(0xFF0D1117),
              ],
            ),
          ),
        ),

        // ── Main content ─────────────────────────────────────────────────
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

              // ── Left panel ───────────────────────────────────────────────
              SizedBox(
                width: 160,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Logo mark
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [AppColors.primary, AppColors.accent],
                        ),
                      ),
                      child: const Center(
                        child: Text('🐾', style: TextStyle(fontSize: 18)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Welcome\nto Likha Pet',
                      style: GoogleFonts.rajdhani(
                        color: Colors.white,
                        fontSize: 20, fontWeight: FontWeight.w900,
                        height: 1.1)),
                    const SizedBox(height: 8),
                    const Text(
                      'Tap each egg to hatch\nyour starter pets.\nEach one is unique!',
                      style: TextStyle(
                        color: Colors.white54, fontSize: 11, height: 1.4)),

                    const Spacer(),

                    // Progress dots
                    Row(children: List.generate(3, (i) {
                      final done = _eggStates[i] == _EggState.hatched;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: done ? 20 : 8, height: 8,
                        margin: const EdgeInsets.only(right: 5),
                        decoration: BoxDecoration(
                          color: done
                              ? AppColors.accent
                              : Colors.white24,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    })),

                    const SizedBox(height: 12),

                    // CTA button
                    AnimatedOpacity(
                      opacity: _allHatched ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 400),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _allHatched ? _finish : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            elevation: _allHatched ? 8 : 0,
                            shadowColor: AppColors.primary.withValues(alpha: 0.5),
                          ),
                          child: Text('Start Adventure!',
                            style: GoogleFonts.rajdhani(
                              color: Colors.white,
                              fontSize: 14, fontWeight: FontWeight.w900,
                              letterSpacing: 0.5)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
              ),

              const SizedBox(width: 16),

              // ── 3 egg cards ──────────────────────────────────────────────
              Expanded(
                child: Row(
                  children: List.generate(3, (i) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: _EggCard(
                        pet:        _pets[i],
                        eggState:   _eggStates[i],
                        shakeCtrl:  _shakeCtrl[i],
                        revealCtrl: _revealCtrl[i],
                        index:      i,
                        onTap:      () => _hatch(i),
                      ),
                    ),
                  )),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ── Egg card ──────────────────────────────────────────────────────────────────

enum _EggState { idle, hatching, hatched }

class _EggCard extends StatelessWidget {
  final OwnedPet pet;
  final _EggState eggState;
  final AnimationController shakeCtrl;
  final AnimationController revealCtrl;
  final int index;
  final VoidCallback onTap;

  const _EggCard({
    required this.pet,
    required this.eggState,
    required this.shakeCtrl,
    required this.revealCtrl,
    required this.index,
    required this.onTap,
  });

  static Color _classColor(CreatureClass cls) => switch (cls) {
    CreatureClass.plant   => const Color(0xFF4CAF50),
    CreatureClass.aquatic => const Color(0xFF29B6F6),
    CreatureClass.beast   => const Color(0xFFFF9800),
    CreatureClass.reptile => const Color(0xFF66BB6A),
    CreatureClass.bird    => const Color(0xFFFF80AB),
    CreatureClass.bug     => const Color(0xFFFF5252),
  };

  static const _rarity = ['★ Common', '★★ Rare', '★★★ Epic'];

  @override
  Widget build(BuildContext context) {
    final body      = kBodyCatalogue[pet.bodyId];
    final bodyClass = body?.bodyClass ?? CreatureClass.beast;
    final color     = _classColor(bodyClass);
    final isHatched = eggState == _EggState.hatched;

    return AnimatedBuilder(
      animation: shakeCtrl,
      builder: (_, child) => Transform.translate(
        offset: Offset(sin(shakeCtrl.value * pi * 8) * 8, 0),
        child: child,
      ),
      child: GestureDetector(
        onTap: eggState == _EggState.idle ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          decoration: BoxDecoration(
            color: isHatched
                ? color.withValues(alpha: 0.08)
                : const Color(0xFF161C2E),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isHatched
                  ? color.withValues(alpha: 0.7)
                  : Colors.white.withValues(alpha: 0.08),
              width: isHatched ? 2 : 1,
            ),
            boxShadow: isHatched
                ? [BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: 20, spreadRadius: 2)]
                : null,
          ),
          clipBehavior: Clip.antiAlias,
          child: eggState == _EggState.hatched
              ? _buildHatched(bodyClass, color)
              : _buildEgg(eggState == _EggState.hatching),
        ),
      ),
    );
  }

  Widget _buildEgg(bool isHatching) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Pulsing egg glow
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isHatching
                  ? Colors.orange.withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.03),
            ),
            child: Text(
              isHatching ? '✨' : '🥚',
              style: TextStyle(fontSize: isHatching ? 52 : 48),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            isHatching ? 'Hatching...' : 'Tap to hatch',
            style: TextStyle(
              color: isHatching ? Colors.orange : Colors.white38,
              fontSize: 11, fontWeight: FontWeight.w600),
          ),
          if (!isHatching) ...[
            const SizedBox(height: 6),
            Text('Mystery Pet #${index + 1}',
              style: const TextStyle(
                color: Colors.white24, fontSize: 9)),
          ],
        ],
      ),
    );
  }

  Widget _buildHatched(CreatureClass cls, Color color) {
    final def = pet.toCreatureDefinition();
    return ScaleTransition(
      scale: CurvedAnimation(parent: revealCtrl, curve: Curves.elasticOut),
      child: Column(
        children: [
          // Pet renderer — width is always the tight constraint in landscape
          // (card ≈ 200px wide × 350px tall).  Square WebView must fit the width.
          Expanded(
            flex: 5,
            child: LayoutBuilder(
              builder: (_, constraints) {
                final side = (constraints.maxWidth * 0.90).clamp(60.0, 200.0);
                return Center(
                  child: PetRendererWidget(
                    def:  def,
                    size: side,
                    yOff: 0.70,
                  ),
                );
              },
            ),
          ),

          // Class badge + part dots
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 10),
            child: Column(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: color.withValues(alpha: 0.6)),
                ),
                child: Text(cls.displayName,
                  style: TextStyle(color: color, fontSize: 10,
                      fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 6),
              // Part class dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _PartDot(def.horn.partClass),
                  const SizedBox(width: 4),
                  _PartDot(def.back.partClass),
                  const SizedBox(width: 4),
                  _PartDot(def.tail.partClass),
                  const SizedBox(width: 4),
                  _PartDot(def.mouth.partClass),
                ],
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

// ── Part dot ──────────────────────────────────────────────────────────────────

class _PartDot extends StatelessWidget {
  final CreatureClass cls;
  const _PartDot(this.cls);

  @override
  Widget build(BuildContext context) => Container(
    width: 10, height: 10,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: _color(cls),
      boxShadow: [BoxShadow(
        color: _color(cls).withValues(alpha: 0.6),
        blurRadius: 4)],
    ),
  );

  static Color _color(CreatureClass cls) => switch (cls) {
    CreatureClass.plant   => const Color(0xFF4CAF50),
    CreatureClass.aquatic => const Color(0xFF29B6F6),
    CreatureClass.beast   => const Color(0xFFFF9800),
    CreatureClass.reptile => const Color(0xFF66BB6A),
    CreatureClass.bird    => const Color(0xFFFF80AB),
    CreatureClass.bug     => const Color(0xFFFF5252),
  };
}
