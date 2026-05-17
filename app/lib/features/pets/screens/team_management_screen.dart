import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../models/owned_pet.dart';
import '../models/team_composition.dart';
import '../providers/player_provider.dart';
import '../widgets/team_position_display.dart';

/// Manage saved team compositions
class TeamManagementScreen extends ConsumerStatefulWidget {
  const TeamManagementScreen({super.key});

  @override
  ConsumerState<TeamManagementScreen> createState() =>
      _TeamManagementScreenState();
}

class _TeamManagementScreenState extends ConsumerState<TeamManagementScreen> {
  String? _editingTeamId;
  late TextEditingController _nameController;

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

  void _startEdit(TeamComposition team) {
    setState(() {
      _editingTeamId = team.id;
      _nameController.text = team.name;
    });
  }

  void _cancelEdit() {
    setState(() {
      _editingTeamId = null;
      _nameController.clear();
    });
  }

  void _saveEdit(String teamId) {
    final newName = _nameController.text.trim();
    if (newName.isNotEmpty) {
      ref
          .read(playerProvider.notifier)
          .renameTeamComposition(teamId, newName);
    }
    _cancelEdit();
  }

  @override
  Widget build(BuildContext context) {
    final playerData = ref.watch(playerProvider);
    final teams = playerData.savedTeams;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Team Presets',
          style: GoogleFonts.rajdhani(
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: Text(
                '${teams.length} teams',
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
      body: teams.isEmpty
          ? _EmptyState()
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: teams.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _TeamCard(
                team: teams[i],
                roster: playerData.roster,
                isEditing: _editingTeamId == teams[i].id,
                nameController: _nameController,
                onStartEdit: () => _startEdit(teams[i]),
                onCancelEdit: _cancelEdit,
                onSaveEdit: () => _saveEdit(teams[i].id),
                onLoad: () {
                  ref.read(playerProvider.notifier).loadTeamComposition(teams[i].id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content:
                          Text('Loaded team: ${teams[i].name}'),
                      backgroundColor: AppColors.primary,
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
                onDelete: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: AppColors.surface,
                      title: const Text('Delete Team?'),
                      content: Text(
                        'Are you sure you want to delete "${teams[i].name}"?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => ctx.pop(),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () {
                            ref
                                .read(playerProvider.notifier)
                                .deleteTeamComposition(teams[i].id);
                            ctx.pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Deleted "${teams[i].name}"'),
                                backgroundColor: Colors.red,
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          },
                          child: const Text(
                            'Delete',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }
}

/// Team card with position display
class _TeamCard extends StatelessWidget {
  final TeamComposition team;
  final List<OwnedPet> roster;
  final bool isEditing;
  final TextEditingController nameController;
  final VoidCallback onStartEdit;
  final VoidCallback onCancelEdit;
  final VoidCallback onSaveEdit;
  final VoidCallback onLoad;
  final VoidCallback onDelete;

  const _TeamCard({
    required this.team,
    required this.roster,
    required this.isEditing,
    required this.nameController,
    required this.onStartEdit,
    required this.onCancelEdit,
    required this.onSaveEdit,
    required this.onLoad,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
        color: AppColors.surface.withValues(alpha: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with team name and actions
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: Row(
              children: [
                Expanded(
                  child: isEditing
                      ? TextField(
                          controller: nameController,
                          decoration: InputDecoration(
                            hintText: 'Team name',
                            filled: true,
                            fillColor: AppColors.bg,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  const BorderSide(color: AppColors.divider),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                          ),
                          autofocus: true,
                        )
                      : Text(
                          team.name,
                          style: GoogleFonts.rajdhani(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                ),
                if (isEditing)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check, color: Colors.green),
                        onPressed: onSaveEdit,
                        tooltip: 'Save',
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: onCancelEdit,
                        tooltip: 'Cancel',
                      ),
                    ],
                  )
                else
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon:
                            const Icon(Icons.edit, color: AppColors.textMuted),
                        onPressed: onStartEdit,
                        tooltip: 'Rename',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete,
                            color: Colors.red),
                        onPressed: onDelete,
                        tooltip: 'Delete',
                      ),
                    ],
                  ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFF1A2535)),

          // Position display
          Padding(
            padding: const EdgeInsets.all(12),
            child: TeamPositionDisplay(
              team: team,
              roster: roster,
            ),
          ),

          // Action buttons
          if (!isEditing)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onLoad,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Load Team'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Empty state when no teams saved
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.layers_outlined,
                size: 64, color: Colors.white24),
            const SizedBox(height: 16),
            Text(
              'No Team Presets Yet',
              style: GoogleFonts.rajdhani(
                color: Colors.white70,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Build a team in My Pets and save it\nto quickly switch between formations',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
}
