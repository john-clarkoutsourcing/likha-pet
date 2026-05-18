import 'package:flutter/material.dart';

class GameMechanicsScreen extends StatefulWidget {
  const GameMechanicsScreen({super.key});

  @override
  State<GameMechanicsScreen> createState() => _GameMechanicsScreenState();
}

class _GameMechanicsScreenState extends State<GameMechanicsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050810),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A1A2E),
        elevation: 1,
        centerTitle: true,
        title: const Text(
          'Battle Mechanics',
          style: TextStyle(
            fontFamily: 'LilitaOne',
            fontSize: 24,
            color: Color(0xFFEAFBFF),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF4AC4D9),
          labelColor: const Color(0xFF4AC4D9),
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: 'CORE'),
            Tab(text: 'BATTLE'),
            Tab(text: 'LAST STAND'),
            Tab(text: 'STATUS'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCoreTab(),
          _buildBattleTab(),
          _buildLastStandTab(),
          _buildStatusTab(),
        ],
      ),
    );
  }

  Widget _buildCoreTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildMechanicCard(
          title: '⚡ Energy System',
          points: [
            'Shared team energy pool (3/9 cap)',
            'Regenerate +2 energy per round',
            'Each card costs 1-3 energy',
            'Cannot play if team lacks energy',
          ],
        ),
        const SizedBox(height: 12),
        _buildMechanicCard(
          title: '🎯 Turn Order',
          points: [
            'Based on Speed stat (higher = faster)',
            'Speed buffs affect turn order mid-round',
            'Ties resolved randomly',
            'All living pets get a turn each round',
          ],
        ),
        const SizedBox(height: 12),
        _buildMechanicCard(
          title: '🛡️ Shield System',
          points: [
            'Blocks incoming damage first',
            'Resets to 0 at end of round (no carryover)',
            'Maximum 999 shield per round',
            'Damage calculated: net = ATK - DEF',
          ],
        ),
        const SizedBox(height: 12),
        _buildMechanicCard(
          title: '🎲 Damage Caps',
          points: [
            'Maximum damage per hit: 90',
            'Minimum damage: 1 (no healing damage)',
            'Defense subtracts BEFORE caps apply',
            'Multi-hit cards: cap applies to each hit',
          ],
        ),
      ],
    );
  }

  Widget _buildBattleTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildMechanicCard(
          title: '💪 Attacks',
          points: [
            'Deal damage based on ATK stat',
            'Reduced by enemy DEF stat',
            'Can apply status effects on hit',
            'Critical hits deal 2x damage',
          ],
        ),
        const SizedBox(height: 12),
        _buildMechanicCard(
          title: '🔄 Combo System',
          points: [
            '3v3 formation (Front/Mid/Back)',
            'All cards by one pet hit same target',
            'Multi-card combos grant bonuses',
            'Draw 3 new cards per round',
          ],
        ),
        const SizedBox(height: 12),
        _buildMechanicCard(
          title: '🎴 Hand Management',
          points: [
            '6-card hand max (start with 3)',
            'Draw 3 new cards each round',
            'No hand discard mechanic',
            'Expired cards removed auto',
          ],
        ),
        const SizedBox(height: 12),
        _buildMechanicCard(
          title: '🩸 Blood Moon (Round 10+)',
          points: [
            'True damage to ALL pets each round',
            'Starting damage: 20',
            'Escalates +10 per round (20→30→40...)',
            'Ignores shield, hits before phase end',
          ],
        ),
      ],
    );
  }

  Widget _buildLastStandTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildMechanicCard(
          title: '🔥 Last Stand Trigger',
          description:
              'An Axie enters Last Stand if the final blow is close enough to its remaining health that its Morale stat can carry it through.',
          points: [
            'Triggers if: Morale Modifier > Overkill',
            'Overkill = Damage - Remaining HP',
            'Morale Modifier = (100 / Remaining HP) × Morale',
            'Blocked by Chill debuff',
            'Example: 61 Morale, 100 HP, 150 dmg hit → survives!',
          ],
        ),
        const SizedBox(height: 12),
        _buildMechanicCard(
          title: '🔥 Ticks Per Morale Bracket',
          points: [
            '0–29 morale = 1 tick (Aquas/Birds)',
            '30–50 morale = 2 ticks (Standard units)',
            '51–70 morale = 3 ticks (Beasts/Mechs/Bugs)',
            '71+ morale = 4 ticks (requires buffs)',
          ],
        ),
        const SizedBox(height: 12),
        _buildMechanicCard(
          title: '🔥 Tick Consumption',
          points: [
            'On attack: -1 tick',
            'On incoming hit: -2 ticks',
            'On idle (skip turn): -1 tick',
            'When ticks ≤ 0: pet faints immediately',
          ],
        ),
        const SizedBox(height: 12),
        _buildMechanicCard(
          title: '🔥 Counter-Play',
          subtitle: 'Against Last Stand:',
          points: [
            'Apply Chill debuff (blocks entry)',
            'Maximize overkill (leave low HP)',
            'Use multi-hit combos (2 ticks per hit)',
            'Poison damage (triggers on action)',
          ],
        ),
      ],
    );
  }

  Widget _buildStatusTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildMechanicCard(
          title: '⬆️ Buffs',
          subtitle: 'Beneficial effects (last N rounds):',
          points: [
            'ATK Up: +20% attack (stackable)',
            'DEF Up: +20% defense (stackable)',
            'SPD Up: +20% speed (stackable)',
            'Regen: +15 HP per round',
            'Energized: +1 energy per round',
          ],
        ),
        const SizedBox(height: 12),
        _buildMechanicCard(
          title: '⬇️ Debuffs',
          subtitle: 'Harmful effects (last N rounds):',
          points: [
            'ATK Down: -20% attack',
            'DEF Down: -20% defense',
            'SPD Down: -20% speed',
            'Poison: 8 HP damage per action (stackable)',
            'Burn: 12 HP damage per round',
            'Stun: skip next action (consumed)',
            'Chill: cannot enter Last Stand',
          ],
        ),
        const SizedBox(height: 12),
        _buildMechanicCard(
          title: '❌ Special Debuffs',
          points: [
            'Sleep: next hit ignores shield',
            'Fear: skip next action',
            'Stench: enemies skip targeting this pet',
            'Aroma: forced target for enemies',
            'Heal Blocked: cannot receive healing',
          ],
        ),
      ],
    );
  }

  Widget _buildMechanicCard({
    required String title,
    String? subtitle,
    String? description,
    required List<String> points,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F1923),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF1E3A5F),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'LilitaOne',
              fontSize: 18,
              color: Color(0xFFEAFBFF),
              letterSpacing: 0.5,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontFamily: 'Fredoka',
                fontSize: 12,
                color: Color(0xFFAAE8F5),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          if (description != null) ...[
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(
                fontFamily: 'Fredoka',
                fontSize: 13,
                color: Colors.white70,
                height: 1.5,
              ),
            ),
          ],
          const SizedBox(height: 12),
          ...points.map((point) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '• ',
                  style: TextStyle(
                    color: Color(0xFF4AC4D9),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Expanded(
                  child: Text(
                    point,
                    style: const TextStyle(
                      fontFamily: 'Fredoka',
                      fontSize: 13,
                      color: Colors.white70,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}
