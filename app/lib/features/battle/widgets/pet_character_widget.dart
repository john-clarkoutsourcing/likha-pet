import 'dart:math';
import 'dart:ui' as ui;
import 'package:flame/components.dart' hide Matrix4;
import 'package:flame/effects.dart';
import 'package:flame/game.dart' hide Matrix4;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:spine_flutter/spine_flutter.dart' show SpineWidget, SpineWidgetController;

// ── Config ────────────────────────────────────────────────────────────────────

class PetCharacterConfig {
  final String texturePath;
  final String? spineAtlasPath;
  final String? spineSkeletonPath;
  final Map<String, dynamic>? skeletonJson;  // For runtime-generated mixed skeletons

  const PetCharacterConfig({
    required this.texturePath,
    this.spineAtlasPath,
    this.spineSkeletonPath,
    this.skeletonJson,
  });

  bool get hasSpine => (spineAtlasPath != null && spineSkeletonPath != null) || skeletonJson != null;
  bool get isMixed => skeletonJson != null;
}

enum PetCharacterAnimState {
  idle,
  move,          // action/move-forward — hop before attacking
  attackMelee,   // attack/melee/tail-roll
  attackRanged,  // attack/ranged/tail-roll
  attack,        // generic fallback (tries melee then ranged)
  hit,
  buff,
  debuff,
  heal,
  shield,
  faint,
}

// ── Flame game ────────────────────────────────────────────────────────────────

class _CharacterGame extends FlameGame {
  final String texturePath;
  _CharacterGame({required this.texturePath});

  SpriteComponent? _sprite;
  // Keep a strong Dart reference to the ui.Image so the GC cannot collect
  // it while Flame still holds a native handle — prevents the
  // "SkImage was disposed" assertion in dart:ui during rapid rebuilds.
  ui.Image? _imageRef;

  double _t      = 0;
  bool _idle     = true;
  bool _removed  = false;

  @override
  Color backgroundColor() => Colors.transparent;

  @override
  void onRemove() {
    _removed = true;
    _sprite  = null;   // prevent any further draw calls on the sprite
    _imageRef = null;  // release the strong reference only after Flame stops rendering
    super.onRemove();
  }

  @override
  void render(Canvas canvas) {
    if (_removed || _sprite == null) return;
    try {
      super.render(canvas);
    } catch (_) {
      // Swallow any residual SkImage-disposed assertions.
    }
  }

