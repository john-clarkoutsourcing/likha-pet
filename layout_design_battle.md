# Battle Scene Layout Breakdown (For Graphic Artist)

## Overall Style
- Cute/cartoon fantasy battle arena
- Bright pastel palette
- Soft shadows and rounded UI
- Mobile-first landscape orientation
- Inspired by creature battlers like Axie-style games

---

# SCREEN STRUCTURE

The screen is divided into **5 main zones**:

---

# 1. TOP HUD BAR

Located across the entire top width.

## Left Side — Player Info Panel
- Wooden signboard style container
- Displays:
  - Username / Team name
  - Possibly guild or status text
- Rounded cartoon wood texture
- Slight drop shadow

## Center — Turn Order Timeline
Horizontal initiative tracker.

Contains:
- “Round 1” text
- Small creature icons in sequence
- Number overlays indicating turn order
- Current active turn highlighted larger

Purpose:
- Shows attack order for all units

## Right Side — Utility Icons
Small circular buttons:
- Settings gear icon
- Card/deck icon with remaining count

Spacing:
- Floating independently with minimal frame

---

# 2. BATTLEFIELD AREA (CENTER)

Largest section of screen.

## Background
Beach/desert fantasy ruins.

Contains:
- Broken stone arches
- Ancient statue face
- Sandy arena floor
- Blue sky gradient
- Atmospheric depth blur

## Character Placement

Two teams facing each other:
- Left team faces right
- Right team faces left

Formation:
- 3 units front/back arrangement
- Slight perspective staggering

## Character Style
- Chubby circular creatures
- Minimal limbs
- Large expressive eyes
- Each unit themed by element/color

Examples:
- Pink healer/support
- White cat-like attacker
- Purple tank/debuffer
- Blue aquatic unit
- Yellow plant support
- Dark fluffy tank

---

# 3. UNIT HUD ELEMENTS

Every creature has floating UI above them.

## Health Bar
- Horizontal green/yellow bar
- HP number beside icon
- Rounded capsule style

## Class/Role Icon
Small colored symbol:
- Paw
- Shield
- Crown
- Heart

Used for:
- Type/class identification

## Status Indicators
Potential buffs/debuffs:
- Shield
- Poison
- Silence
- Mark
- Heal

Should float compactly near HP bar.

---

# 4. BOTTOM ACTION/CARD AREA

Main gameplay interaction zone.

## Left Corner — Energy Counter
Circular orange orb UI.

Displays:
- Current energy
- Max energy

Example:
“3/10”

## Center Bottom — Ability Cards

Cards are spread horizontally.

### Card Anatomy
- Colored frame by class/type
- Large artwork illustration
- Energy cost top-left
- Attack/defense values bottom
- Ability description text
- Unit ownership marker at bottom

### Card Types Seen
- Attack
- Debuff
- Status effects
- Disable/silence

### Card Design Style
- Rounded corners
- Cartoon fantasy
- Thick outlines
- High readability

---

# 5. BOTTOM RIGHT — END TURN BUTTON

Large CTA button.

## Style
- Bright orange/yellow
- Rounded rectangle
- Glossy cartoon finish

Contains:
- Crossed swords icon
- “End Turn” text

Should visually stand out strongly.

---

# UX / VISUAL HIERARCHY

Priority order:
1. Active battlefield
2. Turn order
3. Cards
4. HP bars
5. Secondary controls

The player eye flow should go:
Turn Order → Battlefield → Cards → End Turn

---

# SPACING & COMPOSITION

## Top Area
~15% of screen height

## Battlefield
~60% of screen height

## Bottom Card Area
~25% of screen height

---

# ANIMATION SUGGESTIONS

## Units
- Idle bounce
- Blink animation
- Small squash/stretch

## UI
- HP bars smoothly drain
- Cards glow on hover
- Active turn icon pulses

## Combat
- Damage numbers pop upward
- Shake effect on hit
- Small particles per class element

---

# ART DIRECTION NOTES

## Use:
- Thick outlines
- Saturated colors
- Soft gradients
- Playful proportions
- Minimal realism

## Avoid:
- Sharp realistic textures
- Thin typography
- Dark gritty palette
- Overly complex backgrounds

---

# LAYERING ORDER

Background Ruins  
→ Arena Ground  
→ Shadows  
→ Characters  
→ HP/UI Above Units  
→ Top HUD  
→ Bottom Cards  
→ Floating FX/Particles  
→ Modal/Settings Layer