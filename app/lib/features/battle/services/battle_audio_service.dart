import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

class BattleAudioService {
  static final BattleAudioService instance = BattleAudioService._();
  BattleAudioService._();

  static const _keyMusicVol  = 'audio_music_volume';
  static const _keySfxVol    = 'audio_sfx_volume';
  static const _keyMusicMute = 'audio_music_muted';
  static const _keySfxMute   = 'audio_sfx_muted';

  // SFX pool — created once, never disposed.
  static const _poolSize = 6;
  final _pool = List.generate(_poolSize, (_) => AudioPlayer());
  int _poolIdx = 0;

  bool _initialized = false;
  final _rng = Random();

  // BGM state — always use the _bgmSeq guard to detect overtaken calls.
  AudioPlayer? _bgmPlayer;
  String?      _currentBgmPath;
  double       _currentBaseVolume = 0.6;
  String?      _bgmOwner;
  int          _bgmSeq = 0; // increments on every new playBgm call

  // ── Volume / mute state ────────────────────────────────────────────────────

  double _musicVolume = 1.0;
  double _sfxVolume   = 1.0;
  bool   _musicMuted  = false;
  bool   _sfxMuted    = false;

  double get musicVolume => _musicVolume;
  double get sfxVolume   => _sfxVolume;
  bool   get musicMuted  => _musicMuted;
  bool   get sfxMuted    => _sfxMuted;
  bool   get isMuted     => _sfxMuted;

