import 'package:flutter/material.dart';

import '../data/classic_card_status_icon_map.dart';

class ClassicTraitCardWidget extends StatelessWidget {
  final String imagePath;
  final String imageName;
  final String name;
  final int energy;
  final int attack;
  final int defense;
  final String description;
  final bool showDescription;

  const ClassicTraitCardWidget({
    super.key,
    required this.imagePath,
    required this.imageName,
    required this.name,
    required this.energy,
    required this.attack,
    required this.defense,
    required this.description,
    this.showDescription = true,
  });

  @override
  Widget build(BuildContext context) {
    final statusIcon = kClassicCardStatusIconByImageName[imageName];

    return AspectRatio(
      aspectRatio: 220 / 300,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          final uiScale = (w / 220).clamp(0.6, 1.0).toDouble();
          final isCompact = w < 120;
          final nameFontSize = (isCompact ? w * 0.088 : w * 0.075)
              .clamp(isCompact ? 8.5 : 11.0, isCompact ? 10.5 : 15.0)
              .toDouble();
          final nameTopPadding = isCompact ? h * 0.018 : h * 0.046;
          final nameRowHeight = isCompact ? h * 0.112 : h * 0.125;
          final descTopPadding = isCompact ? h * 0.008 : h * 0.02;
          final descIconYOffset = isCompact ? h * 0.008 : h * 0.02;
          final descIconSize = isCompact ? (22 * uiScale) : (30 * uiScale);
          final descTextSize = isCompact ? (w * 0.075).clamp(7.0, 8.5) : 10 * uiScale;
          final descMaxLines = isCompact ? 1 : 2;

          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: w * 0.09,
                top: h * 0.067,
                width: w * 0.91,
                height: h,
                child: Image.asset(
                  imagePath,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) =>
                      Container(color: const Color(0xFF1D2440)),
                ),
              ),
              Positioned.fill(
                child: Column(
                  children: [
                    SizedBox(
                      height: h * 0.17,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _EnergyBadge(value: energy, size: w * 0.273),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: h * 0.43,
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: Padding(
                          padding: EdgeInsets.only(left: w * 0.036),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (attack > 0)
                                _StatBadge(
                                  value: attack,
                                  iconAsset:
                                      'assets/images/status/classic/icon-atk.png',
                                  width: w * 0.273,
                                  height: h * 0.20,
                                ),
                              if (defense > 0)
                                _StatBadge(
                                  value: defense,
                                  iconAsset:
                                      'assets/images/status/classic/icon-def.png',
                                  width: w * 0.273,
                                  height: h * 0.20,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: nameRowHeight,
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: w * 0.177,
                          right: w * 0.073,
                          top: nameTopPadding,
                        ),
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: Text(
                            name,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Fredoka',
                              color: const Color(0xFF442215),
                              fontSize: nameFontSize,
                              fontWeight: FontWeight.w700,
                              shadows: const [
                                Shadow(color: Colors.black26, blurRadius: 2)
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (showDescription)
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            left: w * 0.177,
                            right: w * 0.073,
                            top: descTopPadding,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              if (statusIcon != null)
                                Transform.translate(
                                  offset: Offset(-4 * uiScale, descIconYOffset),
                                  child: SizedBox(
                                    width: descIconSize,
                                    height: descIconSize,
                                    child: Image.asset(
                                      'assets/images/status/classic/$statusIcon.png',
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                              if (statusIcon != null)
                                SizedBox(width: 4 * uiScale),
                              Expanded(
                                child: Text(
                                  description,
                                  maxLines: descMaxLines,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: descTextSize.toDouble(),
                                    fontWeight: FontWeight.w700,
                                    height: 1.15,
                                    shadows: const [
                                      Shadow(
                                          color: Colors.black45, blurRadius: 2)
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EnergyBadge extends StatelessWidget {
  final int value;
  final double size;
  const _EnergyBadge({required this.value, required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/status/classic/icon-energy-big.png',
            fit: BoxFit.contain,
          ),
          Center(
              child: Text(
                '$value',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: size * 0.38,
                  fontWeight: FontWeight.w900,
                  shadows: const [Shadow(color: Colors.black45, blurRadius: 2)],
                ),
              ),
          ),
        ],
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final int value;
  final String iconAsset;
  final double width;
  final double height;
  const _StatBadge({
    required this.value,
    required this.iconAsset,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(iconAsset, fit: BoxFit.contain),
          Center(
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: width * 0.28,
                fontWeight: FontWeight.w900,
                shadows: const [Shadow(color: Colors.black45, blurRadius: 2)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
