import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../providers/battle_view_model.dart';
import 'classic_trait_card_widget.dart';
import 'pet_renderer_widget.dart';
import 'shared_battle_hud.dart'
    show battleClassicCardAttack, battleClassicCardDefense, battleClassicImageNameFromPath, kBattleCardCatalogByTraitId;

class BattlePetDetailsSheet {
  static Future<void> show(BuildContext context, PetViewModel pet) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (_) => _BattlePetDetailsPanel(pet: pet),
    );
  }
}

class _BattlePetDetailsPanel extends StatelessWidget {
  final PetViewModel pet;
  const _BattlePetDetailsPanel({required this.pet});

  @override
  Widget build(BuildContext context) {
    final def = pet.creatureDef;
    final clsName = def?.className ?? 'unknown';
    final clsColor = _clsColor(clsName);
    final traitEntries = pet.traits.map((trait) {
      final cardEntry = kBattleCardCatalogByTraitId[trait.id];
      final imagePath = pet.partCardArt[trait.partName] ??
          cardEntry?.templatePath ??
          'assets/images/part-cards/default-card-art.png';
      final imageName = cardEntry?.imageName ??
          battleClassicImageNameFromPath(imagePath) ??
          trait.id;
      return (
        trait: trait,
        cardEntry: cardEntry,
        imagePath: imagePath,
        imageName: imageName,
      );
    }).toList();

    return SafeArea(
      child: DraggableScrollableSheet(
        initialChildSize: 0.82,
        minChildSize: 0.55,
        maxChildSize: 0.92,
        builder: (context, controller) {
          return Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0D1220),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(top: BorderSide(color: clsColor.withValues(alpha: 0.45))),
            ),
            child: SingleChildScrollView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 132,
                        height: 132,
                        child: pet.creatureDef != null
                            ? PetRendererWidget(def: pet.creatureDef!, size: 132)
                            : const Icon(Icons.pets, size: 96, color: Colors.white24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pet.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _pill('Class', clsName),
                                _pill('HP', '${pet.hp}/${pet.maxHp}'),
                                _pill('Shield', '${pet.shield}'),
                                _pill('SPD', '${pet.speed}'),
                                _pill('MOR', '${pet.morale}'),
                                _pill('SKL', '${pet.skill}'),
                                _pill('Energy', '${pet.energy}/${pet.maxEnergy}'),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              pet.isFainted ? 'Fainted' : pet.positionLabel,
                              style: TextStyle(
                                color: pet.isFainted ? AppColors.fainted : clsColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _sectionTitle('Attributes'),
                  const SizedBox(height: 8),
                  _attributeGrid(pet),
                  const SizedBox(height: 18),
                  _sectionTitle('Skills'),
                  const SizedBox(height: 10),
                  if (traitEntries.isEmpty)
                    const Text('No skills available.', style: TextStyle(color: Colors.white54))
                  else
                    SizedBox(
                      height: 246,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: traitEntries.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (_, i) {
                          final entry = traitEntries[i];
                          final trait = entry.trait;
                          final cardEntry = entry.cardEntry;
                          return SizedBox(
                            width: 150,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SizedBox(
                                  height: 182,
                                  child: ClassicTraitCardWidget(
                                    imagePath: entry.imagePath,
                                    imageName: entry.imageName,
                                    name: trait.name,
                                    energy: trait.energyCost,
                                    attack: battleClassicCardAttack(trait, cardEntry),
                                    defense: battleClassicCardDefense(trait, cardEntry),
                                    description: trait.description,
                                    showDescription: true,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  trait.effectSummary,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  'Target: ${trait.targetSummary} · CD ${trait.cooldownMax}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _attributeGrid(PetViewModel pet) {
    final def = pet.creatureDef;
    final stats = def?.computedStats;
    final items = <_AttrItem>[
      _AttrItem('HP', '${pet.hp}/${pet.maxHp}'),
      _AttrItem('Shield', '${pet.shield}'),
      _AttrItem('Energy', '${pet.energy}/${pet.maxEnergy}'),
      _AttrItem('Speed', '${pet.speed}'),
      _AttrItem('Morale', '${pet.morale}'),
      _AttrItem('Skill', '${pet.skill}'),
      if (stats != null) ...[
        _AttrItem('Base HP', '${stats.hp}'),
        _AttrItem('Base SPD', '${stats.speed}'),
        _AttrItem('Base SKL', '${stats.skill}'),
        _AttrItem('Base MOR', '${stats.morale}'),
      ],
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items
          .map(
            (item) => Container(
              width: 106,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.label,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      )),
                  const SizedBox(height: 4),
                  Text(item.value,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      )),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _sectionTitle(String text) => Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w900,
        ),
      );

  Widget _pill(String label, String value) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white12),
        ),
        child: Text(
          '$label: $value',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      );

  static Color _clsColor(String cls) => switch (cls.toLowerCase()) {
        'beast' => const Color(0xFFFF9800),
        'plant' => const Color(0xFF4CAF50),
        'aquatic' => const Color(0xFF29B6F6),
        'reptile' => const Color(0xFF66BB6A),
        'bird' => const Color(0xFFFF80AB),
        'bug' => const Color(0xFFFF5252),
        _ => const Color(0xFF9C27B0),
      };
}

class _AttrItem {
  final String label;
  final String value;
  const _AttrItem(this.label, this.value);
}
