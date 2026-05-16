// Web-only implementation — compiled only when dart.library.html is available.
import 'dart:convert';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

final Map<String, html.IFrameElement> _iframesByViewId = {};

void registerIFrameFactory(String viewId, String url) {
  ui_web.platformViewRegistry.registerViewFactory(viewId, (_) {
    final iframe = html.IFrameElement();
    iframe.src = url;
    iframe.style.border = 'none';
    iframe.style.width = '100%';
    iframe.style.height = '100%';
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
