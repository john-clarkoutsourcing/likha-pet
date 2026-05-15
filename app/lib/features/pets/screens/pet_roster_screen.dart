import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../battle/data/creature_registry.dart';
import '../../battle/screens/battle_screen.dart';
import '../models/owned_pet.dart';
import '../providers/player_provider.dart';

// ── Class colours ─────────────────────────────────────────────────────────────

Color _clsColor(String cls) => switch (cls) {
  'plant'   => const Color(0xFF4CAF50),
  'aquatic' => const Color(0xFF29B6F6),
  'beast'   => const Color(0xFFFF9800),
  'reptile' => const Color(0xFF66BB6A),
  'bird'    => const Color(0xFFFF80AB),
  'bug'     => const Color(0xFFFF5252),
  _         => const Color(0xFF9C27B0),
};

// ── Screen ────────────────────────────────────────────────────────────────────

class PetRosterScreen extends ConsumerStatefulWidget {
  const PetRosterScreen({super.key});

  @override
  ConsumerState<PetRosterScreen> createState() => _PetRosterScreenState();
}

class _PetRosterScreenState extends ConsumerState<PetRosterScreen> {
  int? _selectedSlot; // which team slot is being reassigned (0/1/2)

  @override
  Widget build(BuildContext context) {
    final playerData = ref.watch(playerProvider);
    final roster     = playerData.roster;
    final activeTeam = playerData.activeTeam;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(children: [
          // ── Header ──────────────────────────────────────────────────────────
          _Header(crystals: playerData.soulCrystals),

          // ── Active team strip ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
            child: Row(children: [
              Text('ACTIVE TEAM',
                style: GoogleFonts.rajdhani(
                  color: Colors.white38, fontSize: 11,
                  fontWeight: FontWeight.w800, letterSpacing: 1.5)),
              const Spacer(),
              if (_selectedSlot != null)
                Text('Tap a pet to assign to slot ${_selectedSlot! + 1}',
                  style: const TextStyle(color: Colors.amberAccent, fontSize: 10)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Row(
              children: List.generate(3, (i) {
                final uid = i < activeTeam.length ? activeTeam[i] : null;
                final pet = uid != null ? playerData.petById(uid) : null;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(left: i == 0 ? 0 : 6),
                    child: _TeamSlot(
                      pet: pet,
                      slotIndex: i,
                      isSelected: _selectedSlot == i,
                      onTap: () => setState(() =>
                          _selectedSlot = _selectedSlot == i ? null : i),
                    ),
                  ),
                );
              }),
            ),
          ),

          Divider(color: Colors.white10, height: 1),

          // ── Roster label ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
            child: Row(
              children: [
                Text('MY PETS  (${roster.length})',
                  style: GoogleFonts.rajdhani(
                    color: Colors.white38, fontSize: 11,
                    fontWeight: FontWeight.w800, letterSpacing: 1.5)),
              ],
            ),
          ),

          // ── Pet grid ────────────────────────────────────────────────────────
          Expanded(
            child: roster.isEmpty
                ? _EmptyState()
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.78,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: roster.length,
                    itemBuilder: (_, i) {
                      final pet     = roster[i];
                      final inTeam  = activeTeam.contains(pet.uid);
                      final inSlot  = inTeam
                          ? activeTeam.indexOf(pet.uid) + 1
                          : null;
                      return _PetCard(
                        pet: pet,
                        inSlot: inSlot,
                        isPickMode: _selectedSlot != null,
                        onTap: () {
                          if (_selectedSlot != null) {
                            _assignToSlot(pet.uid, _selectedSlot!);
                          }
                        },
                      );
                    },
                  ),
          ),
        ]),
      ),

      // ── Battle button ────────────────────────────────────────────────────────
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: playerData.hasFullTeam
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _selectedSlot != null
                      ? null
                      : () => context.push(
                          Routes.battle,
                          extra: const BattleScreenArgs(
                            playerTeamName: 'My Team',
                            enemyTeamName:  'Rivals',
                          ),
                        ),
                  icon: const Text('⚔', style: TextStyle(fontSize: 18)),
                  label: Text('Battle',
                      style: GoogleFonts.rajdhani(
                          fontSize: 18, fontWeight: FontWeight.w800)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedSlot != null
                        ? Colors.white12
                        : AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  void _assignToSlot(String petUid, int slot) {
    final current = List<String>.from(
        ref.read(playerProvider).activeTeam.take(3));

    // Ensure list has 3 slots
    while (current.length < 3) { current.add(''); }

    // Remove this pet from any existing slot first
    for (var i = 0; i < current.length; i++) {
      if (current[i] == petUid) current[i] = '';
    }
    current[slot] = petUid;

    // Remove empty slots and trim to 3
    final filled = current.where((uid) => uid.isNotEmpty).toList();
    ref.read(playerProvider.notifier).setActiveTeam(
        filled.length == 3 ? filled : filled);

    setState(() => _selectedSlot = null);
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final int crystals;
  const _Header({required this.crystals});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 8, 12, 4),
    child: Row(children: [
      IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white70),
        onPressed: () => context.pop(),
      ),
      Text('My Pets',
        style: GoogleFonts.rajdhani(
          color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
      const Spacer(),
      // Crystal counter
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF1A2535),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Text('💎', style: TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Text('$crystals',
            style: const TextStyle(
              color: Color(0xFF44BBFF), fontSize: 12, fontWeight: FontWeight.w800)),
        ]),
      ),
      const SizedBox(width: 8),
      // Breed button
      GestureDetector(
        onTap: () => context.push(Routes.breed),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFF9C27B0).withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: const Color(0xFF9C27B0).withValues(alpha: 0.5)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Text('🧬', style: TextStyle(fontSize: 12)),
            const SizedBox(width: 4),
            Text('Breed',
              style: GoogleFonts.rajdhani(
                color: const Color(0xFFCE93D8),
                fontSize: 12, fontWeight: FontWeight.w800)),
          ]),
        ),
      ),
    ]),
  );
}

