/**
 * download-assets.js
 *
 * Downloads all texture PNGs needed by our game from Axie's CDN.
 * Saves them to public/mixer-stuffs/v3/ so the renderer can use
 * local files instead of hitting the CDN on every load.
 *
 * Run once: node scripts/download-assets.js
 *
 * What it downloads:
 *   - body-normal.body (the base body silhouette)
 *   - All class-colored body.body variants
 *   - All horn/back/tail/mouth/ear/eye parts for our 36 part samples
 *   - Each part colored for the 6 body class variants
 *   - Leg, shadow, ball and other skeleton parts
 */

const fs   = require('fs');
const path = require('path');
const https = require('https');

const {
  initAxieMixer,
  getAxieSpineFromCombo,
  getAxieColorPartShift,
  getVariantAttachmentPath,
} = require('@axieinfinity/mixer');

const CDN_BASE  = 'https://axiecdn.axieinfinity.com/mixer-stuffs/v3';
const OUT_DIR   = path.join(__dirname, '..', 'public', 'mixer-stuffs', 'v3');
const DATA_DIR  = path.join(__dirname, '..', 'public');

// ── Part samples our kPartCatalogue uses ────────────────────────────────────
// horn/back/tail: 6 variants × 6 classes = 36
// mouth: 4 variants × 6 classes = 24
const CLASSES   = ['beast', 'plant', 'aquatic', 'reptile', 'bird', 'bug'];
const HBT_VARS  = ['02', '04', '06', '08', '10', '12'];
const MOUTH_VARS = ['02', '04', '08', '10'];

// Body class → colorIdx mapping (one representative color per class)
const CLASS_COLOR_IDX = {
  beast:   3,
  plant:   6,
  aquatic: 12,
  reptile: 18,
  bird:    24,
  bug:     30,
};

// ── Helpers ──────────────────────────────────────────────────────────────────

function ensureDir(dir) {
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
}

function download(url, dest) {
  return new Promise((resolve, reject) => {
    if (fs.existsSync(dest)) { resolve('skipped'); return; }
    ensureDir(path.dirname(dest));
    const file = fs.createWriteStream(dest);
    https.get(url, (res) => {
      if (res.statusCode === 301 || res.statusCode === 302) {
        file.close();
        fs.unlinkSync(dest);
        download(res.headers.location, dest).then(resolve).catch(reject);
        return;
      }
      if (res.statusCode !== 200) {
        file.close();
        fs.unlinkSync(dest);
        resolve(`skip-${res.statusCode}`);
        return;
      }
      res.pipe(file);
      file.on('finish', () => { file.close(); resolve('ok'); });
    }).on('error', (e) => {
      if (fs.existsSync(dest)) fs.unlinkSync(dest);
      reject(e);
    });
  });
}

// Collect all texture URLs for a given bone combo + color index
function collectUrls(spineJson, variant) {
  const partColorShift = getAxieColorPartShift(variant);
  const urls = new Map(); // relativePath → url

  const skins = Array.isArray(spineJson.skins) ? spineJson.skins : [{ attachments: spineJson.skins }];
  for (const skin of skins) {
    const attachments = skin.attachments || skin;
    for (const slotName in attachments) {
      const slotAtts = attachments[slotName];
      for (const attName in slotAtts) {
        const att = slotAtts[attName];
        const attachPath = att.path || attName;
        const relativePath = getVariantAttachmentPath(slotName, attachPath, variant, partColorShift);
        if (!urls.has(relativePath)) {
          urls.set(relativePath, `${CDN_BASE}/${relativePath}`);
        }
      }
    }
  }
  return urls;
}

// ── Main ─────────────────────────────────────────────────────────────────────

