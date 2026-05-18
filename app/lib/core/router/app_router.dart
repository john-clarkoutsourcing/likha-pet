import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/home/screens/pet_roster_integrated_screen.dart';
import '../../features/home/screens/pet_detail_screen.dart';
import '../../features/home/screens/game_mechanics_screen.dart';
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
import '../../features/settings/screens/settings_screen.dart';

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
  static const mechanics     = '/mechanics';
  static const pvpQueue      = '/pvp';
  static const pvpBattle     = '/pvp/battle';
  static const pvpResult     = '/pvp/result';
  static const settings      = '/settings';
}

/// A plain ChangeNotifier that RouterGuard pings whenever auth state changes.
/// GoRouter's refreshListenable watches it to re-run the redirect callback.
class AuthChangeNotifier extends ChangeNotifier {
  // Called by RouterGuard's ref.listen — public so the state class can reach it.
  void ping() => notifyListeners();
}

/// Create a stable GoRouter.
/// [initialAuth]      — auth state at creation time (for initialLocation only).
/// [authNotifier]     — pinged whenever auth changes; triggers redirect re-eval.
/// [isAuthenticated]  — closure that reads LIVE auth state, never stale.
GoRouter createGoRouter({
  required bool initialAuth,
  required AuthChangeNotifier authNotifier,
  required bool Function() isAuthenticated,
}) {
  return GoRouter(
    initialLocation: initialAuth ? Routes.home : Routes.login,
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final auth = isAuthenticated();
      final onAuthPage = state.uri.path == Routes.login ||
          state.uri.path == Routes.register;
      if (!auth && !onAuthPage) return Routes.login;
      if (auth && onAuthPage) return Routes.home;
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
        path: Routes.mechanics,
        builder: (_, __) => const GameMechanicsScreen(),
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
      GoRoute(
        path: Routes.settings,
        builder: (_, __) => const SettingsScreen(),
      ),
    ],
  );
}

/// Router Guard Widget
/// 
/// This widget manages GoRouter configuration based on auth state from Riverpod.
/// It creates a new GoRouter instance whenever auth state changes, causing redirects.
class RouterGuard extends ConsumerStatefulWidget {
  const RouterGuard({Key? key}) : super(key: key);

  @override
  ConsumerState<RouterGuard> createState() => _RouterGuardState();
}

class _RouterGuardState extends ConsumerState<RouterGuard> {
  late final GoRouter _router;
  final _authNotifier = AuthChangeNotifier();

  @override
  void initState() {
    super.initState();
    _router = createGoRouter(
      initialAuth: ref.read(authProvider) == AuthState.authenticated,
      authNotifier: _authNotifier,
      isAuthenticated: () => ref.read(authProvider) == AuthState.authenticated,
    );
  }

  @override
  void dispose() {
    _authNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Ping the notifier whenever auth changes — GoRouter re-runs its redirect.
    ref.listen<AuthState>(authProvider, (_, __) => _authNotifier.ping());

    return MaterialApp.router(
      title: 'Likha Pet',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      routerConfig: _router,
    );
  }
}
