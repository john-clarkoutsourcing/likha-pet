import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:likha_pet_battle_engine/trait.dart';

import '../../../core/theme/app_colors.dart';
import '../../battle/data/creature_registry.dart';
import '../../battle/widgets/pet_renderer_widget.dart';
import '../../pets/models/owned_pet.dart';
import '../../pets/providers/player_provider.dart';

// ── Rarity colour ─────────────────────────────────────────────────────────────

Color _rarityColor(String r) => switch (r.toLowerCase()) {
  'common'     => const Color(0xFFAAAAAA),
  'uncommon'   => const Color(0xFF44CC66),
  'rare'       => const Color(0xFF4488FF),
  'epic'       => const Color(0xFFCC44FF),
  'legendary'  => const Color(0xFFFFCC00),
  _            => Colors.white38,
};

// ── Class accent colours ──────────────────────────────────────────────────────

const _kAccents = <String, Color>{
  'bug':     Color(0xFFE85AA8),
  'beast':   Color(0xFFF0A040),
  'reptile': Color(0xFF4ADC7A),
  'aquatic': Color(0xFF4AC4D9),
  'plant':   Color(0xFFA8D94A),
  'bird':    Color(0xFFF586A0),
};

Color _clsAccent(String cls) =>
    _kAccents[cls.toLowerCase()] ?? const Color(0xFF4AC4D9);

const _kPartLabels = {
  'horn':  'HORN',
  'back':  'BACK',
  'tail':  'TAIL',
  'mouth': 'MOUTH',
};

const _kPartIcons = {
  'horn':  Icons.arrow_upward_rounded,
  'back':  Icons.shield_rounded,
  'tail':  Icons.rotate_right_rounded,
  'mouth': Icons.record_voice_over_rounded,
};

// ── Screen ────────────────────────────────────────────────────────────────────

class PetDetailScreen extends ConsumerWidget {
  final String petId;
  const PetDetailScreen({super.key, required this.petId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);
    final pet = player.roster.where((p) => p.uid == petId).firstOrNull;

    if (pet == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF050810),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0A1224),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white54),
            onPressed: () => context.pop(),
          ),
          title: const Text('Pet Not Found',
              style: TextStyle(color: Colors.white54)),
        ),
        body: const Center(
          child: Text('Pet not found in your roster.',
              style: TextStyle(color: Colors.white38)),
        ),
      );
    }

    final def   = pet.toCreatureDefinition();
    final stats = def.computedStats;
    final accent = _clsAccent(pet.classLabel);

    return Scaffold(
      backgroundColor: const Color(0xFF050810),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.8),
            radius: 1.2,
            colors: [accent.withValues(alpha: 0.08), const Color(0x00050810)],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              // ── Top bar ────────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                  child: Row(children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios,
                          color: Colors.white54, size: 18),
                      onPressed: () => context.pop(),
                    ),
                    Expanded(
                      child: Text(
                        pet.name,
                        style: GoogleFonts.rajdhani(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _ClassBadge(label: pet.classLabel, accent: accent),
                    const SizedBox(width: 8),
                    _PurityBadge(purity: pet.purity),
                  ]),
                ),
              ),

              // ── Hero ───────────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: _HeroSection(pet: pet, def: def, stats: stats, accent: accent),
              ),

              // ── Stats row ──────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: _StatsRow(stats: stats, accent: accent),
                ),
              ),

              // ── Cards section label ────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Text(
                    'BATTLE CARDS',
                    style: GoogleFonts.rajdhani(
                      color: Colors.white38,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),

              // ── Card list ─────────────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _PartCard(part: def.horn,  bodyAccent: accent, cardRarity: pet.hornRarity),
                    const SizedBox(height: 10),
                    _PartCard(part: def.back,  bodyAccent: accent, cardRarity: pet.backRarity),
                    const SizedBox(height: 10),
                    _PartCard(part: def.tail,  bodyAccent: accent, cardRarity: pet.tailRarity),
                    const SizedBox(height: 10),
                    _PartCard(part: def.mouth, bodyAccent: accent, cardRarity: pet.mouthRarity),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Hero section: sprite + name ───────────────────────────────────────────────

class _HeroSection extends StatelessWidget {
  final OwnedPet pet;
  final CreatureDefinition def;
  final ({int hp, int speed, int skill, int morale}) stats;
  final Color accent;

