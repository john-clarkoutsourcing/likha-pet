import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../battle/data/creature_registry.dart';
import '../../battle/screens/battle_screen.dart';
import '../models/owned_pet.dart';
import '../models/team_composition.dart';
import '../providers/player_provider.dart';

// ── Shared helpers ─────────────────────────────────────────────────────────────

Color _clsColor(String cls) => switch (cls) {
      'plant'   => const Color(0xFF4CAF50),
      'aquatic' => const Color(0xFF29B6F6),
      'beast'   => const Color(0xFFFF9800),
      'reptile' => const Color(0xFF66BB6A),
      'bird'    => const Color(0xFFFF80AB),
      'bug'     => const Color(0xFFFF5252),
      _         => const Color(0xFF9C27B0),
    };

// FRONT / MID / BACK visual identity
const _kPositionColors = [
  Color(0xFFFF5252), // FRONT — red (defender)
  Color(0xFFFFD740), // MID   — gold (fighter)
  Color(0xFF69F0AE), // BACK  — green (support)
];
const _kPositionIcons = [
  Icons.shield_rounded,       // FRONT
  Icons.bolt,                 // MID
  Icons.auto_fix_high,        // BACK
];
const _kPositionLabels = ['FRONT', 'MID', 'BACK'];
const _kPositionRoles  = ['Defender', 'Fighter', 'Support'];

// ── Screen ────────────────────────────────────────────────────────────────────

class PetRosterScreen extends ConsumerStatefulWidget {
  const PetRosterScreen({super.key});

  @override
  ConsumerState<PetRosterScreen> createState() => _PetRosterScreenState();
}

class _PetRosterScreenState extends ConsumerState<PetRosterScreen> {
  int? _selectedSlot; // 0=FRONT 1=MID 2=BACK while picking

