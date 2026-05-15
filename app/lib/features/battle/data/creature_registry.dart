import 'package:flame/components.dart' hide Matrix4;
import 'package:likha_pet_battle_engine/pet.dart';
import 'package:likha_pet_battle_engine/trait.dart';
import '../widgets/pet_character_widget.dart';
import '../widgets/pet_sprite_widget.dart';

// ── PartDefinition ────────────────────────────────────────────────────────────
//
// A single body part. It knows:
//   • which slot it occupies (horn / back / tail / mouth)
//   • which class it belongs to (drives stat bonuses + same-class damage bonus)
//   • which card it grants in battle (via traitFactory)
//   • which card-art image to show in the UI
//
// Parts are INDEPENDENT from the creature's body class. Any part can be placed
// on any body, enabling mixed-class builds.

class PartDefinition {
  final String id;
  final String partType;        // 'horn' | 'back' | 'tail' | 'mouth'
  final CreatureClass partClass;
  final String cardArtPath;
  final Trait Function() _factory;

  PartDefinition({
    required this.id,
    required this.partType,
    required this.partClass,
    required this.cardArtPath,
    required Trait Function() traitFactory,
  }) : _factory = traitFactory;

  String get className => partClass.name;

  /// Returns a fresh Trait stamped with this part's class.
  Trait buildTrait() => _factory().withPartClass(partClass);
}

// ── BodyDefinition ────────────────────────────────────────────────────────────
//
// The creature's VISUAL body and body class. The body:
//   • determines the Spine animation shown on the battlefield
//   • sets the base stats (HP / Speed / Skill / Morale) before part bonuses
//   • defines the class advantage/disadvantage for the creature
//
// The body class does NOT lock which parts the creature can use.

class BodyDefinition {
  final String id;
  final String name;
  final CreatureClass bodyClass;
  final PetCharacterConfig spineConfig;
  final PetSpriteConfig? spriteConfig;

  const BodyDefinition({
    required this.id,
    required this.name,
    required this.bodyClass,
    required this.spineConfig,
    this.spriteConfig,
  });

  String get className => bodyClass.name;
}

// ── CreatureDefinition ────────────────────────────────────────────────────────
//
// A specific creature: one body + four freely chosen parts.
// Stats are computed from body-class base + all 4 part-class bonuses.
// Parts may come from any class — pure-breed or hybrid.

class CreatureDefinition {
  final String id;
  final String name;
  final BodyDefinition body;
  final PartDefinition horn;
  final PartDefinition back;
  final PartDefinition tail;
  final PartDefinition mouth;

  CreatureDefinition({
    required this.id,
    required this.name,
    required this.body,
    required this.horn,
    required this.back,
    required this.tail,
    required this.mouth,
  });

  // ── Convenience getters ────────────────────────────────────────────────────

  CreatureClass get bodyClass => body.bodyClass;
  String get className       => body.bodyClass.name;
  PetCharacterConfig get spineConfig  => body.spineConfig;
  PetSpriteConfig?   get spriteConfig => body.spriteConfig;

  List<PartDefinition> get parts => [horn, back, tail, mouth];

  Map<String, String> get partCardArt => {
    'horn':  horn.cardArtPath,
    'back':  back.cardArtPath,
    'tail':  tail.cardArtPath,
    'mouth': mouth.cardArtPath,
  };

  // ── Stats ──────────────────────────────────────────────────────────────────
  //
  // Total stats = body-class base + sum of part-class bonuses.
  // A pure-breed creature maximises its primary stats; a hybrid trades
  // optimisation for card variety.

  ({int hp, int speed, int skill, int morale}) get computedStats {
    final b = bodyClass.baseBodyStats;
    var hp = b.hp, spd = b.speed, skl = b.skill, mor = b.morale;
    for (final p in parts) {
      final bonus = p.partClass.partStatBonus;
      hp += bonus.hp; spd += bonus.speed;
      skl += bonus.skill; mor += bonus.morale;
    }
    return (hp: hp, speed: spd, skill: skl, morale: mor);
  }

