import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
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

// ── Class palette ─────────────────────────────────────────────────────────────

const _kAccents = <String, Color>{
  'beast':   Color(0xFFF0A040),
  'plant':   Color(0xFFA8D94A),
  'aquatic': Color(0xFF4AC4D9),
  'reptile': Color(0xFF4ADC7A),
  'bird':    Color(0xFFF586A0),
  'bug':     Color(0xFFE85AA8),
};

Color _petAccent(OwnedPet pet) {
  final body = kBodyCatalogue[pet.bodyId];
  return _kAccents[body?.className ?? ''] ?? const Color(0xFF4AC4D9);
}

// ── Screen ────────────────────────────────────────────────────────────────────

enum _EggState { idle, hatching, hatched }

class StarterPackScreen extends ConsumerStatefulWidget {
  const StarterPackScreen({super.key});
  @override
  ConsumerState<StarterPackScreen> createState() => _StarterPackScreenState();
}

class _StarterPackScreenState extends ConsumerState<StarterPackScreen>
    with TickerProviderStateMixin {
  List<OwnedPet>   _pets      = [];
  List<_EggState>  _eggStates = [];
  bool             _allHatched = false;

  // Per-egg controllers
  List<AnimationController> _shakeCtrl   = [];
  List<AnimationController> _revealCtrl  = [];
  List<AnimationController> _pulseCtrl   = [];
  List<AnimationController> _glowCtrl    = [];

  // Ambient scene controller
  late final AnimationController _ambient;

  static const _kPositionLabels = ['FRONT', 'MID', 'BACK'];
  static const _kPositionColors = [
    Color(0xFFFF4466),
    Color(0xFFFFCC44),
    Color(0xFF44FF88),
  ];

  @override
  void initState() {
    super.initState();
    _ambient = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) => _loadOrGenerate());
  }

  @override
  void dispose() {
    _ambient.dispose();
    for (final c in _shakeCtrl)  c.dispose();
    for (final c in _revealCtrl) c.dispose();
    for (final c in _pulseCtrl)  c.dispose();
    for (final c in _glowCtrl)   c.dispose();
    super.dispose();
  }

  // ── Init ────────────────────────────────────────────────────────────────────

  void _loadOrGenerate() {
    final player = ref.read(playerProvider);
    List<OwnedPet> pets;
    if (player.hasStarters) {
      pets = player.roster.take(3).toList();
    } else {
      pets = StarterPackService.generate();
      ref.read(playerProvider.notifier).saveStarterPets(pets);
    }

    final revealed = player.revealedStarterUids;
    _initControllers(pets.length);

    final states = pets
        .map((p) => revealed.contains(p.uid) ? _EggState.hatched : _EggState.idle)
        .toList();

    setState(() {
      _pets       = pets;
      _eggStates  = states;
      _allHatched = states.every((s) => s == _EggState.hatched);
    });

    for (var i = 0; i < states.length; i++) {
      if (states[i] == _EggState.hatched) {
        _revealCtrl[i].value = 1.0;
      } else {
        _pulseCtrl[i].repeat(reverse: true);
        _glowCtrl[i].repeat(reverse: true);
      }
    }
  }

  void _initControllers(int n) {
    for (final c in [..._shakeCtrl, ..._revealCtrl, ..._pulseCtrl, ..._glowCtrl]) {
      c.dispose();
    }
    _shakeCtrl  = List.generate(n, (_) => AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500)));
    _revealCtrl = List.generate(n, (_) => AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800)));
    _pulseCtrl  = List.generate(n, (_) => AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2200)));
    _glowCtrl   = List.generate(n, (_) => AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 2800 + n * 200)));
  }

  // ── Hatch ────────────────────────────────────────────────────────────────────

  Future<void> _hatch(int i) async {
    if (_eggStates[i] != _EggState.idle) return;

    HapticFeedback.mediumImpact();
    setState(() => _eggStates[i] = _EggState.hatching);
    _pulseCtrl[i].stop();
    _glowCtrl[i].stop();

    // Multi-shake burst
    for (var k = 0; k < 3; k++) {
      await _shakeCtrl[i].forward();
      _shakeCtrl[i].reset();
      await Future.delayed(const Duration(milliseconds: 60));
    }

    if (!mounted) return;
    HapticFeedback.heavyImpact();
    setState(() => _eggStates[i] = _EggState.hatched);
    await _revealCtrl[i].forward();

    ref.read(playerProvider.notifier).revealStarterPet(_pets[i].uid);
    if (mounted) await PetRevealSheet.show(context, _pets[i]);

    if (!mounted) return;
    if (_eggStates.every((s) => s == _EggState.hatched)) {
      setState(() => _allHatched = true);
    }
  }

  Future<void> _finish() async {
    HapticFeedback.lightImpact();
    ref.read(playerProvider.notifier).completeStarterPack();
    if (mounted) context.go(Routes.home);
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_pets.isEmpty) {
      return const Scaffold(
        backgroundColor: Color(0xFF050810),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF4AC4D9)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF050810),
      body: Stack(children: [
        // ── Animated background ──────────────────────────────────────────────
        _AmbientBg(ctrl: _ambient, pets: _pets, eggStates: _eggStates),

        // ── Rune decorations ─────────────────────────────────────────────────
        _RuneDecor(),

        // ── Main layout ──────────────────────────────────────────────────────
        SafeArea(
          child: LayoutBuilder(builder: (context, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;
            final isWide = w > 700;

            return isWide
                ? _WideLayout(
                    pets:       _pets,
                    eggStates:  _eggStates,
                    allHatched: _allHatched,
                    shakeCtrl:  _shakeCtrl,
                    revealCtrl: _revealCtrl,
                    pulseCtrl:  _pulseCtrl,
                    glowCtrl:   _glowCtrl,
                    ambient:    _ambient,
                    onHatch:    _hatch,
                    onFinish:   _finish,
                  )
                : _NarrowLayout(
                    pets:       _pets,
                    eggStates:  _eggStates,
                    allHatched: _allHatched,
                    shakeCtrl:  _shakeCtrl,
                    revealCtrl: _revealCtrl,
                    pulseCtrl:  _pulseCtrl,
                    glowCtrl:   _glowCtrl,
                    ambient:    _ambient,
                    onHatch:    _hatch,
                    onFinish:   _finish,
                  );
          }),
        ),
      ]),
    );
  }
}

