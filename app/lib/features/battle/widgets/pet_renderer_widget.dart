import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:likha_pet_battle_engine/trait.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../data/creature_registry.dart';
import '../services/likha_mixer.dart';
import '../widgets/pet_composite_widget.dart';
import '../../pets/models/owned_pet.dart';
import 'pet_renderer_iframe_stub.dart'
    if (dart.library.html) 'pet_renderer_iframe_web.dart';

// ── PetRendererWidget ─────────────────────────────────────────────────────────
//
// Renders a pet using the bundled Pixi.js + pixi-spine + @axieinfinity/mixer
// renderer loaded as a Flutter asset (assets/renderer/renderer.html).
//
// Readiness detection uses two strategies:
//   1. RendererReady JS channel (fast path, fires when mixer init completes)
//   2. Polling via runJavaScriptReturningResult every 800ms (fallback)
//
// Both check window._mixerReady which is set by standalone.js after initMixer().

class PetRendererWidget extends StatefulWidget {
  final CreatureDefinition def;
  final double size;
  final bool flipHorizontal;
  final String animation;

  /// figScale — Pixi figure scale within the 400×400 internal canvas.
  /// Default 0.22 fills ~66% of the internal canvas height.
  /// The canvas is CSS-scaled to [size] for display, so this value is
  /// independent of display size — change it only to make the pet larger/smaller.
  final double? figScale;
  final double scaleMult;
  final double yOff;

  const PetRendererWidget({
    super.key,
    required this.def,
    this.size = 200,
    this.flipHorizontal = false,
    this.animation = 'action/idle/normal',
    this.figScale,
    this.scaleMult = 1.0,
    this.yOff = 0.80,
  });

  // Fixed scale for the 400px internal canvas — display-size-independent.
  double get _effectiveScale => figScale ?? 0.22;

  static PetRendererWidget fromOwned(
    OwnedPet pet, {
    double size = 200,
    bool flipHorizontal = false,
    String animation = 'action/idle/normal',
    double? figScale,
    double yOff = 0.80,
  }) =>
      PetRendererWidget(
        def: pet.toCreatureDefinition(),
        size: size,
        flipHorizontal: flipHorizontal,
        animation: animation,
        figScale: figScale,
        yOff: yOff,
      );

  @override
  State<PetRendererWidget> createState() => _PetRendererWidgetState();
}

/// Cached renderer HTML loaded once per app session.
String? _cachedRendererHtml;

