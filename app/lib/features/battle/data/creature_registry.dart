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
  final String partType; // 'horn' | 'back' | 'tail' | 'mouth'
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
  Trait buildTrait() {
    final base = _factory().withPartClass(partClass);
    final cardId = cardArtPath.split('/').last.replaceAll('.png', '');
    return TraitLibrary.withClassicCardStats(
      baseTrait: base,
      traitId: id,
      cardId: cardId,
    );
  }
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
  String get className => body.bodyClass.name;
  PetCharacterConfig get spineConfig => body.spineConfig;
  PetSpriteConfig? get spriteConfig => body.spriteConfig;

  List<PartDefinition> get parts => [horn, back, tail, mouth];

  Map<String, String> get partCardArt => {
        'horn': horn.cardArtPath,
        'back': back.cardArtPath,
        'tail': tail.cardArtPath,
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
      hp += bonus.hp;
      spd += bonus.speed;
      skl += bonus.skill;
      mor += bonus.morale;
    }
    return (hp: hp, speed: spd, skill: skl, morale: mor);
  }

  /// Build a fresh Pet — call once per battle, never share between sessions.
  /// [displayName] overrides the default creature name (e.g., for player-named pets).
  Pet toPet({String? displayName}) {
    final s = computedStats;
    return Pet(
      id: id,
      name: displayName ?? name,
      creatureClass: bodyClass,
      maxHp: s.hp,
      speed: s.speed,
      morale: s.morale,
      skill: s.skill,
      traits: parts.map((p) => p.buildTrait()).toList(),
    );
  }
}

// ── Card art path helper ──────────────────────────────────────────────────────

String _card(String cls, String part, String variant) =>
    'assets/images/part-cards/$cls-$part-$variant.png';

// ═══════════════════════════════════════════════════════════════════════════════
// BODY CATALOGUE
// One entry per Spine-animated character variant.
// The body determines visuals + body-class base stats only.
// ═══════════════════════════════════════════════════════════════════════════════

final Map<String, BodyDefinition> kBodyCatalogue = {
  'plant_1': BodyDefinition(
    id: 'plant_1',
    name: 'Treant',
    bodyClass: CreatureClass.plant,
    spineConfig: const PetCharacterConfig(
      texturePath: 'assets/sprites/plant_full.png',
      spineAtlasPath: 'assets/spines/plant/04-ena-plant.atlas',
      spineSkeletonPath: 'assets/spines/plant/04-ena-plant.json',
    ),
    spriteConfig: PetSpriteConfig(
        idle: PetAnimConfig(
            sheetFile: 'plant.png',
            frameSize: Vector2(64, 64),
            frameCount: 1,
            stepTime: 1.0)),
  ),
  'aquatic_1': BodyDefinition(
    id: 'aquatic_1',
    name: 'Puffy',
    bodyClass: CreatureClass.aquatic,
    spineConfig: const PetCharacterConfig(
      texturePath: 'assets/sprites/aquatic_full.png',
      spineAtlasPath: 'assets/spines/aquatic/03-puffy-aquatic.atlas',
      spineSkeletonPath: 'assets/spines/aquatic/03-puffy-aquatic.json',
    ),
    spriteConfig: PetSpriteConfig(
        idle: PetAnimConfig(
            sheetFile: 'aquatic.png',
            frameSize: Vector2(64, 64),
            frameCount: 1,
            stepTime: 1.0)),
  ),
  'beast_1': BodyDefinition(
    id: 'beast_1',
    name: 'Buba',
    bodyClass: CreatureClass.beast,
    spineConfig: const PetCharacterConfig(
      texturePath: 'assets/sprites/beast_full.png',
      spineAtlasPath: 'assets/spines/beast/buba.atlas',
      spineSkeletonPath: 'assets/spines/beast/buba.json',
    ),
    spriteConfig: PetSpriteConfig(
        idle: PetAnimConfig(
            sheetFile: 'beast.png',
            frameSize: Vector2(64, 64),
            frameCount: 1,
            stepTime: 1.0)),
  ),
  'reptile_1': BodyDefinition(
    id: 'reptile_1',
    name: 'Kida',
    bodyClass: CreatureClass.reptile,
    spineConfig: const PetCharacterConfig(
      texturePath: 'assets/sprites/reptile_full.png',
      spineAtlasPath: 'assets/spines/reptile/08-machito-reptile.atlas',
      spineSkeletonPath: 'assets/spines/reptile/08-machito-reptile.json',
    ),
    spriteConfig: PetSpriteConfig(
        idle: PetAnimConfig(
            sheetFile: 'reptile.png',
            frameSize: Vector2(64, 64),
            frameCount: 1,
            stepTime: 1.0)),
  ),
  'bird_1': BodyDefinition(
    id: 'bird_1',
    name: 'Momo',
    bodyClass: CreatureClass.bird,
    spineConfig: const PetCharacterConfig(
      texturePath: 'assets/sprites/bird_full.png',
      spineAtlasPath: 'assets/spines/bird/12-momo-bird.atlas',
      spineSkeletonPath: 'assets/spines/bird/12-momo-bird.json',
    ),
    spriteConfig: PetSpriteConfig(
        idle: PetAnimConfig(
            sheetFile: 'bird.png',
            frameSize: Vector2(64, 64),
            frameCount: 1,
            stepTime: 1.0)),
  ),
  'bug_1': BodyDefinition(
    id: 'bug_1',
    name: 'Plum',
    bodyClass: CreatureClass.bug,
    spineConfig: const PetCharacterConfig(
      texturePath: 'assets/sprites/bug_full.png',
      spineAtlasPath: 'assets/spines/bug/06-pomodoro-bug.atlas',
      spineSkeletonPath: 'assets/spines/bug/06-pomodoro-bug.json',
    ),
    spriteConfig: PetSpriteConfig(
        idle: PetAnimConfig(
            sheetFile: 'bug.png',
            frameSize: Vector2(64, 64),
            frameCount: 1,
            stepTime: 1.0)),
  ),
};

