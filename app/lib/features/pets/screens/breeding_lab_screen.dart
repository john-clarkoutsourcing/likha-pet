import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:likha_pet_battle_engine/trait.dart';
import '../../battle/data/creature_registry.dart';
import '../models/owned_pet.dart';
import '../providers/player_provider.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

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

class BreedingLabScreen extends ConsumerStatefulWidget {
  const BreedingLabScreen({super.key});

  @override
  ConsumerState<BreedingLabScreen> createState() => _BreedingLabState();
}

class _BreedingLabState extends ConsumerState<BreedingLabScreen> {
  OwnedPet? _parentA;
  OwnedPet? _parentB;
  final _nameCtrl = TextEditingController();
  bool _breeding  = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  int get _cost {
    if (_parentA == null || _parentB == null) return 0;
    return ref.read(playerProvider.notifier)
        .breedCost(_parentA!.uid, _parentB!.uid);
  }

  bool get _canBreed {
    final p = ref.read(playerProvider);
    return _parentA != null &&
        _parentB != null &&
        _parentA!.uid != _parentB!.uid &&
        _parentA!.canBreed &&
        _parentB!.canBreed &&
        p.soulCrystals >= _cost;
  }

  @override
  Widget build(BuildContext context) {
    final player   = ref.watch(playerProvider);
    final crystals = player.soulCrystals;

    return Scaffold(
      backgroundColor: const Color(0xFF0A1220),
      body: SafeArea(
        child: Column(children: [
          // ── Header ──────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 16, 4),
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white70),
                onPressed: () => context.pop(),
              ),
              Text('Breeding Lab',
                style: GoogleFonts.rajdhani(
                  color: Colors.white, fontSize: 22,
                  fontWeight: FontWeight.w800)),
              const Spacer(),
              _CrystalBadge(crystals: crystals),
            ]),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Column(children: [

                // ── Parent selection row ─────────────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _ParentCard(
                        label: 'Parent A',
                        pet: _parentA,
                        onSelect: () => _pickParent(
                            isA: true, exclude: _parentB?.uid),
                        onClear: () => setState(() => _parentA = null),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(top: 32),
                      child: _HeartDivider(),
                    ),
                    Expanded(
                      child: _ParentCard(
                        label: 'Parent B',
                        pet: _parentB,
                        onSelect: () => _pickParent(
                            isA: false, exclude: _parentA?.uid),
                        onClear: () => setState(() => _parentB = null),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // ── Offspring preview ────────────────────────────────────────
                if (_parentA != null && _parentB != null) ...[
                  _OffspringPreview(parentA: _parentA!, parentB: _parentB!),
                  const SizedBox(height: 16),

                  // Name input
                  TextField(
                    controller: _nameCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Offspring name (optional)',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: const Color(0xFF1A2535),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.white12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF1E3A5F)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // ── Breed cost + breed status ────────────────────────────────
                if (_parentA != null && _parentB != null) ...[
                  _BreedInfo(
                    parentA: _parentA!,
                    parentB: _parentB!,
                    cost: _cost,
                    crystals: crystals,
                  ),
                  const SizedBox(height: 16),
                ],

                // ── Breed button ─────────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _canBreed && !_breeding ? _doBreed : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9C27B0),
                      disabledBackgroundColor: Colors.white10,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _breeding
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text(
                            _parentA == null || _parentB == null
                                ? 'Select two parents'
                                : 'Breed  ·  💎 $_cost',
                            style: GoogleFonts.rajdhani(
                              color: Colors.white, fontSize: 18,
                              fontWeight: FontWeight.w800)),
                  ),
                ),

                // ── Tips ─────────────────────────────────────────────────────
                const SizedBox(height: 24),
                _BreedingTips(),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> _doBreed() async {
    setState(() => _breeding = true);

    final name = _nameCtrl.text.trim().isEmpty
        ? 'Offspring'
        : _nameCtrl.text.trim();

    final offspring = ref.read(playerProvider.notifier)
        .breed(_parentA!.uid, _parentB!.uid, name);

    await Future.delayed(const Duration(milliseconds: 800)); // hatch effect
    if (!mounted) return;

    setState(() => _breeding = false);

    if (offspring != null) {
      _nameCtrl.clear();
      setState(() { _parentA = null; _parentB = null; });
      _showHatchResult(offspring);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Breeding failed — check crystals')),
      );
    }
  }

  void _showHatchResult(OwnedPet pet) {
    final body  = kBodyCatalogue[pet.bodyId];
    final cls   = body?.className ?? 'beast';
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: const Color(0xFF111A28),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('🥚 Hatched!',
              style: GoogleFonts.rajdhani(
                color: Colors.white, fontSize: 26,
                fontWeight: FontWeight.w900)),
            const SizedBox(height: 16),
            Image.asset('assets/images/icons/$cls.png',
                width: 80, height: 80,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.pets, size: 60, color: Colors.white54)),
            const SizedBox(height: 12),
            Text(pet.name,
              style: GoogleFonts.rajdhani(
                color: Colors.white, fontSize: 22,
                fontWeight: FontWeight.w800)),
            Text('${body?.bodyClass.displayName ?? ''} body  ·  ${pet.purityLabel} purity',
              style: const TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 8),
            // Part dots
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (final id in [pet.hornId, pet.backId, pet.tailId, pet.mouthId]) ...[
                _PartDotLarge(partId: id),
                const SizedBox(width: 6),
              ],
            ]),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9C27B0),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: Text('Awesome!',
                  style: GoogleFonts.rajdhani(
                    color: Colors.white, fontSize: 16,
                    fontWeight: FontWeight.w800)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _pickParent({required bool isA, String? exclude}) async {
    final roster = ref.read(playerProvider).roster
        .where((p) => p.canBreed && p.uid != exclude)
        .toList();

    if (roster.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No eligible parents — pets must have < 5 breeds')),
      );
      return;
    }

    final picked = await showModalBottomSheet<OwnedPet>(
      context: context,
      backgroundColor: const Color(0xFF111A28),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (_) => _ParentPicker(roster: roster),
    );

    if (picked != null && mounted) {
      setState(() => isA ? _parentA = picked : _parentB = picked);
    }
  }
}

