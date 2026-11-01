class_name MeshData
extends RefCounted
## An editable mesh: vertices, edges and faces, the three things EDIT mode
## selects. Faces are polygons (index lists, convex, counter-clockwise seen
## from outside); edges are derived from faces and kept unique. `build_mesh()`
## turns it into the flat-shaded ArrayMesh the viewport draws.

var verts := PackedVector3Array()
var edges: Array[Vector2i] = []          # (a, b) with a < b
var faces: Array[PackedInt32Array] = []

var _edge_index: Dictionary = {}         # Vector2i -> index into edges


# --- building -----------------------------------------------------------------

func add_vert(p: Vector3) -> int:
	verts.append(p)
	return verts.size() - 1


func add_face(idx: PackedInt32Array) -> int:
	faces.append(idx)
	for i in idx.size():
		_add_edge(idx[i], idx[(i + 1) % idx.size()])
	return faces.size() - 1


func _add_edge(a: int, b: int) -> int:
	var key := Vector2i(mini(a, b), maxi(a, b))
	if _edge_index.has(key):
		return _edge_index[key]
	edges.append(key)
	_edge_index[key] = edges.size() - 1
	return edges.size() - 1


func edge_index(a: int, b: int) -> int:
	return _edge_index.get(Vector2i(mini(a, b), maxi(a, b)), -1)


# --- primitives ---------------------------------------------------------------

static func make_plane(size := 2.0) -> MeshData:
	var m := MeshData.new()
	var h := size * 0.5
	m.add_vert(Vector3(-h, 0, -h)); m.add_vert(Vector3(h, 0, -h))
	m.add_vert(Vector3(h, 0, h)); m.add_vert(Vector3(-h, 0, h))
	m.add_face(PackedInt32Array([0, 3, 2, 1]))
	return m


static func make_cube(size := 2.0) -> MeshData:
	var m := MeshData.new()
	var h := size * 0.5
	for y in [-h, h]:
		m.add_vert(Vector3(-h, y, -h)); m.add_vert(Vector3(h, y, -h))
		m.add_vert(Vector3(h, y, h)); m.add_vert(Vector3(-h, y, h))
	m.add_face(PackedInt32Array([0, 1, 2, 3]))   # bottom
	m.add_face(PackedInt32Array([4, 7, 6, 5]))   # top
	m.add_face(PackedInt32Array([0, 4, 5, 1]))   # -z
	m.add_face(PackedInt32Array([1, 5, 6, 2]))   # +x
	m.add_face(PackedInt32Array([2, 6, 7, 3]))   # +z
	m.add_face(PackedInt32Array([3, 7, 4, 0]))   # -x
	return m


static func make_cylinder(radius := 1.0, height := 2.0, segs := 16) -> MeshData:
	var m := MeshData.new()
	var h := height * 0.5
	for ring in [-h, h]:
		for i in segs:
			var a := TAU * float(i) / float(segs)
			m.add_vert(Vector3(cos(a) * radius, ring, -sin(a) * radius))
	var bottom := PackedInt32Array()
	var top := PackedInt32Array()
	for i in segs:
		var j := (i + 1) % segs
		m.add_face(PackedInt32Array([i, j, segs + j, segs + i]))
		bottom.append(segs - 1 - i)
		top.append(segs + i)
	m.add_face(bottom)
	m.add_face(top)
	return m


