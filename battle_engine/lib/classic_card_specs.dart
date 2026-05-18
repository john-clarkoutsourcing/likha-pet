class ClassicCardSpec {
  final String name;
  final int attack;
  final int defense;
  final int energy;
  final String description;
  const ClassicCardSpec({
    required this.name,
    required this.attack,
    required this.defense,
    required this.energy,
    required this.description,
  });
}

const Map<String, ClassicCardSpec> kClassicCardSpecs = {
  'aquatic-back-02': ClassicCardSpec(
      name: 'Shelter',
      attack: 0,
      defense: 120,
      energy: 1,
      description: 'This Axie can\'t receive critical strikes this round.'),
  'aquatic-back-04': ClassicCardSpec(
      name: 'Scale Dart',
      attack: 100,
      defense: 35,
      energy: 1,
      description: 'Draw a card when attacking an idle target.'),
  'aquatic-back-06': ClassicCardSpec(
      name: 'Swift Escape',
      attack: 100,
      defense: 35,
      energy: 1,
      description: 'Apply Speed+ to this Axie for 2 rounds when attacked.'),
  'aquatic-back-08': ClassicCardSpec(
      name: 'Shipwreck',
      attack: 85,
      defense: 60,
      energy: 1,
      description:
          'Apply attack + to this Axie if its shield breaks. Can only trigger once per round.'),
  'aquatic-back-10': ClassicCardSpec(
      name: 'Aqua Vitality',
      attack: 75,
      defense: 30,
      energy: 1,
      description:
          'Successful attacks restore 50 HP for each Anemone part this Axie posseses.'),
  'aquatic-back-12': ClassicCardSpec(
      name: 'Spinal Tap',
      attack: 100,
      defense: 20,
      energy: 1,
      description:
          'Prioritize idle target when comboed with at least 2 additional cards.'),
  'aquatic-horn-02': ClassicCardSpec(
      name: 'Shell Jab',
      attack: 125,
      defense: 25,
      energy: 1,
      description: 'Deal 150% damage when attacking an idle target.'),
  'aquatic-horn-04': ClassicCardSpec(
      name: 'Deep Sea Gore',
      attack: 80,
      defense: 50,
      energy: 1,
      description:
          'Deal 30% of shield gained when the round started as bonus damage.'),
  'aquatic-horn-06': ClassicCardSpec(
      name: 'Clam Slash',
      attack: 115,
      defense: 35,
      energy: 1,
      description:
          'Apply Attack+ to this Axie when attacking Beast, Bug, or Mech targets.'),
  'aquatic-horn-08': ClassicCardSpec(
      name: 'Aquaponics',
      attack: 75,
      defense: 30,
      energy: 1,
      description:
          'Successful attacks restore 50 HP for each Anemone part this Axie posseses.'),
  'aquatic-horn-10': ClassicCardSpec(
      name: 'Hero\'s Bane',
      attack: 125,
      defense: 20,
      energy: 1,
      description: 'End target\'s Last Stand.'),
  'aquatic-horn-12': ClassicCardSpec(
      name: 'Star Shuriken',
      attack: 115,
      defense: 15,
      energy: 1,
      description:
          'Target cannot enter Last Stand if this card brings its HP to zero.'),
  'aquatic-mouth-02': ClassicCardSpec(
      name: 'Angry Lam',
      attack: 110,
      defense: 40,
      energy: 1,
      description: 'Deal 120% damage if this Axie\'s HP is below 50%.'),
  'aquatic-mouth-04': ClassicCardSpec(
      name: 'Swallow',
      attack: 90,
      defense: 25,
      energy: 1,
      description: 'Heal this Axie by the damage inflicted with this card.'),
  'aquatic-mouth-08': ClassicCardSpec(
      name: 'Fish Hook',
      attack: 120,
      defense: 25,
      energy: 1,
      description:
          'Apply Attack+ to this Axie when attacking Plant, Reptile, or Dusk targets.'),
  'aquatic-mouth-10': ClassicCardSpec(
      name: 'Crimson Water',
      attack: 120,
      defense: 30,
      energy: 1,
      description: 'Target injured enemy if this Axie\'s HP is below 50%.'),
  'aquatic-tail-02': ClassicCardSpec(
      name: 'Upstream Swim',
      attack: 110,
      defense: 30,
      energy: 1,
      description:
          'Apply Speed+ to this Axie for 2 rounds when comboed with another Aquatic class card.'),
  'aquatic-tail-04': ClassicCardSpec(
      name: 'Tail Slap',
      attack: 20,
      defense: 0,
      energy: 0,
      description: 'Gain 1 energy when comboed with another card.'),
  'aquatic-tail-06': ClassicCardSpec(
      name: 'Black Bubble',
      attack: 110,
      defense: 40,
      energy: 1,
      description: 'Apply Jinx for 4 rounds.'),
  'aquatic-tail-08': ClassicCardSpec(
      name: 'Water Sphere',
      attack: 110,
      defense: 40,
      energy: 1,
      description: 'Apply Chill for 4 rounds.'),
  'aquatic-tail-10': ClassicCardSpec(
      name: 'Flanking Smack',
      attack: 100,
      defense: 45,
      energy: 1,
      description: 'Deal 120% damage if this Axie attacks first.'),
  'aquatic-tail-12': ClassicCardSpec(
      name: 'Chitin Jump',
      attack: 25,
      defense: 30,
      energy: 1,
      description: 'Prioritizes furthest target'),
  'beast-back-02': ClassicCardSpec(
      name: 'Single Combat',
      attack: 80,
      defense: 20,
      energy: 1,
      description:
          'Guaranteed critical strike when comboed with at least 2 other cards.'),
  'beast-back-04': ClassicCardSpec(
      name: 'Heroic Reward',
      attack: 55,
      defense: 0,
      energy: 0,
      description:
          'Draw a card when attacking an Aquatic, Bird, or Dawn target.'),
  'beast-back-06': ClassicCardSpec(
      name: 'Nitro Leap',
      attack: 120,
      defense: 35,
      energy: 1,
      description: 'Attack first if any Axie is in Last Stand.'),
  'beast-back-08': ClassicCardSpec(
      name: 'Revenge Arrow',
      attack: 120,
      defense: 25,
      energy: 1,
      description: 'Deal 200% damage when in Last Stand.'),
  'beast-back-10': ClassicCardSpec(
      name: 'Woodman Power',
      attack: 80,
      defense: 40,
      energy: 1,
      description:
          'Apply Stun when hit by a Plant or Reptile card. Triggers once per round.'),
  'beast-back-12': ClassicCardSpec(
      name: 'Juggling Balls',
      attack: 40,
      defense: 30,
      energy: 1,
      description: 'Strike 3 times.'),
  'beast-horn-02': ClassicCardSpec(
      name: 'Branch Charge',
      attack: 100,
      defense: 0,
      energy: 1,
      description: 'Guaranteed critical strike when attacking first.'),
  'beast-horn-04': ClassicCardSpec(
      name: 'Ivory Stab',
      attack: 90,
      defense: 30,
      energy: 1,
      description:
          'Gain 1 energy per critical strike dealt by your team this round.'),
  'beast-horn-06': ClassicCardSpec(
      name: 'Merry Legion',
      attack: 90,
      defense: 40,
      energy: 1,
      description: 'Bonus 20% shield when comboed.'),
  'beast-horn-08': ClassicCardSpec(
      name: 'Sugar Rush',
      attack: 110,
      defense: 40,
      energy: 1,
      description: 'Apply Aroma to self until next round.'),
  'beast-horn-10': ClassicCardSpec(
      name: 'Sinister Strike',
      attack: 130,
      defense: 20,
      energy: 1,
      description: 'Deal 200% damage on critical strikes.'),
  'beast-horn-12': ClassicCardSpec(
      name: 'Acrobatic',
      attack: 110,
      defense: 30,
      energy: 1,
      description:
          'Apply speed + to this Axie for 2 rounds when comboed with another card.'),
  'beast-mouth-02': ClassicCardSpec(
      name: 'Nut Crack',
      attack: 105,
      defense: 30,
      energy: 1,
      description:
          'Deal 120% damage when comboed with another \'Nut Cracker\' card.'),
  'beast-mouth-04': ClassicCardSpec(
      name: 'Piercing Sound',
      attack: 85,
      defense: 30,
      energy: 1,
      description: 'Destroy 1 of your opponent\'s energy.'),
  'beast-mouth-08': ClassicCardSpec(
      name: 'Death Mark',
      attack: 110,
      defense: 30,
      energy: 1,
      description: 'Apply Lethal to target if this Axie\'s HP is below 30%.'),
  'beast-mouth-10': ClassicCardSpec(
      name: 'Self Rally',
      attack: 0,
      defense: 20,
      energy: 0,
      description: 'Apply Speed+ and Morale+ to team for 2 rounds.'),
  'beast-tail-02': ClassicCardSpec(
      name: 'Luna Absorb',
      attack: 0,
      defense: 30,
      energy: 0,
      description: 'Gain 1 energy after attacking.'),
  'beast-tail-04': ClassicCardSpec(
      name: 'Night Steal',
      attack: 90,
      defense: 20,
      energy: 1,
      description:
          'Steal 1 energy from your opponent when comboed with another card.'),
  'beast-tail-06': ClassicCardSpec(
      name: 'Rampant Howl',
      attack: 110,
      defense: 30,
      energy: 1,
      description:
          'Guaranteed Last Stand if killed this round when comboed with another 3 cards.'),
  'beast-tail-08': ClassicCardSpec(
      name: 'Hare Dagger',
      attack: 115,
      defense: 20,
      energy: 1,
      description:
          'Draw a card if this Axie attacks at the beginning of the round.'),
  'beast-tail-10': ClassicCardSpec(
      name: 'Nut Throw',
      attack: 105,
      defense: 30,
      energy: 1,
      description:
          'Deal 120% damage when comboed with another \'Nut Cracker\' card.'),
  'beast-tail-12': ClassicCardSpec(
      name: 'Gerbil Jump',
      attack: 50,
      defense: 25,
      energy: 1,
      description:
          'Skip the closest target if there are 2 or more enemies remaining.'),
  'bird-back-02': ClassicCardSpec(
      name: 'Balloon Pop',
      attack: 40,
      defense: 0,
      energy: 0,
      description:
          'Apply Fear to target for 1 turn. If defending, apply Fear to self until next round.'),
  'bird-back-04': ClassicCardSpec(
      name: 'Heart Break',
      attack: 120,
      defense: 30,
      energy: 1,
      description: 'Apply Chill for 4 rounds.'),
  'bird-back-05': ClassicCardSpec(
      name: 'Heart Break II',
      attack: 120,
      defense: 30,
      energy: 1,
      description: 'Target cannot use ally-targeting cards this round when comboed with 2 other cards.'),
  'bird-back-06': ClassicCardSpec(
      name: 'Ill-omened',
      attack: 120,
      defense: 30,
      energy: 1,
      description: 'Apply Jinx for 4 rounds.'),
  'bird-back-08': ClassicCardSpec(
      name: 'Blackmail',
      attack: 120,
      defense: 30,
      energy: 1,
      description: 'Transfer all debuffs on this Axie to target.'),
  'bird-back-09': ClassicCardSpec(
      name: 'Blackmail II',
      attack: 120,
      defense: 15,
      energy: 1,
      description: 'Deal 20% extra damage to targets that have debuffs.'),
  'bird-back-10': ClassicCardSpec(
      name: 'Patient Hunter',
      attack: 130,
      defense: 10,
      energy: 1,
      description:
          'Target an Aquatic class enemy if this Axie\'s HP is below 50%'),
  'bird-back-12': ClassicCardSpec(
      name: 'Triple Threat',
      attack: 40,
      defense: 10,
      energy: 0,
      description: 'Attack twice if this Axie has any debuffs.'),
  'bird-horn-02': ClassicCardSpec(
      name: 'Eggbomb',
      attack: 120,
      defense: 10,
      energy: 1,
      description: 'Apply Aroma to the target until the next round.'),
  'bird-horn-04': ClassicCardSpec(
      name: 'Cockadoodledoo',
      attack: 0,
      defense: 20,
      energy: 0,
      description: 'Apply attack+ to the whole team'),
  'bird-horn-06': ClassicCardSpec(
      name: 'Air Force One',
      attack: 125,
      defense: 30,
      energy: 1,
      description: 'Deal 120% damage when chained with another "Trump" card.'),
  'bird-horn-08': ClassicCardSpec(
      name: 'Headshot',
      attack: 135,
      defense: 0,
      energy: 1,
      description: 'Disable target\'s horn cards next round.'),
  'bird-horn-10': ClassicCardSpec(
      name: 'Smart Shot',
      attack: 40,
      defense: 20,
      energy: 1,
      description:
          'Skip the closest target if there are 2 or more enemies remaining.'),
  'bird-horn-12': ClassicCardSpec(
      name: 'Feather Lunge',
      attack: 120,
      defense: 30,
      energy: 1,
      description: 'Deal 120% damage when chained with another "Lunge" card.'),
  'bird-mouth-02': ClassicCardSpec(
      name: 'Soothing Song',
      attack: 60,
      defense: 0,
      energy: 1,
      description: 'Ignore shield. Apply sleep to target.'),
  'bird-mouth-04': ClassicCardSpec(
      name: 'Peace Treaty',
      attack: 120,
      defense: 25,
      energy: 1,
      description: 'Apply Attack- on target.'),
  'bird-mouth-08': ClassicCardSpec(
      name: 'Insectivore',
      attack: 130,
      defense: 20,
      energy: 1,
      description: 'Target Bug class enemy if this Axie\'s HP is below 50%.'),
  'bird-mouth-10': ClassicCardSpec(
      name: 'Dark Swoop',
      attack: 30,
      defense: 0,
      energy: 1,
      description: 'Target fastest enemy.'),
  'bird-tail-02': ClassicCardSpec(
      name: 'Early Bird',
      attack: 110,
      defense: 20,
      energy: 1,
      description: 'Deal 120% damage if this Axie attacks first.'),
  'bird-tail-04': ClassicCardSpec(
      name: 'Sunder Armor',
      attack: 105,
      defense: 30,
      energy: 1,
      description: 'Add 20% shield to this Axie for each debuff it possesses.'),
  'bird-tail-06': ClassicCardSpec(
      name: 'Risky Feather',
      attack: 150,
      defense: 0,
      energy: 1,
      description: 'Apply 2 Attack- to this Axie.'),
  'bird-tail-08': ClassicCardSpec(
      name: 'Puffy Smack',
      attack: 110,
      defense: 40,
      energy: 1,
      description: 'Skip targets that are in Last Stand.'),
  'bird-tail-10': ClassicCardSpec(
      name: 'Cool Breeze',
      attack: 125,
      defense: 20,
      energy: 1,
      description: 'Apply Chill for 4 rounds.'),
  'bird-tail-12': ClassicCardSpec(
      name: 'All-out Shot',
      attack: 115,
      defense: 0,
      energy: 0,
      description: 'Inflict 30% of this Axie\'s max HP to itself.'),
  'bug-back-02': ClassicCardSpec(
      name: 'Sticky Goo',
      attack: 40,
      defense: 60,
      energy: 1,
      description:
          'Stun attacker if this Axie\'s shield breaks. Can only trigger once per round.'),
  'bug-back-04': ClassicCardSpec(
      name: 'Barb Strike',
      attack: 90,
      defense: 40,
      energy: 1,
      description: 'Apply 2 poison to target when played in a chain.'),
  'bug-back-06': ClassicCardSpec(
      name: 'Bug Noise',
      attack: 100,
      defense: 45,
      energy: 1,
      description: 'Apply Attack- to target.'),
  'bug-back-08': ClassicCardSpec(
      name: 'Bug Splat',
      attack: 100,
      defense: 55,
      energy: 1,
      description: 'Deal 50% more damage when attacking Bug targets.'),
  'bug-back-10': ClassicCardSpec(
      name: 'Scarab Curse',
      attack: 100,
      defense: 45,
      energy: 1,
      description:
          'Target cannot heal for 2 rounds. This debuff can\'t be removed.'),
  'bug-back-12': ClassicCardSpec(
      name: 'Buzzing Wind',
      attack: 10,
      defense: 30,
      energy: 0,
      description: 'Apply Fragile for 2 rounds.'),
  'bug-horn-02': ClassicCardSpec(
      name: 'Mystic Rush',
      attack: 40,
      defense: 0,
      energy: 0,
      description: 'Apply Speed- to target for 2 rounds.'),
  'bug-horn-04': ClassicCardSpec(
      name: 'Bug Signal',
      attack: 90,
      defense: 35,
      energy: 1,
      description:
          'Steal energy from your opponent when chained with another "Bug Signal" card.'),
  'bug-horn-06': ClassicCardSpec(
      name: 'Grub Surprise',
      attack: 120,
      defense: 20,
      energy: 1,
      description: 'Apply Fear to shielded targets.'),
  'bug-horn-08': ClassicCardSpec(
      name: 'Dull Grip',
      attack: 120,
      defense: 20,
      energy: 1,
      description: 'Deal 30% more damage to shielded targets.'),
  'bug-horn-10': ClassicCardSpec(
      name: 'Third Glance',
      attack: 100,
      defense: 30,
      energy: 1,
      description:
          'Randomly discard 1 card from your enemy\'s hand when comboed with another card'),
  'bug-horn-12': ClassicCardSpec(
      name: 'Disguise',
      attack: 20,
      defense: 20,
      energy: 0,
      description: 'Gain 1 energy when comboed with a plant card.'),
  'bug-mouth-02': ClassicCardSpec(
      name: 'Blood Taste',
      attack: 80,
      defense: 40,
      energy: 1,
      description: 'Heal this Axie by the damage inflicted with this card.'),
  'bug-mouth-04': ClassicCardSpec(
      name: 'Sunder Claw',
      attack: 20,
      defense: 0,
      energy: 0,
      description:
          'Randomly discard 1 card from your enemy\'s hand when comboed with another card'),
  'bug-mouth-08': ClassicCardSpec(
      name: 'Terror Chomp',
      attack: 100,
      defense: 35,
      energy: 1,
      description: 'Apply Fear to target for 2 turns when played in a Chain.'),
  'bug-mouth-10': ClassicCardSpec(
      name: 'Mite Bite',
      attack: 30,
      defense: 0,
      energy: 0,
      description: 'Add 100% more damage when comboed with another card.'),
  'bug-tail-02': ClassicCardSpec(
      name: 'Chemical Warfare',
      attack: 60,
      defense: 60,
      energy: 1,
      description: 'Apply Stench for 3 rounds'),
  'bug-tail-04': ClassicCardSpec(
      name: 'Twin Needle',
      attack: 35,
      defense: 0,
      energy: 0,
      description: 'Attack twice when comboed with another card.'),
  'bug-tail-06': ClassicCardSpec(
      name: 'Anesthetic Bait',
      attack: 80,
      defense: 40,
      energy: 1,
      description:
          'Apply stun when struck by Aquatic or Bird class cards. Can only trigger once per round.'),
  'bug-tail-08': ClassicCardSpec(
      name: 'Numbing Lecretion',
      attack: 30,
      defense: 30,
      energy: 1,
      description:
          'Disable target\'s melee cards when comboed with another card.'),
  'bug-tail-10': ClassicCardSpec(
      name: 'Grub Explode',
      attack: 65,
      defense: 0,
      energy: 0,
      description:
          'Deal 200% damage when attacking in Last stand. Axie\'s Last Stand ends after it attacks.'),
  'bug-tail-12': ClassicCardSpec(
      name: 'Allergic Reaction',
      attack: 100,
      defense: 40,
      energy: 1,
      description: 'Deal 130% damage to debuffed targets.'),
  'plant-back-02': ClassicCardSpec(
      name: 'Turnip Rocket',
      attack: 60,
      defense: 80,
      energy: 1,
      description: 'Target a bird if comboed with 2 or more cards.'),
  'plant-back-04': ClassicCardSpec(
      name: 'Shroom\'s Grace',
      attack: 0,
      defense: 50,
      energy: 1,
      description: 'Heal this Axie for 120 HP.'),
  'plant-back-06': ClassicCardSpec(
      name: 'Cleanse Scent',
      attack: 0,
      defense: 30,
      energy: 0,
      description:
          'Remove all debuffs from self. Can activate while stunned or feared.'),
  'plant-back-08': ClassicCardSpec(
      name: 'Aqua Stock',
      attack: 40,
      defense: 90,
      energy: 1,
      description: 'Gain 1 energy if this Axie is struck by an Aquatic card.'),
  'plant-back-10': ClassicCardSpec(
      name: 'Refresh',
      attack: 0,
      defense: 30,
      energy: 0,
      description: 'Remove all Debuffs from frontline Axie.'),
  'plant-back-12': ClassicCardSpec(
      name: 'October Treat',
      attack: 0,
      defense: 130,
      energy: 1,
      description:
          'Draw a card if this Axie\'s shield doesn\'t break this round.'),
  'plant-horn-02': ClassicCardSpec(
      name: 'Bamboo Clan',
      attack: 90,
      defense: 50,
      energy: 1,
      description: 'Increased 20% damage when played in a chain.'),
  'plant-horn-04': ClassicCardSpec(
      name: 'Wooden Stab',
      attack: 105,
      defense: 40,
      energy: 1,
      description: 'Deal 120% damage if this Axie\'s shield breaks.'),
  'plant-horn-06': ClassicCardSpec(
      name: 'Healing Aroma',
      attack: 0,
      defense: 50,
      energy: 1,
      description: 'Heal this Axie for120 HP.'),
  'plant-horn-08': ClassicCardSpec(
      name: 'Sweet Party',
      attack: 0,
      defense: 40,
      energy: 2,
      description: 'Heal frontline Axie for 270 HP'),
  'plant-horn-10': ClassicCardSpec(
      name: 'Prickly Trap',
      attack: 110,
      defense: 20,
      energy: 1,
      description: 'Deal 120% damage if this Axie attacks last.'),
  'plant-horn-12': ClassicCardSpec(
      name: 'Seed Bullet',
      attack: 30,
      defense: 50,
      energy: 1,
      description: 'Target the fastest enemy.'),
  'plant-mouth-02': ClassicCardSpec(
      name: 'Vegetal Bite',
      attack: 30,
      defense: 30,
      energy: 1,
      description:
          'Steal 1 energy from your opponent when comboed with another card.'),
  'plant-mouth-04': ClassicCardSpec(
      name: 'Drain Bite',
      attack: 60,
      defense: 60,
      energy: 1,
      description: 'Heal this Axie by the damage this card inflicts.'),
  'plant-mouth-08': ClassicCardSpec(
      name: 'Vegan Diet',
      attack: 75,
      defense: 75,
      energy: 1,
      description:
          'Heal this Axie by the damage this card inflicts on a Plant target.'),
  'plant-mouth-10': ClassicCardSpec(
      name: 'Forest Spirit',
      attack: 0,
      defense: 40,
      energy: 1,
      description: 'Heal frontline Axie for 120 HP'),
  'plant-tail-02': ClassicCardSpec(
      name: 'Carrot Hammer',
      attack: 80,
      defense: 50,
      energy: 1,
      description:
          'Gain 1 energy if this Axie\'s shield breaks. Can only trigger once per round.'),
  'plant-tail-04': ClassicCardSpec(
      name: 'Cattail Slap',
      attack: 10,
      defense: 30,
      energy: 0,
      description: 'Draw a card if struck by a Beast, Bug, or Mech card.'),
  'plant-tail-06': ClassicCardSpec(
      name: 'Leek Leak',
      attack: 60,
      defense: 80,
      energy: 1,
      description:
          'When hit, disable the attacker\'s ranged cards next round.'),
  'plant-tail-08': ClassicCardSpec(
      name: 'Gas Unleash',
      attack: 20,
      defense: 20,
      energy: 1,
      description:
          'Apply poison each time this card is used to attack or defend.'),
  'plant-tail-10': ClassicCardSpec(
      name: 'Aqua Deflect',
      attack: 70,
      defense: 90,
      energy: 1,
      description:
          'Cannot be targeted by an Aquatic axie if this Axie has teammates remaining.'),
  'plant-tail-12': ClassicCardSpec(
      name: 'Spicy Surprise',
      attack: 80,
      defense: 60,
      energy: 1,
      description: 'Disable target\'s mouth cards next round.'),
  'reptile-back-02': ClassicCardSpec(
      name: 'Ivory Chop',
      attack: 70,
      defense: 70,
      energy: 1,
      description: 'Draw a card if this Axie\'s shield breaks.'),
  'reptile-back-04': ClassicCardSpec(
      name: 'Spike Throw',
      attack: 80,
      defense: 50,
      energy: 1,
      description:
          'Target enemy with lowest shield when comboed with 2 or more cards.'),
  'reptile-back-06': ClassicCardSpec(
      name: 'Vine Dagger',
      attack: 25,
      defense: 30,
      energy: 0,
      description:
          'Double shield from this card when comboed with a plant card.'),
  'reptile-back-08': ClassicCardSpec(
      name: 'Bulwark',
      attack: 20,
      defense: 80,
      energy: 1,
      description: 'Reflect 40% of melee damage back at attacker.'),
  'reptile-back-10': ClassicCardSpec(
      name: 'Slippery Shield',
      attack: 10,
      defense: 145,
      energy: 1,
      description: 'Add 15% of this Axie\'s shield to adjacent teammates.'),
  'reptile-back-12': ClassicCardSpec(
      name: 'Nile Strike',
      attack: 85,
      defense: 60,
      energy: 1,
      description: 'Apply Speed- to target for 2 rounds.'),
  'reptile-horn-02': ClassicCardSpec(
      name: 'Poo Fling',
      attack: 70,
      defense: 60,
      energy: 1,
      description: 'Apply Stench for 3 rounds.'),
  'reptile-horn-04': ClassicCardSpec(
      name: 'Scaly Lunge',
      attack: 120,
      defense: 30,
      energy: 1,
      description: 'Deal 120% damage when chained with another "lunge" card.'),
  'reptile-horn-06': ClassicCardSpec(
      name: 'Surprise Invasion',
      attack: 100,
      defense: 40,
      energy: 1,
      description: 'Deal 130% damage if target is faster than this Axie.'),
  'reptile-horn-08': ClassicCardSpec(
      name: 'Tiny Catapult',
      attack: 90,
      defense: 40,
      energy: 1,
      description: 'Reflect 40% of ranged damage back at attacker.'),
  'reptile-horn-10': ClassicCardSpec(
      name: 'Disarm',
      attack: 105,
      defense: 40,
      energy: 1,
      description: 'Apply speed- to target for 2 rounds.'),
  'reptile-horn-12': ClassicCardSpec(
      name: 'Overgrow Keratin',
      attack: 90,
      defense: 30,
      energy: 1,
      description: 'Recover 20 shield per turn.'),
  'reptile-mouth-02': ClassicCardSpec(
      name: 'Sneaky Raid',
      attack: 20,
      defense: 30,
      energy: 1,
      description: 'Target the furthest enemy.'),
  'reptile-mouth-04': ClassicCardSpec(
      name: 'Kotaro bite',
      attack: 85,
      defense: 30,
      energy: 1,
      description: 'Gain 1 energy if target is faster than this Axie.'),
  'reptile-mouth-08': ClassicCardSpec(
      name: 'Why So Serious',
      attack: 95,
      defense: 55,
      energy: 1,
      description:
          'Heal this Axie by damage inflicted with this card to Aquatic targets.'),
  'reptile-mouth-10': ClassicCardSpec(
      name: 'Chomp',
      attack: 75,
      defense: 50,
      energy: 1,
      description:
          'Apply Stun to enemy when comboed with at least 2 additional cards.'),
  'reptile-tail-02': ClassicCardSpec(
      name: 'Critical Escape',
      attack: 90,
      defense: 20,
      energy: 1,
      description: 'Reduce damage taken by 15% this round.'),
  'reptile-tail-04': ClassicCardSpec(
      name: 'Scale Dart',
      attack: 75,
      defense: 60,
      energy: 1,
      description: 'Generate 1 energy when attacking a buffed target.'),
  'reptile-tail-06': ClassicCardSpec(
      name: 'Tiny Swing',
      attack: 85,
      defense: 40,
      energy: 1,
      description: 'Deal 150% damage after round 4.'),
  'reptile-tail-08': ClassicCardSpec(
      name: 'Jar Barrage',
      attack: 90,
      defense: 20,
      energy: 1,
      description:
          'Attacks that break this Axie\'s shield cannot do additional damage. Can only trigger once per round.'),
  'reptile-tail-10': ClassicCardSpec(
      name: 'Neuro Toxin',
      attack: 100,
      defense: 50,
      energy: 1,
      description: 'Apply 2 Attack- to poisoned targets.'),
  'reptile-tail-12': ClassicCardSpec(
      name: 'Venom Spray',
      attack: 20,
      defense: 20,
      energy: 0,
      description: 'Apply 1 Poison to target.'),
};
