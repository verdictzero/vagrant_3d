# UI design tokens — the monochrome house style, as numbers

**Paste this whole file into a prompt to build UI in this style.** It is the
quantitative half of the style: every colour, face, size, gap and timing the
shipped UI uses, with the code it was read from. The *why* behind each rule is
in `DOC_ui_style.md`; this file is the *what*, kept short enough to re-feed.

Read from: `scripts/SCRIPT_menu_system.gd` (palette home, pause menu),
`scripts/SCRIPT_combat_panel.gd` (the frame), `scripts/autoload/AUTOLOAD_fonts.gd`
(type roles), `scripts/SCRIPT_command_menu.gd` (battle command list),
`scripts/SCRIPT_main_menu.gd` (title menu), `scripts/SCRIPT_golf_shot_panel.gd`
and `scripts/SCRIPT_golf_par_card.gd` (HUD cards).

All pixel values are in the **1280×720 design space** (`project.godot`:
viewport 1280×720, stretch mode `viewport`, aspect `expand`).

---

## 0. Instructions for whoever is building with this

1. No hue. Every colour is a grey from §1; channel spread `max−min ≤ 0.031`.
2. No rounded corners. Corners are square or cut at 45° (§3).
3. No light mode. Everything sits on black.
4. Pick a grey by **role** (§1 ladder), a font by **role** (§2), never by look.
5. One bright step: `cursor` (white) means *where you are* — and nothing else
   except a gauge that has topped out.
6. Words in the `ui` face, numbers in the `clock` face. `technical` (mono) is
   for diegetic, in-world readouts only — never an overlay.
7. Selection changes brightness and weight, never type size, never reflow.
8. No buttons/pills as calls to action — a CTA is a row with the selection
   treatment.
9. UI draws above any post-process (dither/LUT); the world goes under it. Menu-only screens (title, debug scene picker) have no post-process at all: player-facing UI is outside the game world and is drawn crisp.
10. UI lives inside the 16:9 frame (`SafeFrame.rect()`), whatever the panel. Only the on-screen touch pad goes out into the margin, which is a near-black-to-dark-grey vertical ramp under faint live static. Fingers drive the pad and nothing else: no Control is ever touched directly.
11. In Godot, reach the tokens by name (`const MENU := preload(".../SCRIPT_menu_system.gd")`,
    then `MENU.COL_CURSOR`) instead of copying values. Copy only where an
    import is impossible, and pin the copy with a test.

---

## 1. Colour

### The ramp (text and marks)

Walk top to bottom; stop at the first role that fits.

| # | Token (`COL_`) | 0–1 | Hex | Use it for |
|---|---|---|---|---|
| 1 | `CURSOR` | 1.00 | `#FFFFFF` | Where you are: selected row, live marker, cursor border. Also: a full gauge. |
| – | `BRIGHT` | 0.96 | `#F5F5F5` | Transient flash text ("Saved") that fades out. |
| 2 | `NAME` | 0.90 | `#E6E6E6` | The primary value a widget exists to show; names; help line. |
| 3 | `READY` | 0.82 | `#D1D1D1` | Interactive and available, not selected. Body copy. |
| 4 | `TAG` | 0.60 | `#999999` | Words that frame a value: section heads, labels, units, hints. |
| 5 | `WAIT` | 0.45 | `#737373` | Not available yet; held/out-of-focus state; edges. **Large text only.** |
| 6 | `DIM` | 0.33 | `#545454` | Rules, ticks, unlit rungs, disabled/struck rows, "- Empty -". **Never readable text.** |
| 7 | `HP` / `TP` / `EXP` | 0.85 / 0.68 / 0.52 | `#D9D9D9` / `#ADADAD` / `#858585` | Bar fills, 1st/2nd/3rd weight. Step **down** as the fill's area grows. |

Anything the cursor sits on is capped at `READY` so the cursor has something to
be brighter than.

### Chrome

