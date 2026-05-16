import 'dart:math';
import 'package:flame/cache.dart';
import 'package:flame/components.dart' hide Matrix4;
import 'package:flame/widgets.dart';
import 'package:flutter/material.dart';

// ── Config ────────────────────────────────────────────────────────────────────

class ProjectileConfig {
  final String sheetFile;   // filename under assetPrefix
  final String assetPrefix; // e.g. assets/sprites/
  final int    frameCount;
  final int?   amountPerRow;
  final double frameSize;   // px per frame (square)
  final double textureSize; // source frame size in sprite sheet
  final double stepTime;    // seconds per frame
  final double scale;       // visual scale on screen
  final bool   useScreenBlend;

  const ProjectileConfig({
    required this.sheetFile,
    this.assetPrefix = 'assets/sprites/',
    required this.frameCount,
    this.amountPerRow,
    this.frameSize = 120,
    this.textureSize = 120,
    this.stepTime  = 0.10,
    this.scale     = 1.0,
    this.useScreenBlend = false,
  });
}

// Assign a projectile type to each pet ID.
const kPetProjectiles = <String, ProjectileConfig>{
  'bayani_1': ProjectileConfig(sheetFile: 'water_ball.png',  frameCount: 12),
  'bayani_2': ProjectileConfig(sheetFile: 'fire_ball.png',   frameCount: 8),
  'bayani_3': ProjectileConfig(sheetFile: 'fire_spell.png',  frameCount: 8),
  'diwata_1': ProjectileConfig(sheetFile: 'water_spell.png', frameCount: 8),
  'diwata_2': ProjectileConfig(sheetFile: 'water_arrow.png', frameCount: 8),
  'diwata_3': ProjectileConfig(sheetFile: 'fire_arrow.png',  frameCount: 8),
};

const kEffectProjectiles = <String, ProjectileConfig>{
  'damage': ProjectileConfig(sheetFile: 'fire_arrow.png', frameCount: 8, scale: 0.9),
  'aoe': ProjectileConfig(sheetFile: 'fire_ball.png', frameCount: 8, scale: 1.1),
  'heal': ProjectileConfig(
    sheetFile: 'healing_particle_effect.png',
    assetPrefix: 'assets/images/effects/',
    frameCount: 12,
    amountPerRow: 4,
    frameSize: 160,
    textureSize: 256,
    stepTime: 0.06,
    scale: 1.0,
    useScreenBlend: true,
  ),
  'shield': ProjectileConfig(sheetFile: 'water_ball.png', frameCount: 12, scale: 1.0),
  'buff': ProjectileConfig(sheetFile: 'water_spell.png', frameCount: 8, scale: 1.0),
  'debuff': ProjectileConfig(sheetFile: 'fire_spell.png', frameCount: 8, scale: 1.0),
  'shieldBreak': ProjectileConfig(sheetFile: 'fire_ball.png', frameCount: 8, scale: 1.1),
};

ProjectileConfig resolveProjectileConfig(String petId, {String? effectType}) {
  if (effectType != null) {
    final byEffect = kEffectProjectiles[effectType];
    if (byEffect != null) return byEffect;
  }
  return kPetProjectiles[petId] ??
      const ProjectileConfig(sheetFile: 'water_ball.png', frameCount: 12);
}

final _imagesByPrefix = <String, Images>{};
Images _imagesForPrefix(String prefix) =>
    _imagesByPrefix.putIfAbsent(prefix, () => Images(prefix: prefix));

// ── Projectile data passed to overlay ────────────────────────────────────────

class ProjectileInstance {
  final String           id;
  final Offset           start;  // absolute screen coords
  final Offset           end;
  final ProjectileConfig config;

  const ProjectileInstance({
    required this.id,
    required this.start,
    required this.end,
    required this.config,
  });
}

// ── Single flying projectile ──────────────────────────────────────────────────

class ProjectileWidget extends StatefulWidget {
  final ProjectileInstance data;
  final VoidCallback        onDone;

  const ProjectileWidget({super.key, required this.data, required this.onDone});

  @override
  State<ProjectileWidget> createState() => _ProjectileWidgetState();
}

class _ProjectileWidgetState extends State<ProjectileWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset>   _pos;
  late Animation<double>   _angle; // rotate to face direction of travel

  @override
  void initState() {
    super.initState();
    final dx = widget.data.end.dx - widget.data.start.dx;
    final dy = widget.data.end.dy - widget.data.start.dy;
    final travelAngle = atan2(dy, dx);

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pos = Tween<Offset>(begin: widget.data.start, end: widget.data.end)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeIn));
    _angle = ConstantTween<double>(travelAngle).animate(_ctrl);

    _ctrl.forward().then((_) {
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cfg  = widget.data.config;
    final size = cfg.frameSize * cfg.scale;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) => Positioned(
        left: _pos.value.dx - size / 2,
        top:  _pos.value.dy - size / 2,
        child: Transform.rotate(
          angle: _angle.value,
          child: child,
        ),
      ),
      child: SizedBox(
        width: size, height: size,
        child: SpriteAnimationWidget.asset(
          path:   cfg.sheetFile,
          images: _imagesForPrefix(cfg.assetPrefix),
          data: SpriteAnimationData.sequenced(
            amount:      cfg.frameCount,
            amountPerRow: cfg.amountPerRow ?? cfg.frameCount,
            stepTime:    cfg.stepTime,
            textureSize: Vector2(cfg.textureSize, cfg.textureSize),
            loop: true,
          ),
          paint: cfg.useScreenBlend
              ? (Paint()
                ..isAntiAlias = true
                ..filterQuality = FilterQuality.high
                ..blendMode = BlendMode.screen)
              : null,
          errorBuilder: (_) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}
