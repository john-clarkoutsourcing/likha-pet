import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:likha_pet_battle_engine/trait.dart';
import '../data/creature_registry.dart';
import '../services/likha_mixer.dart';
import '../widgets/pet_composite_widget.dart';
import '../../pets/models/owned_pet.dart';
import 'pet_renderer_iframe_stub.dart'
    if (dart.library.html) 'pet_renderer_iframe_web.dart' as iframe;

// ── PetRendererWidget ─────────────────────────────────────────────────────────
//
// Mobile (iOS/Android): uses WebView to load localhost:3001/render
// Web (Chrome):         uses HtmlElementView (<iframe>) to embed the same URL
//
// Both paths use @axieinfinity/mixer + Pixi.js + pixi-spine to render a fully
// animated Axie assembled from the pet's actual parts.
//
// Requires the pet-renderer Next.js service running on port 3001.

const _kRendererBase = 'http://localhost:3001';

// Tracks view IDs already registered so we never double-register.
final _registeredWebViews = <String>{};

class PetRendererWidget extends StatefulWidget {
  final CreatureDefinition def;
  final double size;
  final bool flipHorizontal;
  final String animation;
  final bool transparent;

  /// [figScale] — Pixi figure scale. Null = auto-calculate from [size].
  ///   Auto formula: size/1400, clamped 0.07–0.22.
  ///   Explicit override useful for non-square containers.
  /// [scaleMult] — Additional multiplier applied to figScale (default 1.0).
  ///   Use to shrink oversized skeletons (e.g., 0.1 for 10% of default size).
  /// [yOff] — figure Y anchor as fraction of canvas height (0.72 default).
  final double? figScale;
  final double scaleMult;
  final double yOff;

  const PetRendererWidget({
    super.key,
    required this.def,
    this.size           = 200,
    this.flipHorizontal = false,
    this.animation      = 'action/idle/normal',
    this.transparent    = true,
    this.figScale,          // null = auto
    this.scaleMult      = 1.0,
    this.yOff           = 0.72,
  });

  /// Auto-calculated scale so the figure fits inside the canvas.
  /// Axie figures look correct at 0.18 on a ~400px canvas → divisor ≈ 2200.
  /// When figScale is explicitly set, use it directly (no clamping).
  double get _effectiveScale =>
      (figScale ?? (size / 2200).clamp(0.05, 0.16));

  static PetRendererWidget fromOwned(
    OwnedPet pet, {
    double size          = 200,
    bool flipHorizontal  = false,
    String animation     = 'action/idle/normal',
    double? figScale,
    double yOff          = 0.72,
  }) =>
      PetRendererWidget(
        def:            pet.toCreatureDefinition(),
        size:           size,
        flipHorizontal: flipHorizontal,
        animation:      animation,
        figScale:       figScale,
        yOff:           yOff,
      );

  @override
  State<PetRendererWidget> createState() => _PetRendererWidgetState();
}

class _PetRendererWidgetState extends State<PetRendererWidget> {
  WebViewController? _ctrl;
  bool _ready = false;
  String? _webViewId;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _setupWebIframe();
    } else {
      _initCtrl();
    }
  }

  void _setupWebIframe() {
    final url = _buildUrl();
    final viewId = 'pet-renderer-${url.hashCode.abs()}';
    if (!_registeredWebViews.contains(viewId)) {
      _registeredWebViews.add(viewId);
      iframe.registerIFrameFactory(viewId, url);
    }
    setState(() => _webViewId = viewId);
  }

  void _initCtrl() {
    _ctrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) => setState(() => _ready = true),
      ))
      ..loadRequest(Uri.parse(_buildUrl()));
  }

  @override
  void didUpdateWidget(PetRendererWidget old) {
    super.didUpdateWidget(old);
    if (kIsWeb) {
      if (_urlChanged(old)) _setupWebIframe();
      return;
    }
    if (_ctrl == null) return;
    if (_urlChanged(old)) {
      setState(() => _ready = false);
      _ctrl!.loadRequest(Uri.parse(_buildUrl()));
    } else if (old.animation != widget.animation) {
      _ctrl!.runJavaScript("window.playAnimation('${widget.animation}', true)");
    }
  }

  bool _urlChanged(PetRendererWidget old) =>
      old.def.id != widget.def.id ||
      old.def.horn.id != widget.def.horn.id ||
      old.def.back.id != widget.def.back.id ||
      old.def.tail.id != widget.def.tail.id ||
      old.def.mouth.id != widget.def.mouth.id ||
      old._effectiveScale != widget._effectiveScale ||
      old.yOff != widget.yOff;

  String _buildUrl() {
    final def = widget.def;
    final horn = LikhaMixer.sampleFromCardArt(def.horn.cardArtPath);
    final back = LikhaMixer.sampleFromCardArt(def.back.cardArtPath);
    final tail = LikhaMixer.sampleFromCardArt(def.tail.cardArtPath);
    final mouth = LikhaMixer.sampleFromCardArt(def.mouth.cardArtPath);
    
    final params = {
      'bodyId':   '4',  // Use bodyValue=4 which maps to beast-04 skeleton
      'body':     'body-normal',
      'horn':     horn,
      'back':     back,
      'tail':     tail,
      'mouth':    mouth,
      'ears':     '${def.bodyClass.name}-04',
      'eyes':     '${def.bodyClass.name}-04',
      'colorIdx': _colorIdxFor(def.bodyClass).toString(),
      'anim':     widget.animation,
      'figScale': widget._effectiveScale.toStringAsFixed(3),
      'scaleMult': widget.scaleMult.toStringAsFixed(3),
      'yOff':     widget.yOff.toStringAsFixed(3),
      'cw':       widget.size.toInt().toString(),
      'ch':       widget.size.toInt().toString(),
    };
    final query = params.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
    final url = '$_kRendererBase/render?$query';
    print('[PetRenderer] Parts: horn=$horn back=$back tail=$tail mouth=$mouth');
    print('[PetRenderer] figScale=${widget._effectiveScale} scaleMult=${widget.scaleMult} size=${widget.size}');
    print('[PetRenderer] URL: $url');
    return url;
  }

  static int _colorIdxFor(CreatureClass cls) => switch (cls) {
    CreatureClass.beast   => 3,
    CreatureClass.plant   => 6,
    CreatureClass.aquatic => 12,
    CreatureClass.reptile => 18,
    CreatureClass.bird    => 24,
    CreatureClass.bug     => 30,
  };

  @override
  Widget build(BuildContext context) {
    // ── Web: HtmlElementView iframe ──────────────────────────────────────
    if (kIsWeb) {
      if (_webViewId == null) return _fallback();
      Widget view = iframe.buildIFrameView(_webViewId!, widget.size);
      if (widget.flipHorizontal) {
        view = Transform(
          alignment: Alignment.center,
          transform: Matrix4.diagonal3Values(-1, 1, 1),
          child: view,
        );
      }
      return view;
    }

    // ── Native: WebView ──────────────────────────────────────────────────
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
      width:  widget.size,
      height: widget.size,
      child: Stack(fit: StackFit.expand, children: [
        view,
        if (!_ready)
          const Center(child: CircularProgressIndicator(
              strokeWidth: 2, color: Colors.white38)),
      ]),
    );
  }

  Widget _fallback() => PetCompositeWidget(
    def:  widget.def,
    size: widget.size,
  );
}
