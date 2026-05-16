import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:likha_pet_battle_engine/trait.dart';
import '../../../core/theme/app_colors.dart';
import '../../battle/data/creature_registry.dart';
import '../../battle/widgets/pet_renderer_widget.dart';
import '../../pets/models/owned_pet.dart';

// ── PetRevealSheet ────────────────────────────────────────────────────────────
//
// Full-screen bottom sheet shown after hatching an egg.
// Displays the hatched pet Axie-style: body class + 4 parts with their traits.

class PetRevealSheet extends StatelessWidget {
  final OwnedPet pet;
  final VoidCallback onClose;

  const PetRevealSheet({super.key, required this.pet, required this.onClose});

  static Future<void> show(BuildContext context, OwnedPet pet) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PetRevealSheet(pet: pet, onClose: () => Navigator.pop(context)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final def       = pet.toCreatureDefinition();
    final body      = def.body;
    final stats     = def.computedStats;
    final bodyColor = _classColor(body.bodyClass);
    final size      = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;

    return DraggableScrollableSheet(
      initialChildSize: isLandscape ? 0.98 : 0.92,
      minChildSize:     isLandscape ? 0.80 : 0.50,
      maxChildSize:     0.98,
      builder: (_, ctrl) => Container(
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(color: bodyColor.withValues(alpha: 0.4)),
        ),
        child: isLandscape
            ? _buildLandscape(context, def, body, stats, bodyColor, ctrl)
            : _buildPortrait(context, def, body, stats, bodyColor, ctrl),
      ),
    );
  }

  // ── Landscape: pet on left, info scrolling on right ───────────────────────

  Widget _buildLandscape(BuildContext context, CreatureDefinition def,
      BodyDefinition body,
      ({int hp, int speed, int skill, int morale}) stats,
      Color bodyColor,
      ScrollController ctrl) {
    final screenH = MediaQuery.of(context).size.height;
    final petSize = (screenH * 0.80).clamp(140.0, 340.0);

    return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // ── Pet panel ─────────────────────────────────────────────────────────
      Container(
        width: petSize,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [
              bodyColor.withValues(alpha: 0.18),
              bodyColor.withValues(alpha: 0.04),
            ],
          ),
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
          PetRendererWidget(def: def, size: petSize * 0.85),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _ClassBadge(cls: body.bodyClass, color: bodyColor),
            const SizedBox(width: 8),
            _PurityBadge(purity: pet.purity),
          ]),
          const SizedBox(height: 8),
        ]),
      ),

      // ── Info panel ────────────────────────────────────────────────────────
      Expanded(
        child: ListView(
          controller: ctrl,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          children: [
            // Handle
            Center(
              child: Container(
                width: 32, height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),

            // Stats
            Row(children: [
              _StatBox('❤', '${stats.hp}',     const Color(0xFF66FF88)),
              const SizedBox(width: 6),
              _StatBox('⚡', '${stats.speed}',  const Color(0xFFFFCC44)),
              const SizedBox(width: 6),
              _StatBox('🏅', '${stats.skill}',  const Color(0xFF88CCFF)),
              const SizedBox(width: 6),
              _StatBox('🔥', '${stats.morale}', const Color(0xFFFF9944)),
            ]),

            const SizedBox(height: 12),

            Text('Parts & Skills',
              style: GoogleFonts.rajdhani(
                color: Colors.white70, fontSize: 12,
                fontWeight: FontWeight.w700, letterSpacing: 1)),
            const SizedBox(height: 8),

            for (final slot in ['horn', 'back', 'tail', 'mouth'])
              _PartRow(part: _partFor(def, slot), slot: slot),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onClose,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: Text('Awesome!',
                  style: GoogleFonts.rajdhani(
                    color: Colors.white, fontSize: 15,
                    fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    ]);
  }

  // ── Portrait: pet on top, info below ──────────────────────────────────────

  Widget _buildPortrait(BuildContext context, CreatureDefinition def,
      BodyDefinition body,
      ({int hp, int speed, int skill, int morale}) stats,
      Color bodyColor,
      ScrollController ctrl) {
    final screenH = MediaQuery.of(context).size.height;
    final petH    = (screenH * 0.32).clamp(160.0, 280.0);

    return ListView(
      controller: ctrl,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        Center(
          child: Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
                color: Colors.white24, borderRadius: BorderRadius.circular(2)),
          ),
        ),

        Container(
          height: petH,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [
                bodyColor.withValues(alpha: 0.20),
                bodyColor.withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: bodyColor.withValues(alpha: 0.4)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Center(
            child: PetRendererWidget(def: def, size: 400),
          ),
        ),

        const SizedBox(height: 14),

        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _ClassBadge(cls: body.bodyClass, color: bodyColor),
          const SizedBox(width: 10),
          _PurityBadge(purity: pet.purity),
        ]),

        const SizedBox(height: 16),

        Row(children: [
          _StatBox('❤ HP',  '${stats.hp}',     const Color(0xFF66FF88)),
          const SizedBox(width: 8),
          _StatBox('⚡ SPD', '${stats.speed}',  const Color(0xFFFFCC44)),
          const SizedBox(width: 8),
          _StatBox('🏅 SKL', '${stats.skill}',  const Color(0xFF88CCFF)),
          const SizedBox(width: 8),
          _StatBox('🔥 MOR', '${stats.morale}', const Color(0xFFFF9944)),
        ]),

        const SizedBox(height: 20),

        Text('Parts & Skills',
          style: GoogleFonts.rajdhani(
            color: Colors.white70, fontSize: 13,
            fontWeight: FontWeight.w700, letterSpacing: 1)),
        const SizedBox(height: 12),

        for (final slot in ['horn', 'back', 'tail', 'mouth'])
          _PartRow(part: _partFor(def, slot), slot: slot),

        const SizedBox(height: 20),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: onClose,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Awesome!',
              style: GoogleFonts.rajdhani(
                color: Colors.white, fontSize: 16,
                fontWeight: FontWeight.w800)),
          ),
        ),
      ],
    );
  }

  PartDefinition _partFor(CreatureDefinition def, String slot) => switch (slot) {
    'horn'  => def.horn,
    'back'  => def.back,
    'tail'  => def.tail,
    'mouth' => def.mouth,
    _       => def.horn,
  };

  static Color _classColor(CreatureClass cls) => switch (cls) {
    CreatureClass.plant   => const Color(0xFF4CAF50),
    CreatureClass.aquatic => const Color(0xFF29B6F6),
    CreatureClass.beast   => const Color(0xFFFF9800),
    CreatureClass.reptile => const Color(0xFF66BB6A),
    CreatureClass.bird    => const Color(0xFFFF80AB),
    CreatureClass.bug     => const Color(0xFFFF5252),
  };

}

