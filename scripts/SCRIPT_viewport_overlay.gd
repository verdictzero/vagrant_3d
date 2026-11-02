class_name ViewportOverlay
extends Control
## Everything drawn over the 3D view: wires, selection, hover, the box, the
## snap mark, group markers, the status line. It reads the editor's state
## each frame and draws nothing of its own. Depth is ignored on purpose: this
## is the x-ray wire.

const T := preload("res://scripts/SCRIPT_ui_tokens.gd")

var editor: Node   # SCRIPT_editor.gd

const DOT := 3.0
const SEL_DOT := 7.0
const HOVER_DOT := 5.0
const GROUP_AXIS := 0.5


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if editor == null:
		return
	var cam: Camera3D = editor.camera()
	_draw_groups(cam)
	if editor.mode == editor.Mode.OBJECT:
		_draw_object_mode(cam)
	else:
		_draw_edit_mode(cam)
	editor.gizmo_draw(self)
	if editor.box_active:
		var r: Rect2 = editor.box_rect()
		draw_rect(r, T.SEL_BG, true)
		draw_rect(r, T.COL_CURSOR, false, 1.0)
	if not editor.snap_hit.is_empty():
		var w: Vector3 = editor.snap_hit.point
		if not cam.is_position_behind(w):
			var p := cam.unproject_position(w)
			draw_rect(Rect2(p - Vector2(7, 7), Vector2(14, 14)), T.KEYLINE, false, 3.0)
			draw_rect(Rect2(p - Vector2(7, 7), Vector2(14, 14)), T.COL_CURSOR, false, 1.5)
	if editor.pen_hover_valid:
		var p: Vector2 = editor.pen_hover_pos
		draw_line(p + Vector2(-10, 0), p + Vector2(-3, 0), T.COL_NAME, 1.0)
		draw_line(p + Vector2(3, 0), p + Vector2(10, 0), T.COL_NAME, 1.0)
		draw_line(p + Vector2(0, -10), p + Vector2(0, -3), T.COL_NAME, 1.0)
		draw_line(p + Vector2(0, 3), p + Vector2(0, 10), T.COL_NAME, 1.0)
	_draw_status()
	_draw_flash()


## A message over the top of the view that fades out over its last second.
func _draw_flash() -> void:
	var left: int = editor.flash_until - Time.get_ticks_msec()
	if left <= 0 or editor.flash_text == "":
		return
	var view: Rect2 = editor.view_rect
	var f: Font = Fonts.ui()
	var a := clampf(float(left) / 1000.0, 0.0, 1.0)
	var col := Color(T.COL_BRIGHT, a)
	var w := f.get_string_size(editor.flash_text, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FS_ROW).x
	var at := Vector2(view.get_center().x - w * 0.5, view.position.y + 34.0)
	draw_string_outline(f, at, editor.flash_text, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FS_ROW, 4, Color(0, 0, 0, a))
	draw_string(f, at, editor.flash_text, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FS_ROW, col)


## Groups have no mesh: they show as plain axes at their origin, lit when
## selected.
func _draw_groups(cam: Camera3D) -> void:
	for o in editor.objects():
		if not o.is_group:
			continue
		var col := T.COL_DIM
		var w := 1.0
		if o == editor.active_object:
			col = T.COL_CURSOR
			w = 1.5
		elif editor.sel_objects.has(o):
			col = T.COL_READY
		elif o == editor.hover_object:
			col = T.COL_TAG
		var xf: Transform3D = o.global_transform
		for axis in [Vector3.RIGHT, Vector3.UP, Vector3.BACK]:
			var a: Vector3 = xf * (axis * -GROUP_AXIS)
			var b: Vector3 = xf * (axis * GROUP_AXIS)
			if cam.is_position_behind(a) or cam.is_position_behind(b):
				continue
			draw_line(cam.unproject_position(a), cam.unproject_position(b), col, w)


