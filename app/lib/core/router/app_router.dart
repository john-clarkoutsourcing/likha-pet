import 'package:go_router/go_router.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/pve/screens/world_map_screen.dart';
import '../../features/pve/screens/stage_preview_screen.dart';
import '../../features/battle/screens/battle_screen.dart';
import '../../features/battle/screens/battle_result_screen.dart';

// Route name constants — use these instead of raw strings everywhere
class Routes {
  static const home          = '/';
  static const worldMap      = '/pve';
  static const stagePreview  = '/pve/stage/:stageId';
  static const battle        = '/battle';
  static const battleResult  = '/battle/result';
}

final appRouter = GoRouter(
  initialLocation: Routes.home,
  routes: [
    GoRoute(
      path: Routes.home,
      builder: (_, __) => const HomeScreen(),
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
  ],
);
