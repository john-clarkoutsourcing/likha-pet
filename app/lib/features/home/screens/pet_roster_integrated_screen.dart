import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/router/app_router.dart';
import '../../battle/screens/battle_screen.dart';
import '../../pets/providers/player_provider.dart';
import '../../home/models/pet_model.dart';
import '../../home/providers/pet_inventory_provider.dart';
import '../../home/widgets/hatch_animation_dialog.dart';

/// Integrated Pet Roster - displays real pet data from API
/// Allows team building and pet management
class PetRosterIntegratedScreen extends ConsumerStatefulWidget {
  const PetRosterIntegratedScreen({super.key});

  @override
  ConsumerState<PetRosterIntegratedScreen> createState() =>
      _PetRosterIntegratedScreenState();
}

class _PetRosterIntegratedScreenState
    extends ConsumerState<PetRosterIntegratedScreen> {
  int? _selectedSlot; // which team slot is being reassigned (0/1/2)
  final Set<String> _selectedTeam = {};

  @override
  void initState() {
    super.initState();
    // Initialize team selection from player provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final player = ref.read(playerProvider);
      _selectedTeam.clear();
      _selectedTeam.addAll(player.activeTeam);
    });
  }

  @override
  Widget build(BuildContext context) {
    final petsAsync = ref.watch(petInventoryProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: petsAsync.when(
          data: (allPets) {
            final hatched = allPets.where((p) => p.isHatched).toList();
            final eggs = allPets.where((p) => p.isEgg).toList();

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header ────────────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'My Pets',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${hatched.length} Hatched · ${eggs.length} Eggs',
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Active Team Builder ────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'BATTLE TEAM',
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const Spacer(),
                            if (_selectedSlot != null)
                              Text(
                                'Tap pet to assign to slot ${_selectedSlot! + 1}',
                                style: const TextStyle(
                                  color: Colors.amberAccent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: List.generate(3, (i) {
                            final petId = i < _selectedTeam.length
                                ? _selectedTeam.elementAt(i)
                                : null;
                            final pet = petId != null
                                ? allPets.where((p) => p.id == petId).firstOrNull
                                : null;

                            return Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedSlot =
                                        _selectedSlot == i ? null : i;
                                  });
                                },
                                child: Container(
                                  margin:
                                      EdgeInsets.only(right: i < 2 ? 12 : 0),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: _selectedSlot == i
                                        ? AppColors.primary.withValues(
                                            alpha: 0.3)
                                        : AppColors.surface,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _selectedSlot == i
                                          ? AppColors.primary
                                          : AppColors.divider,
                                      width: _selectedSlot == i ? 2 : 1,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        pet != null ? 'Slot ${i + 1}' : '',
                                        style: const TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      if (pet != null) ...[
                                        Text(
                                          pet.isEgg ? '🥚' : '🧬',
                                          style: const TextStyle(
                                            fontSize: 24,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          pet.name,
                                          style: const TextStyle(
                                            color: AppColors.textPrimary,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          textAlign: TextAlign.center,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ] else ...[
                                        const Text(
                                          '?',
                                          style: TextStyle(
                                            color: AppColors.textMuted,
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        const Text(
                                          'Empty',
                                          style: TextStyle(
                                            color: AppColors.textMuted,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  ),

                  const Divider(color: AppColors.divider),

                  // ── Hatched Pets Section ───────────────────────────────────
                  if (hatched.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                      child: Text(
                        'HATCHED PETS (${hatched.length})',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  if (hatched.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.75,
                        ),
                        itemCount: hatched.length,
                        itemBuilder: (context, index) {
                          final pet = hatched[index];
                          final isSelected = _selectedTeam.contains(pet.id);

                          return _PetCard(
                            pet: pet,
                            isSelected: isSelected,
                            isSelectable: _selectedSlot != null,
                            onTap: () {
                              if (_selectedSlot != null && !pet.isEgg) {
                                setState(() {
                                  _selectedTeam.remove(pet.id);
                                  final teamList = _selectedTeam.toList();
                                  while (teamList.length < 3) {
                                    teamList.add('');
                                  }
                                  teamList[_selectedSlot!] = pet.id;
                                  _selectedTeam.clear();
                                  _selectedTeam.addAll(
                                    teamList
                                        .where((id) => id.isNotEmpty)
                                        .toList(),
                                  );
                                  _selectedSlot = null;
                                });
                              }
                            },
                          );
                        },
                      ),
                    ),

                  // ── Eggs Section ──────────────────────────────────────────
                  if (eggs.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                      child: Text(
                        'EGGS (${eggs.length})',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  if (eggs.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.75,
                        ),
                        itemCount: eggs.length,
                        itemBuilder: (context, index) {
                          final egg = eggs[index];

                          return _EggCard(
                            egg: egg,
                            onHatchPressed: () async {
                              await _showHatchAnimation(context, ref, egg);
                            },
                          );
                        },
                      ),
                    ),

                  const SizedBox(height: 100),
                ],
              ),
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(),
          ),
          error: (error, st) => Center(
            child: Text(
              'Error: $error',
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.surface,
                  foregroundColor: AppColors.textPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _selectedTeam.length == 3
                    ? () async {
                        // Save team and navigate to battle
                        final teamList = _selectedTeam.toList();
                        ref.read(playerProvider.notifier).setActiveTeam(
                              teamList.sublist(0, 3),
                            );

                        if (mounted) {
                          context.push(
                            Routes.battle,
                            extra: const BattleScreenArgs(
                              playerTeamName: 'My Team',
                              enemyTeamName: 'Rivals',
                            ),
                          );
                        }
                      }
                    : null,
                icon: const Icon(Icons.sports_kabaddi),
                label: const Text('Battle'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selectedTeam.length == 3
                      ? AppColors.primary
                      : Colors.white12,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showHatchAnimation(
    BuildContext context,
    WidgetRef ref,
    PetModel egg,
  ) async {
    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return HatchAnimationDialog(
          egg: egg,
          onHatchComplete: () async {
            try {
              final notifier = ref.read(petInventoryProvider.notifier);
              final hatchedPet = await notifier.hatchEgg(egg.id);

              if (context.mounted && hatchedPet != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content:
                        Text('${hatchedPet.name} hatched successfully! 🎉'),
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 2),
                  ),
                );
                // Refresh UI
                setState(() {});
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to hatch: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          },
        );
      },
    );
  }
}

/// Pet Card Widget - shows hatched pet
class _PetCard extends StatelessWidget {
  final PetModel pet;
  final bool isSelected;
  final bool isSelectable;
  final VoidCallback onTap;

  const _PetCard({
    required this.pet,
    required this.isSelected,
    required this.isSelectable,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isSelectable ? onTap : () => context.push(Routes.petDetail.replaceFirst(':petId', pet.id)),
      onLongPress: () => context.push(Routes.petDetail.replaceFirst(':petId', pet.id)),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? _getRarityColor().withValues(alpha: 0.2)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? _getRarityColor() : AppColors.divider,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: _getRarityColor().withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Pet emoji
              Text(
                pet.attributes.element,
                style: const TextStyle(fontSize: 48),
              ),
              const SizedBox(height: 8),

              // Pet name
              Text(
                pet.name,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),

              // Rarity badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: _getRarityColor().withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: _getRarityColor()),
                ),
                child: Text(
                  pet.attributes.rarity,
                  style: TextStyle(
                    color: _getRarityColor(),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Power stat
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    '💪',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${pet.attributes.basePower}',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              // Selection indicator
              if (isSelected)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _getRarityColor(),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '✓ Selected',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getRarityColor() {
    switch (pet.attributes.rarity) {
      case 'Common':
        return Colors.grey;
      case 'Uncommon':
        return Colors.green;
      case 'Rare':
        return Colors.blue;
      case 'Epic':
        return Colors.purple;
      case 'Legendary':
        return Colors.orange;
      default:
        return Colors.white;
    }
  }
}

/// Egg Card Widget - shows egg with hatch button
class _EggCard extends StatelessWidget {
  final PetModel egg;
  final VoidCallback onHatchPressed;

  const _EggCard({
    required this.egg,
    required this.onHatchPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider),
            boxShadow: [
              BoxShadow(
                color: Colors.yellow.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  '🥚',
                  style: TextStyle(fontSize: 48),
                ),
                const SizedBox(height: 8),
                Text(
                  egg.name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.yellow.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.yellow),
                  ),
                  child: const Text(
                    'Ready',
                    style: TextStyle(
                      color: Colors.yellow,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: GestureDetector(
            onTap: onHatchPressed,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.8),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.favorite, color: Colors.red, size: 12),
                  SizedBox(width: 4),
                  Text(
                    'Hatch',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
