import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:likha_pet_battle_engine/trait.dart';
import '../providers/test_battle_provider.dart';

class TestBattleScreen extends ConsumerStatefulWidget {
  const TestBattleScreen({super.key});

  @override
  ConsumerState<TestBattleScreen> createState() => _TestBattleScreenState();
}

class _TestBattleScreenState extends ConsumerState<TestBattleScreen> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(testBattleProvider);
    final notifier = ref.read(testBattleProvider.notifier);

    if (!state.petCreated) {
      return _PetCreatorPanel(notifier: notifier, state: state);
    } else {
      return _TestBattlePanel(notifier: notifier, state: state);
    }
  }
}

// ── Pet Creator Panel ─────────────────────────────────────────────────────────

class _PetCreatorPanel extends ConsumerWidget {
  final TestBattleNotifier notifier;
  final TestPetCreatorState state;

  const _PetCreatorPanel({
    required this.notifier,
    required this.state,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Battle Creator'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Select Traits for Each Body Part',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // Character preview panel
            _CharacterPreviewPanel(
              selectedTraits: state.selectedTraitNames,
              notifier: notifier,
            ),
            const SizedBox(height: 24),

            // Body trait selector
            _TraitSelector(
              part: TraitPart.body,
              notifier: notifier,
              selectedTraitName: state.selectedTraitNames[TraitPart.body],
            ),
            const SizedBox(height: 12),

            // Horn trait selector
            _TraitSelector(
              part: TraitPart.horn,
              notifier: notifier,
              selectedTraitName: state.selectedTraitNames[TraitPart.horn],
            ),
            const SizedBox(height: 12),

            // Back trait selector
            _TraitSelector(
              part: TraitPart.back,
              notifier: notifier,
              selectedTraitName: state.selectedTraitNames[TraitPart.back],
            ),
            const SizedBox(height: 12),

            // Mouth trait selector
            _TraitSelector(
              part: TraitPart.mouth,
              notifier: notifier,
              selectedTraitName: state.selectedTraitNames[TraitPart.mouth],
            ),
            const SizedBox(height: 12),

            // Tail trait selector
            _TraitSelector(
              part: TraitPart.tail,
              notifier: notifier,
              selectedTraitName: state.selectedTraitNames[TraitPart.tail],
            ),
            const SizedBox(height: 24),

            // Create pet button
            ElevatedButton(
              onPressed: _allTraitsSelected(state)
                  ? () => notifier.createPetAndStartBattle()
                  : null,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text(
                'Create Pet & Start Battle',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),

            if (state.actionLog.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  border: Border.all(color: Colors.orange),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  state.actionLog,
                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                ),
              ),
          ],
        ),
      ),
    );
  }

  bool _allTraitsSelected(TestPetCreatorState state) {
    return state.selectedTraitNames.values.every((t) => t != null);
  }
}

// ── Trait Selector Widget ─────────────────────────────────────────────────────

class _TraitSelector extends ConsumerWidget {
  final TraitPart part;
  final TestBattleNotifier notifier;
  final String? selectedTraitName;