| Token | Godot `Color` | CSS | Use |
|---|---|---|---|
| `PANEL_BG` | `(0.05, 0.05, 0.06, 0.82)` | `rgba(13,13,15,.82)` | Every window fill. Translucent on purpose. |
| `PANEL_BORDER` | `(0.72, 0.72, 0.74, 1)` | `#B8B8BD` | Every window frame. The +0.02 blue is the only hue allowed. |
| `SEL_BG` | `(1, 1, 1, 0.10)` | `rgba(255,255,255,.10)` | Fill inside the cursor box. |
| `COL_BAR_BG` | `(0, 0, 0, 0.5)` | `rgba(0,0,0,.5)` | Bar track. |
| `COL_BAR_BORDER` | `(0.6, 0.6, 0.6, 0.7)` | `rgba(153,153,153,.7)` | Bar track border (1 px). |
| `KEYLINE` | `(0, 0, 0, 0.85)` | `rgba(0,0,0,.85)` | Black hairline under a white mark drawn over a white fill. |
| `COL_OUTLINE` | `(0, 0, 0, 1)` or `0.85` | `#000` | Text outline where text floats over live gameplay (§5). |
| `COL_SHADOW` | `(0, 0, 0, 0.60)` | `rgba(0,0,0,.6)` | Text drop shadow over gameplay. |

Command-menu-only surfaces (still on the ramp):

| Token | Value | Use |
|---|---|---|
| `HATCH_INK` | white @ 0.09 | Row plate fill, drawn as diagonal hatching |
| `HATCH_INK_SEL` | white @ 0.14 | Selected row's hatching |
| `PILL_BG` / `PILL_BORDER` | black @ 0.55 / border grey @ 0.35 | Cost / tag plates |
| `BADGE_BG` / `BADGE_BORDER` | `(0.05,0.05,0.06,0.95)` / border grey @ 0.50 | Chevron badges |
| `DISC_BG` | `(0.08, 0.08, 0.09)` | Icon disc |
| `GRAIN` | black @ 0.18 | Plate grain |

### Contrast against the panel (`#0B0B0C` effective)

`CURSOR` 19.7 · `NAME` 15.8 · `READY` 12.9 · `TAG` 6.9 · `EXP` 5.3 ·
`WAIT` 4.15 (AA large only) · `DIM` 2.6 (fails everything — marks only).

---

## 2. Type

### Roles (`Fonts` autoload — always call by role)

| Role | Call | Face | For |
|---|---|---|---|
| title | `Fonts.title()` | Draco | Wordmark, big branding only. **No punctuation in its cmap** (`?` renders blank). |
| ui | `Fonts.ui(weight, condensed)` | Zalando Sans (+ Condensed) | All non-diegetic UI. Menus use **Condensed Medium**: `Fonts.ui("medium", true)`. |
| clock | `Fonts.clock()` | digital-7 (mono) | Every number in a panel: stats, costs, money, time. Zero-pad (`03`). |
| technical | `Fonts.technical()` | Share Tech Mono | Diegetic only: cockpit, consoles, key names in Help/Debug lists. |
| prompts | `Fonts.prompts()` | PromptFont | Controller/key glyphs, one char each, via `ButtonGlyphs`. Never words, never a fallback. |

Weights available for `ui`: `extralight, light, regular, medium, semibold,
bold, extrabold, black` (both normal and condensed cuts).

| Weight | Where |
|---|---|
| Condensed **Medium** | Default for every menu/HUD label |
| Condensed **Bold** | Selected command-menu row; title menu selected row |
| Condensed **ExtraLight** | Title menu unselected rows (→ Bold when selected, same size) |
| **Black** | Display-size single glyphs (status portrait `?` at 128) |

### Size scale (px, in the 1280×720 space)

