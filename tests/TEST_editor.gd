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
	for l in [ed.mode_list, ed.elem_list, ed.pointer_list, ed.toggle_list]:
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
	await _fingers()
	await _rows_by_touch()
	await _popovers()
	await _delete()
	await _groups()
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
	var empty := Vector2(ed.view_rect.end.x - 20, ed.view_rect.position.y + 20)
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
	# A tap in MOVE still selects.
	_pen_tap(_vert_screen(a, 5))
	await _settle()
	ok(ed.sel_verts.has(5) and ed.sel_verts.size() == 1, "a tap in MOVE picks vertex 5")
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
	p = _row_center(ed.pointer_list, 2)
	_finger(0, p, true)
	_finger(0, p, false)
	await _settle()
	ok(ed.pointer == ed.Pointer.SELECT, "TOOL is disabled: nothing is bound to it yet")
	p = _row_center(ed.add_list, 3)
	_finger(0, p, true)
	_finger(0, p, false)
	await _settle()
	ok(ed.objects().size() == 3 and ed.active_object.name == "Sphere", "the SPHERE row adds a sphere")
	ok(ed.mode == ed.Mode.OBJECT, "and lands in OBJECT mode")


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
	ed.delete_selected()
	ok(a.data.vert_count() == 7 and a.data.face_count() == 3, "DELETE in EDIT removes the vertex and its faces")
	ok(ed.sel_verts.is_empty(), "and nothing is selected after")
	ok(a.mesh_instance.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size() == 18, "the drawn mesh follows")
