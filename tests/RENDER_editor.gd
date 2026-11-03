extends SceneTree
## Screenshots of the editor, for looking at. Needs a real renderer:
##
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --path . --rendering-driver opengl3 \
##       --audio-driver Dummy --resolution 1600x900 \
##       --script res://tests/RENDER_editor.gd -- --out=/tmp/shots
##
## Writes object.png (a group, two meshes, one selected), snap.png (the snap
## menu), shading.png (the gallery, gold picked), edit_vert.png (a box's
## worth of verts, the pen hovering, held to a vertex).

const SCENE := "res://scenes/SCENE_editor.tscn"

var out := "/tmp/shots"
var ed: Node


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out)
	ed = (load(SCENE) as PackedScene).instantiate()
	root.add_child(ed)
	await _frames(4)
	var cube = ed.add_primitive("CUBE")
	var sphere = ed.add_primitive("SPHERE")
	var cyl = ed.add_primitive("CYLINDER")
	sphere.global_position = Vector3(3, 0, 0)
	cyl.global_position = Vector3(-3, 0, -1)
	ed.select_object(cube)
	ed.select_object(sphere, true)
	ed.add_group()
	ed.select_object(cube)
	ed.select_object(cyl, true)
	ed.active_object = cube
	ed._refresh_lists()
	await _frames(6)
	_shot("object")
	ed.open_popover("SNAP")
	await _frames(6)
	_shot("snap")
	ed.close_popover()
	ed.open_popover("SHADING")
	ed._on_matcap_picked(10)
	await _frames(6)
	_shot("shading")
	ed.close_popover()
	ed._on_matcap_picked(0)
	ed.set_mode(ed.Mode.EDIT)
	ed.set_elem(ed.Elem.VERT)
	ed.select_verts({4: true, 5: true, 6: true, 7: true})
	ed.pointer = ed.Pointer.MOVE
	ed._refresh_lists()
	var hover: Vector2 = ed.camera().unproject_position(cube.global_transform * cube.data.verts[1])
	ed.update_hover(hover, 12.0)
	ed.pen_hover_valid = true
	ed.pen_hover_pos = hover
	ed.snap_hit = {"point": cyl.global_transform * cyl.data.verts[3], "kind": "VERTEX"}
	await _frames(6)
	_shot("edit_vert")
	ed.snap_hit = {}
	ed.pen_hover_valid = false
	ed.set_elem(ed.Elem.FACE)
	ed.select_faces({1: true})
	ed.pointer = ed.Pointer.TOOL
	ed.tool_start("EXTRUDE")
	ed.tool_set(0, 0.75)
	await _frames(6)
	_shot("tool")
	ed.tool_apply()
	ed.set_mode(ed.Mode.OBJECT)
	ed.select_object(cube)
	ed.tool_start("ROTATE")
	ed.tool_set(1, 35.0)
	ed.tool_set(0, -10.0)
	await _frames(6)
	_shot("rotate")
	ed.tool_cancel()
	ed.orbit.view_from_axis(Vector3.BACK)
	ed.open_popover("ADD")
	ed._refresh_lists()
	await _frames(6)
	_shot("front_add")
	ed.close_popover()
	# Bevel every edge of the cube, then inset its top and sink it.
	ed.orbit.set_ortho(false)
	ed.orbit.yaw = -0.6
	ed.orbit.pitch = -0.5
	ed.orbit.apply()
	ed.select_object(cube)
	ed.set_mode(ed.Mode.EDIT)
	ed.set_elem(ed.Elem.EDGE)
	var all := {}
	for i in cube.data.edge_count():
		all[i] = true
	ed.select_edges(all)
	ed.tool_start("BEVEL")
	ed.tool_set(0, 0.2)
	await _frames(6)
	_shot("bevel")
	ed.tool_apply()
	ed.set_elem(ed.Elem.FACE)
	var top := -1
	for f in cube.data.face_count():
		if cube.data.face_normal(f).y > 0.99:
			top = f
	ed.select_faces({top: true})
	ed.tool_start("INSET")
	ed.tool_set(0, 0.3)
	ed.tool_set(1, -0.4)
	ed._refresh_props()
	await _frames(6)
	_shot("inset")
	ed.tool_apply()
	ed.set_mode(ed.Mode.OBJECT)
	ed.select_object(cube)
	ed._on_toolbar_tapped("MOVE")
	await _frames(6)
	_shot("gizmo_move")
	ed._on_toolbar_tapped("ROTATE")
	ed.tool_set(1, 20.0)
	await _frames(6)
	_shot("gizmo_rotate")
	ed.tool_cancel()
	ed.pointer = ed.Pointer.SELECT
	for n in SceneFile.list():
		SceneFile.delete(n)
	ed.file_save(false)
	ed.file_save(true)
	ed.open_popover("FILE")
	await _frames(6)
	_shot("file")
	for n in SceneFile.list():
		SceneFile.delete(n)
	ed.close_popover()
	# A subdivided, smooth cube off to one side, mirrored across X.
	ed.file_new()
	var box = ed.add_primitive("CUBE")
	for i in box.data.verts.size():
		box.data.verts[i].x += 1.6
	box.rebuild()
	ed.add_modifier("SUBDIVISION")
	box.modifiers[0].levels = 2
	ed.add_modifier("MIRROR")
	box.smooth = true
	box.rebuild()
	ed.orbit.target = Vector3.ZERO
	ed.orbit.distance = 9.0
	ed.orbit.apply()
	ed._refresh_lists()
	await _frames(6)
	_shot("modifiers")
	ed.ask_rename()
	await _frames(6)
	_shot("rename")
	ed.prompt.cancel()
	# Trim: a lasso drawn over a cube from the front, then the tunnel it cut.
	ed.file_new()
	var tc = ed.add_primitive("CUBE")
	ed.orbit.target = Vector3.ZERO
	ed.orbit.distance = 8.0
	ed.orbit.set_view("FRONT", false)
	ed._on_toolbar_tapped("TRIM")
	var cam: Camera3D = ed.camera()
	var mid: Vector2 = cam.unproject_position(Vector3.ZERO)
	var rad: float = (cam.unproject_position(Vector3(0.5, 0, 0)) - mid).x
	ed.trim_drawing = true
	ed.trim_points = PackedVector2Array()
	for k in 40:
		var wob := 1.0 + 0.18 * sin(k * 0.9)
		ed.trim_points.append(mid + Vector2(cos(TAU * k / 40.0), sin(TAU * k / 40.0)) * rad * wob)
	ed._refresh_lists()
	await _frames(6)
	_shot("trim_draw")
	ed.trim_finish()
	ed.orbit.set_ortho(false)
	ed.orbit.yaw = -0.22
	ed.orbit.pitch = -0.16
	ed.orbit.distance = 6.5
	ed.orbit.apply()
	ed.pointer = ed.Pointer.SELECT
	ed.clear_object_selection()
	ed._refresh_lists()
	await _frames(6)
	_shot("trim_done")
	quit(0)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(label: String) -> void:
	var img := root.get_texture().get_image()
	var path := out.path_join(label + ".png")
	img.save_png(path)
	print("wrote ", path, " ", img.get_size())
