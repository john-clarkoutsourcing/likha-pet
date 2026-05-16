/**
 * /render — Renders a pet from a bone combo via URL query params.
 *
 * Textures are served from /mixer-stuffs/v3/ (downloaded from Axie CDN)
 * so no internet connection is needed at render time.
 *
 * Query params:
 *   body     body sample  (default: body-normal)
 *   horn     e.g. beast-04
 *   back     e.g. aquatic-06
 *   tail     e.g. plant-04
 *   mouth    e.g. beast-04
 *   ears     defaults to horn sample
 *   eyes     defaults to horn sample
 *   colorIdx color variant index 0-N  (default: class-based)
 *   anim     animation name  (default: action/idle/normal)
 *   figScale Pixi figure scale  (default: 0.18)
 *   yOff     vertical anchor 0-1  (default: 0.72)
 *   cw/ch    canvas width/height in px
 */

import type { NextPage } from 'next'
import { useEffect, useRef } from 'react'

const LOCAL_BASE = '/mixer-stuffs/v3'

const RenderPage: NextPage = () => {
  const containerRef = useRef<HTMLDivElement>(null)
  const appRef       = useRef<any>(null)
  const figureRef    = useRef<any>(null)

  useEffect(() => {
    let destroyed = false

    const run = async () => {
      // ── PIXI + pixi-spine ────────────────────────────────────────────────
      const PIXI: any = (await import('pixi.js')) as any
      PIXI.settings.PRECISION_FRAGMENT = PIXI.PRECISION.HIGH
      require('pixi-spine')

      const {
        initAxieMixer,
        getAxieSpineFromCombo,
        getAxieColorPartShift,
        getVariantAttachmentPath,
      } = await import('@axieinfinity/mixer')

      // ── Load mixer data from /public ─────────────────────────────────────
      const [genes, samples, variants, animations] = await Promise.all([
        fetch('/creature-genes.json').then(r => r.json()),
        fetch('/creature-samples.json').then(r => r.json()),
        fetch('/creature-variants.json').then(r => r.json()),
        fetch('/creature-animations.json').then(r => r.json()),
      ])

      // Shims for mixer ≥ 1.4
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

      // ── Parse URL params ─────────────────────────────────────────────────
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
        ['body-id', String(colorIdx)],
        ['body',    body  ],
        ['back',    back  ],
        ['ears',    ears  ],
        ['ear',     ears  ],
        ['eyes',    eyes  ],
        ['horn',    horn  ],
        ['mouth',   mouth ],
        ['tail',    tail  ],
      ])

      // ── Init Pixi app ────────────────────────────────────────────────────
      const cw = parseInt(p.get('cw') || '0', 10)
      const ch = parseInt(p.get('ch') || '0', 10)
      const w  = cw || containerRef.current.offsetWidth  || window.innerWidth
      const h  = ch || containerRef.current.offsetHeight || window.innerHeight

      const app = new PIXI.Application({
        transparent:     true,
        backgroundColor: 0,
        width: w, height: h,
        resolution:  window.devicePixelRatio || 1,
        autoDensity: true,
        autoStart:   true,
      })
      containerRef.current.appendChild(app.view)
      appRef.current = app

      const yOff = parseFloat(p.get('yOff') || '0.72')
      app.stage.position.set(w / 2, h * yOff)

      // ── Build skeleton from combo ────────────────────────────────────────
      const result = getAxieSpineFromCombo(combo, colorIdx)
      if (result.error || !result.skeletonDataAsset) {
        hideLoading('Error: ' + (result.error || 'No skeleton'))
        return
      }
      const spineJson = result.skeletonDataAsset
      const variant   = result.variant   // e.g. 'beast-03'

      // ── Load textures from LOCAL /mixer-stuffs/v3/ ───────────────────────
      // Each texture is a PNG downloaded from the CDN with correct class colors.
      // Path is computed by getVariantAttachmentPath() — same logic the CDN uses.
      const shift = getAxieColorPartShift(variant)
      const loader = new PIXI.loaders.Loader()

      const skins = Array.isArray(spineJson.skins)
        ? spineJson.skins
        : [{ attachments: spineJson.skins }]

      for (const skin of skins) {
        const atts = skin.attachments || skin
        for (const slotName in atts) {
          for (const attName in atts[slotName]) {
            const att      = atts[slotName][attName]
            const attPath  = att.path || attName
            const relPath  = getVariantAttachmentPath(slotName, attPath, variant, shift)
            const localUrl = `${LOCAL_BASE}/${relPath}`
            if (!loader.resources[attPath]) {
              loader.add(attPath, localUrl)
            }
          }
        }
      }

      await new Promise<void>(resolve => loader.load(() => resolve()))
      if (destroyed) return

      // ── Build PIXI texture map ────────────────────────────────────────────
      const allTextures: Record<string, any> = {}
      for (const skin of skins) {
        const atts = skin.attachments || skin
        for (const slotName in atts) {
          for (const attName in atts[slotName]) {
            const att     = atts[slotName][attName]
            const attPath = att.path || attName
            const res     = loader.resources[attPath]
            if (res?.texture) allTextures[attPath] = res.texture
          }
        }
      }

      const spineAtlas  = new PIXI.spine.core.TextureAtlas()
      spineAtlas.addTextureHash(allTextures, false)
      const atlasLoader = new PIXI.spine.core.AtlasAttachmentLoader(spineAtlas)
      const spineData   = new PIXI.spine.core.SkeletonJson(atlasLoader).readSkeletonData(spineJson)

      if (destroyed) return

      // ── Spawn figure ─────────────────────────────────────────────────────
      const figure     = new PIXI.spine.Spine(spineData)
      const figScale   = parseFloat(p.get('figScale') || '0.18')
      const scaleMult  = parseFloat(p.get('scaleMult') || '1.0')
      figure.scale.set(figScale * scaleMult)
      figure.stateData.setMix('draft/run-origin',   'action/idle/normal', 0.1)
      figure.stateData.setMix('action/idle/normal', 'draft/run-origin',   0.2)
      figure.state.setAnimation(0, anim, true)

      // Hide shadow slot
      try { const s = figure.skeleton.findSlot('shadow'); if (s) s.attachment = null } catch (_) {}

      app.stage.addChild(figure)
      figureRef.current = figure
      hideLoading()

      // ── JS bridge for Flutter ────────────────────────────────────────────
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
