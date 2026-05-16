import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/router/app_router.dart';
import '../../battle/screens/battle_screen.dart';
import '../../auth/providers/auth_provider.dart';
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
    final userId = ref.watch(userIdProvider) ?? '—';
    final userEmail = ref.watch(userEmailProvider) ?? '—';

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Left panel: branding + eggs ────────────────────────────────
            SizedBox(
              width: 240,
              child: Container(
                decoration: const BoxDecoration(
                  border: Border(right: BorderSide(color: Color(0xFF1A1F35))),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Likha Pet',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
                          ),
                          const Text(
                            'Filipino-inspired Pet Strategy',
                            style: TextStyle(
                              color: AppColors.secondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.divider),
                            ),
                            child: Text(
                              'Phase 2  ·  ${player.roster.length} pets',
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 10,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),
                    const Divider(height: 1, color: Color(0xFF1A1F35)),
                    const SizedBox(height: 8),

                    // Eggs section (scrollable)
                    Expanded(
                      child: eggsAsync.when(
                        data: (eggs) {
                          if (eggs.isEmpty) {
                            return const Center(
                              child: Text('No pending eggs',
                                  style: TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 11)),
                            );
                          }
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20),
                                child: Text(
                                  'Starter Eggs (${eggs.length})',
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Expanded(
                                child: GridView.builder(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: 8,
                                    mainAxisSpacing: 8,
                                    childAspectRatio: 0.82,
                                  ),
                                  itemCount: eggs.length,
                                  itemBuilder: (context, index) {
                                    final egg = eggs[index];
                                    return _EggCardContainer(
                                      egg: egg,
                                      onHatchPressed: () async {
                                        await _handleHatchEgg(
                                            context, ref, egg.id);
                                      },
                                    );
                                  },
                                ),
                              ),
                            ],
                          );
                        },
                        loading: () => const Center(
                            child: CircularProgressIndicator()),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Right panel: scrollable menu buttons ───────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Profile (Debug)',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          userEmail,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        SelectableText(
                          'UID: $userId',
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 10,
                          ),
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Main Menu',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _MenuButton(
                    icon: '🐾',
                    label: 'My Pets',
                    subtitle: 'Roster · Team builder',
                    color: const Color(0xFF9C27B0),
                    onTap: () => context.push(Routes.roster),
                  ),
                  const SizedBox(height: 8),
                  _MenuButton(
                    icon: '🤺',
                    label: 'Arena (PvP)',
                    subtitle: 'Real-time · MMR ladder',
                    color: const Color(0xFFEF5350),
                    onTap: () => context.push(Routes.pvpQueue),
                  ),
                  const SizedBox(height: 8),
                  _MenuButton(
                    icon: '⚔',
                    label: 'Quick Battle (PvE)',
                    subtitle: player.hasFullTeam
                        ? 'My Team  vs  Rivals'
                        : 'Set up a team first',
                    color: player.hasFullTeam
                        ? AppColors.primary
                        : Colors.white24,
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
                  const SizedBox(height: 8),
                  _MenuButton(
                    icon: '🗺',
                    label: 'Adventure Mode',
                    subtitle: 'PvE stages — Coming soon',
                    color: AppColors.accent,
                    onTap: () => context.push(Routes.worldMap),
                  ),
                  const SizedBox(height: 8),
                  _MenuButton(
                    icon: '📖',
                    label: 'Library',
                    subtitle: 'Parts · Classes · Skills',
                    color: const Color(0xFF26C6DA),
                    onTap: () => context.push(Routes.library),
                  ),
                  const SizedBox(height: 8),
                  _MenuButton(
                    icon: '🧪',
                    label: 'Test Battle Lab',
                    subtitle: 'Debug traits, body parts & animations',
                    color: const Color(0xFF7C3AED),
                    onTap: () => context.go(Routes.testBattle),
                  ),
                ],
              ),
            ),
          ],
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