| Size | Role | Seen as |
|---|---|---|
| 10 | micro | Unit inside a cost pill, tag-plate word |
| 11–12 | log | Battle log sub/top lines |
| 14 | hint / card head | Bottom hint line; HUD card headings & units (`FONT_TAG`) |
| 15 | secondary | Small units, loot gains, prompts under a result |
| 16 | section label | `MENU`, `ENEMIES`, stat tags, debug notes |
| **18** | **body / list** | Default `_label`; enemy & command rows; info text; key names; LCD inline numbers |
| 20 | row (default `_row`) | Equip rows, empty-state lines, stat values (clock) |
| **22** | **menu row / numerals** | Pause-menu command rows, title-menu rows, footer & card numbers (clock), screen heads |
| 24–30 | header | Status value 24, LOOT 26, flash 28, character name 30, VICTORY 30 |
| 64 | display | Wordmark (Draco), battle banner |

Spaced-out headers for big moments: `"V I C T O R Y"`, `"L O O T"` — single
spaces between letters, triple between words, drawn in `CURSOR`.

---

## 3. Shape: the chamfer frame

One primitive (`SCRIPT_combat_panel.gd`) for every window, card, plate and
cursor box.

| Property | Value |
|---|---|
| Corners | 45° cuts, never rounded. Default: **top-right + bottom-left cut**, the other two square. |
| Border | **2 px**, closed antialiased polyline, `PANEL_BORDER` |
| Fill | `PANEL_BG` |
| Cut, large window | **16** |
| Cut, menu row (title menu) | **12** |
| Cut, command-menu plate / ball well | **10** |
| Cut, cursor box | **8** |
| Shadow | Off by default. When on: `rgba(0,0,0,.4)` split over 4 offset copies, offset `(2, 3)` — stacked polygons, not a blur. |

Paired panels flip which corners are cut so adjacent cuts face away from each
other (pause menu: content pane cuts TR+BR, info pane cuts TL+BL, footer no cuts).

> Known deviation: `SCRIPT_menu_system.gd::_bar` gives progress bars
> `corner_radius 2`. That breaks rule 2; don't copy it.

---

## 4. Spacing

### Scale

Use these steps; the shipped code sits on them almost everywhere.

`2 · 4 · 6 · 8 · 12 · 16 · 20 · 24 · 40`

Plus two HUD-card steps, `9` and `13`, used only inside the compact cards.

### Screen layout (pause menu, the reference full-screen layout)

| Thing | Value |
|---|---|
| Outer margin (left/right) | **40** |
| Top of first window | **60** |
| Gutter between windows | **20** |
| Command column | `x40 y60`, `240×500` |
| Content pane | `x300 y60`, `940×430` |
| Info pane | `x300 y510`, `940×90` |
| Footer strip | `x40 y620`, `1200×56` |
| Hint line | `x40 y686`, 14 px `TAG` |
| Title wordmark | right-aligned to x 1232 (48 from edge), `y52`, 64 px, shadow `(3,3)` black @ 0.9 |

### Inside a window (`_vbox_in(panel, left, top, right, bottom, separation)`)

| Window | Padding L/T/R/B | Row separation |
|---|---|---|
| Default | 16 / 12 / 16 / 12 | 4 |
| Command column | 24 / 18 / 20 / 18 | 8 |
| Content pane | 28 / 22 / 28 / 22 | 6 |
| Info pane | 24 / 14 / 24 / 14 | 2 |
| Footer | 24 / 14 / 24 / – | 40 between groups, 12 within a group (word + number) |

Pattern: **section label (16, `TAG`) → `HSeparator` → rows.**

### HUD cards (golf shot panel, par card)

| Token | Value |
|---|---|
| `PAD` (frame inset) | 13 (`COMPACT_PAD` 9 on handheld) |
| `TAG_H` (heading row) | 19 |
| `RULE_GAP` (heading baseline → hairline) | 6 |
| `GAP` (rule/footer → interior) | 9 |
| `FOOT_H` (readout row) | 24 |
| Card width | 264 |

Pattern: **14 px `TAG` heading → hairline rule → content → 22 px clock readout footer.**

