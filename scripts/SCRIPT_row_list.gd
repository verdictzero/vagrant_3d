class_name RowList
extends Control
## A list of rows in the house style: no buttons, only rows. One floating
## cursor box marks the active row; other selected rows brighten. Rows run
## down (a panel, a menu) or across (a bar). A press-and-hold or a sideways
## drag lifts a row for the hierarchy's drag-to-parent.
##
## Items, every key but id and text optional:
##   id, text, icon (an Icons glyph), depth, tree (bools: which ancestor
##   levels keep a line running past this row), last (last child of its
##   parent), disabled, heading (a section label, not a row), value (text at
##   the right), value_clock (the value is a number: clock face), on (true /
##   false draws a lit / unlit mark at the right), lit (a bar toggle that is
##   on).

const T := preload("res://scripts/SCRIPT_ui_tokens.gd")
const Chamfer := preload("res://scripts/SCRIPT_chamfer_panel.gd")

signal tapped(id: Variant)
signal drag_dropped(from_id: Variant, to_id: Variant)   # to_id null: dropped on nothing

@export var horizontal := false
@export var draggable := false
@export var font_size: int = T.FS_BODY
@export var indent := 16.0

var items: Array[Dictionary] = []
var active: Variant = null          # id under the cursor box
var selected: Dictionary = {}       # id -> true, brightened rows

const HOLD := 0.3
const SLOP := 14.0
const REACH := 5.0
const MARK := 8.0

var _press_id: Variant = null
var _press_pos := Vector2.ZERO
var _press_time := 0.0
var _press_pointer := -1            # touch index, or -1 for the pen/mouse
var _dragging := false
var _drag_pos := Vector2.ZERO
var _box_rect := Rect2()
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

func row_height(i: int) -> float:
	return float(T.HEAD_H) if items[i].get("heading", false) else float(T.ROW_H)


func row_rect(i: int) -> Rect2:
	if horizontal:
		var x := 0.0
		for k in i:
			x += row_width(k)
		return Rect2(x, 0.0, row_width(i), T.ROW_H)
	var y := 0.0
	for k in i:
		y += row_height(k)
	return Rect2(0.0, y, size.x, row_height(i))


## Across: the content, centred, with PAD either side.
func row_width(i: int) -> float:
	return _content_width(items[i]) + T.PAD * 2


