extends SceneTree
## Headless: no hue anywhere in the token sheet, and the panel's chrome is
## the one deliberate exception. docs/DOC_ui_style.md s12.
## Run: godot --headless --path . --script res://tests/TEST_ui_tokens.gd

const TOKENS := "res://scripts/SCRIPT_ui_tokens.gd"
const GREY_TOLERANCE := 0.031

var fails := 0


func ok(cond: bool, msg: String) -> void:
	print(("  PASS  " if cond else "  FAIL  ") + msg)
	if not cond:
		fails += 1


func _initialize() -> void:
	var script: GDScript = load(TOKENS)
	var consts := script.get_script_constant_map()
	var colours := 0
	for k in consts:
		var v = consts[k]
		if v is Color:
			colours += 1
			var spread: float = max(v.r, v.g, v.b) - min(v.r, v.g, v.b)
			ok(spread <= GREY_TOLERANCE, "%s is grey (spread %.3f)" % [k, spread])
	ok(colours >= 12, "the sheet declares at least 12 colours (%d)" % colours)
	ok(consts.COL_CURSOR.r == 1.0, "cursor is white")
	ok(consts.COL_DIM.r < consts.COL_WAIT.r and consts.COL_WAIT.r < consts.COL_TAG.r \
			and consts.COL_TAG.r < consts.COL_READY.r and consts.COL_READY.r < consts.COL_NAME.r,
			"the ramp is ordered")
	print("ui tokens: %d failure(s)" % fails)
	quit(1 if fails > 0 else 0)
