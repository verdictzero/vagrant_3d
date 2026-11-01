class_name MatcapGrid
extends Control
## The matcap gallery: a grid of the built-in matcaps, each drawn as an
## octagon cut out of its sphere image. The cursor box marks the one in use.

const T := preload("res://scripts/SCRIPT_ui_tokens.gd")
const Chamfer := preload("res://scripts/SCRIPT_chamfer_panel.gd")

signal picked(index: int)

const COLS := 4
const CELL := 60.0
const GAP := 8.0

var active := 0
var _press := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = grid_size()
	size = grid_size()


static func grid_size() -> Vector2:
	var rows := ceili(float(Matcaps.count()) / float(COLS))
	return Vector2(COLS * CELL + (COLS - 1) * GAP, rows * CELL + (rows - 1) * GAP)


func cell_rect(i: int) -> Rect2:
	@warning_ignore("integer_division")
	var r := i / COLS
	var c := i % COLS
	return Rect2(c * (CELL + GAP), r * (CELL + GAP), CELL, CELL)


func cell_at(pos: Vector2) -> int:
	for i in Matcaps.count():
		if cell_rect(i).grow(GAP * 0.5).has_point(pos):
			return i
	return -1


func set_active(i: int) -> void:
	active = i
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var touch := event as InputEventScreenTouch
	var click := event as InputEventMouseButton
	var pos := Vector2.ZERO
	var pressed := false
	var is_press_event := false
	if touch != null:
		pos = touch.position
		pressed = touch.pressed
		is_press_event = true
	elif click != null and click.button_index == MOUSE_BUTTON_LEFT:
		pos = click.position
		pressed = click.pressed
		is_press_event = true
	if not is_press_event:
		return
	accept_event()
	if pressed:
		_press = cell_at(pos)
	elif _press >= 0:
		var i := cell_at(pos)
		if i == _press:
			picked.emit(i)
		_press = -1


func _draw() -> void:
	for i in Matcaps.count():
		var r := cell_rect(i)
		var tex := Matcaps.texture(i)
		var pts := PackedVector2Array()
		var uvs := PackedVector2Array()
		for k in range(0, Icons.OCT.size(), 2):
			var u := Vector2(Icons.OCT[k], Icons.OCT[k + 1])
			pts.append(r.position + u * r.size)
			uvs.append(u)
		if tex != null:
			var cols := PackedColorArray()
			cols.resize(pts.size())
			cols.fill(Color.WHITE)
			draw_polygon(pts, cols, uvs, tex)
		else:
			draw_colored_polygon(pts, T.COL_DIM)
		var ring := pts.duplicate()
		ring.append(pts[0])
		draw_polyline(ring, T.COL_CURSOR if i == active else T.COL_WAIT, 1.0, true)
		if i == active:
			Chamfer.draw_cursor_box(self, r.grow(3.0), T.COL_CURSOR, Color(0, 0, 0, 0))