  /// Build a fresh Pet — call once per battle, never share between sessions.
  Pet toPet() {
    final s = computedStats;
    return Pet(
      id:            id,
      name:          name,
      creatureClass: bodyClass,
      maxHp:         s.hp,
      speed:         s.speed,
      morale:        s.morale,
      skill:         s.skill,
      traits:        parts.map((p) => p.buildTrait()).toList(),
    );
  }
}

// ── Card art path helper ──────────────────────────────────────────────────────

String _card(String cls, String part, String variant) =>
    'assets/images/cards/$cls-$part-$variant.png';

// ═══════════════════════════════════════════════════════════════════════════════
// BODY CATALOGUE
// One entry per Spine-animated character variant.
// The body determines visuals + body-class base stats only.
// ═══════════════════════════════════════════════════════════════════════════════

final Map<String, BodyDefinition> kBodyCatalogue = {

  'plant_1': BodyDefinition(
    id: 'plant_1', name: 'Treant',
    bodyClass: CreatureClass.plant,
    spineConfig: const PetCharacterConfig(
      texturePath:       'assets/sprites/plant_full.png',
      spineAtlasPath:    'assets/spines/plant/04-ena-plant.atlas',
      spineSkeletonPath: 'assets/spines/plant/04-ena-plant.json',
    ),
    spriteConfig: PetSpriteConfig(
      idle: PetAnimConfig(sheetFile: 'plant.png',
          frameSize: Vector2(64, 64), frameCount: 1, stepTime: 1.0)),
  ),

  'aquatic_1': BodyDefinition(
    id: 'aquatic_1', name: 'Puffy',
    bodyClass: CreatureClass.aquatic,
    spineConfig: const PetCharacterConfig(
      texturePath:       'assets/sprites/aquatic_full.png',
      spineAtlasPath:    'assets/spines/aquatic/03-puffy-aquatic.atlas',
      spineSkeletonPath: 'assets/spines/aquatic/03-puffy-aquatic.json',
    ),
    spriteConfig: PetSpriteConfig(
      idle: PetAnimConfig(sheetFile: 'aquatic.png',
          frameSize: Vector2(64, 64), frameCount: 1, stepTime: 1.0)),
  ),

  'beast_1': BodyDefinition(
    id: 'beast_1', name: 'Buba',
    bodyClass: CreatureClass.beast,
    spineConfig: const PetCharacterConfig(
      texturePath:       'assets/sprites/beast_full.png',
      spineAtlasPath:    'assets/spines/beast/05-dps-beast.atlas',
      spineSkeletonPath: 'assets/spines/beast/05-dps-beast.json',
    ),
    spriteConfig: PetSpriteConfig(
      idle: PetAnimConfig(sheetFile: 'beast.png',
          frameSize: Vector2(64, 64), frameCount: 1, stepTime: 1.0)),
  ),

  'reptile_1': BodyDefinition(
    id: 'reptile_1', name: 'Kida',
    bodyClass: CreatureClass.reptile,
    spineConfig: const PetCharacterConfig(
      texturePath:       'assets/sprites/reptile_full.png',
      spineAtlasPath:    'assets/spines/reptile/08-machito-reptile.atlas',
      spineSkeletonPath: 'assets/spines/reptile/08-machito-reptile.json',
    ),
    spriteConfig: PetSpriteConfig(
      idle: PetAnimConfig(sheetFile: 'reptile.png',
          frameSize: Vector2(64, 64), frameCount: 1, stepTime: 1.0)),
  ),

  'bird_1': BodyDefinition(
    id: 'bird_1', name: 'Momo',
    bodyClass: CreatureClass.bird,
    spineConfig: const PetCharacterConfig(
      texturePath:       'assets/sprites/bird_full.png',
      spineAtlasPath:    'assets/spines/bird/12-momo-bird.atlas',
      spineSkeletonPath: 'assets/spines/bird/12-momo-bird.json',
    ),
    spriteConfig: PetSpriteConfig(
      idle: PetAnimConfig(sheetFile: 'bird.png',
          frameSize: Vector2(64, 64), frameCount: 1, stepTime: 1.0)),
  ),

  'bug_1': BodyDefinition(
    id: 'bug_1', name: 'Plum',
    bodyClass: CreatureClass.bug,
    spineConfig: const PetCharacterConfig(
      texturePath:       'assets/sprites/bug_full.png',
      spineAtlasPath:    'assets/spines/bug/06-pomodoro-bug.atlas',
      spineSkeletonPath: 'assets/spines/bug/06-pomodoro-bug.json',
    ),
    spriteConfig: PetSpriteConfig(
      idle: PetAnimConfig(sheetFile: 'bug.png',
          frameSize: Vector2(64, 64), frameCount: 1, stepTime: 1.0)),
  ),
};

