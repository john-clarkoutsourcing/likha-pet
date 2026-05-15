import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/router/app_router.dart';
import '../../battle/screens/battle_screen.dart';
import '../../pets/providers/player_provider.dart';
import '../providers/pet_inventory_provider.dart';
import '../models/pet_model.dart';
import '../widgets/egg_card.dart';
import '../widgets/hatch_animation_dialog.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Redirect new players (no pets yet) to the starter pack screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final player = ref.read(playerProvider);
      if (player.roster.isEmpty && mounted) {
        context.go(Routes.starterPack);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final player = ref.watch(playerProvider);
    final eggsAsync = ref.watch(eggsProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),

              // ── Title ──────────────────────────────────────────────────────
              const Text(
                'Likha Pet',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
              const Text(
                'Filipino-inspired AI Pet Strategy',
                style: TextStyle(
                  color: AppColors.secondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),

              // ── Starter Pack Eggs Section ──────────────────────────────────
              eggsAsync.when(
                data: (eggs) {
                  if (eggs.isNotEmpty) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your Starter Pack (${eggs.length} Eggs)',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.8,
                          ),
                          itemCount: eggs.length,
                          itemBuilder: (context, index) {
                            final egg = eggs[index];
                            return _EggCardContainer(
                              egg: egg,
                              onHatchPressed: () async {
                                await _handleHatchEgg(context, ref, egg.id);
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                      ],
                    );
                  }
                  return const SizedBox.shrink();
                },
                loading: () => Container(
                  padding: const EdgeInsets.all(24),
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (_, __) => const SizedBox.shrink(),
              ),

              // ── Menu ───────────────────────────────────────────────────────
              const Text(
                'Main Menu',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),
              _MenuButton(
                icon: '🐾',
                label: 'My Pets',
                subtitle: 'Roster · Team builder',
                color: const Color(0xFF9C27B0),
                onTap: () => context.push(Routes.roster),
              ),
              const SizedBox(height: 10),

              _MenuButton(
                icon: '⚔',
                label: 'Quick Battle (PvE)',
                subtitle: player.hasFullTeam ? 'My Team  vs  Rivals' : 'Set up a team first',
                color:
                    player.hasFullTeam ? AppColors.primary : Colors.white24,
                onTap: player.hasFullTeam
                    ? () => context.push(
                          Routes.battle,
                          extra: const BattleScreenArgs(
                            playerTeamName: 'My Team',
                            enemyTeamName: 'Rivals',
                          ),
                        )
                    : () => context.go(Routes.roster),
              ),
              const SizedBox(height: 10),

              _MenuButton(
                icon: '🗺',
                label: 'Adventure Mode',
                subtitle: 'PvE stages — Coming soon',
                color: AppColors.accent,
                onTap: () => context.push(Routes.worldMap),
              ),
              const SizedBox(height: 10),

              _MenuButton(
                icon: '🧪',
                label: 'Test Battle Lab',
                subtitle: 'Debug traits, body parts & animations',
                color: const Color(0xFF7C3AED),
                onTap: () => context.go(Routes.testBattle),
              ),
              const SizedBox(height: 24),

              // ── Phase label ────────────────────────────────────────────────
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Text(
                    'Phase 2  ·  ${player.roster.length} pets',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleHatchEgg(
    BuildContext context,
    WidgetRef ref,
    String petId,
  ) async {
    try {
      final notifier = ref.read(petInventoryProvider.notifier);
      final currentState = ref.read(petInventoryProvider);
      
      PetModel? eggToHatch;

      // Extract egg from async state
      currentState.whenData((pets) {
        try {
          eggToHatch = pets.firstWhere(
            (pet) => pet.id == petId && pet.isEgg,
          );
        } catch (e) {
          // Egg not found
        }
      });

      if (!context.mounted || eggToHatch == null) return;

      // Show hatching animation dialog
      if (!context.mounted) return;
      
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          return HatchAnimationDialog(
            egg: eggToHatch!,
            onHatchComplete: () async {
              // Perform the actual hatch API call after animation
              try {
                final hatchedPet = await notifier.hatchEgg(petId);

                if (context.mounted && hatchedPet != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${hatchedPet.name} hatched successfully! 🎉'),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 2),
                    ),
                  );
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
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _EggCardContainer extends ConsumerWidget {
  final dynamic egg;
  final VoidCallback onHatchPressed;

  const _EggCardContainer({
    required this.egg,
    required this.onHatchPressed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Stack(
      children: [
        EggCard(
          egg: egg,
          onTap: onHatchPressed,
        ),
        // Hatch button overlay
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.8),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: GestureDetector(
              onTap: onHatchPressed,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.favorite, color: Colors.red, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'Tap to Hatch',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
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

class _MenuButton extends StatelessWidget {
  final String icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _MenuButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(icon, style: const TextStyle(fontSize: 20)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right,
                  color: AppColors.textMuted, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
