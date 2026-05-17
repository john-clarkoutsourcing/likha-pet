// Non-web stub — no-op implementations used on iOS/Android native.
import 'package:flutter/material.dart';

// Native apps are never mobile web browsers (they are native apps).
bool get isMobileWebBrowser => false;

void registerIFrameFactory(String viewId, String url) {}
void postIFrameMessage(String viewId, Map<String, Object?> message) {}
Widget buildIFrameView(String viewId, double size) => const SizedBox();