// ── Ambient background ────────────────────────────────────────────────────────

class _AmbientBg extends StatelessWidget {
  final AnimationController ctrl;
  final List<OwnedPet> pets;
  final List<_EggState> eggStates;
  const _AmbientBg({required this.ctrl, required this.pets, required this.eggStates});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ctrl,
      builder: (_, __) {
        // Pick dominant color from hatched pets
        Color dominant = const Color(0xFF4AC4D9);
        for (var i = 0; i < eggStates.length; i++) {
          if (eggStates[i] == _EggState.hatched && i < pets.length) {
            dominant = _petAccent(pets[i]);
            break;
          }
        }
        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(
                -0.3 + ctrl.value * 0.6,
                -0.6 + ctrl.value * 0.3,
              ),
              radius: 1.4,
              colors: [
                dominant.withValues(alpha: 0.07 + ctrl.value * 0.05),
                const Color(0x00050810),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Rune decorations ──────────────────────────────────────────────────────────

class _RuneDecor extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(children: [
        Positioned(top: 20, left: 20, width: 60, height: 60,
          child: Opacity(opacity: 0.08,
            child: SvgPicture.asset('assets/images/ui/rune-spiral.svg',
                colorFilter: const ColorFilter.mode(Color(0xFF4AC4D9), BlendMode.srcIn)))),
        Positioned(top: 40, right: 30, width: 48, height: 48,
          child: Opacity(opacity: 0.06,
            child: SvgPicture.asset('assets/images/ui/rune-eye.svg',
                colorFilter: const ColorFilter.mode(Color(0xFF4AC4D9), BlendMode.srcIn)))),
        Positioned(bottom: 60, left: 40, width: 52, height: 52,
          child: Opacity(opacity: 0.07,
            child: SvgPicture.asset('assets/images/ui/rune-arrow.svg',
                colorFilter: const ColorFilter.mode(Color(0xFFE85AA8), BlendMode.srcIn)))),
        Positioned(bottom: 30, right: 20, width: 44, height: 44,
          child: Opacity(opacity: 0.07,
            child: SvgPicture.asset('assets/images/ui/rune-swirl.svg',
                colorFilter: const ColorFilter.mode(Color(0xFF4AC4D9), BlendMode.srcIn)))),
      ]),
    );
  }
}