  const _TraitSelector({
    required this.part,
    required this.notifier,
    this.selectedTraitName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final availableTraitNames = notifier.getTraitNamesForPart(part);
    final selectedTrait = selectedTraitName != null
        ? notifier.getTraitByName(selectedTraitName!)
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          part.name.toUpperCase(),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        ),
        const SizedBox(height: 8),
        DropdownButton<String>(
          isExpanded: true,
          value: selectedTraitName,
          hint: const Text('Select a trait...'),
          onChanged: (traitName) {
            if (traitName != null) notifier.selectTrait(part, traitName);
          },
          items: availableTraitNames.map((traitName) {
            final trait = notifier.getTraitByName(traitName);
            return DropdownMenuItem<String>(
              value: traitName,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(trait?.name ?? traitName),
                  Text(
                    '${trait?.effect.type.name ?? "unknown"} | Dmg: ${trait?.effect.value ?? 0}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
        if (selectedTrait != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                border: Border.all(color: Colors.blue.shade200),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '✓ ${selectedTrait.name}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade800,
                    ),
                  ),
                  Text(
                    'Type: ${selectedTrait.effect.type.name} | Value: ${selectedTrait.effect.value}',
                    style: const TextStyle(fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ── Test Battle Panel ─────────────────────────────────────────────────────────

class _TestBattlePanel extends ConsumerWidget {
  final TestBattleNotifier notifier;
  final TestPetCreatorState state;

  const _TestBattlePanel({
    required this.notifier,
    required this.state,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Battle Arena'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => notifier.reset(),
            tooltip: 'Reset to creator',
          ),
        ],
      ),
      body: Column(
        children: [
          // Battle header
          Container(
            color: Colors.blue.shade50,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Pet: ${state.testPet?.name ?? "N/A"}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Enemy: ${state.dummyEnemy?.name ?? "N/A"}',
                  style: const TextStyle(fontSize: 14),
                ),
                if (state.testPet != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: LinearProgressIndicator(
                          value: state.testPet!.hp / 150,
                          minHeight: 8,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('HP: ${state.testPet!.hp}/150'),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Skill buttons (test pet traits)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Skills',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: (state.testPet?.traits ?? []).map((trait) {
                    return ElevatedButton(
                      onPressed: !state.isWaitingForAction
                          ? null
                          : () => notifier.executeTestAction(trait),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            trait.name,
                            style: const TextStyle(fontSize: 11),
                          ),
                          Text(
                            trait.effect.type.name,
                            style: const TextStyle(fontSize: 9),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Animation state display
          if (state.petAnimStates.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  border: Border.all(color: Colors.purple),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: state.petAnimStates.entries.map((e) {
                    return Text(
                      '🎬 ${e.key}: ${e.value}',
                      style: const TextStyle(fontSize: 12),
                    );
                  }).toList(),
                ),
              ),
            ),
          const SizedBox(height: 16),

          // Action log
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView(
                  children: [
                    const Text(
                      'Action Log',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      state.actionLog.isEmpty
                          ? 'Waiting for action...'
                          : state.actionLog,
                      style: const TextStyle(fontSize: 11, height: 1.5),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ── Character Preview Panel ───────────────────────────────────────────────────

class _CharacterPreviewPanel extends ConsumerWidget {
  final Map<TraitPart, String?> selectedTraits;
  final TestBattleNotifier notifier;

  const _CharacterPreviewPanel({
    required this.selectedTraits,
    required this.notifier,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bodyTrait = selectedTraits[TraitPart.body] != null
        ? notifier.getTraitByName(selectedTraits[TraitPart.body]!)
        : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        border: Border.all(color: Colors.indigo, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Character type header
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (bodyTrait != null) ...[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _getEffectTypeColor(bodyTrait.effect.type),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      bodyTrait.name.split(' ').first.substring(0, 1),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Character Type',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    Text(
                      bodyTrait?.name ?? 'Select body type',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Part breakdown
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Body Parts',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 12),
              // Horn, Back, Mouth, Tail parts (exclude body from display)
              ...[TraitPart.horn, TraitPart.back, TraitPart.mouth, TraitPart.tail]
                  .map((part) {
                final traitName = selectedTraits[part];
                final trait = traitName != null
                    ? notifier.getTraitByName(traitName)
                    : null;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: trait != null
                              ? _getEffectTypeColor(trait.effect.type)
                              : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(
                          child: Text(
                            part.name[0].toUpperCase(),
                            style: TextStyle(
                              color:
                                  trait != null ? Colors.white : Colors.grey,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              part.name.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              trait?.name ?? '(empty)',
                              style: TextStyle(
                                fontSize: 13,
                                color: trait != null
                                    ? Colors.black87
                                    : Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (trait != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${trait.effect.value}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),

          const SizedBox(height: 16),

          // Combined character stats
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.indigo.shade200),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _StatBadge(
                  icon: '⚔',
                  label: 'ATK',
                  value: _calculateStat('attack'),
                ),
                _StatBadge(
                  icon: '🛡',
                  label: 'DEF',
                  value: _calculateStat('defense'),
                ),
                _StatBadge(
                  icon: '⚡',
                  label: 'SPD',
                  value: _calculateStat('speed'),
                ),
                _StatBadge(
                  icon: '❤',
                  label: 'HP',
                  value: 150,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Calculate combined stat from selected traits
  int _calculateStat(String statType) {
    int total = 30; // base stat
    for (final traitName in selectedTraits.values) {
      if (traitName != null) {
        final trait = notifier.getTraitByName(traitName);
        if (trait != null) {
          if (statType == 'attack' &&
              trait.effect.type == EffectType.damage) {
            total += (trait.effect.value ~/ 3).clamp(0, 10);
          } else if (statType == 'defense' &&
              (trait.effect.type == EffectType.shield ||
                  trait.effect.type == EffectType.buff)) {
            total += (trait.effect.value ~/ 4).clamp(0, 8);
          } else if (statType == 'speed' && trait.effect.type == EffectType.heal) {
            total += 3;
          }
        }
      }
    }
    return total;
  }

  /// Get color for effect type
  Color _getEffectTypeColor(EffectType type) {
    switch (type) {
      case EffectType.damage:
        return Colors.red.shade500;
      case EffectType.heal:
        return Colors.green.shade500;
      case EffectType.shield:
      case EffectType.buff:
        return Colors.blue.shade500;
      case EffectType.debuff:
        return Colors.purple.shade500;
      default:
        return Colors.grey.shade500;
    }
  }
}

// ── Stat Badge Widget ─────────────────────────────────────────────────────────

class _StatBadge extends StatelessWidget {
  final String icon;
  final String label;
  final int value;

  const _StatBadge({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          icon,
          style: const TextStyle(fontSize: 20),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 9, color: Colors.grey),
        ),
        Text(
          '$value',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
