import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:likha_pet_battle_engine/trait.dart';
import '../../../core/theme/app_colors.dart';
import '../../battle/data/creature_registry.dart';
import '../../battle/data/trait_card_catalog.dart';
import '../../battle/widgets/classic_trait_card_widget.dart';

// ── Palette ───────────────────────────────────────────────────────────────────

const _kAccents = <String, Color>{
  'beast':   Color(0xFFF0A040),
  'plant':   Color(0xFFA8D94A),
  'aquatic': Color(0xFF4AC4D9),
  'reptile': Color(0xFF4ADC7A),
  'bird':    Color(0xFFF586A0),
  'bug':     Color(0xFFE85AA8),
};

Color _cls(String c) => _kAccents[c] ?? const Color(0xFF4AC4D9);

const _kParts = ['All', 'Horn', 'Back', 'Tail', 'Mouth'];
const _kClasses = ['All', 'Beast', 'Plant', 'Aquatic', 'Reptile', 'Bird', 'Bug'];

// ── Entry wrapper ─────────────────────────────────────────────────────────────

class _E {
  final TraitCardCatalogEntry d;
  const _E(this.d);
  String get cls   => d.cardClass;
  String get part  => d.partType; // Horn|Back|Tail|Mouth
  String get name  => d.trait.name;
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
  String _cls  = 'All';
  String _part = 'All';
  String _q    = '';
  List<_E> _all = [];
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this)
      ..addListener(() => setState(() {}));
    _all = TraitCardCatalog.build().map((e) => _E(e)).toList();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  List<_E> get _filtered {
    return _all.where((e) {
      final matchCls  = _cls  == 'All' || e.cls  == _cls.toLowerCase();
      final matchPart = _part == 'All' || e.part == _part;
      final matchQ    = _q.isEmpty ||
          e.name.toLowerCase().contains(_q.toLowerCase());
      return matchCls && matchPart && matchQ;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050810),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.8, -0.7),
            radius: 1.1,
            colors: [Color(0x0C4AC4D9), Color(0x00050810)],
          ),
        ),
        child: SafeArea(
          child: Column(children: [
            _TopBar(onBack: () => context.pop()),
            _TabRow(controller: _tabs),
            if (_tabs.index == 0) ...[
              _SearchBar(ctrl: _searchCtrl, onChanged: (v) => setState(() => _q = v)),
              _FilterRow(
                items: _kClasses,
                selected: _cls,
                accent: _cls == 'All' ? AppColors.primary : _cls2color(_cls),
                onSelect: (v) => setState(() => _cls = v),
              ),
              _FilterRow(
                items: _kParts,
                selected: _part,
                accent: AppColors.primary,
                onSelect: (v) => setState(() => _part = v),
                small: true,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${_filtered.length} cards',
                    style: GoogleFonts.rajdhani(
                      color: Colors.white24,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ],
            Expanded(
              child: TabBarView(
                controller: _tabs,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _CardsGrid(entries: _filtered),
                  const _ClassesView(),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }

  static Color _cls2color(String cls) =>
      _kAccents[cls.toLowerCase()] ?? AppColors.primary;
}

// ── Top bar ───────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final VoidCallback onBack;
  const _TopBar({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 16, 4),
      child: Row(children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF7FE3F5), size: 18),
          onPressed: onBack,
        ),
        Text('LIBRARY',
            style: const TextStyle(
              fontFamily: 'LilitaOne',
              color: Color(0xFFEAFBFF),
              fontSize: 22,
              letterSpacing: 2,
              shadows: [Shadow(color: Color(0xFF4AC4D9), blurRadius: 12)],
            )),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF4AC4D9).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
                color: const Color(0xFF4AC4D9).withValues(alpha: 0.35)),
          ),
          child: const Text('TRAITS & CLASSES',
              style: TextStyle(
                  fontFamily: 'Fredoka',
                  color: Color(0xFF4AC4D9),
                  fontSize: 10)),
        ),
      ]),
    );
  }
}

// ── Tab row ───────────────────────────────────────────────────────────────────

class _TabRow extends StatelessWidget {
  final TabController controller;
  const _TabRow({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1224),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E3A5F)),
      ),
      child: TabBar(
        controller: controller,
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: const LinearGradient(
              colors: [Color(0xFF4AC4D9), Color(0xFF2B8A9C)]),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFF4AC4D9).withValues(alpha: 0.35),
                blurRadius: 8),
          ],
        ),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white38,
        labelStyle: GoogleFonts.rajdhani(
            fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.5),
        unselectedLabelStyle: GoogleFonts.rajdhani(
            fontSize: 13, fontWeight: FontWeight.w700),
        tabs: const [
          Tab(text: 'SKILLS'),
          Tab(text: 'CLASSES'),
        ],
      ),
    );
  }
}