static func make_sphere(radius := 1.0, rings := 8, segs := 16) -> MeshData:
	var m := MeshData.new()
	var south := m.add_vert(Vector3(0, -radius, 0))
	for r in range(1, rings):
		var phi := PI * float(r) / float(rings) - PI * 0.5
		var y := sin(phi) * radius
		var rr := cos(phi) * radius
		for i in segs:
			var a := TAU * float(i) / float(segs)
			m.add_vert(Vector3(cos(a) * rr, y, -sin(a) * rr))
	var north := m.add_vert(Vector3(0, radius, 0))
	var base := func(r: int) -> int: return 1 + (r - 1) * segs
	for i in segs:
		var j := (i + 1) % segs
		m.add_face(PackedInt32Array([south, base.call(1) + j, base.call(1) + i]))
		for r in range(1, rings - 1):
			var lo: int = base.call(r)
			var hi: int = base.call(r + 1)
			m.add_face(PackedInt32Array([lo + i, lo + j, hi + j, hi + i]))
		m.add_face(PackedInt32Array([base.call(rings - 1) + i, base.call(rings - 1) + j, north]))
	return m


# --- queries ------------------------------------------------------------------

func face_center(f: int) -> Vector3:
	var c := Vector3.ZERO
	for i in faces[f]:
		c += verts[i]
	return c / float(faces[f].size())


func face_normal(f: int) -> Vector3:
	var idx := faces[f]
	var n := Vector3.ZERO
	for i in idx.size():
		var a := verts[idx[i]]
		var b := verts[idx[(i + 1) % idx.size()]]
		n += (a - b).cross(a + b)
	return n.normalized()


## Triangles of face `f`, fanned from its first vertex: [[a,b,c], ...].
func face_triangles(f: int) -> Array:
	var idx := faces[f]
	var out := []
	for i in range(1, idx.size() - 1):
		out.append([idx[0], idx[i], idx[i + 1]])
	return out


## Nearest hit of a local-space ray on any face: {face, t, point} or {}.
func ray_hit(origin: Vector3, dir: Vector3) -> Dictionary:
	var best := {}
	for f in faces.size():
		for tri in face_triangles(f):
			var hit = Geometry3D.ray_intersects_triangle(origin, dir,
					verts[tri[0]], verts[tri[1]], verts[tri[2]])
			if hit == null:
				continue
			var t: float = (hit - origin).dot(dir)
			if best.is_empty() or t < best.t:
				best = {"face": f, "t": t, "point": hit}
	return best


func vert_count() -> int: return verts.size()
func edge_count() -> int: return edges.size()
func face_count() -> int: return faces.size()


# --- editing ------------------------------------------------------------------

## Remove the given vertices, every edge and face that uses one of them, and
## renumber what is left. `which` is a Dictionary used as a set (index -> true).
func delete_verts(which: Dictionary) -> void:
	if which.is_empty():
		return
	var remap := PackedInt32Array()
	remap.resize(verts.size())
	var kept := PackedVector3Array()
	for i in verts.size():
		if which.has(i):
			remap[i] = -1
		else:
			remap[i] = kept.size()
			kept.append(verts[i])
	var old_faces := faces
	var old_edges := edges
	verts = kept
	faces = []
	edges = []
	_edge_index = {}
	for f in old_faces:
		var nf := PackedInt32Array()
		var alive := true
		for i in f:
			if remap[i] < 0:
				alive = false
				break
			nf.append(remap[i])
		if alive:
			add_face(nf)
	# Edges that belonged to no surviving face (wire edges) survive on their own.
	for e in old_edges:
		if remap[e.x] >= 0 and remap[e.y] >= 0:
			_add_edge(remap[e.x], remap[e.y])


## Every face that has vertex `v` on its ring.
func faces_using_vert(v: int) -> Array[int]:
	var out: Array[int] = []
	for f in faces.size():
		if faces[f].has(v):
			out.append(f)
	return out


# --- rendering ----------------------------------------------------------------

## Flat-shaded triangle mesh. Vertices are split per face so every face has
## its own normal; that is the clay look, and it is also what makes face
## selection readable later. Faces here wind counter-clockwise seen from
## outside (the right-hand rule gives the outward normal); Godot's front
## faces wind CLOCKWISE, so each triangle is emitted reversed.
func build_mesh() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if faces.is_empty():
		return mesh
	var pos := PackedVector3Array()
	var nrm := PackedVector3Array()
	for f in faces.size():
		var n := face_normal(f)
		for tri in face_triangles(f):
			for i in [tri[0], tri[2], tri[1]]:
				pos.append(verts[i])
				nrm.append(n)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = pos
	arrays[Mesh.ARRAY_NORMAL] = nrm
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


