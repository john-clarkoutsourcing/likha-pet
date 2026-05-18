import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../battle/widgets/pet_renderer_widget.dart';
import '../../pets/models/owned_pet.dart';
import '../../pets/providers/player_provider.dart';

// ── Class accent palette ───────────────────────────────────────────────────────

const _kAccents = <String, Color>{
  'bug':     Color(0xFFE85AA8),
  'beast':   Color(0xFFF0A040),
  'reptile': Color(0xFF4ADC7A),
  'aquatic': Color(0xFF4AC4D9),
  'plant':   Color(0xFFA8D94A),
  'bird':    Color(0xFFF586A0),
};

const _kClasses = ['ALL', 'BUG', 'BEAST', 'REPTILE', 'AQUATIC', 'PLANT', 'BIRD'];

Color _accent(OwnedPet pet) =>
    _kAccents[pet.classLabel.toLowerCase()] ?? const Color(0xFF4AC4D9);

// ── Sort mode ─────────────────────────────────────────────────────────────────

enum _Sort { newest, rarityDesc, nameAsc }

// ── Screen ────────────────────────────────────────────────────────────────────

class PetRosterIntegratedScreen extends ConsumerStatefulWidget {
  const PetRosterIntegratedScreen({super.key});

  @override
  ConsumerState<PetRosterIntegratedScreen> createState() => _ScreenState();
}

class _ScreenState extends ConsumerState<PetRosterIntegratedScreen> {
  String _search = '';
  String _classFilter = 'ALL';
  _Sort  _sort        = _Sort.newest;
  final  _searchCtrl  = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<OwnedPet> _filtered(List<OwnedPet> roster) {
    var pets = roster.where((p) {
      final matchCls = _classFilter == 'ALL' ||
          p.classLabel.toUpperCase() == _classFilter;
      final matchQ = _search.isEmpty ||
          p.name.toLowerCase().contains(_search.toLowerCase());
      return matchCls && matchQ;
    }).toList();

    switch (_sort) {
      case _Sort.newest:
        pets.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case _Sort.rarityDesc:
        pets.sort((a, b) => b.purity.compareTo(a.purity));
      case _Sort.nameAsc:
        pets.sort((a, b) => a.name.compareTo(b.name));
    }
    return pets;
  }

