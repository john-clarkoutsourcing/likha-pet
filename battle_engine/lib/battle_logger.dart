/// Structured battle log.
///
/// Produces two outputs:
///   [transcript] — human-readable text for console output and replay views.
///   [events]     — typed event stream for Flutter widget animation.
///
/// Flutter integration:
///   RoundLogPanel widget pattern-matches on [events] to trigger animations.
///   BattleReplayScreen renders [transcript] as a scrollable text view.
///   Each event type maps to a distinct animation (damage flash, heal pulse, etc.).
class BattleLogger {
  final StringBuffer _buf = StringBuffer();
  final List<BattleEvent> events = [];

  // ── Structure ──────────────────────────────────────────────────────────────

  void separator([int width = 60]) => _line('═' * width);

  void header(String text) {
    final pad = ' ' * (((60 - text.length) ~/ 2).clamp(0, 60));
    _line('$pad$text');
  }

  void roundBanner(int round) {
    final dashes = '─' * (49 - round.toString().length);
    _line('\n┌── Round $round $dashes');
    events.add(RoundStartEvent(round: round));
  }

  void phase(String label) => _line('│ [$label]');

  void roundEnd() => _line('└${'─' * 56}');

  // ── Combat events ──────────────────────────────────────────────────────────

  void action(String actorName, String traitName) {
    _line('  ⚔  $actorName uses [$traitName]');
    events.add(ActionEvent(actorName: actorName, traitName: traitName));
  }

  void noTarget() => _line('     → No valid target.');

  void damage(String target, int amount, int newHp,
      {bool isAoe = false, bool isCrit = false}) {
    final tag = isAoe ? 'AoE ' : '';
    final crit = isCrit ? ' ★CRIT★' : '';
    _line('     → $target takes $amount ${tag}damage. HP: $newHp$crit');
    events.add(DamageEvent(
      targetName: target,
      amount: amount,
      newHp: newHp,
      isAoe: isAoe,
      isCrit: isCrit,
    ));
  }

  void heal(String target, int amount, int newHp) {
    _line('     → $target recovers $amount HP. HP: $newHp');
    events.add(HealEvent(targetName: target, amount: amount, newHp: newHp));
  }

  void shield(String target, int amount, int newShield) {
    _line('     → $target gains $amount shield. Shield: $newShield');
    events.add(ShieldEvent(
      targetName: target,
      amount: amount,
      newShield: newShield,
    ));
  }

  void buff(String target, String buffType, int value, int duration) {
    _line('     → $target gains $buffType +$value for $duration rounds.');
    events.add(BuffAppliedEvent(
      targetName: target,
      buffType: buffType,
      value: value,
      duration: duration,
    ));
  }

  void debuff(String target, String debuffType, int value, int duration) {
    _line('     → $target afflicted with $debuffType ($value dmg, $duration rounds).');
    events.add(DebuffAppliedEvent(
      targetName: target,
      debuffType: debuffType,
      value: value,
      duration: duration,
    ));
  }

  void stun(String target) {
    _line('     → $target is STUNNED for 1 round!');
    events.add(
      DebuffAppliedEvent(
        targetName: target,
        debuffType: 'stunned',
        value: 0,
        duration: 1,
      ),
    );
  }

  void poisonTick(String petName, int dmg, int newHp) {
    _line('  ☠  $petName takes $dmg poison damage. HP: $newHp');
    events.add(DamageEvent(
      targetName: petName,
      amount: dmg,
      newHp: newHp,
      isAoe: false,
      isPoisonTick: true,
    ));
  }

  void burnTick(String petName, int dmg, int newHp) {
    _line('  🔥  $petName takes $dmg burn damage. HP: $newHp');
    events.add(DamageEvent(
      targetName: petName,
      amount: dmg,
      newHp: newHp,
      isAoe: false,
      isBurnTick: true,
    ));
  }

  void regenTick(String petName, int amount, int newHp) {
    _line('  💚  $petName regenerates $amount HP. HP: $newHp');
    events.add(HealEvent(targetName: petName, amount: amount, newHp: newHp));
  }

