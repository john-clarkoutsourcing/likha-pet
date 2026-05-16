import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DeadPetEffect extends StatefulWidget {
  final double size;
  final bool flipHorizontal;

  const DeadPetEffect({
    super.key,
    required this.size,
    this.flipHorizontal = false,
  });

  @override
  State<DeadPetEffect> createState() => _DeadPetEffectState();
}

class _DeadPetEffectState extends State<DeadPetEffect>
    with SingleTickerProviderStateMixin {
  static const _kFrameCount = 10;
  static const _kStepMs = 80;
  static const _kSpritePath = 'assets/images/pet-sub-effect/dead_pet.png';

  late final AnimationController _controller;
  ui.Image? _spriteSheet;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _kFrameCount * _kStepMs),
    )..repeat();
    _loadSpriteSheet();
  }

  Future<void> _loadSpriteSheet() async {
    try {
      final data = await rootBundle.load(_kSpritePath);
      final bytes = data.buffer.asUint8List();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      if (!mounted) return;
      setState(() => _spriteSheet = frame.image);
    } catch (_) {
      // Keep a graceful empty state if asset load fails.
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sheet = _spriteSheet;
    if (sheet == null) {
      return SizedBox(width: widget.size, height: widget.size);
    }

    Widget child = SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, __) {
          final frame = ((_controller.value * _kFrameCount).floor()) % _kFrameCount;
          return CustomPaint(
            size: Size(widget.size, widget.size),
            painter: _DeadPetPainter(sheet: sheet, frame: frame),
          );
        },
      ),
    );

    if (widget.flipHorizontal) {
      child = Transform(
        alignment: Alignment.center,
        transform: Matrix4.diagonal3Values(-1, 1, 1),
        child: child,
      );
    }
    return child;
  }
}

class _DeadPetPainter extends CustomPainter {
  final ui.Image sheet;
  final int frame;

  const _DeadPetPainter({
    required this.sheet,
    required this.frame,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final frameWidth = sheet.width / 10.0;
    final src = Rect.fromLTWH(frame * frameWidth, 0, frameWidth, sheet.height.toDouble());
    final dst = Offset.zero & size;
    canvas.drawImageRect(
      sheet,
      src,
      dst,
      Paint()
        ..isAntiAlias = true
        ..filterQuality = FilterQuality.high,
    );
  }

  @override
  bool shouldRepaint(covariant _DeadPetPainter oldDelegate) =>
      oldDelegate.frame != frame || oldDelegate.sheet != sheet;
}
