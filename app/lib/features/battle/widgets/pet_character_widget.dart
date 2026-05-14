import 'dart:math';
import 'package:flame/components.dart' hide Matrix4;
import 'package:flame/effects.dart';
import 'package:flame/game.dart' hide Matrix4;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ── Config ────────────────────────────────────────────────────────────────────

class PetCharacterConfig {
  final String texturePath;
  const PetCharacterConfig({required this.texturePath});
}

enum PetCharacterAnimState { idle, attack, hit, faint }

// ── Flame game ────────────────────────────────────────────────────────────────

class _CharacterGame extends FlameGame {
  final String texturePath;
  _CharacterGame({required this.texturePath});

  SpriteComponent? _sprite;
  double _t   = 0;
  bool _idle  = true; // false while an animation effect is running

  @override
  Color backgroundColor() => Colors.transparent;

  @override
  Future<void> onLoad() async {
    try {
      final bytes   = await rootBundle.load(texturePath);
      final uiImage = await decodeImageFromList(bytes.buffer.asUint8List());
      images.add(texturePath, uiImage);
      _sprite = SpriteComponent(
        sprite:   Sprite(uiImage),
        size:     Vector2(size.x, size.y),
        position: size / 2,
        anchor:   Anchor.center,
      );
      add(_sprite!);
    } catch (_) {}
  }

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    if (_idle) {
      _sprite?.position.y = size.y / 2 + sin(_t * 2.5) * 3;
    }
  }

  // Lunge toward the enemy then spring back.
  // [isPlayer] true = faces right (lunge right), false = faces left (lunge left).
  void playAttack({required bool isPlayer}) {
    final sp = _sprite;
    if (sp == null) return;
    _idle = false;
    sp.removeWhere((c) => c is Effect);

    final dir    = isPlayer ? 55.0 : -55.0;
    final center = Vector2(size.x / 2, size.y / 2);

    sp.add(SequenceEffect([
      // Rush forward
      MoveByEffect(Vector2(dir, -14),
          EffectController(duration: 0.25, curve: Curves.easeOut)),
      // Brief hold at peak
      MoveByEffect(Vector2.zero(),
          EffectController(duration: 0.12)),
      // Spring back
      MoveByEffect(Vector2(-dir, 14),
          EffectController(duration: 0.35, curve: Curves.easeIn)),
      MoveToEffect(center, EffectController(duration: 0.06)),
    ], onComplete: () {
      sp.position = center;
      _idle = true;
    }));
  }

  void playHit() {
    final sp = _sprite;
    if (sp == null) return;
    sp.removeWhere((c) => c is Effect);
    sp.add(SequenceEffect([
      MoveByEffect(Vector2(-12, 0), EffectController(duration: 0.06)),
      MoveByEffect(Vector2( 12, 0), EffectController(duration: 0.06)),
    ]));
  }
}

// ── Widget ────────────────────────────────────────────────────────────────────

class PetCharacterWidget extends StatefulWidget {
  final PetCharacterConfig    config;
  final PetCharacterAnimState animState;
  final double                size;
  final bool                  flipHorizontal;

  const PetCharacterWidget({
    super.key,
    required this.config,
    required this.size,
    this.animState      = PetCharacterAnimState.idle,
    this.flipHorizontal = false,
  });

  @override
  State<PetCharacterWidget> createState() => _PetCharacterWidgetState();
}

class _PetCharacterWidgetState extends State<PetCharacterWidget> {
  late _CharacterGame _game;

  @override
  void initState() {
    super.initState();
    _game = _CharacterGame(texturePath: widget.config.texturePath);
  }

  @override
  void didUpdateWidget(PetCharacterWidget old) {
    super.didUpdateWidget(old);
    if (old.animState == widget.animState) return;
    switch (widget.animState) {
      case PetCharacterAnimState.attack:
        _game.playAttack(isPlayer: widget.flipHorizontal);
      case PetCharacterAnimState.hit:
        _game.playHit();
      case PetCharacterAnimState.idle:
      case PetCharacterAnimState.faint:
        break;
    }
  }

  @override
  void dispose() {
    _game.onRemove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget child = GameWidget(game: _game);
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