// ═══════════════════════════════════════════════════════════════════════════════
// PARTS CATALOGUE  (programmatically generated — 132 entries)
//
// Key format: {class}_{slot}_{variant}  e.g. 'beast_horn_04'
//
// Horn/Back/Tail — 6 variants: 02 04 06 08 10 12  (all in local atlas + card art)
// Mouth          — 4 variants: 02 04 08 10         (card art availability)
//
// Traits tier:
//   Variants 02/04 → tier-1 base trait
//   Variants 06/08/10/12 → tier-2 trait (horn + back have tier-2; tail + mouth reuse tier-1)
// ═══════════════════════════════════════════════════════════════════════════════

// Available variants per slot (matching local card art and atlas)
const _kHornBackTailVariants = ['02', '04', '06', '08', '10', '12'];
const _kMouthVariants = ['02', '04', '08', '10'];

// Map (class, slot, variant) → trait factory
Trait Function() _traitFor(CreatureClass cls, String slot, String v) {
  final tier2 = ['06', '08', '10', '12'].contains(v);
  if (slot == 'horn')
    return switch (cls) {
      CreatureClass.beast =>
        tier2 ? () => TraitLibrary.beastHorn2 : () => TraitLibrary.beastHorn,
      CreatureClass.plant =>
        tier2 ? () => TraitLibrary.plantHorn2 : () => TraitLibrary.plantHorn,
      CreatureClass.aquatic => tier2
          ? () => TraitLibrary.aquaticHorn2
          : () => TraitLibrary.aquaticHorn,
      CreatureClass.bird =>
        tier2 ? () => TraitLibrary.birdHorn2 : () => TraitLibrary.birdHorn,
      CreatureClass.bug =>
        tier2 ? () => TraitLibrary.bugHorn2 : () => TraitLibrary.bugHorn,
      CreatureClass.reptile => tier2
          ? () => TraitLibrary.reptileHorn2
          : () => TraitLibrary.reptileHorn,
    };
  if (slot == 'back')
    return switch (cls) {
      CreatureClass.beast =>
        tier2 ? () => TraitLibrary.beastBack2 : () => TraitLibrary.beastBack,
      CreatureClass.plant =>
        tier2 ? () => TraitLibrary.plantBack2 : () => TraitLibrary.plantBack,
      CreatureClass.aquatic => tier2
          ? () => TraitLibrary.aquaticBack2
          : () => TraitLibrary.aquaticBack,
      CreatureClass.bird =>
        tier2 ? () => TraitLibrary.birdBack2 : () => TraitLibrary.birdBack,
      CreatureClass.bug =>
        tier2 ? () => TraitLibrary.bugBack2 : () => TraitLibrary.bugBack,
      CreatureClass.reptile => tier2
          ? () => TraitLibrary.reptileBack2
          : () => TraitLibrary.reptileBack,
    };
  if (slot == 'tail')
    return switch (cls) {
      CreatureClass.beast => () => TraitLibrary.beastTail,
      CreatureClass.plant => () => TraitLibrary.plantTail,
      CreatureClass.aquatic => () => TraitLibrary.aquaticTail,
      CreatureClass.bird => () => TraitLibrary.birdTail,
      CreatureClass.bug => () => TraitLibrary.bugTail,
      CreatureClass.reptile => () => TraitLibrary.reptileTail,
    };
  // Mouth variant '02' uses the alternate lifesteal/energy-steal trait for
  // bug and plant; all other variants fall back to the base mouth trait.
  return switch (cls) {
    CreatureClass.beast   => () => TraitLibrary.beastMouth,
    CreatureClass.plant   => v == '02'
        ? () => TraitLibrary.plantMouthVegetalBite  // Vegetal Bite — energy steal
        : () => TraitLibrary.plantMouth,            // Drain Bite — lifesteal
    CreatureClass.aquatic => () => TraitLibrary.aquaticMouth,
    CreatureClass.bird    => () => TraitLibrary.birdMouth,
    CreatureClass.bug     => v == '02'
        ? () => TraitLibrary.bugMouthBloodTaste  // Blood Taste — lifesteal
        : () => TraitLibrary.bugMouth,           // Sunder Claw
    CreatureClass.reptile => () => TraitLibrary.reptileMouth,
  };
}

