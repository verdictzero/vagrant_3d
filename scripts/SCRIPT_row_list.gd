class_name RowList
extends Control
## A list of rows in the house style: no buttons, only rows. One floating
## cursor box marks the active row; other selected rows brighten. Rows can be
## laid out down (a panel) or across (a mode bar). A press-and-hold or a
## sideways-free drag lifts a row for the hierarchy's drag-to-parent.
##
## Items: { id, text, depth = 0, disabled = false }.

const T := preload("res://scripts/SCRIPT_ui_tokens.gd")
const Chamfer := preload("res://scripts/SCRIPT_chamfer_panel.gd")

signal tapped(id: Variant)
signal drag_dropped(from_id: Variant, to_id: Variant)   # to_id null: dropped on nothing

@export var horizontal := false
@export var draggable := false
@export var font_size: int = T.FS_BODY
@export var indent := 18.0

var items: Array[Dictionary] = []
var active: Variant = null          # id under the cursor box
var selected: Dictionary = {}       # id -> true, brightened rows

const HOLD := 0.3
const SLOP := 14.0
const REACH := 6.0

var _press_id: Variant = null
var _press_pos := Vector2.ZERO
var _press_time := 0.0
var _press_pointer := -1            # touch index, or -1 for the pen/mouse
var _dragging := false
var _drag_pos := Vector2.ZERO
var _box_rect := Rect2()
var _box_target := Rect2()
var _box_live := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(true)


func set_items(list: Array[Dictionary]) -> void:
	items = list
	queue_redraw()


func set_active(id: Variant) -> void:
	active = id
	queue_redraw()


func set_selected(ids: Dictionary) -> void:
	selected = ids
	queue_redraw()


# --- geometry -----------------------------------------------------------------

func row_rect(i: int) -> Rect2:
	if horizontal:
		var x := 0.0
		for k in i:
			x += _row_width(k)
		return Rect2(x, 0.0, _row_width(i), T.ROW_H)
	return Rect2(0.0, i * T.ROW_H, size.x, T.ROW_H)


func _row_width(i: int) -> float:
	var f: Font = Fonts.ui()
	return f.get_string_size(items[i].text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + T.PAD * 2


## The row at `pos` (local), or the nearest within REACH; -1 for none.
func row_at(pos: Vector2) -> int:
	var best := -1
	var best_d := INF
	for i in items.size():
		var r := row_rect(i)
		var d := maxf(maxf(r.position.x - pos.x, pos.x - r.end.x),
				maxf(r.position.y - pos.y, pos.y - r.end.y))
		d = maxf(d, 0.0)
		if d <= REACH and d < best_d:
			best_d = d
			best = i
	return best


func index_of(id: Variant) -> int:
	for i in items.size():
		if items[i].id == id:
			return i
	return -1


# --- input --------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	var touch := event as InputEventScreenTouch
	var drag := event as InputEventScreenDrag
	var click := event as InputEventMouseButton
	var motion := event as InputEventMouseMotion
	if touch != null:
		if touch.pressed:
			_press(touch.position, touch.index)
		elif touch.index == _press_pointer:
			_release(touch.position)
		accept_event()
	elif drag != null and drag.index == _press_pointer:
		_move(drag.position)
		accept_event()
	elif click != null and click.button_index == MOUSE_BUTTON_LEFT:
		if click.pressed:
			_press(click.position, -1)
		elif _press_pointer == -1 and _press_id != null:
			_release(click.position)
		accept_event()
	elif motion != null and _press_pointer == -1 and _press_id != null:
		_move(motion.position)
		accept_event()


func _press(pos: Vector2, pointer: int) -> void:
	if _press_id != null:
		return
	var i := row_at(pos)
	if i < 0 or items[i].get("disabled", false):
		return
	_press_id = items[i].id
	_press_pos = pos
	_press_time = 0.0
	_press_pointer = pointer
	_dragging = false
	_drag_pos = pos


func _move(pos: Vector2) -> void:
	_drag_pos = pos
	if draggable and not _dragging and pos.distance_to(_press_pos) > SLOP:
		_dragging = true
	queue_redraw()


func _release(pos: Vector2) -> void:
	var id: Variant = _press_id
	_press_id = null
	_press_pointer = -1
	if _dragging:
		_dragging = false
		var i := row_at(pos)
		var to: Variant = items[i].id if i >= 0 else null
		if to != id:
			drag_dropped.emit(id, to)
	else:
		tapped.emit(id)
	queue_redraw()


func _process(delta: float) -> void:
	if _press_id != null and draggable and not _dragging:
		_press_time += delta
		if _press_time >= HOLD:
			_dragging = true
			queue_redraw()
	# The cursor box flies to its row rather than jumping.
	var i := index_of(active)
	if i >= 0:
		var r := row_rect(i).grow_individual(0, T.SEL_PAD_Y, 0, T.SEL_PAD_Y)
		r = r.grow_individual(-T.SEL_PAD_X, 0, -T.SEL_PAD_X, 0) if horizontal \
				else r.grow_individual(-T.SEL_PAD_X * 0.5, 0, -T.SEL_PAD_X * 0.5, 0)
		if not _box_live:
			_box_rect = r
			_box_live = true
			queue_redraw()
		_box_target = r
		var k := 1.0 - exp(-delta / (T.TRAVEL * 0.35))
		var before := _box_rect
		_box_rect = Rect2(_box_rect.position.lerp(r.position, k), _box_rect.size.lerp(r.size, k))
		if before != _box_rect:
			queue_redraw()
	else:
		_box_live = false


# --- drawing ------------------------------------------------------------------

func _draw() -> void:
	var font: Font = Fonts.ui()
	var bold: Font = Fonts.ui("bold")
	if _box_live:
		Chamfer.draw_cursor_box(self, _box_rect, T.COL_CURSOR)
	for i in items.size():
		var it := items[i]
		var r := row_rect(i)
		var disabled: bool = it.get("disabled", false)
		var col := T.COL_READY
		var f := font
		if disabled:
			col = T.COL_DIM
		elif it.id == active:
			col = T.COL_CURSOR
			f = bold
		elif selected.has(it.id):
			col = T.COL_NAME
		if _dragging and it.id == _press_id:
			col = T.COL_WAIT
		var x := r.position.x + T.PAD + float(it.get("depth", 0)) * indent
		var y := r.position.y + (r.size.y + font_size * 0.7) * 0.5
		draw_string(f, Vector2(x, y), it.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, col)
		if disabled:
			var w := f.get_string_size(it.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			var sy := y - font_size * 0.3
			draw_line(Vector2(x, sy), Vector2(x + w, sy), T.COL_DIM, 1.0)
	if _dragging:
		# The drop target gets a WAIT box; the lifted row rides the pointer.
		var over := row_at(_drag_pos)
		if over >= 0 and items[over].id != _press_id:
			Chamfer.draw_cursor_box(self, row_rect(over).grow(-2.0), T.COL_WAIT, Color(0, 0, 0, 0))
		var pi := index_of(_press_id)
		if pi >= 0:
			var gy := _drag_pos.y + font_size * 0.35
			draw_string(bold, Vector2(T.PAD, gy), items[pi].text, HORIZONTAL_ALIGNMENT_LEFT,
					-1, font_size, T.COL_CURSOR)
