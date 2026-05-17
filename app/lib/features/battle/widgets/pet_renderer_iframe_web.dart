// Web-only implementation — compiled only when dart.library.html is available.
import 'dart:convert';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

/// True on iOS/Android mobile browsers where iframe WebGL is unreliable.
/// When true, PetRendererWidget skips the iframe and shows PetCompositeWidget.
bool get isMobileWebBrowser {
  final ua = html.window.navigator.userAgent.toLowerCase();
  return ua.contains('iphone') || ua.contains('ipad') || ua.contains('android');
}

final Map<String, html.IFrameElement> _iframesByViewId = {};

void registerIFrameFactory(String viewId, String url) {
  ui_web.platformViewRegistry.registerViewFactory(viewId, (_) {
    final iframe = html.IFrameElement();
    iframe.src = url;
    iframe.style.border = 'none';
    iframe.style.width = '100%';
    iframe.style.height = '100%';
    // Let Flutter widgets behind/around this platform view receive taps.
    iframe.style.pointerEvents = 'none';
    _iframesByViewId[viewId] = iframe;
    return iframe;
  });
}

void postIFrameMessage(String viewId, Map<String, Object?> message) {
  final iframe = _iframesByViewId[viewId];
  final win = iframe?.contentWindow;
  if (win == null) return;
  try {
    win.postMessage(jsonEncode(message), '*');
  } catch (_) {}
}

Widget buildIFrameView(String viewId, double size) {
  return SizedBox(
    width: size,
    height: size,
    child: HtmlElementView(viewType: viewId),
  );
}
