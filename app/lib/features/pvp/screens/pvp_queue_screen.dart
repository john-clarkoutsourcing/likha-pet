import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../pets/models/owned_pet.dart';
import '../../pets/providers/player_provider.dart';
import '../models/pvp_message.dart';
import '../providers/pvp_battle_provider.dart';
import '../providers/pvp_queue_provider.dart';

class PvpQueueScreen extends ConsumerStatefulWidget {
  const PvpQueueScreen({super.key});

  @override
  ConsumerState<PvpQueueScreen> createState() => _PvpQueueScreenState();
}

class _PvpQueueScreenState extends ConsumerState<PvpQueueScreen> {
  @override
  Widget build(BuildContext context) {
    final queue      = ref.watch(pvpQueueProvider);
    final playerData = ref.watch(playerProvider);
    final team       = playerData.activeRoster;

    // Navigate to battle when a match is found
    ref.listen(pvpQueueProvider, (prev, next) {
      if (next.phase == QueuePhase.matched && next.matchFound != null) {
        final match = next.matchFound!;
        // Find the saved team name that matches the active roster
        final teamUids = team.map((p) => p.uid).toList();
        final savedTeam = playerData.savedTeams.cast<dynamic>().firstWhere(
          (t) =>
              t.petUids.length == teamUids.length &&
              List.generate(teamUids.length, (i) => t.petUids[i] == teamUids[i])
                  .every((b) => b),
          orElse: () => null,
        );
        final teamName = savedTeam?.name as String? ?? 'My Team';
        ref.read(pvpQueueProvider.notifier).clearMatch();
        ref.read(pvpBattleArgsProvider.notifier).state = PvpBattleArgs(
          matchFound: match,
          myTeam: team,
          myTeamName: teamName,
        );
        context.go(Routes.pvpBattle);
      }
    });

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('Arena (PvP)', style: TextStyle(color: AppColors.textPrimary)),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // MMR badge
              if (queue.mmr > 0) ...[
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Text(
                      'MMR  ${queue.mmr}',
                      style: const TextStyle(
                          color: AppColors.secondary,
                          fontWeight: FontWeight.bold,
                          fontSize: 18),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Team preview
              Text('Your Team', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final pet in team) ...[
                    _PetChip(pet: pet),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
              const SizedBox(height: 32),

              // Status / action
              if (queue.phase == QueuePhase.idle || queue.phase == QueuePhase.connecting) ...[
                if (queue.error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(queue.error!,
                        style: const TextStyle(color: Colors.redAccent), textAlign: TextAlign.center),
                  ),
                ElevatedButton(
                  onPressed: team.length == 3
                      ? () => ref.read(pvpQueueProvider.notifier).joinQueue(team)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF5350),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    team.length < 3 ? 'Select 3 pets first' : 'Find Match',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ] else if (queue.phase == QueuePhase.queuing) ...[
                _QueueSpinner(position: queue.position),
                const SizedBox(height: 20),
                OutlinedButton(
                  onPressed: () => ref.read(pvpQueueProvider.notifier).leaveQueue(),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.divider),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
                ),
              ] else if (queue.phase == QueuePhase.matched) ...[
                const Center(
                  child: CircularProgressIndicator(color: AppColors.accent),
                ),
                const SizedBox(height: 12),
                const Text('Match found! Loading battle…',
                    style: TextStyle(color: AppColors.textPrimary),
                    textAlign: TextAlign.center),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PetChip extends StatelessWidget {
  final OwnedPet pet;
  const _PetChip({required this.pet});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: Text(pet.name,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
    );
  }
}

class _QueueSpinner extends StatefulWidget {
  final int position;
  const _QueueSpinner({required this.position});

  @override
  State<_QueueSpinner> createState() => _QueueSpinnerState();
}

class _QueueSpinnerState extends State<_QueueSpinner> {
  int _elapsed = 0;
  late final _timer = Stream.periodic(const Duration(seconds: 1), (t) => t + 1)
      .listen((t) { if (mounted) setState(() => _elapsed = t); });

  @override
  void dispose() { _timer.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final mins = _elapsed ~/ 60;
    final secs = _elapsed % 60;
    final elapsed = mins > 0
        ? '${mins}m ${secs.toString().padLeft(2, '0')}s'
        : '${secs}s';

    return Column(children: [
      const CircularProgressIndicator(color: const Color(0xFFEF5350)),
      const SizedBox(height: 16),
      Text('Searching for opponent…',
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 15)),
      const SizedBox(height: 4),
      Text('$elapsed · Position ${widget.position}',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
    ]);
  }
}
