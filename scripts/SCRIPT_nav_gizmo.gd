class_name NavGizmo
extends Control
## The axes ball in the view's corner: the three axes as the camera sees
## them, positive ends lettered and filled, negative ends hollow. Tap an
## end to look from there; drag the ball to orbit.

const T := preload("res://scripts/SCRIPT_ui_tokens.gd")

signal axis_tapped(axis: Vector3)
signal orbited(delta: Vector2)

const SIZE := 120.0
const R := 42.0
const END := 20.0
const HIT := 16.0
const SLOP := 6.0

var camera: Camera3D
var hover_axis := Vector3.ZERO

var _press_pos := Vector2.ZERO
var _pressed := false
var _dragging := false
var _last := Vector2.ZERO
var _pointer := -1

const AXES := [Vector3.RIGHT, Vector3.UP, Vector3.BACK, Vector3.LEFT, Vector3.DOWN, Vector3.FORWARD]
const LETTERS := {Vector3.RIGHT: "X", Vector3.UP: "Y", Vector3.BACK: "Z"}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	size = Vector2(SIZE, SIZE)


func _process(_delta: float) -> void:
	queue_redraw()


## Where an axis end sits on the ball, and how deep it is (positive = toward
## the camera).
func end_point(axis: Vector3) -> Array:
	var inv := camera.global_basis.inverse()
	var v := inv * axis
	return [size * 0.5 + Vector2(v.x, -v.y) * R, v.z]


func axis_at(pos: Vector2) -> Vector3:
	var best := Vector3.ZERO
	var best_d := HIT
	var best_z := -INF
	for a in AXES:
		var e := end_point(a)
		var d: float = e[0].distance_to(pos)
		# Nearer ends win ties, as they are drawn on top.
		if d <= HIT and (d < best_d or (absf(d - best_d) < 2.0 and e[1] > best_z)):
			best = a
			best_d = d
			best_z = e[1]
	return best


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
		elif _pointer == -1 and _pressed:
			_up(click.position)
		accept_event()
	elif motion != null:
		if _pressed and _pointer == -1:
			_moved(motion.position)
		else:
			hover_axis = axis_at(motion.position)
		accept_event()


func _down(pos: Vector2, pointer: int) -> void:
	if _pressed:
		return
	_pressed = true
	_pointer = pointer
	_press_pos = pos
	_last = pos
	_dragging = false


func _moved(pos: Vector2) -> void:
	if not _dragging and pos.distance_to(_press_pos) > SLOP:
		_dragging = true
	if _dragging:
		orbited.emit(pos - _last)
	_last = pos


func _up(pos: Vector2) -> void:
	_pressed = false
	_pointer = -1
	if not _dragging:
		var a := axis_at(pos)
		if a != Vector3.ZERO:
			axis_tapped.emit(a)
	_dragging = false


func _draw() -> void:
	if camera == null:
		return
	var c := size * 0.5
	var bold: Font = Fonts.ui("bold")
	# Far ends first, so the near ones sit on top.
	var order := AXES.duplicate()
	order.sort_custom(func(a, b): return end_point(a)[1] < end_point(b)[1])
	for a in order:
		var e := end_point(a)
		var p: Vector2 = e[0]
		var near: float = clampf((e[1] + 1.0) * 0.5, 0.0, 1.0)   # 0 far, 1 near
		var positive := LETTERS.has(a)
		var col := T.COL_NAME.lerp(T.COL_WAIT, 1.0 - near)
		if a == hover_axis:
			col = T.COL_CURSOR
		var box := Rect2(p - Vector2(END, END) * 0.5, Vector2(END, END))
		if positive:
			draw_line(c, p, T.COL_TAG.lerp(T.COL_DIM, 1.0 - near), 1.5, true)
			draw_rect(box, col, true)
			var letter: String = LETTERS[a]
			var w := bold.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FS_HINT).x
			draw_string(bold, Vector2(p.x - w * 0.5, p.y + T.FS_HINT * 0.36), letter,
					HORIZONTAL_ALIGNMENT_LEFT, -1, T.FS_HINT, Color.BLACK)
		else:
			draw_rect(box.grow(-3.0), col, false, 1.5)