class _PetRendererWidgetState extends State<PetRendererWidget> {
  WebViewController? _ctrl;
  bool _pageReady = false; // page fully loaded
  bool _renderSent = false; // render params sent at least once
  Timer? _pollTimer;
  String _rendererHtml = '';
  String? _webViewId;
  static int _webViewCounter = 0;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _setupWebIFrameRenderer();
      return;
    }
    _loadAndInit();
  }

  Future<void> _loadAndInit() async {
    if (kIsWeb) return;
    _cachedRendererHtml ??=
        await rootBundle.loadString('assets/renderer/renderer.html');
    if (!mounted) return;
    setState(() => _rendererHtml = _cachedRendererHtml!);
    _initCtrl();
  }

  void _setupWebIFrameRenderer() {
    // renderer.html detects mobile and forces Pixi.js Canvas2D mode,
    // avoiding the iOS WebGL context limit that was causing crashes.
    final viewId = 'pet-renderer-${_webViewCounter++}';
    registerIFrameFactory(viewId, _buildWebRendererUrl());
    if (!mounted) return;
    setState(() => _webViewId = viewId);
  }

  String _buildWebRendererUrl() {
    final def = widget.def;
    final params = <String, String>{
      'body': 'body-normal',
      'horn': _sampleForPart(def.horn.cardArtPath, def.bodyClass.name),
      'back': _sampleForPart(def.back.cardArtPath, def.bodyClass.name),
      'tail': _sampleForPart(def.tail.cardArtPath, def.bodyClass.name),
      'mouth': _sampleForPart(def.mouth.cardArtPath, def.bodyClass.name),
      'ears': '${def.bodyClass.name}-04',
      'eyes': '${def.bodyClass.name}-04',
      'colorIdx': '${_colorIdxFor(def.bodyClass)}',
      'anim': widget.animation,
      'figScale': widget._effectiveScale.toStringAsFixed(3),
      'scaleMult': widget.scaleMult.toStringAsFixed(3),
      'yOff': widget.yOff.toStringAsFixed(3),
      'cw': '${widget.size.toInt()}',
      'ch': '${widget.size.toInt()}',
    };
    final query = Uri(queryParameters: params).query;
    final rendererUrl =
        Uri.base.resolve('assets/assets/renderer/renderer.html');
    return '$rendererUrl?$query';
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _initCtrl() {
    _ctrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      // Fast path: JS notifies Flutter when mixer is ready.
      ..addJavaScriptChannel(
        'RendererReady',
        onMessageReceived: (msg) {
          if (!mounted) return;
          _pollTimer?.cancel();
          if (msg.message.startsWith('error:')) {
            _devLog('[WebView] RendererReady error: ${msg.message}');
            return;
          }
          _onMixerReady();
        },
      )
      ..addJavaScriptChannel(
        'FlutterLog',
        onMessageReceived: (msg) => _devLog('[WebView] ${msg.message}'),
      )
      ..setNavigationDelegate(NavigationDelegate(
        onWebResourceError: (e) =>
            _devLog('[WebView] Resource error: ${e.description}'),
        onPageFinished: (url) {
          _devLog('[WebView] Page loaded: $url');
          if (!mounted) return;
          // Start polling in case JS channels don't fire.
          _startPolling();
        },
      ))
      ..loadHtmlString(
        // Load as HTML string (not file://) so the browser gives the page
        // a non-file origin, which fixes transparent WebGL compositing on
        // iOS WKWebView. All textures are injected as base64 data: URLs so
        // no file-system access is needed.
        _rendererHtml,
      );
  }

  void _onMixerReady() {
    if (!mounted) return;
    if (!_pageReady) {
      _pageReady = true;
      setState(() {});
    }
    if (!_renderSent) {
      _renderSent = true;
      _injectTexturesAndRender();
    }
  }

  Future<void> _injectTexturesAndRender() async {
    if (!mounted || _ctrl == null) return;
    try {
      final textures = await _preloadTextures(widget.def);
      if (!mounted) return;
      if (textures.isNotEmpty) {
        final json = jsonEncode(textures);
        await _ctrl!.runJavaScript('window.preloadedTextures = $json;');
        _devLog('[WebView] Injected ${textures.length} preloaded textures');
      }
    } catch (e) {
      _devLog('[WebView] Texture preload error: $e');
    }
    if (!mounted) return;
    _ctrl!.runJavaScript(_buildRenderCall());
  }

  /// Loads PNG textures needed to render this specific pet from Flutter assets.
  /// Returns base64 data URLs keyed by relative path within the mixer-stuffs dir.
  ///
  /// Loads:
  ///  • body-normal — shared body skeleton
  ///  • All 6 variants of the body class — for consistent ear/eyes rendering
  ///  • The specific variant folder for each part (horn/back/tail/mouth)
  ///    so hybrid pets with cross-class parts render correctly
  Future<Map<String, String>> _preloadTextures(CreatureDefinition def) async {
    const prefix = 'assets/renderer/mixer-stuffs/v3/';

    // All variant directories needed for this pet
    final neededDirs = <String>{
      'body-normal',
      // All 6 variants of the body class (for ears, eyes, and body-specific anims)
      for (final v in ['02', '04', '06', '08', '10', '12'])
        '${def.bodyClass.name}-$v',
      // Specific variant for each part — critical for hybrid/cross-class parts
      _sampleForPart(def.horn.cardArtPath, def.bodyClass.name),
      _sampleForPart(def.back.cardArtPath, def.bodyClass.name),
      _sampleForPart(def.tail.cardArtPath, def.bodyClass.name),
      _sampleForPart(def.mouth.cardArtPath, def.bodyClass.name),
    };

    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final all = manifest.listAssets();
    final result = <String, String>{};

    for (final asset in all) {
      if (!asset.startsWith(prefix) || !asset.endsWith('.png')) continue;
      final relPath =
          asset.substring(prefix.length); // e.g. "beast-04/back.png"
      final dir = relPath.split('/').first;
      if (!neededDirs.contains(dir)) continue;
      try {
        final data = await rootBundle.load(asset);
        final b64 = base64Encode(data.buffer.asUint8List());
        result[relPath] = 'data:image/png;base64,$b64';
      } catch (_) {}
    }
    return result;
  }

  void _startPolling() {
    _pollTimer?.cancel();
    int attempts = 0;
    _pollTimer =
        Timer.periodic(const Duration(milliseconds: 800), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      attempts++;
      if (attempts > 30) {
        // 24s timeout — give up
        timer.cancel();
        _devLog('[WebView] Poll timeout — renderer not ready after 24s');
        if (!_pageReady) {
          _pageReady = true;
          setState(() {});
        }
        return;
      }
      try {
        final result = await _ctrl!.runJavaScriptReturningResult(
          'window._mixerReady === true ? "ready" : (window._renderError ? "error:" + window._renderError : "wait")',
        );
        final r = result.toString().replaceAll('"', '');
        if (r == 'ready') {
          timer.cancel();
          _devLog('[WebView] Poll: mixer ready (attempt $attempts)');
          _onMixerReady();
        } else if (r.startsWith('error:')) {
          timer.cancel();
          _devLog('[WebView] Poll: render error: $r');
          if (!_pageReady) {
            _pageReady = true;
            setState(() {});
          }
        }
        // else "wait" — keep polling
      } catch (e) {
        _devLog('[WebView] Poll error: $e');
      }
    });
  }

  @override
  void didUpdateWidget(PetRendererWidget old) {
    super.didUpdateWidget(old);
    if (kIsWeb) {
      final modelChanged = old.def.horn.id != widget.def.horn.id ||
          old.def.back.id != widget.def.back.id ||
          old.def.tail.id != widget.def.tail.id ||
          old.def.mouth.id != widget.def.mouth.id ||
          old.def.bodyClass != widget.def.bodyClass ||
          old.size != widget.size ||
          old._effectiveScale != widget._effectiveScale ||
          old.scaleMult != widget.scaleMult ||
          old.yOff != widget.yOff;
      if (modelChanged) {
        _setupWebIFrameRenderer();
        return;
      }

      final animChanged = old.animation != widget.animation;
      if (animChanged && _webViewId != null) {
        postIFrameMessage(_webViewId!, {
          'type': 'likha:playAnimation',
          'animation': widget.animation,
          'loop': _isLooping(widget.animation),
        });
      }
      return;
    }
    if (_ctrl == null || !_pageReady) return;

    final partsChanged = old.def.horn.id != widget.def.horn.id ||
        old.def.back.id != widget.def.back.id ||
        old.def.tail.id != widget.def.tail.id ||
        old.def.mouth.id != widget.def.mouth.id ||
        old.def.bodyClass != widget.def.bodyClass;

    if (partsChanged ||
        old._effectiveScale != widget._effectiveScale ||
        old.yOff != widget.yOff) {
      _renderSent = false;
      _onMixerReady();
    } else if (old.animation != widget.animation) {
      // One-shot animations (hit, attack, buff, etc.) play once then auto-return
      // to idle. Only idle/random variants loop continuously.
      final loop = _isLooping(widget.animation);
      _ctrl!.runJavaScript(
          "window.LikhaPetRenderer.playAnimation('${widget.animation}', $loop)");
    }
  }

  String _buildRenderCall() {
    final def = widget.def;
    final horn = _sampleForPart(def.horn.cardArtPath, def.bodyClass.name);
    final back = _sampleForPart(def.back.cardArtPath, def.bodyClass.name);
    final tail = _sampleForPart(def.tail.cardArtPath, def.bodyClass.name);
    final mouth = _sampleForPart(def.mouth.cardArtPath, def.bodyClass.name);

    final params = {
      'body': 'body-normal',
      'horn': horn,
      'back': back,
      'tail': tail,
      'mouth': mouth,
      'ears': '${def.bodyClass.name}-04',
      'eyes': '${def.bodyClass.name}-04',
      'colorIdx': _colorIdxFor(def.bodyClass),
      'anim': widget.animation,
      'figScale': double.parse(widget._effectiveScale.toStringAsFixed(3)),
      'scaleMult': double.parse(widget.scaleMult.toStringAsFixed(3)),
      'yOff': double.parse(widget.yOff.toStringAsFixed(3)),
      'width': widget.size.toInt(),
      'height': widget.size.toInt(),
    };

    _devLog(
        '[WebView] Sending render: horn=$horn back=$back tail=$tail mouth=$mouth '
        'colorIdx=${params["colorIdx"]} figScale=${params["figScale"]}');
    final json = jsonEncode(params);
    return 'window.LikhaPetRenderer.render($json)';
  }

  static int _colorIdxFor(CreatureClass cls) => switch (cls) {
        CreatureClass.beast => 3,
        CreatureClass.plant => 6,
        CreatureClass.aquatic => 12,
        CreatureClass.reptile => 18,
        CreatureClass.bird => 24,
        CreatureClass.bug => 30,
      };

  static String _sampleForPart(String cardArtPath, String bodyClass) {
    const validClasses = {
      'beast',
      'plant',
      'aquatic',
      'reptile',
      'bird',
      'bug'
    };
    const validVariants = {'02', '04', '06', '08', '10', '12'};

    try {
      final sample = LikhaMixer.sampleFromCardArt(cardArtPath);
      final parts = sample.split('-');
      if (parts.length == 2 &&
          validClasses.contains(parts[0]) &&
          validVariants.contains(parts[1])) {
        return sample;
      }
    } catch (_) {}

    final fallbackClass =
        validClasses.contains(bodyClass) ? bodyClass : 'beast';
    return '$fallbackClass-04';
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      if (_webViewId == null) return _fallback();
      Widget view = buildIFrameView(_webViewId!, widget.size);
      if (widget.flipHorizontal) {
        view = Transform(
          alignment: Alignment.center,
          transform: Matrix4.diagonal3Values(-1, 1, 1),
          child: view,
        );
      }
      return view;
    }
    if (_ctrl == null) return _fallback();

    Widget view = WebViewWidget(controller: _ctrl!);
    if (widget.flipHorizontal) {
      view = Transform(
        alignment: Alignment.center,
        transform: Matrix4.diagonal3Values(-1, 1, 1),
        child: view,
      );
    }

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(fit: StackFit.expand, children: [
        view,
        if (!_pageReady)
          const Center(
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white38)),
      ]),
    );
  }

  /// Only idle and random-idle animations should loop.
  /// Attack, hit, buff, debuff, heal, shield, move, faint all play once.
  static bool _isLooping(String anim) =>
      anim.startsWith('action/idle') || anim.startsWith('action/mix');

  Widget _fallback() => PetCompositeWidget(
        def: widget.def,
        size: widget.size,
      );
}

void _devLog(String message) {
  if (kDebugMode) {
    debugPrint(message);
  }
}
