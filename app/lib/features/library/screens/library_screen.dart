import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:likha_pet_battle_engine/trait.dart';
import '../../../core/theme/app_colors.dart';
import '../../battle/data/creature_registry.dart';

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

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  String _filterClass = 'all';
  String _filterSlot  = 'all';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() => setState(() {}));
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(children: [
          // ── Header ──────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white70),
                onPressed: () => context.pop(),
              ),
              Text('Catalogue',
                style: GoogleFonts.rajdhani(
                  color: Colors.white, fontSize: 22,
                  fontWeight: FontWeight.w800)),
              const Spacer(),
              Text(
                '${kBodyCatalogue.length} bodies  ·  ${kPartCatalogue.length} parts',
                style: const TextStyle(color: Colors.white38, fontSize: 11)),
            ]),
          ),

          // ── Tabs ─────────────────────────────────────────────────────────────
          TabBar(
            controller: _tabs,
            indicatorColor: AppColors.primary,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white38,
            labelStyle: GoogleFonts.rajdhani(
                fontSize: 14, fontWeight: FontWeight.w800),
            tabs: const [
              Tab(text: 'BODIES'),
              Tab(text: 'PARTS'),
            ],
          ),

          // ── Filters for Parts tab ─────────────────────────────────────────
          if (_tabs.index == 1)
            _Filters(
              filterClass: _filterClass,
              filterSlot:  _filterSlot,
              onClassChanged: (v) => setState(() => _filterClass = v),
              onSlotChanged:  (v) => setState(() => _filterSlot  = v),
            ),

          // ── Content ────────────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _BodiesTab(),
                _PartsTab(filterClass: _filterClass, filterSlot: _filterSlot),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Filters ───────────────────────────────────────────────────────────────────

class _Filters extends StatelessWidget {
  final String filterClass, filterSlot;
  final ValueChanged<String> onClassChanged, onSlotChanged;
  const _Filters({
    required this.filterClass, required this.filterSlot,
    required this.onClassChanged, required this.onSlotChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(children: [
        _FilterChip('All', filterClass == 'all', () => onClassChanged('all')),
        const SizedBox(width: 4),
        for (final cls in ['beast','plant','aquatic','reptile','bird','bug'])
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: _FilterChip(
              cls[0].toUpperCase() + cls.substring(1),
              filterClass == cls,
              () => onClassChanged(cls),
              color: _clsColor(cls),
            ),
          ),
        const Spacer(),
        _FilterChip('All', filterSlot == 'all', () => onSlotChanged('all')),
        const SizedBox(width: 4),
        for (final slot in ['horn','back','tail','mouth'])
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: _FilterChip(
              slot[0].toUpperCase(),
              filterSlot == slot,
              () => onSlotChanged(slot),
            ),
          ),
      ]),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool   active;
  final VoidCallback onTap;
  final Color? color;
  const _FilterChip(this.label, this.active, this.onTap, {this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: active ? c.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: active ? c.withValues(alpha: 0.7) : Colors.white12,
          ),
        ),
        child: Text(label,
          style: TextStyle(
            color: active ? c : Colors.white38,
            fontSize: 10, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

// ── Bodies tab ────────────────────────────────────────────────────────────────

class _BodiesTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final bodies = kBodyCatalogue.values.toList();
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.85,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: bodies.length,
      itemBuilder: (_, i) => _BodyCard(body: bodies[i]),
    );
  }
}

class _BodyCard extends StatelessWidget {
  final BodyDefinition body;
  const _BodyCard({required this.body});

