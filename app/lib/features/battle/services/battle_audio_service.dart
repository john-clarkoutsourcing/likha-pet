import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class BattleAudioService {
  static final BattleAudioService instance = BattleAudioService._();
  BattleAudioService._();

  // Pool of players for concurrent SFX (attacks and hits overlap).
  static const _poolSize = 6;
  final _pool = List.generate(_poolSize, (_) => AudioPlayer());
  int _poolIdx = 0;

  bool _muted = false;
  bool _initialized = false;
  final _rng = Random();

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    for (final p in _pool) {
      await p.setReleaseMode(ReleaseMode.stop);
      if (!kIsWeb) await p.setPlayerMode(PlayerMode.lowLatency);
    }
  }

  void setMuted(bool muted) => _muted = muted;
  bool get isMuted => _muted;

  void _play(String assetPath, {double volume = 1.0}) {
    if (_muted || !_initialized) return;
    final player = _pool[_poolIdx % _poolSize];
    _poolIdx++;
    player.play(AssetSource(assetPath), volume: volume);
  }

  // ── Attack / skill sounds ──────────────────────────────────────────────────
  // Axie Classic style: sword swoosh for damage, spell chime for magic,
  // bubble pop for heal/buff, bite for bug-class attacks.

  static const _swingSounds = [
    'audio/battle/attack_swing.wav',
    'audio/battle/attack_swing_2.wav',
    'audio/battle/attack_swing_3.wav',
  ];
  static const _biteSounds = [
    'audio/battle/attack_bite.wav',
    'audio/battle/attack_bite_2.wav',
  ];

  void playAttack(String effectType) {
    switch (effectType) {
      case 'damage':
        _play(_swingSounds[_rng.nextInt(_swingSounds.length)]);
      case 'aoe':
        _play('audio/battle/attack_spell.wav', volume: 0.9);
      case 'heal':
        _play('audio/battle/attack_heal.wav', volume: 0.8);
      case 'shield':
        _play('audio/battle/attack_buff.wav', volume: 0.8);
      case 'shieldBreak':
        _play(_biteSounds[_rng.nextInt(_biteSounds.length)]);
      case 'buff':
        _play('audio/battle/attack_buff.wav', volume: 0.7);
      case 'debuff':
        _play('audio/battle/attack_magic.wav', volume: 0.75);
      case 'stun':
        _play('audio/battle/attack_magic.wav', volume: 0.8);
      case 'poison' || 'burn':
        _play(_biteSounds[_rng.nextInt(_biteSounds.length)], volume: 0.7);
      default:
        _play(_swingSounds[_rng.nextInt(_swingSounds.length)]);
    }
  }

  // ── Hit / faint sounds ─────────────────────────────────────────────────────
  // Uses creature "hurt" sounds — the cute yelp an Axie makes when hit.

  static const _hurtSounds = [
    'audio/battle/pet_hurt_1.ogg',
    'audio/battle/pet_hurt_2.ogg',
    'audio/battle/pet_hurt_3.ogg',
    'audio/battle/pet_hurt_4.ogg',
    'audio/battle/pet_hurt_5.ogg',
  ];

  void playHit({bool faint = false}) {
    // All hits use creature hurt sounds; faint is slightly louder.
    final s = _hurtSounds[_rng.nextInt(_hurtSounds.length)];
    _play(s, volume: faint ? 1.0 : 0.8);
  }

  // ── Card sounds ────────────────────────────────────────────────────────────
  // From the Cockatrice digital card game (CC0) — actual card game SFX.

  void playCardDraw() {
    _play('audio/card/card_draw.wav', volume: 0.8);
  }

  void playCardPlay() {
    _play('audio/card/card_play.wav', volume: 0.9);
  }

  void playCardUnplay() {
    _play('audio/card/card_tap.wav', volume: 0.6);
  }

  void playShuffle() {
    _play('audio/card/shuffle.wav', volume: 0.7);
  }

  void playEnergyGain() {
    // Coin chime — matches Axie's energy orb collection sound.
    final coins = [
      'audio/card/energy_gain.wav',
      'audio/card/energy_gain_2.wav',
      'audio/card/energy_gain_3.wav',
    ];
    _play(coins[_rng.nextInt(coins.length)], volume: 0.75);
  }

  // ── UI sounds ──────────────────────────────────────────────────────────────
  // RPG interface sounds — short chime clicks.

  void playConfirm() => _play('audio/ui/confirm.wav', volume: 0.8);
  void playError()   => _play('audio/card/card_error.wav', volume: 0.7);
  void playBack()    => _play('audio/ui/back.wav',    volume: 0.7);
  void playTap()     => _play('audio/ui/tap.wav',     volume: 0.55);
}
