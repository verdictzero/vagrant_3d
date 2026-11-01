class_name ToolWindow
extends Control
## The tool properties window: what the live tool is doing, as numbers you
## can read and sliders you can pull. One window for every tool; the tool
## hands it a list of properties and gets told when one changes. Sits in the
## bottom-left of the view while a tool is live. One Control, drawn and
## hit-tested by region, so a finger and the pen drive it the same way.
##
## A property: { label, value, span, unit, decimals }. The slider runs
## -span .. +span; the number shows the true value even past the ends.

const T := preload("res://scripts/SCRIPT_ui_tokens.gd")
const Chamfer := preload("res://scripts/SCRIPT_chamfer_panel.gd")

signal value_changed(index: int, v: float)
signal applied
signal cancelled

const W := 440.0
const LABEL_W := 60.0
const VALUE_W := 104.0
const KNOB := 12.0

var tool_name := ""
var props: Array = []

var _press := ""          # "p0", "p1", ... "APPLY", "CANCEL" or ""
var _pointer := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func show_tool(label: String, properties: Array) -> void:
	tool_name = label
	props = properties
	size = Vector2(W, height_for(props.size()))
	visible = true
	queue_redraw()


func set_values(values: Array) -> void:
	for i in mini(values.size(), props.size()):
		props[i].value = values[i]
	queue_redraw()


static func height_for(n: int) -> float:
	return T.HEAD_H + n * T.ROW_H + T.ROW_H + 10.0


# --- regions ------------------------------------------------------------------

func row_rect(i: int) -> Rect2:
	return Rect2(0.0, T.HEAD_H + i * T.ROW_H, size.x, T.ROW_H)


func track_rect(i: int) -> Rect2:
	var r := row_rect(i)
	return Rect2(LABEL_W, r.position.y, size.x - LABEL_W - VALUE_W, r.size.y)


func button_rect(which: String) -> Rect2:
	var y := T.HEAD_H + props.size() * T.ROW_H + 4.0
	var half := size.x * 0.5
	return Rect2(0.0 if which == "APPLY" else half, y, half, T.ROW_H)


func region_at(pos: Vector2) -> String:
	for i in props.size():
		if track_rect(i).grow(3.0).has_point(pos):
			return "p%d" % i
	for b in ["APPLY", "CANCEL"]:
		if button_rect(b).has_point(pos):
			return b
	return ""


func knob_x(i: int) -> float:
	var tr := track_rect(i)
	var inset := T.PAD + KNOB
	var span: float = props[i].span
	return tr.position.x + inset + (clampf(props[i].value, -span, span) + span) / (2.0 * span) * (tr.size.x - inset * 2.0)


func value_at(i: int, x: float) -> float:
	var tr := track_rect(i)
	var inset := T.PAD + KNOB
	var t := clampf((x - tr.position.x - inset) / (tr.size.x - inset * 2.0), 0.0, 1.0)
	var span: float = props[i].span
	return -span + t * 2.0 * span


# --- input --------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	var touch := event as InputEventScreenTouch
	var drag := event as InputEventScreenDrag
	var click := event as InputEventMouseButton
	var motion := event as InputEventMouseMotion
	if touch != null:
		if touch.pressed:
			_down(touch.position, touch.index)
		elif touch.index == _pointer:
			_up(touch.position)
		accept_event()
	elif drag != null and drag.index == _pointer:
		_moved(drag.position)
		accept_event()
	elif click != null and click.button_index == MOUSE_BUTTON_LEFT:
		if click.pressed:
			_down(click.position, -1)
		elif _pointer == -1 and _press != "":
			_up(click.position)
		accept_event()
	elif motion != null and _pointer == -1 and _press != "":
		_moved(motion.position)
		accept_event()


func _down(pos: Vector2, pointer: int) -> void:
	if _press != "":
		return
	_press = region_at(pos)
	_pointer = pointer
	_moved(pos)
	queue_redraw()


func _moved(pos: Vector2) -> void:
	if _press.begins_with("p"):
		var i := int(_press.substr(1))
		value_changed.emit(i, value_at(i, pos.x))


