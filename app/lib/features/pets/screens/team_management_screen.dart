import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:likha_pet_battle_engine/trait.dart';

import '../../battle/widgets/pet_renderer_widget.dart';
import '../models/owned_pet.dart';
import '../models/team_composition.dart';
import '../providers/player_provider.dart';

// ── Color constants ───────────────────────────────────────────────────────────

const _kActive   = Color(0xFFE85AA8); // magenta
const _kCyan     = Color(0xFF4AC4D9);
const _kCyanBright = Color(0xFF7FE3F5);

Color _cls(CreatureClass c) => switch (c) {
  CreatureClass.plant   => const Color(0xFFA8D94A),
  CreatureClass.aquatic => const Color(0xFF4AC4D9),
  CreatureClass.beast   => const Color(0xFFF0A040),
  CreatureClass.reptile => const Color(0xFF4ADC7A),
  CreatureClass.bird    => const Color(0xFFF586A0),
  CreatureClass.bug     => const Color(0xFFE85AA8),
};

// ── Helpers ───────────────────────────────────────────────────────────────────

bool _isActive(TeamComposition team, List<String> activeTeam) {
  if (activeTeam.length != 3 || team.petUids.length != 3) return false;
  return team.petUids[0] == activeTeam[0] &&
      team.petUids[1] == activeTeam[1] &&
      team.petUids[2] == activeTeam[2];
}

int _teamPower(List<OwnedPet?> pets) {
  final valid = pets.whereType<OwnedPet>().toList();
  if (valid.isEmpty) return 0;
  int total = 0;
  for (final p in valid) {
    final s = p.toCreatureDefinition().computedStats;
    total += s.hp + s.speed + s.morale + s.skill;
  }
  return total ~/ valid.length;
}

// ── Screen ────────────────────────────────────────────────────────────────────

class TeamManagementScreen extends ConsumerWidget {
  const TeamManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player     = ref.watch(playerProvider);
    final teams      = List<TeamComposition>.from(player.savedTeams)
      ..sort((a, b) {
        final aActive = _isActive(a, player.activeTeam) ? 0 : 1;
        final bActive = _isActive(b, player.activeTeam) ? 0 : 1;
        return aActive.compareTo(bActive);
      });
    final canCreate  = player.roster.length >= 3;

