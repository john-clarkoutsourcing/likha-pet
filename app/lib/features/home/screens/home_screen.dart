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
    final mediaQuery = MediaQuery.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF050810),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          final layout = _HomeLayoutMetrics.fromView(
            screenSize: size,
            safePadding: mediaQuery.padding,
          );

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
              Positioned.fromRect(
                rect: layout.contentRect,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _buildTeamFormation(player, layout),
                    _buildTopCluster(playerName, layout),
                    _buildRightTotem(player, layout),
                    _buildBottomLeftNav(layout),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTopCluster(String playerName, _HomeLayoutMetrics layout) {
    final size = layout.contentSize;
    final leftRegionWidth =
        size.width - layout.totemWidth - layout.horizontalGap * 2;
    final nameplateLeft = size.width * 0.02;
    final topInset = size.height * 0.02;
    final nameplateWidth = (leftRegionWidth * (layout.isMobile ? 0.54 : 0.50))
        .clamp(170.0, 430.0);
    final nameplateHeight = (size.height *
            (layout.isMobile ? 0.08 : (layout.isCompact ? 0.095 : 0.082)))
        .clamp(44.0, 84.0);
    final questSize = (layout.isMobile ? 52.0 : (layout.isCompact ? 62.0 : 70.0));
    final questLeft = math.min(
      leftRegionWidth - questSize,
      nameplateLeft + nameplateWidth + layout.horizontalGap,
    );
    final energyTop = topInset + nameplateHeight + size.height * 0.018;

    return Stack(
      children: [
        Positioned(
          left: nameplateLeft,
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
                    fontSize: layout.isCompact ? 24 : 28,
                    glow: true,
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: nameplateLeft + size.width * 0.01,
          top: energyTop,
          child: _EnergyChip(
            isCompact: layout.isCompact,
            isMobile: layout.isMobile,
          ),
        ),
        Positioned(
          left: questLeft,
          top: topInset,
          child: _QuestButton(
            onTap: () => context.push(Routes.library),
            size: questSize,
          ),
        ),
      ],
    );
  }

  Widget _buildRightTotem(PlayerData player, _HomeLayoutMetrics layout) {
    final size = layout.contentSize;
    final width = layout.totemWidth;
    final height = layout.totemHeight;
    final canQuickBattle = player.hasFullTeam;

    return Positioned(
      right: 0,
      top: size.height * (layout.isMobile ? 0.01 : 0.005),
      width: width,
      height: height,
      child: _AssetFrame(
        assetPath: 'assets/images/ui/totem-frame.svg',
        width: width,
        height: height,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            width * 0.12,
            height * (layout.isMobile ? 0.13 : 0.11),
            width * 0.12,
            height * (layout.isMobile ? 0.08 : 0.07),
          ),
          child: Stack(
            children: [
              _RuneRails(animation: _sceneController),
              Column(
                children: [
                  _PvpBanner(
                    width: width * 0.82,
                    compact: layout.isMobile,
                    onTap: () => context.push(Routes.pvpQueue),
                  ),
                  SizedBox(height: height * 0.035),
                  _TotemButton(
                    assetPath: 'assets/images/ui/button-cyan.svg',
                    label: 'ADVENTURE',
                    icon: Icons.flag,
                    width: width * 0.82,
                    compact: layout.isMobile,
                    onTap: () => context.push(Routes.worldMap),
                  ),
                  SizedBox(height: height * 0.02),
                  _TotemButton(
                    assetPath: 'assets/images/ui/button-magenta.svg',
                    label: 'ARENA',
                    icon: Icons.sports_martial_arts,
                    width: width * 0.82,
                    compact: layout.isMobile,
                    onTap: canQuickBattle
                        ? () => context.push(
                              Routes.battle,
                              extra: const BattleScreenArgs(
                                playerTeamName: 'My Team',
                                enemyTeamName: 'Rivals',
                              ),
                            )
                        : () => context.push(Routes.teamManager),
                  ),
                  const Spacer(),
                  _TotemFooter(
                    iconSize: layout.isMobile ? 14 : (layout.isCompact ? 18 : 20),
                    tileSize: layout.isMobile ? 34 : (layout.isCompact ? 42 : 46),
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

  Widget _buildBottomLeftNav(_HomeLayoutMetrics layout) {
    final buttonSize = layout.navButtonSize;
    final gap = layout.horizontalGap;

    return Positioned(
      left: 0,
      bottom: 0,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _NavAssetButton(
            label: 'MY PETS',
            svgIcon: 'assets/images/ui/pets.svg',
            svgColorFilter: const ColorFilter.mode(
              Color(0xFF7FE3F5), BlendMode.srcIn),
            size: buttonSize,
            onTap: () => context.push(Routes.roster),
          ),
          SizedBox(width: gap),
          _NavAssetButton(
            label: 'MY TEAMS',
            svgIcon: 'assets/images/ui/teams-icon.svg',
            size: buttonSize,
            onTap: () => context.push(Routes.teamManager),
          ),
          SizedBox(width: gap),
          _NavAssetButton(
            label: 'TRAITS',
            svgIcon: 'assets/images/ui/traits-icon.svg',
            size: buttonSize,
            onTap: () => context.push(Routes.library),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamFormation(PlayerData player, _HomeLayoutMetrics layout) {
    final size       = layout.contentSize;
    final team       = _resolveActiveTeam(player);
    final teamName   = player.activeComposition?.name;
    final leftRegionWidth =
        size.width - layout.totemWidth - layout.horizontalGap * 2;
    final maxHeight = size.height -
        layout.navRowHeight -
        layout.horizontalGap * 1.7 -
        size.height * (layout.isMobile ? 0.18 : 0.14);
    final formationHeight = math.min(
      size.height * (layout.isMobile ? 0.36 : (layout.isCompact ? 0.50 : 0.56)),
      maxHeight,
    );
    final formationWidth = math.min(
      leftRegionWidth,
      size.width * (layout.isMobile ? 0.66 : (layout.isCompact ? 0.62 : 0.60)),
    );
    final baseSize =
        (formationHeight *
                (layout.isMobile ? 0.60 : (layout.isCompact ? 0.56 : 0.60)))
            .clamp(layout.isMobile ? 120.0 : 180.0, layout.isMobile ? 170.0 : 360.0);
    final leftOne = layout.isMobile ? 0.00 : 0.04;
    final leftTwo = layout.isMobile ? 0.24 : 0.24;
    final leftThree = layout.isMobile ? 0.49 : 0.47;

    final nameFontSize = layout.isMobile ? 13.0 : 16.0;

    return Positioned(
      left: 0,
      bottom: layout.navRowHeight + layout.horizontalGap * 1.5,
      width: formationWidth,
      height: formationHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ── Active team name banner ─────────────────────────────────────
          Positioned(
            top: 0,
            left: 8,
            right: 0,
            child: teamName != null
                ? Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE85AA8).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFFE85AA8).withValues(alpha: 0.6),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFE85AA8).withValues(alpha: 0.25),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.bolt_rounded,
                                size: 11, color: Color(0xFFE85AA8)),
                            const SizedBox(width: 4),
                            Text(
                              teamName,
                              style: TextStyle(
                                fontFamily: 'LilitaOne',
                                color: const Color(0xFFFFBBDD),
                                fontSize: nameFontSize,
                                shadows: const [
                                  Shadow(
                                      color: Color(0xFF0A1224),
                                      offset: Offset(-1, -1),
                                      blurRadius: 1),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : GestureDetector(
                    onTap: () => context.push(Routes.teamManager),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4AC4D9).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF4AC4D9).withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_rounded,
                              size: 11,
                              color: const Color(0xFF4AC4D9).withValues(alpha: 0.8)),
                          const SizedBox(width: 4),
                          Text(
                            'Set Active Team',
                            style: TextStyle(
                              fontFamily: 'Fredoka',
                              color: const Color(0xFF7FE3F5).withValues(alpha: 0.7),
                              fontSize: nameFontSize - 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
          // ── Pet actors ──────────────────────────────────────────────────
          _PetActor(
            pet: team[0],
            label: 'FRONT',
            positionLabel: 'FRONT',
            positionColor: const Color(0xFFFF5252),
            size: baseSize * 0.94,
            left: formationWidth * leftOne,
            bottom: formationHeight * 0.01,
            animation: _sceneController,
            phase: 0.4,
          ),
          _PetActor(
            pet: team[1],
            label: 'MID',
            positionLabel: 'MID',
            positionColor: const Color(0xFFFFD740),
            size: baseSize,
            left: formationWidth * leftTwo,
            bottom: formationHeight * 0.0,
            animation: _sceneController,
            phase: 1.0,
            isHero: true,
          ),
          _PetActor(
            pet: team[2],
            label: 'BACK',
            positionLabel: 'BACK',
            positionColor: const Color(0xFF69F0AE),
            size: baseSize * 0.94,
            left: formationWidth * leftThree,
            bottom: formationHeight * 0.01,
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

class _HomeLayoutMetrics {
  final Size screenSize;
  final EdgeInsets safePadding;
  final Rect contentRect;
  final bool isCompact;
  final bool isMobile;
  final double scale;

  const _HomeLayoutMetrics({
    required this.screenSize,
    required this.safePadding,
    required this.contentRect,
    required this.isCompact,
    required this.isMobile,
    required this.scale,
  });

  factory _HomeLayoutMetrics.fromView({
    required Size screenSize,
    required EdgeInsets safePadding,
  }) {
    final usableWidth = screenSize.width - safePadding.horizontal;
    final usableHeight = screenSize.height - safePadding.vertical;
    final horizontalInset = math.max(12.0, usableWidth * 0.018);
    final verticalInset = math.max(10.0, usableHeight * 0.02);
    final contentRect = Rect.fromLTWH(
      safePadding.left + horizontalInset,
      safePadding.top + verticalInset,
      usableWidth - (horizontalInset * 2),
      usableHeight - (verticalInset * 2),
    );
    final shortestSide = math.min(contentRect.width, contentRect.height);
    final isMobile = contentRect.width < 760 || shortestSide < 520;
    final isCompact = contentRect.width < 1100;
    final scale = math.min(contentRect.width / 1600, contentRect.height / 900)
        .clamp(0.55, 1.2);

    return _HomeLayoutMetrics(
      screenSize: screenSize,
      safePadding: safePadding,
      contentRect: contentRect,
      isCompact: isCompact,
      isMobile: isMobile,
      scale: scale,
    );
  }

  Size get contentSize => contentRect.size;

  bool get isLandscape => contentSize.width >= contentSize.height;

  double get horizontalGap =>
      (contentSize.width * (isMobile ? 0.018 : 0.014)).clamp(8.0, 18.0);

  double get totemWidth {
    if (isMobile && isLandscape) {
      return (contentSize.width * 0.35).clamp(188.0, 260.0);
    }

    return (isMobile ? contentSize.width * 0.31 : contentSize.width * 0.22)
        .clamp(isMobile ? 156.0 : 220.0, isMobile ? 210.0 : 360.0);
  }

  double get totemHeight {
    if (isMobile && isLandscape) {
      return math.min(contentSize.height * 0.82, contentSize.height);
    }

    return math.min(
      contentSize.height * (isMobile ? 0.70 : 0.94),
      contentSize.height,
    );
  }

  double get navButtonSize =>
      (isMobile ? contentSize.width * 0.13 : contentSize.width * 0.078)
          .clamp(56.0, 88.0);

  double get navLabelHeight =>
      navButtonSize < 75 ? 14.0 : (navButtonSize < 90 ? 16.0 : 18.0);

  double get navRowHeight => navButtonSize + navLabelHeight + 8;
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
  final bool isMobile;

  const _EnergyChip({required this.isCompact, required this.isMobile});

  @override
  Widget build(BuildContext context) {
    final chipWidth = isMobile ? 96.0 : (isCompact ? 108.0 : 118.0);
    final chipHeight = isMobile ? 36.0 : (isCompact ? 40.0 : 44.0);

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
  final bool compact;
  final VoidCallback onTap;

  const _PvpBanner({
    required this.width,
    required this.compact,
    required this.onTap,
  });

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
              left: width * 0.13,
              right: width * 0.13,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'PVP Arena',
                  style: _displayStyle(
                    fontSize: compact ? 13 : (width < 170 ? 16 : 18),
                  ),
                ),
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
  final bool compact;
  final VoidCallback onTap;

  const _TotemButton({
    required this.assetPath,
    required this.label,
    required this.icon,
    required this.width,
    required this.compact,
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
                  size: compact ? width * 0.11 : width * 0.12,
                  shadows: const [
                    Shadow(color: Color(0xAA0A1224), blurRadius: 8),
                  ],
                ),
                SizedBox(width: width * 0.04),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      style: _displayStyle(
                        fontSize: compact ? 14 : (width < 200 ? 17 : 19),
                        glow: true,
                      ),
                    ),
                  ),
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
  final String        label;
  final IconData?     icon;
  final String?       svgIcon;
  final ColorFilter?  svgColorFilter;
  final double        size;
  final VoidCallback  onTap;

  const _NavAssetButton({
    required this.label,
    required this.size,
    required this.onTap,
    this.icon,
    this.svgIcon,
    this.svgColorFilter,
  }) : assert(icon != null || svgIcon != null,
            'Provide either icon or svgIcon');

  @override
  Widget build(BuildContext context) {
    final labelHeight = size < 75 ? 14.0 : (size < 90 ? 16.0 : 18.0);
    final runeSize    = size < 75 ? 9.0 : 11.0;
    final iconArea    = size * (svgIcon != null ? 0.52 : 0.34);

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
                    top: 6,
                    left: 7,
                    child: SvgPicture.asset(
                      'assets/images/ui/rune-swirl.svg',
                      width: runeSize,
                      height: runeSize,
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 7,
                    child: Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()..scaleByDouble(-1.0, 1.0, 1.0, 1.0),
                      child: SvgPicture.asset(
                        'assets/images/ui/rune-swirl.svg',
                        width: runeSize,
                        height: runeSize,
                      ),
                    ),
                  ),
                  Center(
                    child: svgIcon != null
                        ? SvgPicture.asset(
                            svgIcon!,
                            width:       iconArea,
                            height:      iconArea,
                            fit:         BoxFit.contain,
                            colorFilter: svgColorFilter,
                          )
                        : Icon(
                            icon!,
                            color: const Color(0xFF7FE3F5),
                            size: iconArea,
                            shadows: const [
                              Shadow(
                                  color: Color(0xAA00E5FF),
                                  blurRadius: 12),
                              Shadow(
                                  color: Color(0xAA4AC4D9),
                                  blurRadius: 22),
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
                  style: _displayStyle(
                      fontSize: size < 75 ? 11 : (size < 90 ? 13 : 15)),
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
  final String positionLabel;
  final Color  positionColor;
  final double size;
  final double left;
  final double bottom;
  final Animation<double> animation;
  final double phase;
  final bool isHero;

  const _PetActor({
    required this.pet,
    required this.label,
    required this.positionLabel,
    required this.positionColor,
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
                    child: SizedBox(
                      width: size * (isHero ? 0.82 : 0.76),
                      height: size * (isHero ? 0.82 : 0.76),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: size * (isHero ? 0.38 : 0.32),
                            height: size * (isHero ? 0.38 : 0.32),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF00E5FF)
                                  .withValues(alpha: 0.10 * pulse),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF00E5FF)
                                      .withValues(alpha: 0.55 * pulse),
                                  blurRadius: 55,
                                  spreadRadius: 22,
                                ),
                                BoxShadow(
                                  color: const Color(0xFF4AC4D9)
                                      .withValues(alpha: 0.30 * pulse),
                                  blurRadius: 90,
                                  spreadRadius: 36,
                                ),
                              ],
                            ),
                          ),
                          Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()..scaleByDouble(-1.0, 1.0, 1.0, 1.0),
                            child: PetRendererWidget.fromOwned(
                              pet!,
                              size: size * 0.76,
                              figScale: 0.25,
                              animation: 'action/idle/normal',
                            ),
                          ),
                        ],
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
                // ── Position label pill (FRONT / MID / BACK) ─────────────
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: size * 0.07,
                        vertical:   size * 0.018,
                      ),
                      decoration: BoxDecoration(
                        color: positionColor.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: positionColor.withValues(alpha: 0.65),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: positionColor.withValues(alpha: 0.30),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Text(
                        positionLabel,
                        style: TextStyle(
                          fontFamily: 'LilitaOne',
                          color: positionColor,
                          fontSize: (size * 0.07).clamp(8.0, 13.0),
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
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
