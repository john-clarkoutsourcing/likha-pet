import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../models/pet_model.dart';
import '../providers/pet_inventory_provider.dart';
import '../widgets/pet_sprite_display.dart';

/// Pet Detail Screen - shows full pet information
class PetDetailScreen extends ConsumerStatefulWidget {
  final String petId;

  const PetDetailScreen({
    super.key,
    required this.petId,
  });

  @override
  ConsumerState<PetDetailScreen> createState() => _PetDetailScreenState();
}

class _PetDetailScreenState extends ConsumerState<PetDetailScreen> {
  late TextEditingController _nameController;
  bool _isEditing = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final petsAsync = ref.watch(petInventoryProvider);

    return petsAsync.when(
      data: (allPets) {
        final pet = allPets.where((p) => p.id == widget.petId).firstOrNull;

        if (pet == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Pet Not Found')),
            body: const Center(child: Text('Pet not found')),
          );
        }

        // Initialize name controller if empty
        if (_nameController.text.isEmpty) {
          _nameController.text = pet.name;
        }

        return Scaffold(
          backgroundColor: AppColors.bg,
          appBar: AppBar(
            backgroundColor: AppColors.surface,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.pop(),
            ),
            title: const Text('Pet Details'),
            actions: [
              if (!_isEditing)
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => setState(() => _isEditing = true),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Center(
                    child: TextButton(
                      onPressed: _isSaving ? null : () => _saveName(ref, pet),
                      child: const Text(
                        'Save',
                        style: TextStyle(color: AppColors.primary),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Pet Card ────────────────────────────────────────────────
                _PetHero(pet: pet),
                const SizedBox(height: 32),

                // ── Sprite Display (DNA-based) ──────────────────────────────
                Center(
                  child: PetSpriteDisplay(
                    pet: pet,
                    size: 140,
                  ),
                ),
                const SizedBox(height: 32),

                // ── Pet Name (Editable) ──────────────────────────────────────
                _NameSection(
                  name: pet.name,
                  isEditing: _isEditing,
                  controller: _nameController,
                  onEditCancel: () => setState(() {
                    _isEditing = false;
                    _nameController.text = pet.name;
                  }),
                ),
                const SizedBox(height: 28),

                // ── DNA Info ─────────────────────────────────────────────────
                _InfoSection(
                  title: 'DNA',
                  children: [
                    _InfoRow(
                      label: 'DNA Code',
                      value: pet.dna,
                    ),
                    const Divider(color: AppColors.divider),
                    _InfoRow(
                      label: 'State',
                      value: pet.state,
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // ── Attributes ──────────────────────────────────────────────
                _InfoSection(
                  title: 'Attributes',
                  children: [
                    _InfoRow(
                      label: 'Rarity',
                      value: pet.attributes.rarity,
                    ),
                    const Divider(color: AppColors.divider),
                    _InfoRow(
                      label: 'Element',
                      value: pet.attributes.element,
                    ),
                    const Divider(color: AppColors.divider),
                    _InfoRow(
                      label: 'Base Power',
                      value: '${pet.attributes.basePower}',
                    ),
                    const Divider(color: AppColors.divider),
                    _InfoRow(
                      label: 'Color',
                      value: pet.attributes.color,
                    ),
                    const Divider(color: AppColors.divider),
                    _InfoRow(
                      label: 'Pattern',
                      value: pet.attributes.pattern,
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // ── Timeline ─────────────────────────────────────────────────
                _InfoSection(
                  title: 'Timeline',
                  children: [
                    _InfoRow(
                      label: 'Created',
                      value: _formatDate(pet.createdAt),
                    ),
                    const Divider(color: AppColors.divider),
                    _InfoRow(
                      label: 'Hatch Ready At',
                      value: _formatDate(pet.hatchTime),
                    ),
                  ],
                ),

                const SizedBox(height: 60),
              ],
            ),
          ),
        );
      },
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Loading...')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, st) => Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(child: Text('Error: $error')),
      ),
    );
  }

  Future<void> _saveName(WidgetRef ref, PetModel pet) async {
    final newName = _nameController.text.trim();

    if (newName.isEmpty || newName == pet.name) {
      setState(() => _isEditing = false);
      return;
    }

    setState(() => _isSaving = true);

    try {
      // TODO: Implement API endpoint to rename pet
      // For now, just update locally
      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        setState(() {
          _isEditing = false;
          _isSaving = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pet renamed successfully! ✨'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to rename: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDate(int milliseconds) {
    final date = DateTime.fromMillisecondsSinceEpoch(milliseconds);
    return '${date.month}/${date.day}/${date.year}';
  }
}

/// Hero card showing pet visually
class _PetHero extends StatelessWidget {
  final PetModel pet;

  const _PetHero({required this.pet});

  @override
  Widget build(BuildContext context) {
    final rarityColor = _getRarityColor(pet.attributes.rarity);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            rarityColor.withValues(alpha: 0.2),
            rarityColor.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: rarityColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: rarityColor.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          // Pet emoji
          Text(
            pet.isEgg ? '🥚' : pet.attributes.element,
            style: const TextStyle(fontSize: 96),
          ),
          const SizedBox(height: 16),

          // Pet name
          Text(
            pet.name,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),

          // Rarity and state
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: rarityColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: rarityColor),
                ),
                child: Text(
                  pet.attributes.rarity,
                  style: TextStyle(
                    color: rarityColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primary),
                ),
                child: Text(
                  pet.state,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getRarityColor(String rarity) {
    switch (rarity) {
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

/// Name section with edit capability
class _NameSection extends StatelessWidget {
  final String name;
  final bool isEditing;
  final TextEditingController controller;
  final VoidCallback onEditCancel;

  const _NameSection({
    required this.name,
    required this.isEditing,
    required this.controller,
    required this.onEditCancel,
  });

  @override
  Widget build(BuildContext context) {
    if (isEditing) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Edit Pet Name',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: 'Enter new name',
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.divider),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.divider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary, width: 2),
              ),
            ),
            style: const TextStyle(color: AppColors.textPrimary),
            autofocus: true,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onEditCancel,
                  icon: const Icon(Icons.close),
                  label: const Text('Cancel'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white12,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Pet Name',
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          name,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

/// Generic info section with title
class _InfoSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _InfoSection({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

/// Info row showing label and value
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.right,
          ),
        ],
      ),
    );
  }
}
