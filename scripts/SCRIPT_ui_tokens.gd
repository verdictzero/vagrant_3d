class_name UiTokens
extends RefCounted
## The house UI tokens, by name. docs/DOC_ui_design_tokens.md is the sheet;
## docs/DOC_ui_style.md is the why. Reach for these, never copy the values.

# The ramp. No hue anywhere: channel spread <= 0.031 (TEST_ui_tokens.gd).
const COL_CURSOR := Color(1.00, 1.00, 1.00)   # where you are
const COL_BRIGHT := Color(0.96, 0.96, 0.96)   # transient flash text
const COL_NAME := Color(0.90, 0.90, 0.90)     # the primary value
const COL_READY := Color(0.82, 0.82, 0.82)    # interactive, available
const COL_TAG := Color(0.60, 0.60, 0.60)      # labels, units, headings
const COL_WAIT := Color(0.45, 0.45, 0.45)     # not available; edges
const COL_DIM := Color(0.33, 0.33, 0.33)      # rules, ticks, disabled rows

# Chrome. The +0.02 blue is the one hue allowed.
const PANEL_BG := Color(0.05, 0.05, 0.06, 0.82)
const PANEL_BORDER := Color(0.72, 0.72, 0.74, 1.0)
const SEL_BG := Color(1.0, 1.0, 1.0, 0.10)
const KEYLINE := Color(0.0, 0.0, 0.0, 0.85)

# Shape.
const CUT := 16.0        # large window
const ROW_CUT := 12.0    # menu row
const SEL_CUT := 8.0     # cursor box
const BORDER := 2.0

# Type sizes, in the 1280x720 space.
const FS_HINT := 14
const FS_LABEL := 16
const FS_BODY := 18
const FS_ROW := 22

# Layout. Tool margins, not the pause menu's 40: the viewport is the point.
const MARGIN := 16
const GUTTER := 12
const PAD := 16
const ROW_H := 40        # a finger's row
const SEL_PAD_X := 10
const SEL_PAD_Y := 4

# Motion.
const TRAVEL := 0.16

# The world, drawn in the same greys.
const WORLD_BG := Color(0.07, 0.07, 0.075)
const CLAY := Color(0.55, 0.55, 0.55)
const GRID := Color(0.20, 0.20, 0.20)
const AXIS := Color(0.33, 0.33, 0.33)