final Map<String, PartDefinition> kPartCatalogue = Map.fromEntries([
  for (final cls in CreatureClass.values)
    for (final slot in ['horn', 'back', 'tail', 'mouth']) ...[
      for (final v
          in (slot == 'mouth' ? _kMouthVariants : _kHornBackTailVariants))
        MapEntry(
          '${cls.name}_${slot}_$v',
          PartDefinition(
            id: '${cls.name}_${slot}_$v',
            partType: slot,
            partClass: cls,
            cardArtPath: _card(cls.name, slot, v),
            traitFactory: _traitFor(cls, slot, v),
          ),
        ),
    ],
]);

// (legacy hand-written entries removed — replaced by kPartCatalogue generator above)
// ignore: unused_element
final Map<String, PartDefinition> _kPartCatalogueUnused = {
  'beast_horn': PartDefinition(
    id: 'beast_horn', partType: 'horn',
    partClass: CreatureClass.beast,
    cardArtPath: _card('beast', 'horn', '04'),
    traitFactory: () => TraitLibrary.beastHorn, // Nut Crack
  ),
  'beast_back': PartDefinition(
    id: 'beast_back', partType: 'back',
    partClass: CreatureClass.beast,
    cardArtPath: _card('beast', 'back', '04'),
    traitFactory: () => TraitLibrary.beastBack, // Rage
  ),
  'beast_tail': PartDefinition(
    id: 'beast_tail', partType: 'tail',
    partClass: CreatureClass.beast,
    cardArtPath: _card('beast', 'tail', '04'),
    traitFactory: () => TraitLibrary.beastTail, // Sinister Strike
  ),
  'beast_mouth': PartDefinition(
    id: 'beast_mouth', partType: 'mouth',
    partClass: CreatureClass.beast,
    cardArtPath: _card('beast', 'mouth', '04'),
    traitFactory: () => TraitLibrary.beastMouth, // Chomp
  ),

  // ── Plant parts ────────────────────────────────────────────────────────────
  'plant_horn': PartDefinition(
    id: 'plant_horn', partType: 'horn',
    partClass: CreatureClass.plant,
    cardArtPath: _card('plant', 'horn', '04'),
    traitFactory: () => TraitLibrary.plantHorn, // Cactus
  ),
  'plant_back': PartDefinition(
    id: 'plant_back', partType: 'back',
    partClass: CreatureClass.plant,
    cardArtPath: _card('plant', 'back', '04'),
    traitFactory: () => TraitLibrary.plantBack, // Sponge
  ),
  'plant_tail': PartDefinition(
    id: 'plant_tail', partType: 'tail',
    partClass: CreatureClass.plant,
    cardArtPath: _card('plant', 'tail', '04'),
    traitFactory: () => TraitLibrary.plantTail, // Healing Herbs
  ),
  'plant_mouth': PartDefinition(
    id: 'plant_mouth', partType: 'mouth',
    partClass: CreatureClass.plant,
    cardArtPath: _card('plant', 'mouth', '04'),
    traitFactory: () => TraitLibrary.plantMouth, // Serious (0 energy!)
  ),

  // ── Aquatic parts ──────────────────────────────────────────────────────────
  'aquatic_horn': PartDefinition(
    id: 'aquatic_horn', partType: 'horn',
    partClass: CreatureClass.aquatic,
    cardArtPath: _card('aquatic', 'horn', '04'),
    traitFactory: () => TraitLibrary.aquaticHorn, // Angry Lam
  ),
  'aquatic_back': PartDefinition(
    id: 'aquatic_back', partType: 'back',
    partClass: CreatureClass.aquatic,
    cardArtPath: _card('aquatic', 'back', '04'),
    traitFactory: () => TraitLibrary.aquaticBack, // Shelter
  ),
  'aquatic_tail': PartDefinition(
    id: 'aquatic_tail', partType: 'tail',
    partClass: CreatureClass.aquatic,
    cardArtPath: _card('aquatic', 'tail', '04'),
    traitFactory: () => TraitLibrary.aquaticTail, // Swift Escape
  ),
  'aquatic_mouth': PartDefinition(
    id: 'aquatic_mouth', partType: 'mouth',
    partClass: CreatureClass.aquatic,
    cardArtPath: _card('aquatic', 'mouth', '04'),
    traitFactory: () => TraitLibrary.aquaticMouth, // Upstream Swim
  ),

  // ── Bird parts ─────────────────────────────────────────────────────────────
  'bird_horn': PartDefinition(
    id: 'bird_horn', partType: 'horn',
    partClass: CreatureClass.bird,
    cardArtPath: _card('bird', 'horn', '12'),
    traitFactory: () => TraitLibrary.birdHorn, // Eggshell
  ),
  'bird_back': PartDefinition(
    id: 'bird_back', partType: 'back',
    partClass: CreatureClass.bird,
    cardArtPath: _card('bird', 'back', '12'),
    traitFactory: () => TraitLibrary.birdBack, // Feather Lunge
  ),
  'bird_tail': PartDefinition(
    id: 'bird_tail', partType: 'tail',
    partClass: CreatureClass.bird,
    cardArtPath: _card('bird', 'tail', '12'),
    traitFactory: () => TraitLibrary.birdTail, // Pigeon Post
  ),
  'bird_mouth': PartDefinition(
    id: 'bird_mouth', partType: 'mouth',
    partClass: CreatureClass.bird,
    cardArtPath: _card('bird', 'mouth', '10'), // nearest to 12
    traitFactory: () => TraitLibrary.birdMouth, // Peace Treaty
  ),

  // ── Bug parts ──────────────────────────────────────────────────────────────
  'bug_horn': PartDefinition(
    id: 'bug_horn', partType: 'horn',
    partClass: CreatureClass.bug,
    cardArtPath: _card('bug', 'horn', '06'),
    traitFactory: () => TraitLibrary.bugHorn, // Mandible Strike
  ),
  'bug_back': PartDefinition(
    id: 'bug_back', partType: 'back',
    partClass: CreatureClass.bug,
    cardArtPath: _card('bug', 'back', '06'),
    traitFactory: () => TraitLibrary.bugBack, // Sticky Goo
  ),
  'bug_tail': PartDefinition(
    id: 'bug_tail', partType: 'tail',
    partClass: CreatureClass.bug,
    cardArtPath: _card('bug', 'tail', '06'),
    traitFactory: () => TraitLibrary.bugTail, // Venom Spit
  ),
  'bug_mouth': PartDefinition(
    id: 'bug_mouth', partType: 'mouth',
    partClass: CreatureClass.bug,
    cardArtPath: _card('bug', 'mouth', '08'), // nearest to 06
    traitFactory: () => TraitLibrary.bugMouth, // Numbing Lecretion
  ),

  // ── Beast variant parts ────────────────────────────────────────────────────
  'beast_horn_2': PartDefinition(
    id: 'beast_horn_2', partType: 'horn',
    partClass: CreatureClass.beast,
    cardArtPath: _card('beast', 'horn', '06'),
    traitFactory: () => TraitLibrary.beastHorn2, // Merry Legion
  ),
  'beast_back_2': PartDefinition(
    id: 'beast_back_2', partType: 'back',
    partClass: CreatureClass.beast,
    cardArtPath: _card('beast', 'back', '06'),
    traitFactory: () => TraitLibrary.beastBack2, // Nitro Leap
  ),

  // ── Plant variant parts ────────────────────────────────────────────────────
  'plant_horn_2': PartDefinition(
    id: 'plant_horn_2', partType: 'horn',
    partClass: CreatureClass.plant,
    cardArtPath: _card('plant', 'horn', '06'),
    traitFactory: () => TraitLibrary.plantHorn2, // Healing Aroma
  ),
  'plant_back_2': PartDefinition(
    id: 'plant_back_2', partType: 'back',
    partClass: CreatureClass.plant,
    cardArtPath: _card('plant', 'back', '06'),
    traitFactory: () => TraitLibrary.plantBack2, // Cleanse Scent
  ),

  // ── Aquatic variant parts ──────────────────────────────────────────────────
  'aquatic_horn_2': PartDefinition(
    id: 'aquatic_horn_2', partType: 'horn',
    partClass: CreatureClass.aquatic,
    cardArtPath: _card('aquatic', 'horn', '06'),
    traitFactory: () => TraitLibrary.aquaticHorn2, // Clam Slash
  ),
  'aquatic_back_2': PartDefinition(
    id: 'aquatic_back_2', partType: 'back',
    partClass: CreatureClass.aquatic,
    cardArtPath: _card('aquatic', 'back', '06'),
    traitFactory: () => TraitLibrary.aquaticBack2, // Swift Escape
  ),

  // ── Bird variant parts ─────────────────────────────────────────────────────
  'bird_horn_2': PartDefinition(
    id: 'bird_horn_2', partType: 'horn',
    partClass: CreatureClass.bird,
    cardArtPath: _card('bird', 'horn', '10'),
    traitFactory: () => TraitLibrary.birdHorn2, // Air Force One
  ),
  'bird_back_2': PartDefinition(
    id: 'bird_back_2', partType: 'back',
    partClass: CreatureClass.bird,
    cardArtPath: _card('bird', 'back', '10'),
    traitFactory: () => TraitLibrary.birdBack2, // Ill-omened
  ),

  // ── Bug variant parts ──────────────────────────────────────────────────────
  'bug_horn_2': PartDefinition(
    id: 'bug_horn_2', partType: 'horn',
    partClass: CreatureClass.bug,
    cardArtPath: _card('bug', 'horn', '08'),
    traitFactory: () => TraitLibrary.bugHorn2, // Grub Surprise
  ),
  'bug_back_2': PartDefinition(
    id: 'bug_back_2', partType: 'back',
    partClass: CreatureClass.bug,
    cardArtPath: _card('bug', 'back', '08'),
    traitFactory: () => TraitLibrary.bugBack2, // Bug Noise
  ),

  // ── Reptile parts ──────────────────────────────────────────────────────────
  'reptile_horn': PartDefinition(
    id: 'reptile_horn', partType: 'horn',
    partClass: CreatureClass.reptile,
    cardArtPath: _card('reptile', 'horn', '08'),
    traitFactory: () => TraitLibrary.reptileHorn, // Tiny Dino
  ),
  'reptile_back': PartDefinition(
    id: 'reptile_back', partType: 'back',
    partClass: CreatureClass.reptile,
    cardArtPath: _card('reptile', 'back', '08'),
    traitFactory: () => TraitLibrary.reptileBack, // Bone Sail
  ),
  'reptile_tail': PartDefinition(
    id: 'reptile_tail', partType: 'tail',
    partClass: CreatureClass.reptile,
    cardArtPath: _card('reptile', 'tail', '08'),
    traitFactory: () => TraitLibrary.reptileTail, // Scale Regeneration
  ),
  'reptile_mouth': PartDefinition(
    id: 'reptile_mouth', partType: 'mouth',
    partClass: CreatureClass.reptile,
    cardArtPath: _card('reptile', 'mouth', '08'),
    traitFactory: () => TraitLibrary.reptileMouth, // Tiny Catapult
  ),

  // ── Reptile variant parts (legacy — superseded by kPartCatalogue generator) ─
  'reptile_horn_2': PartDefinition(
    id: 'reptile_horn_2', partType: 'horn',
    partClass: CreatureClass.reptile,
    cardArtPath: _card('reptile', 'horn', '10'),
    traitFactory: () => TraitLibrary.reptileHorn2, // Surprise Invasion
  ),
  'reptile_back_2': PartDefinition(
    id: 'reptile_back_2', partType: 'back',
    partClass: CreatureClass.reptile,
    cardArtPath: _card('reptile', 'back', '10'),
    traitFactory: () => TraitLibrary.reptileBack2, // Vine Dagger
  ),
};

