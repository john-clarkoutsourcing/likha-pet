import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:likha_pet_battle_engine/trait.dart';
import '../../../core/theme/app_colors.dart';
import '../../battle/widgets/pet_renderer_widget.dart';
import '../../pets/models/owned_pet.dart';
import '../../pets/providers/player_provider.dart';

class PetRosterIntegratedScreen extends ConsumerStatefulWidget {
  const PetRosterIntegratedScreen({super.key});

  @override
  ConsumerState<PetRosterIntegratedScreen> createState() => _State();
}

class _State extends ConsumerState<PetRosterIntegratedScreen> {
  final Set<String> _team = {};
  String? _selectedPetUid; // highlighted card

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = ref.read(playerProvider);
      setState(() {
        _team.clear();
        _team.addAll(p.activeTeam);
      });
    });
  }

  void _toggleTeam(String uid) {
    setState(() {
      if (_team.contains(uid)) {
        _team.remove(uid);
      } else if (_team.length < 3) {
        _team.add(uid);
      }
    });
  }

  void _saveAndBack() {
    if (_team.length == 3) {
      ref.read(playerProvider.notifier).setActiveTeam(_team.toList());
    }
    context.pop();
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
            // ── Left panel ─────────────────────────────────────────────────
            SizedBox(
              width: 180,
              child: _LeftPanel(
                roster: roster,
                team: _team,
                onSave: _saveAndBack,
                onBack: () => context.pop(),
                onRemove: (uid) => setState(() => _team.remove(uid)),
              ),
            ),

            // ── Pets grid ──────────────────────────────────────────────────
            Expanded(
              child: roster.isEmpty
                  ? _EmptyState()
                  : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.75,
                      ),
                      itemCount: roster.length,
                      itemBuilder: (_, i) {
                        final pet = roster[i];
                        final inTeam = _team.contains(pet.uid);
                        final selected = _selectedPetUid == pet.uid;
                        return _PetCard(
                          pet: pet,
                          inTeam: inTeam,
                          highlighted: selected,
                          onTap: () {
                            setState(() {
                              _selectedPetUid =
                                  selected ? null : pet.uid;
                              _toggleTeam(pet.uid);
                            });
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Left panel ─────────────────────────────────────────────────────────────────

class _LeftPanel extends StatelessWidget {
  final List<OwnedPet> roster;
  final Set<String> team;
  final VoidCallback onSave;
  final VoidCallback onBack;
  final void Function(String uid) onRemove;

  const _LeftPanel({
    required this.roster,
    required this.team,
    required this.onSave,
    required this.onBack,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: Color(0xFF1A1F35))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header (non-scrollable)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    TextButton(
                      onPressed: onBack,
                      style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero),
                      child: const Text('← Back',
                          style: TextStyle(
                              color: Colors.white38, fontSize: 11)),
                    ),
                    const Spacer(),
                  ],
                ),
                Text('My Pets',
                    style: GoogleFonts.rajdhani(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900)),
                Text('${roster.length} pets · ${team.length}/3 team',
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 10)),
              ],
            ),
          ),

          const SizedBox(height: 8),
          const Divider(height: 1, color: Color(0xFF1A1F35)),

          // Team slots + save (scrollable area)
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('TEAM  ${team.length}/3',
                      style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1)),
                  const SizedBox(height: 6),
                  for (int i = 0; i < 3; i++) _TeamSlot(
                    pet: _petAt(roster, team, i),
                    index: i,
                    onRemove: onRemove,
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: team.length == 3 ? onSave : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: team.length == 3
                            ? AppColors.primary
                            : Colors.white12,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text(
                          team.length == 3 ? 'Save Team' : 'Pick 3',
                          style: GoogleFonts.rajdhani(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w800)),
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

  static OwnedPet? _petAt(
      List<OwnedPet> roster, Set<String> team, int slot) {
    final teamList = team.toList();
    if (slot >= teamList.length) return null;
    final uid = teamList[slot];
    return roster.where((p) => p.uid == uid).firstOrNull;
  }
}

// ── Team slot ──────────────────────────────────────────────────────────────────

class _TeamSlot extends StatelessWidget {
  final OwnedPet? pet;
  final int index;
  final void Function(String uid) onRemove;

