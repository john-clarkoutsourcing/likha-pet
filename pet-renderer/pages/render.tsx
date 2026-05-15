/**
 * /render — Renders a pet from a bone combo via URL query params.
 *
 * Uses the LOCAL atlas (axie-2d-v3-stuff.png) instead of Axie's CDN.
 * All assets are self-hosted — no internet connection required after first load.
 *
 * Query params:
 *   body     body sample (default: body-normal)
 *   horn     e.g. beast-04
 *   back     e.g. aquatic-06
 *   tail     e.g. plant-04
 *   mouth    e.g. beast-04
 *   ears     e.g. beast-04  (defaults to same sample as horn)
 *   eyes     e.g. beast-04  (defaults to same sample as horn)
 *   colorIdx color variant index 0-N (default 0)
 *   anim     animation name (default: action/idle/normal)
 *   figScale figure scale  (default: 0.18)
 *   scaleMult scale multiplier to apply on top of figScale (default: 1.0)
 *   yOff     vertical anchor 0-1 (default: 0.72)
 *   cw/ch    canvas width/height in px
 */

import type { NextPage } from 'next'
import { useEffect, useRef } from 'react'

// ── Atlas region parser ───────────────────────────────────────────────────────

interface AtlasRegion {
  x: number; y: number; width: number; height: number
}

function parseAtlas(src: string): Map<string, AtlasRegion> {
  const map = new Map<string, AtlasRegion>()
  const lines = src.split('\n')
  let i = 0
  while (i < lines.length) {
    const line = lines[i].trimEnd()
    if (
      line.length > 0 &&
      !line.startsWith(' ') &&
      !line.startsWith('\t') &&
      !line.includes(':') &&
      !line.endsWith('.png') &&
      !line.endsWith('.jpg')
    ) {
      const name = line.trim()
      const props: Record<string, string> = {}
      i++
      while (i < lines.length && (lines[i].startsWith(' ') || lines[i].startsWith('\t'))) {
        const idx = lines[i].indexOf(':')
        if (idx > 0) {
          props[lines[i].slice(0, idx).trim()] = lines[i].slice(idx + 1).trim()
        }
        i++
      }
      const [rx, ry] = (props['xy'] || '0, 0').split(',').map(s => parseInt(s.trim(), 10))
      const [rw, rh] = (props['size'] || '0, 0').split(',').map(s => parseInt(s.trim(), 10))
      map.set(name, { x: rx, y: ry, width: rw, height: rh })
    } else {
      i++
    }
  }
  return map
}

// ── Crop a region from the atlas into a data URL using Canvas ─────────────────

function cropToDataUrl(atlasImg: HTMLImageElement, r: AtlasRegion): string {
  const c = document.createElement('canvas')
  c.width  = r.width
  c.height = r.height
  const ctx = c.getContext('2d')!
  ctx.drawImage(atlasImg, r.x, r.y, r.width, r.height, 0, 0, r.width, r.height)
  return c.toDataURL('image/png')
}

// ── Build PIXI texture map from local atlas ───────────────────────────────────
// Returns { attachmentPath: dataUrl } for every skin attachment in the spine JSON.

function buildTextureMap(
  spineJson: any,
  atlasRegions: Map<string, AtlasRegion>,
  atlasImg: HTMLImageElement
): Record<string, string> {
  const map: Record<string, string> = {}
  const skins = spineJson.skins
  for (const skin of skins) {
    for (const slotName in skin.attachments) {
      for (const attName in skin.attachments[slotName]) {
        const att  = skin.attachments[slotName][attName]
        let path = att.path || attName
        if (map[path]) continue
        
        let region = atlasRegions.get(path)
        
        // Fallback 1: if beast-00 part not found, try beast-04
        if (!region && path.includes('beast-00')) {
          const fallbackPath = path.replace('beast-00', 'beast-04')
          region = atlasRegions.get(fallbackPath)
          if (region) console.log(`[buildTextureMap] Using ${fallbackPath} for ${path}`)
        }
        
        // Fallback 2: if beast body part not found, use body-normal equivalent
        if (!region && path.match(/^beast-\d+\.body/)) {
          const fallbackPath = path.replace(/beast-\d+/, 'body-normal')
          region = atlasRegions.get(fallbackPath)
          if (region) console.log(`[buildTextureMap] Using ${fallbackPath} for ${path}`)
        }
        
        if (region) map[path] = cropToDataUrl(atlasImg, region)
      }
    }
  }
  return map
}

// ── Page ──────────────────────────────────────────────────────────────────────