  const _HeroSection({
    required this.pet,
    required this.def,
    required this.stats,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      height: 200,
      decoration: BoxDecoration(
        color: const Color(0xFF0A1224),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.12),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(children: [
        // Sprite
        Expanded(
          flex: 5,
          child: ClipRRect(
            borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(16)),
            child: PetRendererWidget.fromOwned(pet, size: 200),
          ),
        ),
        // Info
        Expanded(
          flex: 6,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  pet.classLabel.toUpperCase(),
                  style: TextStyle(
                    color: accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  pet.name,
                  style: GoogleFonts.rajdhani(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                _StatChip(icon: Icons.favorite, label: '${stats.hp} HP',
                    color: const Color(0xFFFF4466)),
                const SizedBox(height: 5),
                _StatChip(icon: Icons.bolt, label: '${stats.speed} SPD',
                    color: const Color(0xFFFFCC44)),
                const SizedBox(height: 5),
                Row(children: [
                  _StatChip(
                    icon: Icons.emoji_events,
                    label: '${stats.morale}',
                    color: const Color(0xFFFF8844),
                    compact: true,
                  ),
                  const SizedBox(width: 8),
                  _StatChip(
                    icon: Icons.auto_awesome,
                    label: '${stats.skill}',
                    color: const Color(0xFF88CCFF),
                    compact: true,
                  ),
                ]),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Stats bar row ─────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final ({int hp, int speed, int skill, int morale}) stats;
  final Color accent;
  const _StatsRow({required this.stats, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      _StatBox(label: 'HP',     value: stats.hp,     color: const Color(0xFFFF4466)),
      const SizedBox(width: 8),
      _StatBox(label: 'SPEED',  value: stats.speed,  color: const Color(0xFFFFCC44)),
      const SizedBox(width: 8),
      _StatBox(label: 'MORALE', value: stats.morale, color: const Color(0xFFFF8844)),
      const SizedBox(width: 8),
      _StatBox(label: 'SKILL',  value: stats.skill,  color: const Color(0xFF88CCFF)),
    ]);
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final int    value;
  final Color  color;
  const _StatBox({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(children: [
        Text('$value',
            style: TextStyle(
                color: color, fontSize: 18, fontWeight: FontWeight.w900)),
        Text(label,
            style: const TextStyle(
                color: Colors.white38, fontSize: 9, fontWeight: FontWeight.w700,
                letterSpacing: 1)),
      ]),
    ),
  );
}

// ── Part / card tile ──────────────────────────────────────────────────────────

class _PartCard extends StatelessWidget {
  final PartDefinition part;
  final Color bodyAccent;
  final String cardRarity;
  const _PartCard({required this.part, required this.bodyAccent, required this.cardRarity});

  @override
  Widget build(BuildContext context) {
    final trait      = part.buildTrait();
    final partAccent = _clsAccent(part.className);
    final slotLabel  = _kPartLabels[part.partType] ?? part.partType.toUpperCase();
    final slotIcon   = _kPartIcons[part.partType] ?? Icons.extension;
    final isPure     = part.partClass.name == bodyAccent.toString(); // visual only

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0A1224),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: partAccent.withValues(alpha: 0.30)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Card art
        ClipRRect(
          borderRadius:
              const BorderRadius.horizontal(left: Radius.circular(13)),
          child: SizedBox(
            width: 80,
            height: 100,
            child: part.cardArtPath.isNotEmpty
                ? Image.asset(
                    part.cardArtPath,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        _CardArtFallback(accent: partAccent, icon: slotIcon),
                  )
                : _CardArtFallback(accent: partAccent, icon: slotIcon),
          ),
        ),

        // Info
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Slot badge + class badge + rarity badge
                Row(children: [
                  _Badge(
                    label: slotLabel,
                    color: Colors.white24,
                    icon: slotIcon,
                  ),
                  const SizedBox(width: 6),
                  _Badge(
                    label: part.className.toUpperCase(),
                    color: partAccent,
                  ),
                  const SizedBox(width: 6),
                  _Badge(
                    label: cardRarity.toUpperCase(),
                    color: _rarityColor(cardRarity),
                  ),
                  const Spacer(),
                  // Energy cost
                  _EnergyPip(cost: trait.energyCost),
                ]),
                const SizedBox(height: 6),
                // Card name
                Text(
                  trait.name,
                  style: GoogleFonts.rajdhani(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                // Card description
                Text(
                  trait.description.isNotEmpty
                      ? trait.description
                      : _effectSummary(trait),
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    height: 1.4,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                // ATK / DEF chips
                const SizedBox(height: 8),
                _CardStatRow(trait: trait),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  String _effectSummary(Trait t) {
    final e = t.effect;
    return switch (e.type) {
      EffectType.damage    => 'Deal ${e.value} damage.',
      EffectType.heal      => 'Restore ${e.value} HP.',
      EffectType.shield    => 'Grant ${e.value} shield.',
      EffectType.shieldBreak => 'Break enemy shield.',
      EffectType.buff      => 'Apply ${e.buffType?.name ?? "buff"}.',
      EffectType.debuff    => 'Apply ${e.debuffType?.name ?? "debuff"}.',
    };
  }
}

class _CardArtFallback extends StatelessWidget {
  final Color accent;
  final IconData icon;
  const _CardArtFallback({required this.accent, required this.icon});

  @override
  Widget build(BuildContext context) => Container(
    color: accent.withValues(alpha: 0.08),
    child: Center(
      child: Icon(icon, color: accent.withValues(alpha: 0.5), size: 28),
    ),
  );
}

class _CardStatRow extends StatelessWidget {
  final Trait trait;
  const _CardStatRow({required this.trait});

  @override
  Widget build(BuildContext context) {
    final e = trait.effect;
    final atk = e.type == EffectType.damage
        ? e.value
        : 0;
    final def = e.selfShield > 0 ? e.selfShield : 0;

    return Row(children: [
      if (atk > 0) ...[
        _MiniStat(label: 'ATK', value: atk, color: const Color(0xFFFF6644)),
        const SizedBox(width: 8),
      ],
      if (def > 0) ...[
        _MiniStat(label: 'DEF', value: def, color: const Color(0xFF44BBFF)),
        const SizedBox(width: 8),
      ],
      if (e.type == EffectType.heal)
        _MiniStat(label: 'HEAL', value: e.value, color: const Color(0xFF44FF88)),
      if (e.type == EffectType.shield)
        _MiniStat(label: 'SHIELD', value: e.value, color: const Color(0xFFFFCC44)),
    ]);
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final int    value;
  final Color  color;
  const _MiniStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: color.withValues(alpha: 0.35)),
    ),
    child: Text(
      '$label $value',
      style: TextStyle(
          color: color, fontSize: 9, fontWeight: FontWeight.w800),
    ),
  );
}

// ── Small helpers ─────────────────────────────────────────────────────────────

class _ClassBadge extends StatelessWidget {
  final String label;
  final Color  accent;
  const _ClassBadge({required this.label, required this.accent});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: accent.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: accent.withValues(alpha: 0.5)),
    ),
    child: Text(
      label.toUpperCase(),
      style: TextStyle(
          color: accent, fontSize: 10, fontWeight: FontWeight.w800,
          letterSpacing: 1),
    ),
  );
}

class _PurityBadge extends StatelessWidget {
  final int purity;
  const _PurityBadge({required this.purity});

  @override
  Widget build(BuildContext context) {
    final color = purity == 4
        ? const Color(0xFFFFD700)
        : purity >= 2
            ? const Color(0xFF88CCFF)
            : Colors.white38;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        '$purity/4',
        style: TextStyle(
            color: color, fontSize: 10, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String   label;
  final Color    color;
  final IconData? icon;
  const _Badge({required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      if (icon != null) ...[
        Icon(icon, color: color.withValues(alpha: 0.8), size: 9),
        const SizedBox(width: 3),
      ],
      Text(label,
          style: TextStyle(
              color: color.withValues(alpha: 0.9),
              fontSize: 8,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5)),
    ]),
  );
}

class _EnergyPip extends StatelessWidget {
  final int cost;
  const _EnergyPip({required this.cost});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: const Color(0xFFFFCC44).withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(
          color: const Color(0xFFFFCC44).withValues(alpha: 0.5)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.bolt, color: Color(0xFFFFCC44), size: 10),
      Text('$cost',
          style: const TextStyle(
              color: Color(0xFFFFCC44),
              fontSize: 10,
              fontWeight: FontWeight.w900)),
    ]),
  );
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Color    color;
  final bool     compact;
  const _StatChip({
    required this.icon,
    required this.label,
    required this.color,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, color: color, size: compact ? 10 : 12),
      const SizedBox(width: 4),
      Text(label,
          style: TextStyle(
              color: Colors.white70,
              fontSize: compact ? 10 : 12,
              fontWeight: FontWeight.w700)),
    ],
  );
}
