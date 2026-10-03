---
name: Serene Hearth
colors:
  surface: '#edfdf6'
  surface-dim: '#cdded7'
  surface-bright: '#edfdf6'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#e7f7f0'
  surface-container: '#e1f2eb'
  surface-container-high: '#dbece5'
  surface-container-highest: '#d6e6df'
  on-surface: '#101e1a'
  on-surface-variant: '#3e4945'
  inverse-surface: '#25332f'
  inverse-on-surface: '#e4f4ed'
  outline: '#6f7975'
  outline-variant: '#bec9c4'
  surface-tint: '#066b59'
  primary: '#005445'
  on-primary: '#ffffff'
  primary-container: '#0e6e5c'
  on-primary-container: '#9bedd6'
  inverse-primary: '#84d6c0'
  secondary: '#633fcd'
  on-secondary: '#ffffff'
  secondary-container: '#7c5be8'
  on-secondary-container: '#fffbff'
  tertiary: '#7b3500'
  on-tertiary: '#ffffff'
  tertiary-container: '#a04700'
  on-tertiary-container: '#ffd4bf'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#a0f2db'
  primary-fixed-dim: '#84d6c0'
  on-primary-fixed: '#002019'
  on-primary-fixed-variant: '#005143'
  secondary-fixed: '#e7deff'
  secondary-fixed-dim: '#ccbdff'
  on-secondary-fixed: '#1f0060'
  on-secondary-fixed-variant: '#4d24b7'
  tertiary-fixed: '#ffdbca'
  tertiary-fixed-dim: '#ffb68e'
  on-tertiary-fixed: '#331200'
  on-tertiary-fixed-variant: '#763300'
  background: '#edfdf6'
  on-background: '#101e1a'
  surface-variant: '#d6e6df'
typography:
  display-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 44px
    fontWeight: '800'
    lineHeight: 52px
    letterSpacing: -0.03em
  headline-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 32px
    fontWeight: '800'
    lineHeight: 40px
    letterSpacing: -0.02em
  headline-lg-mobile:
    fontFamily: Plus Jakarta Sans
    fontSize: 26px
    fontWeight: '800'
    lineHeight: 34px
    letterSpacing: -0.02em
  headline-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 22px
    fontWeight: '800'
    lineHeight: 28px
    letterSpacing: -0.015em
  title-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 18px
    fontWeight: '700'
    lineHeight: 24px
    letterSpacing: -0.01em
  title-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 16px
    fontWeight: '600'
    lineHeight: 22px
    letterSpacing: 0em
  body-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 16px
    fontWeight: '500'
    lineHeight: 24px
    letterSpacing: 0.01em
  body-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
    letterSpacing: 0.01em
  body-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 12px
    fontWeight: '400'
    lineHeight: 16px
    letterSpacing: 0.02em
  label-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 20px
    letterSpacing: 0.02em
  label-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 12px
    fontWeight: '600'
    lineHeight: 16px
    letterSpacing: 0.03em
  label-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 11px
    fontWeight: '700'
    lineHeight: 14px
    letterSpacing: 0.04em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  gutter: 1rem
  gutter-tablet: 1.5rem
  margin: 1rem
  margin-tablet: 2rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 1rem
  space-lg: 1.25rem
  space-xl: 1.75rem
  space-2xl: 2.5rem
---

## Brand & Style

This design system is tailored for a peaceful, reassuring, private family location app crafted specifically for everyday domestic life. The aesthetic avoids cold surveillance-tech paradigms or frantic parental-tracking tropes; instead, it establishes an atmosphere of mutual trust, quiet care, and domestic serenity. 

The design combines the tactile, adaptive principles of **Material You / Material 3** with a grounded European editorial discipline:
- **Tone & Mood:** Reassuring, unhurried, privacy-first, warm, and protective.
- **Visual Stance:** Generous negative space, soft ambient elevation, rounded organic containers, and crisp typographic hierarchy.
- **Illustration & Imagery Rules:** Strictly no stock photos, no gradient meshes, and no standard emoji representations. All visual aids rely on crisp, flat duo-tone or tri-tone vector silhouettes using the core family member palette.
- **Iconography:** Strictly Material Symbols Rounded, utilizing 2-pixel strokes and fully rounded joints to reinforce approachability.

## Colors

The palette balances tranquil botanical slate hues with warm signals, ensuring low-stress readability in varied lighting environments.

### Core System Palette
- **Primary (`#0E6E5C` - Deep Teal):** Used for key identity points, confirmed safe states, home geofences, and primary interactive elements.
- **Primary Container (`#DCEFE9` - Soft Teal Tint):** Used for non-urgent background highlights, selected list tiles, and subtle badge containers.
- **Alert / SOS (`#B4370A` - Burnt Orange):** A deliberate shift from aggressive fluorescent red to an earthen, urgent burnt tone for battery warnings, urgent notifications, and emergency triggers.
- **Canvas / Background (`#F3F5F4` - Mist Grey):** A neutral base that softens screen glare compared to pure white.
- **Surface & Cards (`#FFFFFF` - Pure White):** Used to isolate distinct content cards and interactive map overlays.
- **Text Ink (`#12201C` - Forest Char):** High-contrast deep slate green for effortless readability.
- **Secondary Text (`#5B6763` - Sage Muted):** Subdued labeling, secondary timestamps, and descriptive sub-labels.