const RenderPage: NextPage = () => {
  const containerRef = useRef<HTMLDivElement>(null)
  const appRef       = useRef<any>(null)
  const figureRef    = useRef<any>(null)

  useEffect(() => {
    let destroyed = false

    const run = async () => {
      // ── PIXI + pixi-spine (browser-only dynamic imports) ───────────────
      const PIXI: any = (await import('pixi.js')) as any
      PIXI.settings.PRECISION_FRAGMENT = PIXI.PRECISION.HIGH
      require('pixi-spine')

      const { initAxieMixer, getAxieSpineFromCombo, getAxieSpineFromGenes } = await import('@axieinfinity/mixer')

      // ── Mixer data (local JSON — served by Next.js from /public) ───────
      const [genes, samples, variants, animations] = await Promise.all([
        fetch('/creature-genes.json').then(r => r.json()),
        fetch('/creature-samples.json').then(r => r.json()),
        fetch('/creature-variants.json').then(r => r.json()),
        fetch('/creature-animations.json').then(r => r.json()),
      ])

      // Shims required by mixer ≥ 1.4
      if (genes?.items?.parts) {
        genes.items.parts = genes.items.parts.map((p: any) => ({
          ...p, skinsLv2: p.skinsLv2 ?? [],
        }))
      }
      if (genes?.items && !genes.items.bodies) {
        genes.items.bodies = [{ skin: 0, bodyValue: -1, mysticValue: -1, bodyName: 'body-normal' }]
      }

      initAxieMixer(genes, samples, variants, animations)
      if (destroyed || !containerRef.current) return

      // ── URL params ─────────────────────────────────────────────────────
      const p        = new URLSearchParams(window.location.search)
      const body     = p.get('body')     || 'body-normal'
      const colorIdx = parseInt(p.get('colorIdx') || '0', 10)
      const anim     = p.get('anim')     || 'action/idle/normal'
      const horn     = p.get('horn')     || 'beast-04'
      const back     = p.get('back')     || 'beast-04'
      const tail     = p.get('tail')     || 'beast-04'
      const mouth    = p.get('mouth')    || 'beast-04'
      const ears     = p.get('ears')     || horn
      const eyes     = p.get('eyes')     || horn

      const combo = new Map<string, string>([
        ['body-id', p.get('bodyId') || '4'],  // Use bodyValue 4 by default
        ['body',    body ],
        ['back',    back ],
        ['ears',    ears ],
        ['ear',     ears ],
        ['eyes',    eyes ],
        ['horn',    horn ],
        ['mouth',   mouth],
        ['tail',    tail ],
        ['class',   'beast'],  // Explicitly set class to beast
      ])

      // ── Pixi app ───────────────────────────────────────────────────────
      const cw = parseInt(p.get('cw') || '0', 10)
      const ch = parseInt(p.get('ch') || '0', 10)
      const w  = cw || containerRef.current.offsetWidth  || window.innerWidth
      const h  = ch || containerRef.current.offsetHeight || window.innerHeight

      const app = new PIXI.Application({
        transparent: true,
        backgroundColor: 0,
        width: w, height: h,
        resolution: window.devicePixelRatio || 1,
        autoDensity: true,
        autoStart: true,
      })
      containerRef.current.appendChild(app.view)
      appRef.current = app

      const yOff = parseFloat(p.get('yOff') || '0.72')
      app.stage.position.set(w / 2, h * yOff)

      // Try using DNA if provided, otherwise fall back to combo
      const dna = p.get('dna')
      let result: any
      
      if (dna && dna.length === 24) {
        const metaMap = new Map<string, string>([['name', 'test']])
        result = getAxieSpineFromGenes(dna, metaMap)
      } else {
        result = getAxieSpineFromCombo(combo, colorIdx)
      }

      
      if (result.error || !result.skeletonDataAsset) {
        console.error('Mixer error:', result.error || 'No skeletonDataAsset')
        hideLoading('Error: ' + (result.error || 'Invalid skeleton'))
        return
      }
      const spineJson = result.skeletonDataAsset
      
      // DEBUG: Log skeleton bones and slots

      
      // DEBUG: Log actual attachment paths in skeleton
      const skins = spineJson?.skins || []
      const allPaths = new Set()
      skins.forEach((skin: any) => {
        Object.entries(skin.attachments || {}).forEach(([slotName, attachments]: any) => {
          Object.entries(attachments || {}).forEach(([attName, att]: any) => {
            const path = att?.path || attName
            allPaths.add(path)
            if (slotName === 'body' || slotName === 'eyes' || slotName === 'mouth' || slotName === 'horn' || slotName === 'back') {
              console.log(`  [${slotName}] ${attName} -> path: "${path}"`)
            }
          })
        })
      })

      // ── Load LOCAL atlas — zero CDN dependency ─────────────────────────
      // 1. Fetch the combined 4096×4096 atlas PNG + its metadata from our own server
      // 2. Parse metadata to get pixel coords of every region
      // 3. Crop each region the skeleton actually uses using <canvas>
      // 4. Feed data URLs directly to PIXI — no external requests
      const [atlasText, atlasImg] = await Promise.all([
        fetch('/axie-2d-v3-stuff.atlas').then(r => r.text()),
        new Promise<HTMLImageElement>((resolve, reject) => {
          const img = new Image()
          img.crossOrigin = 'anonymous'
          img.onload  = () => resolve(img)
          img.onerror = (e) => reject(e)
          img.src = '/axie-2d-v3-stuff.png'
        }),
      ])
      if (destroyed) return

      const atlasRegions = parseAtlas(atlasText)
      const texMap = buildTextureMap(spineJson, atlasRegions, atlasImg)
      
      // Log texture paths for body, legs, eyes, mouth
      Object.keys(texMap).forEach(path => {
        if (path.includes('body') || path.includes('leg') || path.includes('eye') || path.includes('mouth')) {
          console.log(`  Texture: ${path}`)
        }
      })

      // ── Build PIXI texture atlas ───────────────────────────────────────
      const allTextures: Record<string, any> = {}
      for (const [path, dataUrl] of Object.entries(texMap)) {
        allTextures[path] = PIXI.Texture.from(dataUrl)
      }
      const spineAtlas  = new PIXI.spine.core.TextureAtlas()
      spineAtlas.addTextureHash(allTextures, false)
      const atlasLoader = new PIXI.spine.core.AtlasAttachmentLoader(spineAtlas)
      const spineData   = new PIXI.spine.core.SkeletonJson(atlasLoader).readSkeletonData(spineJson)

      if (destroyed) return

      // ── Spawn animated figure ──────────────────────────────────────────
      const figure = new PIXI.spine.Spine(spineData)
      const figScale = parseFloat(p.get('figScale') || '0.18')
      const scaleMult = parseFloat(p.get('scaleMult') || '1.0')  // NEW: scale multiplier
      figure.scale.set(figScale * scaleMult)  // Apply both scale and multiplier
      figure.stateData.setMix('draft/run-origin',   'action/idle/normal', 0.1)
      figure.stateData.setMix('action/idle/normal', 'draft/run-origin',   0.2)
      figure.state.setAnimation(0, anim, true)

      // CRITICAL: Ensure skin is set (mixer may not set default skin)
      if (spineData.skins && spineData.skins.length > 0) {
        const firstSkin = spineData.skins[0]
        figure.skeleton.setSkinByName(firstSkin.name)
        console.log(`[Renderer] Set skin: ${firstSkin.name}`)
      }

      // Update skeleton transforms after setting skin
      figure.skeleton.updateWorldTransform()

      // DEBUG: Log bone transforms
      figure.skeleton.bones.forEach((bone: any) => {
        if (bone.data.name.includes('body') || bone.data.name.includes('leg') || bone.data.name.includes('eye') || bone.data.name.includes('mouth')) {
          console.log(`  ${bone.data.name}: scale=[${bone.scaleX.toFixed(2)}, ${bone.scaleY.toFixed(2)}], pos=[${bone.x.toFixed(1)}, ${bone.y.toFixed(1)}]`)
        }
      })

      // Hide ground shadow slot
      try { const s = figure.skeleton.findSlot('shadow'); if (s) s.attachment = null } catch (_) {}

      app.stage.addChild(figure)
      figureRef.current = figure
      hideLoading()

      // ── Flutter JS bridge ──────────────────────────────────────────────
      ;(window as any).playAnimation = (name: string, loop = true) => {
        figureRef.current?.state?.setAnimation(0, name, loop)
      }
    }

    function hideLoading(msg?: string) {
      const el = document.getElementById('loading')
      if (!el) return
      if (msg) { el.textContent = msg } else { el.style.display = 'none' }
    }

    run().catch(e => {
      console.error('render failed:', e)
      const el = document.getElementById('loading')
      if (el) el.textContent = 'Failed to load'
    })

    return () => {
      destroyed = true
      appRef.current?.destroy(true)
      appRef.current = null
    }
  }, [])

  return (
    <>
      <style>{`
        * { margin:0; padding:0; box-sizing:border-box }
        html,body { width:100%; height:100%; overflow:hidden; background:transparent }
        #container { width:100vw; height:100vh }
        #loading {
          position:fixed; inset:0;
          display:flex; align-items:center; justify-content:center;
          color:rgba(255,255,255,.5);
          font:13px -apple-system,sans-serif;
          pointer-events:none
        }
      `}</style>
      <div id="container" ref={containerRef} />
      <div id="loading">Loading pet…</div>
    </>
  )
}

export default RenderPage
