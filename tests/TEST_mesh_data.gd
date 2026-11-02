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
	_extrude()
	_inset()
	_bevel()
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
	# Godot's front faces wind clockwise: each drawn triangle's right-hand
	# normal must point AGAINST the face normal it carries.
	var pos: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var nrm: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var wrong := 0
	for t in range(0, pos.size(), 3):
		var rh := (pos[t + 1] - pos[t]).cross(pos[t + 2] - pos[t])
		if rh.dot(nrm[t]) > 0.0:
			wrong += 1
	ok(wrong == 0, "every drawn triangle winds clockwise for Godot (%d did not)" % wrong)
	ok(MeshData.new().build_mesh().get_surface_count() == 0, "an empty mesh builds nothing")
	var hit := MeshData.make_cube().ray_hit(Vector3(0, 0, 5), Vector3(0, 0, -1))
	ok(not hit.is_empty() and hit.face == 4, "a ray from +Z hits the +Z face (%s)" % str(hit))
	ok(MeshData.make_cube().ray_hit(Vector3(5, 5, 5), Vector3(0, 0, -1)).is_empty(), "a ray that misses, misses")


func _outward_all(m: MeshData, centre: Vector3, label: String) -> void:
	var bad := 0
	for f in m.face_count():
		if m.face_normal(f).dot(m.face_center(f) - centre) <= 0.0:
			bad += 1
	ok(bad == 0, "%s: every face winds outward (%d did not)" % [label, bad])


func _extrude() -> void:
	# A cube's top, pulled up half a unit: the top rises, four walls appear,
	# the old top is gone, and the whole is still one closed shell.
	var m := MeshData.make_cube()
	var job := m.extrude_begin({}, {}, {1: true}, false)
	m.extrude_set(job, 0.5)
	ok(m.vert_count() == 12 and m.edge_count() == 20 and m.face_count() == 10,
			"cube top extruded: 12 v, 20 e, 10 f (%d, %d, %d)" % [m.vert_count(), m.edge_count(), m.face_count()])
	ok(m.vert_count() - m.edge_count() + m.face_count() == 2, "and still a closed shell")
	var risen := true
	for i in job.moving:
		risen = risen and is_equal_approx(m.verts[i].y, 1.5)
	ok(risen and job.moving.size() == 4, "the four new verts sit at y 1.5")
	ok(job.sel_verts.size() == 4, "and are the selection after")
	_outward_all(m, Vector3(0, 0.25, 0), "extruded cube")
	# A plane's one face: the rim grows walls and the floor is gone.
	m = MeshData.make_plane()
	job = m.extrude_begin({}, {}, {0: true}, false)
	m.extrude_set(job, 1.0)
	ok(m.vert_count() == 8 and m.edge_count() == 12 and m.face_count() == 5,
			"plane extruded: 8 v, 12 e, 5 f, open underneath (%d, %d, %d)" % [m.vert_count(), m.edge_count(), m.face_count()])
	ok(job.dir[0].is_equal_approx(Vector3.UP), "along the plane's normal")
	# Every face, along normals: nothing new, every corner slides out its own diagonal.
	m = MeshData.make_cube()
	job = m.extrude_begin({}, {}, {0: true, 1: true, 2: true, 3: true, 4: true, 5: true}, true)
	m.extrude_set(job, 0.5)
	ok(m.vert_count() == 8 and m.face_count() == 6, "all faces along normals adds nothing")
	ok(m.verts[0].is_equal_approx(Vector3(-1, -1, -1) + Vector3(-1, -1, -1).normalized() * 0.5),
			"and corner 0 moved out along its own normal (%s)" % m.verts[0])
	# An edge of a plane grows a wall facing out.
	m = MeshData.make_plane()
	job = m.extrude_begin({}, {0: true}, {}, false)
	m.extrude_set(job, 0.5)
	ok(m.vert_count() == 6 and m.edge_count() == 7 and m.face_count() == 2,
			"plane edge extruded: 6 v, 7 e, 2 f (%d, %d, %d)" % [m.vert_count(), m.edge_count(), m.face_count()])
	ok(m.face_normal(1).dot(m.face_center(1)) > 0.0, "the wall faces away from the plane")
	ok(is_equal_approx(m.verts[4].y, 0.5), "and stands up")
	# A vertex grows a wire edge.
	m = MeshData.make_plane()
	job = m.extrude_begin({0: true}, {}, {}, false)
	m.extrude_set(job, 0.5)
	ok(m.vert_count() == 5 and m.edge_count() == 5 and m.face_count() == 1, "a vertex extrudes to a wire edge")
	ok(m.edge_index(0, 4) >= 0, "joined to where it came from")
	# copy() is a real copy.
	var a := MeshData.make_cube()
	var b := a.copy()
	b.verts[0] = Vector3(9, 9, 9)
	b.delete_verts({1: true})
	ok(a.vert_count() == 8 and a.verts[0] == Vector3(-1, -1, -1) and a.edge_count() == 12, "copy() shares nothing")