  @override
  Widget build(BuildContext context) {
    final player   = ref.watch(playerProvider);
    final roster   = player.roster;
    final filtered = _filtered(roster);
    final hasFilter = _classFilter != 'ALL' || _search.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFF050810),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.9, -0.85),
            radius: 1.1,
            colors: [Color(0x0F4AC4D9), Color(0x00050810)],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(
                total:      roster.length,
                showing:    filtered.length,
                hasFilter:  hasFilter,
              ),
              _Toolbar(
                searchCtrl:  _searchCtrl,
                classFilter: _classFilter,
                sort:        _sort,
                onSearch:    (v) => setState(() => _search = v),
                onClearSearch: () => setState(() {
                  _search = '';
                  _searchCtrl.clear();
                }),
                onClass: (cls) => setState(() => _classFilter = cls),
                onSort:  (s)   => setState(() => _sort = s),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? _EmptyState(
                        hasFilters: hasFilter,
                        onReset: () => setState(() {
                          _classFilter = 'ALL';
                          _search      = '';
                          _searchCtrl.clear();
                        }),
                      )
                    : LayoutBuilder(
                        builder: (_, gridConstraints) {
                          final w    = gridConstraints.maxWidth;
                          final cols = w < 500  ? 2
                                     : w < 800  ? 3
                                     : w < 1100 ? 4
                                     : 5;
                          final gap  = cols >= 4 ? 8.0 : 10.0;
                          return GridView.builder(
                            padding: EdgeInsets.fromLTRB(16, 8, 16, 32),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount:   cols,
                              crossAxisSpacing: gap,
                              mainAxisSpacing:  gap,
                              childAspectRatio: 0.80,
                            ),
                            itemCount: filtered.length,
                            itemBuilder: (_, i) => _PetCard(
                              pet:    filtered[i],
                              phase:  (i * 0.7) % (2 * math.pi),
                              onTap:  () => context.push(
                                '/pet/${filtered[i].uid}',
                              ),
                              onRename: () =>
                                  _showRename(context, filtered[i]),
                            ),
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

  void _showRename(BuildContext context, OwnedPet pet) {
    final ctrl = TextEditingController(text: pet.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0A1224),
        title: Row(children: [
          const Icon(Icons.drive_file_rename_outline,
              color: Colors.amberAccent, size: 18),
          const SizedBox(width: 8),
          const Text('Rename Pet',
              style: TextStyle(color: Colors.white, fontSize: 16)),
        ]),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Pet name',
            filled: true,
            fillColor: const Color(0xFF050810),
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          style: const TextStyle(color: Colors.white),
          maxLength: 20,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final name = ctrl.text.trim();
              if (name.isNotEmpty) {
                ref.read(playerProvider.notifier).renamePet(pet.uid, name);
                ctrl.dispose();
                Navigator.of(ctx).pop();
              }
            },
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final int  total;
  final int  showing;
  final bool hasFilter;

  const _Header({
    required this.total,
    required this.showing,
    required this.hasFilter,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = hasFilter && showing != total
        ? 'Roster · $total pets · showing $showing'
        : 'Roster · $total pets';

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 16, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF7FE3F5)),
            onPressed: () => context.pop(),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'My Pets',
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
                subtitle,
                style: const TextStyle(
                  fontFamily: 'Fredoka',
                  color: Color(0xFFAAE8F5),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const Spacer(),
          // Breed CTA
          GestureDetector(
            onTap: () => context.push(Routes.breed),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFF9C27B0).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: const Color(0xFF9C27B0).withValues(alpha: 0.55)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('🧬', style: TextStyle(fontSize: 12)),
                  SizedBox(width: 4),
                  Text(
                    'Breed',
                    style: TextStyle(
                      fontFamily: 'LilitaOne',
                      color: Color(0xFFCE93D8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Manage Teams CTA
          GestureDetector(
            onTap: () => context.push(Routes.teamManager),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFF4AC4D9).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: const Color(0xFF4AC4D9).withValues(alpha: 0.55)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4AC4D9).withValues(alpha: 0.2),
                    blurRadius: 14,
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.groups_rounded,
                      size: 14, color: Color(0xFF4AC4D9)),
                  SizedBox(width: 5),
                  Text(
                    'Manage Teams',
                    style: TextStyle(
                      fontFamily: 'LilitaOne',
                      color: Color(0xFF4AC4D9),
                      fontSize: 12,
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

// ── Toolbar ───────────────────────────────────────────────────────────────────

class _Toolbar extends StatelessWidget {
  final TextEditingController           searchCtrl;
  final String                          classFilter;
  final _Sort                           sort;
  final void Function(String)           onSearch;
  final VoidCallback                    onClearSearch;
  final void Function(String)           onClass;
  final void Function(_Sort)            onSort;

  const _Toolbar({
    required this.searchCtrl,
    required this.classFilter,
    required this.sort,
    required this.onSearch,
    required this.onClearSearch,
    required this.onClass,
    required this.onSort,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1224),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: const Color(0xFF4AC4D9).withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Search + sort row
          Row(
            children: [
              Expanded(
                child: _SearchField(
                  ctrl:     searchCtrl,
                  onChanged: onSearch,
                  onClear:  onClearSearch,
                ),
              ),
              const SizedBox(width: 8),
              _SortPicker(value: sort, onChanged: onSort),
            ],
          ),
          const SizedBox(height: 10),
          // Class filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _kClasses.map((cls) {
                final active = classFilter == cls;
                final accent = cls == 'ALL'
                    ? const Color(0xFF4AC4D9)
                    : _kAccents[cls.toLowerCase()] ??
                        const Color(0xFF4AC4D9);
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () => onClass(cls),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 11, vertical: 5),
                      decoration: BoxDecoration(
                        color: active
                            ? accent.withValues(alpha: 0.22)
                            : Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: active
                              ? accent.withValues(alpha: 0.8)
                              : Colors.white.withValues(alpha: 0.12),
                          width: active ? 1.5 : 1,
                        ),
                        boxShadow: active
                            ? [
                                BoxShadow(
                                  color: accent.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                ),
                              ]
                            : null,
                      ),
                      child: Text(
                        cls,
                        style: TextStyle(
                          fontFamily: 'LilitaOne',
                          color: active ? accent : Colors.white38,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(growable: false),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController ctrl;
  final void Function(String) onChanged;
  final VoidCallback onClear;

  const _SearchField({
    required this.ctrl,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: const Color(0xFF050810),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: const Color(0xFF4AC4D9).withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 10),
          const Icon(Icons.search, size: 16, color: Color(0xFF4AC4D9)),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: ctrl,
              onChanged: onChanged,
              style: const TextStyle(
                fontFamily: 'Fredoka',
                color: Color(0xFFCDEEF4),
                fontSize: 13,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Search by name…',
                hintStyle: TextStyle(
                  fontFamily: 'Fredoka',
                  color: Color(0xFF4AC4D9),
                  fontSize: 12,
                ),
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (ctrl.text.isNotEmpty)
            GestureDetector(
              onTap: onClear,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.close, size: 14, color: Colors.white38),
              ),
            ),
        ],
      ),
    );
  }
}

class _SortPicker extends StatelessWidget {
  final _Sort                value;
  final void Function(_Sort) onChanged;

  const _SortPicker({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF050810),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: const Color(0xFF4AC4D9).withValues(alpha: 0.25)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<_Sort>(
          value: value,
          dropdownColor: const Color(0xFF0A1224),
          style: const TextStyle(
            fontFamily: 'Fredoka',
            color: Color(0xFFCDEEF4),
            fontSize: 12,
          ),
          icon: const Icon(Icons.sort, size: 14, color: Color(0xFF4AC4D9)),
          isDense: true,
          onChanged: (v) => onChanged(v!),
          items: const [
            DropdownMenuItem(value: _Sort.newest,     child: Text('Newest')),
            DropdownMenuItem(value: _Sort.rarityDesc, child: Text('Rarity ↓')),
            DropdownMenuItem(value: _Sort.nameAsc,    child: Text('Name A–Z')),
          ],
        ),
      ),
    );
  }
}

// ── Pet card ──────────────────────────────────────────────────────────────────

class _PetCard extends StatefulWidget {
  final OwnedPet     pet;
  final double       phase;
  final VoidCallback onTap;
  final VoidCallback onRename;

  const _PetCard({
    required this.pet,
    required this.phase,
    required this.onTap,
    required this.onRename,
  });

  @override
  State<_PetCard> createState() => _PetCardState();
}

class _PetCardState extends State<_PetCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 2800),
      vsync: this,
    )
      ..value = widget.phase / (2 * math.pi)
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pet    = widget.pet;
    final accent = _accent(pet);
    final def    = pet.toCreatureDefinition();
    final stats  = def.computedStats;

    return LayoutBuilder(
      builder: (_, cardConstraints) {
        final cw = cardConstraints.maxWidth;
        // Scale footer typography with card width
        final nameFs   = cw < 140 ? 10.0 : cw < 180 ? 11.0 : 13.0;
        final statFs   = cw < 140 ?  8.0 : 9.0;
        final starFs   = cw < 140 ?  8.0 : cw < 180 ? 9.0 : 10.0;
        final footPad  = cw < 140 ?  6.0 : 10.0;
        final radius   = cw < 140 ? 10.0 : 16.0;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0E1A33),
                Color(0xFF0A1224),
                Color(0xFF050810),
              ],
            ),
            border: Border.all(color: accent.withValues(alpha: 0.35)),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.07),
                blurRadius: 14,
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              // ── Sprite area — tap here to view pet details ─────────────────
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: widget.onTap,
                    splashColor: accent.withValues(alpha: 0.18),
                    highlightColor: accent.withValues(alpha: 0.10),
                    child: LayoutBuilder(
                builder: (_, spriteConstraints) {
                  final spriteSize =
                      (spriteConstraints.maxHeight * 0.80).clamp(90.0, 280.0);
                  return AnimatedBuilder(
                    animation: _ctrl,
                    builder: (context, _) {
                      final t      = _ctrl.value;
                      final bob    = math.sin(t * math.pi) * 8;

                      return Stack(
                        children: [
                          // Gradient bg tint
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    accent.withValues(alpha: 0.08),
                                    accent.withValues(alpha: 0.03),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // Ground glow ellipse
                          Positioned(
                            bottom: 10,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: Container(
                                width: spriteSize * 0.50,
                                height: 10,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(999),
                                  gradient: RadialGradient(
                                    colors: [
                                      Colors.black.withValues(alpha: 0.30 + (t * 0.10)),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Pet sprite with bob
                          Positioned(
                            bottom: 12 + bob,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: PetRendererWidget.fromOwned(
                                pet,
                                size: spriteSize,
                                animation: 'action/idle/normal',
                              ),
                            ),
                          ),
                          // Class tag — top-left
                          Positioned(
                            top: 8,
                            left: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.22),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: accent.withValues(alpha: 0.65)),
                              ),
                              child: Text(
                                pet.classLabel.toUpperCase(),
                                style: TextStyle(
                                  fontFamily: 'LilitaOne',
                                  color: accent,
                                  fontSize: 9,
                                ),
                              ),
                            ),
                          ),
                          // Generation badge — top-right
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF050810)
                                    .withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: const Color(0xFF4AC4D9)
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                              child: Text(
                                'GEN ${pet.generation}',
                                style: const TextStyle(
                                  fontFamily: 'LilitaOne',
                                  color: Color(0xFF4AC4D9),
                                  fontSize: 9,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  );        // AnimatedBuilder
                },          // LayoutBuilder builder
              ),             // LayoutBuilder
            ),               // InkWell
          ),                 // Material
        ),                   // Expanded sprite area

            // ── Footer — tap name to rename ────────────────────────────────
            Container(
              padding: EdgeInsets.fromLTRB(footPad, 6, footPad, 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.28),
                border: Border(
                  top: BorderSide(color: accent.withValues(alpha: 0.22)),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name row — tap name or pencil icon to rename
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: widget.onRename,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  pet.name,
                                  style: TextStyle(
                                    fontFamily: 'LilitaOne',
                                    color: const Color(0xFFEAFBFF),
                                    fontSize: nameFs,
                                    shadows: const [
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
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 3),
                              Icon(
                                Icons.drive_file_rename_outline,
                                size: statFs,
                                color: Colors.amberAccent.withValues(alpha: 0.5),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.favorite,
                          size: statFs,
                          color: const Color(0xFF66FF88)
                              .withValues(alpha: 0.9)),
                      const SizedBox(width: 2),
                      Text(
                        '${stats.hp}',
                        style: TextStyle(
                          color: const Color(0xFF66FF88),
                          fontSize: statFs,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  // Stars + Speed
                  Row(
                    children: [
                      ...List.generate(
                        4,
                        (i) => Text(
                          i < pet.purity ? '★' : '☆',
                          style: TextStyle(
                            color: pet.purity == 4
                                ? Colors.amber
                                : Colors.white38,
                            fontSize: starFs,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.bolt,
                          size: statFs,
                          color: const Color(0xFFFFCC44)
                              .withValues(alpha: 0.9)),
                      const SizedBox(width: 2),
                      Text(
                        '${stats.speed}',
                        style: TextStyle(
                          color: const Color(0xFFFFCC44),
                          fontSize: statFs,
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
      ); // AnimatedContainer
      }, // LayoutBuilder builder
    ); // LayoutBuilder
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool         hasFilters;
  final VoidCallback onReset;

  const _EmptyState({required this.hasFilters, required this.onReset});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasFilters ? Icons.search_off : Icons.cruelty_free,
            size: 56,
            color: const Color(0xFF4AC4D9).withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            hasFilters ? 'No pets match' : 'No pets yet',
            style: const TextStyle(
              fontFamily: 'LilitaOne',
              color: Color(0xFFEAFBFF),
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hasFilters
                ? 'Try a different filter or search term'
                : 'Hatch an egg to get started',
            style: const TextStyle(
              fontFamily: 'Fredoka',
              color: Color(0xFF7FE3F5),
              fontSize: 13,
            ),
          ),
          if (hasFilters) ...[
            const SizedBox(height: 18),
            GestureDetector(
              onTap: onReset,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 9),
                decoration: BoxDecoration(
                  color: const Color(0xFF4AC4D9).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF4AC4D9).withValues(alpha: 0.5),
                  ),
                ),
                child: const Text(
                  'Reset filters',
                  style: TextStyle(
                    fontFamily: 'LilitaOne',
                    color: Color(0xFF4AC4D9),
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
