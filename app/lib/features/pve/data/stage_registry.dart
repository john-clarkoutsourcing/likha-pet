import 'package:likha_pet_battle_engine/pet.dart';
import '../../battle/data/creature_registry.dart';

// ── StageConfig ───────────────────────────────────────────────────────────────
//
// One PvE stage. The enemy team is defined by a list of CreatureDefinitions
// built from the body/parts catalogues — allowing precise mixed-class builds.

class StageConfig {
  final String id;
  final String name;
  final String description;
  final String emoji;
  final int    crystalReward;
  final int    recommendedPurity; // parts matching body class (0–4 guide)
  final List<CreatureDefinition> enemyDefs;

  const StageConfig({
    required this.id,
    required this.name,
    required this.description,
    required this.emoji,
    required this.crystalReward,
    required this.recommendedPurity,
    required this.enemyDefs,
  });

  List<Pet> buildEnemyTeam() =>
      enemyDefs.map((d) => d.toPet()).toList();

  String get difficultyLabel => switch (recommendedPurity) {
    0 || 1 => 'Beginner',
    2      => 'Easy',
    3      => 'Medium',
    4      => 'Hard',
    _      => 'Expert',
  };
}

// ── Helpers ───────────────────────────────────────────────────────────────────

CreatureDefinition _enemy(
  String bodyId,
  String hornId,
  String backId,
  String tailId,
  String mouthId, {
  String? nameOverride,
}) {
  final body = kBodyCatalogue[bodyId]!;
  return CreatureDefinition(
    id:    '${bodyId}_stage',
    name:  nameOverride ?? body.name,
    body:  body,
    horn:  kPartCatalogue[hornId]!,
    back:  kPartCatalogue[backId]!,
    tail:  kPartCatalogue[tailId]!,
    mouth: kPartCatalogue[mouthId]!,
  );
}

// Pure-breed shorthand
CreatureDefinition _pure(String bodyId, {String? name}) {
  final cls = kBodyCatalogue[bodyId]!.className;
  return _enemy(bodyId, '${cls}_horn', '${cls}_back',
      '${cls}_tail', '${cls}_mouth', nameOverride: name);
}

// ── Stage registry ────────────────────────────────────────────────────────────
//
// 10 stages, difficulty escalating from beginner to expert.
// Enemy teams are handcrafted — later stages exploit class advantages against
// typical player builds (Plant/Aquatic/Beast starters).