  @override
  Widget build(BuildContext context) {
    final playerData = ref.watch(playerProvider);
    final roster     = playerData.roster;
    final activeTeam = playerData.activeTeam;

    // Name of the currently-loaded saved team (if any)
    final loadedTeam = playerData.savedTeams.cast<TeamComposition?>()
        .firstWhere(
          (t) =>
              t != null &&
              t.petUids.length == activeTeam.length &&
              List.generate(
                activeTeam.length,
                (i) => t.petUids[i] == activeTeam[i],
              ).every((b) => b),
          orElse: () => null,
        );

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ────────────────────────────────────────────────────────
            _Header(crystals: playerData.soulCrystals),

            // ── Active team section ───────────────────────────────────────────
            _ActiveTeamSection(
              activeTeam:   activeTeam,
              playerData:   playerData,
              selectedSlot: _selectedSlot,
              loadedTeam:   loadedTeam,
              onSlotTap:    (i) => setState(
                () => _selectedSlot = _selectedSlot == i ? null : i,
              ),
              onSaveTap: () => _showSaveTeamDialog(context, ref, playerData),
              onManageTap: () => _showTeamManagementDialog(context, ref),
            ),

            // Pick-mode hint
            if (_selectedSlot != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 2),
                child: Row(
                  children: [
                    Icon(
                      _kPositionIcons[_selectedSlot!],
                      size: 14,
                      color: _kPositionColors[_selectedSlot!],
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Tap a pet below to assign to ${_kPositionLabels[_selectedSlot!]}',
                      style: TextStyle(
                        color: _kPositionColors[_selectedSlot!],
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => setState(() => _selectedSlot = null),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),

            Divider(color: Colors.white10, height: 12),

            // ── Roster label ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'MY PETS  (${roster.length})',
                style: GoogleFonts.rajdhani(
                  color: Colors.white38,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
            ),

            // ── Pet grid ──────────────────────────────────────────────────────
            Expanded(
              child: roster.isEmpty
                  ? _EmptyState()
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 100),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.75,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: roster.length,
                      itemBuilder: (_, i) {
                        final pet = roster[i];
                        final slotIdx = activeTeam.indexOf(pet.uid); // -1 if not in team
                        return _PetCard(
                          pet:        pet,
                          slotIndex:  slotIdx, // -1 = not in team
                          isPickMode: _selectedSlot != null,
                          onTap: () {
                            if (_selectedSlot != null) {
                              _assignToSlot(pet.uid, _selectedSlot!);
                            }
                          },
                          onRenameTap: () => _showRenamePetDialog(
                            context, ref, pet.uid, pet.name,
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),

      // ── Bottom action buttons ─────────────────────────────────────────────
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: playerData.hasFullTeam
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _selectedSlot != null
                      ? null
                      : () => context.push(
                            Routes.battle,
                            extra: BattleScreenArgs(
                              playerTeamName:
                                  loadedTeam?.name ?? 'My Team',
                              enemyTeamName: 'Rivals',
                            ),
                          ),
                  icon: const Text('⚔', style: TextStyle(fontSize: 20)),
                  label: Text(
                    'Battle',
                    style: GoogleFonts.rajdhani(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedSlot != null
                        ? Colors.white12
                        : AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  // ── Slot assignment ─────────────────────────────────────────────────────────

  void _assignToSlot(String petUid, int slot) {
    final current = List<String>.from(
      ref.read(playerProvider).activeTeam.take(3),
    );
    while (current.length < 3) { current.add(''); }
    // Remove from existing slot
    for (var i = 0; i < current.length; i++) {
      if (current[i] == petUid) current[i] = '';
    }
    current[slot] = petUid;
    final filled = current.where((u) => u.isNotEmpty).toList();
    ref.read(playerProvider.notifier).setActiveTeam(
          filled.length == 3 ? filled : filled,
        );
    setState(() => _selectedSlot = null);
  }

  // ── Dialogs ─────────────────────────────────────────────────────────────────

  void _showSaveTeamDialog(
    BuildContext context,
    WidgetRef ref,
    playerData,
  ) {
    final roster     = playerData.roster as List<OwnedPet>;
    final activeTeam = playerData.activeTeam as List<String>;
    final petClasses = activeTeam
        .map((uid) => roster.firstWhere((p) => p.uid == uid))
        .map((p) => p.classLabel.isNotEmpty ? p.classLabel[0].toUpperCase() : '?')
        .join('');
    final defaultName = petClasses.isNotEmpty ? petClasses : 'Team';
    final ctrl = TextEditingController(text: defaultName);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Row(
          children: [
            const Text('💾', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Text(
              'Save Team',
              style: GoogleFonts.rajdhani(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Team name',
              style: GoogleFonts.rajdhani(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: ctrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: defaultName,
                filled: true,
                fillColor: AppColors.bg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              style: const TextStyle(color: Colors.white),
              maxLength: 20,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final name =
                  ctrl.text.trim().isEmpty ? defaultName : ctrl.text.trim();
              ref.read(playerProvider.notifier).saveTeamComposition(name);
              ctrl.dispose();
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Team "$name" saved!'),
                  backgroundColor: AppColors.primary,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showTeamManagementDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.surface,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: _TeamManagementDialog(
          onClose: () => Navigator.of(ctx).pop(),
          onLoad: () {
            Navigator.of(ctx).pop();
            setState(() => _selectedSlot = null);
          },
          onRename: (teamId, name) =>
              _showRenameTeamDialog(context, ref, teamId, name),
        ),
      ),
    );
  }

  void _showRenameTeamDialog(
    BuildContext context,
    WidgetRef ref,
    String teamId,
    String currentName,
  ) {
    final ctrl = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Rename Team'),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(
            hintText: 'Team name',
            filled: true,
            fillColor: AppColors.bg,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          style: const TextStyle(color: Colors.white),
          autofocus: true,
          maxLength: 20,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newName = ctrl.text.trim();
              if (newName.isNotEmpty) {
                ref
                    .read(playerProvider.notifier)
                    .renameTeamComposition(teamId, newName);
                ctrl.dispose();
                Navigator.of(ctx).pop();
                setState(() {});
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary),
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  void _showRenamePetDialog(
    BuildContext context,
    WidgetRef ref,
    String petUid,
    String currentName,
  ) {
    final ctrl = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Row(
          children: [
            const Icon(Icons.drive_file_rename_outline,
                color: Colors.amberAccent, size: 20),
            const SizedBox(width: 8),
            const Text('Rename Pet',
                style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(
            hintText: 'Pet name',
            filled: true,
            fillColor: AppColors.bg,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          style: const TextStyle(color: Colors.white),
          autofocus: true,
          maxLength: 20,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newName = ctrl.text.trim();
              if (newName.isNotEmpty) {
                ref.read(playerProvider.notifier).renamePet(petUid, newName);
                ctrl.dispose();
                Navigator.of(ctx).pop();
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary),
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final int crystals;
  const _Header({required this.crystals});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 12, 4),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white70),
              onPressed: () => context.pop(),
            ),
            Text(
              'My Pets',
              style: GoogleFonts.rajdhani(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF1A2535),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('💎', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 4),
                  Text(
                    '$crystals',
                    style: const TextStyle(
                      color: Color(0xFF44BBFF),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => context.push(Routes.breed),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF9C27B0).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF9C27B0).withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🧬', style: TextStyle(fontSize: 12)),
                    const SizedBox(width: 4),
                    Text(
                      'Breed',
                      style: GoogleFonts.rajdhani(
                        color: const Color(0xFFCE93D8),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
}

// ── Active Team Section ───────────────────────────────────────────────────────

class _ActiveTeamSection extends ConsumerWidget {
  final List<String>        activeTeam;
  final dynamic             playerData;
  final int?                selectedSlot;
  final TeamComposition?    loadedTeam;
  final void Function(int)  onSlotTap;
  final VoidCallback        onSaveTap;
  final VoidCallback        onManageTap;

  const _ActiveTeamSection({
    required this.activeTeam,
    required this.playerData,
    required this.selectedSlot,
    required this.loadedTeam,
    required this.onSlotTap,
    required this.onSaveTap,
    required this.onManageTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Row: label + team name + save + manage ─────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 12, 6),
          child: Row(
            children: [
              Text(
                'ACTIVE TEAM',
                style: GoogleFonts.rajdhani(
                  color: Colors.white38,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(width: 8),
              if (loadedTeam != null)
                Flexible(
                  child: Text(
                    '· ${loadedTeam!.name}',
                    style: GoogleFonts.rajdhani(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              const Spacer(),
              // Save button
              _IconChip(
                icon: Icons.save_rounded,
                label: 'Save',
                color: const Color(0xFF69F0AE),
                onTap: onSaveTap,
              ),
              const SizedBox(width: 6),
              // Manage button
              _IconChip(
                icon: Icons.folder_open_rounded,
                label: 'Load',
                color: const Color(0xFFFFD740),
                onTap: onManageTap,
              ),
            ],
          ),
        ),

        // ── FRONT / MID / BACK slots ───────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Row(
            children: List.generate(3, (i) {
              final uid = i < activeTeam.length ? activeTeam[i] : null;
              final pet = uid != null ? playerData.petById(uid) : null;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i < 2 ? 8 : 0),
                  child: _PositionSlot(
                    slotIndex:  i,
                    pet:        pet,
                    isSelected: selectedSlot == i,
                    onTap:      () => onSlotTap(i),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

// ── Small chip button ─────────────────────────────────────────────────────────

class _IconChip extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Color    color;
  final VoidCallback onTap;

  const _IconChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.rajdhani(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      );
}

// ── Position slot (FRONT / MID / BACK) ───────────────────────────────────────

class _PositionSlot extends StatelessWidget {
  final int      slotIndex;
  final OwnedPet? pet;
  final bool     isSelected;
  final VoidCallback onTap;

  const _PositionSlot({
    required this.slotIndex,
    required this.pet,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final posColor = _kPositionColors[slotIndex];
    final posIcon  = _kPositionIcons[slotIndex];
    final posLabel = _kPositionLabels[slotIndex];
    final posRole  = _kPositionRoles[slotIndex];

    final empty = pet == null;
    final cls   = empty ? '' : (kBodyCatalogue[pet!.bodyId]?.className ?? '');
    final petColor = empty ? posColor : _clsColor(cls);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: isSelected
              ? posColor.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? posColor
                : posColor.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: posColor.withValues(alpha: 0.25), blurRadius: 8)]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Position banner ────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 5),
              decoration: BoxDecoration(
                color: posColor.withValues(alpha: isSelected ? 0.25 : 0.12),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(11),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(posIcon, size: 11, color: posColor),
                  const SizedBox(width: 4),
                  Text(
                    posLabel,
                    style: GoogleFonts.rajdhani(
                      color: posColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),

            // ── Pet content / empty ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              child: empty
                  ? Column(
                      children: [
                        Icon(posIcon,
                            size: 24,
                            color: posColor.withValues(alpha: 0.25)),
                        const SizedBox(height: 2),
                        Text(
                          posRole,
                          style: TextStyle(
                            color: posColor.withValues(alpha: 0.35),
                            fontSize: 9,
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        // Class icon
                        Image.asset(
                          'assets/images/icons/mini-$cls.png',
                          width: 26,
                          height: 26,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.pets,
                            size: 20,
                            color: petColor.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                pet!.name,
                                style: GoogleFonts.rajdhani(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                pet!.classLabel.toUpperCase(),
                                style: TextStyle(
                                  color: petColor,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Pet grid card ─────────────────────────────────────────────────────────────

class _PetCard extends StatelessWidget {
  final OwnedPet pet;
  final int      slotIndex;  // -1 = not in team; 0/1/2 = FRONT/MID/BACK
  final bool     isPickMode;
  final VoidCallback onTap;
  final VoidCallback onRenameTap;

  const _PetCard({
    required this.pet,
    required this.slotIndex,
    required this.isPickMode,
    required this.onTap,
    required this.onRenameTap,
  });

  bool get _inTeam => slotIndex >= 0;

  @override
  Widget build(BuildContext context) {
    final body  = kBodyCatalogue[pet.bodyId];
    final cls   = body?.className ?? 'beast';
    final color = _clsColor(cls);
    final stats = pet.toCreatureDefinition().computedStats;

    final posColor = _inTeam ? _kPositionColors[slotIndex] : null;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: const Color(0xFF111A28),
          border: Border.all(
            color: isPickMode
                ? color
                : _inTeam
                    ? posColor!.withValues(alpha: 0.6)
                    : color.withValues(alpha: 0.3),
            width: _inTeam ? 2 : 1,
          ),
          boxShadow: _inTeam
              ? [BoxShadow(color: posColor!.withValues(alpha: 0.3), blurRadius: 10)]
              : isPickMode
                  ? [BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 8)]
                  : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Image area ─────────────────────────────────────────────────
            Expanded(
              child: Stack(
                children: [
                  // Gradient background
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(13),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            color.withValues(alpha: 0.22),
                            color.withValues(alpha: 0.07),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Class icon
                  Center(
                    child: Image.asset(
                      'assets/images/icons/$cls.png',
                      width: 68,
                      height: 68,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.pets,
                        size: 48,
                        color: color.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                  // Purity badge (top-left)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        pet.purityLabel,
                        style: TextStyle(
                          color: pet.purity == 4
                              ? Colors.amberAccent
                              : Colors.white60,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  // Position badge (top-right) — FRONT / MID / BACK pill
                  if (_inTeam)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: posColor!.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: posColor.withValues(alpha: 0.5),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _kPositionIcons[slotIndex],
                              size: 9,
                              color: Colors.black87,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              _kPositionLabels[slotIndex],
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ── Info strip ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 5, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name row + rename button
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          pet.name,
                          style: GoogleFonts.rajdhani(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Visible rename icon
                      GestureDetector(
                        onTap: onRenameTap,
                        child: const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Icon(
                            Icons.drive_file_rename_outline,
                            size: 13,
                            color: Colors.white30,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  // Part dots + stats
                  Row(
                    children: [
                      _partDot(pet.hornId),
                      const SizedBox(width: 3),
                      _partDot(pet.backId),
                      const SizedBox(width: 3),
                      _partDot(pet.tailId),
                      const SizedBox(width: 3),
                      _partDot(pet.mouthId),
                      const Spacer(),
                      Icon(Icons.favorite,
                          size: 9, color: const Color(0xFF66FF88)),
                      const SizedBox(width: 2),
                      Text(
                        '${stats.hp}',
                        style: const TextStyle(
                          color: Color(0xFF66FF88),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Icon(Icons.bolt,
                          size: 9, color: const Color(0xFFFFCC44)),
                      const SizedBox(width: 2),
                      Text(
                        '${stats.speed}',
                        style: const TextStyle(
                          color: Color(0xFFFFCC44),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _partDot(String partId) {
    final part  = kPartCatalogue[partId];
    final color = part != null ? _clsColor(part.className) : Colors.white24;
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.8),
        border: Border.all(color: color, width: 0.5),
      ),
    );
  }
}

// ── Team Management Dialog ────────────────────────────────────────────────────

class _TeamManagementDialog extends ConsumerWidget {
  final VoidCallback onClose;
  final VoidCallback onLoad;
  final void Function(String teamId, String name) onRename;

  const _TeamManagementDialog({
    required this.onClose,
    required this.onLoad,
    required this.onRename,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerData = ref.watch(playerProvider);
    final savedTeams = playerData.savedTeams;

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.6,
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 12),
            child: Row(
              children: [
                const Icon(Icons.folder_open_rounded,
                    color: Color(0xFFFFD740), size: 20),
                const SizedBox(width: 8),
                Text(
                  'Saved Teams',
                  style: GoogleFonts.rajdhani(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: onClose,
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white10, height: 1),

          // Team list
          Expanded(
            child: savedTeams.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.bookmark_border,
                            size: 40, color: Colors.white24),
                        const SizedBox(height: 12),
                        Text(
                          'No saved teams yet',
                          style: GoogleFonts.rajdhani(
                            color: Colors.white38,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Use the Save button on the roster\nto save your current team',
                          style: TextStyle(
                              color: Colors.white24, fontSize: 11),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: savedTeams.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 8),
                    itemBuilder: (ctx, i) {
                      final team     = savedTeams[i];
                      final teamPets = team.petUids
                          .map((uid) => playerData.petById(uid))
                          .whereType<OwnedPet>()
                          .toList();
                      return _SavedTeamCard(
                        team:     team,
                        teamPets: teamPets,
                        onLoad: () {
                          ref
                              .read(playerProvider.notifier)
                              .loadTeamComposition(team.id);
                          onLoad();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Loaded: ${team.name}'),
                              duration: const Duration(seconds: 2),
                              backgroundColor: AppColors.primary,
                            ),
                          );
                        },
                        onRename: () => onRename(team.id, team.name),
                        onDelete: () => ref
                            .read(playerProvider.notifier)
                            .deleteTeamComposition(team.id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Saved team card ───────────────────────────────────────────────────────────

class _SavedTeamCard extends StatelessWidget {
  final TeamComposition team;
  final List<OwnedPet>  teamPets;
  final VoidCallback    onLoad;
  final VoidCallback    onRename;
  final VoidCallback    onDelete;

  const _SavedTeamCard({
    required this.team,
    required this.teamPets,
    required this.onLoad,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          // Team name + actions
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 4, 6),
            child: Row(
              children: [
                const Icon(Icons.bookmark,
                    size: 14, color: Color(0xFFFFD740)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    team.name,
                    style: GoogleFonts.rajdhani(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.drive_file_rename_outline,
                      size: 16, color: Colors.amberAccent),
                  onPressed: onRename,
                  tooltip: 'Rename',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      size: 16, color: Colors.redAccent),
                  onPressed: onDelete,
                  tooltip: 'Delete',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),

          // FRONT / MID / BACK pet preview
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            child: Row(
              children: List.generate(3, (i) {
                final pet      = i < teamPets.length ? teamPets[i] : null;
                final posColor = _kPositionColors[i];
                final posIcon  = _kPositionIcons[i];
                final posLabel = _kPositionLabels[i];
                final cls      = pet != null
                    ? (kBodyCatalogue[pet.bodyId]?.className ?? '')
                    : '';
                final petColor = pet != null ? _clsColor(cls) : posColor;

                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: i < 2 ? 6 : 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 6),
                      decoration: BoxDecoration(
                        color: posColor.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: posColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        children: [
                          // Position label
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(posIcon, size: 9, color: posColor),
                              const SizedBox(width: 3),
                              Text(
                                posLabel,
                                style: TextStyle(
                                  color: posColor,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          // Class icon
                          if (pet != null)
                            Image.asset(
                              'assets/images/icons/mini-$cls.png',
                              width: 24,
                              height: 24,
                              errorBuilder: (_, __, ___) => Icon(
                                Icons.pets,
                                size: 18,
                                color: petColor.withValues(alpha: 0.5),
                              ),
                            )
                          else
                            Icon(Icons.remove_circle_outline,
                                size: 18,
                                color: posColor.withValues(alpha: 0.2)),
                          const SizedBox(height: 3),
                          // Pet name
                          Text(
                            pet?.name ?? '—',
                            style: TextStyle(
                              color: pet != null
                                  ? Colors.white70
                                  : Colors.white24,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),

          // Load button
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            child: SizedBox(
              width: double.infinity,
              height: 36,
              child: ElevatedButton.icon(
                onPressed: onLoad,
                icon: const Icon(Icons.play_arrow_rounded, size: 16),
                label: Text(
                  'Load Team',
                  style: GoogleFonts.rajdhani(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🥚', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(
              'No pets yet',
              style: GoogleFonts.rajdhani(
                color: Colors.white38,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Hatch an egg to get started',
              style: TextStyle(color: Colors.white24, fontSize: 12),
            ),
          ],
        ),
      );
}
