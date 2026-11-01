extends SceneTree
## Screenshots of the editor, for looking at. Needs a real renderer:
##
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 \
##       --audio-driver Dummy --resolution 1280x720 \
##       --script res://tests/RENDER_editor.gd -- --out=/tmp/shots
##
## Writes object.png (two objects, one selected), edit_face.png (a face),
## edit_vert.png (a box's worth of verts, the pen hovering).

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
	ed.reparent_object(sphere, cube)
	ed.select_object(cube)
	ed.select_object(cyl, true)
	ed.active_object = cube
	ed._refresh_lists()
	await _frames(6)
	_shot("object")
	ed.set_mode(ed.Mode.EDIT)
	ed.set_elem(ed.Elem.FACE)
	ed.select_faces({ed.pick_face(ed.camera().unproject_position(cube.global_position)): true})
	await _frames(6)
	_shot("edit_face")
	ed.set_elem(ed.Elem.VERT)
	ed.select_verts({4: true, 5: true, 6: true, 7: true})
	ed.pointer = ed.Pointer.MOVE
	ed._refresh_lists()
	ed.update_hover(ed.camera().unproject_position(cube.global_transform * cube.data.verts[1]), 14.0)
	ed.pen_hover_valid = true
	ed.pen_hover_pos = ed.camera().unproject_position(cube.global_transform * cube.data.verts[1])
	await _frames(6)
	_shot("edit_vert")
	quit(0)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(label: String) -> void:
	var img := root.get_texture().get_image()
	var path := out.path_join(label + ".png")
	img.save_png(path)
	print("wrote ", path, " ", img.get_size())