  const _TeamSlot({required this.pet, required this.index, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final color = pet != null ? _classColor(pet!.toCreatureDefinition().bodyClass) : Colors.white12;
    return GestureDetector(
      onTap: pet != null ? () => onRemove(pet!.uid) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        height: 44,
        decoration: BoxDecoration(
          color: color.withValues(alpha: pet != null ? 0.12 : 0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: pet != null ? color.withValues(alpha: 0.5) : Colors.white12,
          ),
        ),
        child: Row(children: [
          // Mini renderer
          SizedBox(
            width: 44, height: 44,
            child: pet != null
                ? PetRendererWidget.fromOwned(pet!, size: 44)
                : Center(
                    child: Text('${index + 1}',
                        style: const TextStyle(
                            color: Colors.white24, fontSize: 14,
                            fontWeight: FontWeight.w900))),
          ),
          if (pet != null) ...[
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(pet!.classLabel,
                      style: TextStyle(
                          color: color, fontSize: 10,
                          fontWeight: FontWeight.w700)),
                  Text(pet!.purityLabel,
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 9)),
                ],
              ),
            ),
            const Icon(Icons.close, color: Colors.white24, size: 14),
            const SizedBox(width: 6),
          ],
        ]),
      ),
    );
  }
}

// ── Pet card ──────────────────────────────────────────────────────────────────

class _PetCard extends StatelessWidget {
  final OwnedPet pet;
  final bool inTeam;
  final bool highlighted;
  final VoidCallback onTap;

  const _PetCard({
    required this.pet,
    required this.inTeam,
    required this.highlighted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final def = pet.toCreatureDefinition();
    final cls = def.bodyClass;
    final color = _classColor(cls);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: inTeam
              ? color.withValues(alpha: 0.15)
              : const Color(0xFF111A28),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: inTeam
                ? color.withValues(alpha: 0.8)
                : Colors.white.withValues(alpha: 0.08),
            width: inTeam ? 2 : 1,
          ),
          boxShadow: inTeam
              ? [BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: 12, spreadRadius: 1)]
              : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // ── Pet renderer ───────────────────────────────────────────────
            Expanded(
              child: Stack(children: [
                Center(
                  child: PetRendererWidget.fromOwned(pet, size: 120),
                ),
                if (inTeam)
                  Positioned(
                    top: 6, right: 6,
                    child: Container(
                      width: 20, height: 20,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle, color: color),
                      child: const Icon(Icons.check,
                          color: Colors.white, size: 12),
                    ),
                  ),
              ]),
            ),

            // ── Info row ───────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Class badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                          color: color.withValues(alpha: 0.5)),
                    ),
                    child: Text(cls.displayName,
                        style: TextStyle(
                            color: color,
                            fontSize: 9,
                            fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(height: 4),

                  // Purity stars
                  Text(
                    List.generate(4, (i) =>
                        i < pet.purity ? '★' : '☆').join(),
                    style: TextStyle(
                      color: pet.purity == 4
                          ? Colors.amber
                          : Colors.white38,
                      fontSize: 10,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Part class dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _Dot(def.horn.partClass),
                      const SizedBox(width: 3),
                      _Dot(def.back.partClass),
                      const SizedBox(width: 3),
                      _Dot(def.tail.partClass),
                      const SizedBox(width: 3),
                      _Dot(def.mouth.partClass),
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
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _Dot extends StatelessWidget {
  final CreatureClass cls;
  const _Dot(this.cls);

  @override
  Widget build(BuildContext context) => Container(
    width: 8, height: 8,
    decoration: BoxDecoration(
        shape: BoxShape.circle, color: _classColor(cls)),
  );
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const Center(
    child: Text('No pets yet',
        style: TextStyle(color: Colors.white24, fontSize: 16)),
  );
}

Color _classColor(CreatureClass cls) => switch (cls) {
  CreatureClass.plant   => const Color(0xFF4CAF50),
  CreatureClass.aquatic => const Color(0xFF29B6F6),
  CreatureClass.beast   => const Color(0xFFFF9800),
  CreatureClass.reptile => const Color(0xFF66BB6A),
  CreatureClass.bird    => const Color(0xFFFF80AB),
  CreatureClass.bug     => const Color(0xFFFF5252),
};
