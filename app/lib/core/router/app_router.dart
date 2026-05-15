import 'package:go_router/go_router.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/pve/screens/world_map_screen.dart';
import '../../features/pve/screens/stage_preview_screen.dart';
import '../../features/battle/screens/battle_screen.dart';
import '../../features/battle/screens/battle_result_screen.dart';
import '../../features/test/screens/test_battle_screen.dart';
import '../../features/pets/screens/pet_roster_screen.dart';
import '../../features/pets/screens/breeding_lab_screen.dart';
import '../../features/library/screens/library_screen.dart';

class Routes {
  static const home          = '/';
  static const roster        = '/roster';
  static const breed         = '/breed';
  static const worldMap      = '/pve';
  static const stagePreview  = '/pve/stage/:stageId';
  static const battle        = '/battle';
  static const battleResult  = '/battle/result';
  static const testBattle    = '/test-battle';
  static const library       = '/library';
}

final appRouter = GoRouter(
  initialLocation: Routes.home,
  routes: [
    GoRoute(
      path: Routes.home,
      builder: (_, __) => const HomeScreen(),
    ),
    GoRoute(
      path: Routes.roster,
      builder: (_, __) => const PetRosterScreen(),
    ),
    GoRoute(
      path: Routes.breed,
      builder: (_, __) => const BreedingLabScreen(),
    ),
    GoRoute(
      path: Routes.worldMap,
      builder: (_, __) => const WorldMapScreen(),
    ),
    GoRoute(
      path: Routes.stagePreview,
      builder: (context, state) {
        final stageId = state.pathParameters['stageId']!;
        return StagePreviewScreen(stageId: stageId);
      },
    ),
    GoRoute(
      path: Routes.battle,
      builder: (context, state) {
        final extra = state.extra! as BattleScreenArgs;
        return BattleScreen(args: extra);
      },
    ),
    GoRoute(
      path: Routes.battleResult,
      builder: (context, state) {
        final extra = state.extra! as BattleResultArgs;
        return BattleResultScreen(args: extra);
      },
    ),
    GoRoute(
      path: Routes.testBattle,
      builder: (_, __) => const TestBattleScreen(),
    ),
    GoRoute(
      path: Routes.library,
      builder: (_, __) => const LibraryScreen(),
    ),
  ],
);