// ── Search bar ────────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final TextEditingController ctrl;
  final ValueChanged<String> onChanged;
  const _SearchBar({required this.ctrl, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: TextField(
        controller: ctrl,
        onChanged: onChanged,
        style: const TextStyle(
            fontFamily: 'Fredoka', color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Search cards...',
          hintStyle: const TextStyle(
              fontFamily: 'Fredoka', color: Colors.white24, fontSize: 13),
          prefixIcon: const Icon(Icons.search_rounded,
              color: Color(0xFF4AC4D9), size: 18),
          suffixIcon: ctrl.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: Colors.white38, size: 16),
                  onPressed: () {
                    ctrl.clear();
                    onChanged('');
                  },
                )
              : null,
          filled: true,
          fillColor: const Color(0xFF0A1224),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF1E3A5F)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF1E3A5F)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                const BorderSide(color: Color(0xFF4AC4D9), width: 1.5),
          ),
        ),
      ),
    );
  }
}

// ── Filter chip row ───────────────────────────────────────────────────────────

class _FilterRow extends StatelessWidget {
  final List<String> items;
  final String selected;
  final Color accent;
  final ValueChanged<String> onSelect;
  final bool small;

  const _FilterRow({
    required this.items,
    required this.selected,
    required this.accent,
    required this.onSelect,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: small ? 28 : 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemCount: items.length,
        itemBuilder: (_, i) {
          final item   = items[i];
          final active = item == selected;
          final color  = item == 'All'
              ? AppColors.primary
              : (_kAccents[item.toLowerCase()] ?? accent);

          return GestureDetector(
            onTap: () => onSelect(item),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: EdgeInsets.symmetric(
                  horizontal: small ? 10 : 12,
                  vertical: small ? 4 : 6),
              decoration: BoxDecoration(
                color: active
                    ? color.withValues(alpha: 0.2)
                    : const Color(0xFF0A1224),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: active
                      ? color.withValues(alpha: 0.7)
                      : const Color(0xFF1E3A5F),
                  width: active ? 1.5 : 1,
                ),
                boxShadow: active
                    ? [BoxShadow(
                        color: color.withValues(alpha: 0.25),
                        blurRadius: 8)]
                    : null,
              ),
              child: Text(
                item,
                style: TextStyle(
                  fontFamily: 'LilitaOne',
                  color: active ? color : Colors.white38,
                  fontSize: small ? 9 : 11,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Cards grid ────────────────────────────────────────────────────────────────

class _CardsGrid extends StatelessWidget {
  final List<_E> entries;
  const _CardsGrid({required this.entries});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.search_off_rounded,
              size: 48, color: Color(0xFF4AC4D9)),
          const SizedBox(height: 8),
          const Text('No cards found',
              style: TextStyle(
                  fontFamily: 'Fredoka',
                  color: Colors.white38,
                  fontSize: 14)),
        ]),
      );
    }

    return LayoutBuilder(builder: (_, c) {
      final cols = c.maxWidth < 500
          ? 3
          : c.maxWidth < 800
              ? 4
              : c.maxWidth < 1100
                  ? 5
                  : 6;
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          childAspectRatio: 0.70,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: entries.length,
        itemBuilder: (_, i) => _CardTile(e: entries[i]),
      );
    });
  }
}

class _CardTile extends StatelessWidget {
  final _E e;
  const _CardTile({required this.e});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        splashColor: _cls(e.cls).withValues(alpha: 0.2),
        onTap: () => _showDetail(context),
        child: Stack(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: ClassicTraitCardWidget(
              imagePath: e.d.templatePath,
              imageName: e.d.imageName,
              name: e.d.trait.name,
              energy: e.d.energy,
              attack: e.d.attack,
              defense: e.d.defense,
              description: e.d.description,
              showDescription: true,
            ),
          ),
          // Class accent border
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: _cls(e.cls).withValues(alpha: 0.4), width: 1),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => _CardDetail(e: e),
    );
  }
}

// ── Card detail dialog ────────────────────────────────────────────────────────

class _CardDetail extends StatelessWidget {
  final _E e;
  const _CardDetail({required this.e});