func _content_width(it: Dictionary) -> float:
	var f: Font = Fonts.ui()
	var w: float = f.get_string_size(it.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	if it.has("icon"):
		w += T.ICON + T.ICON_GAP
	return w


## The whole list's natural size.
func content_size() -> Vector2:
	if items.is_empty():
		return Vector2.ZERO
	var last := row_rect(items.size() - 1)
	return Vector2(last.end.x, T.ROW_H) if horizontal else Vector2(size.x, last.end.y)


## The row at `pos` (local), or the nearest within REACH; -1 for none.
func row_at(pos: Vector2) -> int:
	var best := -1
	var best_d := INF
	for i in items.size():
		if items[i].get("heading", false):
			continue
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
		var r := row_rect(i).grow_individual(-T.SEL_PAD_X, -T.SEL_PAD_Y, -T.SEL_PAD_X, -T.SEL_PAD_Y)
		if not _box_live:
			_box_rect = r
			_box_live = true
			queue_redraw()
		var k := 1.0 - exp(-delta / (T.TRAVEL * 0.35))
		var before := _box_rect
		_box_rect = Rect2(_box_rect.position.lerp(r.position, k), _box_rect.size.lerp(r.size, k))
		if before != _box_rect:
			queue_redraw()
	elif _box_live:
		_box_live = false
		queue_redraw()


# --- drawing ------------------------------------------------------------------

func _draw() -> void:
	var font: Font = Fonts.ui()
	var bold: Font = Fonts.ui("bold")
	if _box_live:
		Chamfer.draw_cursor_box(self, _box_rect, T.COL_CURSOR)
	for i in items.size():
		var it := items[i]
		var r := row_rect(i)
		if it.get("heading", false):
			var hy := r.position.y + _baseline(font, T.FS_LABEL, r.size.y)
			draw_string(font, Vector2(T.PAD, hy), it.text, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FS_LABEL, T.COL_TAG)
			continue
		var disabled: bool = it.get("disabled", false)
		var col := T.COL_READY
		var f := font
		if disabled:
			col = T.COL_DIM
		elif it.id == active:
			col = T.COL_CURSOR
			f = bold
		elif selected.has(it.id) or it.get("lit", false):
			col = T.COL_NAME
		if _dragging and it.id == _press_id:
			col = T.COL_WAIT
		var depth := int(it.get("depth", 0))
		var x := r.position.x + T.PAD + depth * indent
		if horizontal:
			x = r.position.x + (r.size.x - _content_width(it)) * 0.5
		if depth > 0:
			_draw_tree(it, r, depth)
		if it.has("icon"):
			var ir := Rect2(x, r.position.y + (r.size.y - T.ICON) * 0.5, T.ICON, T.ICON)
			Icons.draw(self, it.icon, ir, col)
			x += T.ICON + T.ICON_GAP
		var y := r.position.y + _baseline(f, font_size, r.size.y)
		draw_string(f, Vector2(x, y), it.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, col)
		if disabled:
			var w := f.get_string_size(it.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			var sy := y - font_size * 0.3
			draw_line(Vector2(x, sy), Vector2(x + w, sy), T.COL_DIM, 1.0)
		if it.get("lit", false) and horizontal:
			draw_rect(Rect2(r.get_center().x - 3.0, r.end.y - 5.0, 6.0, 3.0), T.COL_NAME, true)
		# The right-hand side: a value, or an on/off mark.
		var rx := r.end.x - T.PAD
		if it.has("value"):
			var vf: Font = Fonts.clock() if it.get("value_clock", false) else font
			var vs: int = font_size + 2 if it.get("value_clock", false) else font_size
			var vw := vf.get_string_size(it.value, HORIZONTAL_ALIGNMENT_LEFT, -1, vs).x
			draw_string(vf, Vector2(rx - vw, r.position.y + _baseline(vf, vs, r.size.y)), it.value,
					HORIZONTAL_ALIGNMENT_LEFT, -1, vs, T.COL_DIM if disabled else T.COL_NAME)
		elif it.has("on"):
			var m := Rect2(rx - MARK, r.get_center().y - MARK * 0.5, MARK, MARK)
			if it.on:
				draw_rect(m, T.COL_DIM if disabled else T.COL_NAME, true)
			else:
				draw_rect(m, T.COL_DIM, false, 1.0)
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


## The baseline that centres a line of `size` text in a row `h` tall.
static func _baseline(f: Font, size: int, h: float) -> float:
	var asc := f.get_ascent(size)
	var desc := f.get_descent(size)
	return (h + asc - desc) * 0.5


## The |_ that says "child of the row above": a line down from the parent's
## column to this row's middle, then across to its icon, with the parent's
## line carried on past when more siblings follow.
func _draw_tree(it: Dictionary, r: Rect2, depth: int) -> void:
	var tree: Array = it.get("tree", [])
	var mid := r.get_center().y
	for k in depth:
		var lx := r.position.x + T.PAD + k * indent + 5.0
		if k == depth - 1:
			var bottom: float = mid if it.get("last", false) else r.end.y
			draw_line(Vector2(lx, r.position.y), Vector2(lx, bottom), T.COL_WAIT, 1.0)
			draw_line(Vector2(lx, mid), Vector2(lx + indent - 7.0, mid), T.COL_WAIT, 1.0)
		elif k < tree.size() and tree[k]:
			draw_line(Vector2(lx, r.position.y), Vector2(lx, r.end.y), T.COL_WAIT, 1.0)