// ═══════════════════════════════════════════════════════════════════════════════
// PARTS CATALOGUE
// All 24 available parts (6 classes × 4 slots).
// Any part can be equipped on any body — class mixing is intentional.
//
// Card-art variant numbers derived from Spine skeleton names:
//   04-ena-plant → 04  |  03-puffy-aquatic → 04 (nearest)
//   05-dps-beast → 04 (nearest) |  08-machito-reptile → 08
//   12-momo-bird → 12  |  06-pomodoro-bug → 06
// ═══════════════════════════════════════════════════════════════════════════════

final Map<String, PartDefinition> kPartCatalogue = {

  // ── Beast parts ────────────────────────────────────────────────────────────
  'beast_horn': PartDefinition(
    id: 'beast_horn', partType: 'horn',
    partClass: CreatureClass.beast,
    cardArtPath: _card('beast', 'horn', '04'),
    traitFactory: () => TraitLibrary.beastHorn,           // Nut Crack
  ),
  'beast_back': PartDefinition(
    id: 'beast_back', partType: 'back',
    partClass: CreatureClass.beast,
    cardArtPath: _card('beast', 'back', '04'),
    traitFactory: () => TraitLibrary.beastBack,           // Rage
  ),
  'beast_tail': PartDefinition(
    id: 'beast_tail', partType: 'tail',
    partClass: CreatureClass.beast,
    cardArtPath: _card('beast', 'tail', '04'),
    traitFactory: () => TraitLibrary.beastTail,           // Sinister Strike
  ),
  'beast_mouth': PartDefinition(
    id: 'beast_mouth', partType: 'mouth',
    partClass: CreatureClass.beast,
    cardArtPath: _card('beast', 'mouth', '04'),
    traitFactory: () => TraitLibrary.beastMouth,          // Chomp
  ),

  // ── Plant parts ────────────────────────────────────────────────────────────
  'plant_horn': PartDefinition(
    id: 'plant_horn', partType: 'horn',
    partClass: CreatureClass.plant,
    cardArtPath: _card('plant', 'horn', '04'),
    traitFactory: () => TraitLibrary.plantHorn,           // Cactus
  ),
  'plant_back': PartDefinition(
    id: 'plant_back', partType: 'back',
    partClass: CreatureClass.plant,
    cardArtPath: _card('plant', 'back', '04'),
    traitFactory: () => TraitLibrary.plantBack,           // Sponge
  ),
  'plant_tail': PartDefinition(
    id: 'plant_tail', partType: 'tail',
    partClass: CreatureClass.plant,
    cardArtPath: _card('plant', 'tail', '04'),
    traitFactory: () => TraitLibrary.plantTail,           // Healing Herbs
  ),
  'plant_mouth': PartDefinition(
    id: 'plant_mouth', partType: 'mouth',
    partClass: CreatureClass.plant,
    cardArtPath: _card('plant', 'mouth', '04'),
    traitFactory: () => TraitLibrary.plantMouth,          // Serious (0 energy!)
  ),

  // ── Aquatic parts ──────────────────────────────────────────────────────────
  'aquatic_horn': PartDefinition(
    id: 'aquatic_horn', partType: 'horn',
    partClass: CreatureClass.aquatic,
    cardArtPath: _card('aquatic', 'horn', '04'),
    traitFactory: () => TraitLibrary.aquaticHorn,         // Angry Lam
  ),
  'aquatic_back': PartDefinition(
    id: 'aquatic_back', partType: 'back',
    partClass: CreatureClass.aquatic,
    cardArtPath: _card('aquatic', 'back', '04'),
    traitFactory: () => TraitLibrary.aquaticBack,         // Shelter
  ),
  'aquatic_tail': PartDefinition(
    id: 'aquatic_tail', partType: 'tail',
    partClass: CreatureClass.aquatic,
    cardArtPath: _card('aquatic', 'tail', '04'),
    traitFactory: () => TraitLibrary.aquaticTail,         // Swift Escape
  ),
  'aquatic_mouth': PartDefinition(
    id: 'aquatic_mouth', partType: 'mouth',
    partClass: CreatureClass.aquatic,
    cardArtPath: _card('aquatic', 'mouth', '04'),
    traitFactory: () => TraitLibrary.aquaticMouth,        // Upstream Swim
  ),

  // ── Bird parts ─────────────────────────────────────────────────────────────
  'bird_horn': PartDefinition(
    id: 'bird_horn', partType: 'horn',
    partClass: CreatureClass.bird,
    cardArtPath: _card('bird', 'horn', '12'),
    traitFactory: () => TraitLibrary.birdHorn,            // Eggshell
  ),
  'bird_back': PartDefinition(
    id: 'bird_back', partType: 'back',
    partClass: CreatureClass.bird,
    cardArtPath: _card('bird', 'back', '12'),
    traitFactory: () => TraitLibrary.birdBack,            // Feather Lunge
  ),
  'bird_tail': PartDefinition(
    id: 'bird_tail', partType: 'tail',
    partClass: CreatureClass.bird,
    cardArtPath: _card('bird', 'tail', '12'),
    traitFactory: () => TraitLibrary.birdTail,            // Pigeon Post
  ),
  'bird_mouth': PartDefinition(
    id: 'bird_mouth', partType: 'mouth',
    partClass: CreatureClass.bird,
    cardArtPath: _card('bird', 'mouth', '10'),            // nearest to 12
    traitFactory: () => TraitLibrary.birdMouth,           // Peace Treaty
  ),

  // ── Bug parts ──────────────────────────────────────────────────────────────
  'bug_horn': PartDefinition(
    id: 'bug_horn', partType: 'horn',
    partClass: CreatureClass.bug,
    cardArtPath: _card('bug', 'horn', '06'),
    traitFactory: () => TraitLibrary.bugHorn,             // Mandible Strike
  ),
  'bug_back': PartDefinition(
    id: 'bug_back', partType: 'back',
    partClass: CreatureClass.bug,
    cardArtPath: _card('bug', 'back', '06'),
    traitFactory: () => TraitLibrary.bugBack,             // Sticky Goo
  ),
  'bug_tail': PartDefinition(
    id: 'bug_tail', partType: 'tail',
    partClass: CreatureClass.bug,
    cardArtPath: _card('bug', 'tail', '06'),
    traitFactory: () => TraitLibrary.bugTail,             // Venom Spit
  ),
  'bug_mouth': PartDefinition(
    id: 'bug_mouth', partType: 'mouth',
    partClass: CreatureClass.bug,
    cardArtPath: _card('bug', 'mouth', '08'),             // nearest to 06
    traitFactory: () => TraitLibrary.bugMouth,            // Numbing Lecretion
  ),

  // ── Reptile parts ──────────────────────────────────────────────────────────
  'reptile_horn': PartDefinition(
    id: 'reptile_horn', partType: 'horn',
    partClass: CreatureClass.reptile,
    cardArtPath: _card('reptile', 'horn', '08'),
    traitFactory: () => TraitLibrary.reptileHorn,         // Tiny Dino
  ),
  'reptile_back': PartDefinition(
    id: 'reptile_back', partType: 'back',
    partClass: CreatureClass.reptile,
    cardArtPath: _card('reptile', 'back', '08'),
    traitFactory: () => TraitLibrary.reptileBack,         // Bone Sail
  ),
  'reptile_tail': PartDefinition(
    id: 'reptile_tail', partType: 'tail',
    partClass: CreatureClass.reptile,
    cardArtPath: _card('reptile', 'tail', '08'),
    traitFactory: () => TraitLibrary.reptileTail,         // Scale Regeneration
  ),
  'reptile_mouth': PartDefinition(
    id: 'reptile_mouth', partType: 'mouth',
    partClass: CreatureClass.reptile,
    cardArtPath: _card('reptile', 'mouth', '08'),
    traitFactory: () => TraitLibrary.reptileMouth,        // Tiny Catapult
  ),
};

