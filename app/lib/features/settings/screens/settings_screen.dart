import 'package:flutter/material.dart';
import '../../battle/services/battle_audio_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late double _musicVolume;
  late double _sfxVolume;
  late bool   _musicMuted;
  late bool   _sfxMuted;

  @override
  void initState() {
    super.initState();
    final svc = BattleAudioService.instance;
    _musicVolume = svc.musicVolume;
    _sfxVolume   = svc.sfxVolume;
    _musicMuted  = svc.musicMuted;
    _sfxMuted    = svc.sfxMuted;
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _setMusicVolume(double v) {
    setState(() => _musicVolume = v);
    BattleAudioService.instance.setMusicVolume(v);
  }

  void _setSfxVolume(double v) {
    setState(() => _sfxVolume = v);
    BattleAudioService.instance.setSfxVolume(v);
  }

  void _toggleMusicMute() {
    final next = !_musicMuted;
    setState(() => _musicMuted = next);
    BattleAudioService.instance.setMusicMuted(next);
  }

  void _toggleSfxMute() {
    final next = !_sfxMuted;
    setState(() => _sfxMuted = next);
    BattleAudioService.instance.setSfxMuted(next);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050810),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1525),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Settings',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 18,
            letterSpacing: 0.5,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: Color(0xFF7FE3F5)),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        children: [
          _SectionHeader(label: 'Audio'),
          const SizedBox(height: 12),
          _AudioRow(
            icon: Icons.music_note_rounded,
            label: 'Music',
            volume: _musicVolume,
            muted: _musicMuted,
            onVolumeChanged: _setMusicVolume,
            onMuteToggle: _toggleMusicMute,
          ),
          const SizedBox(height: 16),
          _AudioRow(
            icon: Icons.spatial_audio_off_rounded,
            label: 'Sound Effects',
            volume: _sfxVolume,
            muted: _sfxMuted,
            onVolumeChanged: _setSfxVolume,
            onMuteToggle: _toggleSfxMute,
          ),
        ],
      ),
    );
  }
}

// ── Section header ─────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: Color(0xFF7FE3F5),
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.8,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF7FE3F5).withValues(alpha: 0.4),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Audio row (slider + mute button) ──────────────────────────────────────

class _AudioRow extends StatelessWidget {
  final IconData icon;
  final String   label;
  final double   volume;
  final bool     muted;
  final ValueChanged<double> onVolumeChanged;
  final VoidCallback         onMuteToggle;

  const _AudioRow({
    required this.icon,
    required this.label,
    required this.volume,
    required this.muted,
    required this.onVolumeChanged,
    required this.onMuteToggle,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveVolume = muted ? 0.0 : volume;
    final pct = (effectiveVolume * 100).round();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1525),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF1E2E48),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF7FE3F5), size: 18),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                muted ? 'Muted' : '$pct%',
                style: TextStyle(
                  color: muted
                      ? Colors.white38
                      : const Color(0xFF7FE3F5),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: onMuteToggle,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    muted
                        ? Icons.volume_off_rounded
                        : Icons.volume_up_rounded,
                    key: ValueKey(muted),
                    color: muted ? Colors.white38 : const Color(0xFF7FE3F5),
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: muted
                  ? Colors.white24
                  : const Color(0xFF7FE3F5),
              inactiveTrackColor: const Color(0xFF1E2E48),
              thumbColor: muted ? Colors.white38 : Colors.white,
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayShape:
                  const RoundSliderOverlayShape(overlayRadius: 14),
              overlayColor:
                  const Color(0xFF7FE3F5).withValues(alpha: 0.15),
              trackHeight: 3,
            ),
            child: Slider(
              value: volume,
              min: 0.0,
              max: 1.0,
              onChanged: muted ? null : onVolumeChanged,
            ),
          ),
        ],
      ),
    );
  }
}
