import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:likha_pet_battle_engine/trait.dart';
import '../../../core/theme/app_colors.dart';
import '../../battle/data/creature_registry.dart';
import '../../battle/data/trait_card_catalog.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

Color _clsColor(String cls) => switch (cls) {
      'plant' => const Color(0xFF4CAF50),
      'aquatic' => const Color(0xFF29B6F6),
      'beast' => const Color(0xFFFF9800),
      'reptile' => const Color(0xFF66BB6A),
      'bird' => const Color(0xFFFF80AB),
      'bug' => const Color(0xFFFF5252),
      'curse' => const Color(0xFF9C27B0),
      'others' => const Color(0xFF9E9E9E),
      'tool' => const Color(0xFF795548),
      _ => const Color(0xFF9C27B0),
    };

String _titleCase(String s) => s
    .split(' ')
    .map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1))
    .join(' ');

/// A catalog entry built from a card-template PNG file + Origins card data.
class _CardEntry {
  final String templatePath;
  final String cls;
  final String name;

  // Origins card stats (always available for all 205 cards)
  final int energy;
  final int attack;
  final int defense;
  final int healing;
  final String abilityType;
  final String partType;
  final String description;

  // Engine trait — only present for ~24 battle-mapped cards
  final Trait? trait;

  const _CardEntry({
    required this.templatePath,
    required this.cls,
    required this.name,
    required this.energy,
    required this.attack,
    required this.defense,
    required this.healing,
    required this.abilityType,
    required this.partType,
    required this.description,
    this.trait,
  });
}

// ── Screen ────────────────────────────────────────────────────────────────────

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  String _filterClass = 'all';
  List<_CardEntry> _cards = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() => setState(() {}));
    _loadCards();
  }

  void _loadCards() {
    final entries = TraitCardCatalog.build()
        .map(
          (e) => _CardEntry(
            templatePath: e.templatePath,
            cls: e.cardClass,
            name: _titleCase(e.imageName),
            energy: e.card.energy,
            attack: e.card.attack,
            defense: e.card.defense,
            healing: e.card.healing,
            abilityType: e.card.abilityType,
            partType: e.card.partType,
            description: e.card.description,
            trait: e.trait,
          ),
        )
        .toList(growable: false);
    if (mounted) {
      setState(() {
        _cards = entries;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  List<_CardEntry> get _filteredCards {
    if (_filterClass == 'all') return _cards;
    return _cards.where((c) => c.cls == _filterClass).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Left panel: header + tabs + filters ───────────────────────
            SizedBox(
              width: 168,
              child: Container(
                decoration: const BoxDecoration(
                  border: Border(right: BorderSide(color: Color(0xFF1A1F35))),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                      child: Row(children: [
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.arrow_back,
                              color: Colors.white54, size: 18),
                          onPressed: () => context.pop(),
                        ),
                        const SizedBox(width: 4),
                        Text('Library',
                            style: GoogleFonts.rajdhani(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800)),
                      ]),
                    ),
                    const SizedBox(height: 6),

                    // Tabs
                    TabBar(
                      controller: _tabs,
                      indicatorColor: AppColors.primary,
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.white38,
                      labelStyle: GoogleFonts.rajdhani(
                          fontSize: 11, fontWeight: FontWeight.w800),
                      tabs: const [
                        Tab(text: 'SKILLS'),
                        Tab(text: 'CLASSES'),
                      ],
                    ),

                    const Divider(height: 1, color: Color(0xFF1A1F35)),
                    const SizedBox(height: 8),

                    // Class filters (only on SKILLS tab)
                    if (_tabs.index == 0) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text('CLASS',
                            style: const TextStyle(
                                color: Colors.white24,
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1)),
                      ),
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            _Chip('All', _filterClass == 'all',
                                () => setState(() => _filterClass = 'all')),
                            for (final cls in [
                              'beast',
                              'plant',
                              'aquatic',
                              'reptile',
                              'bird',
                              'bug',
                            ])
                              _Chip(
                                cls[0].toUpperCase() + cls.substring(1),
                                _filterClass == cls,
                                () => setState(() => _filterClass = cls),
                                color: _clsColor(cls),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Count
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                            _loading
                                ? 'Loading…'
                                : '${_filteredCards.length} cards',
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 10)),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // ── Right panel: grid ─────────────────────────────────────────
            Expanded(
              child: _loading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: AppColors.primary))
                  : TabBarView(
                      controller: _tabs,
                      children: [
                        _SkillsGrid(cards: _filteredCards),
                        _ClassesGrid(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Filter chip ───────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  final Color? color;
  const _Chip(this.label, this.active, this.onTap, {this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: active
              ? c.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
              color: active ? c.withValues(alpha: 0.7) : Colors.white12),
        ),
        child: Text(label,
            style: TextStyle(
                color: active ? c : Colors.white38,
                fontSize: 9,
                fontWeight: FontWeight.w700)),
      ),
    );
  }
}

// ── Skills grid ───────────────────────────────────────────────────────────────

class _SkillsGrid extends StatelessWidget {
  final List<_CardEntry> cards;
  const _SkillsGrid({required this.cards});

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) {
      return const Center(
          child: Text('No cards', style: TextStyle(color: Colors.white38)));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(10),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        childAspectRatio: 0.72,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
      ),
      itemCount: cards.length,
      itemBuilder: (_, i) => _SkillCard(entry: cards[i]),
    );
  }
}