  void shieldBreak(String targetName) {
    _line('     → ${targetName}\'s shield was broken!');
    events.add(ShieldBreakEvent(targetName: targetName));
  }

  void stunSkip(String petName) {
    _line('  ⚡ $petName is STUNNED — skips their turn.');
    events.add(StunSkipEvent(petName: petName));
  }

  void fainted(String petName) {
    _line('     ☠  $petName FAINTED!');
    events.add(FaintedEvent(petName: petName));
  }

  // ── Status display ─────────────────────────────────────────────────────────

  void teamStatus(String teamName, List<String> statLines) {
    _line('│  $teamName:');
    for (final s in statLines) {
      _line('│    $s');
    }
  }

  // ── Outcome ────────────────────────────────────────────────────────────────

  void winner(String teamName) {
    _line('\n${'═' * 60}');
    _line(' 🏆  $teamName WINS!');
    _line('═' * 60);
    events.add(BattleEndEvent(winnerTeam: teamName));
  }

  void draw(int maxRounds) {
    _line('\n${'═' * 60}');
    _line(' 🤝  DRAW after $maxRounds rounds.');
    _line('═' * 60);
    events.add(BattleEndEvent(winnerTeam: null));
  }

  // ── Output ─────────────────────────────────────────────────────────────────

  String get transcript => _buf.toString();

  void _line(String text) => _buf.writeln(text);
}

// ── Event hierarchy ───────────────────────────────────────────────────────────
//
// Flutter integration:
//   switch (event) {
//     RoundStartEvent e => showRoundBanner(e.round),
//     DamageEvent e     => animateDamageFlash(e.targetName, e.amount),
//     HealEvent e       => animateHealPulse(e.targetName, e.amount),
//     FaintedEvent e    => animateFaint(e.petName),
//     BattleEndEvent e  => showResultScreen(e.winnerTeam),
//     ...
//   }

sealed class BattleEvent {
  const BattleEvent();
}

class RoundStartEvent extends BattleEvent {
  final int round;
  const RoundStartEvent({required this.round});
}

class ActionEvent extends BattleEvent {
  final String actorName;
  final String traitName;
  const ActionEvent({required this.actorName, required this.traitName});
}

class DamageEvent extends BattleEvent {
  final String targetName;
  final int    amount;
  final int    newHp;
  final bool   isAoe;
  final bool   isPoisonTick;
  final bool   isBurnTick;
  final bool   isCrit;
  const DamageEvent({
    required this.targetName,
    required this.amount,
    required this.newHp,
    required this.isAoe,
    this.isPoisonTick = false,
    this.isBurnTick   = false,
    this.isCrit       = false,
  });
}

class HealEvent extends BattleEvent {
  final String targetName;
  final int amount;
  final int newHp;
  const HealEvent({
    required this.targetName,
    required this.amount,
    required this.newHp,
  });
}

class ShieldEvent extends BattleEvent {
  final String targetName;
  final int amount;
  final int newShield;
  const ShieldEvent({
    required this.targetName,
    required this.amount,
    required this.newShield,
  });
}

class BuffAppliedEvent extends BattleEvent {
  final String targetName;
  final String buffType;
  final int value;
  final int duration;
  const BuffAppliedEvent({
    required this.targetName,
    required this.buffType,
    required this.value,
    required this.duration,
  });
}

class DebuffAppliedEvent extends BattleEvent {
  final String targetName;
  final String debuffType;
  final int value;
  final int duration;
  const DebuffAppliedEvent({
    required this.targetName,
    required this.debuffType,
    required this.value,
    required this.duration,
  });
}

class StunSkipEvent extends BattleEvent {
  final String petName;
  const StunSkipEvent({required this.petName});
}

class FaintedEvent extends BattleEvent {
  final String petName;
  const FaintedEvent({required this.petName});
}

class BattleEndEvent extends BattleEvent {
  /// null = draw
  final String? winnerTeam;
  const BattleEndEvent({this.winnerTeam});
}

class ShieldBreakEvent extends BattleEvent {
  final String targetName;
  const ShieldBreakEvent({required this.targetName});
}