# --- copying and face removal --------------------------------------------------

func copy() -> MeshData:
	var m := MeshData.new()
	m.verts = verts.duplicate()
	m.edges = edges.duplicate()
	m.faces = faces.duplicate(true)
	m._edge_index = _edge_index.duplicate()
	return m


## Every face on each edge: Vector2i -> Array of face indices. Edges in no
## face are wire edges.
func edge_face_map() -> Dictionary:
	var out := {}
	for e in edges:
		out[e] = []
	for f in faces.size():
		var idx := faces[f]
		for i in idx.size():
			var a := idx[i]
			var b := idx[(i + 1) % idx.size()]
			out[Vector2i(mini(a, b), maxi(a, b))].append(f)
	return out


## Drop the faces in `which` (a set). Edges are rebuilt from what remains;
## wire edges survive.
func remove_faces(which: Dictionary) -> void:
	var efm := edge_face_map()
	var wires: Array[Vector2i] = []
	for e in efm:
		if efm[e].is_empty():
			wires.append(e)
	var kept: Array[PackedInt32Array] = []
	for f in faces.size():
		if not which.has(f):
			kept.append(faces[f])
	faces = []
	edges = []
	_edge_index = {}
	for f in kept:
		add_face(f)
	for e in wires:
		_add_edge(e.x, e.y)


## Area-weighted normal (Newell, not normalised): long faces count more.
func face_normal_raw(f: int) -> Vector3:
	var idx := faces[f]
	var n := Vector3.ZERO
	for i in idx.size():
		var a := verts[idx[i]]
		var b := verts[idx[(i + 1) % idx.size()]]
		n += (a - b).cross(a + b)
	return n


## The normal at vertex `v`: the faces in `among` (a set, or all faces when
## empty) that use it, averaged. UP when no face does.
func vertex_normal(v: int, among: Dictionary = {}) -> Vector3:
	var n := Vector3.ZERO
	for f in faces.size():
		if (among.is_empty() or among.has(f)) and faces[f].has(v):
			n += face_normal(f)
	return n.normalized() if n.length_squared() > 0.0 else Vector3.UP


## True when face `f` runs a then b in its winding.
func face_runs(f: int, a: int, b: int) -> bool:
	var idx := faces[f]
	for i in idx.size():
		if idx[i] == a and idx[(i + 1) % idx.size()] == b:
			return true
	return false


# --- extrude -------------------------------------------------------------------
#
# Two steps, so a slider can pull the result live: `extrude_begin` builds the
# new topology at zero offset and says which vertices move and which way;
# `extrude_set` puts them at an offset. Cancel is the caller's: it keeps a
# copy() from before.
#
# What gets extruded follows the selection the way Blender picks: whole
# faces when any are selected (a region: its rim grows walls and its inside
# comes along), else edges (each grows a quad), else vertices (each grows a
# wire edge). EXTRUDE moves everything along one direction, the region's
# normal; EXTRUDE NORMALS moves each vertex along its own.

## Returns { moving: PackedInt32Array, base: PackedVector3Array,
##           dir: PackedVector3Array, sel_verts: Dictionary }.
func extrude_begin(sel_v: Dictionary, sel_e: Dictionary, sel_f: Dictionary,
		along_normals: bool) -> Dictionary:
	if not sel_f.is_empty():
		return _extrude_faces(sel_f, along_normals)
	if not sel_e.is_empty():
		return _extrude_edges(sel_e, along_normals)
	return _extrude_verts(sel_v)


func extrude_set(job: Dictionary, amount: float) -> void:
	var moving: PackedInt32Array = job.moving
	var base: PackedVector3Array = job.base
	var dir: PackedVector3Array = job.dir
	for i in moving.size():
		verts[moving[i]] = base[i] + dir[i] * amount