  // ── Init ───────────────────────────────────────────────────────────────────

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    for (final p in _pool) {
      await _safely(() => p.setReleaseMode(ReleaseMode.stop));
      if (!kIsWeb) await _safely(() => p.setPlayerMode(PlayerMode.lowLatency));
    }
    await _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _musicVolume = prefs.getDouble(_keyMusicVol)  ?? 1.0;
    _sfxVolume   = prefs.getDouble(_keySfxVol)    ?? 1.0;
    _musicMuted  = prefs.getBool(_keyMusicMute)   ?? false;
    _sfxMuted    = prefs.getBool(_keySfxMute)     ?? false;
  }

  // ── Settings setters ───────────────────────────────────────────────────────

  Future<void> setMusicVolume(double v) async {
    _musicVolume = v.clamp(0.0, 1.0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyMusicVol, _musicVolume);
    _refreshBgmVolume();
  }

  Future<void> setSfxVolume(double v) async {
    _sfxVolume = v.clamp(0.0, 1.0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keySfxVol, _sfxVolume);
  }

  Future<void> setMusicMuted(bool muted) async {
    _musicMuted = muted;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyMusicMute, muted);

    final p = _bgmPlayer;
    if (muted) {
      await _safely(() async { await p?.pause(); });
    } else if (p != null) {
      await _safely(() => p.resume());
      _refreshBgmVolume();
    } else if (_currentBgmPath != null) {
      await playBgm(_currentBgmPath!, baseVolume: _currentBaseVolume);
    }
  }

  Future<void> setSfxMuted(bool muted) async {
    _sfxMuted = muted;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySfxMute, muted);
  }

  void _refreshBgmVolume() {
    final p = _bgmPlayer;
    if (p == null || _musicMuted) return;
    _safely(() => p.setVolume((_currentBaseVolume * _musicVolume).clamp(0.0, 1.0)));
  }

  // Legacy compat — mutes/unmutes both channels.
  void setMuted(bool muted) {
    _musicMuted = muted;
    _sfxMuted   = muted;
    if (muted) _safely(() async { await _bgmPlayer?.pause(); });
  }

  // ── Background music ───────────────────────────────────────────────────────

  Future<void> playBgm(String assetPath, {double baseVolume = 0.6}) async {
    // Capture sequence number so an overtaken call can detect itself.
    final seq = ++_bgmSeq;

    // Tear down any current player first.
    await _teardownBgm();

    _currentBgmPath    = assetPath;
    _currentBaseVolume = baseVolume;

    if (_musicMuted) return;

    final player = AudioPlayer();
    _bgmPlayer = player;

    try {
      await player.setReleaseMode(ReleaseMode.loop);

      // Another playBgm call overtook us — abandon this player.
      if (_bgmSeq != seq) {
        _bgmPlayer = null;
        await _safely(() => player.dispose());
        return;
      }

      final vol = (baseVolume * _musicVolume).clamp(0.0, 1.0);
      await player.play(AssetSource(assetPath), volume: vol);

      if (_bgmSeq != seq) {
        _bgmPlayer = null;
        await _safely(() => player.dispose());
      }
    } catch (e) {
      // If this player failed, clear it so future calls start clean.
      if (_bgmPlayer == player) _bgmPlayer = null;
      await _safely(() => player.dispose());
    }
  }

  // Owner-scoped BGM API so battle flows can manage lifecycle safely.
  // Repeated calls from the same owner/path are treated as updates, not replay.
  Future<void> playOwnedBgm(
    String owner,
    String assetPath, {
    double baseVolume = 0.6,
  }) async {
    if (_bgmOwner == owner &&
        _currentBgmPath == assetPath &&
        _bgmPlayer != null) {
      _currentBaseVolume = baseVolume;
      _refreshBgmVolume();
      return;
    }

    _bgmOwner = owner;
    await playBgm(assetPath, baseVolume: baseVolume);
  }

  Future<void> stopBgm() async {
    ++_bgmSeq; // invalidate any in-flight playBgm
    await _teardownBgm();
    _bgmOwner = null;
    _currentBgmPath = null;
  }

  Future<void> stopOwnedBgm(String owner) async {
    if (_bgmOwner != owner) return;
    await stopBgm();
  }

  Future<void> _teardownBgm() async {
    final p = _bgmPlayer;
    _bgmPlayer = null;
    if (p == null) return;
    await _safely(() => p.stop());
    await _safely(() => p.dispose());
  }

  // ── SFX ───────────────────────────────────────────────────────────────────

  void _play(String assetPath, {double volume = 1.0}) {
    if (_sfxMuted || !_initialized) return;
    final scaled = (volume * _sfxVolume).clamp(0.0, 1.0);
    final player = _pool[_poolIdx % _poolSize];
    _poolIdx++;
    _safely(() => player.play(AssetSource(assetPath), volume: scaled));
  }

  // ── Attack / skill sounds ──────────────────────────────────────────────────

  static const _biteSounds = [
    'audio/battle/attack_bite.wav',
    'audio/battle/attack_bite_2.wav',
  ];

  void playAttack(String effectType) {
    switch (effectType) {
      case 'damage':
        _play('audio/battle/attack_punch.wav');
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
        _play('audio/battle/attack_punch.wav');
    }
  }

  // ── Hit / faint sounds ─────────────────────────────────────────────────────

  static const _hurtSounds = [
    'audio/battle/pet_hurt_1.ogg',
    'audio/battle/pet_hurt_2.ogg',
    'audio/battle/pet_hurt_3.ogg',
    'audio/battle/pet_hurt_4.ogg',
    'audio/battle/pet_hurt_5.ogg',
  ];

  void playHit({bool faint = false}) {
    final s = _hurtSounds[_rng.nextInt(_hurtSounds.length)];
    _play(s, volume: faint ? 1.0 : 0.8);
  }

  // ── Card sounds ────────────────────────────────────────────────────────────

  void playCardDraw()   => _play('audio/card/card_draw_1.ogg',  volume: 0.8);
  void playCardPlay()   => _play('audio/card/card_play.wav',  volume: 0.9);
  void playCardUnplay() => _play('audio/card/card_tap.wav',   volume: 0.6);
  void playShuffle()    => _play('audio/card/shuffle.wav',    volume: 0.7);

  void playEnergyGain() {
    final coins = [
      'audio/card/energy_gain.wav',
      'audio/card/energy_gain_2.wav',
      'audio/card/energy_gain_3.wav',
    ];
    _play(coins[_rng.nextInt(coins.length)], volume: 0.75);
  }

  // ── UI sounds ──────────────────────────────────────────────────────────────

  void playConfirm() => _play('audio/ui/confirm.wav',       volume: 0.8);
  void playError()   => _play('audio/card/card_error.wav',  volume: 0.7);
  void playBack()    => _play('audio/ui/back.wav',          volume: 0.7);
  void playTap()     => _play('audio/ui/tap.wav',           volume: 0.55);

  // ── Safety wrapper ─────────────────────────────────────────────────────────

  // Silently swallows "AudioPlayer has been disposed" and similar async errors
  // that arise when navigation tears down a screen mid-playback.
  static Future<void> _safely(Future<void> Function() fn) async {
    try {
      await fn();
    } catch (_) {}
  }
}