### Family Member Identifiers
To distinguish family members on map surfaces and shared timelines without chaotic visual noise, four designated member hues are locked into the system:
- **Member 1 (Primary):** `#0E6E5C` (Teal)
- **Member 2:** `#6D4BD8` (Muted Royal Purple)
- **Member 3:** `#2563EB` (Cobalt Blue)
- **Member 4:** `#B45309` (Warm Amber)

## Typography

The type system is powered entirely by **Plus Jakarta Sans**, utilizing its geometric clarity and rounded terminal feel to create warmth while preserving operational legibility.

- **Headlines & Titles:** Set with an extra-bold `800` weight with tighter tracking (`-0.02em` to `-0.03em`) to anchor dashboards and bottom sheets with an approachable, contemporary presence.
- **Body Text:** Uses weights `400` (for secondary details and contextual status text) and `500` (for primary conversational sentences). Line heights remain open (`1.4` to `1.5`) to allow stress-free scanning on smaller phone screens.
- **Labels & Micro-copy:** Locked to `600` and `700` weight with positive tracking to maintain absolute clarity on mini map pins, battery tags, and status pills.

## Layout & Spacing

The layout is built for fluid mobile use, using strict 4px/8px increments.

- **Mobile Phone (Base Canvas):** Single-column fluid framework with `16px` (`margin`) outer padding, reserving high edge clearances for one-handed operation. Elements dock above native navigation surfaces.
- **Tablet / Split Screen:** Scales to a dual-pane master-detail view with `32px` margins and a permanent list drawer alongside a continuous map display.
- **Vertical Hierarchy:** Content is grouped into discrete semantic islands rather than border lines. Vertical spacing between independent modules uses `space-lg` (20px), while intra-component padding inside cards defaults to `space-md` or `space-lg`.

## Elevation & Depth

This system avoids harsh drop shadows and heavy multi-layered borders. Visual depth is rendered through tinted surface containers and ultra-diffused atmospheric light:

- **Level 0 (Base Canvas):** Tinted Mist Grey (`#F3F5F4`), entirely flat.
- **Level 1 (Cards & Static Containers):** Pure White (`#FFFFFF`) with a delicate ambient shadow tinted with Forest Slate: `box-shadow: 0 4px 20px -2px rgba(18, 32, 28, 0.04), 0 2px 6px -1px rgba(18, 32, 28, 0.02)`.
- **Level 2 (Floating Map Controls & Modals):** White with enhanced ambient dispersion: `box-shadow: 0 8px 30px -4px rgba(18, 32, 28, 0.08), 0 4px 12px -2px rgba(18, 32, 28, 0.03)`.
- **Level 3 (Persistent Bottom Sheets & SOS Overlays):** Deep ambient lift: `box-shadow: 0 -8px 32px 0 rgba(18, 32, 28, 0.08)`.

## Shapes

The design system embraces generous, organic curves that echo domestic warmth and tactile safety:

- **Cards & Dashboard Panels:** Formed with a fixed corner radius of `20px` (`rounded-xl` equivalent).
- **Persistent Bottom Sheets:** Top-left and top-right radii are set to a pronounced `28px`.
- **Buttons, Badges, and Chips:** Full pill geometry (`border-radius: 9999px`) across all sizes.
- **Avatars & Member Radar Pins:** Pure circles with outer status rings.
- **Input Fields:** Generously radiused at `16px` to harmonize between card panels and pill buttons.

## Components

### Buttons
- **Primary Pill Button:** Fully rounded (`9999px`), minimum height `48px` (target `52px` for comfortable thumb interaction). Background: Deep Teal (`#0E6E5C`), text: `#FFFFFF` (14px, weight 600). Pressed state transitions to Deep Teal tinted darker by 10%.
- **Secondary / Action Chip:** Height `40px`, background: Primary Container (`#DCEFE9`), text: Deep Teal (`#0E6E5C`).
- **Emergency / SOS Button:** Height `56px`, full pill, background: Burnt Orange (`#B4370A`), text: `#FFFFFF`.

### Cards & Family Member Tiles
- Set on pure white (`#FFFFFF`) with `20px` border radius and Level 1 elevation.
- Generous internal padding (`16px` to `20px`).
- Member tiles include a left-aligned circular avatar with a 3px ring colored with the member's assigned identifier color, followed by title, status ("Thuis", "Op school", "Onderweg"), and battery life badge.

### Chips & Filter Pills
- Fully rounded pills (`height: 36px`), zero border. Default unselected state uses `#FFFFFF` or `rgba(18, 32, 28, 0.05)` with `14px` medium weight text. Active state uses `#DCEFE9` with Deep Teal text and a leading Material Symbols Rounded icon.

### Form Inputs & Place Search
- Minimum height `52px`, radius `16px`, background: `#FFFFFF` or `#EAECEB`, border: transparent. On focus, a crisp 2px border in Deep Teal (`#0E6E5C`) animates smoothly without layout shift. Text in Forest Char (`#12201C`) with Sage Muted (`#5B6763`) placeholders.

### Lists & Activity Feed
- Clean, divider-less design. List rows utilize subtle surface cards or rely on vertical spacing (`12px` gap) to segment events. Trailing timestamps are set in `label-md` using Sage Muted.

### Bottom Sheet Drawer
- Anchored to the viewport bottom with `28px` rounded upper corners, white canvas, Level 3 elevation, topped by a centered, pill-shaped pull indicator (`36px × 4px`, color `#D1D7D5`, `margin: 12px auto`).