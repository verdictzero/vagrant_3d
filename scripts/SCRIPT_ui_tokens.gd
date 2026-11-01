class_name UiTokens
extends RefCounted
## The house UI tokens, by name. docs/DOC_ui_design_tokens.md is the sheet;
## docs/DOC_ui_style.md is the why. Reach for these, never copy the values.
##
## Sizes are in this project's 1600x900 design space (project.godot), which
## is the sheet's 1280x720 at 0.8: the target is a tablet or a foldable, and
## the sheet's handheld sizes read big there.

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
const CUT := 12.0        # large window
const ROW_CUT := 10.0    # bar strip, popovers
const SEL_CUT := 6.0     # cursor box
const BORDER := 2.0

# Type sizes.
const FS_HINT := 12
const FS_LABEL := 13
const FS_BODY := 16
const FS_ROW := 18

# Layout.
const MARGIN := 12
const GUTTER := 10
const PAD := 12
const ROW_H := 34        # a finger's row
const HEAD_H := 24       # a section heading inside a menu
const ICON := 16
const ICON_GAP := 8
const SEL_PAD_X := 6
const SEL_PAD_Y := 3

# Motion.
const TRAVEL := 0.16

# The world, drawn in the same greys.
const WORLD_BG := Color(0.07, 0.07, 0.075)
const GRID := Color(0.20, 0.20, 0.20)
const AXIS := Color(0.33, 0.33, 0.33)