func _draw_object_mode(cam: Camera3D) -> void:
	var hover: Variant = editor.hover_object
	if hover != null and is_instance_valid(hover) and not editor.sel_objects.has(hover):
		_draw_wire(cam, hover, T.COL_TAG, 1.0)
	for o in editor.sel_objects:
		if o == editor.active_object:
			continue
		_draw_wire(cam, o, T.COL_READY, 1.0)
	if editor.active_object != null:
		_draw_wire(cam, editor.active_object, T.COL_CURSOR, 1.5)


func _draw_wire(cam: Camera3D, o: SceneObject, col: Color, width: float) -> void:
	var xf := o.global_transform
	for e in o.data.edges:
		var a := xf * o.data.verts[e.x]
		var b := xf * o.data.verts[e.y]
		if cam.is_position_behind(a) or cam.is_position_behind(b):
			continue
		draw_line(cam.unproject_position(a), cam.unproject_position(b), col, width)


func _draw_edit_mode(cam: Camera3D) -> void:
	var o: SceneObject = editor.active_object
	if o == null:
		return
	var d := o.data
	var xf := o.global_transform
	var pts := PackedVector2Array()
	var ok := PackedByteArray()
	pts.resize(d.verts.size())
	ok.resize(d.verts.size())
	for i in d.verts.size():
		var w := xf * d.verts[i]
		ok[i] = 0 if cam.is_position_behind(w) else 1
		pts[i] = cam.unproject_position(w) if ok[i] else Vector2.ZERO
	# Faces first (fills), then edges, then verts, so the bright marks sit on top.
	if editor.elem == editor.Elem.FACE:
		for f in d.faces.size():
			var sel: bool = editor.sel_faces.has(f)
			var hov: bool = editor.hover_kind == editor.Elem.FACE and editor.hover_index == f
			if not sel and not hov:
				continue
			var poly := PackedVector2Array()
			var vis := true
			for i in d.faces[f]:
				if not ok[i]:
					vis = false
					break
				poly.append(pts[i])
			if vis and poly.size() >= 3:
				draw_colored_polygon(poly, T.SEL_BG if sel else Color(1, 1, 1, 0.05))
	for e in d.edges.size():
		var ed := d.edges[e]
		if not ok[ed.x] or not ok[ed.y]:
			continue
		var col := T.COL_DIM
		var w := 1.0
		if editor.sel_edges.has(e):
			col = T.COL_CURSOR
			w = 2.0
		elif editor.hover_kind == editor.Elem.EDGE and editor.hover_index == e:
			col = T.COL_TAG
			w = 2.0
		draw_line(pts[ed.x], pts[ed.y], col, w)
	var show_dots: bool = editor.elem == editor.Elem.VERT
	for i in d.verts.size():
		if not ok[i]:
			continue
		if editor.sel_verts.has(i):
			_dot(pts[i], SEL_DOT, T.COL_CURSOR)
		elif show_dots and editor.hover_kind == editor.Elem.VERT and editor.hover_index == i:
			_dot(pts[i], HOVER_DOT, T.COL_TAG)
		elif show_dots:
			_dot(pts[i], DOT, T.COL_WAIT)


func _dot(p: Vector2, s: float, col: Color) -> void:
	draw_rect(Rect2(p - Vector2(s, s) * 0.5, Vector2(s, s)), col, true)


func _draw_status() -> void:
	var view: Rect2 = editor.view_rect
	var ui: Font = Fonts.ui()
	var clock: Font = Fonts.clock()
	var y := view.end.y - 10.0
	var x := view.position.x + 8.0
	var words: String = editor.status_words()
	draw_string(ui, Vector2(x, y), words, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FS_HINT, T.COL_TAG)
	var counts: Array = editor.status_counts()   # [["V", 8], ["E", "04/12"], ...]
	var rx := view.end.x - 8.0
	for i in range(counts.size() - 1, -1, -1):
		var v = counts[i][1]
		var num: String = v if v is String else "%03d" % int(v)
		var nw := clock.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FS_BODY).x
		rx -= nw
		draw_string(clock, Vector2(rx, y), num, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FS_BODY, T.COL_NAME)
		var tag: String = counts[i][0]
		var tw := ui.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FS_HINT).x
		rx -= tw + 4.0
		draw_string(ui, Vector2(rx, y), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FS_HINT, T.COL_TAG)
		rx -= 16.0
