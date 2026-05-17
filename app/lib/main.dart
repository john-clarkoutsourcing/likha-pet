import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spine_flutter/spine_flutter.dart';
import 'app.dart';
import 'core/theme/app_colors.dart';
import 'features/pets/providers/player_provider.dart';
import 'web/webview_platform_stub.dart'
    if (dart.library.html) 'web/webview_platform_web.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Show Flutter errors on-screen — critical for mobile debugging without devtools.
  // Replaces the default crash with a readable error widget.
  ErrorWidget.builder = (details) => _CrashWidget(details.exception.toString());

  // Forward uncaught async Dart errors to Flutter's error system
  // so ErrorWidget.builder can render them on screen.
  PlatformDispatcher.instance.onError = (error, stack) {
    FlutterError.reportError(FlutterErrorDetails(exception: error, stack: stack));
    return true;
  };

  if (kIsWeb) {
    configureWebViewPlatformForWeb();
  } else {
    await initSpineFlutter();
  }

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

// ── Full-screen error widget shown instead of crash ───────────────────────────
// On mobile without devtools, this is the only way to see what went wrong.
// Tap anywhere to copy the text, then screenshot and share with dev.

class _CrashWidget extends StatelessWidget {
  final String message;
  const _CrashWidget(this.message);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('⚠ App Error',
                    style: TextStyle(
                        color: AppColors.offensive,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text(
                    'Screenshot this screen and share with the developer.',
                    style: TextStyle(color: Colors.white54, fontSize: 12)),
                const Divider(color: Colors.white12, height: 24),
                SelectableText(
                  message,
                  style: TextStyle(
                      color: AppColors.offensive.withValues(alpha: 0.75),
                      fontSize: 11,
                      fontFamily: 'monospace'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
