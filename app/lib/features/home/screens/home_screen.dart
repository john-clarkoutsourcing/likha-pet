import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../auth/providers/auth_provider.dart';
import '../../battle/screens/battle_screen.dart';
import '../../battle/widgets/pet_renderer_widget.dart';
import '../../pets/models/owned_pet.dart';
import '../../pets/models/player_data.dart';
import '../../pets/providers/player_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sceneController;

  @override
  void initState() {
    super.initState();
    _sceneController = AnimationController(
      duration: const Duration(seconds: 18),
      vsync: this,
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final player = ref.read(playerProvider);
      if (player.roster.isEmpty && mounted) {
        context.go(Routes.starterPack);
      }
    });
  }

  @override
  void dispose() {
    _sceneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = ref.watch(playerProvider);
    final userEmail = ref.watch(userEmailProvider) ?? 'qiqapi@likha.pet';
    final playerName = userEmail.split('@').first;

    return Scaffold(
      backgroundColor: const Color(0xFF050810),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          final isCompact = size.width < 980;

          return Stack(
            fit: StackFit.expand,
            children: [
              const Image(
                image: AssetImage('assets/images/ui/bg-1.jpg'),
                fit: BoxFit.cover,
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.0, 0.0),
                    radius: 1.15,
                    colors: [
                      Colors.transparent,
                      const Color(0xFF050810).withValues(alpha: 0.35),
                      const Color(0xFF050810).withValues(alpha: 0.72),
                    ],
                  ),
                ),
              ),
              CustomPaint(painter: _FireflyPainter(animation: _sceneController)),
              _buildTeamFormation(player, size, isCompact),
              _buildTopCluster(playerName, size, isCompact),
              _buildRightTotem(player, size, isCompact),
              _buildBottomLeftNav(size, isCompact),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTopCluster(String playerName, Size size, bool isCompact) {
    final nameplateWidth = size.width * (isCompact ? 0.40 : 0.29);
    final nameplateHeight = size.height * (isCompact ? 0.11 : 0.08);
    final topInset = size.height * 0.045;

    return Stack(
      children: [
        Positioned(
          left: size.width * 0.042,
          top: topInset,
          child: _AssetFrame(
            assetPath: 'assets/images/ui/nameplate.svg',
            width: nameplateWidth,
            height: nameplateHeight,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: nameplateWidth * 0.14),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  playerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _displayStyle(
                    fontSize: isCompact ? 24 : 28,
                    glow: true,
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: size.width * 0.055,
          top: size.height * 0.15,
          child: _EnergyChip(isCompact: isCompact),
        ),
        Positioned(
          left: size.width * (isCompact ? 0.43 : 0.36),
          top: topInset,
          child: _QuestButton(
            onTap: () => context.push(Routes.library),
            size: isCompact ? 62 : 70,
          ),
        ),
      ],
    );
  }

  Widget _buildRightTotem(PlayerData player, Size size, bool isCompact) {
    final width = (size.width * (isCompact ? 0.33 : 0.22)).clamp(210.0, 360.0);
    final height = size.height * (isCompact ? 0.90 : 0.95);
    final canQuickBattle = player.hasFullTeam;

    return Positioned(
      right: size.width * 0.015,
      top: size.height * 0.03,
      width: width,
      height: height,
      child: _AssetFrame(
        assetPath: 'assets/images/ui/totem-frame.svg',
        width: width,
        height: height,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            width * 0.12,
            height * 0.11,
            width * 0.12,
            height * 0.07,
          ),
          child: Stack(
            children: [
              _RuneRails(animation: _sceneController),
              Column(
                children: [
                  _PvpBanner(
                    width: width * 0.82,
                    onTap: () => context.push(Routes.pvpQueue),
                  ),
                  SizedBox(height: height * 0.035),
                  _TotemButton(
                    assetPath: 'assets/images/ui/button-cyan.svg',
                    label: 'ADVENTURE',
                    icon: Icons.flag,
                    width: width * 0.82,
                    onTap: () => context.push(Routes.worldMap),
                  ),
                  SizedBox(height: height * 0.02),
                  _TotemButton(
                    assetPath: 'assets/images/ui/button-magenta.svg',
                    label: 'ARENA',
                    icon: Icons.sports_martial_arts,
                    width: width * 0.82,
                    onTap: canQuickBattle
                        ? () => context.push(
                              Routes.battle,
                              extra: const BattleScreenArgs(
                                playerTeamName: 'My Team',
                                enemyTeamName: 'Rivals',
                              ),
                            )
                        : () => context.push(Routes.roster),
                  ),
                  const Spacer(),
                  _TotemFooter(
                    iconSize: isCompact ? 18 : 20,
                    tileSize: isCompact ? 42 : 46,
                    onRankTap: () => context.push(Routes.pvpQueue),
                    onNewsTap: () => context.push(Routes.library),
                    onProfileTap: () => context.push(Routes.roster),
                    onSettingsTap: () async {
                      await ref.read(authProvider.notifier).logout();
                      if (mounted) {
                        context.go(Routes.login);
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomLeftNav(Size size, bool isCompact) {
    final buttonSize = isCompact ? 84.0 : 96.0;

    return Positioned(
      left: size.width * 0.02,
      bottom: size.height * 0.025,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _NavAssetButton(
            label: 'PETS',
            icon: Icons.pets,
            size: buttonSize,
            onTap: () => context.push(Routes.roster),
          ),
          SizedBox(width: size.width * 0.014),
          _NavAssetButton(
            label: 'TRAITS',
            icon: Icons.shield,
            size: buttonSize,
            onTap: () => context.push(Routes.library),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamFormation(PlayerData player, Size size, bool isCompact) {
    final team = _resolveActiveTeam(player);

    final formationHeight = size.height * (isCompact ? 0.52 : 0.58);
    final formationWidth = size.width * (isCompact ? 0.62 : 0.58);
    final baseSize =
        (formationHeight * (isCompact ? 0.50 : 0.56)).clamp(150.0, 340.0);

    return Positioned(
      left: size.width * 0.01,
      bottom: size.height * (isCompact ? 0.19 : 0.21),
      width: formationWidth,
      height: formationHeight,
      child: Stack(
        children: [
          _PetActor(
            pet: team[0],
            label: 'FRONT',
            size: baseSize * 0.9,
            left: formationWidth * 0.09,
            bottom: formationHeight * 0.02,
            animation: _sceneController,
            phase: 0.4,
          ),
          _PetActor(
            pet: team[1],
            label: 'MID',
            size: baseSize,
            left: formationWidth * 0.29,
            bottom: formationHeight * 0.01,
            animation: _sceneController,
            phase: 1.0,
            isHero: true,
          ),
          _PetActor(
            pet: team[2],
            label: 'BACK',
            size: baseSize * 0.9,
            left: formationWidth * 0.49,
            bottom: formationHeight * 0.02,
            animation: _sceneController,
            phase: 1.6,
          ),
        ],
      ),
    );
  }

  List<OwnedPet?> _resolveActiveTeam(PlayerData player) {
    final team = <OwnedPet?>[];

    for (int i = 0; i < 3; i++) {
      if (i >= player.activeTeam.length) {
        team.add(null);
        continue;
      }

      final uid = player.activeTeam[i];
      OwnedPet? pet;
      try {
        pet = player.roster.firstWhere((candidate) => candidate.uid == uid);
      } catch (_) {
        pet = null;
      }
      team.add(pet);
    }

    return team;
  }
}

class _FireflyPainter extends CustomPainter {
  final Animation<double> animation;

  _FireflyPainter({required this.animation}) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(42);
    const count = 58;

    for (int i = 0; i < count; i++) {
      final seedX = random.nextDouble();
      final seedY = random.nextDouble();
      final driftPhase = random.nextDouble() * 2 * math.pi;
      final speed = 0.14 + random.nextDouble() * 0.2;
      final radius = 1.6 + random.nextDouble() * 3.4;

      final t = (animation.value + i * 0.047) % 1.0;
      final x =
          (seedX * size.width) + math.sin((t * 2 * math.pi) + driftPhase) * 26;
      final yBase = seedY * size.height;
      final y =
          (yBase - t * size.height * (1.1 + speed) + size.height) % size.height;

      final alpha = ((math.sin((t * 2 * math.pi) + driftPhase) + 1) * 0.5) *
              0.95 +
          0.25;

      final sparklePulse =
          0.75 + (math.sin((t * 2 * math.pi * 1.8) + driftPhase) + 1) * 0.2;

      canvas.drawCircle(
        Offset(x, y),
        radius + 4.4,
        Paint()
          ..color = const Color(0xFF00E5FF).withValues(alpha: alpha * 0.52)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
      );
      canvas.drawCircle(
        Offset(x, y),
        radius + 2.1,
        Paint()
          ..color = const Color(0xFF00E5FF)
              .withValues(alpha: alpha * 0.72 * sparklePulse)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
      );
      canvas.drawCircle(
        Offset(x, y),
        radius,
        Paint()
          ..color = const Color(0xFFBFF8FF)
              .withValues(alpha: alpha * sparklePulse)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.8),
      );
    }
  }

  @override
  bool shouldRepaint(_FireflyPainter oldDelegate) => true;
}

TextStyle _displayStyle({required double fontSize, bool glow = false}) {
  return TextStyle(
    fontFamily: 'LilitaOne',
    color: const Color(0xFFEAFBFF),
    fontSize: fontSize,
    letterSpacing: 0.5,
    shadows: [
      const Shadow(
        color: Color(0xFF0A1224),
        offset: Offset(-2, -2),
        blurRadius: 1,
      ),
      const Shadow(
        color: Color(0xFF0A1224),
        offset: Offset(2, -2),
        blurRadius: 1,
      ),
      const Shadow(
        color: Color(0xFF0A1224),
        offset: Offset(-2, 2),
        blurRadius: 1,
      ),
      const Shadow(
        color: Color(0xFF0A1224),
        offset: Offset(2, 2),
        blurRadius: 1,
      ),
      if (glow) const Shadow(color: Color(0xAA4AC4D9), blurRadius: 12),
    ],
  );
}

TextStyle _bodyStyle({
  required double fontSize,
  FontWeight weight = FontWeight.w500,
}) {
  return TextStyle(
    fontFamily: 'Fredoka',
    color: const Color(0xFFCDEEF4),
    fontSize: fontSize,
    fontWeight: weight,
  );
}

class _AssetFrame extends StatelessWidget {
  final String assetPath;
  final double width;
  final double height;
  final Widget child;

  const _AssetFrame({
    required this.assetPath,
    required this.width,
    required this.height,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          SvgPicture.asset(assetPath, fit: BoxFit.fill),
          child,
        ],
      ),
    );
  }
}

class _QuestButton extends StatelessWidget {
  final VoidCallback onTap;
  final double size;

  const _QuestButton({required this.onTap, required this.size});

  @override
  Widget build(BuildContext context) {
    final labelHeight = size < 66 ? 14.0 : 16.0;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: size,
        height: size + labelHeight + 8,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: size,
              height: size,
              child: SvgPicture.asset(
                'assets/images/ui/scroll-quest.svg',
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: labelHeight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'QUESTS',
                  maxLines: 1,
                  style: _displayStyle(fontSize: size < 66 ? 12 : 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EnergyChip extends StatelessWidget {
  final bool isCompact;

  const _EnergyChip({required this.isCompact});

  @override
  Widget build(BuildContext context) {
    final chipWidth = isCompact ? 108.0 : 118.0;
    final chipHeight = isCompact ? 40.0 : 44.0;

    return SizedBox(
      width: chipWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AssetFrame(
            assetPath: 'assets/images/ui/energy-chip.svg',
            width: chipWidth,
            height: chipHeight,
            child: Center(
              child: Text(
                '0/0',
                style: _displayStyle(fontSize: isCompact ? 17 : 19),
              ),
            ),
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF0A1224).withValues(alpha: 0.55),
                  border: Border.all(color: const Color(0xFF7FE3F5), width: 1),
                ),
                child: Center(
                  child: Text(
                    '?',
                    style: _displayStyle(fontSize: 10),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Energy?',
                style: _bodyStyle(fontSize: 12, weight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PvpBanner extends StatelessWidget {
  final double width;
  final VoidCallback onTap;

  const _PvpBanner({required this.width, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: width,
        height: width * 0.95,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SvgPicture.asset('assets/images/ui/pvp-banner.svg', fit: BoxFit.fill),
            Positioned(
              top: width * 0.16,
              child: SvgPicture.asset(
                'assets/images/ui/axs-crystal.svg',
                width: width * 0.32,
                height: width * 0.32,
              ),
            ),
            Positioned(
              top: width * 0.52,
              child: Text(
                'PVP Arena',
                style: _displayStyle(fontSize: width < 170 ? 16 : 18),
              ),
            ),
            Positioned(
              top: width * 0.70,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFF0A1224), width: 1.4),
                ),
                child: Text(
                  'SEASON 18',
                  style: _bodyStyle(fontSize: 10, weight: FontWeight.w700).copyWith(
                    color: const Color(0xFF0A1224),
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TotemButton extends StatelessWidget {
  final String assetPath;
  final String label;
  final IconData icon;
  final double width;
  final VoidCallback onTap;

  const _TotemButton({
    required this.assetPath,
    required this.label,
    required this.icon,
    required this.width,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: width,
        height: width * 0.31,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SvgPicture.asset(assetPath, fit: BoxFit.fill),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: Colors.white,
                  size: width * 0.12,
                  shadows: const [
                    Shadow(color: Color(0xAA0A1224), blurRadius: 8),
                  ],
                ),
                SizedBox(width: width * 0.04),
                Text(
                  label,
                  style: _displayStyle(fontSize: width < 200 ? 17 : 19, glow: true),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TotemFooter extends StatelessWidget {
  final double tileSize;
  final double iconSize;
  final VoidCallback onRankTap;
  final VoidCallback onNewsTap;
  final VoidCallback onProfileTap;
  final VoidCallback onSettingsTap;

  const _TotemFooter({
    required this.tileSize,
    required this.iconSize,
    required this.onRankTap,
    required this.onNewsTap,
    required this.onProfileTap,
    required this.onSettingsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _WoodTile(
          icon: Icons.workspace_premium,
          size: tileSize,
          iconSize: iconSize,
          onTap: onRankTap,
        ),
        _WoodTile(
          icon: Icons.article,
          size: tileSize,
          iconSize: iconSize,
          onTap: onNewsTap,
        ),
        _WoodTile(
          icon: Icons.person,
          size: tileSize,
          iconSize: iconSize,
          onTap: onProfileTap,
        ),
        _WoodTile(
          icon: Icons.settings,
          size: tileSize,
          iconSize: iconSize,
          onTap: onSettingsTap,
        ),
      ],
    );
  }
}

class _WoodTile extends StatelessWidget {
  final IconData icon;
  final double size;
  final double iconSize;
  final VoidCallback onTap;

  const _WoodTile({
    required this.icon,
    required this.size,
    required this.iconSize,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SvgPicture.asset('assets/images/ui/wooden-tile.svg', fit: BoxFit.fill),
            Icon(
              icon,
              color: const Color(0xFFBFF0FA),
              size: iconSize,
              shadows: const [
                Shadow(color: Color(0xAA00E5FF), blurRadius: 12),
                Shadow(color: Color(0xAA4AC4D9), blurRadius: 22),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RuneRails extends StatelessWidget {
  final Animation<double> animation;

  const _RuneRails({required this.animation});

  @override
  Widget build(BuildContext context) {
    const runeAssets = [
      'assets/images/ui/rune-swirl.svg',
      'assets/images/ui/rune-eye.svg',
      'assets/images/ui/rune-triple.svg',
      'assets/images/ui/rune-spiral.svg',
      'assets/images/ui/rune-arrow.svg',
    ];

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final pulse = 0.5 + (math.sin(animation.value * 2 * math.pi) + 1) * 0.25;
        return Opacity(opacity: pulse, child: child);
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: const [
          _RuneColumn(runeAssets: runeAssets),
          _RuneColumn(runeAssets: runeAssets),
        ],
      ),
    );
  }
}

class _RuneColumn extends StatelessWidget {
  final List<String> runeAssets;

  const _RuneColumn({required this.runeAssets});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: runeAssets
          .map(
            (asset) => SvgPicture.asset(
              asset,
              width: 12,
              height: 12,
              fit: BoxFit.contain,
            ),
          )
          .toList(growable: false),
    );
  }
}

class _NavAssetButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final double size;
  final VoidCallback onTap;

  const _NavAssetButton({
    required this.label,
    required this.icon,
    required this.size,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final labelHeight = size < 90 ? 16.0 : 18.0;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: size,
        height: size + labelHeight + 8,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: size,
              height: size,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: SvgPicture.asset(
                      'assets/images/ui/nav-button.svg',
                      fit: BoxFit.fill,
                    ),
                  ),
                  Positioned(
                    top: 7,
                    left: 8,
                    child: SvgPicture.asset(
                      'assets/images/ui/rune-swirl.svg',
                      width: 11,
                      height: 11,
                    ),
                  ),
                  Positioned(
                    top: 7,
                    right: 8,
                    child: Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()..scale(-1.0, 1.0),
                      child: SvgPicture.asset(
                        'assets/images/ui/rune-swirl.svg',
                        width: 11,
                        height: 11,
                      ),
                    ),
                  ),
                  Center(
                    child: Icon(
                      icon,
                      color: const Color(0xFF7FE3F5),
                      size: size * 0.34,
                      shadows: const [
                        Shadow(color: Color(0xAA00E5FF), blurRadius: 12),
                        Shadow(color: Color(0xAA4AC4D9), blurRadius: 22),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: labelHeight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: _displayStyle(fontSize: size < 90 ? 14 : 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PetActor extends StatelessWidget {
  final OwnedPet? pet;
  final String label;
  final double size;
  final double left;
  final double bottom;
  final Animation<double> animation;
  final double phase;
  final bool isHero;

  const _PetActor({
    required this.pet,
    required this.label,
    required this.size,
    required this.left,
    required this.bottom,
    required this.animation,
    required this.phase,
    this.isHero = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final bob = math.sin((animation.value * 2 * math.pi) + phase) * 8;
        final pulse = 0.7 + (math.sin((animation.value * 2 * math.pi) + phase) + 1) * 0.15;

        return Positioned(
          left: left,
          bottom: bottom + bob,
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                Positioned(
                  bottom: size * 0.04,
                  child: Container(
                    width: size * 0.62,
                    height: size * 0.16,
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.15 * pulse),
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00E5FF).withValues(alpha: 0.45 * pulse),
                          blurRadius: 24,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  bottom: size * 0.01,
                  child: SvgPicture.asset(
                    'assets/images/ui/hex-platform.svg',
                    width: size * 0.74,
                    height: size * 0.36,
                    fit: BoxFit.contain,
                  ),
                ),
                if (pet != null)
                  Positioned(
                    bottom: size * 0.06,
                    child: Container(
                      width: size * (isHero ? 0.7 : 0.66),
                      height: size * (isHero ? 0.7 : 0.66),
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xAA4AC4D9).withValues(alpha: 0.38),
                            blurRadius: 26,
                          ),
                        ],
                      ),
                      child: Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()..scale(-1.0, 1.0),
                        child: PetRendererWidget.fromOwned(
                          pet!,
                          size: size * 0.68,
                          figScale: 0.25,
                          animation: 'action/idle/normal',
                        ),
                      ),
                    ),
                  )
                else
                  Positioned(
                    bottom: size * 0.10,
                    child: Text(
                      label,
                      style: _displayStyle(fontSize: size * 0.09),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