  @override
  Widget build(BuildContext context) {
    final accent = _cls(e.cls);
    final trait  = e.d.trait;
    final effect = trait.effect;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Material(
        color: Colors.transparent,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 400,
            maxHeight: MediaQuery.sizeOf(context).height * 0.88,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0A1224),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: accent.withValues(alpha: 0.5), width: 1.5),
              boxShadow: [
                BoxShadow(
                    color: accent.withValues(alpha: 0.2),
                    blurRadius: 30,
                    spreadRadius: 2),
              ],
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Card art
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(19)),
                child: SizedBox(
                  height: 200,
                  child: ClassicTraitCardWidget(
                    imagePath: e.d.templatePath,
                    imageName: e.d.imageName,
                    name: e.d.trait.name,
                    energy: e.d.energy,
                    attack: e.d.attack,
                    defense: e.d.defense,
                    description: e.d.description,
                  ),
                ),
              ),

              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name + badges
                      Row(children: [
                        Expanded(
                          child: Text(trait.name,
                              style: const TextStyle(
                                fontFamily: 'LilitaOne',
                                color: Color(0xFFEAFBFF),
                                fontSize: 20,
                              )),
                        ),
                        _Badge(e.cls[0].toUpperCase() + e.cls.substring(1),
                            accent),
                        const SizedBox(width: 6),
                        _Badge(e.d.partType,
                            const Color(0xFF4AC4D9)),
                      ]),
                      const SizedBox(height: 10),

                      // Stats row
                      _StatsRow(e: e.d),
                      const SizedBox(height: 12),

                      // Description
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: accent.withValues(alpha: 0.2)),
                        ),
                        child: Text(
                          trait.description.isNotEmpty
                              ? trait.description
                              : 'No description.',
                          style: const TextStyle(
                              fontFamily: 'Fredoka',
                              color: Colors.white70,
                              fontSize: 13,
                              height: 1.5),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Effect type
                      Row(children: [
                        _InfoChip(
                          icon: _effectIcon(effect.type),
                          label: _effectLabel(effect),
                          color: _effectColor(effect.type),
                        ),
                        const SizedBox(width: 8),
                        _InfoChip(
                          icon: Icons.bolt,
                          label: '${e.d.energy}E',
                          color: const Color(0xFFFFCC44),
                        ),
                        if (e.d.abilityType.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          _InfoChip(
                            icon: Icons.sports_martial_arts,
                            label: e.d.abilityType
                                .replaceAll('Attack', '')
                                .replaceAll('Utility', 'Utility'),
                            color: const Color(0xFFAAE8F5),
                          ),
                        ],
                      ]),
                    ],
                  ),
                ),
              ),

              // Close button
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: double.infinity,
                    height: 40,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: accent.withValues(alpha: 0.35)),
                    ),
                    child: Center(
                      child: Text('CLOSE',
                          style: TextStyle(
                            fontFamily: 'LilitaOne',
                            color: accent,
                            fontSize: 13,
                            letterSpacing: 1,
                          )),
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  IconData _effectIcon(EffectType t) => switch (t) {
        EffectType.damage     => Icons.flash_on,
        EffectType.aoe        => Icons.radar,
        EffectType.heal       => Icons.favorite,
        EffectType.shield     => Icons.shield,
        EffectType.buff       => Icons.arrow_upward,
        EffectType.debuff     => Icons.arrow_downward,
        EffectType.shieldBreak => Icons.shield_outlined,
      };

  Color _effectColor(EffectType t) => switch (t) {
        EffectType.damage     => const Color(0xFFFF4466),
        EffectType.aoe        => const Color(0xFFFF8844),
        EffectType.heal       => const Color(0xFF44FF88),
        EffectType.shield     => const Color(0xFFFFCC44),
        EffectType.buff       => const Color(0xFF88CCFF),
        EffectType.debuff     => const Color(0xFFCE93D8),
        EffectType.shieldBreak => const Color(0xFFFF6644),
      };

  String _effectLabel(TraitEffect e) {
    if (e.value > 0) return '${e.value}';
    return e.type.name[0].toUpperCase() + e.type.name.substring(1);
  }
}

class _StatsRow extends StatelessWidget {
  final TraitCardCatalogEntry e;
  const _StatsRow({required this.e});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      if (e.attack  > 0) _StatBox('ATK', e.attack,  const Color(0xFFFF4466)),
      if (e.defense > 0) _StatBox('DEF', e.defense, const Color(0xFF44BBFF)),
      if (e.healing > 0) _StatBox('HEAL', e.healing, const Color(0xFF44FF88)),
      _StatBox('E', e.energy, const Color(0xFFFFCC44)),
    ]);
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final int    value;
  final Color  color;
  const _StatBox(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(right: 8),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color.withValues(alpha: 0.35)),
    ),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text('$value',
          style: TextStyle(
              color: color, fontSize: 15, fontWeight: FontWeight.w900,
              fontFamily: 'LilitaOne')),
      Text(label,
          style: const TextStyle(
              color: Colors.white38, fontSize: 8,
              fontWeight: FontWeight.w700, letterSpacing: 0.5)),
    ]),
  );
}

