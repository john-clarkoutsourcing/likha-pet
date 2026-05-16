import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:likha_pet_battle_engine/trait.dart';
import '../../../core/theme/app_colors.dart';
import '../../battle/data/creature_registry.dart';
import '../../battle/data/trait_card_catalog.dart';
import '../../battle/widgets/classic_trait_card_widget.dart';

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

/// A catalog entry built from local Classic card metadata.
class _CardEntry {
  final String imageName;
  final String templatePath;
  final String cls;
  final String name;

  final int energy;
  final int attack;
  final int defense;
  final int healing;
  final String abilityType;
  final String partType;
  final String description;

  final Trait trait;

  const _CardEntry({
    required this.imageName,
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
    required this.trait,
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
            imageName: e.imageName,
            templatePath: e.templatePath,
            cls: e.cardClass,
            name: e.trait.name,
            energy: e.energy,
            attack: e.attack,
            defense: e.defense,
            healing: e.healing,
            abilityType: e.abilityType,
            partType: e.partType,
            description: e.description,
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
    return GestureDetector(
      onTap: () => _showDetail(context),
      child: ClassicTraitCardWidget(
        imagePath: entry.templatePath,
        imageName: entry.imageName,
        name: entry.name,
        energy: entry.energy,
        attack: entry.attack,
        defense: entry.defense,
        description: entry.description,
        showDescription: true,
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
    final maxDialogHeight = MediaQuery.sizeOf(context).height * 0.9;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 360, maxHeight: maxDialogHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: ClassicTraitCardWidget(
                imagePath: entry.templatePath,
                imageName: entry.imageName,
                name: entry.name,
                energy: entry.energy,
                attack: entry.attack,
                defense: entry.defense,
                description: entry.description,
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                backgroundColor: Colors.black.withValues(alpha: 0.35),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text(
                'Close',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
          ],
        ),
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
