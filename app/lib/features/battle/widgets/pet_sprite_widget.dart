import 'dart:math';
import 'package:flame/cache.dart';
import 'package:flame/components.dart' hide Matrix4;
import 'package:flame/game.dart' hide Matrix4;
import 'package:flame/widgets.dart';
import 'package:flutter/material.dart';

// ── Sprite config ─────────────────────────────────────────────────────────────

/// One animation state backed by a horizontal-strip PNG spritesheet.
///
/// Place the PNG in `assets/sprites/` then reference it by filename only.
///
/// Example:
///   PetAnimConfig(
///     sheetFile: 'bakunawa_idle.png',
///     frameSize: Vector2(48, 48),
///     frameCount: 6,
///     stepTime: 0.10,
///   )
class PetAnimConfig {
  final String  sheetFile;
  final Vector2 frameSize;
  final int     frameCount;
  final double  stepTime;

  const PetAnimConfig({
    required this.sheetFile,
    required this.frameSize,
    this.frameCount = 4,
    this.stepTime   = 0.12,
  });
}

class PetSpriteConfig {
  final PetAnimConfig  idle;
  final PetAnimConfig? attack;
  final PetAnimConfig? hurt;
  final PetAnimConfig? faint;

  const PetSpriteConfig({required this.idle, this.attack, this.hurt, this.faint});
}

enum PetAnimState { idle, attack, hurt, faint }

// ── Shared image cache (one prefix, shared across all sprite widgets) ─────────

final _spritesImages = Images(prefix: 'assets/sprites/');

// ── Placeholder Flame game (animated until a real sheet is assigned) ──────────

class _PlaceholderGame extends FlameGame {
  final Color  _color;
  final String _label;

  _PlaceholderGame(this._color, this._label);

  double          _t      = 0;
  CircleComponent? _ring;
  CircleComponent? _fill;

  @override
  Color backgroundColor() => Colors.transparent;

  @override
  Future<void> onLoad() async {
    final cx = size.x / 2;
    final cy = size.y / 2;
    final r  = (size.x / 2) - 3;

    _fill = CircleComponent(
      radius: r,
      position: Vector2(cx, cy),
      anchor: Anchor.center,
      paint: Paint()
        ..color = _color
        ..style = PaintingStyle.fill,
    );

    _ring = CircleComponent(
      radius: r,
      position: Vector2(cx, cy),
      anchor: Anchor.center,
      paint: Paint()
        ..color = Colors.white.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    final label = TextComponent(
      text: _label,
      anchor: Anchor.center,
      position: Vector2(cx, cy),
      textRenderer: TextPaint(
        style: TextStyle(
          color: Colors.white,
          fontSize: r * 0.82,
          fontWeight: FontWeight.w900,
        ),
      ),
    );

    addAll([_fill!, _ring!, label]);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    final bob = sin(_t * 2.8) * 2.5;
    final cy  = size.y / 2;
    _fill?.position.y = cy + bob;
    _ring?.position.y = cy + bob;
  }
}

// ── PetSpriteWidget ───────────────────────────────────────────────────────────

/// Renders a pet sprite using Flame.
///
/// - When [config] is provided and the PNG loads: plays the spritesheet animation.
/// - Otherwise: shows a Flame-driven placeholder (bobbing circle) so the game
///   loop is always visible and ready to swap in real sheets.
class PetSpriteWidget extends StatefulWidget {
  final PetSpriteConfig? config;
  final PetAnimState     animState;
  final double           size;
  final bool             flipHorizontal;
  final String           petName;
  final Color            petColor;

  const PetSpriteWidget({
    super.key,
    required this.size,
    required this.petName,
    required this.petColor,
    this.config,
    this.animState      = PetAnimState.idle,
    this.flipHorizontal = false,
  });

  @override
  State<PetSpriteWidget> createState() => _PetSpriteWidgetState();
}

class _PetSpriteWidgetState extends State<PetSpriteWidget> {
  late _PlaceholderGame _placeholder;

  @override
  void initState() {
    super.initState();
    _placeholder = _PlaceholderGame(widget.petColor, widget.petName[0]);
  }

  @override
  void dispose() {
    _placeholder.onRemove();
    super.dispose();
  }

  PetAnimConfig get _animConfig {
    final c = widget.config;
    if (c == null) return _noop;
    return switch (widget.animState) {
      PetAnimState.attack => c.attack ?? c.idle,
      PetAnimState.hurt   => c.hurt   ?? c.idle,
      PetAnimState.faint  => c.faint  ?? c.idle,
      PetAnimState.idle   => c.idle,
    };
  }

  static final _noop = PetAnimConfig(
    sheetFile: '',
    frameSize: Vector2(1, 1),
    frameCount: 1,
  );

  @override
  Widget build(BuildContext context) {
    Widget child;

    if (widget.config != null) {
      final a = _animConfig;
      child = SpriteAnimationWidget.asset(
        path:   a.sheetFile,
        images: _spritesImages,
        data: SpriteAnimationData.sequenced(
          amount:      a.frameCount,
          stepTime:    a.stepTime,
          textureSize: a.frameSize,
          loop: widget.animState != PetAnimState.faint,
        ),
        // Fall back to placeholder if the sheet fails to load.
        errorBuilder: (_) => GameWidget(game: _placeholder),
      );
    } else {
      child = GameWidget(game: _placeholder);
    }

    if (widget.flipHorizontal) {
      child = Transform(
        alignment: Alignment.center,
        transform: Matrix4.diagonal3Values(-1, 1, 1),
        child: child,
      );
    }

    return SizedBox(width: widget.size, height: widget.size, child: child);
  }
}
