extends SceneTree
## Headless: the primitives are closed, wound outward and renumber cleanly.
## Run: godot --headless --path . --script res://tests/TEST_mesh_data.gd

var fails := 0


func ok(cond: bool, msg: String) -> void:
	print(("  PASS  " if cond else "  FAIL  ") + msg)
	if not cond:
		fails += 1


func _initialize() -> void:
	_primitive("plane", MeshData.make_plane(), 4, 4, 1, 1)
	_primitive("cube", MeshData.make_cube(), 8, 12, 6, 2)
	_primitive("cylinder", MeshData.make_cylinder(), 32, 48, 18, 2)
	_primitive("sphere", MeshData.make_sphere(), 114, 240, 128, 2)
	_outward()
	_delete()
	_mesh()
	print("mesh data: %d failure(s)" % fails)
	quit(1 if fails > 0 else 0)


func _primitive(label: String, m: MeshData, v: int, e: int, f: int, euler: int) -> void:
	ok(m.vert_count() == v, "%s has %d verts (%d)" % [label, v, m.vert_count()])
	ok(m.edge_count() == e, "%s has %d edges (%d)" % [label, e, m.edge_count()])
	ok(m.face_count() == f, "%s has %d faces (%d)" % [label, f, m.face_count()])
	var chi := m.vert_count() - m.edge_count() + m.face_count()
	ok(chi == euler, "%s V-E+F = %d (%d)" % [label, euler, chi])
	var dup := false
	var unordered := false
	var seen := {}
	for ed in m.edges:
		unordered = unordered or ed.x >= ed.y
		dup = dup or seen.has(ed)
		seen[ed] = true
	ok(not unordered, "%s edges are ordered (a < b)" % label)
	ok(not dup, "%s has no duplicate edge" % label)


## Every face normal points away from the centre on the closed shapes, and the
## plane faces up.
func _outward() -> void:
	for pair in [["cube", MeshData.make_cube()], ["cylinder", MeshData.make_cylinder()],
			["sphere", MeshData.make_sphere()]]:
		var m: MeshData = pair[1]
		var bad := 0
		for f in m.face_count():
			if m.face_normal(f).dot(m.face_center(f)) <= 0.0:
				bad += 1
		ok(bad == 0, "%s: every face winds outward (%d did not)" % [pair[0], bad])
	ok(MeshData.make_plane().face_normal(0).y > 0.99, "plane faces +Y")


func _delete() -> void:
	var m := MeshData.make_cube()
	m.delete_verts({0: true})
	ok(m.vert_count() == 7, "cube minus a corner: 7 verts (%d)" % m.vert_count())
	ok(m.face_count() == 3, "cube minus a corner: 3 faces (%d)" % m.face_count())
	# The three edges that met at the corner go; the nine others stay.
	ok(m.edge_count() == 9, "cube minus a corner: 9 edges (%d)" % m.edge_count())
	var top := MeshData.make_cube()
	top.delete_verts({4: true, 5: true, 6: true, 7: true})
	ok(top.face_count() == 1 and top.edge_count() == 4, "cube minus its top: one face, 4 edges")


func _mesh() -> void:
	var m := MeshData.make_cube().build_mesh()
	ok(m.get_surface_count() == 1, "cube builds one surface")
	var arrays := m.surface_get_arrays(0)
	ok(arrays[Mesh.ARRAY_VERTEX].size() == 36, "cube is 12 triangles (%d verts)" % arrays[Mesh.ARRAY_VERTEX].size())
	ok(MeshData.new().build_mesh().get_surface_count() == 0, "an empty mesh builds nothing")
	var hit := MeshData.make_cube().ray_hit(Vector3(0, 0, 5), Vector3(0, 0, -1))
	ok(not hit.is_empty() and hit.face == 4, "a ray from +Z hits the +Z face (%s)" % str(hit))
	ok(MeshData.make_cube().ray_hit(Vector3(5, 5, 5), Vector3(0, 0, -1)).is_empty(), "a ray that misses, misses")