// ── Parent picker bottom sheet ─────────────────────────────────────────────────

class _ParentPicker extends StatelessWidget {
  final List<OwnedPet> roster;
  const _ParentPicker({required this.roster});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (_, ctrl) => Column(children: [
        Container(
          width: 40, height: 4,
          margin: const EdgeInsets.only(top: 10, bottom: 10),
          decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text('Select Parent',
            style: GoogleFonts.rajdhani(
              color: Colors.white, fontSize: 18,
              fontWeight: FontWeight.w800)),
        ),
        Expanded(
          child: ListView.builder(
            controller: ctrl,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: roster.length,
            itemBuilder: (_, i) {
              final pet  = roster[i];
              final body = kBodyCatalogue[pet.bodyId];
              final cls  = body?.className ?? 'beast';
              final color = _clsColor(cls);
              return ListTile(
                onTap: () => Navigator.pop(context, pet),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 4),
                leading: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: 0.2),
                    border: Border.all(color: color, width: 1.5),
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/icons/$cls.png',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Icon(Icons.pets, color: color, size: 22),
                    ),
                  ),
                ),
                title: Text(pet.name,
                  style: GoogleFonts.rajdhani(
                    color: Colors.white, fontSize: 15,
                    fontWeight: FontWeight.w700)),
                subtitle: Text(
                  '${body?.bodyClass.displayName ?? ''}  ·  ${pet.purityLabel}  ·  ${pet.breedCount}/5 breeds',
                  style: const TextStyle(color: Colors.white54, fontSize: 11)),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  for (final id in [pet.hornId, pet.backId, pet.tailId, pet.mouthId])
                    Padding(
                      padding: const EdgeInsets.only(left: 3),
                      child: _PartDotSmall(partId: id),
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

// ── Parent card ───────────────────────────────────────────────────────────────

class _ParentCard extends StatelessWidget {
  final String   label;
  final OwnedPet? pet;
  final VoidCallback onSelect;
  final VoidCallback onClear;
  const _ParentCard({
    required this.label,
    required this.pet,
    required this.onSelect,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final body  = pet != null ? kBodyCatalogue[pet!.bodyId] : null;
    final cls   = body?.className ?? '';
    final color = cls.isNotEmpty ? _clsColor(cls) : Colors.white24;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label,
          style: GoogleFonts.rajdhani(
            color: Colors.white54, fontSize: 11,
            fontWeight: FontWeight.w800, letterSpacing: 1)),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onSelect,
          child: Container(
            height: 130,
            decoration: BoxDecoration(
              color: pet != null
                  ? color.withValues(alpha: 0.12)
                  : const Color(0xFF111A28),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: pet != null ? color.withValues(alpha: 0.5) : Colors.white12,
                width: 1.5,
              ),
            ),
            child: pet == null
                ? Center(child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_circle_outline,
                          color: Colors.white24, size: 28),
                      const SizedBox(height: 4),
                      const Text('Select',
                        style: TextStyle(color: Colors.white38, fontSize: 11)),
                    ],
                  ))
                : Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset('assets/images/icons/$cls.png',
                                width: 48, height: 48,
                                errorBuilder: (_, __, ___) =>
                                    Icon(Icons.pets, size: 40,
                                        color: color.withValues(alpha: 0.6))),
                            const SizedBox(height: 6),
                            Text(pet!.name,
                              style: GoogleFonts.rajdhani(
                                color: Colors.white, fontSize: 12,
                                fontWeight: FontWeight.w800),
                              overflow: TextOverflow.ellipsis),
                            Text('${body?.bodyClass.displayName ?? ''}  ${pet!.purityLabel}',
                              style: TextStyle(
                                color: color, fontSize: 9,
                                fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                for (final id in [pet!.hornId, pet!.backId,
                                    pet!.tailId, pet!.mouthId]) ...[
                                  _PartDotSmall(partId: id),
                                  const SizedBox(width: 3),
                                ],
                              ],
                            ),
                            Text('${pet!.breedCount}/5 breeds',
                              style: const TextStyle(
                                color: Colors.white38, fontSize: 9)),
                          ],
                        ),
                      ),
                      Positioned(
                        top: 4, right: 4,
                        child: GestureDetector(
                          onTap: onClear,
                          child: Container(
                            width: 20, height: 20,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black45,
                            ),
                            child: const Icon(Icons.close,
                                size: 12, color: Colors.white54),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

// ── Heart divider ─────────────────────────────────────────────────────────────

class _HeartDivider extends StatelessWidget {
  const _HeartDivider();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 1, height: 20, color: Colors.white12),
      const Text('❤', style: TextStyle(fontSize: 18)),
      Container(width: 1, height: 20, color: Colors.white12),
    ]),
  );
}