// ═══════════════════════════════════════════════════════════════════════════════
// CREATURE REGISTRY — NPC / enemy definitions only
//
// Player pets are NEVER sourced from here — they come from OwnedPet.toCreatureDefinition()
// using the DNA stored in playerProvider.
//
// This registry exists solely for:
//   • Quick-battle enemy team (pve_battle_provider._teamBeta)
//   • PvE stage enemy templates (stage_registry.dart)
//   • Pet info display for non-player pets in battle
// ═══════════════════════════════════════════════════════════════════════════════

P(String id) => kPartCatalogue[id]!; // shorthand
B(String id) => kBodyCatalogue[id]!; // shorthand

final Map<String, CreatureDefinition> kCreatureRegistry = {
  // ── Treant — Plant body, pure-breed ───────────────────────────────────────
  'plant_1': CreatureDefinition(
    id: 'plant_1',
    name: 'Treant',
    body: B('plant_1'),
    horn: P('plant_horn_04'),
    back: P('plant_back_04'),
    tail: P('plant_tail_04'),
    mouth: P('plant_mouth_04'),
  ),

  // ── Puffy — Aquatic body, pure-breed ──────────────────────────────────────
  'aquatic_1': CreatureDefinition(
    id: 'aquatic_1',
    name: 'Puffy',
    body: B('aquatic_1'),
    horn: P('aquatic_horn_04'),
    back: P('aquatic_back_04'),
    tail: P('aquatic_tail_04'),
    mouth: P('aquatic_mouth_04'),
  ),

  // ── Buba — Beast body, pure-breed ─────────────────────────────────────────
  'beast_1': CreatureDefinition(
    id: 'beast_1',
    name: 'Buba',
    body: B('beast_1'),
    horn: P('beast_horn_04'),
    back: P('beast_back_04'),
    tail: P('beast_tail_04'),
    mouth: P('beast_mouth_04'),
  ),

  // ── Kida — Reptile body, pure-breed ───────────────────────────────────────
  'reptile_1': CreatureDefinition(
    id: 'reptile_1',
    name: 'Kida',
    body: B('reptile_1'),
    horn: P('reptile_horn_04'),
    back: P('reptile_back_04'),
    tail: P('reptile_tail_04'),
    mouth: P('reptile_mouth_04'),
  ),

  // ── Momo — Bird body, pure-breed ──────────────────────────────────────────
  'bird_1': CreatureDefinition(
    id: 'bird_1',
    name: 'Momo',
    body: B('bird_1'),
    horn: P('bird_horn_04'),
    back: P('bird_back_04'),
    tail: P('bird_tail_04'),
    mouth: P('bird_mouth_04'),
  ),

  // ── Plum — Bug body, pure-breed ───────────────────────────────────────────
  'bug_1': CreatureDefinition(
    id: 'bug_1',
    name: 'Plum',
    body: B('bug_1'),
    horn: P('bug_horn_04'),
    back: P('bug_back_04'),
    tail: P('bug_tail_04'),
    mouth: P('bug_mouth_04'),
  ),
};