  @override
  Widget build(BuildContext context) {
    final cls    = body.className;
    final color  = _clsColor(cls);
    final base   = body.bodyClass.baseBodyStats;
    final bonusPerPart = body.bodyClass.partStatBonus;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111A28),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(children: [
        // Icon area
        Expanded(
          child: Stack(children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(13)),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [
                      color.withValues(alpha: 0.25),
                      color.withValues(alpha: 0.08),
                    ],
                  ),
                ),
              ),
            ),
            Center(
              child: Image.asset(
                'assets/images/icons/$cls.png',
                width: 64, height: 64,
                errorBuilder: (_, __, ___) =>
                    Icon(Icons.pets, size: 48,
                        color: color.withValues(alpha: 0.5)),
              ),
            ),
          ]),
        ),
        // Info
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(body.name,
                  style: GoogleFonts.rajdhani(
                    color: Colors.white, fontSize: 13,
                    fontWeight: FontWeight.w800),
                  overflow: TextOverflow.ellipsis),
                const Spacer(),
                Text(body.bodyClass.displayName,
                  style: TextStyle(
                    color: color, fontSize: 9,
                    fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 5),
              // Base stats
              _StatLine('❤ HP', '${base.hp}', const Color(0xFF66FF88)),
              _StatLine('⚡ SPD', '${base.speed}', const Color(0xFFFFCC44)),
              _StatLine('🏅 SKL', '${base.skill}', const Color(0xFF88CCFF)),
              _StatLine('🔥 MOR', '${base.morale}', const Color(0xFFFF9944)),
              const SizedBox(height: 4),
              Text('Per part: +HP${bonusPerPart.hp} +SPD${bonusPerPart.speed}'
                  ' +MOR${bonusPerPart.morale}',
                style: const TextStyle(color: Colors.white24, fontSize: 8)),
            ],
          ),
        ),
      ]),
    );
  }
}

class _StatLine extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatLine(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 1),
    child: Row(children: [
      Text(label, style: const TextStyle(color: Colors.white38, fontSize: 9)),
      const Spacer(),
      Text(value,
        style: TextStyle(color: color, fontSize: 9,
            fontWeight: FontWeight.w700)),
    ]),
  );
}

// ── Parts tab ─────────────────────────────────────────────────────────────────

class _PartsTab extends StatelessWidget {
  final String filterClass, filterSlot;
  const _PartsTab({required this.filterClass, required this.filterSlot});

  @override
  Widget build(BuildContext context) {
    var parts = kPartCatalogue.values.toList();
    if (filterClass != 'all') {
      parts = parts.where((p) => p.className == filterClass).toList();
    }
    if (filterSlot != 'all') {
      parts = parts.where((p) => p.partType == filterSlot).toList();
    }
    // Sort: by class, then slot
    parts.sort((a, b) {
      final cls = a.className.compareTo(b.className);
      if (cls != 0) return cls;
      return a.partType.compareTo(b.partType);
    });

    if (parts.isEmpty) {
      return Center(
        child: Text('No parts match this filter',
          style: const TextStyle(color: Colors.white38)));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.62,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: parts.length,
      itemBuilder: (_, i) => _PartCard(part: parts[i]),
    );
  }
}

class _PartCard extends StatelessWidget {
  final PartDefinition part;
  const _PartCard({required this.part});

  @override
  Widget build(BuildContext context) {
    final color = _clsColor(part.className);
    final trait = part.buildTrait();

    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(fit: StackFit.expand, children: [
        // Card art
        Image.asset(part.cardArtPath, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: color.withValues(alpha: 0.1))),

        // Top gradient
        Positioned(
          top: 0, left: 0, right: 0, height: 40,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Colors.black87, Colors.transparent]),
            ),
          ),
        ),

        // Bottom gradient
        Positioned(
          bottom: 0, left: 0, right: 0, height: 70,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter, end: Alignment.topCenter,
                colors: [Colors.black, Colors.transparent]),
            ),
          ),
        ),

        // Class + slot badge
        Positioned(
          top: 5, left: 5,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: color.withValues(alpha: 0.6)),
            ),
            child: Text(
              '${part.className[0].toUpperCase()}  ${part.partType.toUpperCase()}',
              style: TextStyle(color: color, fontSize: 7,
                  fontWeight: FontWeight.w900, letterSpacing: 0.5)),
          ),
        ),

        // Energy cost
        Positioned(
          top: 5, right: 5,
          child: Container(
            width: 20, height: 20,
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
        ),

        // Trait name + description
        Positioned(
          bottom: 4, left: 5, right: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(trait.name,
                style: GoogleFonts.rajdhani(
                  color: Colors.white, fontSize: 11,
                  fontWeight: FontWeight.w800,
                  shadows: const [Shadow(blurRadius: 3, color: Colors.black)]),
                maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(trait.description,
                style: const TextStyle(
                  color: Colors.white60, fontSize: 6.5, height: 1.2),
                maxLines: 3, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ]),
    );
  }
}