func _closed(m: MeshData, label: String) -> void:
	ok(m.vert_count() - m.edge_count() + m.face_count() == 2,
			"%s is a closed shell (%d v, %d e, %d f)" % [label, m.vert_count(), m.edge_count(), m.face_count()])
	var efm := m.edge_face_map()
	var open := 0
	for e in efm:
		if efm[e].size() != 2:
			open += 1
	ok(open == 0, "%s: every edge has two faces (%d do not)" % [label, open])


func _inset() -> void:
	var m := MeshData.make_cube()
	var job := m.inset_begin({1: true})
	m.job_set(job, 0.25)
	ok(m.vert_count() == 12 and m.face_count() == 10, "cube top inset: 12 v, 10 f (%d, %d)" % [m.vert_count(), m.face_count()])
	_closed(m, "inset cube")
	var flat := true
	var inner := true
	for i in job.moving:
		flat = flat and is_equal_approx(m.verts[i].y, 1.0)
		inner = inner and is_equal_approx(absf(m.verts[i].x), 0.75) and is_equal_approx(absf(m.verts[i].z), 0.75)
	ok(flat, "the ring lies flat in the top")
	ok(inner, "a quarter in from every edge")
	_outward_all(m, Vector3.ZERO, "inset cube")
	m.job_set(job, 0.25, 0.5)
	var raised := true
	for i in job.moving:
		raised = raised and is_equal_approx(m.verts[i].y, 1.5)
	ok(raised, "DEPTH lifts the inner face along its normal")
	# Two neighbouring faces inset as one region: one ring, not two.
	m = MeshData.make_cube()
	job = m.inset_begin({1: true, 4: true})
	m.job_set(job, 0.25)
	ok(m.face_count() == 6 + 6, "two faces inset as a region add six ring faces (%d)" % m.face_count())
	_closed(m, "region inset")


func _bevel() -> void:
	# One edge of a cube: the edge becomes a strip, its two ends split.
	var m := MeshData.make_cube()
	var e := m.edge_index(4, 5)   # the top's -z edge
	var job := m.bevel_begin({e: true})
	m.job_set(job, 0.25)
	ok(m.vert_count() == 10 and m.face_count() == 7, "one cube edge bevelled: 10 v, 7 f (%d, %d)" % [m.vert_count(), m.face_count()])
	_closed(m, "bevelled edge")
	_outward_all(m, Vector3.ZERO, "bevelled edge")
	var on_top := 0
	var on_side := 0
	for i in job.moving:
		var v: Vector3 = m.verts[i]
		if is_equal_approx(v.y, 1.0) and is_equal_approx(v.z, -0.75):
			on_top += 1
		if is_equal_approx(v.z, -1.0) and is_equal_approx(v.y, 0.75):
			on_side += 1
	ok(on_top == 2 and on_side == 2, "the new edges sit 0.25 in on the top and down the side (%d, %d)" % [on_top, on_side])
	# Every edge: corners become triangles.
	m = MeshData.make_cube()
	var all := {}
	for i in m.edge_count():
		all[i] = true
	job = m.bevel_begin(all)
	m.job_set(job, 0.2)
	ok(m.vert_count() == 24 and m.face_count() == 26,
			"every cube edge bevelled: 24 v, 26 f (%d, %d)" % [m.vert_count(), m.face_count()])
	_closed(m, "bevelled cube")
	_outward_all(m, Vector3.ZERO, "bevelled cube")
	var tris := 0
	for f in m.faces:
		if f.size() == 3:
			tris += 1
	ok(tris == 8, "with a triangle at each corner (%d)" % tris)
	# The ring of four edges round the top.
	m = MeshData.make_cube()
	var ring := {}
	for pair in [[4, 5], [5, 6], [6, 7], [7, 4]]:
		ring[m.edge_index(pair[0], pair[1])] = true
	job = m.bevel_begin(ring)
	m.job_set(job, 0.25)
	ok(m.face_count() == 6 + 4 and m.vert_count() == 12,
			"the top ring bevelled: 12 v, 10 f, a strip all round (%d, %d)" % [m.vert_count(), m.face_count()])
	_closed(m, "bevelled ring")
	# The amount stops before the new edges cross.
	m = MeshData.make_cube()
	job = m.bevel_begin({m.edge_index(4, 5): true})
	m.job_set(job, 50.0)
	var inside := true
	for v in m.verts:
		inside = inside and absf(v.x) <= 1.0001 and absf(v.y) <= 1.0001 and absf(v.z) <= 1.0001
	ok(inside, "a huge amount is clamped inside the cube")
	# A plane's border edge has one face: nothing to bevel.
	m = MeshData.make_plane()
	ok(m.bevel_begin({0: true}).is_empty(), "a border edge is not bevelled")
