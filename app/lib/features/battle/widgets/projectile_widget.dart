import 'dart:math';
import 'package:flame/cache.dart';
import 'package:flame/components.dart' hide Matrix4;
import 'package:flame/widgets.dart';
import 'package:flutter/material.dart';

// ── Config ────────────────────────────────────────────────────────────────────

class ProjectileConfig {
  final String sheetFile;    // filename under assetPrefix; empty = use fallbackColor
  final String assetPrefix;
  final int    frameCount;
  final int?   amountPerRow;
  final double frameSize;
  final double textureSize;
  final double stepTime;
  final double scale;
  final bool   useScreenBlend;

  /// When [sheetFile] is empty, the projectile renders as a glowing orb of
  /// this colour — a placeholder until real VFX sprite sheets are available.
  final Color? fallbackColor;

  const ProjectileConfig({
    this.sheetFile = '',
    this.assetPrefix = 'assets/sprites/',
    this.frameCount = 1,
    this.amountPerRow,
    this.frameSize = 120,
    this.textureSize = 120,
    this.stepTime  = 0.10,
    this.scale     = 1.0,
    this.useScreenBlend = false,
    this.fallbackColor,
  });
}

// ── Placeholder colours by creature class ─────────────────────────────────────

const kProjectileClassColors = <String, Color>{
  'aquatic': Color(0xFF4ECBF5),
  'beast':   Color(0xFFF5A623),
  'bird':    Color(0xFFFFF176),
  'plant':   Color(0xFF66BB6A),
  'reptile': Color(0xFFBA68C8),
  'bug':     Color(0xFFAA8855),
};

/// Returns a config that renders the rune-arrow SVG tinted with the class colour.
/// The arrow automatically faces the travel direction (ProjectileWidget rotates it).
ProjectileConfig configForCreatureClass(String className) => ProjectileConfig(
      fallbackColor:
          kProjectileClassColors[className] ?? const Color(0xFFFFFFFF),
      frameSize: 48,
    );

// Sprite-sheet entries go here when assets are ready.
const kEffectProjectiles = <String, ProjectileConfig>{};

ProjectileConfig? resolveProjectileConfig({required String effectType}) =>
    kEffectProjectiles[effectType];

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
      duration: const Duration(milliseconds: 650),
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
        width: size,
        height: size,
        child: cfg.fallbackColor != null
            ? _OrbWidget(color: cfg.fallbackColor!, size: size)
            : SpriteAnimationWidget.asset(
                path: cfg.sheetFile,
                images: _imagesForPrefix(cfg.assetPrefix),
                data: SpriteAnimationData.sequenced(
                  amount: cfg.frameCount,
                  amountPerRow: cfg.amountPerRow ?? cfg.frameCount,
                  stepTime: cfg.stepTime,
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

// ── Prototype rock projectile (CustomPaint — no asset needed) ─────────────────

class _OrbWidget extends StatelessWidget {
  final Color color;
  final double size;
  const _OrbWidget({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _RockPainter(color),
    );
  }
}

class _RockPainter extends CustomPainter {
  final Color tint;
  _RockPainter(this.tint);

  // Irregular stone polygon — points in normalized -0.5..0.5 coordinates.
  static const _pts = [
    Offset( 0.05, -0.46),
    Offset( 0.32, -0.38),
    Offset( 0.46, -0.10),
    Offset( 0.42,  0.22),
    Offset( 0.16,  0.46),
    Offset(-0.14,  0.44),
    Offset(-0.42,  0.26),
    Offset(-0.46, -0.06),
    Offset(-0.28, -0.38),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final s  = size.shortestSide;

    final rock = Color.lerp(const Color(0xFF7A7A7A), tint, 0.30)!;
    final dark = Color.lerp(const Color(0xFF383838), tint, 0.15)!;
    final lite = Color.lerp(const Color(0xFFCCCCCC), tint, 0.18)!;

    final path = _buildPath(cx, cy, s);

    // Drop shadow
    canvas.drawPath(
      path.shift(const Offset(1.5, 2.0)),
      Paint()
        ..color = Colors.black45
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    // Rock body — top-left lighter, bottom-right darker
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [lite, rock, dark],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Rect.fromCenter(
          center: Offset(cx, cy),
          width: s,
          height: s,
        )),
    );

    // Small highlight spot (upper-left face)
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx - s * 0.10, cy - s * 0.12),
        width:  s * 0.26,
        height: s * 0.16,
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.22),
    );

    // Outline
    canvas.drawPath(
      path,
      Paint()
        ..color = dark.withValues(alpha: 0.65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
  }

  Path _buildPath(double cx, double cy, double s) {
    final path = Path();
    final first = Offset(cx + _pts[0].dx * s, cy + _pts[0].dy * s);
    path.moveTo(first.dx, first.dy);
    for (final p in _pts.skip(1)) {
      path.lineTo(cx + p.dx * s, cy + p.dy * s);
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(_RockPainter old) => old.tint != tint;
}