    return Scaffold(
      backgroundColor: const Color(0xFF050810),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.85, -0.9),
            radius: 1.1,
            colors: [Color(0x0F4AC4D9), Color(0x00050810)],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(
                teamCount: teams.length,
                petCount:  player.roster.length,
                canCreate: canCreate,
                onCreate:  () => _showBuilderModal(context, ref),
              ),
              const _InfoBanner(),
              Expanded(
                child: teams.isEmpty
                    ? _EmptyState(
                        canCreate: canCreate,
                        onCreate:  () => _showBuilderModal(context, ref),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                        itemCount: teams.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 12),
                        itemBuilder: (_, i) {
                          final team    = teams[i];
                          final active  = _isActive(team, player.activeTeam);
                          final teamPets = team.petUids
                              .map((uid) => player.petById(uid))
                              .toList();
                          return _TeamCard(
                            key:      ValueKey(team.id),
                            team:     team,
                            teamPets: teamPets,
                            isActive: active,
                            onSetActive: () => ref
                                .read(playerProvider.notifier)
                                .loadTeamComposition(team.id),
                            onEdit: () => _showBuilderModal(
                              context, ref,
                              editing: team,
                              roster:  player.roster,
                            ),
                            onDelete: () => _confirmDelete(
                              context, ref, team, active,
                            ),
                            onRename: (name) => ref
                                .read(playerProvider.notifier)
                                .renameTeamComposition(team.id, name),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Builder modal ────────────────────────────────────────────────────────────

  void _showBuilderModal(
    BuildContext context,
    WidgetRef ref, {
    TeamComposition? editing,
    List<OwnedPet>?  roster,
  }) {
    final allPets = roster ?? ref.read(playerProvider).roster;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Colors.black.withValues(alpha: 0.78),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (ctx, a1, a2) => _BuilderModal(
        editing:  editing,
        roster:   allPets,
        onSave: (name, petUids) {
          if (editing != null) {
            ref.read(playerProvider.notifier)
                .updateTeamComposition(editing.id, name, petUids);
          } else {
            ref.read(playerProvider.notifier)
                .createTeamComposition(name, petUids);
          }
        },
      ),
      transitionBuilder: (ctx, a1, a2, child) {
        final curve = CurvedAnimation(
            parent: a1, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: a1,
          child: ScaleTransition(
            scale: Tween(begin: 0.92, end: 1.0).animate(curve),
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0, 0.04),
                end:   Offset.zero,
              ).animate(curve),
              child: child,
            ),
          ),
        );
      },
    );
  }

  // ── Delete confirm ───────────────────────────────────────────────────────────

  void _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    TeamComposition team,
    bool isActive,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0A1224),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Team?',
            style: TextStyle(color: Colors.white, fontFamily: 'LilitaOne')),
        content: Text(
          'Remove "${team.name}" permanently?'
          '${isActive ? '\n\nThis is your active team.' : ''}',
          style: const TextStyle(
              color: Colors.white70, fontFamily: 'Fredoka', fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              ref
                  .read(playerProvider.notifier)
                  .deleteTeamComposition(team.id);
              Navigator.of(ctx).pop();
            },
            child: const Text('Delete',
                style: TextStyle(
                    color: Color(0xFFE85AA8),
                    fontFamily: 'LilitaOne')),
          ),
        ],
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final int  teamCount;
  final int  petCount;
  final bool canCreate;
  final VoidCallback onCreate;

  const _Header({
    required this.teamCount,
    required this.petCount,
    required this.canCreate,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 16, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: _kCyan),
            onPressed: () => context.pop(),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'My Teams',
                  style: TextStyle(
                    fontFamily: 'LilitaOne',
                    color: Color(0xFFEAFBFF),
                    fontSize: 26,
                    shadows: [
                      Shadow(
                          color: Color(0xFF0A1224),
                          offset: Offset(-2, -2),
                          blurRadius: 1),
                      Shadow(
                          color: Color(0xFF0A1224),
                          offset: Offset(2, 2),
                          blurRadius: 1),
                      Shadow(color: Color(0xAA4AC4D9), blurRadius: 12),
                    ],
                  ),
                ),
                Text(
                  'You have $teamCount team${teamCount == 1 ? '' : 's'}'
                  ' · $petCount pets available',
                  style: const TextStyle(
                    fontFamily: 'Fredoka',
                    color: Color(0xFFAAE8F5),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // CTA or notice
          if (canCreate)
            _CreateBtn(onTap: onCreate)
          else
            _NeedPetsNotice(),
        ],
      ),
    );
  }
}

// ── Create New Team button ─────────────────────────────────────────────────────

class _CreateBtn extends StatefulWidget {
  final VoidCallback onTap;
  const _CreateBtn({required this.onTap});

  @override
  State<_CreateBtn> createState() => _CreateBtnState();
}