// ── Part row ──────────────────────────────────────────────────────────────────

class _PartRow extends StatelessWidget {
  final PartDefinition part;
  final String slot;

  const _PartRow({required this.part, required this.slot});

  @override
  Widget build(BuildContext context) {
    final trait = part.buildTrait();
    final color = _color(part.partClass);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF111A28),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        // Card art thumbnail
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.asset(
            part.cardArtPath,
            width: 48, height: 48,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              width: 48, height: 48,
              color: color.withValues(alpha: 0.15),
              child: Center(child: Text(_slotEmoji(slot),
                  style: const TextStyle(fontSize: 24))),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                // Slot label
                Text(slot.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white38, fontSize: 9,
                    fontWeight: FontWeight.w700, letterSpacing: 1)),
                const SizedBox(width: 8),
                // Class badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: color.withValues(alpha: 0.5)),
                  ),
                  child: Text(part.partClass.displayName,
                    style: TextStyle(color: color, fontSize: 8,
                        fontWeight: FontWeight.w700)),
                ),
              ]),
              const SizedBox(height: 3),
              Text(trait.name,
                style: GoogleFonts.rajdhani(
                  color: Colors.white, fontSize: 13,
                  fontWeight: FontWeight.w800)),
              Text(trait.description,
                style: const TextStyle(color: Colors.white54, fontSize: 10),
                maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        // Energy cost
        Container(
          width: 24, height: 24,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFFFF9800),
          ),
          child: Center(
            child: Text('${trait.energyCost}',
              style: const TextStyle(
                color: Colors.white, fontSize: 10,
                fontWeight: FontWeight.w900)),
          ),
        ),
      ]),
    );
  }

  static Color _color(CreatureClass cls) => switch (cls) {
    CreatureClass.plant   => const Color(0xFF4CAF50),
    CreatureClass.aquatic => const Color(0xFF29B6F6),
    CreatureClass.beast   => const Color(0xFFFF9800),
    CreatureClass.reptile => const Color(0xFF66BB6A),
    CreatureClass.bird    => const Color(0xFFFF80AB),
    CreatureClass.bug     => const Color(0xFFFF5252),
  };

  static String _slotEmoji(String slot) => switch (slot) {
    'horn'  => '🦄',
    'back'  => '🪶',
    'tail'  => '🐉',
    'mouth' => '👄',
    _       => '✦',
  };
}

// ── Small widgets ─────────────────────────────────────────────────────────────

class _StatBox extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatBox(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(children: [
        Text(value,
          style: TextStyle(color: color, fontSize: 16,
              fontWeight: FontWeight.w900)),
        Text(label,
          style: const TextStyle(color: Colors.white38, fontSize: 8)),
      ]),
    ),
  );
}

class _ClassBadge extends StatelessWidget {
  final CreatureClass cls;
  final Color color;
  const _ClassBadge({required this.cls, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(5),
      border: Border.all(color: color.withValues(alpha: 0.5)),
    ),
    child: Text(cls.displayName,
      style: TextStyle(color: color, fontSize: 11,
          fontWeight: FontWeight.w700)),
  );
}

class _PurityBadge extends StatelessWidget {
  final int purity;
  const _PurityBadge({required this.purity});

  @override
  Widget build(BuildContext context) {
    final stars = List.generate(4, (i) => i < purity ? '★' : '☆').join();
    return Text(stars,
      style: TextStyle(
        color: purity == 4 ? Colors.amber : Colors.white38,
        fontSize: 12, letterSpacing: 2));
  }
}
