import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:likha_pet_battle_engine/trait.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../battle/screens/battle_screen.dart';
import '../../battle/widgets/pet_renderer_widget.dart';
import '../../pets/models/owned_pet.dart';
import '../../pets/models/team_composition.dart';
import '../../pets/providers/player_provider.dart';

// ── Position identity ─────────────────────────────────────────────────────────

const _kPosColors  = [Color(0xFFFF5252), Color(0xFFFFD740), Color(0xFF69F0AE)];
const _kPosIcons   = [Icons.shield_rounded, Icons.bolt, Icons.auto_fix_high];
const _kPosLabels  = ['FRONT', 'MID', 'BACK'];
const _kPosRoles   = ['Defender', 'Fighter', 'Support'];

Color _classColor(CreatureClass cls) => switch (cls) {
  CreatureClass.plant   => const Color(0xFF4CAF50),
  CreatureClass.aquatic => const Color(0xFF29B6F6),
  CreatureClass.beast   => const Color(0xFFFF9800),
  CreatureClass.reptile => const Color(0xFF66BB6A),
  CreatureClass.bird    => const Color(0xFFFF80AB),
  CreatureClass.bug     => const Color(0xFFFF5252),
};

// ── Screen ────────────────────────────────────────────────────────────────────

class PetRosterIntegratedScreen extends ConsumerStatefulWidget {
  const PetRosterIntegratedScreen({super.key});

  @override
  ConsumerState<PetRosterIntegratedScreen> createState() => _State();
}

class _State extends ConsumerState<PetRosterIntegratedScreen> {
  // 3 ordered slots: null = empty, String = petUid
  final List<String?> _slots = [null, null, null];