### Player stats HUD

Margin 14 · bar 190×16, gap 5 · label col 42 · value col 80 · HP box 96×22.

---

## 5. Selection & state

Three mechanisms. Pick one per surface; never mix on one list.

**A. Indent + brighten** (`SCRIPT_menu_system.gd` title, settings and scene-select lists)
- Row left margin `4 → 22`; text `READY → CURSOR`. No size change.

**B. Floating cursor box** (pause-menu command column and content pane)
- One chamfer box per navigable list, moved each frame to hug the row.
- Fill `SEL_BG`, border 2 px `CURSOR`, cut 8, pad `10` x / `4` y around the row.
- Focus left the list → box border drops to `WAIT`; row keeps its white.

**C. Plate column** (battle command menu, `SCRIPT_command_menu.gd`)
- Plate `300×30`, pitch 35 (5 gap), cut 10, hatched fill (7 pitch, 3 weight).
- Selected plate scales `1.18 w × 1.45 h`, text `×1.25`, icon `×2`, weight → Bold.
- 9 visible slots, cursor fixed on slot 4; neighbours peel left and fade:
  `ARC_X = [0, 0, -.08, -.24, -.30, -.38] × ROW_W`,
  `ARC_A = [1, .95, .70, .30, .08, 0]`.
- Icon disc 24 (half overhangs the plate), label x 38, text 18.
- Help banner 34 tall under the list, gap 6, margin 18; tag at x 16, text at x 76.
- Moods: **LIVE** (white frame) · **HELD** (frame `WAIT`) · **ASLEEP** (no frame,
  all labels `WAIT`, empty help).

**Title menu** (`SCRIPT_main_menu.gd`)
- Row height 38, separation 6, pad L16 / R18, 22 px.
- Unselected: Condensed ExtraLight `READY`; selected: Condensed Bold `CURSOR`,
  box slides in 26 from the right edge.

**Disabled row:** `DIM`, struck through, skipped by the cursor, inert on accept.

**Text outlines:** only where text sits over live gameplay — title rows 4 px,
battle hint 3 px, golf HUD 2 px, black. Not over a paused/darkened screen.

---

## 6. Motion

| What | Value |
|---|---|
| Cursor travel / row slide | **0.16 s**, back-out ease, overshoot 0.7 (0 = plain ease-out, 1.7 = 10%) |
| Help-line cross-dissolve | **0.22 s** (slightly longer than travel, on purpose) |
| Flash message | appears at `BRIGHT`, alpha fades out over its last 1 s |
| Battle banner | flash up 0.04 s, down 0.34 s, hold 0.62 s; bar 96 tall, text 64 |
| Web equivalent | `transition: transform 160ms cubic-bezier(.34,1.3,.64,1)` |

---

## 7. Bars & gauges

- Track `COL_BAR_BG`, 1 px `COL_BAR_BORDER`; default 220×14 (menu), 190×16 (HUD).
- Fills `HP` → `TP` → `EXP` by weight; larger area ⇒ dimmer step.
- Full gauge ⇒ fill goes `CURSOR`; a cursor on it inverts to black core + white keyline.
- Ring gauges sweep 270°; swing arc 13 thick, 56° half-gap facing right.

---

## 8. Layering (CanvasLayer order)

| Layer | What |
|---|---|
| 128 | Post-process (dither + LUT) — everything below is processed |
| 180 | Player stats, vehicle gauges |
| 190 | Mode HUDs (golf, flight, build) |
| 200 | Title-screen UI |
| 230 | On-screen touch controls |
| 240 | Pause overlay (must cover touch controls) |
| 256 | Screen fade |
| 300 | Scene-transition effects |
| 512 | Developer overlay |

---

## 9. CSS port (drop-in)

