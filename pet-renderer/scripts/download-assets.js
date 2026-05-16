/**
 * download-assets.js
 *
 * Downloads all texture PNGs for our game from Axie's CDN.
 * Uses Node 18+ native fetch (HTTP/2) which the CDN accepts.
 * Saves to public/mixer-stuffs/v3/ for fully offline operation.
 *
 * Run once: node scripts/download-assets.js
 */

const fs   = require('fs');
const path = require('path');

const {
  initAxieMixer,
  getAxieSpineFromCombo,
  getAxieColorPartShift,
  getVariantAttachmentPath,
} = require('@axieinfinity/mixer');

const CDN_BASE = 'https://axiecdn.axieinfinity.com/mixer-stuffs/v3';
const OUT_DIR  = path.join(__dirname, '..', 'public', 'mixer-stuffs', 'v3');
const DATA_DIR = path.join(__dirname, '..', 'public');

const CLASSES    = ['beast', 'plant', 'aquatic', 'reptile', 'bird', 'bug'];
const HBT_VARS   = ['02', '04', '06', '08', '10', '12'];
const MOUTH_VARS = ['02', '04', '08', '10'];

const CLASS_COLOR_IDX = {
  beast: 3, plant: 6, aquatic: 12, reptile: 18, bird: 24, bug: 30,
};

// ── Helpers ───────────────────────────────────────────────────────────────────

function ensureDir(dir) {
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
}

async function downloadFile(url, dest) {
  if (fs.existsSync(dest)) return 'cached';
  ensureDir(path.dirname(dest));
  try {
    const res = await fetch(url);
    if (!res.ok) return `skip-${res.status}`;
    const buf = Buffer.from(await res.arrayBuffer());
    fs.writeFileSync(dest, buf);
    return 'ok';
  } catch (e) {
    return 'error';
  }
}

function collectUrls(spineJson, variant) {
  const shift = getAxieColorPartShift(variant);
  const urls  = new Map();
  const skins = Array.isArray(spineJson.skins) ? spineJson.skins : [{ attachments: spineJson.skins }];
  for (const skin of skins) {
    const atts = skin.attachments || skin;
    for (const slotName in atts) {
      for (const attName in atts[slotName]) {
        const att  = atts[slotName][attName];
        const aPath = att.path || attName;
        const rel  = getVariantAttachmentPath(slotName, aPath, variant, shift);
        if (!urls.has(rel)) urls.set(rel, `${CDN_BASE}/${rel}`);
      }
    }
  }
  return urls;
}

function makeCombo(bodyClass, colorIdx, hornSample, backSample, tailSample, mouthSample) {
  const ears = `${bodyClass}-04`;
  return new Map([
    ['body-id', String(colorIdx)],
    ['body',  'body-normal'],
    ['horn',  hornSample],
    ['back',  backSample],
    ['tail',  tailSample],
    ['mouth', mouthSample],
    ['ears',  ears],
    ['ear',   ears],
    ['eyes',  ears],
  ]);
}

// ── Main ──────────────────────────────────────────────────────────────────────

async function main() {
  console.log('Loading mixer data…');
  const genes      = JSON.parse(fs.readFileSync(path.join(DATA_DIR, 'creature-genes.json'), 'utf8'));
  const samples    = JSON.parse(fs.readFileSync(path.join(DATA_DIR, 'creature-samples.json'), 'utf8'));
  const variants   = JSON.parse(fs.readFileSync(path.join(DATA_DIR, 'creature-variants.json'), 'utf8'));
  const animations = JSON.parse(fs.readFileSync(path.join(DATA_DIR, 'creature-animations.json'), 'utf8'));

  if (genes?.items?.parts) {
    genes.items.parts = genes.items.parts.map(p => ({ ...p, skinsLv2: p.skinsLv2 ?? [] }));
  }
  if (genes?.items && !genes.items.bodies) {
    genes.items.bodies = [{ skin: 0, bodyValue: -1, mysticValue: -1, bodyName: 'body-normal' }];
  }
  initAxieMixer(genes, samples, variants, animations);
  console.log('Mixer initialized.\n');

  const allUrls = new Map();

  function addCombo(combo, colorIdx) {
    const result = getAxieSpineFromCombo(combo, colorIdx);
    if (result.error) return;
    for (const [rel, url] of collectUrls(result.skeletonDataAsset, result.variant)) {
      allUrls.set(rel, url);
    }
  }

  // Collect all texture URLs for every combination we use
  for (const bodyClass of CLASSES) {
    const colorIdx = CLASS_COLOR_IDX[bodyClass];
    const base     = `${bodyClass}-04`;

    // 1. All horn × back variants for this body class (generates body/leg/eye assets)
    for (const hv of HBT_VARS) {
      for (const bv of HBT_VARS) {
        addCombo(makeCombo(bodyClass, colorIdx, `${bodyClass}-${hv}`, `${bodyClass}-${bv}`, base, base), colorIdx);
      }
    }
    // 2. All tail variants
    for (const tv of HBT_VARS) {
      addCombo(makeCombo(bodyClass, colorIdx, base, base, `${bodyClass}-${tv}`, base), colorIdx);
    }
    // 3. All mouth variants
    for (const mv of MOUTH_VARS) {
      addCombo(makeCombo(bodyClass, colorIdx, base, base, base, `${bodyClass}-${mv}`), colorIdx);
    }
    // 4. Cross-class parts on this body (hybrid combos)
    for (const partClass of CLASSES) {
      if (partClass === bodyClass) continue;
      for (const v of HBT_VARS) {
        addCombo(makeCombo(bodyClass, colorIdx, `${partClass}-${v}`, base, base, base), colorIdx);
        addCombo(makeCombo(bodyClass, colorIdx, base, `${partClass}-${v}`, base, base), colorIdx);
        addCombo(makeCombo(bodyClass, colorIdx, base, base, `${partClass}-${v}`, base), colorIdx);
      }
      for (const v of MOUTH_VARS) {
        addCombo(makeCombo(bodyClass, colorIdx, base, base, base, `${partClass}-${v}`), colorIdx);
      }
    }
  }

  const total = allUrls.size;
  console.log(`Total unique textures: ${total}`);
  ensureDir(OUT_DIR);

  let done = 0, cached = 0, failed = 0;
  for (const [rel, url] of allUrls) {
    const dest = path.join(OUT_DIR, ...rel.split('/'));
    const res  = await downloadFile(url, dest);
    if (res === 'ok')     done++;
    else if (res === 'cached') cached++;
    else                  failed++;
    const n = done + cached + failed;
    if (n % 25 === 0) process.stdout.write(`\r  ${n}/${total}  (${done} new, ${cached} cached, ${failed} failed)`);
  }

  console.log(`\n\nDone!`);
  console.log(`  ${done} downloaded, ${cached} already cached, ${failed} not found`);
  console.log(`  Saved to: ${OUT_DIR}`);
}

main().catch(console.error);
