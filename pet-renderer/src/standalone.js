/**
 * standalone.js — Self-contained pet renderer for Flutter WebView.
 *
 * Loaded as a Flutter asset — no server required.
 * Reads pet parts from URL query params, renders via Pixi.js + pixi-spine.
 * Textures loaded from sibling asset paths (mixer-stuffs/v3/).
 */

import 'pixi-spine';
import * as PIXI from 'pixi.js';
import {
  initAxieMixer,
  getAxieSpineFromCombo,
  getAxieColorPartShift,
  getVariantAttachmentPath,
} from '@axieinfinity/mixer';

// ── State ─────────────────────────────────────────────────────────────────────

let _app       = null;
let _figure    = null;
let _loader    = null;
let _spineAtlas = null;
let _spineData  = null;

// ── Init ──────────────────────────────────────────────────────────────────────
// JSON loaded as raw strings (asset/source) and parsed at runtime via JSON.parse.
// This avoids JavaScriptCore's per-expression size limit on iOS, which rejects
// 3+ MiB JavaScript object literals with a silent "Script Error.".

const _genesData      = JSON.parse(require('../public/creature-genes.json'));
const _samplesData    = JSON.parse(require('../public/creature-samples.json'));
const _variantsData   = JSON.parse(require('../public/creature-variants.json'));
const _animationsData = JSON.parse(require('../public/creature-animations.json'));

function initMixer() {
  // Deep copy so initAxieMixer can mutate without affecting the original.
  const genes = JSON.parse(JSON.stringify(_genesData));

  if (genes?.items?.parts) {
    genes.items.parts = genes.items.parts.map(p => ({ ...p, skinsLv2: p.skinsLv2 ?? [] }));
  }
  if (genes?.items && !genes.items.bodies) {
    genes.items.bodies = [{ skin: 0, bodyValue: -1, mysticValue: -1, bodyName: 'body-normal' }];
  }

  initAxieMixer(genes, _samplesData, _variantsData, _animationsData);
}

// ── Render ────────────────────────────────────────────────────────────────────