  @override
  Future<void> onLoad() async {
    try {
      final bytes = await rootBundle.load(texturePath);
      _imageRef   = await decodeImageFromList(bytes.buffer.asUint8List());
      if (_removed) return; // game was removed while loading
      images.add(texturePath, _imageRef!);
      _sprite = SpriteComponent(
        sprite:   Sprite(_imageRef!),
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

  // Forward hop (action/move-forward) — arc jump then land back.
  void playMove({required bool isPlayer}) {
    final sp = _sprite;
    if (sp == null) return;
    _idle = false;
    sp.removeWhere((c) => c is Effect);

    final dir    = isPlayer ? 45.0 : -45.0;
    final center = Vector2(size.x / 2, size.y / 2);

    sp.add(SequenceEffect([
      MoveByEffect(Vector2(dir, -22),
          EffectController(duration: 0.18, curve: Curves.easeOut)),
      MoveByEffect(Vector2(dir * 0.4, 22),
          EffectController(duration: 0.14, curve: Curves.easeIn)),
      MoveByEffect(Vector2(-(dir * 1.4), 0),
          EffectController(duration: 0.30, curve: Curves.easeIn)),
      MoveToEffect(center, EffectController(duration: 0.06)),
    ], onComplete: () {
      sp.position = center;
      _idle = true;
    }));
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

  void playBuffPulse() {
    final sp = _sprite;
    if (sp == null) return;
    _idle = false;
    sp.removeWhere((c) => c is Effect);
    sp.add(SequenceEffect([
      ScaleEffect.to(Vector2.all(1.08), EffectController(duration: 0.14, curve: Curves.easeOut)),
      ScaleEffect.to(Vector2.all(1.0), EffectController(duration: 0.2, curve: Curves.easeIn)),
    ], onComplete: () => _idle = true));
  }

  void playDebuffShake() {
    final sp = _sprite;
    if (sp == null) return;
    _idle = false;
    sp.removeWhere((c) => c is Effect);
    sp.add(SequenceEffect([
      MoveByEffect(Vector2(-10, 0), EffectController(duration: 0.06)),
      MoveByEffect(Vector2(10, 0), EffectController(duration: 0.06)),
      MoveByEffect(Vector2(-6, 0), EffectController(duration: 0.05)),
      MoveByEffect(Vector2(6, 0), EffectController(duration: 0.05)),
    ], onComplete: () => _idle = true));
  }

  void playHealRise() {
    final sp = _sprite;
    if (sp == null) return;
    _idle = false;
    sp.removeWhere((c) => c is Effect);
    sp.add(SequenceEffect([
      MoveByEffect(Vector2(0, -12), EffectController(duration: 0.16, curve: Curves.easeOut)),
      MoveByEffect(Vector2(0, 12), EffectController(duration: 0.2, curve: Curves.easeIn)),
    ], onComplete: () => _idle = true));
  }

  void playShieldBrace() {
    final sp = _sprite;
    if (sp == null) return;
    _idle = false;
    sp.removeWhere((c) => c is Effect);
    sp.add(SequenceEffect([
      ScaleEffect.to(Vector2(0.94, 1.06), EffectController(duration: 0.12, curve: Curves.easeOut)),
      ScaleEffect.to(Vector2.all(1.0), EffectController(duration: 0.16, curve: Curves.easeIn)),
    ], onComplete: () => _idle = true));
  }
}

// ── Widget ────────────────────────────────────────────────────────────────────

class PetCharacterWidget extends StatefulWidget {
  final PetCharacterConfig    config;
  final PetCharacterAnimState animState;
  final double                size;
  final bool                  flipHorizontal;
  /// When set and [animState] is an attack variant, picks the slot-specific
  /// Spine animation instead of the generic attack clips.
  /// Values: 'horn' | 'back' | 'tail' | 'mouth'
  final String?               attackSlot;

  const PetCharacterWidget({
    super.key,
    required this.config,
    required this.size,
    this.animState      = PetCharacterAnimState.idle,
    this.flipHorizontal = false,
    this.attackSlot,
  });

  @override
  State<PetCharacterWidget> createState() => _PetCharacterWidgetState();
}

class _PetCharacterWidgetState extends State<PetCharacterWidget> {
  late _CharacterGame _game;
  late SpineWidgetController _spineController;

  bool _spineReady = false;

  @override
  void initState() {
    super.initState();
    _game = _CharacterGame(texturePath: widget.config.texturePath);
    // spine_flutter uses native FFI — not available on web.
    if (!kIsWeb) _initSpineController();
  }

  @override
  void didUpdateWidget(PetCharacterWidget old) {
    super.didUpdateWidget(old);

    if (!kIsWeb) {
      if (old.config.spineAtlasPath != widget.config.spineAtlasPath ||
          old.config.spineSkeletonPath != widget.config.spineSkeletonPath) {
        _spineReady = false;
        _initSpineController();
      }
    }

    if (old.animState == widget.animState) return;

    if (!kIsWeb && _spineReady && widget.config.hasSpine) {
      _playSpineState(widget.animState);
      return;
    }

    switch (widget.animState) {
      case PetCharacterAnimState.move:
        _game.playMove(isPlayer: widget.flipHorizontal);
      case PetCharacterAnimState.attack:
      case PetCharacterAnimState.attackMelee:
      case PetCharacterAnimState.attackRanged:
        _game.playAttack(isPlayer: widget.flipHorizontal);
      case PetCharacterAnimState.hit:
        _game.playHit();
      case PetCharacterAnimState.buff:
        _game.playBuffPulse();
      case PetCharacterAnimState.debuff:
        _game.playDebuffShake();
      case PetCharacterAnimState.heal:
        _game.playHealRise();
      case PetCharacterAnimState.shield:
        _game.playShieldBrace();
      case PetCharacterAnimState.idle:
      case PetCharacterAnimState.faint:
        break;
    }
  }

  void _initSpineController() {
    _spineController = SpineWidgetController(
      onInitialized: (controller) {
        if (!mounted) return;
        _spineReady = true;

        // AxieMixerPlayground.cs: hide the Spine built-in ground shadow —
        // we render our own Flutter shadow under each pet.
        try {
          controller.skeleton.findSlot('shadow')?.pose.attachment = null;
        } catch (_) {}

        // AutoBlendAnimController equivalent: 200 ms crossfade between all clips.
        try {
          controller.animationState.data.defaultMix = 0.2;
        } catch (_) {}

        _playSpineState(widget.animState);
        setState(() {});
      },
    );
  }

  void _playSpineState(PetCharacterAnimState state) {
    final clips = _clipsForState(state);
    final selected = _firstExistingClip(clips);
    final idleClip = _firstExistingClip(_kIdleClips);
    if (selected == null) return;

    final isIdleState = state == PetCharacterAnimState.idle;

    // Unity AxieFigure.cs: idle at 0.5× timeScale, all combat at 1.0×.
    _spineController.animationState.timeScale = isIdleState ? 0.5 : 1.0;

    _spineController.animationState.setAnimation(0, selected, isIdleState);

    // After any non-idle animation finishes, queue idle at 0.5× (SpineEndHandler equivalent).
    if (!isIdleState && idleClip != null) {
      final idleEntry = _spineController.animationState.addAnimation(0, idleClip, true, 0);
      idleEntry.timeScale = 0.5;
    }
  }

  List<String> _clipsForState(PetCharacterAnimState state) {
    // If an attack slot is specified, use its specific animation candidates.
    final slot = widget.attackSlot;
    if (slot != null) {
      final isAttack = state == PetCharacterAnimState.attack ||
          state == PetCharacterAnimState.attackMelee ||
          state == PetCharacterAnimState.attackRanged;
      if (isAttack) {
        return _kSlotAttackClips[slot] ?? _kAttackClips;
      }
    }
    return switch (state) {
      PetCharacterAnimState.move         => _kMoveClips,
      PetCharacterAnimState.attackMelee  => _kAttackMeleeClips,
      PetCharacterAnimState.attackRanged => _kAttackRangedClips,
      PetCharacterAnimState.attack       => _kAttackClips,
      PetCharacterAnimState.hit          => _kHitClips,
      PetCharacterAnimState.buff         => _kBuffClips,
      PetCharacterAnimState.debuff       => _kDebuffClips,
      PetCharacterAnimState.heal         => _kHealClips,
      PetCharacterAnimState.shield       => _kShieldClips,
      PetCharacterAnimState.faint        => _kFaintClips,
      PetCharacterAnimState.idle         => _kIdleClips,
    };
  }

  String? _firstExistingClip(List<String> candidates) {
    for (final clip in candidates) {
      if (_spineController.skeletonData.findAnimation(clip) != null) {
        return clip;
      }
    }
    return null;
  }

  @override
  void dispose() {
    _game.onRemove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget child;
    // spine_flutter FFI bindings are not available on web — always use the
    // Flame game fallback on that platform.
    if (!kIsWeb && widget.config.hasSpine) {
      final spine = SpineWidget.fromAsset(
        widget.config.spineAtlasPath!,
        widget.config.spineSkeletonPath!,
        _spineController,
        fit: BoxFit.contain,
      );

      child = Stack(
        fit: StackFit.expand,
        children: [
          if (!_spineReady) GameWidget(game: _game),
          spine,
        ],
      );
    } else {
      child = GameWidget(game: _game);
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

// Idle — 0.5× timescale (AxieFigure.cs Awake)
const _kIdleClips = <String>[
  'action/idle/normal',
  'action/idle/balance',
  'action/idle',
  'idle',
];

// Move-forward hop (AxieFigure.cs DoJumpAnim)
const _kMoveClips = <String>[
  'action/move-forward',
];

// Melee attack (AxieFigure.cs DoAttackMeleeAnim)
const _kAttackMeleeClips = <String>[
  'attack/melee/tail-roll',
  'attack/melee/normal-attack',
];

// Ranged attack (AxieFigure.cs DoAttackRangedAnim)
const _kAttackRangedClips = <String>[
  'attack/ranged/tail-roll',
  'attack/ranged/cast-fly',
  'attack/ranged/normal-attack',
];

// Generic attack — tries melee then ranged
const _kAttackClips = <String>[
  'attack/melee/tail-roll',
  'attack/melee/normal-attack',
  'attack/ranged/tail-roll',
  'attack/ranged/cast-fly',
];

// Hit — incoming damage
const _kHitClips = <String>[
  'defense/hit-by-ranged-attack',
  'hit',
];

// Buff (AxieFigure.cs DoBuffAnim)
const _kBuffClips = <String>[
  'battle/get-buff',
  'last-stand/battle/get-buff',
];

// Debuff
const _kDebuffClips = <String>[
  'battle/get-debuff',
  'last-stand/battle/get-debuff',
];

// Heal — reuses get-buff (AxieFigure.cs DoHealAnim)
const _kHealClips = <String>[
  'battle/get-buff',
  'last-stand/battle/get-buff',
];

// Shield (AxieFigure.cs DoShieldAnim)
const _kShieldClips = <String>[
  'defense/hit-with-shield',
  'battle/get-buff',
];

// Faint / KO
const _kFaintClips = <String>[
  'battle/ko',
  'action/idle/normal',
];

// Slot-specific attack clips (used when attackSlot is provided)
const _kSlotAttackClips = <String, List<String>>{
  'horn': [
    'attack/melee/horn-gore',
    'attack/melee/normal-attack',
  ],
  'mouth': [
    'attack/melee/mouth-bite',
    'attack/melee/normal-attack',
  ],
  'tail': [
    'attack/melee/tail-smash',
    'attack/melee/tail-roll',
    'attack/melee/tail-thrash',
    'attack/melee/tail-multi-slap',
    'attack/melee/normal-attack',
  ],
  'back': [
    'attack/ranged/cast-high',
    'attack/ranged/cast-fly',
    'attack/ranged/cast-low',
    'attack/ranged/cast-multi',
  ],
};
