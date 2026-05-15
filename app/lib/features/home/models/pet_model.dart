class PetModel {
  final String id;
  final String dna;
  final String state; // 'Egg' or 'Hatched'
  final int hatchTime;
  final int createdAt;
  final String owner;
  final String name;
  final PetAttributes attributes;

  PetModel({
    required this.id,
    required this.dna,
    required this.state,
    required this.hatchTime,
    required this.createdAt,
    required this.owner,
    required this.name,
    required this.attributes,
  });

  factory PetModel.fromJson(Map<String, dynamic> json) {
    return PetModel(
      id:        json['id']        as String? ?? '',
      dna:       json['dna']       as String? ?? '',
      state:     json['state']     as String? ?? 'Egg',
      hatchTime: json['hatchTime'] as int?    ?? 0,
      createdAt: json['createdAt'] as int?    ?? 0,
      owner:     json['owner']     as String? ?? '',
      name:      json['name']      as String? ?? 'Unknown',
      attributes: PetAttributes.fromJson(
          json['attributes'] as Map<String, dynamic>? ?? {}),
    );
  }

  bool get isEgg => state == 'Egg';
  bool get isHatched => state == 'Hatched';
  bool get readyToHatch => isEgg && DateTime.now().millisecondsSinceEpoch >= hatchTime;
}

class PetAttributes {
  final String color;
  final String rarity;
  final int basePower;
  final String element;
  final String pattern;

  PetAttributes({
    required this.color,
    required this.rarity,
    required this.basePower,
    required this.element,
    required this.pattern,
  });

  factory PetAttributes.fromJson(Map<String, dynamic> json) {
    return PetAttributes(
      color:     json['color']     as String? ?? 'Gray',
      rarity:    json['rarity']    as String? ?? 'Common',
      basePower: json['basePower'] as int?    ?? 0,
      element:   json['element']   as String? ?? 'Normal',
      pattern:   json['pattern']   as String? ?? 'Plain',
    );
  }
}