// ── Wide layout (landscape / tablet) ─────────────────────────────────────────

class _WideLayout extends StatelessWidget {
  final List<OwnedPet> pets;
  final List<_EggState> eggStates;
  final bool allHatched;
  final List<AnimationController> shakeCtrl, revealCtrl, pulseCtrl, glowCtrl;
  final AnimationController ambient;
  final void Function(int) onHatch;
  final VoidCallback onFinish;

  const _WideLayout({
    required this.pets, required this.eggStates, required this.allHatched,
    required this.shakeCtrl, required this.revealCtrl, required this.pulseCtrl,
    required this.glowCtrl, required this.ambient,
    required this.onHatch, required this.onFinish,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      // Left info panel
      SizedBox(
        width: 200,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 12, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _GameLogo(),
              const SizedBox(height: 24),
              _InfoText(),
              const Spacer(),
              _ProgressDots(eggStates: eggStates),
              const SizedBox(height: 16),
              _StartButton(allHatched: allHatched, onFinish: onFinish),
            ],
          ),
        ),
      ),

      // Divider line
      Container(
        width: 1,
        margin: const EdgeInsets.symmetric(vertical: 20),
        color: const Color(0xFF4AC4D9).withValues(alpha: 0.12),
      ),

      // 3 Egg cards
      Expanded(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 16, 16, 16),
          child: Row(
            children: List.generate(pets.length, (i) => Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  left: i > 0 ? 8 : 0,
                  right: i < pets.length - 1 ? 8 : 0,
                ),
                child: _EggCard(
                  index: i,
                  pet: pets[i],
                  state: eggStates[i],
                  shakeCtrl: shakeCtrl[i],
                  revealCtrl: revealCtrl[i],
                  pulseCtrl: pulseCtrl[i],
                  glowCtrl: glowCtrl[i],
                  onTap: () => onHatch(i),
                ),
              ),
            )),
          ),
        ),
      ),
    ]);
  }
}

// ── Narrow layout (portrait / mobile) ────────────────────────────────────────

class _NarrowLayout extends StatelessWidget {
  final List<OwnedPet> pets;
  final List<_EggState> eggStates;
  final bool allHatched;
  final List<AnimationController> shakeCtrl, revealCtrl, pulseCtrl, glowCtrl;
  final AnimationController ambient;
  final void Function(int) onHatch;
  final VoidCallback onFinish;

  const _NarrowLayout({
    required this.pets, required this.eggStates, required this.allHatched,
    required this.shakeCtrl, required this.revealCtrl, required this.pulseCtrl,
    required this.glowCtrl, required this.ambient,
    required this.onHatch, required this.onFinish,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Header
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: Row(children: [
          _GameLogo(compact: true),
          const SizedBox(width: 12),
          Expanded(child: _InfoText(compact: true)),
        ]),
      ),

      // Eggs row
      Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: List.generate(pets.length, (i) => Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  left: i > 0 ? 5 : 0,
                  right: i < pets.length - 1 ? 5 : 0,
                ),
                child: _EggCard(
                  index: i,
                  pet: pets[i],
                  state: eggStates[i],
                  shakeCtrl: shakeCtrl[i],
                  revealCtrl: revealCtrl[i],
                  pulseCtrl: pulseCtrl[i],
                  glowCtrl: glowCtrl[i],
                  onTap: () => onHatch(i),
                ),
              ),
            )),
          ),
        ),
      ),

      // Bottom bar
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(children: [
          _ProgressDots(eggStates: eggStates, horizontal: true),
          const SizedBox(height: 10),
          _StartButton(allHatched: allHatched, onFinish: onFinish),
        ]),
      ),
    ]);
  }
}

// ── Logo / header ─────────────────────────────────────────────────────────────