  // Which slot is being assigned right now (0/1/2), or null
  int? _assigningSlot;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final active = ref.read(playerProvider).activeTeam;
      for (var i = 0; i < 3 && i < active.length; i++) {
        _slots[i] = active[i];
      }
      setState(() {});
    });
  }

  bool get _teamFull => _slots.every((s) => s != null);

  void _assignPet(String uid) {
    if (_assigningSlot == null) return;
    setState(() {
      // Remove pet from any existing slot first
      for (var i = 0; i < 3; i++) {
        if (_slots[i] == uid) _slots[i] = null;
      }
      _slots[_assigningSlot!] = uid;
      // Auto-advance to next empty slot
      final next = _slots.indexWhere((s) => s == null);
      _assigningSlot = next == -1 ? null : next;
    });
  }

  void _clearSlot(int slot) => setState(() {
        _slots[slot] = null;
        _assigningSlot = slot;
      });

  void _saveTeam() {
    if (!_teamFull) return;
    ref.read(playerProvider.notifier).setActiveTeam(
          _slots.whereType<String>().toList(),
        );
  }

  void _battle() {
    _saveTeam();
    final loaded = _loadedTeamName();
    context.push(
      Routes.battle,
      extra: BattleScreenArgs(
        playerTeamName: loaded ?? 'My Team',
        enemyTeamName: 'Rivals',
      ),
    );
  }

  String? _loadedTeamName() {
    final active = _slots.whereType<String>().toList();
    if (active.length != 3) return null;
    return ref.read(playerProvider).savedTeams.cast<TeamComposition?>().firstWhere(
          (t) =>
              t != null &&
              t.petUids.length == 3 &&
              t.petUids[0] == active[0] &&
              t.petUids[1] == active[1] &&
              t.petUids[2] == active[2],
          orElse: () => null,
        )?.name;
  }

  @override
  Widget build(BuildContext context) {
    final player = ref.watch(playerProvider);
    final roster = player.roster;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Left panel: team builder ────────────────────────────────────
            SizedBox(
              width: 190,
              child: _LeftPanel(
                slots:         _slots,
                roster:        roster,
                assigningSlot: _assigningSlot,
                teamFull:      _teamFull,
                loadedName:    _loadedTeamName(),
                onSelectSlot:  (i) => setState(
                  () => _assigningSlot = _assigningSlot == i ? null : i,
                ),
                onClearSlot:   _clearSlot,
                onSave:        _saveTeam,
                onBattle:      _battle,
                onBack:        () => context.pop(),
                onSaveNamed:   () => _showSaveDialog(context),
                onLoadTeams:   () => _showLoadDialog(context),
              ),
            ),

            // ── Right panel: pet grid ───────────────────────────────────────
            Expanded(
              child: _PetGrid(
                roster:        roster,
                slots:         _slots,
                assigningSlot: _assigningSlot,
                onTapPet:      _assignPet,
                onRenamePet:   (uid, name) =>
                    _showRenameDialog(context, uid, name),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Dialogs ─────────────────────────────────────────────────────────────────

  void _showSaveDialog(BuildContext context) {
    final roster = ref.read(playerProvider).roster;
    final classes = _slots
        .whereType<String>()
        .map((uid) => roster.firstWhere((p) => p.uid == uid))
        .map((p) => p.classLabel.isNotEmpty
            ? p.classLabel[0].toUpperCase()
            : '?')
        .join('');
    final defaultName = classes.isNotEmpty ? classes : 'Team';
    final ctrl = TextEditingController(text: defaultName);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Row(children: [
          const Icon(Icons.save_rounded, color: Color(0xFF69F0AE), size: 20),
          const SizedBox(width: 8),
          Text('Save Team',
              style: GoogleFonts.rajdhani(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
        ]),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: defaultName,
            filled: true,
            fillColor: AppColors.bg,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.white24)),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 10),
          ),
          style: const TextStyle(color: Colors.white),
          maxLength: 20,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _saveTeam();
              final name = ctrl.text.trim().isEmpty
                  ? defaultName
                  : ctrl.text.trim();
              ref
                  .read(playerProvider.notifier)
                  .saveTeamComposition(name);
              ctrl.dispose();
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Team "$name" saved!'),
                backgroundColor: AppColors.primary,
                duration: const Duration(seconds: 2),
              ));
            },
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showLoadDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.surface,
        insetPadding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: _LoadTeamsDialog(
          onLoad: (teamId) {
            ref
                .read(playerProvider.notifier)
                .loadTeamComposition(teamId);
            final active = ref.read(playerProvider).activeTeam;
            for (var i = 0; i < 3; i++) {
              _slots[i] = i < active.length ? active[i] : null;
            }
            setState(() => _assigningSlot = null);
            Navigator.of(ctx).pop();
          },
          onRename: (teamId, name) {
            Navigator.of(ctx).pop();
            _showRenameTeamDialog(context, teamId, name);
          },
          onDelete: (teamId) {
            ref
                .read(playerProvider.notifier)
                .deleteTeamComposition(teamId);
          },
        ),
      ),
    );
  }

  void _showRenameTeamDialog(
      BuildContext context, String teamId, String current) {
    final ctrl = TextEditingController(text: current);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Rename Team',
            style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Team name',
            filled: true,
            fillColor: AppColors.bg,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
          style: const TextStyle(color: Colors.white),
          maxLength: 20,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final name = ctrl.text.trim();
              if (name.isNotEmpty) {
                ref
                    .read(playerProvider.notifier)
                    .renameTeamComposition(teamId, name);
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

  void _showRenameDialog(
      BuildContext context, String uid, String current) {
    final ctrl = TextEditingController(text: current);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Row(children: [
          const Icon(Icons.drive_file_rename_outline,
              color: Colors.amberAccent, size: 18),
          const SizedBox(width: 8),
          const Text('Rename Pet',
              style: TextStyle(color: Colors.white, fontSize: 16)),
        ]),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Pet name',
            filled: true,
            fillColor: AppColors.bg,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
          style: const TextStyle(color: Colors.white),
          maxLength: 20,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final name = ctrl.text.trim();
              if (name.isNotEmpty) {
                ref.read(playerProvider.notifier).renamePet(uid, name);
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

// ── Left panel ────────────────────────────────────────────────────────────────

class _LeftPanel extends StatelessWidget {
  final List<String?>   slots;
  final List<OwnedPet>  roster;
  final int?            assigningSlot;
  final bool            teamFull;
  final String?         loadedName;
  final void Function(int)    onSelectSlot;
  final void Function(int)    onClearSlot;
  final VoidCallback          onSave;
  final VoidCallback          onBattle;
  final VoidCallback          onBack;
  final VoidCallback          onSaveNamed;
  final VoidCallback          onLoadTeams;

  const _LeftPanel({
    required this.slots,
    required this.roster,
    required this.assigningSlot,
    required this.teamFull,
    required this.loadedName,
    required this.onSelectSlot,
    required this.onClearSlot,
    required this.onSave,
    required this.onBattle,
    required this.onBack,
    required this.onSaveNamed,
    required this.onLoadTeams,
  });

  OwnedPet? _petAt(int slot) {
    final uid = slots[slot];
    if (uid == null) return null;
    return roster.cast<OwnedPet?>().firstWhere(
          (p) => p?.uid == uid,
          orElse: () => null,
        );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: Color(0xFF1A1F35))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header ───────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Row(
              children: [
                GestureDetector(
                  onTap: onBack,
                  child: const Icon(Icons.arrow_back,
                      color: Colors.white38, size: 18),
                ),
                const SizedBox(width: 8),
                Text('My Pets',
                    style: GoogleFonts.rajdhani(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900)),
                const Spacer(),
                // Load saved teams
                GestureDetector(
                  onTap: onLoadTeams,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD740).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: const Color(0xFFFFD740)
                              .withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.folder_open_rounded,
                            size: 11, color: Color(0xFFFFD740)),
                        const SizedBox(width: 3),
                        Text('Load',
                            style: GoogleFonts.rajdhani(
                                color: const Color(0xFFFFD740),
                                fontSize: 10,
                                fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Loaded team name
          if (loadedName != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 3, 12, 0),
              child: Text(
                '· $loadedName',
                style: GoogleFonts.rajdhani(
                    color: AppColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis,
              ),
            ),

          const SizedBox(height: 8),
          const Divider(height: 1, color: Color(0xFF1A1F35)),

          // ── Position slots ────────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Instruction hint
                  if (assigningSlot != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: _kPosColors[assigningSlot!]
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _kPosColors[assigningSlot!]
                              .withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(children: [
                        Icon(_kPosIcons[assigningSlot!],
                            size: 11,
                            color: _kPosColors[assigningSlot!]),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Tap a pet to set ${_kPosLabels[assigningSlot!]}',
                            style: TextStyle(
                                color: _kPosColors[assigningSlot!],
                                fontSize: 10,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                      ]),
                    ),

                  // 3 position slots
                  for (int i = 0; i < 3; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _PositionSlot(
                        slot:       i,
                        pet:        _petAt(i),
                        isAssigning: assigningSlot == i,
                        onTap:      () => onSelectSlot(i),
                        onClear:    () => onClearSlot(i),
                      ),
                    ),

                  const Divider(height: 16, color: Color(0xFF1A1F35)),

                  // Save named team button
                  GestureDetector(
                    onTap: teamFull ? onSaveNamed : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: teamFull
                            ? const Color(0xFF69F0AE).withValues(alpha: 0.1)
                            : Colors.white.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: teamFull
                              ? const Color(0xFF69F0AE)
                                  .withValues(alpha: 0.4)
                              : Colors.white12,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.save_rounded,
                              size: 13,
                              color: teamFull
                                  ? const Color(0xFF69F0AE)
                                  : Colors.white24),
                          const SizedBox(width: 5),
                          Text('Save Team',
                              style: GoogleFonts.rajdhani(
                                  color: teamFull
                                      ? const Color(0xFF69F0AE)
                                      : Colors.white24,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Battle button
                  SizedBox(
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: teamFull ? onBattle : null,
                      icon: const Text('⚔',
                          style: TextStyle(fontSize: 16)),
                      label: Text('Battle',
                          style: GoogleFonts.rajdhani(
                              fontSize: 16,
                              fontWeight: FontWeight.w800)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: teamFull
                            ? AppColors.primary
                            : Colors.white12,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
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
}

// ── Position slot widget ──────────────────────────────────────────────────────

class _PositionSlot extends StatelessWidget {
  final int       slot;
  final OwnedPet? pet;
  final bool      isAssigning;
  final VoidCallback onTap;
  final VoidCallback onClear;

  const _PositionSlot({
    required this.slot,
    required this.pet,
    required this.isAssigning,
    required this.onTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final posColor = _kPosColors[slot];
    final posIcon  = _kPosIcons[slot];
    final posLabel = _kPosLabels[slot];
    final posRole  = _kPosRoles[slot];
    final empty    = pet == null;

    final def  = empty ? null : pet!.toCreatureDefinition();
    final cls  = def?.bodyClass;
    final petColor = cls != null ? _classColor(cls) : posColor;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: isAssigning
              ? posColor.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isAssigning
                ? posColor
                : posColor.withValues(alpha: 0.35),
            width: isAssigning ? 2 : 1,
          ),
          boxShadow: isAssigning
              ? [BoxShadow(
                  color: posColor.withValues(alpha: 0.25),
                  blurRadius: 8)]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Position banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: posColor
                    .withValues(alpha: isAssigning ? 0.22 : 0.10),
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(9)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(posIcon, size: 10, color: posColor),
                  const SizedBox(width: 4),
                  Text(posLabel,
                      style: GoogleFonts.rajdhani(
                          color: posColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2)),
                ],
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              child: empty
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(posIcon,
                            size: 16,
                            color: posColor.withValues(alpha: 0.25)),
                        const SizedBox(width: 4),
                        Text(posRole,
                            style: TextStyle(
                                color: posColor.withValues(alpha: 0.35),
                                fontSize: 10)),
                      ],
                    )
                  : Row(
                      children: [
                        // Mini renderer
                        SizedBox(
                          width: 40,
                          height: 40,
                          child: PetRendererWidget.fromOwned(
                              pet!, size: 40),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(pet!.name,
                                  style: GoogleFonts.rajdhani(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800),
                                  overflow: TextOverflow.ellipsis),
                              Text(
                                  cls?.displayName.toUpperCase() ?? '',
                                  style: TextStyle(
                                      color: petColor, fontSize: 9)),
                            ],
                          ),
                        ),
                        // Remove button
                        GestureDetector(
                          onTap: onClear,
                          child: const Icon(Icons.close,
                              color: Colors.white24, size: 14),
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

// ── Pet grid ──────────────────────────────────────────────────────────────────

class _PetGrid extends StatelessWidget {
  final List<OwnedPet>  roster;
  final List<String?>   slots;
  final int?            assigningSlot;
  final void Function(String uid)         onTapPet;
  final void Function(String uid, String name) onRenamePet;

  const _PetGrid({
    required this.roster,
    required this.slots,
    required this.assigningSlot,
    required this.onTapPet,
    required this.onRenamePet,
  });

  int _slotOf(String uid) => slots.indexOf(uid); // -1 if not in team

  @override
  Widget build(BuildContext context) {
    if (roster.isEmpty) {
      return const Center(
        child: Text('No pets yet',
            style: TextStyle(color: Colors.white24, fontSize: 16)),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.72,
      ),
      itemCount: roster.length,
      itemBuilder: (_, i) {
        final pet      = roster[i];
        final slotIdx  = _slotOf(pet.uid);
        final picking  = assigningSlot != null;

        return _PetCard(
          pet:           pet,
          slotIndex:     slotIdx,
          isPicking:     picking,
          onTap:         () => onTapPet(pet.uid),
          onRename:      () => onRenamePet(pet.uid, pet.name),
        );
      },
    );
  }
}

// ── Pet card ──────────────────────────────────────────────────────────────────

class _PetCard extends StatelessWidget {
  final OwnedPet pet;
  final int      slotIndex;  // -1 = not in team
  final bool     isPicking;
  final VoidCallback onTap;
  final VoidCallback onRename;

  const _PetCard({
    required this.pet,
    required this.slotIndex,
    required this.isPicking,
    required this.onTap,
    required this.onRename,
  });

  bool get _inTeam => slotIndex >= 0;

  @override
  Widget build(BuildContext context) {
    final def      = pet.toCreatureDefinition();
    final cls      = def.bodyClass;
    final color    = _classColor(cls);
    final posColor = _inTeam ? _kPosColors[slotIndex] : null;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: _inTeam
              ? color.withValues(alpha: 0.12)
              : const Color(0xFF111A28),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _inTeam
                ? posColor!.withValues(alpha: 0.8)
                : isPicking
                    ? color.withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.08),
            width: _inTeam ? 2 : 1,
          ),
          boxShadow: _inTeam
              ? [BoxShadow(
                  color: posColor!.withValues(alpha: 0.3),
                  blurRadius: 12, spreadRadius: 1)]
              : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // ── Renderer area ──────────────────────────────────────────────
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final s = constraints.maxHeight.clamp(80.0, 300.0);
                  return Stack(children: [
                Center(
                  child: PetRendererWidget.fromOwned(pet, size: s),
                ),
                // Position badge (FRONT / MID / BACK pill)
                if (_inTeam)
                  Positioned(
                    top: 5,
                    right: 5,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: posColor!.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(
                              color: posColor.withValues(alpha: 0.5),
                              blurRadius: 4)
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_kPosIcons[slotIndex],
                              size: 8, color: Colors.black87),
                          const SizedBox(width: 2),
                          Text(_kPosLabels[slotIndex],
                              style: const TextStyle(
                                  color: Colors.black87,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5)),
                        ],
                      ),
                    ),
                  ),
                // Purity badge
                Positioned(
                  top: 5,
                  left: 5,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(4)),
                    child: Text(pet.purityLabel,
                        style: TextStyle(
                            color: pet.purity == 4
                                ? Colors.amberAccent
                                : Colors.white60,
                            fontSize: 8,
                            fontWeight: FontWeight.w800)),
                  ),
                ),
              ]);
                },
              ),
            ),

            // ── Info strip ─────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(7, 4, 7, 7),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + rename — whole row is tappable
                  GestureDetector(
                    onTap: onRename,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amberAccent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                            color: Colors.amberAccent.withValues(alpha: 0.25)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.drive_file_rename_outline,
                            size: 11, color: Colors.amberAccent),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(pet.name,
                              style: GoogleFonts.rajdhani(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800),
                              overflow: TextOverflow.ellipsis),
                        ),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 3),
                  // Class badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                          color: color.withValues(alpha: 0.5)),
                    ),
                    child: Text(cls.displayName,
                        style: TextStyle(
                            color: color,
                            fontSize: 8,
                            fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(height: 3),
                  // Purity stars + part dots
                  Row(children: [
                    Text(
                      List.generate(
                              4, (i) => i < pet.purity ? '★' : '☆')
                          .join(),
                      style: TextStyle(
                          color: pet.purity == 4
                              ? Colors.amber
                              : Colors.white38,
                          fontSize: 9,
                          letterSpacing: 0.5),
                    ),
                    const Spacer(),
                    _Dot(def.horn.partClass),
                    const SizedBox(width: 2),
                    _Dot(def.back.partClass),
                    const SizedBox(width: 2),
                    _Dot(def.tail.partClass),
                    const SizedBox(width: 2),
                    _Dot(def.mouth.partClass),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Load teams dialog ─────────────────────────────────────────────────────────

class _LoadTeamsDialog extends ConsumerWidget {
  final void Function(String teamId) onLoad;
  final void Function(String teamId, String name) onRename;
  final void Function(String teamId) onDelete;

  const _LoadTeamsDialog({
    required this.onLoad,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);
    final teams  = player.savedTeams;

    return SizedBox(
      width: 360,
      height: MediaQuery.of(context).size.height * 0.65,
      child: Column(children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 12),
          child: Row(children: [
            const Icon(Icons.folder_open_rounded,
                color: Color(0xFFFFD740), size: 20),
            const SizedBox(width: 8),
            Text('Saved Teams',
                style: GoogleFonts.rajdhani(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Colors.white)),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white54, size: 18),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ]),
        ),
        const Divider(color: Colors.white10, height: 1),

        // Team list
        Expanded(
          child: teams.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.bookmark_border,
                          size: 36, color: Colors.white24),
                      const SizedBox(height: 10),
                      Text('No saved teams yet',
                          style: GoogleFonts.rajdhani(
                              color: Colors.white38, fontSize: 15)),
                      const SizedBox(height: 4),
                      const Text('Build a team and tap "Save Team"',
                          style: TextStyle(
                              color: Colors.white24, fontSize: 11)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: teams.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) {
                    final team     = teams[i];
                    final teamPets = team.petUids
                        .map((uid) => player.petById(uid))
                        .whereType<OwnedPet>()
                        .toList();

                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(children: [
                        // Team name row
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 4, 4),
                          child: Row(children: [
                            const Icon(Icons.bookmark,
                                size: 13, color: Color(0xFFFFD740)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(team.name,
                                  style: GoogleFonts.rajdhani(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white)),
                            ),
                            IconButton(
                              icon: const Icon(
                                  Icons.drive_file_rename_outline,
                                  size: 15,
                                  color: Colors.amberAccent),
                              onPressed: () =>
                                  onRename(team.id, team.name),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  size: 15, color: Colors.redAccent),
                              onPressed: () => onDelete(team.id),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            const SizedBox(width: 4),
                          ]),
                        ),

                        // FRONT / MID / BACK preview
                        Padding(
                          padding:
                              const EdgeInsets.fromLTRB(10, 0, 10, 8),
                          child: Row(
                            children: List.generate(3, (slot) {
                              final pet = slot < teamPets.length
                                  ? teamPets[slot]
                                  : null;
                              final pc  = _kPosColors[slot];
                              final pi  = _kPosIcons[slot];
                              final pl  = _kPosLabels[slot];

                              return Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(
                                      right: slot < 2 ? 6 : 0),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: pc.withValues(alpha: 0.06),
                                      borderRadius:
                                          BorderRadius.circular(6),
                                      border: Border.all(
                                          color: pc
                                              .withValues(alpha: 0.3)),
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(pi,
                                                size: 8, color: pc),
                                            const SizedBox(width: 2),
                                            Text(pl,
                                                style: TextStyle(
                                                    color: pc,
                                                    fontSize: 7,
                                                    fontWeight:
                                                        FontWeight
                                                            .w900)),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        if (pet != null)
                                          SizedBox(
                                            width: 28,
                                            height: 28,
                                            child:
                                                PetRendererWidget.fromOwned(
                                                    pet, size: 28),
                                          )
                                        else
                                          Icon(
                                              Icons
                                                  .remove_circle_outline,
                                              size: 16,
                                              color: pc.withValues(
                                                  alpha: 0.2)),
                                        const SizedBox(height: 2),
                                        Text(
                                          pet?.name ?? '—',
                                          style: TextStyle(
                                              color: pet != null
                                                  ? Colors.white60
                                                  : Colors.white24,
                                              fontSize: 8,
                                              fontWeight:
                                                  FontWeight.w700),
                                          textAlign: TextAlign.center,
                                          maxLines: 1,
                                          overflow:
                                              TextOverflow.ellipsis,
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
                          padding:
                              const EdgeInsets.fromLTRB(10, 0, 10, 10),
                          child: SizedBox(
                            width: double.infinity,
                            height: 34,
                            child: ElevatedButton.icon(
                              onPressed: () => onLoad(team.id),
                              icon: const Icon(
                                  Icons.play_arrow_rounded,
                                  size: 14),
                              label: Text('Load',
                                  style: GoogleFonts.rajdhani(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(7)),
                              ),
                            ),
                          ),
                        ),
                      ]),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _Dot extends StatelessWidget {
  final CreatureClass cls;
  const _Dot(this.cls);

  @override
  Widget build(BuildContext context) => Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
            shape: BoxShape.circle, color: _classColor(cls)),
      );
}