// ── Offspring preview ─────────────────────────────────────────────────────────

class _OffspringPreview extends StatelessWidget {
  final OwnedPet parentA;
  final OwnedPet parentB;
  const _OffspringPreview({required this.parentA, required this.parentB});

  @override
  Widget build(BuildContext context) {
    final bodyA = kBodyCatalogue[parentA.bodyId];
    final bodyB = kBodyCatalogue[parentB.bodyId];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111A28),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text('🥚', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Text('Offspring Preview',
              style: GoogleFonts.rajdhani(
                color: Colors.white, fontSize: 15,
                fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 10),

          // Body
          _PreviewRow(
            slot: 'BODY',
            optionA: bodyA?.bodyClass.displayName ?? '?',
            optionB: bodyB?.bodyClass.displayName ?? '?',
            colorA: _clsColor(bodyA?.className ?? ''),
            colorB: _clsColor(bodyB?.className ?? ''),
            prob: '50%',
          ),

          const SizedBox(height: 6),
          _previewSlot('HORN', parentA.hornId, parentB.hornId),
          const SizedBox(height: 4),
          _previewSlot('BACK', parentA.backId, parentB.backId),
          const SizedBox(height: 4),
          _previewSlot('TAIL', parentA.tailId, parentB.tailId),
          const SizedBox(height: 4),
          _previewSlot('MOUTH', parentA.mouthId, parentB.mouthId),

          const SizedBox(height: 10),
          const Text(
            'Each part: 37.5% from A · 37.5% from B · 25% from hidden genes',
            style: TextStyle(color: Colors.white38, fontSize: 9, height: 1.4)),
        ],
      ),
    );
  }

  Widget _previewSlot(String label, String idA, String idB) {
    final partA = kPartCatalogue[idA];
    final partB = kPartCatalogue[idB];
    final traitA = partA?.buildTrait().name ?? idA;
    final traitB = partB?.buildTrait().name ?? idB;
    return _PreviewRow(
      slot: label,
      optionA: traitA,
      optionB: traitB,
      colorA: _clsColor(partA?.className ?? ''),
      colorB: _clsColor(partB?.className ?? ''),
      prob: '37.5%',
    );
  }
}

class _PreviewRow extends StatelessWidget {
  final String slot, optionA, optionB, prob;
  final Color colorA, colorB;
  const _PreviewRow({
    required this.slot, required this.optionA, required this.optionB,
    required this.colorA, required this.colorB, required this.prob,
  });

  @override
  Widget build(BuildContext context) => Row(children: [
    SizedBox(
      width: 44,
      child: Text(slot,
        style: const TextStyle(
          color: Colors.white38, fontSize: 8,
          fontWeight: FontWeight.w800, letterSpacing: 0.8)),
    ),
    Expanded(
      child: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: colorA.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: colorA.withValues(alpha: 0.4)),
          ),
          child: Text(optionA,
            style: TextStyle(color: colorA, fontSize: 8,
                fontWeight: FontWeight.w700),
            overflow: TextOverflow.ellipsis),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text('$prob each',
            style: const TextStyle(color: Colors.white24, fontSize: 8)),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: colorB.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: colorB.withValues(alpha: 0.4)),
          ),
          child: Text(optionB,
            style: TextStyle(color: colorB, fontSize: 8,
                fontWeight: FontWeight.w700),
            overflow: TextOverflow.ellipsis),
        ),
      ]),
    ),
  ]);
}

