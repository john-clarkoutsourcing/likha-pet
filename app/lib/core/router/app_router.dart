import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/home/screens/pet_roster_integrated_screen.dart';
import '../../features/home/screens/pet_detail_screen.dart';
import '../../features/pve/screens/world_map_screen.dart';
import '../../features/pve/screens/stage_preview_screen.dart';
import '../../features/battle/screens/battle_screen.dart';
import '../../features/battle/screens/battle_result_screen.dart';
import '../../features/test/screens/test_battle_screen.dart';
import '../../features/pets/screens/breeding_lab_screen.dart';
import '../../features/pets/screens/team_management_screen.dart';
import '../../features/library/screens/library_screen.dart';
import '../../features/onboarding/screens/starter_pack_screen.dart';
import '../../features/pvp/screens/pvp_queue_screen.dart';
import '../../features/pvp/screens/pvp_battle_screen.dart';
import '../../features/pvp/screens/pvp_result_screen.dart';

class Routes {
  static const login         = '/login';
  static const register      = '/register';
  static const starterPack   = '/starter-pack';
  static const home          = '/home';
  static const roster        = '/roster';
  static const petDetail     = '/pet/:petId';
  static const breed         = '/breed';
  static const teamManager   = '/teams';
  static const worldMap      = '/pve';
  static const stagePreview  = '/pve/stage/:stageId';
  static const battle        = '/battle';
  static const battleResult  = '/battle/result';
  static const testBattle    = '/test-battle';
  static const library       = '/library';
  static const pvpQueue      = '/pvp';
  static const pvpBattle     = '/pvp/battle';
  static const pvpResult     = '/pvp/result';
}

/// Create GoRouter with auth-based redirect using Riverpod
GoRouter createGoRouter(bool isAuthenticated) {
  return GoRouter(
    initialLocation: isAuthenticated ? Routes.home : Routes.login,
    redirect: (context, state) {
      final isBrowser = state.uri.path == Routes.login || state.uri.path == Routes.register;
      
      if (!isAuthenticated && !isBrowser) {
        return Routes.login;
      }
      
      if (isAuthenticated && isBrowser) {
        return Routes.home;
      }
      
      return null;
    },
    routes: [
      // Auth routes (public)
      GoRoute(
        path: Routes.login,
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: Routes.register,
        builder: (_, __) => const RegisterScreen(),
      ),
      // Protected routes (require auth)
      GoRoute(
        path: Routes.starterPack,
        builder: (_, __) => const StarterPackScreen(),
      ),
      GoRoute(
        path: Routes.home,
        builder: (_, __) => const HomeScreen(),
      ),
      GoRoute(
        path: Routes.roster,
        builder: (_, __) => const PetRosterIntegratedScreen(),
      ),
      GoRoute(
        path: Routes.petDetail,
        builder: (context, state) {
          final petId = state.pathParameters['petId']!;
          return PetDetailScreen(petId: petId);
        },
      ),
      GoRoute(
        path: Routes.breed,
        builder: (_, __) => const BreedingLabScreen(),
      ),
      GoRoute(
        path: Routes.teamManager,
        builder: (_, __) => const TeamManagementScreen(),
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
      GoRoute(
        path: Routes.pvpQueue,
        builder: (_, __) => const PvpQueueScreen(),
      ),
      GoRoute(
        path: Routes.pvpBattle,
        builder: (_, __) => const PvpBattleScreen(),
      ),
      GoRoute(
        path: Routes.pvpResult,
        builder: (context, state) {
          final extra = state.extra! as PvpResultArgs;
          return PvpResultScreen(args: extra);
        },
      ),
    ],
  );
}

/// Router Guard Widget
/// 
/// This widget manages GoRouter configuration based on auth state from Riverpod.
/// It creates a new GoRouter instance whenever auth state changes, causing redirects.
class RouterGuard extends ConsumerWidget {
  const RouterGuard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final isAuthenticated = authState == AuthState.authenticated;

    // Create a new router whenever auth state changes
    final router = createGoRouter(isAuthenticated);

    return MaterialApp.router(
      title: 'Likha Pet',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      routerConfig: router,
    );
  }
}
