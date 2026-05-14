/// Shared team energy pool — one pool per team, drawn on by all pets.
///
/// Axie-style energy model:
///   - Team starts at [kTeamEnergyStart] energy.
///   - Gains [kTeamEnergyRegen] per round.
///   - Caps at [kTeamEnergyCap] (allows banking a few rounds of unspent energy).
///   - All pets on the same team read/spend from this single pool.

const int kTeamEnergyStart = 3;
const int kTeamEnergyRegen = 2;
const int kTeamEnergyCap   = 9;

class EnergyPool {
  int _energy;

  EnergyPool({int initial = kTeamEnergyStart}) : _energy = initial;

  int get energy => _energy;

  bool canAfford(int cost) => _energy >= cost;

  void spend(int cost) {
    _energy = (_energy - cost).clamp(0, kTeamEnergyCap);
  }

  void regen() {
    _energy = (_energy + kTeamEnergyRegen).clamp(0, kTeamEnergyCap);
  }
}