// ── Breed info ────────────────────────────────────────────────────────────────

class _BreedInfo extends StatelessWidget {
  final OwnedPet parentA, parentB;
  final int cost, crystals;
  const _BreedInfo({
    required this.parentA, required this.parentB,
    required this.cost, required this.crystals,
  });

  @override
  Widget build(BuildContext context) {
    final canAfford = crystals >= cost;
    final sameUid   = parentA.uid == parentB.uid;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2535),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Breed cost',
            style: TextStyle(color: Colors.white54, fontSize: 12)),
          Text('💎 $cost',
            style: TextStyle(
              color: canAfford ? const Color(0xFF44BBFF) : Colors.redAccent,
              fontSize: 14, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 4),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Your crystals',
            style: TextStyle(color: Colors.white54, fontSize: 12)),
          Text('💎 $crystals',
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ]),
        if (!canAfford) ...[
          const SizedBox(height: 6),
          const Text('Not enough crystals — win battles to earn more',
            style: TextStyle(color: Colors.redAccent, fontSize: 10)),
        ],
        if (sameUid) ...[
          const SizedBox(height: 6),
          const Text('Cannot breed a pet with itself',
            style: TextStyle(color: Colors.redAccent, fontSize: 10)),
        ],
        if (!parentA.canBreed || !parentB.canBreed) ...[
          const SizedBox(height: 6),
          const Text('One parent has reached max breed count (5)',
            style: TextStyle(color: Colors.orangeAccent, fontSize: 10)),
        ],
      ]),
    );
  }
}

// ── Crystal badge ─────────────────────────────────────────────────────────────

class _CrystalBadge extends StatelessWidget {
  final int crystals;
  const _CrystalBadge({required this.crystals});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0xFF1A2535),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white12),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      const Text('💎', style: TextStyle(fontSize: 14)),
      const SizedBox(width: 4),
      Text('$crystals',
        style: const TextStyle(
          color: Color(0xFF44BBFF), fontSize: 13,
          fontWeight: FontWeight.w800)),
    ]),
  );
}

// ── Breeding tips ─────────────────────────────────────────────────────────────

class _BreedingTips extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.03),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.white10),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Breeding Tips',
          style: GoogleFonts.rajdhani(
            color: Colors.white54, fontSize: 12,
            fontWeight: FontWeight.w800, letterSpacing: 1)),
        const SizedBox(height: 6),
        for (final tip in [
          '🧬 Offspring inherit dominant genes (37.5% each parent)',
          '🔮 Hidden recessive genes can surface — surprise parts!',
          '⭐ Pure-breed (4/4) pets get +10% same-class card bonus',
          '⚡ Higher breed count = higher cost, max 5 breeds each',
          '💎 Win battles to earn Soul Crystals for breeding',
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(tip,
              style: const TextStyle(
                color: Colors.white38, fontSize: 10, height: 1.4)),
          ),
      ],
    ),
  );
}

// ── Small helpers ─────────────────────────────────────────────────────────────

class _PartDotSmall extends StatelessWidget {
  final String partId;
  const _PartDotSmall({required this.partId});

  @override
  Widget build(BuildContext context) {
    final part  = kPartCatalogue[partId];
    final color = part != null ? _clsColor(part.className) : Colors.white24;
    return Container(
      width: 9, height: 9,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.8),
      ),
    );
  }
}

class _PartDotLarge extends StatelessWidget {
  final String partId;
  const _PartDotLarge({required this.partId});

  @override
  Widget build(BuildContext context) {
    final part  = kPartCatalogue[partId];
    final color = part != null ? _clsColor(part.className) : Colors.white24;
    final cls   = part?.className ?? '';
    return Column(children: [
      Container(
        width: 30, height: 30,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.2),
          border: Border.all(color: color, width: 1.5),
        ),
        child: Center(
          child: Image.asset(
            'assets/images/part-icons/$cls-${part?.partType ?? 'horn'}.png',
            width: 20, height: 20,
            errorBuilder: (_, __, ___) => Icon(
              Icons.circle, size: 12, color: color),
          ),
        ),
      ),
      const SizedBox(height: 3),
      Text(part?.partType.toUpperCase() ?? '',
        style: const TextStyle(color: Colors.white38, fontSize: 7,
            fontWeight: FontWeight.w700)),
    ]);
  }
}
