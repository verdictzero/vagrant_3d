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
## selection readable later.
func build_mesh() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if faces.is_empty():
		return mesh
	var pos := PackedVector3Array()
	var nrm := PackedVector3Array()
	for f in faces.size():
		var n := face_normal(f)
		for tri in face_triangles(f):
			for i in tri:
				pos.append(verts[i])
				nrm.append(n)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = pos
	arrays[Mesh.ARRAY_NORMAL] = nrm
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