class _GameLogo extends StatelessWidget {
  final bool compact;
  const _GameLogo({this.compact = false});

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
              colors: [Color(0xFF4AC4D9), Color(0xFF9C27B0)]),
          boxShadow: [
            BoxShadow(color: const Color(0xFF4AC4D9).withValues(alpha: 0.4),
                blurRadius: 12),
          ],
        ),
        child: const Center(child: Text('🐾', style: TextStyle(fontSize: 18))),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 48, height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
              colors: [Color(0xFF4AC4D9), Color(0xFF9C27B0)]),
          boxShadow: [
            BoxShadow(color: const Color(0xFF4AC4D9).withValues(alpha: 0.4),
                blurRadius: 16),
          ],
        ),
        child: const Center(child: Text('🐾', style: TextStyle(fontSize: 24))),
      ),
      const SizedBox(height: 12),
      const Text('LIKHA PET',
          style: TextStyle(
            fontFamily: 'LilitaOne',
            color: Color(0xFFEAFBFF),
            fontSize: 18,
            letterSpacing: 2,
            shadows: [Shadow(color: Color(0xFF4AC4D9), blurRadius: 10)],
          )),
    ]);
  }
}

// ── Info text ─────────────────────────────────────────────────────────────────

class _InfoText extends StatelessWidget {
  final bool compact;
  const _InfoText({this.compact = false});

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Choose Your Companions',
            style: GoogleFonts.rajdhani(
                color: Colors.white, fontSize: 16,
                fontWeight: FontWeight.w900, height: 1.1)),
        const Text('Tap each egg to reveal your starter pets',
            style: TextStyle(
                fontFamily: 'Fredoka', color: Colors.white38, fontSize: 11)),
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Choose Your\nCompanions',
          style: GoogleFonts.rajdhani(
              color: Colors.white, fontSize: 22,
              fontWeight: FontWeight.w900, height: 1.1)),
      const SizedBox(height: 8),
      const Text(
          'Three unique pets await.\nTap each egg to reveal\nyour starter companions.',
          style: TextStyle(
              fontFamily: 'Fredoka', color: Colors.white54,
              fontSize: 12, height: 1.5)),
      const SizedBox(height: 16),
      _FeatureLine(icon: '🧬', text: 'Unique DNA genetics'),
      const SizedBox(height: 5),
      _FeatureLine(icon: '⚔', text: 'Distinct battle cards'),
      const SizedBox(height: 5),
      _FeatureLine(icon: '🏆', text: 'Different class strengths'),
    ]);
  }
}

class _FeatureLine extends StatelessWidget {
  final String icon, text;
  const _FeatureLine({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Row(children: [
    Text(icon, style: const TextStyle(fontSize: 12)),
    const SizedBox(width: 6),
    Text(text, style: const TextStyle(
        fontFamily: 'Fredoka', color: Colors.white38, fontSize: 11)),
  ]);
}

// ── Progress dots ─────────────────────────────────────────────────────────────

class _ProgressDots extends StatelessWidget {
  final List<_EggState> eggStates;
  final bool horizontal;
  const _ProgressDots({required this.eggStates, this.horizontal = false});

  @override
  Widget build(BuildContext context) {
    final hatched = eggStates.where((s) => s == _EggState.hatched).length;
    final total   = eggStates.length;

    final dots = Row(
      mainAxisSize: horizontal ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final done = i < hatched;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: done ? 24 : 8,
          height: 8,
          margin: const EdgeInsets.only(right: 5),
          decoration: BoxDecoration(
            gradient: done
                ? const LinearGradient(
                    colors: [Color(0xFF4AC4D9), Color(0xFF9C27B0)])
                : null,
            color: done ? null : Colors.white12,
            borderRadius: BorderRadius.circular(4),
            boxShadow: done
                ? [BoxShadow(
                    color: const Color(0xFF4AC4D9).withValues(alpha: 0.5),
                    blurRadius: 6)]
                : null,
          ),
        );
      }),
    );

    return Column(
      crossAxisAlignment: horizontal
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        if (!horizontal)
          Text('$hatched / $total HATCHED',
              style: const TextStyle(
                  fontFamily: 'LilitaOne',
                  color: Colors.white38,
                  fontSize: 9,
                  letterSpacing: 1.5)),
        if (!horizontal) const SizedBox(height: 6),
        dots,
      ],
    );
  }
}