// ═══════════════════════════════════════════════════════════════════════════════
// CREATURE REGISTRY — default pure-breed roster
//
// Each entry is a specific creature: one body + four parts that may be from
// ANY class. The current roster uses pure-breed builds (all parts match body),
// but you can swap any part to any catalogued part to create hybrids.
//
// Example of a hybrid: a Plant body with a Beast horn (Nut Crack) for
// extra burst damage while keeping Plant's defensive back/tail/mouth.
//
// To add a new creature or change a build:
//   1. Pick a body from kBodyCatalogue.
//   2. Pick 4 parts (one per slot) from kPartCatalogue.
//   3. Add the CreatureDefinition here and reference it in the team builder.
// ═══════════════════════════════════════════════════════════════════════════════

P(String id) => kPartCatalogue[id]!;   // shorthand
B(String id) => kBodyCatalogue[id]!;   // shorthand

final Map<String, CreatureDefinition> kCreatureRegistry = {

  // ── Treant — Plant body, pure-breed ───────────────────────────────────────
  'plant_1': CreatureDefinition(
    id: 'plant_1', name: 'Treant',
    body:  B('plant_1'),
    horn:  P('plant_horn'),   // Cactus   — DEF up + 45 shield
    back:  P('plant_back'),   // Sponge   — DEF up + 35 shield
    tail:  P('plant_tail'),   // Healing Herbs — heal ally
    mouth: P('plant_mouth'),  // Serious  — 0-energy free shield
  ),

  // ── Puffy — Aquatic body, pure-breed ──────────────────────────────────────
  'aquatic_1': CreatureDefinition(
    id: 'aquatic_1', name: 'Puffy',
    body:  B('aquatic_1'),
    horn:  P('aquatic_horn'),   // Angry Lam    — pierce back row
    back:  P('aquatic_back'),   // Shelter      — big DEF + shield
    tail:  P('aquatic_tail'),   // Swift Escape — SPD up + shield
    mouth: P('aquatic_mouth'),  // Upstream Swim — stun
  ),

  // ── Buba — Beast body, pure-breed ─────────────────────────────────────────
  'beast_1': CreatureDefinition(
    id: 'beast_1', name: 'Buba',
    body:  B('beast_1'),
    horn:  P('beast_horn'),   // Nut Crack       — 55 dmg
    back:  P('beast_back'),   // Rage            — ATK up + shield
    tail:  P('beast_tail'),   // Sinister Strike — 55 dmg
    mouth: P('beast_mouth'),  // Chomp           — 50 dmg finisher
  ),

  // ── Kida — Reptile body, pure-breed ───────────────────────────────────────
  'reptile_1': CreatureDefinition(
    id: 'reptile_1', name: 'Kida',
    body:  B('reptile_1'),
    horn:  P('reptile_horn'),   // Tiny Dino      — 50 dmg + 25 shield
    back:  P('reptile_back'),   // Bone Sail      — DEF up + 40 shield
    tail:  P('reptile_tail'),   // Scale Regen    — REGEN 20/r for 3r
    mouth: P('reptile_mouth'),  // Tiny Catapult  — pierce + 25 shield
  ),

  // ── Momo — Bird body, pure-breed ──────────────────────────────────────────
  'bird_1': CreatureDefinition(
    id: 'bird_1', name: 'Momo',
    body:  B('bird_1'),
    horn:  P('bird_horn'),   // Eggshell     — ATK up + 40 shield
    back:  P('bird_back'),   // Feather Lunge — 65 dmg (max single hit)
    tail:  P('bird_tail'),   // Pigeon Post   — 50 dmg
    mouth: P('bird_mouth'),  // Peace Treaty  — shield break
  ),

  // ── Plum — Bug body, pure-breed ───────────────────────────────────────────
  'bug_1': CreatureDefinition(
    id: 'bug_1', name: 'Plum',
    body:  B('bug_1'),
    horn:  P('bug_horn'),   // Mandible Strike   — 60 dmg (best 1-energy)
    back:  P('bug_back'),   // Sticky Goo        — slow + 25 shield
    tail:  P('bug_tail'),   // Venom Spit        — poison stack
    mouth: P('bug_mouth'),  // Numbing Lecretion — stun
  ),
};