async function renderPet(params) {
  try {
    const {
      body     = 'body-normal',
      horn     = 'beast-04',
      back     = 'beast-04',
      tail     = 'beast-04',
      mouth    = 'beast-04',
      ears,
      eyes,
      colorIdx = 0,
      anim     = 'action/idle/normal',
      figScale = 0.22,
      scaleMult = 1.0,
      yOff     = 0.80,
      width    = window.innerWidth,
      height   = window.innerHeight,
    } = params;

    log('renderPet START: horn=' + horn + ' back=' + back + ' tail=' + tail + ' mouth=' + mouth);

    const earsVal = ears || horn;
    const eyesVal = eyes || horn;

    const combo = new Map([
      ['body-id', String(colorIdx)],
      ['body',  body ],
      ['back',  back ],
      ['ears',  earsVal],
      ['ear',   earsVal],
      ['eyes',  eyesVal],
      ['horn',  horn ],
      ['mouth', mouth],
      ['tail',  tail ],
    ]);

    log('Building spine for horn=' + horn + ' back=' + back + ' tail=' + tail + ' mouth=' + mouth);
    const result = getAxieSpineFromCombo(combo, colorIdx);
    if (result.error || !result.skeletonDataAsset) {
      const msg = result.error || 'No skeleton';
      log('Spine error: ' + msg);
      hideLoading('Spine error: ' + msg);
      return;
    }
    log('Spine built, variant=' + result.variant);

    const spineJson = result.skeletonDataAsset;
    const variant   = result.variant;
    const shift     = getAxieColorPartShift(variant);

    log('Cleanup: destroying old app/figure/loader/spine');
    // ── Cleanup previous renderer resources ──────────────────────────────────
    // Must destroy in this order: figure → app → loader → atlas/spine
    if (_figure) {
      try { _figure.destroy(true); _figure = null; } catch (e) { log('Figure destroy error: ' + e); }
    }
    if (_app) {
      try { _app.destroy(true); _app = null; } catch (e) { log('App destroy error: ' + e); }
    }
    if (_loader) {
      try { 
        _loader.reset();
        _loader = null;
      } catch (e) { log('Loader reset error: ' + e); }
    }
    if (_spineAtlas) {
      try { _spineAtlas = null; } catch (_) {}
    }
    if (_spineData) {
      try { _spineData = null; } catch (_) {}
    }
    log('Cleanup complete');

    // ── Setup Pixi app ─────────────────────────────────────────────────────────
    log('Setting up Pixi app');
    PIXI.settings.PRECISION_FRAGMENT = PIXI.PRECISION.HIGH;

    const container = document.getElementById('container');
    if (!container) {
      throw new Error('Container element not found');
    }
    
    // Remove old canvas from DOM before creating new one (prevents iOS memory leak)
    if (container && container.firstChild) {
      try { container.removeChild(container.firstChild); } catch (_) {}
    }
    
    const displayW = Number(width);
    const displayH = Number(height);
    const INTERNAL = 400;

    log('Creating Pixi Application: internal=' + INTERNAL + ' display=' + displayW + 'x' + displayH);
    _app = new PIXI.Application({
      transparent:     true,
      backgroundColor: 0,
      width:   INTERNAL,
      height:  INTERNAL,
      resolution:  Math.min(window.devicePixelRatio || 1, 2),
      autoStart:   true,
      antialias:   true,
      autoResize:  false,
    });
    
    _app.view.style.width  = displayW + 'px';
    _app.view.style.height = displayH + 'px';
    
    try {
      container.appendChild(_app.view);
    } catch (e) {
      throw new Error('Failed to append canvas to container: ' + e);
    }
    
    _app.stage.position.set(INTERNAL / 2, INTERNAL * Number(yOff));

    log('Renderer: ' + (_app.renderer.type === 1 ? 'WebGL' : 'Canvas2D'));

    // ── Load textures ─────────────────────────────────────────────────────────
    log('Loading textures...');
    status('Loading textures…');
    const skins = Array.isArray(spineJson.skins) ? spineJson.skins : [{ attachments: spineJson.skins }];
    const preloaded = window.preloadedTextures || {};

    // Collect unique (attPath → url) pairs
    const toLoad = new Map();
    for (const skin of skins) {
      const atts = skin.attachments || skin;
      for (const slotName in atts) {
        for (const attName in atts[slotName]) {
          const att     = atts[slotName][attName];
          const attPath = att.path || attName;
          if (toLoad.has(attPath)) continue;
          const relPath = getVariantAttachmentPath(slotName, attPath, variant, shift);
          const url = preloaded[relPath] || `mixer-stuffs/v3/${relPath}`;
          toLoad.set(attPath, url);
        }
      }
    }
    log('Texture collection: ' + toLoad.size + ' needed, ' + Object.keys(preloaded).length + ' preloaded');

    _loader = new PIXI.loaders.Loader();
    const IMAGE_TYPE = PIXI.loaders.Resource.LOAD_TYPE.IMAGE;
    for (const [attPath, url] of toLoad) {
      _loader.add(attPath, url, { loadType: IMAGE_TYPE });
    }

    log('Starting texture load...');
    await new Promise((resolve, reject) => {
      _loader.load(() => {
        log('Loader callback triggered');
        resolve();
      });
      setTimeout(() => reject(new Error('Texture load timeout (15s)')), 15000);
    });
    log('Texture load complete');

    // ── Build texture map ──────────────────────────────────────────────────────
    const allTextures = {};
    let loadedCount = 0;
    for (const [attPath] of toLoad) {
      const res = _loader.resources[attPath];
      if (res?.texture) { allTextures[attPath] = res.texture; loadedCount++; }
      else if (res?.error) log('Texture fail: ' + attPath + ' → ' + res.error);
    }
    log('Textures loaded: ' + loadedCount + '/' + toLoad.size);

    if (loadedCount === 0) {
      hideLoading('No textures loaded (0/' + toLoad.size + ')');
      return;
    }

    // ── Build spine data ───────────────────────────────────────────────────────
    log('Creating spine atlas...');
    _spineAtlas  = new PIXI.spine.core.TextureAtlas();
    _spineAtlas.addTextureHash(allTextures, false);
    
    log('Creating atlas loader...');
    const atlasLoader = new PIXI.spine.core.AtlasAttachmentLoader(_spineAtlas);
    
    log('Creating spine skeleton data...');
    _spineData   = new PIXI.spine.core.SkeletonJson(atlasLoader).readSkeletonData(spineJson);

    // ── Spawn figure ───────────────────────────────────────────────────────────
    log('Creating spine figure...');
    _figure = new PIXI.spine.Spine(_spineData);
    
    _figure.scale.set(Number(figScale) * Number(scaleMult));
    _figure.stateData.setMix('draft/run-origin',   'action/idle/normal', 0.1);
    _figure.stateData.setMix('action/idle/normal', 'draft/run-origin',   0.2);
    
    const shouldLoop = anim.startsWith('action/idle') || anim.startsWith('action/mix');
    _figure.state.setAnimation(0, anim, shouldLoop);
    if (!shouldLoop) {
      _figure.state.addAnimation(0, 'action/idle/normal', true, 0);
    }

    try { const s = _figure.skeleton.findSlot('shadow'); if (s) s.attachment = null; } catch (_) {}

    log('Adding figure to stage...');
    _app.stage.addChild(_figure);
    log('Render complete');
    hideLoading();

  } catch (err) {
    const msg = err && err.message ? err.message : String(err);
    log('renderPet ERROR: ' + msg);
    if (err && err.stack) {
      log('Error stack: ' + err.stack);
    }
    hideLoading('Render error: ' + msg.substring(0, 80));
    window._renderError = msg;
  }
}