class _CreateBtnState extends State<_CreateBtn> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp:   (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF4AC4D9), Color(0xFF2B8A9C)],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kCyanBright, width: 2),
            boxShadow: [
              BoxShadow(
                color: _kCyan.withValues(alpha: 0.55),
                blurRadius: 16,
                spreadRadius: 1,
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_rounded, size: 16, color: Colors.white),
              SizedBox(width: 6),
              Text(
                'Create New Team',
                style: TextStyle(
                  fontFamily: 'LilitaOne',
                  color: Colors.white,
                  fontSize: 13,
                  shadows: [
                    Shadow(
                        color: Color(0xFF0A1224),
                        offset: Offset(-1, -1),
                        blurRadius: 1),
                    Shadow(
                        color: Color(0xFF0A1224),
                        offset: Offset(1, 1),
                        blurRadius: 1),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NeedPetsNotice extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFE85AA8).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: const Color(0xFFE85AA8).withValues(alpha: 0.35)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.info_outline_rounded,
              size: 13, color: Color(0xFFE85AA8)),
          SizedBox(width: 5),
          Text(
            'Need ≥3 pets',
            style: TextStyle(
              fontFamily: 'Fredoka',
              color: Color(0xFFE85AA8),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Info banner ───────────────────────────────────────────────────────────────

class _InfoBanner extends StatelessWidget {
  const _InfoBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _kCyan.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kCyan.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(Icons.shield_rounded, size: 15, color: _kCyan),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Each team uses exactly 3 pets. The same pet can appear in '
              'multiple teams — build as many lineups as you want.',
              style: TextStyle(
                fontFamily: 'Fredoka',
                color: Color(0xFFAAE8F5),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Team card ─────────────────────────────────────────────────────────────────

class _TeamCard extends StatefulWidget {
  final TeamComposition   team;
  final List<OwnedPet?>   teamPets;
  final bool              isActive;
  final VoidCallback      onSetActive;
  final VoidCallback      onEdit;
  final VoidCallback      onDelete;
  final void Function(String) onRename;

  const _TeamCard({
    super.key,
    required this.team,
    required this.teamPets,
    required this.isActive,
    required this.onSetActive,
    required this.onEdit,
    required this.onDelete,
    required this.onRename,
  });

  @override
  State<_TeamCard> createState() => _TeamCardState();
}

class _TeamCardState extends State<_TeamCard> {
  bool _editing = false;
  bool _deleteHover = false;
  late final _nameCtrl = TextEditingController(text: widget.team.name);
  late final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus && _editing) _commitEdit();
    });
  }

  @override
  void didUpdateWidget(_TeamCard old) {
    super.didUpdateWidget(old);
    if (!_editing) _nameCtrl.text = widget.team.name;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startEdit() => setState(() => _editing = true);

  void _commitEdit() {
    final name = _nameCtrl.text.trim();
    if (name.isNotEmpty && name != widget.team.name) {
      widget.onRename(name);
    } else {
      _nameCtrl.text = widget.team.name;
    }
    setState(() => _editing = false);
  }

  void _cancelEdit() {
    _nameCtrl.text = widget.team.name;
    setState(() => _editing = false);
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.isActive ? _kActive : _kCyan;
    final power  = _teamPower(widget.teamPets);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0E1A33),
            Color(0xFF0A1224),
            Color(0xFF050810),
          ],
          stops: [0.0, 0.6, 1.0],
        ),
        border: Border.all(
          color: accent.withValues(alpha: widget.isActive ? 0.65 : 0.28),
          width: widget.isActive ? 2 : 1,
        ),
        boxShadow: widget.isActive
            ? [
                BoxShadow(
                  color: _kActive.withValues(alpha: 0.28),
                  blurRadius: 18,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Column(
        children: [
          // ── Top row: name + active chip + power ─────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: _editing
                      ? _NameField(
                          ctrl:      _nameCtrl,
                          focusNode: _focusNode,
                          onDone:    _commitEdit,
                          onEscape:  _cancelEdit,
                        )
                      : GestureDetector(
                          onTap: _startEdit,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  widget.team.name,
                                  style: const TextStyle(
                                    fontFamily: 'LilitaOne',
                                    color: Color(0xFFEAFBFF),
                                    fontSize: 18,
                                    shadows: [
                                      Shadow(
                                          color: Color(0xFF0A1224),
                                          offset: Offset(-1, -1),
                                          blurRadius: 1),
                                    ],
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(Icons.edit_rounded,
                                  size: 13,
                                  color: _kCyan.withValues(alpha: 0.5)),
                            ],
                          ),
                        ),
                ),
                const SizedBox(width: 8),
                if (widget.isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _kActive.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: _kActive.withValues(alpha: 0.65)),
                      boxShadow: [
                        BoxShadow(
                          color: _kActive.withValues(alpha: 0.35),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: const Text(
                      'ACTIVE',
                      style: TextStyle(
                        fontFamily: 'LilitaOne',
                        color: _kActive,
                        fontSize: 10,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                // Power readout
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_rounded,
                            size: 12, color: Color(0xFFFFD740)),
                        const SizedBox(width: 3),
                        Text(
                          '$power',
                          style: const TextStyle(
                            fontFamily: 'LilitaOne',
                            color: Color(0xFFFFD740),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const Text(
                      'avg PWR',
                      style: TextStyle(
                        fontFamily: 'Fredoka',
                        color: Colors.white38,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── 3-pet mini row ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            child: Row(
              children: List.generate(3, (i) {
                final pet = i < widget.teamPets.length
                    ? widget.teamPets[i]
                    : null;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: i < 2 ? 8 : 0),
                    child: _MiniPetCell(pet: pet, slot: i),
                  ),
                );
              }),
            ),
          ),

          // ── Action row ───────────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: (widget.isActive ? _kActive : _kCyan)
                      .withValues(alpha: 0.15),
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  if (!widget.isActive)
                    _CardAction(
                      label: 'Set Active',
                      icon:  Icons.bolt_rounded,
                      color: _kActive,
                      onTap: widget.onSetActive,
                    ),
                  if (!widget.isActive) const SizedBox(width: 6),
                  _CardAction(
                    label: 'Edit',
                    icon:  Icons.edit_outlined,
                    color: _kCyan,
                    onTap: widget.onEdit,
                  ),
                  const Spacer(),
                  // Delete
                  MouseRegion(
                    onEnter:  (_) => setState(() => _deleteHover = true),
                    onExit:   (_) => setState(() => _deleteHover = false),
                    child: GestureDetector(
                      onTap: widget.onDelete,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: _deleteHover
                              ? const Color(0xFFE85AA8)
                                  .withValues(alpha: 0.12)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _deleteHover
                                ? const Color(0xFFE85AA8)
                                    .withValues(alpha: 0.4)
                                : Colors.transparent,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.delete_outline,
                                size: 14,
                                color: _deleteHover
                                    ? const Color(0xFFE85AA8)
                                    : Colors.white24),
                            const SizedBox(width: 4),
                            Text(
                              'Delete',
                              style: TextStyle(
                                fontFamily: 'Fredoka',
                                color: _deleteHover
                                    ? const Color(0xFFE85AA8)
                                    : Colors.white24,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
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

// ── Inline name field ─────────────────────────────────────────────────────────

class _NameField extends StatelessWidget {
  final TextEditingController ctrl;
  final FocusNode             focusNode;
  final VoidCallback          onDone;
  final VoidCallback          onEscape;

  const _NameField({
    required this.ctrl,
    required this.focusNode,
    required this.onDone,
    required this.onEscape,
  });

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: (e) {
        if (e is KeyDownEvent &&
            e.logicalKey == LogicalKeyboardKey.escape) {
          onEscape();
        }
      },
      child: TextField(
        controller: ctrl,
        focusNode:  focusNode,
        autofocus:  true,
        maxLength:  32,
        style: const TextStyle(
          fontFamily: 'LilitaOne',
          color: Color(0xFFEAFBFF),
          fontSize: 17,
        ),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 10, vertical: 6),
          counterText: '',
          filled: true,
          fillColor: _kCyan.withValues(alpha: 0.08),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide:
                BorderSide(color: _kCyan.withValues(alpha: 0.4)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _kCyan, width: 1.5),
          ),
        ),
        textInputAction: TextInputAction.done,
        onEditingComplete: onDone,
      ),
    );
  }
}

// ── Card action button ────────────────────────────────────────────────────────

class _CardAction extends StatelessWidget {
  final String   label;
  final IconData icon;
  final Color    color;
  final VoidCallback onTap;

  const _CardAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border:
              Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'LilitaOne',
                color: color,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Mini pet cell (in team card) ──────────────────────────────────────────────

class _MiniPetCell extends StatelessWidget {
  final OwnedPet? pet;
  final int       slot;

  const _MiniPetCell({required this.pet, required this.slot});

  static const _kSlotLabels = ['FRONT', 'MID', 'BACK'];
  static const _kSlotColors = [
    Color(0xFFFF5252),
    Color(0xFFFFD740),
    Color(0xFF69F0AE),
  ];

  @override
  Widget build(BuildContext context) {
    final posColor = _kSlotColors[slot];
    final posLabel = _kSlotLabels[slot];

    if (pet == null) {
      return Container(
        height: 96,
        decoration: BoxDecoration(
          color: posColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: posColor.withValues(alpha: 0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_off_outlined,
                size: 18,
                color: posColor.withValues(alpha: 0.2)),
            const SizedBox(height: 3),
            Text(posLabel,
                style: TextStyle(
                    color: posColor.withValues(alpha: 0.3),
                    fontSize: 8,
                    fontFamily: 'LilitaOne')),
          ],
        ),
      );
    }

    final def   = pet!.toCreatureDefinition();
    final cls   = def.bodyClass;
    final color = _cls(cls);
    final stats = def.computedStats;
    final power = stats.hp + stats.speed + stats.morale + stats.skill;

    return Container(
      height: 96,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          // Position label strip
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 3),
            decoration: BoxDecoration(
              color: posColor.withValues(alpha: 0.12),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(9)),
            ),
            child: Text(
              posLabel,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'LilitaOne',
                color: posColor,
                fontSize: 8,
                letterSpacing: 0.5,
              ),
            ),
          ),
          // Sprite
          Expanded(
            child: Center(
              child: SizedBox(
                width: 52,
                height: 52,
                child: PetRendererWidget.fromOwned(pet!, size: 52),
              ),
            ),
          ),
          // Name + class chip + power
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 5),
            child: Column(
              children: [
                Text(
                  pet!.name,
                  style: const TextStyle(
                    fontFamily: 'LilitaOne',
                    color: Color(0xFFEAFBFF),
                    fontSize: 9,
                  ),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                            color: color.withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        cls.displayName.toUpperCase(),
                        style: TextStyle(
                          fontFamily: 'LilitaOne',
                          color: color,
                          fontSize: 7,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$power',
                      style: const TextStyle(
                        fontFamily: 'Fredoka',
                        color: Color(0xFFFFD740),
                        fontSize: 8,
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
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool         canCreate;
  final VoidCallback onCreate;

  const _EmptyState({required this.canCreate, required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt_rounded,
              size: 60,
              color: _kCyan.withValues(alpha: 0.28)),
          const SizedBox(height: 16),
          const Text(
            'No teams yet',
            style: TextStyle(
              fontFamily: 'LilitaOne',
              color: Color(0xFFEAFBFF),
              fontSize: 22,
              shadows: [
                Shadow(color: Color(0xAA4AC4D9), blurRadius: 10),
              ],
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Create your first team to start battling',
            style: TextStyle(
              fontFamily: 'Fredoka',
              color: Color(0xFF7FE3F5),
              fontSize: 13,
            ),
          ),
          if (canCreate) ...[
            const SizedBox(height: 20),
            _CreateBtn(onTap: onCreate),
          ],
        ],
      ),
    );
  }
}

// ── Builder modal ─────────────────────────────────────────────────────────────

class _BuilderModal extends StatefulWidget {
  final TeamComposition?                          editing;
  final List<OwnedPet>                            roster;
  final void Function(String, List<String>)       onSave;

  const _BuilderModal({
    this.editing,
    required this.roster,
    required this.onSave,
  });

  @override
  State<_BuilderModal> createState() => _BuilderModalState();
}

class _BuilderModalState extends State<_BuilderModal> {
  // 3 selected pets (null = empty slot)
  late final List<OwnedPet?> _slots;
  late final TextEditingController _nameCtrl;

  @override
  void initState() {
    super.initState();
    if (widget.editing != null) {
      _slots = widget.editing!.petUids.map((uid) {
        return widget.roster
            .cast<OwnedPet?>()
            .firstWhere((p) => p?.uid == uid, orElse: () => null);
      }).toList();
    } else {
      _slots = [null, null, null];
    }
    _nameCtrl = TextEditingController(
        text: widget.editing?.name ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  bool get _canSave =>
      _slots.every((s) => s != null) && _nameCtrl.text.trim().isNotEmpty;

  void _onPickerTap(OwnedPet pet) {
    final existingIdx = _slots.indexWhere((s) => s?.uid == pet.uid);
    if (existingIdx >= 0) {
      setState(() => _slots[existingIdx] = null);
    } else {
      final emptyIdx = _slots.indexOf(null);
      if (emptyIdx >= 0) setState(() => _slots[emptyIdx] = pet);
    }
  }

  void _clearSlot(int i) => setState(() => _slots[i] = null);

  void _doSave() {
    final name = _nameCtrl.text.trim();
    if (!_canSave || name.isEmpty) return;
    widget.onSave(name, _slots.map((p) => p!.uid).toList());
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit    = widget.editing != null;
    final filledCnt = _slots.where((s) => s != null).length;
    final full      = filledCnt == 3;

    return Align(
      alignment: Alignment.center,
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: MediaQuery.of(context).padding.top + 20,
          bottom: MediaQuery.of(context).padding.bottom + 20,
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          decoration: BoxDecoration(
            color: const Color(0xFF0A1224),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _kCyan.withValues(alpha: 0.55), width: 2),
            boxShadow: [
              BoxShadow(
                color: _kCyan.withValues(alpha: 0.30),
                blurRadius: 36,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Modal header
              _ModalHeader(isEdit: isEdit),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // LINEUP section
                      const _SectionLabel('LINEUP'),
                      const SizedBox(height: 8),
                      Row(
                        children: List.generate(3, (i) {
                          return Expanded(
                            child: Padding(
                              padding:
                                  EdgeInsets.only(right: i < 2 ? 8 : 0),
                              child: _SlotCell(
                                slot:    i,
                                pet:     _slots[i],
                                onClear: () => _clearSlot(i),
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 18),
                      // TEAM NAME section
                      const _SectionLabel('TEAM NAME'),
                      const SizedBox(height: 8),
                      _NameInput(
                        ctrl: _nameCtrl,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 18),
                      // ROSTER section
                      Row(
                        children: [
                          _SectionLabel(
                              full ? 'ROSTER · TAP TO SWAP' : 'ROSTER · TAP TO ADD'),
                          const Spacer(),
                          Text(
                            '$filledCnt / 3 selected',
                            style: const TextStyle(
                              fontFamily: 'Fredoka',
                              color: Color(0xFF7FE3F5),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount:   3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing:  8,
                          childAspectRatio: 0.70,
                        ),
                        itemCount: widget.roster.length,
                        itemBuilder: (_, i) {
                          final pet      = widget.roster[i];
                          final slotIdx  =
                              _slots.indexWhere((s) => s?.uid == pet.uid);
                          return _RosterPickerCard(
                            pet:      pet,
                            slotIdx:  slotIdx, // -1 = not selected
                            canAdd:   !full || slotIdx >= 0,
                            onTap:    () => _onPickerTap(pet),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              // Footer
              _ModalFooter(
                canSave: _canSave,
                isEdit:  isEdit,
                onCancel: () => Navigator.of(context).pop(),
                onSave:   _doSave,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Modal header ──────────────────────────────────────────────────────────────

class _ModalHeader extends StatelessWidget {
  final bool isEdit;
  const _ModalHeader({required this.isEdit});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 14, 14),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: _kCyan.withValues(alpha: 0.2)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEdit ? 'Edit Team' : 'Build a New Team',
                  style: const TextStyle(
                    fontFamily: 'LilitaOne',
                    color: Color(0xFFEAFBFF),
                    fontSize: 20,
                    shadows: [
                      Shadow(color: Color(0xAA4AC4D9), blurRadius: 10),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isEdit
                      ? 'Update pets or rename your formation'
                      : 'Choose 3 pets and give your team a name',
                  style: const TextStyle(
                    fontFamily: 'Fredoka',
                    color: Color(0xFF7FE3F5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded,
                color: Colors.white38, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: 'LilitaOne',
        color: Color(0xFF4AC4D9),
        fontSize: 10,
        letterSpacing: 1.5,
      ),
    );
  }
}

// ── Slot cell (in modal) ──────────────────────────────────────────────────────

class _SlotCell extends StatelessWidget {
  final int       slot;
  final OwnedPet? pet;
  final VoidCallback onClear;

  const _SlotCell({
    required this.slot,
    required this.pet,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    if (pet == null) {
      return Container(
        height: 110,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _kCyan.withValues(alpha: 0.35),
            style: BorderStyle.solid,
          ),
          color: _kCyan.withValues(alpha: 0.05),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _kCyan.withValues(alpha: 0.12),
                border:
                    Border.all(color: _kCyan.withValues(alpha: 0.4)),
              ),
              child: const Icon(Icons.add_rounded,
                  size: 16, color: _kCyan),
            ),
            const SizedBox(height: 6),
            Text(
              'SLOT ${slot + 1}',
              style: const TextStyle(
                fontFamily: 'LilitaOne',
                color: _kCyan,
                fontSize: 9,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      );
    }

    final def   = pet!.toCreatureDefinition();
    final cls   = def.bodyClass;
    final color = _cls(cls);

    return Container(
      height: 110,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.65), width: 2),
        color: color.withValues(alpha: 0.08),
        boxShadow: [
          BoxShadow(
              color: color.withValues(alpha: 0.18), blurRadius: 10),
        ],
      ),
      child: Stack(
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Center(
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: PetRendererWidget.fromOwned(pet!, size: 56),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: color.withValues(alpha: 0.55)),
                ),
                child: Text(
                  cls.displayName.toUpperCase(),
                  style: TextStyle(
                    fontFamily: 'LilitaOne',
                    color: color,
                    fontSize: 8,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  pet!.name,
                  style: const TextStyle(
                    fontFamily: 'LilitaOne',
                    color: Color(0xFFEAFBFF),
                    fontSize: 9,
                  ),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          // X button
          Positioned(
            top: 5,
            right: 5,
            child: GestureDetector(
              onTap: onClear,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(Icons.close_rounded,
                    size: 12, color: Colors.white54),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Name input ────────────────────────────────────────────────────────────────

class _NameInput extends StatelessWidget {
  final TextEditingController ctrl;
  final void Function(String) onChanged;

  const _NameInput({required this.ctrl, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      onChanged:  onChanged,
      maxLength:  32,
      style: const TextStyle(
        fontFamily: 'Fredoka',
        color: Color(0xFFEAFBFF),
        fontSize: 15,
      ),
      decoration: InputDecoration(
        counterText: '',
        hintText:    'e.g. Alpha Squad',
        hintStyle: const TextStyle(
          fontFamily: 'Fredoka',
          color: Color(0xFF4AC4D9),
          fontSize: 14,
        ),
        filled:     true,
        fillColor:  _kCyan.withValues(alpha: 0.06),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              BorderSide(color: _kCyan.withValues(alpha: 0.35)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _kCyan, width: 2),
        ),
      ),
    );
  }
}

// ── Modal footer ──────────────────────────────────────────────────────────────

class _ModalFooter extends StatelessWidget {
  final bool         canSave;
  final bool         isEdit;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  const _ModalFooter({
    required this.canSave,
    required this.isEdit,
    required this.onCancel,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: _kCyan.withValues(alpha: 0.2)),
        ),
      ),
      child: Row(
        children: [
          // Cancel
          Expanded(
            child: GestureDetector(
              onTap: onCancel,
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white12),
                ),
                child: const Center(
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      fontFamily: 'LilitaOne',
                      color: Colors.white54,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Save
          Expanded(
            flex: 2,
            child: GestureDetector(
              onTap: canSave ? onSave : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 44,
                decoration: BoxDecoration(
                  gradient: canSave
                      ? const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF4AC4D9), Color(0xFF2B8A9C)],
                        )
                      : null,
                  color: canSave ? null : Colors.white12,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: canSave
                        ? _kCyanBright
                        : Colors.white12,
                    width: canSave ? 1.5 : 1,
                  ),
                  boxShadow: canSave
                      ? [
                          BoxShadow(
                            color: _kCyan.withValues(alpha: 0.45),
                            blurRadius: 14,
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    isEdit ? 'Save Changes' : 'Save Team',
                    style: TextStyle(
                      fontFamily: 'LilitaOne',
                      color: canSave ? Colors.white : Colors.white24,
                      fontSize: 15,
                      shadows: canSave
                          ? const [
                              Shadow(
                                  color: Color(0xFF0A1224),
                                  offset: Offset(-1, -1),
                                  blurRadius: 1),
                            ]
                          : null,
                    ),
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

// ── Roster picker card (in modal grid) ───────────────────────────────────────

class _RosterPickerCard extends StatelessWidget {
  final OwnedPet pet;
  final int      slotIdx;  // -1 = not selected
  final bool     canAdd;
  final VoidCallback onTap;

  const _RosterPickerCard({
    required this.pet,
    required this.slotIdx,
    required this.canAdd,
    required this.onTap,
  });

  bool get _selected => slotIdx >= 0;

  static const _kSlotColors = [
    Color(0xFFFF5252),
    Color(0xFFFFD740),
    Color(0xFF69F0AE),
  ];

  @override
  Widget build(BuildContext context) {
    final def      = pet.toCreatureDefinition();
    final cls      = def.bodyClass;
    final color    = _cls(cls);
    final posColor = _selected ? _kSlotColors[slotIdx] : null;

    return GestureDetector(
      onTap: (canAdd || _selected) ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: _selected
              ? color.withValues(alpha: 0.14)
              : const Color(0xFF0D1525),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _selected
                ? color.withValues(alpha: 0.80)
                : !canAdd
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.white.withValues(alpha: 0.10),
            width: _selected ? 2 : 1,
          ),
          boxShadow: _selected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.28),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: Opacity(
          opacity: (!canAdd && !_selected) ? 0.35 : 1.0,
          child: Column(
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (_, c) {
                    final s = c.maxHeight.clamp(60.0, 200.0);
                    return Stack(
                      children: [
                        Center(
                          child: PetRendererWidget.fromOwned(
                              pet, size: s),
                        ),
                        // Check badge (selected)
                        if (_selected)
                          Positioned(
                            top: 5,
                            right: 5,
                            child: Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _kCyan,
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        _kCyan.withValues(alpha: 0.5),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.check_rounded,
                                  size: 12, color: Colors.white),
                            ),
                          ),
                        // Position slot indicator
                        if (_selected && posColor != null)
                          Positioned(
                            top: 5,
                            left: 5,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: posColor.withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                ['F', 'M', 'B'][slotIdx],
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        // Purity badge
                        Positioned(
                          bottom: 4,
                          left: 5,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              pet.purityLabel,
                              style: TextStyle(
                                color: pet.purity == 4
                                    ? Colors.amberAccent
                                    : Colors.white60,
                                fontSize: 8,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              // Info strip
              Container(
                padding: const EdgeInsets.fromLTRB(5, 4, 5, 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      pet.name,
                      style: const TextStyle(
                        fontFamily: 'LilitaOne',
                        color: Color(0xFFEAFBFF),
                        fontSize: 10,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                            color: color.withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        cls.displayName,
                        style: TextStyle(
                          fontFamily: 'LilitaOne',
                          color: color,
                          fontSize: 8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
