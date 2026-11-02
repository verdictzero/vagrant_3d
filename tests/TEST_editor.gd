extends SceneTree
## Headless: the editor from events alone. Primitives land in the hierarchy,
## a row dragged onto another parents under it, pen taps pick objects, verts,
## edges and faces, MOVE moves them, fingers orbit and pinch, and DELETE
## does what it says in both modes.
## Run: godot --headless --path . --script res://tests/TEST_editor.gd

const SCENE := "res://scenes/SCENE_editor.tscn"
const SETTLE := 3

var fails := 0
var ed: Node


func ok(cond: bool, msg: String) -> void:
	print(("  PASS  " if cond else "  FAIL  ") + msg)
	if not cond:
		fails += 1


func _initialize() -> void:
	# Headless opens a 64x64 window. Ignoring the aspect makes the canvas the
	# 1280x720 design space; events go in already in those coordinates.
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	ed = (load(SCENE) as PackedScene).instantiate()
	root.add_child(ed)
	await _settle()
	ok(root.get_visible_rect().size == Vector2(1600, 900), "the canvas is 1600x900 (%s)" % root.get_visible_rect().size)
	ok(ed.view_rect.end.x < ed.hierarchy.global_position.x and ed.view_rect.position.y > ed.top_panel.size.y,
			"the view sits left of the hierarchy, under the bar (%s)" % ed.view_rect)
	ok(ed.view_rect.end.y <= 900 and ed.view_rect.position.x >= 12, "and inside the canvas")
	ok(ed.snap_on and ed.snap_targets.INCREMENT and ed.snap_absolute, "snapping is on by default: increment, absolute grid")
	ok(ed.view_rect.position.x > ed.toolbar.global_position.x + 40, "the tool column sits left of the view")
	ok(absf(ed.right_panel.size.y - ed.props_panel.size.y) < 1.0 and ed.props_panel.position.y > ed.right_panel.position.y + ed.right_panel.size.y,
			"the hierarchy and the properties split the right column")
	ok(ed.view_rect.encloses(Rect2(ed.gizmo.position, ed.gizmo.size)), "the axes ball is inside the view")
	for l in [ed.mode_list, ed.elem_list, ed.add_bar, ed.toggle_list]:
		var centred := true
		for i in l.items.size():
			var r: Rect2 = l.row_rect(i)
			centred = centred and absf(r.size.x - (l._content_width(l.items[i]) + 24.0)) < 0.5
		ok(centred, "bar rows are their content plus equal padding either side")
	await _hierarchy()
	await _pen_picks()
	await _edit_picks()
	await _move()
	await _snap()
	await _tools()
	await _transform()
	await _fingers()
	await _rows_by_touch()
	await _popovers()
	await _view()
	await _delete()
	await _groups()
	await _scroll()
	await _new_tools()
	await _history()
	await _scrub_and_keys()
	await _gizmos()
	await _loopcut_and_duplicate()
	await _select_menu()
	await _files()
	print("editor: %d failure(s)" % fails)
	quit(1 if fails > 0 else 0)


func _settle() -> void:
	for i in SETTLE:
		await process_frame


# --- events --------------------------------------------------------------------

