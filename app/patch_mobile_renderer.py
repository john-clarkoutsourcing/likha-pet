#!/usr/bin/env python3
"""
Post-build patch: injects mobile HTML renderer selection directly into
flutter_bootstrap.js after `flutter build web`.

Why direct injection is more reliable than index.html Proxy tricks:
  The bootstrap runs as a self-contained script. Our patch runs synchronously
  at the EXACT moment between _flutter.buildConfig being set and
  _flutter.loader.load() being called — no Proxy timing, no async races.

What the patch does:
  1. Prepends {renderer:'html'} to buildConfig.builds so the loader can find it.
  2. Overrides _flutter.loader.load() to pass config.renderer='html' on mobile.
     This tells the loader to select the html build, skipping CanvasKit entirely.
"""

import sys
import re

BOOTSTRAP = 'build/web/flutter_bootstrap.js'

PATCH = """
;(function(){
  if(!/iPhone|iPad|iPod|Android/i.test(navigator.userAgent))return;
  /* Force HTML renderer on mobile — CanvasKit/WebGL crashes on iOS Safari.
     Injected by patch_mobile_renderer.py after flutter build web. */
  if(_flutter.buildConfig&&_flutter.buildConfig.builds){
    _flutter.buildConfig.builds.unshift(
      {compileTarget:"dart2js",renderer:"html",mainJsPath:"main.dart.js"}
    );
  }
  var _origLoad=_flutter.loader.load.bind(_flutter.loader);
  _flutter.loader.load=function(cfg){
    cfg=Object.assign({},cfg||{});
    cfg.config=Object.assign({renderer:"html"},cfg.config||{});
    return _origLoad(cfg);
  };
})();
"""

def patch():
    with open(BOOTSTRAP, 'r', encoding='utf-8') as f:
        content = f.read()

    # Guard: don't double-patch
    if 'patch_mobile_renderer' in content:
        print('flutter_bootstrap.js already patched — skipping.')
        return

    # Find the _flutter.loader.load({ call (the final call at the end of the file)
    # and insert our patch immediately before it.
    marker = '_flutter.loader.load({'
    idx = content.rfind(marker)   # rfind = last occurrence
    if idx == -1:
        print('ERROR: Could not find _flutter.loader.load({ in bootstrap — patch failed.')
        sys.exit(1)

    patched = content[:idx] + PATCH + content[idx:]

    with open(BOOTSTRAP, 'w', encoding='utf-8') as f:
        f.write(patched)

    print('✓ Mobile HTML renderer patch applied to flutter_bootstrap.js')

if __name__ == '__main__':
    patch()