class _SkillCard extends StatelessWidget {
  final _CardEntry entry;
  const _SkillCard({required this.entry});

  void _showDetail(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => _SkillDetailDialog(entry: entry),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = _clsColor(entry.cls);

    return GestureDetector(
      onTap: () => _showDetail(context),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.asset(
          entry.templatePath,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: color.withValues(alpha: 0.1),
            child: Center(
              child: Text(entry.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white54, fontSize: 8)),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Skill detail dialog ───────────────────────────────────────────────────────

class _SkillDetailDialog extends StatelessWidget {
  final _CardEntry entry;
  const _SkillDetailDialog({required this.entry});

  @override
  Widget build(BuildContext context) {
    final color = _clsColor(entry.cls);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Large card image ────────────────────────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 200,
              child: Image.asset(
                entry.templatePath,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Container(
                  width: 200,
                  height: 272,
                  color: color.withValues(alpha: 0.15),
                  child: Center(
                    child: Text(entry.name,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 14)),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 16),

          // ── Info panel ──────────────────────────────────────────────────
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF111827),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color.withValues(alpha: 0.4)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Class badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: color.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      entry.cls[0].toUpperCase() + entry.cls.substring(1),
                      style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Card name
                  Text(entry.name,
                      style: GoogleFonts.rajdhani(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900)),

                  const SizedBox(height: 6),
                  // Energy cost
                  Row(children: [
                    const Text('Energy  ',
                        style: TextStyle(color: Colors.white38, fontSize: 11)),
                    if (entry.energy == 0)
                      const Text('Free',
                          style: TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                              fontStyle: FontStyle.italic))
                    else
                      ...List.generate(
                        entry.energy,
                        (_) => Container(
                          width: 10,
                          height: 10,
                          margin: const EdgeInsets.only(right: 3),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF4FC3F7),
                          ),
                        ),
                      ),
                  ]),
                  const SizedBox(height: 6),
                  // Ability type + part
                  Text(
                    '${entry.abilityType.toUpperCase()}  ·  ${entry.partType.toUpperCase()}',
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 10,
                      letterSpacing: 0.5,
                    ),
                  ),

                  // Stats row (attack / defense / healing)
                  if (entry.attack > 0 || entry.defense > 0 || entry.healing > 0) ...[
                    const SizedBox(height: 8),
                    Wrap(spacing: 10, children: [
                      if (entry.attack > 0)
                        _StatChip(label: 'ATK', value: entry.attack, color: Colors.redAccent),
                      if (entry.defense > 0)
                        _StatChip(label: 'DEF', value: entry.defense, color: Colors.blueAccent),
                      if (entry.healing > 0)
                        _StatChip(label: 'HEAL', value: entry.healing, color: Colors.greenAccent),
                    ]),
                  ],

                  const SizedBox(height: 8),
                  // Description
                  Text(
                    entry.description.isEmpty
                        ? 'No description available.'
                        : entry.description,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 14),
                  // Close
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.06),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Close',
                          style:
                              TextStyle(color: Colors.white54, fontSize: 12)),
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

// ── Classes grid ──────────────────────────────────────────────────────────────

class _ClassesGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final bodies = kBodyCatalogue.values.toList();
    return GridView.builder(
      padding: const EdgeInsets.all(10),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.05,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: bodies.length,
      itemBuilder: (_, i) => _ClassCard(body: bodies[i]),
    );
  }
}

class _ClassCard extends StatelessWidget {
  final BodyDefinition body;
  const _ClassCard({required this.body});

  @override
  Widget build(BuildContext context) {
    final cls = body.className;
    final color = _clsColor(cls);
    final base = body.bodyClass.baseBodyStats;
    final bonus = body.bodyClass.partStatBonus;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111A28),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(children: [
        // Icon + gradient header
        Expanded(
          flex: 3,
          child: Stack(fit: StackFit.expand, children: [
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(13)),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withValues(alpha: 0.3),
                    color.withValues(alpha: 0.08),
                  ],
                ),
              ),
            ),
            Center(
              child: Image.asset(
                'assets/images/icons/$cls.png',
                width: 52,
                height: 52,
                errorBuilder: (_, __, ___) => Icon(Icons.pets,
                    size: 40, color: color.withValues(alpha: 0.5)),
              ),
            ),
            Positioned(
              top: 6,
              left: 8,
              child: Text(body.bodyClass.displayName,
                  style: TextStyle(
                      color: color, fontSize: 11, fontWeight: FontWeight.w900)),
            ),
          ]),
        ),

        // Stats
        Expanded(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 2, 8, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Row('❤', '${base.hp}', const Color(0xFF66FF88)),
                _Row('⚡', '${base.speed}', const Color(0xFFFFCC44)),
                _Row('🏅', '${base.skill}', const Color(0xFF88CCFF)),
                _Row('🔥', '${base.morale}', const Color(0xFFFF9944)),
                Text('+${bonus.hp}HP/part',
                    style: const TextStyle(color: Colors.white24, fontSize: 7)),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}

class _Row extends StatelessWidget {
  final String icon, value;
  final Color color;
  const _Row(this.icon, this.value, this.color);

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 8)),
          const SizedBox(width: 3),
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 9, fontWeight: FontWeight.w700)),
        ],
      );
}

class _StatChip extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _StatChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text('$label $value',
            style: TextStyle(
                color: color, fontSize: 10, fontWeight: FontWeight.w700)),
      );
}
