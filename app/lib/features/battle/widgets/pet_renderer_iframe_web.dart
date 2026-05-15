// Web-only implementation — compiled only when dart.library.html is available.
import 'package:web/web.dart' as web;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

void registerIFrameFactory(String viewId, String url) {
  ui_web.platformViewRegistry.registerViewFactory(viewId, (_) {
    final iframe = web.HTMLIFrameElement();
    iframe.src = url;
    iframe.style.border = 'none';
    iframe.style.width = '100%';
    iframe.style.height = '100%';
    return iframe;
  });
}

Widget buildIFrameView(String viewId, double size) {
  return SizedBox(
    width: size,
    height: size,
    child: HtmlElementView(viewType: viewId),
  );
}