class _Badge extends StatelessWidget {
  final String label;
  final Color  color;
  const _Badge(this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color.withValues(alpha: 0.5)),
    ),
    child: Text(label,
        style: TextStyle(
            color: color,
            fontFamily: 'LilitaOne',
            fontSize: 9,
            letterSpacing: 0.5)),
  );
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Color    color;
  const _InfoChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: color, size: 11),
      const SizedBox(width: 4),
      Text(label,
          style: TextStyle(
              color: color, fontFamily: 'Fredoka', fontSize: 11)),
    ]),
  );
}

// ── Classes view ──────────────────────────────────────────────────────────────

class _ClassesView extends StatelessWidget {
  const _ClassesView();

  static const _kClassOrder = [
    'beast', 'plant', 'aquatic', 'reptile', 'bird', 'bug'
  ];

  @override
  Widget build(BuildContext context) {
    final bodies = {
      for (final b in kBodyCatalogue.values) b.className: b
    };

    return LayoutBuilder(builder: (_, c) {
      final cols = c.maxWidth < 600 ? 2 : c.maxWidth < 900 ? 3 : 4;
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          childAspectRatio: 0.9,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: _kClassOrder.length,
        itemBuilder: (_, i) {
          final name = _kClassOrder[i];
          final body = bodies[name];
          if (body == null) return const SizedBox.shrink();
          return _ClassCard(body: body);
        },
      );
    });
  }
}

class _ClassCard extends StatelessWidget {
  final BodyDefinition body;
  const _ClassCard({required this.body});

  static const _kAdvantages = <String, String>{
    'beast':   'Strong vs: Aquatic, Bird',
    'plant':   'Strong vs: Aquatic, Reptile',
    'aquatic': 'Strong vs: Beast, Bird',
    'reptile': 'Strong vs: Beast, Bug',
    'bird':    'Strong vs: Bug, Plant',
    'bug':     'Strong vs: Plant, Aquatic',
  };

  @override
  Widget build(BuildContext context) {
    final cls   = body.className;
    final color = _cls(cls);
    final base  = body.bodyClass.baseBodyStats;
    final bonus = body.bodyClass.partStatBonus;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.12),
            const Color(0xFF0A1224),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
              color: color.withValues(alpha: 0.08),
              blurRadius: 12,
              spreadRadius: 1),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Class name + icon
            Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.15),
                  border: Border.all(color: color.withValues(alpha: 0.5)),
                ),
                child: Center(
                  child: Image.asset(
                    'assets/images/icons/$cls.png',
                    width: 22, height: 22,
                    errorBuilder: (_, __, ___) => Icon(Icons.pets,
                        size: 18, color: color),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(body.bodyClass.displayName,
                        style: TextStyle(
                          fontFamily: 'LilitaOne',
                          color: color,
                          fontSize: 16,
                        )),
                    Text('Body Class',
                        style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 9,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ]),

            const SizedBox(height: 12),

            // Base stats
            _StatBar('HP',     base.hp,     const Color(0xFFFF4466), 200),
            const SizedBox(height: 4),
            _StatBar('SPD',    base.speed,  const Color(0xFFFFCC44), 50),
            const SizedBox(height: 4),
            _StatBar('SKILL',  base.skill,  const Color(0xFF88CCFF), 50),
            const SizedBox(height: 4),
            _StatBar('MORALE', base.morale, const Color(0xFFFF8844), 50),

            const SizedBox(height: 8),

            // Part bonus
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('+${bonus.hp} HP per matching part',
                  style: TextStyle(
                      color: color.withValues(alpha: 0.8),
                      fontFamily: 'Fredoka',
                      fontSize: 10)),
            ),

            const Spacer(),

            // Advantage
            Text(
              _kAdvantages[cls] ?? '',
              style: const TextStyle(
                  fontFamily: 'Fredoka',
                  color: Colors.white38,
                  fontSize: 9,
                  height: 1.3),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatBar extends StatelessWidget {
  final String label;
  final int    value;
  final Color  color;
  final int    max;
  const _StatBar(this.label, this.value, this.color, this.max);

  @override
  Widget build(BuildContext context) => Row(children: [
    SizedBox(
      width: 40,
      child: Text(label,
          style: const TextStyle(
              color: Colors.white38,
              fontSize: 8,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5)),
    ),
    Expanded(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: LinearProgressIndicator(
          value: (value / max).clamp(0.0, 1.0),
          backgroundColor: color.withValues(alpha: 0.1),
          valueColor: AlwaysStoppedAnimation(color),
          minHeight: 5,
        ),
      ),
    ),
    const SizedBox(width: 6),
    Text('$value',
        style: TextStyle(
            color: color,
            fontSize: 9,
            fontWeight: FontWeight.w800)),
  ]);
}