function hideLoading(msg) {
  const el = document.getElementById('loading');
  if (!el) return;
  if (msg) { el.textContent = msg; }
  else      { el.style.display = 'none'; }
}

function status(msg) {
  const el = document.getElementById('loading');
  if (el && el.style.display !== 'none') el.textContent = msg;
  log(msg);
}

// ── Public API (called by Flutter JS bridge) ──────────────────────────────────

window.LikhaPetRenderer = {
  renderFromQuery: async function() {
    const p = new URLSearchParams(window.location.search);
    await renderPet({
      body:      p.get('body')      || 'body-normal',
      horn:      p.get('horn')      || 'beast-04',
      back:      p.get('back')      || 'beast-04',
      tail:      p.get('tail')      || 'beast-04',
      mouth:     p.get('mouth')     || 'beast-04',
      ears:      p.get('ears'),
      eyes:      p.get('eyes'),
      colorIdx:  parseInt(p.get('colorIdx') || '0', 10),
      anim:      p.get('anim')      || 'action/idle/normal',
      figScale:  parseFloat(p.get('figScale') || '0.22'),
      scaleMult: parseFloat(p.get('scaleMult') || '1.0'),
      yOff:      parseFloat(p.get('yOff')     || '0.72'),
      width:     parseInt(p.get('cw') || String(window.innerWidth),  10),
      height:    parseInt(p.get('ch') || String(window.innerHeight), 10),
    });
  },

  playAnimation: function(name, loop) {
    if (!_figure?.state) return;
    // If loop not explicitly provided, determine from animation name
    const shouldLoop = (loop !== undefined) ? loop
        : (name.startsWith('action/idle') || name.startsWith('action/mix'));
    _figure.state.setAnimation(0, name, shouldLoop);
    // One-shot animations queue a return to idle when finished
    if (!shouldLoop) {
      _figure.state.addAnimation(0, 'action/idle/normal', true, 0);
    }
  },

  cleanup: function() {
    // Explicit cleanup for memory management
    if (_figure) {
      try { _figure.destroy(true); _figure = null; } catch (_) {}
    }
    if (_app) {
      try { _app.destroy(true); _app = null; } catch (_) {}
    }
    if (_loader) {
      try { 
        _loader.reset();
        _loader = null;
      } catch (_) {}
    }
    if (_spineAtlas) {
      try { _spineAtlas = null; } catch (_) {}
    }
    if (_spineData) {
      try { _spineData = null; } catch (_) {}
    }
    log('Renderer cleaned up');
  },
};

// ── Bootstrap ─────────────────────────────────────────────────────────────────

let _mixerReady = false;
let _pendingParams = null;

// Expose ready flag so Flutter can poll via runJavaScriptReturningResult.
window._mixerReady = false;
window._renderError = null;

function log(msg) {
  console.log('[Renderer] ' + msg);
  try { if (window.FlutterLog) window.FlutterLog.postMessage(msg); } catch (_) {}
}

// Global error handler to catch uncaught exceptions
window.onerror = function(msg, url, lineNo, colNo, error) {
  const fullMsg = 'UNCAUGHT: ' + msg + ' at ' + url + ':' + lineNo + ':' + colNo;
  log(fullMsg);
  if (error && error.stack) {
    log('Stack: ' + error.stack);
  }
  return false; // Don't suppress the error
};

window.onunhandledrejection = function(event) {
  const fullMsg = 'UNHANDLED PROMISE: ' + (event.reason ? event.reason.toString() : 'unknown');
  log(fullMsg);
  if (event.reason && event.reason.stack) {
    log('Stack: ' + event.reason.stack);
  }
};

window.addEventListener('DOMContentLoaded', async () => {
  try {
    log('DOMContentLoaded — starting initMixer');
    initMixer();
    log('Mixer initialized');
    _mixerReady = true;
    window._mixerReady = true;

    log('Sending RendererReady, channel exists: ' + !!window.RendererReady);
    try {
      if (window.RendererReady) window.RendererReady.postMessage('ready');
    } catch (_) {}

    if (_pendingParams) {
      const p = _pendingParams;
      _pendingParams = null;
      await renderPet(p);
    } else {
      const p = new URLSearchParams(window.location.search);
      if (p.get('horn')) await window.LikhaPetRenderer.renderFromQuery();
    }
  } catch (e) {
    const msg = e && e.message ? e.message : String(e);
    log('INIT FAILED: ' + msg);
    hideLoading('Init failed: ' + msg.substring(0, 80));
    window._renderError = msg;
    try {
      if (window.RendererReady) window.RendererReady.postMessage('error:' + msg);
    } catch (_) {}
  }
});

window.LikhaPetRenderer.render = async function(params) {
  if (!_mixerReady) {
    _pendingParams = params;
    return;
  }
  await renderPet(params);
};
