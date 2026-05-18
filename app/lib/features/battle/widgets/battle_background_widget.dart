import 'dart:math';
import 'package:flutter/material.dart';

const _kNormalBg2 = [
  'assets/images/bg2/battleground-1.jpg',
];

const _kBloodMoonBg2 = [
  'assets/images/bg2/battleground-2.jpg',
  'assets/images/bg2/battleground-3.jpg',
];

class BattleBackgroundWidget extends StatefulWidget {
  final bool isBloodMoon;

  const BattleBackgroundWidget({
    super.key,
    this.isBloodMoon = false,
  });

  @override
  State<BattleBackgroundWidget> createState() => _BattleBackgroundWidgetState();
}

class _BattleBackgroundWidgetState extends State<BattleBackgroundWidget> {
  late String _bgAsset;

  @override
  void initState() {
    super.initState();
    _bgAsset = _pickRandom(widget.isBloodMoon);
  }

  @override
  void didUpdateWidget(covariant BattleBackgroundWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isBloodMoon != widget.isBloodMoon) {
      setState(() {
        _bgAsset = _pickRandom(widget.isBloodMoon);
      });
    }
  }

  String _pickRandom(bool isBloodMoon) {
    final pool = isBloodMoon ? _kBloodMoonBg2 : _kNormalBg2;
    return pool[Random().nextInt(pool.length)];
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 420),
      child: _StaticBattleBackground(
        key: ValueKey(_bgAsset),
        assetPath: _bgAsset,
      ),
    );
  }
}

class _StaticBattleBackground extends StatelessWidget {
  final String assetPath;
  const _StaticBattleBackground({
    super.key,
    required this.assetPath,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      fit: BoxFit.cover,
      alignment: Alignment.center,
    );
  }
}