```css
:root {
  /* ramp */
  --xg-void:#000; --xg-cursor:#FFF; --xg-bright:#F5F5F5; --xg-name:#E6E6E6;
  --xg-hp:#D9D9D9; --xg-ready:#D1D1D1; --xg-tp:#ADADAD; --xg-tag:#999;
  --xg-exp:#858585; --xg-wait:#737373; --xg-dim:#545454;
  /* chrome */
  --xg-panel-bg:rgba(13,13,15,.82); --xg-panel-border:#B8B8BD;
  --xg-cursor-fill:rgba(255,255,255,.10);
  --xg-bar-bg:rgba(0,0,0,.5); --xg-bar-border:rgba(153,153,153,.7);
  /* shape */
  --xg-border:2px; --xg-cut-lg:16px; --xg-cut:12px; --xg-cut-plate:10px; --xg-cut-sm:8px;
  /* space */
  --xg-s1:2px; --xg-s2:4px; --xg-s3:6px; --xg-s4:8px; --xg-s5:12px;
  --xg-s6:16px; --xg-s7:20px; --xg-s8:24px; --xg-s9:40px;
  /* type */
  --xg-font-title:"Draco", serif;
  --xg-font-ui:"Zalando Sans Condensed", "Zalando Sans", system-ui, sans-serif;
  --xg-font-clock:"digital-7 Mono", "digital-7", ui-monospace, monospace;
  --xg-font-tech:"Share Tech Mono", ui-monospace, monospace;
  /* never put PromptFont in a fallback chain */
  --xg-fs-micro:10px; --xg-fs-hint:14px; --xg-fs-small:15px; --xg-fs-label:16px;
  --xg-fs-body:18px; --xg-fs-row:20px; --xg-fs-menu:22px; --xg-fs-head:28px;
  --xg-fs-display:64px;
  /* motion */
  --xg-travel:160ms; --xg-fade:220ms;
  --xg-ease:cubic-bezier(.34,1.3,.64,1);
}
html, body { background:var(--xg-void); color:var(--xg-ready);
  font:500 var(--xg-fs-body)/1.35 var(--xg-font-ui); }
* { border-radius:0 !important; }
.xg-panel { position:relative; background:var(--xg-panel-bg);
  clip-path:polygon(0 0, calc(100% - var(--xg-cut-lg)) 0, 100% var(--xg-cut-lg),
    100% 100%, var(--xg-cut-lg) 100%, 0 calc(100% - var(--xg-cut-lg))); }
/* 2px frame: second clipped layer behind (clip-path eats real borders) */
.xg-panel::before { content:""; position:absolute; inset:calc(var(--xg-border) * -1);
  background:var(--xg-panel-border); clip-path:inherit; z-index:-1; }
.xg-label { color:var(--xg-tag); font-size:var(--xg-fs-label); letter-spacing:.04em;
  text-transform:uppercase; }
.xg-num { font-family:var(--xg-font-clock); color:var(--xg-name);
  font-variant-numeric:tabular-nums; }
.xg-row { color:var(--xg-ready); font-size:var(--xg-fs-menu); }
.xg-row[aria-selected="true"] { color:var(--xg-cursor); }
.xg-row[aria-disabled="true"] { color:var(--xg-dim); text-decoration:line-through; }
:focus-visible { outline:2px solid var(--xg-cursor); outline-offset:2px; }
```

---

## 10. Pre-ship checklist

- [ ] Every colour is a ramp/chrome token; spread ≤ 0.031.
- [ ] No `border-radius` / `corner_radius` anywhere.
- [ ] Exactly one `CURSOR`-white thing per widget (or a full gauge).
- [ ] No readable text in `DIM`; `WAIT` only at ≥ 18 px.
- [ ] Words in `ui`, numbers in `clock`, mono only for in-world readouts.
- [ ] Section label 16 `TAG` → rule → rows; body 18; menu rows 22.
- [ ] Spacing on the scale (2/4/6/8/12/16/20/24/40); 40 outer, 20 gutter.
- [ ] Selection changes colour/weight only; nothing reflows.
- [ ] UI above the post-process layer.
