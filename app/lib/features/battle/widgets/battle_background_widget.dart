import 'package:flame/components.dart' hide Matrix4;
import 'package:flame/game.dart' hide Matrix4;
import 'package:flame/parallax.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

// Layers ordered back→front. Each subsequent layer moves ~1.35× faster.
// baseVelocity drives the sky (slowest); birds end up at ~10× that speed.
const _kLayers = [
  'bg2/sky.png',
  'bg2/clouds_3.png',
  'bg2/clouds_2.png',
  'bg2/clouds_1.png',
  'bg2/rocks_3.png',
  'bg2/rocks_2.png',
  'bg2/pines.png',
  'bg2/rocks_1.png',
  'bg2/birds.png',
];

class _BackgroundGame extends FlameGame {
  @override
  Future<void> onLoad() async {
    add(await ParallaxComponent.load(
      _kLayers.map(ParallaxImageData.new).toList(),
      baseVelocity:            Vector2(8, 0),
      velocityMultiplierDelta: Vector2(1.35, 1.0),
      alignment: Alignment.bottomCenter,
      fill:      LayerFill.height,
    ));
  }
}

class BattleBackgroundWidget extends StatefulWidget {
  const BattleBackgroundWidget({super.key});

  @override
  State<BattleBackgroundWidget> createState() => _BattleBackgroundWidgetState();
}

class _BattleBackgroundWidgetState extends State<BattleBackgroundWidget> {
  late final _BackgroundGame _game;

  @override
  void initState() {
    super.initState();
    _game = _BackgroundGame();
  }

  @override
  void dispose() {
    _game.onRemove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return const _StaticBattleBackground();
    }
    return GameWidget(game: _game);
  }
}

class _StaticBattleBackground extends StatelessWidget {
  const _StaticBattleBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        for (final layer in _kLayers)
          Image.asset(
            'assets/images/$layer',
            fit: BoxFit.cover,
            alignment: Alignment.bottomCenter,
          ),
      ],
    );
  }
}