final List<StageConfig> kStageRegistry = [

  // ── Stage 1: Starter Meadow ───────────────────────────────────────────────
  StageConfig(
    id: '1',
    name: 'Starter Meadow',
    description: 'Three gentle Plant creatures. Learn the basics.',
    emoji: '🌿',
    crystalReward: 50,
    recommendedPurity: 0,
    enemyDefs: [
      _pure('plant_1', name: 'Sprout'),
      _pure('plant_1', name: 'Petal'),
      _pure('plant_1', name: 'Leafy'),
    ],
  ),

  // ── Stage 2: Blue Lagoon ──────────────────────────────────────────────────
  StageConfig(
    id: '2',
    name: 'Blue Lagoon',
    description: 'Swift Aquatic creatures — watch out for the stun.',
    emoji: '🌊',
    crystalReward: 60,
    recommendedPurity: 1,
    enemyDefs: [
      _pure('aquatic_1', name: 'Ripple'),
      _pure('aquatic_1', name: 'Surge'),
      _pure('aquatic_1', name: 'Crest'),
    ],
  ),

  // ── Stage 3: Beast Den ────────────────────────────────────────────────────
  StageConfig(
    id: '3',
    name: 'Beast Den',
    description: 'Aggressive Beast pack. High damage output every round.',
    emoji: '🐾',
    crystalReward: 70,
    recommendedPurity: 1,
    enemyDefs: [
      _pure('beast_1', name: 'Snarl'),
      _pure('beast_1', name: 'Fang'),
      _pure('beast_1', name: 'Claw'),
    ],
  ),

  // ── Stage 4: Poison Hollow ────────────────────────────────────────────────
  StageConfig(
    id: '4',
    name: 'Poison Hollow',
    description: 'Bug team — all three can stack poison. Kill them fast.',
    emoji: '🐛',
    crystalReward: 80,
    recommendedPurity: 2,
    enemyDefs: [
      _pure('bug_1', name: 'Sting'),
      _pure('bug_1', name: 'Venom'),
      // Bug with aquatic body — faster
      _enemy('aquatic_1', 'bug_horn', 'bug_back', 'bug_tail', 'bug_mouth',
          nameOverride: 'Dart'),
    ],
  ),

  // ── Stage 5: Nest Peak ────────────────────────────────────────────────────
  StageConfig(
    id: '5',
    name: 'Nest Peak',
    description: 'Fast Bird squad. Feather Lunge hits hard; Peace Treaty strips your shield.',
    emoji: '🦅',
    crystalReward: 90,
    recommendedPurity: 2,
    enemyDefs: [
      _pure('bird_1', name: 'Talon'),
      _pure('bird_1', name: 'Swift'),
      // Bird with beast back — even higher single-hit
      _enemy('bird_1', 'bird_horn', 'beast_back', 'bird_tail', 'bird_mouth',
          nameOverride: 'Apex'),
    ],
  ),

  // ── Stage 6: Iron Scale ───────────────────────────────────────────────────
  StageConfig(
    id: '6',
    name: 'Iron Scale',
    description: 'Tanky Reptile trio. Bone Sail + Regen combo — outlast them.',
    emoji: '🦎',
    crystalReward: 100,
    recommendedPurity: 2,
    enemyDefs: [
      _pure('reptile_1', name: 'Scale'),
      _pure('reptile_1', name: 'Shell'),
      // Reptile with plant back (Sponge) — extra DEF
      _enemy('reptile_1', 'reptile_horn', 'plant_back', 'reptile_tail',
          'reptile_mouth', nameOverride: 'Bastion'),
    ],
  ),

  // ── Stage 7: Mixed Fray ───────────────────────────────────────────────────
  StageConfig(
    id: '7',
    name: 'Mixed Fray',
    description: 'A balanced team exploiting class triangles. Watch for advantages.',
    emoji: '⚔️',
    crystalReward: 120,
    recommendedPurity: 3,
    enemyDefs: [
      // Plant body — strong vs your Aquatic
      _pure('plant_1', name: 'Warden'),
      // Beast body — strong vs your Aquatic too, fast attacker
      _enemy('beast_1', 'beast_horn', 'beast_back', 'beast_tail', 'bug_mouth',
          nameOverride: 'Ravager'),
      // Bird body — strong vs your Beast
      _enemy('bird_1', 'bird_back', 'bird_horn', 'aquatic_tail', 'bird_mouth',
          nameOverride: 'Falcon'),
    ],
  ),

  // ── Stage 8: Predator Pack ────────────────────────────────────────────────
  StageConfig(
    id: '8',
    name: 'Predator Pack',
    description: 'Aquatic speed + Bug poison + Reptile tank. Diverse threats every round.',
    emoji: '🌑',
    crystalReward: 140,
    recommendedPurity: 3,
    enemyDefs: [
      // Aquatic with Bug tail (poison + speed)
      _enemy('aquatic_1', 'aquatic_horn', 'aquatic_back', 'bug_tail',
          'aquatic_mouth', nameOverride: 'Viper'),
      // Bug with high damage
      _enemy('bug_1', 'bug_horn', 'bug_back', 'beast_tail', 'bug_mouth',
          nameOverride: 'Crusher'),
      // Reptile with regen + Aquatic stun mouth
      _enemy('reptile_1', 'reptile_horn', 'reptile_back', 'reptile_tail',
          'aquatic_mouth', nameOverride: 'Bulwark'),
    ],
  ),

  // ── Stage 9: Elite Guard ──────────────────────────────────────────────────
  StageConfig(
    id: '9',
    name: 'Elite Guard',
    description: 'Counter-build specialists. They will exploit your weaknesses.',
    emoji: '🗡️',
    crystalReward: 160,
    recommendedPurity: 4,
    enemyDefs: [
      // Plant body with Beast horn (Nut Crack) — has class advantage over Aquatic + burst
      _enemy('plant_1', 'beast_horn', 'plant_back', 'plant_tail', 'plant_mouth',
          nameOverride: 'Thornskull'),
      // Reptile body with Bug tail (poison) + Bird horn (Eggshell)
      _enemy('reptile_1', 'bird_horn', 'reptile_back', 'bug_tail',
          'reptile_mouth', nameOverride: 'Ironvenom'),
      // Bird body with Plant back (Sponge) + free Serious shield
      _enemy('bird_1', 'bird_horn', 'plant_back', 'bird_tail', 'plant_mouth',
          nameOverride: 'Shieldwing'),
    ],
  ),

  // ── Stage 10: Champion's Trial ────────────────────────────────────────────
  StageConfig(
    id: '10',
    name: "Champion's Trial",
    description: 'The ultimate test. Pure-breed optimised builds with full class synergy.',
    emoji: '👑',
    crystalReward: 250,
    recommendedPurity: 4,
    enemyDefs: [
      // Perfect anti-Aquatic Plant tank with Serious mouth (free shield every round)
      _enemy('plant_1', 'plant_horn', 'plant_back', 'plant_tail', 'plant_mouth',
          nameOverride: 'Ancient Oak'),
      // Anti-Beast/Bug Aquatic speed + stun
      _enemy('aquatic_1', 'aquatic_horn', 'aquatic_back', 'aquatic_tail',
          'aquatic_mouth', nameOverride: 'Torrent'),
      // Anti-Plant/Reptile Beast burst with all high-dmg cards
      _enemy('beast_1', 'beast_horn', 'beast_back', 'beast_tail', 'beast_mouth',
          nameOverride: 'Apex Predator'),
    ],
  ),
];

// Lookup by ID
StageConfig? stageById(String id) =>
    kStageRegistry.cast<StageConfig?>().firstWhere(
        (s) => s?.id == id, orElse: () => null);
