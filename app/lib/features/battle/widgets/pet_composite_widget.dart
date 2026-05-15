import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:likha_pet_battle_engine/trait.dart';
import '../data/creature_registry.dart';
import '../../pets/models/owned_pet.dart';

// ── PetCompositeWidget ────────────────────────────────────────────────────────
//
// Renders a pet assembled from its ACTUAL parts — the 4 part card arts
// arranged around a neutral body circle coloured by body class.
//
// This is the honest "assembled from genes" display.  Pre-baked class sprites
// (beast_full.png etc.) are NOT used here because they have horn/tail/back
// baked into the image which conflicts with what the DNA actually says.
//
// Part card arts come from kPartCatalogue[partId].cardArtPath which is derived
// directly from the pet's DNA — so what you see matches the skills shown.
//
// Layout:
//          [Back card]
//    [Horn] ○CLASS○ [Mouth]
//          [Tail card]

class PetCompositeWidget extends StatelessWidget {
  final CreatureDefinition def;
  final double size;
  final bool flipHorizontal;

  const PetCompositeWidget({
    super.key,
    required this.def,
    this.size = 140,
    this.flipHorizontal = false,
  });

  static PetCompositeWidget fromOwned(OwnedPet pet, {double size = 140}) =>
      PetCompositeWidget(def: pet.toCreatureDefinition(), size: size);

  @override
  Widget build(BuildContext context) {
    final w = _build();
    if (!flipHorizontal) return w;
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.diagonal3Values(-1, 1, 1),
      child: w,
    );
  }

  Widget _build() {
    final bodyColor = _clsColor(def.bodyClass);
    final cardSz    = size * 0.32;
    final bodySz    = size * 0.28;
    final pad       = size * 0.06;

    return SizedBox(
      width:  size,
      height: size,
      child: Stack(alignment: Alignment.center, children: [

        // ── Back (top-center) ────────────────────────────────────────────
        Positioned(
          top: 0,
          child: _card(def.back, cardSz),
        ),

        // ── Horn (left) ──────────────────────────────────────────────────
        Positioned(
          left: 0,
          top:  size * 0.3,
          child: _card(def.horn, cardSz),
        ),

        // ── Mouth (right) ────────────────────────────────────────────────
        Positioned(
          right: 0,
          top:   size * 0.3,
          child: _card(def.mouth, cardSz),
        ),

        // ── Tail (bottom-center) ─────────────────────────────────────────
        Positioned(
          bottom: 0,
          child:  _card(def.tail, cardSz),
        ),

        // ── Body class badge (center) ────────────────────────────────────
        Container(
          width:  bodySz,
          height: bodySz,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: bodyColor.withValues(alpha: 0.18),
            border: Border.all(color: bodyColor, width: 2),
            boxShadow: [BoxShadow(
              color: bodyColor.withValues(alpha: 0.45),
              blurRadius: 8, spreadRadius: 1)],
          ),
          child: Center(
            child: Image.asset(
              'assets/images/icons/${def.bodyClass.name}.png',
              width:  bodySz * 0.62,
              height: bodySz * 0.62,
              errorBuilder: (_, __, ___) => Text(
                _clsEmoji(def.bodyClass),
                style: TextStyle(fontSize: bodySz * 0.38)),
            ),
          ),
        ),

        // ── Purity dots (bottom-right corner) ───────────────────────────
        Positioned(
          bottom: pad * 0.3,
          right:  pad * 0.3,
          child: _PurityRow(def: def, dotSize: size * 0.06),
        ),
      ]),
    );
  }

  Widget _card(PartDefinition part, double cardSz) {
    final color = _clsColor(part.partClass);
    return Container(
      width:  cardSz,
      height: cardSz * 1.2,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(cardSz * 0.12),
        border: Border.all(color: color, width: 1.5),
        boxShadow: [BoxShadow(
          color: color.withValues(alpha: 0.4),
          blurRadius: 4, offset: const Offset(0, 2))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        part.cardArtPath,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: color.withValues(alpha: 0.15),
          child: Center(child: Icon(Icons.style,
              color: color, size: cardSz * 0.4)),
        ),
      ),
    );
  }

  static Color _clsColor(CreatureClass c) => switch (c) {
    CreatureClass.plant   => const Color(0xFF4CAF50),
    CreatureClass.aquatic => const Color(0xFF29B6F6),
    CreatureClass.beast   => const Color(0xFFFF9800),
    CreatureClass.reptile => const Color(0xFF66BB6A),
    CreatureClass.bird    => const Color(0xFFFF80AB),
    CreatureClass.bug     => const Color(0xFFFF5252),
  };

  static String _clsEmoji(CreatureClass c) => switch (c) {
    CreatureClass.plant   => '🌿',
    CreatureClass.aquatic => '💧',
    CreatureClass.beast   => '🔥',
    CreatureClass.reptile => '🦎',
    CreatureClass.bird    => '🕊️',
    CreatureClass.bug     => '🐛',
  };
}

