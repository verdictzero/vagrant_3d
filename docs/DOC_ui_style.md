# White on dark — the portable UI rules

The numbers — every token, size, gap and timing in one re-feedable sheet —
are in `DOC_ui_design_tokens.md`.

This is the house UI style pulled out of the project it grew in, so it can be
applied to something else: a website, a tool, another game, another engine.
Everything here is transcribed from shipped code (`scripts/SCRIPT_menu_system.gd`
is the palette's home and `scripts/SCRIPT_combat_panel.gd` is the frame's), but
nothing here depends on that code. Take the tables and the rules.

The style has one sentence in it: **there is no colour, so brightness is the
only thing a value can mean, and it must therefore mean exactly one thing at a
time.** Everything below is that sentence with the arguments attached.

**Contents**

1. [The three rules](#1-the-three-rules)
2. [The ramp](#2-the-ramp)
3. [Picking a step](#3-picking-a-step)
4. [The one bright step](#4-the-one-bright-step)
5. [Alarms without red](#5-alarms-without-red)
6. [Shape: the chamfer](#6-shape-the-chamfer)
7. [Type: five roles](#7-type-five-roles)
8. [Selection: two mechanisms, pick one](#8-selection-two-mechanisms-pick-one)
9. [Depth: what sits above what](#9-depth-what-sits-above-what)
10. [Contrast, measured](#10-contrast-measured)
11. [Reach the tokens, don't copy them](#11-reach-the-tokens-dont-copy-them)
12. [Keeping it honest](#12-keeping-it-honest)
13. [Porting: CSS](#13-porting-css)
14. [Porting: anywhere else](#14-porting-anywhere-else)
15. [The failure catalogue](#15-the-failure-catalogue)
16. [Do / don't](#16-do--dont)

---

## 1. The three rules

**No hue.** Every surface, every label, every fill is a step of grey on black.
Colour is never decorative and never semantic. If you want to say "this one
matters", you say it in brightness.

**No round corners.** A corner is either a square right angle or a 45° cut.
Border radius does not exist in this UI. One shape, used everywhere, is what
makes a strange interface feel designed rather than assembled.

**There is no light mode.** Everything sits on black. Do not build one. A
brightness ramp inverted onto white is not the same design with the values
flipped — the whole hierarchy below assumes a dark field that unlit things can
recede into, and white has no such floor.

These are not stylistic preferences that came first. Each one was arrived at by
shipping the opposite and taking it back out; §15 has the wreckage.

---

## 2. The ramp

Ten steps, black through white. The names are functional, not tonal — the point
is that a reader picks a step by asking *what is this for*, never by asking
*how bright should this be*.

| Token | 0–1 | Hex | Role |
| --- | --- | --- | --- |
| `cursor` | `1.00` | `#FFFFFF` | **Where you are.** The selected row, the live marker. |
| `bright` | `0.96` | `#F5F5F5` | Transient flash messages ("Saved") that fade out. |
| `name` | `0.90` | `#E6E6E6` | Primary values — the number the panel exists to show. |
| `hp` | `0.85` | `#D9D9D9` | Bar fill, first weight. |
| `ready` | `0.82` | `#D1D1D1` | Selectable but not selected. The resting state of anything interactive. |
| `tp` | `0.68` | `#ADADAD` | Bar fill, second weight. |
| `tag` | `0.60` | `#999999` | Section labels, units, carets — the words that frame a value. |
| `exp` | `0.52` | `#858585` | Bar fill, third weight. |
| `wait` | `0.45` | `#737373` | Inactive, not yet available, edges. |
| `dim` | `0.33` | `#545454` | Least emphasis: rules, ticks, unlit rungs, disabled placeholders. |

Chrome and containers:

| Token | Value | Hex / CSS |
| --- | --- | --- |
| `panel-bg` | `Color(0.05, 0.05, 0.06, 0.82)` | `rgba(13, 13, 15, 0.82)` |
| `panel-border` | `Color(0.72, 0.72, 0.74)` | `#B8B8BD` |
| `cursor-fill` | `Color(1, 1, 1, 0.10)` | `rgba(255, 255, 255, 0.10)` |
| `bar-bg` | `Color(0, 0, 0, 0.5)` | `rgba(0, 0, 0, 0.5)` |
| `bar-border` | `Color(0.6, 0.6, 0.6, 0.7)` | `rgba(153, 153, 153, 0.7)` |
| `void` | `Color(0, 0, 0)` | `#000000` |

**The chrome is a hair blue and that is deliberate.** `panel-bg` and
`panel-border` carry `+0.02` on the blue channel — a cool grey reads as *glass*,
a neutral one reads as *dirt*. It is the only hue anywhere in the system and it
is below the threshold at which anyone would call it a colour. When you write
the automated check in §12, its tolerance exists to admit exactly this and
nothing else.

**Panels are translucent.** `0.82` alpha, so whatever is behind the UI stays
faintly visible through it. A panel that is opaque black on a black field is
invisible; a panel that lets the world through is a pane of glass laid on it.

---

## 3. Picking a step

Work down this list and stop at the first line that fits. Do not skip to "what
looks right" — the ramp is only legible because the same question always
produces the same answer.

1. Is it **where the user is** right now? → `cursor`. See §4 first.
2. Is it the **value this widget exists to show**? → `name`.
3. Is it **interactive and available**? → `ready`.
4. Is it a **word that frames a value** — a label, a unit, a caret? → `tag`.
5. Is it **not available yet**, or an edge, or a boundary? → `wait`.
6. Is it **structural furniture** — a rule, a tick, an unlit element? → `dim`.
7. Is it a **bar fill**? → `hp` / `tp` / `exp`, by the rule in the next
   paragraph.

**Bar fills are chosen by area, not by importance.** Brightness competes with
brightness **× area**. A bar 8 px tall and a finger wide takes `hp` and reads as
a small bright mark. A gauge sweeping 248° around a 70 px radius takes `tp`,
because at `hp` that much lit surface becomes the brightest thing on screen —
brighter than the white cursor sitting on top of it, which inverts the entire
hierarchy. When a fill gets big, step it down.

---

## 4. The one bright step

On a grey field there is exactly one step above "primary value", and spending it
on two meanings spends it on neither.

**`cursor` means "where you are". Nothing else.** The selected row, the swing
marker, the lit rung, the pin on the rim, the strike point on the ball. Each of
those is the cursor of its own widget, and no two of them are ever on the same
widget, so they are never ambiguous.

The corollary is easy to miss: **whatever sits behind the cursor must stop short
of it.** In the shipped game the golf ball is grey — its shading ramp tops out at
`ready`, two clear steps down — precisely so the strike point marked on it has
something to be brighter than. A white ball would have put the panel's brightest
value directly behind its own cursor. If you are drawing something the cursor
will sit on, cap it at `ready` and leave the top two steps free.

---

## 5. Alarms without red

An orange meaning "ready" and a red meaning "danger" are, in grey, the same
grey. So an alarm is not a recolour — **a gauge that needs attention fills
white.**

That is the one place `cursor` is spent on something other than position, and it
is allowed because it is the same event every time: a gauge topping out.

When the alarm and the cursor collide on one widget, **invert the cursor**: draw
it as a black core with a white keyline. That is the maximum contrast available
against a white fill, and it costs nothing, because the thing it is drawn on is
already saying "full". In the shipped game this happens at exactly one moment —
the swing gauge at full power, which is the moment that decides the shot.

---

## 6. Shape: the chamfer

One frame primitive, used for every window, card, tooltip and cursor box.

- Corners are **cut at 45°**, never rounded. Each corner is independently square
  or cut.
- The house shape is **top-right and bottom-left cut**, the other two square.
  Keep it consistent; the asymmetry is what makes it read as a shape rather than
  as a bevel.
- Cut length by scale: **16 px** large windows · **12 px** menu rows · **8 px**
  selection cursor boxes.
- Border: **2 px**, drawn as a closed polyline in `panel-border`.
- Fill: translucent `panel-bg`.
- Drop shadow: off by default. Where it is used (cards that float above other
  cards), it is several offset copies of the polygon at a fraction of the alpha
  each, so the overlap near the card is darkest and the fringe fades — not a
  blur.

**There are no buttons in this system, only rows.** A call to action is a panel
row with the selection treatment, not a filled pill. If you find yourself
drawing a pill you have left the style.

---

## 7. Type: five roles

Pick by **role**, never by filename. The roles are what port; the specific faces
are replaceable.

| Role | Face here | Used for |
| --- | --- | --- |
| **title** | Draco | Wordmark and big branding moments only. Never body copy. |
| **ui** | Zalando Sans (+ Condensed cut, 8 weights) | Non-diegetic UI: menu rows, labels, body. |
| **technical** | Share Tech Mono | **Diegetic** readouts — things inside the world. Cockpit instruments, machine consoles, developer tools. |
| **clock** | digital-7 | Clocks and LCD-style numerics. |
| **prompts** | PromptFont | Button glyphs — one character per physical control. **Never words.** |

**A glyph font is not a text font, and the rule has to be written down or it
will be broken.** A face like PromptFont puts its controller buttons on **real
Unicode codepoints** — the one that draws the A button is `U+21D3`, which is ⇓
in every other font on the machine. Two consequences, and both bite:

* it is **never a fallback** on another font. Fall back to it and an arrow in a
  sentence turns into a gamepad button.
* it is **never the font of a sentence**. It draws the glyph; the text role
  draws the words beside it. One label, two fonts.

Keep the mapping from control to codepoint in one named table and never paste
the characters into a string literal, where they read as arrows and maths in
every editor and diff you will ever look at.

**The diegetic split is the rule that gets broken.** `technical` is for surfaces
that exist *in the fiction* — a readout a character could be looking at. An
overlay the player sees but the character does not is `ui`, however retro it
looks. A monospace face on an overlay is the single most common way this style
goes wrong, because it always looks plausible.

Within a panel, the useful split is **words in `ui`, numbers in `clock`**.

**Zero-pad numerics to a fixed width** (`03`, `96`). A lone seven-segment digit
is genuinely hard to read with no neighbour to give it scale, and a fixed width
stops the row reflowing every time a value crosses ten.

**Selection changes weight, not size.** ExtraLight → Bold at the same point
size, with a fixed row height, so nothing reflows. If you need the row to move,
move the row (§8) — do not let the type resize.

---

## 8. Selection: two mechanisms, pick one

Both are grayscale, so the *mechanism* is the only thing distinguishing one
menu surface from another. That makes it worth choosing deliberately and then
being consistent.

**Indent and brighten.** Each row shifts right when selected (here: 4 px → 22 px
of left margin) and its text goes `ready` → `cursor`. Good for a short list on a
busy background; the motion is per-row and local.

**A floating cursor box.** Rows never move. One chamfered box — `cursor-fill`
at 10% white, `cursor` border, 8 px cut — is repositioned each frame to hug the
current row. Good for dense lists and for anything with two focus levels,
because the box's position *is* the focus indicator and there is exactly one per
navigable list.

Build the floating box as **one element you move**, not as a style you apply to
each row. That is what makes the transition animatable and what keeps "there is
only one cursor" true by construction.

**Keyboard and pointer share one cursor.** There is no separate hover state and
no separate focus ring — hovering moves the cursor. On the web you still owe
`:focus-visible` a visible treatment (§13), because there the cursor is a
stylesheet away from not existing.

---

## 9. Depth: what sits above what

If the design has a full-screen post-process (dither, scanlines, palette snap,
grain, chromatic aberration — anything), then:

> **The UI draws above the post-process pass. Only the world below it is
> processed.**

This is the one invariant in the whole document that is not a matter of taste.
Run text through an ordered-dither or a palette snap and its antialiasing is
quantised along with everything else: glyph edges break up, thin borders drop
in and out between frames, and the interface reads as broken rather than as
styled. Process the world; leave the interface crisp on top of it.

The stack this project ships, as a reference ordering:

| Layer | What |
| --- | --- |
| 128 | **Post-process (dither + palette LUT)** — everything below is processed |
| 180 | Player stats, vehicle gauges |
| 190 | Mode HUDs (golf, flight, build) |
| 200 | Title-screen UI |
| 230 | On-screen touch controls |
| 240 | **Pause menu overlay** — must cover the touch controls |
| 256 | Screen fade |
| 300 | Scene-transition effects |
| 512 | Developer overlay |

The numbers are arbitrary; the order is not. Leave gaps — every one of those
gaps has been used at least once.

One consequence worth stating: **the pause overlay must be above the on-screen
controls.** A pause menu with a glass d-pad drawn over it is a pause menu the
player can shoot through.

---

## 10. Contrast, measured

WCAG 2.x ratios, computed against the panel fill composited over black
(`rgba(13,13,15,0.82)` over `#000000` = `#0B0B0C`), and against pure black.

| Token | vs panel | vs black | Verdict |
| --- | --- | --- | --- |
| `cursor` `#FFFFFF` | 19.67:1 | 21.00:1 | AAA |
| `bright` `#F5F5F5` | 18.05:1 | 19.26:1 | AAA |
| `name` `#E6E6E6` | 15.76:1 | 16.83:1 | AAA |
| `hp` `#D9D9D9` | 13.94:1 | 14.88:1 | AAA |
| `ready` `#D1D1D1` | 12.88:1 | 13.75:1 | AAA |
| `panel-border` `#B8B8BD` | 9.96:1 | 10.63:1 | AAA |
| `tp` `#ADADAD` | 8.77:1 | 9.36:1 | AAA |
| `tag` `#999999` | 6.91:1 | 7.37:1 | AAA |
| `exp` `#858585` | 5.33:1 | 5.69:1 | AA, AAA for large |
| `wait` `#737373` | 4.15:1 | 4.43:1 | **AA large only** |
| `dim` `#545454` | 2.60:1 | 2.77:1 | **Fails AA, including large** |

The ramp is unusually comfortable down to `tag` — removing hue costs nothing in
luminance, so a grey scheme measures better than the coloured one it replaces
at the same apparent weight.

**The bottom two steps are not text colours.** `wait` passes for large text
only. `dim` passes nothing: at 2.60:1 it does not reach the 3:1 floor for large
text either. Both are legitimate for *marks* — rules, ticks, inactive
furniture, disabled placeholders whose content is not needed — and neither may
ever be used for body copy or for a label a user has to read. If you need
"disabled but readable", that is `wait` at large size, or a `tag`-weight label
with the interaction removed some other way.

> Earlier project notes quoted `dim` as 3.5:1 and called it "large-text AA at
> best". That number does not reproduce under any plate I can compute, and the
> conclusion it supported was too generous. The table above is the computed one.

---

## 11. Reach the tokens, don't copy them

Every surface in this style shares one palette. There are two ways to arrange
that and they are not equally good.

**Copy the values, and pin the copies with a test.** The surface declares its
own constants with the same numbers, and a test asserts each one still equals
the original. Drift becomes *detectable*.

**Reach for the originals by name.** The surface imports the palette module and
takes `COL_CURSOR` from it. Drift becomes *impossible*, and restyling the
palette restyles every surface for free.

Prefer the second wherever the language allows it. Use the first only where a
module boundary genuinely forbids the import — and then write the test, because
an uncopied copy is how a palette quietly becomes four palettes.

Either way, **hold tokens by name, not by value.** A test that asserts
`COL_CURSOR == #FFFFFF` fails the day someone restyles the whole UI on purpose,
which is the one day you want it to pass. A test that asserts *this surface's
cursor is the palette's cursor* is the one that holds.

---

## 12. Keeping it honest

The style's defining rule — no hue — is the kind a codebase loses one
well-meaning commit at a time. It is also trivially checkable, so check it.

**Walk the constants and measure the channel spread.**

```
spread = max(r, g, b) - min(r, g, b)
assert spread <= 0.031
```

Over every colour constant a UI module declares, including colours nested inside
arrays — a shading ramp with a hue smuggled in as its fourth element is exactly
the shape of the mistake this catches. The tolerance is `0.031` rather than zero
so it admits the deliberately-cool chrome from §2 and nothing a person would
call a colour.

The value of this form is that it covers constants **that do not exist yet**: a
tinted colour added next year fails a test written this year, with no
maintenance in between. Assert the module has a minimum number of colours to
check, too, or the test passes vacuously the day someone renames the constants.

**What it cannot catch** is a colour literal written inline at the draw site
rather than declared as a constant. Nothing reaches those. Knowing the hole is
there is most of the defence: declare your colours.

**Check generated assets too.** If a palette LUT, atlas or texture carries the
look, it is a binary that no source file guards — re-bake it from the wrong
input and the whole interface comes back in colour with every script unchanged.
Read the pixels and assert they are greys.

---

## 13. Porting: CSS

```css
:root {
  --xg-void:          #000000;
  --xg-cursor:        #FFFFFF;
  --xg-bright:        #F5F5F5;
  --xg-name:          #E6E6E6;
  --xg-hp:            #D9D9D9;
  --xg-ready:         #D1D1D1;
  --xg-tp:            #ADADAD;
  --xg-tag:           #999999;
  --xg-exp:           #858585;
  --xg-wait:          #737373;
  --xg-dim:           #545454;

  --xg-panel-bg:      rgba(13, 13, 15, 0.82);
  --xg-panel-border:  #B8B8BD;
  --xg-cursor-fill:   rgba(255, 255, 255, 0.10);
  --xg-bar-bg:        rgba(0, 0, 0, 0.5);
  --xg-bar-border:    rgba(153, 153, 153, 0.7);

  --xg-cut:           12px;
  --xg-cut-lg:        16px;
  --xg-cut-sm:        8px;
  --xg-border:        2px;
}
```

**The chamfer.** `clip-path` clips a CSS border away with the rest of the box,
so the frame has to be a second clipped layer behind the first:

```css
.xg-panel {
  position: relative;
  background: var(--xg-panel-bg);
  clip-path: polygon(
    0 0, calc(100% - var(--xg-cut)) 0, 100% var(--xg-cut),
    100% 100%, var(--xg-cut) 100%, 0 calc(100% - var(--xg-cut)));
}
.xg-panel::before {          /* the 2px frame */
  content: "";
  position: absolute;
  inset: 0;
  background: var(--xg-panel-border);
  clip-path: inherit;
  z-index: -1;
  margin: calc(var(--xg-border) * -1);
}
```

**Never** add `border-radius` to a descendant. One rounded corner anywhere reads
as a mistake rather than as variety.

**Selection**, as one moved element rather than a per-row style:

```css
.xg-cursor-box {
  position: absolute;
  background: var(--xg-cursor-fill);
  outline: var(--xg-border) solid var(--xg-cursor);
  --xg-cut: var(--xg-cut-sm);
  transition: transform 120ms ease-out, width 120ms ease-out;
}
```

**Focus.** The engine has no focus ring because the cursor *is* focus. On the
web, keep that and add a fallback that survives a stylesheet failure:

```css
:focus-visible { outline: 2px solid var(--xg-cursor); outline-offset: 2px; }
```

**Do not reproduce a palette LUT on the web.** It fights text antialiasing and
you will lose. Reproduce the *impression*: a tiled 4×4 Bayer texture at low
opacity over **background plates only**, plus a soft white bloom behind
emissive type. The matrix, if you want it:

```
 0  8  2 10
12  4 14  6
 3 11  1  9
15  7 13  5
```

---

## 14. Porting: anywhere else

What actually travels, in order of how much it matters:

1. **The ramp and its role names** (§2). Ten greys and the discipline of picking
   by role. This is the whole style; everything else is decoration.
2. **One bright step, meaning one thing** (§4). The rule that survives every
   other simplification.
3. **The chamfer** (§6). One shape, one cut size per scale, never rounded.
4. **The type roles** (§7), especially the diegetic split — and, if a glyph
   font is among them, the rule that it is never a fallback. On the web that is
   not a style question but a correctness one: a CSS fallback chain will happily
   substitute a button glyph into a sentence, and an arrow in body copy becomes
   a gamepad button on one machine and not another.
5. **UI above the post-process** (§9), if there is one.
6. **The grey-spread assertion** (§12), in whatever test framework exists.

What does **not** travel: the specific font files (check licensing before
embedding any of them), the layer numbers, and the 1280×720 design space the
pixel measurements in this project are quoted in.

If the target has a smaller palette than 24-bit — a console pastiche, an
e-ink display, a terminal — collapse the ramp from the bottom, not the top.
`cursor`, `name`, `ready`, `tag` and `dim` are the five that must stay distinct;
`hp`/`tp`/`exp` exist only to give bars three weights and can merge into one.

---

## 15. The failure catalogue

Every one of these shipped before it was taken back out.

**Seven saturated hues on a HUD over a colourful world.** A panel was built as a
faithful 16-bit console pastiche — bevelled white frame, ruled green title bar,
swing arc banded white/red/yellow/green/cyan/blue/magenta. On its own, against a
flat backdrop, it was good. On screen it looked like a screenshot from a
different game, and the two things actually worth reading had no more of the eye
than the window frame did, because everything was shouting equally. **A UI
cannot win a contrast fight with a lit 3D world. Stop entering it.**

**Hue used as an identifier.** A fan of club cards was hue-stepped, one colour
per card. The hue was assigned by *position in the fan*, and the fan reorders —
so the same club was a different colour depending on what was selected, and "the
blue-green one" was never learnable. What identified a club was its label and
its position in the ladder, both of which survived the hue's removal untouched.

**The brightest fill, brighter than the cursor on top of it.** See §3. A gauge
fill at the bar weight, scaled up to a 248° sweep, out-shouted the white marker
riding on it. Brightness × area.

**A warm palette LUT under a white-on-black scene.** The project's default
palette ramps warm above `#B0B0B0`, so a monochrome scene quantised through it
came back cream: measured at `rgb(192, 184, 176)` — a channel spread of 16 —
with 17% of the frame carrying visible chroma. The fix was a mono LUT built by
replacing each entry of the same ramp with its Rec.709 luminance, so the tonal
*distribution* the look was built on survived and only the cast went. A fresh
linear ramp would have been easier and would have banded differently in the
darks, which is where a dither pass does its most visible work.

**A gradient seam under an inverting element.** A top scrim was shortened to
follow its content and put its falloff across the middle of a letterform. Under
an element that inverts what is behind it, a seam in the background is a seam in
the *letters*. Keep gradients entirely above or entirely below anything that
reads its own backdrop.

**Mid-grey behind a difference blend.** If you use the "invert what is behind
me" trick for a wordmark (`mix-blend-mode: difference` on white, or `1 - screen`
in a shader), then a background at exactly 0.5 inverts to 0.5 and the element
vanishes. This is inherent to every difference blend ever shipped — it is not a
bug to engineer around, it is a constraint on what may sit behind it. Also: such
an element takes **no outline** (the outline is drawn through the same blend, so
it only fattens the letterform) and nothing above it may isolate the blend, or
it stops at its own parent instead of reaching the floor.

**An unoutlined grey row on a line.** Text drawn over a scrolling grid needs a
black outline, or a row that happens to sit on a grid line is a row with a line
through it. Text drawn over a *paused, darkened* game does not. Do not carry the
outline between the two contexts by habit.

---

## 16. Do / don't

**Do**

- Pick a token by role, by walking §3 from the top.
- Spend `cursor` on position, and on nothing else but a topped-out gauge.
- Cap anything the cursor will sit on at `ready`.
- Step a fill down the ramp as its area goes up.
- Keep one frame shape, one cut size per scale.
- Put words in `ui` and numbers in `clock`; keep `technical` for the world.
- Move one cursor element; don't restyle rows.
- Draw the UI above the post-process.
- Assert the no-hue rule in a test that covers constants not yet written.

**Don't**

- Introduce a hue to signal state. There is no hue left to signal it against.
- Round a corner.
- Build a light mode.
- Set body copy in `wait` or `dim`.
- Use a monospace face on an overlay because it looks retro.
- Let selection change type size.
- Copy palette values when you could import them.
- Reproduce a palette LUT over live text.