func _up(pos: Vector2) -> void:
	var was := _press
	_press = ""
	_pointer = -1
	if was == "APPLY" and region_at(pos) == "APPLY":
		applied.emit()
	elif was == "CANCEL" and region_at(pos) == "CANCEL":
		cancelled.emit()
	queue_redraw()


# --- drawing ------------------------------------------------------------------

func _draw() -> void:
	var pts := Chamfer.chamfer_points(size, T.ROW_CUT, true, false, true, false)
	draw_colored_polygon(pts, T.PANEL_BG)
	var ring := pts.duplicate()
	ring.append(pts[0])
	draw_polyline(ring, T.PANEL_BORDER, T.BORDER, true)
	var ui: Font = Fonts.ui()
	var bold: Font = Fonts.ui("bold")
	var clock: Font = Fonts.clock()
	draw_string(ui, Vector2(T.PAD, RowList._baseline(ui, T.FS_LABEL, T.HEAD_H)), tool_name,
			HORIZONTAL_ALIGNMENT_LEFT, -1, T.FS_LABEL, T.COL_TAG)
	for i in props.size():
		var p: Dictionary = props[i]
		var r := row_rect(i)
		var live: bool = _press == "p%d" % i
		var base := r.position.y + RowList._baseline(ui, T.FS_BODY, r.size.y)
		draw_string(bold if live else ui, Vector2(T.PAD, base), p.label, HORIZONTAL_ALIGNMENT_LEFT, -1,
				T.FS_BODY, T.COL_CURSOR if live else T.COL_READY)
		# The track: a rule, a tick at each quarter, the zero tick taller.
		var tr := track_rect(i)
		var cy := r.get_center().y
		var inset := T.PAD + KNOB
		var x0 := tr.position.x + inset
		var x1 := tr.end.x - inset
		draw_line(Vector2(x0, cy), Vector2(x1, cy), T.COL_DIM, 1.0)
		for k in 9:
			var tx := x0 + float(k) / 8.0 * (x1 - x0)
			var th := 7.0 if k == 4 else 3.0
			draw_line(Vector2(tx, cy - th), Vector2(tx, cy + th), T.COL_WAIT, 1.0)
		# The value as a fill from zero, then the knob on top.
		var zx := x0 + 0.5 * (x1 - x0)
		var kx := knob_x(i)
		draw_line(Vector2(zx, cy), Vector2(kx, cy), T.COL_READY, 3.0)
		draw_rect(Rect2(kx - KNOB * 0.5, cy - KNOB * 0.5, KNOB, KNOB), T.COL_CURSOR if live else T.COL_NAME, true)
		# The number, in the clock face, its unit in the ui face.
		var txt: String = ("%+." + str(p.get("decimals", 2)) + "f") % p.value
		var unit: String = p.get("unit", "")
		var uw := ui.get_string_size(unit, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FS_HINT).x if unit != "" else 0.0
		var vw := clock.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FS_ROW).x
		var vx := size.x - T.PAD - uw - vw
		draw_string(clock, Vector2(vx, r.position.y + RowList._baseline(clock, T.FS_ROW, r.size.y)), txt,
				HORIZONTAL_ALIGNMENT_LEFT, -1, T.FS_ROW, T.COL_NAME)
		if unit != "":
			draw_string(ui, Vector2(vx + vw, base), unit, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FS_HINT, T.COL_TAG)
	# APPLY and CANCEL as rows; the one under a finger reads as the cursor.
	for b in ["APPLY", "CANCEL"]:
		var br := button_rect(b)
		var f := bold if _press == b else ui
		var col := T.COL_CURSOR if _press == b else T.COL_READY
		var w := f.get_string_size(b, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FS_BODY).x
		draw_string(f, Vector2(br.get_center().x - w * 0.5, br.position.y + RowList._baseline(f, T.FS_BODY, br.size.y)),
				b, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FS_BODY, col)
		if _press == b:
			Chamfer.draw_cursor_box(self, br.grow_individual(-T.PAD, -T.SEL_PAD_Y, -T.PAD, -T.SEL_PAD_Y), T.COL_CURSOR)