// ── Purity row ────────────────────────────────────────────────────────────────

class _PurityRow extends StatelessWidget {
  final CreatureDefinition def;
  final double dotSize;

  const _PurityRow({required this.def, required this.dotSize});

  static Color _clsColor(CreatureClass c) => switch (c) {
    CreatureClass.plant   => const Color(0xFF4CAF50),
    CreatureClass.aquatic => const Color(0xFF29B6F6),
    CreatureClass.beast   => const Color(0xFFFF9800),
    CreatureClass.reptile => const Color(0xFF66BB6A),
    CreatureClass.bird    => const Color(0xFFFF80AB),
    CreatureClass.bug     => const Color(0xFFFF5252),
  };

  @override
  Widget build(BuildContext context) {
    final parts = [def.horn, def.back, def.tail, def.mouth];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: parts.map((p) {
        final color = _clsColor(p.partClass);
        final isPure = p.partClass == def.bodyClass;
        return Container(
          width:  dotSize,
          height: dotSize,
          margin: EdgeInsets.only(left: dotSize * 0.2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: isPure
                ? Border.all(color: Colors.white, width: 1)
                : null,
          ),
        );
      }).toList(),
    );
  }
}

// ── Slim horizontal version for lists ─────────────────────────────────────────

class PetCompositeSlimWidget extends StatelessWidget {
  final CreatureDefinition def;
  final double height;

  const PetCompositeSlimWidget({
    super.key,
    required this.def,
    this.height = 56,
  });

  @override
  Widget build(BuildContext context) {
    final bodyColor = _clsColor(def.bodyClass);
    final cardH     = height;
    final cardW     = cardH * 0.75;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Body class circle
        Container(
          width:  cardH,
          height: cardH,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: bodyColor.withValues(alpha: 0.15),
            border: Border.all(color: bodyColor, width: 1.5),
          ),
          child: Center(
            child: Image.asset(
              'assets/images/icons/${def.bodyClass.name}.png',
              width:  cardH * 0.55,
              height: cardH * 0.55,
              errorBuilder: (_, __, ___) => Text(
                _clsEmoji(def.bodyClass),
                style: TextStyle(fontSize: cardH * 0.30)),
            ),
          ),
        ),
        const SizedBox(width: 6),
        // 4 part cards in a row
        for (final part in [def.horn, def.back, def.tail, def.mouth]) ...[
          _slimCard(part, cardW, cardH),
          const SizedBox(width: 3),
        ],
      ],
    );
  }

  Widget _slimCard(PartDefinition part, double w, double h) {
    final color = _clsColor(part.partClass);
    return Container(
      width: w, height: h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(part.cardArtPath, fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: color.withValues(alpha: 0.15))),
    );
  }

  static Color _clsColor(CreatureClass c) => switch (c) {
    CreatureClass.plant   => const Color(0xFF4CAF50),
    CreatureClass.aquatic => const Color(0xFF29B6F6),
    CreatureClass.beast   => const Color(0xFFFF9800),
    CreatureClass.reptile => const Color(0xFF66BB6A),
    CreatureClass.bird    => const Color(0xFFFF80AB),
    CreatureClass.bug     => const Color(0xFFFF5252),
  };

  static String _clsEmoji(CreatureClass c) => switch (c) {
    CreatureClass.plant   => '🌿',
    CreatureClass.aquatic => '💧',
    CreatureClass.beast   => '🔥',
    CreatureClass.reptile => '🦎',
    CreatureClass.bird    => '🕊️',
    CreatureClass.bug     => '🐛',
  };
}