func _extrude_faces(sel_f: Dictionary, along_normals: bool) -> Dictionary:
	# Rim edges: in exactly one selected face. Rim vertices are duplicated so
	# the walls have something to stand on; inside vertices move in place.
	var in_region := {}
	var rim: Array = []          # [a, b] as the selected face runs them
	var region_verts := {}
	for f in sel_f:
		var idx := faces[f]
		for i in idx.size():
			var a := idx[i]
			var b := idx[(i + 1) % idx.size()]
			region_verts[a] = true
			var key := Vector2i(mini(a, b), maxi(a, b))
			in_region[key] = in_region.get(key, 0) + 1
	for f in sel_f:
		var idx := faces[f]
		for i in idx.size():
			var a := idx[i]
			var b := idx[(i + 1) % idx.size()]
			if in_region[Vector2i(mini(a, b), maxi(a, b))] == 1:
				rim.append([a, b])
	var rim_verts := {}
	for e in rim:
		rim_verts[e[0]] = true
		rim_verts[e[1]] = true
	# Directions are taken before anything moves or is renumbered.
	var region_n := Vector3.ZERO
	for f in sel_f:
		region_n += face_normal_raw(f)
	region_n = region_n.normalized() if region_n.length_squared() > 0.0 else Vector3.UP
	var dirs := {}
	for v in region_verts:
		dirs[v] = vertex_normal(v, sel_f) if along_normals else region_n
	var map := {}
	for v in region_verts:
		map[v] = add_vert(verts[v]) if rim_verts.has(v) else v
	var new_faces: Array[PackedInt32Array] = []
	for f in sel_f:
		var nf := PackedInt32Array()
		for i in faces[f]:
			nf.append(map[i])
		new_faces.append(nf)
	remove_faces(sel_f)
	for nf in new_faces:
		add_face(nf)
	for e in rim:
		add_face(PackedInt32Array([e[0], e[1], map[e[1]], map[e[0]]]))
	return _job(map, dirs)


func _extrude_edges(sel_e: Dictionary, along_normals: bool) -> Dictionary:
	var efm := edge_face_map()
	var edge_list: Array[Vector2i] = []
	var ev := {}
	for e in sel_e:
		edge_list.append(edges[e])
		ev[edges[e].x] = true
		ev[edges[e].y] = true
	var common := Vector3.ZERO
	for e in edge_list:
		for f in efm[e]:
			common += face_normal(f)
	common = common.normalized() if common.length_squared() > 0.0 else Vector3.UP
	var dirs := {}
	for v in ev:
		dirs[v] = vertex_normal(v) if along_normals else common
	var map := {}
	for v in ev:
		map[v] = add_vert(verts[v])
	for e in edge_list:
		var a := e.x
		var b := e.y
		# Run the edge the way its face does, so the quad faces away from it.
		for f in efm[e]:
			if face_runs(f, b, a):
				a = e.y
				b = e.x
			break
		add_face(PackedInt32Array([a, b, map[b], map[a]]))
	return _job(map, dirs)


func _extrude_verts(sel_v: Dictionary) -> Dictionary:
	var dirs := {}
	var map := {}
	for v in sel_v:
		dirs[v] = vertex_normal(v)
	for v in sel_v:
		map[v] = add_vert(verts[v])
		_add_edge(v, map[v])
	return _job(map, dirs)


func _job(map: Dictionary, dirs: Dictionary) -> Dictionary:
	var moving := PackedInt32Array()
	var base := PackedVector3Array()
	var dir := PackedVector3Array()
	var sel := {}
	for v in map:
		moving.append(map[v])
		base.append(verts[map[v]])
		dir.append(dirs[v])
		sel[map[v]] = true
	return {"moving": moving, "base": base, "dir": dir, "sel_verts": sel}