async function main() {
  console.log('Loading mixer data…');

  // Load JSON data files
  const genes      = JSON.parse(fs.readFileSync(path.join(DATA_DIR, 'creature-genes.json'), 'utf8'));
  const samples    = JSON.parse(fs.readFileSync(path.join(DATA_DIR, 'creature-samples.json'), 'utf8'));
  const variants   = JSON.parse(fs.readFileSync(path.join(DATA_DIR, 'creature-variants.json'), 'utf8'));
  const animations = JSON.parse(fs.readFileSync(path.join(DATA_DIR, 'creature-animations.json'), 'utf8'));

  // Apply shims
  if (genes?.items?.parts) {
    genes.items.parts = genes.items.parts.map(p => ({ ...p, skinsLv2: p.skinsLv2 ?? [] }));
  }
  if (genes?.items && !genes.items.bodies) {
    genes.items.bodies = [{ skin: 0, bodyValue: -1, mysticValue: -1, bodyName: 'body-normal' }];
  }

  initAxieMixer(genes, samples, variants, animations);
  console.log('Mixer initialized.');

  // Collect all unique URLs
  const allUrls = new Map();

  // For each body class, generate combos covering all part samples we use
  for (const bodyClass of CLASSES) {
    const colorIdx = CLASS_COLOR_IDX[bodyClass];

    // Test with a representative combo per class — this generates all shared
    // assets (body, legs, shadow, ball, eyes, ears for this class)
    for (const hornV of HBT_VARS) {
      for (const backV of HBT_VARS) {
        // Use one tail and mouth combo (other variants share same slot textures)
        const combo = new Map([
          ['body-id', String(colorIdx)],
          ['body',    'body-normal'],
          ['horn',    `${bodyClass}-${hornV}`],
          ['back',    `${bodyClass}-${backV}`],
          ['tail',    `${bodyClass}-04`],
          ['mouth',   `${bodyClass}-04`],
          ['ears',    `${bodyClass}-04`],
          ['ear',     `${bodyClass}-04`],
          ['eyes',    `${bodyClass}-04`],
        ]);

        const result = getAxieSpineFromCombo(combo, colorIdx);
        if (result.error) continue;

        const urls = collectUrls(result.skeletonDataAsset, result.variant);
        for (const [rel, url] of urls) allUrls.set(rel, url);
      }
    }

    // Also generate tail variants
    for (const tailV of HBT_VARS) {
      const combo = new Map([
        ['body-id', String(colorIdx)],
        ['body',    'body-normal'],
        ['horn',    `${bodyClass}-04`],
        ['back',    `${bodyClass}-04`],
        ['tail',    `${bodyClass}-${tailV}`],
        ['mouth',   `${bodyClass}-04`],
        ['ears',    `${bodyClass}-04`],
        ['ear',     `${bodyClass}-04`],
        ['eyes',    `${bodyClass}-04`],
      ]);
      const result = getAxieSpineFromCombo(combo, colorIdx);
      if (!result.error) {
        const urls = collectUrls(result.skeletonDataAsset, result.variant);
        for (const [rel, url] of urls) allUrls.set(rel, url);
      }
    }

    // Mouth variants
    for (const mouthV of MOUTH_VARS) {
      const combo = new Map([
        ['body-id', String(colorIdx)],
        ['body',    'body-normal'],
        ['horn',    `${bodyClass}-04`],
        ['back',    `${bodyClass}-04`],
        ['tail',    `${bodyClass}-04`],
        ['mouth',   `${bodyClass}-${mouthV}`],
        ['ears',    `${bodyClass}-04`],
        ['ear',     `${bodyClass}-04`],
        ['eyes',    `${bodyClass}-04`],
      ]);
      const result = getAxieSpineFromCombo(combo, colorIdx);
      if (!result.error) {
        const urls = collectUrls(result.skeletonDataAsset, result.variant);
        for (const [rel, url] of urls) allUrls.set(rel, url);
      }
    }

    // Cross-class parts (hybrid pets) — all other class variants on this body
    for (const partClass of CLASSES) {
      if (partClass === bodyClass) continue;
      for (const v of HBT_VARS) {
        const combo = new Map([
          ['body-id', String(colorIdx)],
          ['body',    'body-normal'],
          ['horn',    `${partClass}-${v}`],
          ['back',    `${bodyClass}-04`],
          ['tail',    `${bodyClass}-04`],
          ['mouth',   `${bodyClass}-04`],
          ['ears',    `${bodyClass}-04`],
          ['ear',     `${bodyClass}-04`],
          ['eyes',    `${bodyClass}-04`],
        ]);
        const result = getAxieSpineFromCombo(combo, colorIdx);
        if (!result.error) {
          const urls = collectUrls(result.skeletonDataAsset, result.variant);
          for (const [rel, url] of urls) allUrls.set(rel, url);
        }
      }
    }
  }

  console.log(`\nTotal unique textures to download: ${allUrls.size}`);
  ensureDir(OUT_DIR);

  // Download all
  let done = 0, skipped = 0, failed = 0;
  const total = allUrls.size;

  for (const [relativePath, url] of allUrls) {
    const dest = path.join(OUT_DIR, ...relativePath.split('/'));
    try {
      const result = await download(url, dest);
      if (result === 'skipped') skipped++;
      else done++;
      if ((done + skipped + failed) % 50 === 0) {
        process.stdout.write(`\r  ${done + skipped + failed}/${total} (${done} new, ${skipped} cached, ${failed} failed)`);
      }
    } catch (e) {
      failed++;
      // Silently skip failures (some parts may not exist on CDN)
    }
  }

  console.log(`\n\nDone!  ${done} downloaded, ${skipped} already cached, ${failed} not found.`);
  console.log(`Assets saved to: ${OUT_DIR}`);
}

main().catch(console.error);
