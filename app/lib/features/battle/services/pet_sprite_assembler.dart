import 'package:flutter/material.dart';
import 'package:likha_pet_battle_engine/trait.dart';
import '../data/creature_registry.dart';
import '../widgets/pet_character_widget.dart';
import '../../pets/models/owned_pet.dart' show OwnedPet;

// ── PetPartVisual ─────────────────────────────────────────────────────────────
//
// Visual data for one equipped part slot.

class PetPartVisual {
  final String cardArtPath;
  final Color classColor;
  /// Ordered Spine animation candidates for this slot's attack.
  /// The widget picks the first one that exists in the loaded skeleton.
  final List<String> attackClips;

  const PetPartVisual({
    required this.cardArtPath,
    required this.classColor,
    required this.attackClips,
  });
}

// ── PetVisualData ─────────────────────────────────────────────────────────────
//
// Everything a widget needs to render one pet — spine config, card arts,
// slot attack clips, gene visibility, and computed stats.
// Produced by PetSpriteAssembler; consumed by PetCharacterWidget and pet cards.

class PetVisualData {
  final PetCharacterConfig spineConfig;
  final CreatureClass bodyClass;
  final Color bodyColor;

  /// Keyed by slot: 'horn' | 'back' | 'tail' | 'mouth'
  final Map<String, PetPartVisual> parts;

  final ({int hp, int speed, int skill, int morale}) stats;
  final int purity;  // 0–4: how many parts share the body class
  final String name;

  const PetVisualData({
    required this.spineConfig,
    required this.bodyClass,
    required this.bodyColor,
    required this.parts,
    required this.stats,
    required this.purity,
    required this.name,
  });

  /// Ordered Spine animation candidates for [slot] ('horn'|'back'|'tail'|'mouth').
  /// Returns null if slot is unknown.
  List<String>? attackClipsFor(String slot) => parts[slot]?.attackClips;

  Color colorFor(String slot) => parts[slot]?.classColor ?? bodyColor;
  String cardArtFor(String slot) => parts[slot]?.cardArtPath ?? '';
}

// ── PetSpriteAssembler ────────────────────────────────────────────────────────
//
// Pure mapping layer: OwnedPet / CreatureDefinition → PetVisualData.
// Mirrors the @axieinfinity/mixer pattern: given genetic data, produce
// everything the renderer needs without the renderer having to know the
// asset layout or gene schema.
//
// Usage:
//   final visual = PetSpriteAssembler.fromOwned(ownedPet);
//   final visual = PetSpriteAssembler.fromDef(creatureDef);

class PetSpriteAssembler {
  const PetSpriteAssembler._();

  static PetVisualData fromOwned(OwnedPet pet) =>
      fromDef(pet.toCreatureDefinition());

  static PetVisualData fromDef(CreatureDefinition def) {
    final body  = def.body;
    final stats = def.computedStats;

    PetPartVisual buildPart(String slot, PartDefinition part) {
      return PetPartVisual(
        cardArtPath: part.cardArtPath,
        classColor:  classColor(part.partClass),
        attackClips: attackClipsForSlot(slot),
      );
    }

    final parts = <String, PetPartVisual>{
      'horn':  buildPart('horn',  def.horn),
      'back':  buildPart('back',  def.back),
      'tail':  buildPart('tail',  def.tail),
      'mouth': buildPart('mouth', def.mouth),
    };

    return PetVisualData(
      spineConfig: body.spineConfig,
      bodyClass:   body.bodyClass,
      bodyColor:   classColor(body.bodyClass),
      parts:       parts,
      stats:       stats,
      purity:      _purityFromDef(def),
      name:        def.name,
    );
  }

  // ── Spine animation candidates per slot ───────────────────────────────────
  //
  // Lists are ordered: the widget picks the first clip that exists in the
  // loaded skeleton's animation list (same as _firstExistingClip in the widget).

  static List<String> attackClipsForSlot(String slot) => switch (slot) {
    'horn'  => const [
      'attack/melee/horn-gore',
      'attack/melee/normal-attack',
    ],
    'mouth' => const [
      'attack/melee/mouth-bite',
      'attack/melee/normal-attack',
    ],
    'tail'  => const [
      'attack/melee/tail-smash',
      'attack/melee/tail-roll',
      'attack/melee/tail-thrash',
      'attack/melee/tail-multi-slap',
      'attack/melee/normal-attack',
    ],
    'back'  => const [
      'attack/ranged/cast-high',
      'attack/ranged/cast-fly',
      'attack/ranged/cast-low',
      'attack/ranged/cast-multi',
    ],
    _       => const [
      'attack/melee/normal-attack',
      'attack/ranged/cast-fly',
    ],
  };

  // ── Class colour ──────────────────────────────────────────────────────────

  static Color classColor(CreatureClass cls) => switch (cls) {
    CreatureClass.plant   => const Color(0xFF4CAF50),
    CreatureClass.aquatic => const Color(0xFF29B6F6),
    CreatureClass.beast   => const Color(0xFFFF9800),
    CreatureClass.reptile => const Color(0xFF66BB6A),
    CreatureClass.bird    => const Color(0xFFFF80AB),
    CreatureClass.bug     => const Color(0xFFFF5252),
  };

  // ── Private ───────────────────────────────────────────────────────────────

  static int _purityFromDef(CreatureDefinition def) {
    final cls = def.bodyClass;
    return def.parts.where((p) => p.partClass == cls).length;
  }
}