func _pen(pos: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = pos
	e.global_position = pos
	if pressed:
		e.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(e, true)


func _pen_move(from: Vector2, to: Vector2, down: bool) -> void:
	var e := InputEventMouseMotion.new()
	e.position = to
	e.global_position = to
	e.relative = to - from
	if down:
		e.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(e, true)


func _pen_tap(pos: Vector2) -> void:
	_pen(pos, true)
	_pen(pos, false)


func _pen_drag(from: Vector2, to: Vector2) -> void:
	_pen(from, true)
	var mid := from.lerp(to, 0.5)
	_pen_move(from, mid, true)
	_pen_move(mid, to, true)
	_pen(to, false)


func _finger(index: int, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = pos
	e.pressed = pressed
	root.push_input(e, true)


func _finger_move(index: int, from: Vector2, to: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = index
	e.position = to
	e.relative = to - from
	root.push_input(e, true)


func _screen(world: Vector3) -> Vector2:
	return ed.camera().unproject_position(world)


func _vert_screen(o: Node3D, i: int) -> Vector2:
	return _screen(o.global_transform * o.data.verts[i])


func _row_center(list: Control, i: int) -> Vector2:
	return list.global_position + list.row_rect(i).get_center()


# --- the checks ----------------------------------------------------------------

func _hierarchy() -> void:
	var a: Node3D = ed.add_primitive("CUBE")
	var b: Node3D = ed.add_primitive("CUBE")
	await _settle()
	ok(a.name == "Cube" and b.name == "Cube 001", "names run Cube, Cube 001 (%s, %s)" % [a.name, b.name])
	ok(ed.hierarchy.items.size() == 2, "two rows in the hierarchy")
	ok(ed.active_object == b and ed.sel_objects == [b], "the new object is selected and active")
	ok(ed.mode == ed.Mode.OBJECT, "adding lands in OBJECT mode")
	# Drag the second row onto the first with the pen: press, go sideways past
	# the slop, land on the target, release.
	b.global_position = Vector3(3, 0, 0)
	var from := _row_center(ed.hierarchy, 1)
	var to := _row_center(ed.hierarchy, 0)
	_pen(from, true)
	_pen_move(from, from + Vector2(30, 0), true)
	_pen_move(from + Vector2(30, 0), to, true)
	_pen(to, false)
	await _settle()
	ok(b.get_parent() == a, "Cube 001 dropped on Cube is its child")
	ok(ed.hierarchy.items[1].depth == 1, "and its row is indented")
	ok(ed.hierarchy.items[1].last and ed.hierarchy.items[1].tree == [false], "it is the last child, under a parent with no siblings after it")
	ok(ed.hierarchy.items[0].icon == &"mesh", "a mesh row carries the mesh glyph")
	ok(b.global_position.is_equal_approx(Vector3(3, 0, 0)), "it kept its place in the world")
	ok(not ed.reparent_object(a, b), "a parent cannot be dropped on its own child")
	ok(a.get_parent() == ed.world_root, "and stays where it was")
	# Dropped on nothing: back to the root.
	from = _row_center(ed.hierarchy, 1)
	to = ed.hierarchy.global_position + Vector2(40, ed.hierarchy.size.y - 20)
	_pen(from, true)
	_pen_move(from, from + Vector2(30, 0), true)
	_pen_move(from + Vector2(30, 0), to, true)
	_pen(to, false)
	await _settle()
	ok(b.get_parent() == ed.world_root, "dropped below the rows, it is back at the root")
	ok(ed.hierarchy.items[1].depth == 0, "and its row is flush")
	# A tap on a row selects.
	_pen_tap(_row_center(ed.hierarchy, 0))
	await _settle()
	ok(ed.active_object == a, "a tap on the first row makes Cube active")


func _pen_picks() -> void:
	var a: Node3D = ed.objects()[0]
	var b: Node3D = ed.objects()[1]
	b.global_position = Vector3(3, 0, 0)
	a.global_position = Vector3(-3, 0, 0)
	await _settle()
	_pen_tap(_screen(b.global_position))
	await _settle()
	ok(ed.active_object == b, "a pen tap on Cube 001 picks it")
	# The bottom-right corner: the top-right is the axes ball's.
	var empty := Vector2(ed.view_rect.end.x - 20, ed.view_rect.end.y - 60)
	ok(ed.pick_object(empty) == null, "the corner of the view is empty")
	_pen_tap(empty)
	await _settle()
	ok(ed.sel_objects.is_empty() and ed.active_object == null, "a pen tap on nothing clears")
	ok(ed.mode_list.items[1].disabled, "EDIT is disabled with nothing active")
	# Pen hover marks what it is over.
	_pen_move(empty, _screen(a.global_position), false)
	ok(ed.hover_object == a, "hovering Cube marks it")
	ok(ed.pen_hover_valid, "the pen crosshair is live inside the view")
	# A box around both origins selects both.
	var pa := _screen(a.global_position)
	var pb := _screen(b.global_position)
	var lo := Vector2(minf(pa.x, pb.x), minf(pa.y, pb.y)) - Vector2(40, 40)
	var hi := Vector2(maxf(pa.x, pb.x), maxf(pa.y, pb.y)) + Vector2(40, 40)
	_pen_drag(lo, hi)
	await _settle()
	ok(ed.sel_objects.size() == 2, "a box around both selects both (%d)" % ed.sel_objects.size())
	ok(not ed.box_active, "the box is gone after release")
	# Panels are not the view: a tap on the right column does not reach it.
	_pen_tap(Vector2(ed.hierarchy.global_position.x + 40, 400))
	await _settle()
	ok(ed.sel_objects.size() == 2, "a tap on the panel does not clear the view's selection")


func _edit_picks() -> void:
	var a: Node3D = ed.objects()[0]
	ed.select_object(a)
	ed.set_mode(ed.Mode.EDIT)
	await _settle()
	ok(ed.mode == ed.Mode.EDIT and not ed.elem_list.items[0].disabled, "EDIT mode, element rows live")
	# Verts.
	var p := _vert_screen(a, 2)
	_pen_tap(p)
	await _settle()
	ok(ed.sel_verts.has(2) and ed.sel_verts.size() == 1, "a pen tap on vertex 2 selects only it")
	ok(ed.sel_edges.is_empty() and ed.sel_faces.is_empty(), "one vertex implies no edge or face")
	# Edges: tap the middle of edge 0.
	ed.set_elem(ed.Elem.EDGE)
	var e0: Vector2i = a.data.edges[0]
	var mid := (_vert_screen(a, e0.x) + _vert_screen(a, e0.y)) * 0.5
	_pen_tap(mid)
	await _settle()
	ok(ed.sel_edges.has(0) and ed.sel_edges.size() == 1, "a tap on an edge's middle selects it")
	ok(ed.sel_verts.size() == 2, "and both its ends")
	# Faces: the face a ray through the object's centre hits first.
	ed.set_elem(ed.Elem.FACE)
	var centre := _screen(a.global_position)
	var f: int = ed.pick_face(centre)
	ok(f >= 0, "the cube's centre is on a face")
	_pen_tap(centre)
	await _settle()
	ok(ed.sel_faces.has(f) and ed.sel_faces.size() == 1, "a tap selects that face")
	ok(ed.sel_verts.size() == 4 and ed.sel_edges.size() == 4, "a quad is 4 verts and 4 edges")
	# A box in vertex mode around the whole cube takes every vertex.
	ed.set_elem(ed.Elem.VERT)
	var box := Rect2(_vert_screen(a, 0), Vector2.ZERO)
	for i in a.data.verts.size():
		box = box.expand(_vert_screen(a, i))
	# Dragged from the bottom-right, which is in the view; the top-left corner
	# of this cube's box is over the left column, where a press would be the
	# panel's.
	_pen_drag(box.end + Vector2(20, 20), box.position - Vector2(20, 20))
	await _settle()
	ok(ed.sel_verts.size() == 8, "a box around the cube selects all 8 (%d)" % ed.sel_verts.size())
	ok(ed.sel_faces.size() == 6, "and so all 6 faces")
	# Switching modes keeps the selection coherent.
	ed.set_elem(ed.Elem.EDGE)
	ok(ed.sel_edges.size() == 12, "edge mode shows the 12 edges of it")


func _move() -> void:
	var a: Node3D = ed.objects()[0]
	ed.snap_on = false
	ed.set_elem(ed.Elem.VERT)
	ed.pointer = ed.Pointer.MOVE
	var before: PackedVector3Array = a.data.verts.duplicate()
	var p := _vert_screen(a, 2)
	ed.select_verts({2: true})
	_pen_drag(p, p + Vector2(60, 0))
	await _settle()
	ok(a.data.verts[2] != before[2], "MOVE drags vertex 2")
	var others_still := true
	for i in before.size():
		if i != 2 and before[i] != a.data.verts[i]:
			others_still = false
	ok(others_still, "and only vertex 2")
	ok(a.data.vert_count() == 8, "the mesh keeps its 8 verts")
	var after := _vert_screen(a, 2)
	ok(absf(after.x - (p.x + 60)) < 2.0 and absf(after.y - p.y) < 2.0,
			"the vertex lands under the pen (%s vs %s)" % [after, p + Vector2(60, 0)])
	ok(ed.tool_live() and ed.tool_kind() == "TRANSLATE" and ed.tool_window.visible,
			"a MOVE drag puts the TRANSLATE numbers up")
	var vals: Array = ed.tool_values()
	ok((a.global_transform * a.data.verts[2] - a.global_transform * before[2]).is_equal_approx(Vector3(vals[0], vals[1], vals[2])),
			"and they are the world delta (%s)" % str(vals))
	# A tap in MOVE still selects.
	_pen_tap(_vert_screen(a, 5))
	await _settle()
	ok(ed.sel_verts.has(5) and ed.sel_verts.size() == 1, "a tap in MOVE picks vertex 5")
	ok(not ed.tool_live() and not ed.tool_window.visible, "and that tap applied the translate and took the window down")
	# Object mode: the parent moves and the child comes with it.
	ed.set_mode(ed.Mode.OBJECT)
	var b: Node3D = ed.objects()[1]
	ed.reparent_object(b, a)
	ed.select_object(a)
	var a0: Vector3 = a.global_position
	var b0: Vector3 = b.global_position
	var ap := _screen(a0)
	_pen_drag(ap, ap + Vector2(0, -80))
	await _settle()
	ok(a.global_position != a0, "MOVE drags the object")
	ok((b.global_position - a.global_position).is_equal_approx(b0 - a0), "its child keeps its offset")
	ed.pointer = ed.Pointer.SELECT
	ed.reparent_object(b, ed.world_root)
	ed.snap_on = true


func _on_grid(v: Vector3, step: float) -> bool:
	for c in [v.x, v.y, v.z]:
		var r: float = fmod(absf(c) + step * 0.5, step) - step * 0.5
		if absf(r) > 0.001:
			return false
	return true


func _snap() -> void:
	var a: Node3D = ed.objects()[0]
	var b: Node3D = ed.objects()[1]
	ed.orbit.distance = 8.0
	ed.orbit.target = Vector3.ZERO
	ed.orbit.apply()
	a.global_position = Vector3(-3, 0, 0)
	b.global_position = Vector3(3, 0, 0)
	ed.pointer = ed.Pointer.MOVE
	ed.select_object(a)
	await _settle()
	# Increment, absolute: wherever the pen lets go, the object is on the grid.
	var p := _screen(a.global_position)
	_pen_drag(p, p + Vector2(37, 11))
	await _settle()
	ok(a.global_position != Vector3(-3, 0, 0), "the drag moved Cube")
	ok(_on_grid(a.global_position, 0.25), "and left it on the 0.25 grid (%s)" % a.global_position)
	# Vertex: let go over a vertex of Cube 001 and the origin lands on it.
	ed.snap_targets.VERTEX = true
	var target: Vector3 = b.global_transform * b.data.verts[0]
	p = _screen(a.global_position)
	var q := _screen(target)
	_pen(p, true)
	_pen_move(p, p.lerp(q, 0.5), true)
	_pen_move(p.lerp(q, 0.5), q, true)
	ok(ed.snap_hit.get("kind", "") == "VERTEX", "held over a vertex, the snap mark is a vertex")
	_pen(q, false)
	await _settle()
	ok(a.global_position.is_equal_approx(target), "and Cube's origin lands on it (%s vs %s)" % [a.global_position, target])
	ok(ed.snap_hit.is_empty(), "the mark goes when the pen lifts")
	ed.snap_targets.VERTEX = false
	# Relative increment: the move is in steps, the position need not be on the grid.
	a.global_position = Vector3(-3.1, 0, 0)
	ed.snap_absolute = false
	p = _screen(a.global_position)
	_pen_drag(p, p + Vector2(37, 11))
	await _settle()
	ok(_on_grid(a.global_position - Vector3(-3.1, 0, 0), 0.25) and not _on_grid(a.global_position, 0.25),
			"relative increment moves in steps off the grid (%s)" % a.global_position)
	ed.snap_absolute = true
	# Off: free.
	ed.snap_on = false
	a.global_position = Vector3(-3, 0, 0)
	p = _screen(a.global_position)
	_pen_drag(p, p + Vector2(37, 11))
	await _settle()
	ok(not _on_grid(a.global_position, 0.25), "with snapping off the move is free (%s)" % a.global_position)
	ed.snap_on = true
	ed.pointer = ed.Pointer.SELECT
	a.global_position = Vector3(-3, 0, 0)


func _tools() -> void:
	var a: Node3D = ed.objects()[0]
	var b: Node3D = ed.objects()[1]
	ed.select_object(a)
	ed.set_mode(ed.Mode.EDIT)
	ed.set_elem(ed.Elem.FACE)
	ed.select_faces({1: true})   # the top
	await _settle()
	ok(ed.toolbar.index_of("EXTRUDE") >= 0 and ed.toolbar.index_of("EXTRUDE NORMALS") >= 0
			and ed.toolbar.index_of("ROTATE") >= 0, "in EDIT the tool column has ROTATE, EXTRUDE and EXTRUDE NORMALS")
	ok(not ed.toolbar.items[ed.toolbar.index_of("INSET")].disabled and not ed.toolbar.items[ed.toolbar.index_of("BEVEL")].disabled,
			"with a face selected INSET and BEVEL are live too")
	var p := _row_center(ed.toolbar, ed.toolbar.index_of("EXTRUDE"))
	_finger(0, p, true)
	_finger(0, p, false)
	await _settle()
	ok(ed.pointer == ed.Pointer.TOOL and ed.current_tool == "EXTRUDE", "a finger tap on EXTRUDE makes it the tool")
	ok(not ed.tool_job.is_empty() and ed.tool_window.visible, "and it starts: the window comes up")
	ok(ed.toolbar.active == "EXTRUDE", "the column's cursor box is on it")
	ok(a.data.face_count() == 10 and a.data.vert_count() == 12, "the top is extruded at zero (%d f, %d v)" % [a.data.face_count(), a.data.vert_count()])
	ok(ed.sel_faces.size() == 1 and ed.sel_verts.size() == 4, "the new top is the selection")
	ok(is_zero_approx(ed.tool_value()), "the amount starts at zero")
	ok(ed.tool_job.props.size() == 1 and ed.tool_job.props[0].label == "AMOUNT", "the window shows one property, AMOUNT")
	# Pull the slider.
	var kx: float = ed.tool_window.global_position.x + ed.tool_window.knob_x(0)
	var ky: float = ed.tool_window.global_position.y + ed.tool_window.row_rect(0).get_center().y
	_pen_drag(Vector2(kx, ky), Vector2(kx + 90.0, ky))
	await _settle()
	ok(ed.tool_value() > 0.0 and _on_grid(Vector3(ed.tool_value(), 0, 0), 0.25),
			"the slider pulls the amount in 0.25 steps (%.2f)" % ed.tool_value())
	var at_height := true
	for i in ed.sel_verts:
		at_height = at_height and is_equal_approx((a.global_transform * a.data.verts[i]).y, 1.0 + ed.tool_value())
	ok(at_height, "the new top sits at 1 + the amount")
	var apply: Vector2 = ed.tool_window.global_position + ed.tool_window.button_rect("APPLY").get_center()
	_pen_tap(apply)
	await _settle()
	ok(ed.tool_job.is_empty() and not ed.tool_window.visible, "APPLY closes the tool")
	ok(a.data.face_count() == 10, "and keeps the result")
	ok(ed.sel_faces.size() == 1, "with the new top still selected")
	# A drag in the view, still in TOOL, extrudes the selection again.
	var f: int = ed.sel_faces.keys()[0]
	var c := _screen(a.global_transform * a.data.face_center(f))
	_pen_drag(c, c + Vector2(80, 0))
	await _settle()
	ok(not ed.tool_job.is_empty() and a.data.face_count() == 14 and ed.tool_value() != 0.0,
			"a drag in the view extrudes again (%d f, %.2f)" % [a.data.face_count(), ed.tool_value()])
	var cancel: Vector2 = ed.tool_window.global_position + ed.tool_window.button_rect("CANCEL").get_center()
	_pen_tap(cancel)
	await _settle()
	ok(ed.tool_job.is_empty() and a.data.face_count() == 10 and a.data.vert_count() == 12, "CANCEL puts the mesh back")
	ok(ed.sel_faces.size() == 1 and ed.sel_faces.has(f), "and the selection")
	ok(a.mesh_instance.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size() == 10 * 6, "and the drawn mesh follows")
	# EXTRUDE NORMALS on an edge of Cube 001 grows a quad.
	ed.select_object(b)
	ed.set_mode(ed.Mode.EDIT)
	ed.set_elem(ed.Elem.EDGE)
	ed.select_edges({0: true})
	ed.tool_start("EXTRUDE NORMALS")
	ed.tool_set(0, 0.5)
	ok(b.data.face_count() == 7 and b.data.vert_count() == 10, "an edge grows a quad (%d f, %d v)" % [b.data.face_count(), b.data.vert_count()])
	ok(ed.sel_edges.size() == 1 and ed.sel_verts.size() == 2, "the new edge is the selection")
	ed.set_mode(ed.Mode.OBJECT)
	ok(ed.tool_job.is_empty() and b.data.face_count() == 7, "leaving EDIT applies a live tool")
	ed.pointer = ed.Pointer.SELECT
	ed.select_object(a)


func _transform() -> void:
	var a: Node3D = ed.objects()[0]
	ed.set_mode(ed.Mode.OBJECT)
	ed.select_object(a)
	a.global_transform = Transform3D(Basis(), Vector3(-3, 0, 0))
	ok(ed.tool_start("ROTATE"), "ROTATE starts on an object")
	ok(ed.tool_window.visible and ed.tool_job.props.size() == 3 and ed.tool_job.props[0].unit == "°",
			"with X Y Z in degrees")
	ed.tool_set(1, 92.0)
	ok(is_equal_approx(ed.tool_value(1), 90.0), "snapped to 5 degree steps (%.1f)" % ed.tool_value(1))
	ok(a.global_basis.is_equal_approx(Basis.from_euler(Vector3(0, deg_to_rad(90.0), 0))), "the object turned 90 about Y")
	ok(a.global_position.is_equal_approx(Vector3(-3, 0, 0)), "about its own origin")
	ed.tool_cancel()
	ok(a.global_basis.is_equal_approx(Basis()) and not ed.tool_live(), "CANCEL turns it back")
	ed.tool_start("TRANSLATE")
	ed.tool_set(0, 1.6)
	ok(a.global_position.is_equal_approx(Vector3(-1.5, 0, 0)), "TRANSLATE X by slider, snapped 1.6 to 1.5 (%s)" % a.global_position)
	ed.tool_apply()
	ok(a.global_position.is_equal_approx(Vector3(-1.5, 0, 0)) and not ed.tool_live(), "APPLY keeps it")
	# A drag in the view with ROTATE as the tool turns about one axis.
	ed.pointer = ed.Pointer.TOOL
	ed.current_tool = "ROTATE"
	var p := _screen(a.global_position)
	_pen_drag(p, p + Vector2(100, 0))
	await _settle()
	ok(ed.tool_live() and ed.tool_kind() == "ROTATE", "a drag in the view with ROTATE turns")
	var vals: Array = ed.tool_values()
	var turned := 0
	var stepped := true
	for v in vals:
		if not is_zero_approx(v):
			turned += 1
			stepped = stepped and is_zero_approx(fmod(absf(v), 5.0))
	ok(turned == 1 and stepped, "about one axis, in 5 degree steps (%s)" % str(vals))
	ed.tool_cancel()
	ok(a.global_basis.is_equal_approx(Basis()), "and CANCEL undoes the turn")
	# Two objects turn about their shared centre.
	var b: Node3D = ed.objects()[1]
	a.global_transform = Transform3D(Basis(), Vector3(-3, 0, 0))
	b.global_transform = Transform3D(Basis(), Vector3(3, 0, 0))
	ed.select_object(a)
	ed.select_object(b, true)
	ed.tool_start("ROTATE")
	ed.tool_set(1, 180.0)
	ok(a.global_position.is_equal_approx(Vector3(3, 0, 0)) and b.global_position.is_equal_approx(Vector3(-3, 0, 0)),
			"two objects turn about their shared centre (%s, %s)" % [a.global_position, b.global_position])
	ed.tool_cancel()
	# In EDIT, vertices turn about their own centre.
	var c: Node3D = ed.add_primitive("CUBE")
	c.global_position = Vector3(0, 0, 5)
	ed.set_mode(ed.Mode.EDIT)
	ed.set_elem(ed.Elem.VERT)
	var all := {}
	for i in 8:
		all[i] = true
	ed.select_verts(all)
	ed.tool_start("ROTATE")
	ed.tool_set(1, 90.0)
	ok(c.data.verts[0].is_equal_approx(Vector3(-1, -1, 1)), "all of a cube's verts turned 90 about Y (%s)" % c.data.verts[0])
	ok(c.global_position.is_equal_approx(Vector3(0, 0, 5)), "without moving the object")
	ed.tool_cancel()
	ok(c.data.verts[0].is_equal_approx(Vector3(-1, -1, -1)), "and CANCEL puts them back")
	ed.set_mode(ed.Mode.OBJECT)
	ed.select_object(c)
	ed.delete_selected()
	ed.pointer = ed.Pointer.SELECT
	ed.select_object(a)


func _popovers() -> void:
	var before: int = ed.sel_objects.size()
	var p := _row_center(ed.toggle_list, 0)
	_finger(0, p, true)
	_finger(0, p, false)
	await _settle()
	ok(ed.popover.visible and ed.popover_kind == "SNAP", "a finger tap on SNAP opens the snap menu")
	var empty := Vector2(ed.view_rect.end.x - 20, ed.view_rect.end.y - 20)
	_finger(0, empty, true)
	_finger(0, empty, false)
	await _settle()
	ok(not ed.popover.visible, "a tap outside closes it")
	ok(ed.sel_objects.size() == before, "and that tap does nothing else")
	_pen_tap(p)
	await _settle()
	var row: Vector2 = ed.snap_menu.global_position + ed.snap_menu.row_rect(ed.snap_menu.index_of("SNAP")).get_center()
	_pen_tap(row)
	ok(not ed.snap_on, "the SNAP row turns snapping off")
	_pen_tap(row)
	ok(ed.snap_on, "and on again")
	var step: Vector2 = ed.snap_menu.global_position + ed.snap_menu.row_rect(ed.snap_menu.index_of("STEP")).get_center()
	_pen_tap(step)
	ok(is_equal_approx(ed.snap_step, 0.1), "STEP steps 0.25 to 0.1")
	for i in 3:
		_pen_tap(step)
	ok(is_equal_approx(ed.snap_step, 0.25), "and round again to 0.25")
	var vert: Vector2 = ed.snap_menu.global_position + ed.snap_menu.row_rect(ed.snap_menu.index_of("VERTEX")).get_center()
	_pen_tap(vert)
	ok(ed.snap_targets.VERTEX, "VERTEX is a target now")
	_pen_tap(vert)
	ok(ed.popover.visible, "the menu stays open while its rows are tapped")
	# Shading.
	p = _row_center(ed.toggle_list, 1)
	_pen_tap(p)
	await _settle()
	ok(ed.popover.visible and ed.matcap_grid.visible, "SHADING opens the matcap gallery")
	ok(Matcaps.count() == 16, "sixteen matcaps")
	var cell: Vector2 = ed.matcap_grid.global_position + ed.matcap_grid.cell_rect(5).get_center()
	_pen_tap(cell)
	ok(SceneObject.matcap_index == 5, "a tap on the sixth cell picks it")
	ok(SceneObject.material().get_shader_parameter("matcap") == Matcaps.texture(5), "and the shared material wears it")
	_pen_tap(p)
	await _settle()
	ok(not ed.popover.visible, "tapping SHADING again closes it")
	SceneObject.set_matcap(0)


func _groups() -> void:
	ed.set_mode(ed.Mode.OBJECT)
	var a: Node3D = ed.objects()[0]
	var c: Node3D = ed.add_primitive("CUBE")
	a.global_position = Vector3(-2, 0, 0)
	c.global_position = Vector3(2, 0, 0)
	ed.select_object(a)
	ed.select_object(c, true)
	var g: Node3D = ed.add_group()
	await _settle()
	ok(g.is_group and g.child_objects().size() == 2, "GROUP with two selected wraps both")
	ok(g.global_position.is_equal_approx(Vector3.ZERO), "at their centre (%s)" % g.global_position)
	ok(a.global_position.is_equal_approx(Vector3(-2, 0, 0)), "and they stay where they were")
	ok(ed.active_object == g and ed.mode == ed.Mode.OBJECT, "the group is active, in OBJECT mode")
	ok(ed.mode_list.items[1].disabled, "EDIT is disabled for a group")
	ed.set_mode(ed.Mode.EDIT)
	ok(ed.mode == ed.Mode.OBJECT, "and cannot be entered")
	var rows: Array = ed.hierarchy.items
	ok(rows[0].icon == &"group" and rows[0].depth == 0, "the group row carries the group glyph at the root")
	ok(rows[1].depth == 1 and not rows[1].last and rows[1].tree == [false], "its first child continues the line")
	ok(rows[2].depth == 2 and rows[2].tree == [false, true], "a grandchild carries its parent's line past it")
	ed.clear_object_selection()
	var s: Node3D = ed.objects()[2]
	s.global_position = Vector3(0, 3, 0)
	var p := _screen(g.global_position)
	_finger(0, p, true)
	_finger(0, p, false)
	await _settle()
	ok(ed.active_object == g, "a finger tap on the group's axes picks it")
	ed.clear_object_selection()
	var e: Node3D = ed.add_group()
	ok(e.get_parent() == ed.world_root and e.child_objects().is_empty(), "GROUP with nothing selected is an empty group at the root")


func _fingers() -> void:
	var yaw0: float = ed.orbit.yaw
	var empty := Vector2(ed.view_rect.end.x - 60, ed.view_rect.end.y - 60)
	_finger(0, empty, true)
	_finger_move(0, empty, empty + Vector2(-100, 0))
	_finger(0, empty + Vector2(-100, 0), false)
	ok(ed.orbit.yaw != yaw0, "one finger dragged orbits")
	ok(ed.sel_objects.size() == 1, "and does not change the selection")
	var dist0: float = ed.orbit.distance
	var c: Vector2 = ed.view_rect.get_center()
	_finger(0, c + Vector2(-50, 0), true)
	_finger(1, c + Vector2(50, 0), true)
	_finger_move(0, c + Vector2(-50, 0), c + Vector2(-100, 0))
	_finger_move(1, c + Vector2(50, 0), c + Vector2(100, 0))
	_finger(0, c + Vector2(-100, 0), false)
	_finger(1, c + Vector2(100, 0), false)
	ok(ed.orbit.distance < dist0, "a pinch out zooms in (%.2f -> %.2f)" % [dist0, ed.orbit.distance])
	ok(ed.sel_objects.size() == 1, "two fingers lifted are not a tap")
	var b: Node3D = ed.objects()[1]
	ed.orbit.distance = 8.0
	ed.orbit.target = b.global_position
	ed.orbit.apply()
	var p := _screen(b.global_position)
	_finger(0, p, true)
	_finger(0, p, false)
	await _settle()
	ok(ed.active_object == b, "a finger tap on Cube 001 picks it")
	# The pen never orbits.
	var yaw1: float = ed.orbit.yaw
	_pen_drag(empty, empty + Vector2(-100, 0))
	await _settle()
	ok(ed.orbit.yaw == yaw1, "a pen drag on nothing does not orbit")


func _rows_by_touch() -> void:
	var a: Node3D = ed.objects()[0]
	ed.select_object(a)
	await _settle()
	var p := _row_center(ed.mode_list, 1)
	_finger(0, p, true)
	_finger(0, p, false)
	await _settle()
	ok(ed.mode == ed.Mode.EDIT, "a finger tap on the EDIT row enters EDIT")
	p = _row_center(ed.elem_list, 2)
	_finger(0, p, true)
	_finger(0, p, false)
	await _settle()
	ok(ed.elem == ed.Elem.FACE, "a finger tap on FACE picks faces")
	ok(ed.toolbar.items[ed.toolbar.index_of("EXTRUDE")].disabled, "EXTRUDE is dimmed with nothing selected")
	p = _row_center(ed.toolbar, ed.toolbar.index_of("EXTRUDE"))
	_finger(0, p, true)
	_finger(0, p, false)
	await _settle()
	ok(ed.pointer == ed.Pointer.SELECT, "and a tap on it does nothing")
	ok(ed.toolbar.index_of("DELETE") >= 0 and ed.toolbar.items[ed.toolbar.index_of("DELETE")].disabled,
			"DELETE is on the column, dimmed with nothing selected")
	p = _row_center(ed.add_bar, 0)
	_finger(0, p, true)
	_finger(0, p, false)
	await _settle()
	ok(ed.popover.visible and ed.popover_kind == "ADD" and ed.add_menu.visible, "ADD opens the add menu")
	ok(ed.add_menu.index_of("SPHERE") >= 0 and ed.add_menu.index_of("GROUP") >= 0, "with the primitives and GROUP on it")
	p = ed.add_menu.global_position + ed.add_menu.row_rect(ed.add_menu.index_of("SPHERE")).get_center()
	_finger(0, p, true)
	_finger(0, p, false)
	await _settle()
	ok(ed.objects().size() == 3 and ed.active_object.name == "Sphere", "the SPHERE row adds a sphere")
	ok(ed.mode == ed.Mode.OBJECT and not ed.popover.visible, "lands in OBJECT mode, and the menu closes")


func _view() -> void:
	ed.orbit.yaw = -0.6
	ed.orbit.pitch = -0.5
	ed.orbit.set_ortho(false)
	ok(ed.status_words().contains("    USER PERSP"), "a free view reads USER PERSP (%s)" % ed.status_words())
	var p := _row_center(ed.proj_list, 0)
	_pen_tap(p)
	await _settle()
	ok(ed.orbit.ortho and ed.camera().projection == Camera3D.PROJECTION_ORTHOGONAL, "ORTHO under the ball goes orthographic")
	ok(ed.proj_list.items[0].lit, "and the row is lit")
	_pen_tap(p)
	await _settle()
	ok(not ed.orbit.ortho and ed.camera().projection == Camera3D.PROJECTION_PERSPECTIVE, "and back")
	# The axes ball: tap +Z for FRONT, again for BACK, +Y for TOP.
	var z: Vector2 = ed.gizmo.global_position + ed.gizmo.end_point(Vector3.BACK)[0]
	_pen_tap(z)
	await _settle()
	ok(ed.orbit.view_name() == "FRONT", "a tap on Z looks from the front (%s)" % ed.orbit.view_name())
	ok(ed.orbit.ortho and ed.orbit.auto_ortho, "and goes orthographic by itself")
	ok(ed.status_words().contains("    FRONT ORTHO"), "the status says FRONT ORTHO")
	z = ed.gizmo.global_position + ed.gizmo.end_point(Vector3.BACK)[0]
	_pen_tap(z)
	await _settle()
	ok(ed.orbit.view_name() == "BACK", "the same end again flips to the back (%s)" % ed.orbit.view_name())
	var y: Vector2 = ed.gizmo.global_position + ed.gizmo.end_point(Vector3.UP)[0]
	_pen_tap(y)
	await _settle()
	ok(ed.orbit.view_name() == "TOP", "Y looks from the top (%s)" % ed.orbit.view_name())
	var x: Vector2 = ed.gizmo.global_position + ed.gizmo.end_point(Vector3.LEFT)[0]
	_pen_tap(x)
	await _settle()
	ok(ed.orbit.view_name() == "LEFT", "the hollow X end looks from the left (%s)" % ed.orbit.view_name())
	# An orbit leaves the axis view and its auto-ortho with it.
	var empty := Vector2(ed.view_rect.get_center().x, ed.view_rect.end.y - 60)
	_finger(0, empty, true)
	_finger_move(0, empty, empty + Vector2(-80, 0))
	_finger(0, empty + Vector2(-80, 0), false)
	ok(ed.orbit.view_name() == "" and not ed.orbit.ortho, "a finger orbit leaves the axis view and perspective returns")
	# A drag on the ball orbits too.
	var yaw0: float = ed.orbit.yaw
	var c: Vector2 = ed.gizmo.global_position + ed.gizmo.size * 0.5
	_pen_drag(c, c + Vector2(40, 0))
	ok(ed.orbit.yaw != yaw0, "a drag on the ball orbits")
	ed.orbit.yaw = -0.6
	ed.orbit.pitch = -0.5
	ed.orbit.distance = 8.0
	ed.orbit.target = Vector3.ZERO
	ed.orbit.apply()
	# The properties panel shows the active object.
	var a: Node3D = ed.objects()[0]
	ed.select_object(a)
	a.global_position = Vector3(1.25, 0, -3)
	ed._refresh_props()
	var texts := []
	for it in ed.props_list.items:
		texts.append(it.text + ":" + str(it.get("value", "")))
	ok(ed.props_list.items[0].text == a.name, "properties lead with the object's name")
	ok(texts.has("X:+1.25") and texts.has("Z:-3.00"), "and show its location (%s)" % str(texts))
	ok(texts.has("VERTS:%03d" % a.data.vert_count()), "and its vertex count")
	ed.clear_object_selection()
	ok(ed.props_list.items[0].text == "NOTHING SELECTED", "with nothing selected they say so")


func _scroll() -> void:
	var extra := []
	for i in 14:
		extra.append(ed.add_primitive("CUBE"))
	await _settle()
	ok(ed.hierarchy.scrollable() and ed.hierarchy.max_scroll() > 0.0, "many objects make the hierarchy scroll")
	var top_before: Variant = ed.hierarchy.items[ed.hierarchy.row_at(Vector2(20, 10))].id
	var from: Vector2 = ed.hierarchy.global_position + Vector2(60, ed.hierarchy.size.y - 30)
	_pen_drag(from, from + Vector2(0, -160))
	await _settle()
	ok(ed.hierarchy.scroll > 0.0, "a drag up the rows scrolls them (%.0f)" % ed.hierarchy.scroll)
	var top_after: Variant = ed.hierarchy.items[ed.hierarchy.row_at(Vector2(20, 10))].id
	ok(top_after != top_before, "a different row is at the top now")
	ok(ed.active_object == extra[extra.size() - 1], "and the drag did not select anything")
	var row: Vector2 = ed.hierarchy.global_position + Vector2(60, 10)
	_pen_tap(row)
	await _settle()
	ok(ed.active_object != null and ed.active_object.get_instance_id() == top_after, "a tap picks the row that is really there")
	var thumb: Rect2 = ed.hierarchy.thumb_rect()
	ok(thumb.size.y < ed.hierarchy.size.y and thumb.position.y > 0.0, "the scrollbar's thumb is part way down")
	for c in extra:
		ed.select_object(c)
		ed.delete_selected()
	await _settle()
	ok(not ed.hierarchy.scrollable(), "with them gone it no longer scrolls")


func _delete() -> void:
	var a: Node3D = ed.objects()[0]
	var b: Node3D = ed.objects()[1]
	var s: Node3D = ed.objects()[2]
	ed.reparent_object(s, b)
	ed.reparent_object(b, a)
	ed.select_object(b)
	ed.delete_selected()
	await _settle()
	ok(not is_instance_valid(b) or b.is_queued_for_deletion(), "DELETE removes Cube 001")
	ok(is_instance_valid(s) and s.get_parent() == a, "its child moves up to Cube")
	ok(ed.objects().size() == 2, "two objects remain")
	ed.select_object(a)
	ed.set_mode(ed.Mode.EDIT)
	ed.select_verts({0: true})
	var v0: int = a.data.vert_count()
	var f0: int = a.data.face_count()
	var touching: int = a.data.faces_using_vert(0).size()
	ed.delete_selected()
	ok(a.data.vert_count() == v0 - 1 and a.data.face_count() == f0 - touching,
			"DELETE in EDIT removes the vertex and its %d faces (%d v, %d f)" % [touching, a.data.vert_count(), a.data.face_count()])
	ok(ed.sel_verts.is_empty(), "and nothing is selected after")
	var drawn: int = 0
	for f in a.data.face_count():
		drawn += (a.data.faces[f].size() - 2) * 3
	ok(a.mesh_instance.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size() == drawn, "the drawn mesh follows")


func _key(code: Key, ctrl := false, shift := false) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	e.ctrl_pressed = ctrl
	e.shift_pressed = shift
	root.push_input(e, true)


func _frame(target: Vector3) -> void:
	ed.orbit.set_ortho(false)
	ed.orbit.yaw = -0.6
	ed.orbit.pitch = -0.5
	ed.orbit.distance = 8.0
	ed.orbit.target = target
	ed.orbit.apply()


func _fresh_cube(at: Vector3) -> Node3D:
	ed.set_mode(ed.Mode.OBJECT)
	var c: Node3D = ed.add_primitive("CUBE")
	c.global_position = at
	_frame(at)
	return c


func _new_tools() -> void:
	var c := _fresh_cube(Vector3(0, 0, 12))
	await _settle()
	ok(ed.toolbar.index_of("SCALE") >= 0, "SCALE is on the object-mode column")
	ok(ed.tool_start("SCALE") and ed.tool_job.props[0].origin == 1.0, "SCALE starts at 1")
	ed.tool_set(0, 1.93)
	ok(is_equal_approx(c.scale.x, 1.9) and is_equal_approx(c.scale.y, 1.0), "X by slider, snapped to 1.9 (%s)" % c.scale)
	ok(c.global_position.is_equal_approx(Vector3(0, 0, 12)), "about the object's own origin")
	ed.tool_apply()
	ed._refresh_props()
	var scl: Array = []
	for it in ed.props_list.items:
		if String(it.id).begins_with("scl"):
			scl.append(it.value)
	ok(scl == ["1.900", "1.000", "1.000"], "the properties show the scale (%s)" % str(scl))
	# A drag away from the pivot scales up evenly.
	c.scale = Vector3.ONE
	ed.pointer = ed.Pointer.TOOL
	ed.current_tool = "SCALE"
	var p := _screen(c.global_position)
	_pen_drag(p + Vector2(60, 0), p + Vector2(120, 0))
	await _settle()
	ok(ed.tool_kind() == "SCALE" and c.scale.x > 1.5 and is_equal_approx(c.scale.x, c.scale.z),
			"a drag outward scales up evenly (%s)" % c.scale)
	ed.tool_cancel()
	ok(c.scale.is_equal_approx(Vector3.ONE), "CANCEL puts the scale back")
	ed.pointer = ed.Pointer.SELECT
	# Inset from the tool column.
	ed.set_mode(ed.Mode.EDIT)
	ed.set_elem(ed.Elem.FACE)
	ed.select_faces({1: true})
	await _settle()
	var f0: int = c.data.face_count()
	p = _row_center(ed.toolbar, ed.toolbar.index_of("INSET"))
	_finger(0, p, true)
	_finger(0, p, false)
	await _settle()
	ok(ed.tool_kind() == "INSET" and ed.tool_job.props.size() == 2, "INSET from the column, with THICKNESS and DEPTH")
	ed.tool_set(0, 0.33)
	ok(is_equal_approx(ed.tool_value(0), 0.35), "thickness snaps in fifths of the step (%.2f)" % ed.tool_value(0))
	ed.tool_set(1, 0.5)
	ok(c.data.face_count() == f0 + 4, "a ring of four faces (%d)" % c.data.face_count())
	var raised := true
	for i in ed.sel_verts:
		raised = raised and is_equal_approx(c.data.verts[i].y, 1.5)
	ok(raised and ed.sel_faces.size() == 1, "the inner face is selected and raised by DEPTH")
	ed.tool_apply()
	# Bevel an edge of a second cube.
	var b := _fresh_cube(Vector3(4, 0, 12))
	ed.set_mode(ed.Mode.EDIT)
	ed.set_elem(ed.Elem.EDGE)
	ed.select_edges({b.data.edge_index(4, 5): true})
	ok(ed.tool_start("BEVEL"), "BEVEL starts on an edge")
	ed.tool_set(0, 0.25)
	ok(b.data.face_count() == 7 and b.data.vert_count() == 10, "the edge is a strip (%d f, %d v)" % [b.data.face_count(), b.data.vert_count()])
	ok(ed.sel_faces.size() == 1, "and the strip is selected")
	ed.tool_cancel()
	ok(b.data.face_count() == 6 and b.data.vert_count() == 8, "CANCEL puts the cube back")
	ed.select_edges({})
	ok(ed.toolbar.items[ed.toolbar.index_of("BEVEL")].disabled, "BEVEL is dimmed with no edge selected")
	ed.set_mode(ed.Mode.OBJECT)


func _history() -> void:
	ed.clear_object_selection()
	var n0: int = ed.objects().size()
	var h0: int = ed.history_index
	var c: Node3D = ed.add_primitive("CUBE")
	ok(ed.history_index == h0 + 1 and ed.history_label() == "ADD CUBE", "adding is an undo step (%s)" % ed.history_label())
	var p := _row_center(ed.history_bar, 0)
	_pen_tap(p)
	await _settle()
	ok(ed.objects().size() == n0, "UNDO in the header takes the cube away")
	ok(ed.can_redo() and not ed.history_bar.items[1].disabled, "and REDO is live")
	_pen_tap(_row_center(ed.history_bar, 1))
	await _settle()
	ok(ed.objects().size() == n0 + 1, "REDO brings it back")
	c = ed.objects()[ed.objects().size() - 1]
	ok(c.name == "Cube 017" or c.name.begins_with("Cube"), "under its name (%s)" % c.name)
	ok(ed.active_object == c, "selected, as it was")
	# A move, applied, then undone.
	_frame(c.global_position)
	ed.select_object(c)
	var start: Vector3 = c.global_position
	ed.tool_start("TRANSLATE")
	ed.tool_set(0, 1.0)
	ed.tool_apply()
	ok(c.global_position.is_equal_approx(start + Vector3(1, 0, 0)), "moved by a unit")
	ed.undo()
	c = ed.active_object
	ok(c != null and c.global_position.is_equal_approx(start), "undo puts it back")
	# An extrude in EDIT: undo keeps EDIT and the face that was picked.
	ed.set_mode(ed.Mode.EDIT)
	ed.set_elem(ed.Elem.FACE)
	ed.select_faces({1: true})
	ed.tool_start("EXTRUDE")
	ed.tool_set(0, 0.5)
	ed.tool_apply()
	ok(ed.active_object.data.face_count() == 10, "extruded")
	ed.undo()
	ok(ed.active_object.data.face_count() == 6, "undo takes the extrude away")
	ok(ed.mode == ed.Mode.EDIT and ed.sel_faces.has(1) and ed.sel_faces.size() == 1,
			"and leaves EDIT with the top face picked, as it was")
	ed.redo()
	ok(ed.active_object.data.face_count() == 10, "redo brings it back")
	# With a tool live, undo cancels it.
	ed.select_faces({0: true})
	ed.tool_start("EXTRUDE")
	ed.tool_set(0, 1.0)
	var h1: int = ed.history_index
	ed.undo()
	ok(not ed.tool_live() and ed.active_object.data.face_count() == 10 and ed.history_index == h1,
			"undo with a tool live cancels it and goes no further")
	ed.set_mode(ed.Mode.OBJECT)
	# A tool that did nothing is not a step.
	ed.tool_start("ROTATE")
	ed.tool_apply()
	ok(ed.history_index == h1, "a tool applied at zero is not an undo step")
	# Fingers: two tapped together undo, three redo, a pinch does neither.
	ed.add_primitive("SPHERE")
	var n1: int = ed.objects().size()
	var v1: Vector2 = ed.view_rect.get_center() + Vector2(-40, 120)
	var v2: Vector2 = v1 + Vector2(90, 0)
	var v3: Vector2 = v1 + Vector2(45, 60)
	_finger(0, v1, true)
	_finger(1, v2, true)
	_finger(0, v1, false)
	_finger(1, v2, false)
	await _settle()
	ok(ed.objects().size() == n1 - 1, "a two-finger tap undoes the sphere")
	_finger(0, v1, true)
	_finger(1, v2, true)
	_finger(2, v3, true)
	_finger(2, v3, false)
	_finger(1, v2, false)
	_finger(0, v1, false)
	await _settle()
	ok(ed.objects().size() == n1, "a three-finger tap redoes it")
	_finger(0, v1, true)
	_finger(1, v2, true)
	_finger_move(0, v1, v1 + Vector2(-60, 0))
	_finger_move(1, v2, v2 + Vector2(60, 0))
	_finger(0, v1 + Vector2(-60, 0), false)
	_finger(1, v2 + Vector2(60, 0), false)
	await _settle()
	ok(ed.objects().size() == n1, "a pinch is not an undo")
	# Every kind of change undoes: parent, group, delete.
	var a: Node3D = ed.objects()[0]
	var s: Node3D = ed.objects()[ed.objects().size() - 1]
	ed.reparent_object(s, a)
	ok(ed.history_label() == "PARENT", "parenting is a step")
	ed.undo()
	ok(ed.objects()[ed.objects().size() - 1].get_parent() == ed.world_root, "undone, the sphere is back at the root")
	ed.select_object(ed.objects()[ed.objects().size() - 1])
	ed.delete_selected()
	ok(ed.objects().size() == n1 - 1 and ed.history_label() == "DELETE", "delete is a step")
	ed.undo()
	ok(ed.objects().size() == n1, "undone, the sphere is back")
	# The history is capped.
	for i in 70:
		ed.history.append(ed.history[ed.history_index])
	ed.history_index = ed.history.size() - 1
	ed.push_undo("CAP")
	ok(ed.history.size() <= ed.HISTORY_MAX, "the history keeps at most %d steps (%d)" % [ed.HISTORY_MAX, ed.history.size()])


func _scrub_and_keys() -> void:
	ed.set_mode(ed.Mode.OBJECT)
	var c := _fresh_cube(Vector3(0, 0, 20))
	await _settle()
	ed._refresh_props()
	var i: int = ed.props_list.index_of("loc0")
	ok(i >= 0 and ed.props_list.items[i].get("scrub", false), "location X is a field")
	var p: Vector2 = ed.props_list.global_position + ed.props_list.row_rect(i).get_center()
	var h0: int = ed.history_index
	_pen_drag(p, p + Vector2(100, 0))
	await _settle()
	ok(is_equal_approx(c.position.x, 1.0), "dragging it 100 px right adds a unit (%.2f)" % c.position.x)
	ok(ed.history_label() == "PROPERTIES" and ed.history_index == ed.history.size() - 1, "as one undo step")
	ed.undo()
	ok(is_zero_approx(ed.active_object.position.x), "which undoes")
	ed.redo()
	c = ed.active_object
	i = ed.props_list.index_of("rot1")
	p = ed.props_list.global_position + ed.props_list.row_rect(i).get_center()
	_pen_drag(p, p + Vector2(-60, 0))
	await _settle()
	ok(is_equal_approx(c.rotation_degrees.y, -30.0), "rotation Y by -60 px is -30 degrees (%.1f)" % c.rotation_degrees.y)
	_key(KEY_Z, true)
	await _settle()
	c = ed.active_object
	ok(is_zero_approx(c.rotation_degrees.y) and is_equal_approx(c.position.x, 1.0), "Ctrl+Z undoes the rotation only")
	_key(KEY_Z, true, true)
	await _settle()
	ok(is_equal_approx(ed.active_object.rotation_degrees.y, -30.0), "Ctrl+Shift+Z redoes it")
	_key(KEY_TAB)
	ok(ed.mode == ed.Mode.EDIT, "Tab enters EDIT")
	_key(KEY_3)
	ok(ed.elem == ed.Elem.FACE, "3 is faces")
	_key(KEY_E)
	ok(ed.pointer == ed.Pointer.TOOL and ed.current_tool == "EXTRUDE", "E picks EXTRUDE")
	_key(KEY_ESCAPE)
	_key(KEY_TAB)
	ok(ed.mode == ed.Mode.OBJECT, "Tab leaves EDIT")
	_key(KEY_KP_7)
	ok(ed.orbit.view_name() == "TOP", "numpad 7 is TOP")
	_key(KEY_KP_7)
	ok(ed.orbit.view_name() == "TOP", "and again is still TOP, not a flip")
	_key(KEY_KP_1, true)
	ok(ed.orbit.view_name() == "BACK", "Ctrl+numpad 1 is BACK")
	_key(KEY_A, false, true)
	ok(ed.popover.visible and ed.popover_kind == "ADD", "Shift+A opens ADD")
	_key(KEY_ESCAPE)
	ok(not ed.popover.visible, "Escape closes it")
	_frame(Vector3.ZERO)


func _gizmos() -> void:
	ed.close_popover()
	ed.set_mode(ed.Mode.OBJECT)
	ed.snap_on = true
	ed.snap_targets.INCREMENT = true
	ed.snap_absolute = true
	var c := _fresh_cube(Vector3(0, 0, 30))
	c.rotation = Vector3.ZERO
	c.scale = Vector3.ONE
	await _settle()
	ed.pointer = ed.Pointer.SELECT
	ok(ed.gizmo_kind() == "", "no gizmo while SELECT is the pointer")
	ed._on_toolbar_tapped("MOVE")
	ed._gizmo_sync()
	ok(ed.gizmo_kind() == "MOVE" and ed.xgizmo.visible(), "MOVE shows the arrows")
	ok(ed.xgizmo.pivot.is_equal_approx(c.global_position), "at the object's origin")
	# Drag the X arrow: the cube moves along X only, onto the grid.
	var sh: Array = ed.xgizmo.shaft(0)
	var tip: Vector2 = sh[1]
	var along: Vector2 = (tip - ed.xgizmo.centre()).normalized()
	ok(ed.gizmo_pick(tip, ed.PEN_RADIUS) == "X", "the X arrow's tip picks X")
	_pen_drag(tip, tip + along * 70.0 + Vector2(0, 25))
	await _settle()
	var p: Vector3 = c.global_position
	ok(p.x > 0.4 and is_zero_approx(p.y) and is_equal_approx(p.z, 30.0), "the X arrow moves along X only (%s)" % p)
	ok(is_zero_approx(fmod(p.x, 0.25)), "and lands on the grid (%.3f)" % p.x)
	ok(ed.tool_kind() == "TRANSLATE" and ed.tool_window.visible, "with the TRANSLATE numbers up")
	# Again on Y continues the same move.
	sh = ed.xgizmo.shaft(1)
	tip = sh[1]
	along = (tip - ed.xgizmo.centre()).normalized()
	_pen_drag(tip, tip + along * 50.0)
	await _settle()
	p = c.global_position
	ok(p.y > 0.2 and p.x > 0.4, "the Y arrow next moves up, keeping the X move (%s)" % p)
	ed.tool_apply()
	ok(ed.history_label() == "TRANSLATE", "one undo step for the move")
	# The rotate rings.
	c.global_position = Vector3(0, 0, 30)
	ed._on_toolbar_tapped("ROTATE")
	ed.tool_cancel()
	await _settle()
	ed._gizmo_sync()
	ok(ed.gizmo_kind() == "ROTATE", "ROTATE as the tool shows the rings")
	var ring: PackedVector2Array = ed.xgizmo.ring(1)
	var on_ring: Vector2 = ring[0]
	ok(ed.gizmo_pick(on_ring, ed.PEN_RADIUS) == "Y" or ed.gizmo_pick(ring[12], ed.PEN_RADIUS) == "Y",
			"a point on the Y ring picks Y")
	var cen: Vector2 = ed.xgizmo.centre()
	var start: Vector2 = ring[12] if ed.gizmo_pick(ring[12], ed.PEN_RADIUS) == "Y" else ring[0]
	var r := start - cen
	var end := cen + r.rotated(-0.6)
	_pen(start, true)
	_pen_move(start, cen + r.rotated(-0.3), true)
	_pen_move(cen + r.rotated(-0.3), end, true)
	_pen(end, false)
	await _settle()
	var vals: Array = ed.tool_values()
	ok(ed.tool_kind() == "ROTATE" and absf(vals[1]) >= 5.0 and is_zero_approx(vals[0]) and is_zero_approx(vals[2]),
			"dragging round the Y ring turns about Y only (%s)" % str(vals))
	ok(is_zero_approx(fmod(absf(vals[1]), 5.0)), "in 5 degree steps")
	ed.tool_cancel()
	# The scale handles.
	ed._on_toolbar_tapped("SCALE")
	ed.tool_cancel()
	ed._gizmo_sync()
	sh = ed.xgizmo.shaft(2)
	if sh.is_empty():
		sh = ed.xgizmo.shaft(0)
	tip = sh[1]
	var which: String = ed.gizmo_pick(tip, ed.PEN_RADIUS)
	along = (tip - ed.xgizmo.centre()).normalized()
	_pen_drag(tip, tip + along * 60.0)
	await _settle()
	var sc: Vector3 = c.scale
	var ai := "XYZ".find(which)
	ok(ai >= 0 and sc[ai] > 1.2 and is_equal_approx(sc[(ai + 1) % 3], 1.0), "a scale handle stretches its own axis only (%s on %s)" % [sc, which])
	ed.tool_cancel()
	# The centre handle scales evenly.
	cen = ed.xgizmo.centre()
	ok(ed.gizmo_pick(cen, ed.PEN_RADIUS) == "C", "the centre is its own handle")
	ed.pointer = ed.Pointer.SELECT
	ok(ed.gizmo_kind() == "", "and SELECT hides it again")


func _loopcut_and_duplicate() -> void:
	var c := _fresh_cube(Vector3(0, 0, -30))
	await _settle()
	ed.set_mode(ed.Mode.EDIT)
	ed.set_elem(ed.Elem.EDGE)
	ed.select_edges({c.data.edge_index(0, 4): true})
	ok(ed.toolbar.index_of("LOOP CUT") >= 0 and not ed.toolbar.items[ed.toolbar.index_of("LOOP CUT")].disabled,
			"LOOP CUT is on the column, live with an edge selected")
	var p := _row_center(ed.toolbar, ed.toolbar.index_of("LOOP CUT"))
	_finger(0, p, true)
	_finger(0, p, false)
	await _settle()
	ok(ed.tool_kind() == "LOOP CUT" and c.data.face_count() == 10, "a tap cuts round the sides (%d faces)" % c.data.face_count())
	ok(ed.sel_edges.size() == 4, "the new loop is selected (%d edges)" % ed.sel_edges.size())
	ed.tool_set(0, 0.47)
	ok(is_equal_approx(ed.tool_value(), 0.5), "FACTOR snaps in tenths (%.2f)" % ed.tool_value())
	ed.tool_apply()
	ok(ed.history_label() == "LOOP CUT", "applied as a step")
	# Duplicate in EDIT: the selected loop's edges, copied in place.
	var v0: int = c.data.vert_count()
	var e0: int = c.data.edge_count()
	ed._on_toolbar_tapped("DUPLICATE")
	ok(c.data.vert_count() == v0 + 4 and c.data.edge_count() == e0 + 4, "DUPLICATE in EDIT copies the loop (%d v, %d e)" % [c.data.vert_count(), c.data.edge_count()])
	ok(ed.pointer == ed.Pointer.MOVE and ed.history_label() == "DUPLICATE", "and leaves MOVE as the pointer, as a step")
	var moved_new := true
	for i in ed.sel_verts:
		moved_new = moved_new and i >= v0
	ok(moved_new, "the copies are the selection")
	ed.undo()
	# Undo rebuilds the scene: nodes held from before are gone, so look again.
	ok(not is_instance_valid(c) or c.is_queued_for_deletion(), "undo rebuilds the scene's nodes")
	c = ed.active_object
	ok(c.data.vert_count() == v0, "and takes the copies away")
	# Duplicate objects: a parent with a child, copied together.
	ed.set_mode(ed.Mode.OBJECT)
	var kid: Node3D = ed.add_primitive("SPHERE")
	kid.global_position = c.global_position + Vector3(3, 0, 0)
	ed.reparent_object(kid, c)
	var n0: int = ed.objects().size()
	ed.select_object(c)
	ed.duplicate_selected()
	ok(ed.objects().size() == n0 + 2, "duplicating a parent copies its child too (%d)" % ed.objects().size())
	var copy: Node3D = ed.active_object
	ok(copy != c and copy.get_parent() == c.get_parent() and copy.global_transform.is_equal_approx(c.global_transform),
			"the copy sits beside it, in the same place")
	ok(copy.child_objects().size() == 1 and copy.child_objects()[0].global_position.is_equal_approx(kid.global_position),
			"with its child where the child was")
	ok(copy.name.begins_with("Cube ") and copy.name != c.name, "under a name of its own (%s)" % copy.name)
	ok(copy.data != c.data, "and a mesh of its own")


func _select_menu() -> void:
	ed.set_mode(ed.Mode.OBJECT)
	var p := _row_center(ed.select_bar, 0)
	_pen_tap(p)
	await _settle()
	ok(ed.popover.visible and ed.popover_kind == "SELECT", "SELECT opens its menu")
	var all_row: Vector2 = ed.select_menu.global_position + ed.select_menu.row_rect(0).get_center()
	_pen_tap(all_row)
	ok(ed.sel_objects.size() == ed.objects().size() and not ed.popover.visible, "ALL selects every object")
	ed.select_all("NONE")
	ok(ed.sel_objects.is_empty() and ed.active_object == null, "NONE clears")
	var a: Node3D = ed.objects()[0]
	ed.select_object(a)
	ed.select_all("INVERT")
	ok(not ed.sel_objects.has(a) and ed.sel_objects.size() == ed.objects().size() - 1, "INVERT flips it")
	ed.select_object(a)
	if a.has_mesh():
		ed.set_mode(ed.Mode.EDIT)
		ed.set_elem(ed.Elem.FACE)
		ed.select_faces({0: true})
		ed.select_all("INVERT")
		ok(ed.sel_faces.size() == a.data.face_count() - 1 and not ed.sel_faces.has(0), "INVERT in face mode flips the faces")
		_key(KEY_A)
		ok(ed.sel_faces.size() == a.data.face_count(), "A selects every face")
		_key(KEY_A, false, false)
		var e := InputEventKey.new()
		e.keycode = KEY_A
		e.pressed = true
		e.alt_pressed = true
		root.push_input(e, true)
		ok(ed.sel_verts.is_empty(), "Alt+A selects none")
		ed.set_mode(ed.Mode.OBJECT)


func _files() -> void:
	# Start clean: no saved scenes from an earlier run.
	for n in SceneFile.list():
		SceneFile.delete(n)
	ed.file_new()
	ok(ed.objects().is_empty() and ed.scene_name == "" and not ed.is_dirty(), "NEW is an empty, untitled, unchanged scene")
	ok(ed.history_label() == "NEW", "and an undo step")
	var c: Node3D = ed.add_primitive("CUBE")
	c.position = Vector3(1, 2, 3)
	var s: Node3D = ed.add_primitive("SPHERE")
	ed.reparent_object(s, c)
	ok(ed.is_dirty() and ed.status_words().begins_with("UNTITLED*"), "changes mark it (%s)" % ed.status_words())
	ok(ed.file_save(false) and ed.scene_name == "SCENE 001", "SAVE names the first scene SCENE 001")
	ok(not ed.is_dirty() and ed.status_words().begins_with("SCENE 001    "), "and it is clean")
	ok(ed.flash_text == "SAVED SCENE 001", "the flash says so")
	ed.file_save(true)
	ok(ed.scene_name == "SCENE 002" and SceneFile.list().size() == 2, "SAVE AS NEW makes SCENE 002")
	# Open the first again, after wiping the scene.
	ed.file_new()
	ok(ed.objects().is_empty(), "wiped")
	_pen_tap(_row_center(ed.file_bar, 0))
	await _settle()
	ok(ed.popover.visible and ed.file_menu.index_of("open:SCENE 001") >= 0, "FILE lists the saved scenes")
	var row: Vector2 = ed.file_menu.global_position + ed.file_menu.row_rect(ed.file_menu.index_of("open:SCENE 001")).get_center()
	_pen_tap(row)
	await _settle()
	ok(ed.objects().size() == 2 and ed.scene_name == "SCENE 001" and not ed.is_dirty(), "a tap opens SCENE 001, clean")
	var c2: Node3D = ed.objects()[0]
	ok(c2.position.is_equal_approx(Vector3(1, 2, 3)) and c2.child_objects().size() == 1, "where it was, with its child")
	ok(c2.data.face_count() == 6, "and its mesh")
	ed.undo()
	ok(ed.objects().is_empty(), "undo goes back to the scene before opening")
	ed.redo()
	# Export.
	var dir := OS.get_user_data_dir().path_join("test_exports")
	ed.export_dir_override = dir
	var path: String = ed.file_export()
	ok(path.ends_with("SCENE_001.obj") and FileAccess.file_exists(path), "EXPORT OBJ writes a file (%s)" % path)
	var text := FileAccess.get_file_as_string(path)
	ok(text.count("\nv ") == 8 + 114 and text.count("\nf ") == 6 + 128, "with every vertex and face (%d v, %d f)" % [text.count("\nv "), text.count("\nf ")])
	ok(text.contains("v 0.000000 1.000000 2.000000") or text.contains("v 0.000000 3.000000 2.000000"),
			"in world space")
	for n in SceneFile.list():
		SceneFile.delete(n)