// ── Team slot ─────────────────────────────────────────────────────────────────

class _TeamSlot extends StatelessWidget {
  final OwnedPet? pet;
  final int slotIndex;
  final bool isSelected;
  final VoidCallback onTap;
  const _TeamSlot({
    required this.pet,
    required this.slotIndex,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final empty = pet == null;
    final cls   = empty ? '' : (kBodyCatalogue[pet!.bodyId]?.className ?? '');
    final color = empty ? Colors.white12 : _clsColor(cls);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 72,
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.25)
              : color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : color.withValues(alpha: 0.35),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: empty
            ? Center(child: Icon(Icons.add, color: Colors.white24, size: 22))
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(children: [
                  Image.asset(
                    'assets/images/icons/mini-$cls.png',
                    width: 28, height: 28,
                    errorBuilder: (_, __, ___) => const SizedBox(width: 28),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(pet!.name,
                          style: GoogleFonts.rajdhani(
                            color: Colors.white, fontSize: 12,
                            fontWeight: FontWeight.w800),
                          overflow: TextOverflow.ellipsis),
                        Text(pet!.classLabel,
                          style: TextStyle(
                            color: color, fontSize: 9,
                            fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ]),
              ),
      ),
    );
  }
}

// ── Pet grid card ─────────────────────────────────────────────────────────────

class _PetCard extends StatelessWidget {
  final OwnedPet pet;
  final int?     inSlot;       // 1/2/3 if in active team, null otherwise
  final bool     isPickMode;
  final VoidCallback onTap;

  const _PetCard({
    required this.pet,
    required this.inSlot,
    required this.isPickMode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final body  = kBodyCatalogue[pet.bodyId];
    final cls   = body?.className ?? 'beast';
    final color = _clsColor(cls);
    final stats = pet.toCreatureDefinition().computedStats;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: const Color(0xFF111A28),
          border: Border.all(
            color: isPickMode ? color : color.withValues(alpha: 0.35),
            width: isPickMode ? 1.5 : 1,
          ),
          boxShadow: isPickMode ? [
            BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 8),
          ] : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [

            // ── Class icon area ──────────────────────────────────────────────
            Expanded(
              child: Stack(
                children: [
                  // Gradient background
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(13)),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            color.withValues(alpha: 0.25),
                            color.withValues(alpha: 0.08),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Class icon
                  Center(
                    child: Image.asset(
                      'assets/images/icons/$cls.png',
                      width: 72, height: 72,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.pets, size: 48, color: color.withValues(alpha: 0.5)),
                    ),
                  ),
                  // Active team badge
                  if (inSlot != null)
                    Positioned(
                      top: 6, right: 6,
                      child: Container(
                        width: 22, height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary,
                          boxShadow: [BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.5),
                              blurRadius: 4)],
                        ),
                        child: Center(
                          child: Text('$inSlot',
                            style: const TextStyle(
                              color: Colors.white, fontSize: 11,
                              fontWeight: FontWeight.w900)),
                        ),
                      ),
                    ),
                  // Purity badge
                  Positioned(
                    top: 6, left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(pet.purityLabel,
                        style: TextStyle(
                          color: pet.purity == 4 ? Colors.amberAccent : Colors.white60,
                          fontSize: 9, fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            ),

            // ── Info strip ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + class
                  Row(children: [
                    Expanded(
                      child: Text(pet.name,
                        style: GoogleFonts.rajdhani(
                          color: Colors.white, fontSize: 13,
                          fontWeight: FontWeight.w800),
                        overflow: TextOverflow.ellipsis),
                    ),
                    Text(pet.classLabel,
                      style: TextStyle(
                        color: color, fontSize: 9,
                        fontWeight: FontWeight.w700)),
                  ]),
                  const SizedBox(height: 4),
                  // Part class dots
                  Row(children: [
                    _partDot(pet.hornId),
                    const SizedBox(width: 3),
                    _partDot(pet.backId),
                    const SizedBox(width: 3),
                    _partDot(pet.tailId),
                    const SizedBox(width: 3),
                    _partDot(pet.mouthId),
                    const Spacer(),
                    // HP stat
                    Icon(Icons.favorite, size: 9, color: const Color(0xFF66FF88)),
                    const SizedBox(width: 2),
                    Text('${stats.hp}',
                      style: const TextStyle(
                        color: Color(0xFF66FF88), fontSize: 9,
                        fontWeight: FontWeight.w700)),
                    const SizedBox(width: 6),
                    Icon(Icons.bolt, size: 9, color: const Color(0xFFFFCC44)),
                    const SizedBox(width: 2),
                    Text('${stats.speed}',
                      style: const TextStyle(
                        color: Color(0xFFFFCC44), fontSize: 9,
                        fontWeight: FontWeight.w700)),
                  ]),
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
      width: 10, height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.8),
        border: Border.all(color: color, width: 0.5),
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
        Text('No pets yet',
          style: GoogleFonts.rajdhani(
            color: Colors.white38, fontSize: 20,
            fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        const Text('Hatch an egg to get started',
          style: TextStyle(color: Colors.white24, fontSize: 12)),
      ],
    ),
  );
}
