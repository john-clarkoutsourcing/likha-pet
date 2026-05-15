import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spine_flutter/spine_flutter.dart';
import 'app.dart';
import 'features/pets/providers/player_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb) await initSpineFlutter();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarBrightness: Brightness.dark,
    statusBarIconBrightness: Brightness.light,
  ));

  // Pre-initialize player data so it's ready before any screen renders.
  final container = ProviderContainer();
  // On launch: initialize player data (loads saved or hatches fresh starters).
  // Call resetAndRehatch() here once to wipe old hardcoded pure-breed pets.
  await container.read(playerProvider.notifier).initialize();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const LikhaPetApp(),
    ),
  );
}