// ── Start button ──────────────────────────────────────────────────────────────

class _StartButton extends StatelessWidget {
  final bool allHatched;
  final VoidCallback onFinish;
  const _StartButton({required this.allHatched, required this.onFinish});

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: allHatched ? 1.0 : 0.3,
      duration: const Duration(milliseconds: 400),
      child: GestureDetector(
        onTap: allHatched ? onFinish : null,
        child: Container(
          width: double.infinity,
          height: 48,
          decoration: BoxDecoration(
            gradient: allHatched
                ? const LinearGradient(
                    colors: [Color(0xFF4AC4D9), Color(0xFF9C27B0)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  )
                : null,
            color: allHatched ? null : Colors.white10,
            borderRadius: BorderRadius.circular(14),
            boxShadow: allHatched
                ? [
                    BoxShadow(
                        color: const Color(0xFF4AC4D9).withValues(alpha: 0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 4)),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              allHatched ? '⚔  START ADVENTURE' : 'HATCH ALL EGGS FIRST',
              style: TextStyle(
                fontFamily: 'LilitaOne',
                color: allHatched ? Colors.white : Colors.white38,
                fontSize: 14,
                letterSpacing: 1.5,
                shadows: allHatched
                    ? const [Shadow(color: Colors.black38, blurRadius: 4)]
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Egg card ──────────────────────────────────────────────────────────────────

class _EggCard extends StatelessWidget {
  final int index;
  final OwnedPet pet;
  final _EggState state;
  final AnimationController shakeCtrl, revealCtrl, pulseCtrl, glowCtrl;
  final VoidCallback onTap;

  const _EggCard({
    required this.index,
    required this.pet,
    required this.state,
    required this.shakeCtrl,
    required this.revealCtrl,
    required this.pulseCtrl,
    required this.glowCtrl,
    required this.onTap,
  });

  static const _kSlotLabels  = ['FRONT', 'MID', 'BACK'];
  static const _kSlotColors  = [Color(0xFFFF4466), Color(0xFFFFCC44), Color(0xFF44FF88)];

  @override
  Widget build(BuildContext context) {
    final accent   = _petAccent(pet);
    final isHatched  = state == _EggState.hatched;
    final isHatching = state == _EggState.hatching;
    final slotColor  = _kSlotColors[index % _kSlotColors.length];
    final slotLabel  = _kSlotLabels[index % _kSlotLabels.length];

    return AnimatedBuilder(
      animation: shakeCtrl,
      builder: (_, child) => Transform.translate(
        offset: Offset(sin(shakeCtrl.value * pi * 10) * 10, 0),
        child: child,
      ),
      child: AnimatedBuilder(
        animation: glowCtrl,
        builder: (_, child) {
          final glow = isHatched
              ? accent.withValues(alpha: 0.35 + glowCtrl.value * 0.15)
              : const Color(0xFF4AC4D9).withValues(alpha: 0.06);
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: glow, blurRadius: 24, spreadRadius: 2),
              ],
            ),
            child: child,
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isHatched
                  ? [
                      accent.withValues(alpha: 0.18),
                      const Color(0xFF0A1224),
                    ]
                  : [
                      const Color(0xFF0E1A33),
                      const Color(0xFF080F1E),
                    ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isHatched
                  ? accent.withValues(alpha: 0.65)
                  : isHatching
                      ? Colors.orange.withValues(alpha: 0.5)
                      : const Color(0xFF1E3A5F),
              width: isHatched ? 1.5 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(children: [
            // Slot badge
            Positioned(
              top: 10, left: 10,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: slotColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: slotColor.withValues(alpha: 0.5)),
                ),
                child: Text(slotLabel,
                    style: TextStyle(
                      fontFamily: 'LilitaOne',
                      color: slotColor,
                      fontSize: 9,
                      letterSpacing: 1,
                    )),
              ),
            ),

            // Content
            isHatched
                ? _HatchedContent(
                    pet: pet,
                    accent: accent,
                    revealCtrl: revealCtrl,
                  )
                : _EggContent(
                    index: index,
                    isHatching: isHatching,
                    pulseCtrl: pulseCtrl,
                    onTap: onTap,
                  ),
          ]),
        ),
      ),
    );
  }
}

// ── Egg content (before hatch) ────────────────────────────────────────────────

class _EggContent extends StatelessWidget {
  final int index;
  final bool isHatching;
  final AnimationController pulseCtrl;
  final VoidCallback onTap;

  const _EggContent({
    required this.index,
    required this.isHatching,
    required this.pulseCtrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isHatching ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 40, 12, 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Glowing egg
            Expanded(
              child: AnimatedBuilder(
                animation: pulseCtrl,
                builder: (_, __) {
                  final glow = isHatching
                      ? Colors.orange.withValues(alpha: 0.25)
                      : const Color(0xFF4AC4D9)
                          .withValues(alpha: 0.06 + pulseCtrl.value * 0.08);
                  return Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: glow,
                            blurRadius: 30,
                            spreadRadius: 8),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        isHatching ? '✨' : '🥚',
                        style: TextStyle(
                            fontSize: isHatching ? 56 : 52),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Hex platform under egg
            SvgPicture.asset(
              'assets/images/ui/hex-platform.svg',
              width: 60,
              colorFilter: ColorFilter.mode(
                  const Color(0xFF4AC4D9).withValues(alpha: 0.25),
                  BlendMode.srcIn),
            ),

            const SizedBox(height: 12),

            // Label
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                isHatching
                    ? 'HATCHING...'
                    : 'TAP TO HATCH',
                key: ValueKey(isHatching),
                style: TextStyle(
                  fontFamily: 'LilitaOne',
                  color: isHatching
                      ? Colors.orange
                      : const Color(0xFF4AC4D9).withValues(alpha: 0.6),
                  fontSize: 10,
                  letterSpacing: 2,
                ),
              ),
            ),

            const SizedBox(height: 4),
            Text(
              'Mystery Pet #${index + 1}',
              style: const TextStyle(
                  fontFamily: 'Fredoka',
                  color: Colors.white24,
                  fontSize: 10),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ── Hatched content ───────────────────────────────────────────────────────────

class _HatchedContent extends StatelessWidget {
  final OwnedPet pet;
  final Color accent;
  final AnimationController revealCtrl;

  const _HatchedContent({
    required this.pet,
    required this.accent,
    required this.revealCtrl,
  });

  @override
  Widget build(BuildContext context) {
    final def = pet.toCreatureDefinition();
    final body = kBodyCatalogue[pet.bodyId];
    final cls  = body?.bodyClass ?? CreatureClass.beast;

    return ScaleTransition(
      scale: CurvedAnimation(
          parent: revealCtrl, curve: Curves.elasticOut),
      child: LayoutBuilder(builder: (_, c) {
        final petSize = (c.maxWidth * 0.82).clamp(60.0, 200.0);
        return Column(children: [
          // Pet sprite
          Expanded(
            child: Stack(children: [
              // Ground glow
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: Center(
                  child: Container(
                    width: petSize * 0.7,
                    height: 12,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      gradient: RadialGradient(
                        colors: [
                          accent.withValues(alpha: 0.6),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Center(
                child: PetRendererWidget(def: def, size: petSize),
              ),
            ]),
          ),

          // Class + name + parts
          Container(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Class badge
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: accent.withValues(alpha: 0.6)),
                ),
                child: Text(cls.displayName,
                    style: TextStyle(
                        fontFamily: 'LilitaOne',
                        color: accent,
                        fontSize: 9,
                        letterSpacing: 1)),
              ),
              const SizedBox(height: 5),
              // Pet name
              Text(pet.name,
                  style: const TextStyle(
                    fontFamily: 'LilitaOne',
                    color: Color(0xFFEAFBFF),
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 5),
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
        ]);
      }),
    );
  }
}

// ── Part dot ──────────────────────────────────────────────────────────────────

class _PartDot extends StatelessWidget {
  final CreatureClass cls;
  const _PartDot(this.cls);

  static Color _c(CreatureClass c) => _kAccents[c.name] ?? const Color(0xFF4AC4D9);

  @override
  Widget build(BuildContext context) => Container(
        width: 9, height: 9,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _c(cls),
          boxShadow: [
            BoxShadow(color: _c(cls).withValues(alpha: 0.7), blurRadius: 5)
          ],
        ),
      );
}
