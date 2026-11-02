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


# --- live operations -------------------------------------------------------------
#
# Every operation that changes topology runs in two steps, so a slider can
# pull the result live: `*_begin` builds the new topology at zero and returns
# a JOB saying which vertices move and which way; `job_set` puts them where
# an amount says. Positions are linear in the amount (base + dir * amount,
# plus dir2 * a second amount where the tool has one), clamped per vertex by
# `limit` where running past it would fold the mesh. Cancel is the caller's:
# it keeps a copy() from before.
#
#   job = { moving, base, dir, dir2?, limit?, sel_verts }

func job_set(job: Dictionary, amount: float, amount2: float = 0.0) -> void:
	var moving: PackedInt32Array = job.moving
	var base: PackedVector3Array = job.base
	var dir: PackedVector3Array = job.dir
	var dir2: PackedVector3Array = job.get("dir2", PackedVector3Array())
	var limit: PackedFloat32Array = job.get("limit", PackedFloat32Array())
	for i in moving.size():
		var a := amount
		if not limit.is_empty():
			a = clampf(a, -limit[i], limit[i])
		var p := base[i] + dir[i] * a
		if not dir2.is_empty():
			p += dir2[i] * amount2
		verts[moving[i]] = p


## Drop vertices no face or edge uses; returns old index -> new (-1 gone).
func compact() -> PackedInt32Array:
	var used := {}
	for f in faces:
		for i in f:
			used[i] = true
	for e in edges:
		used[e.x] = true
		used[e.y] = true
	var remap := PackedInt32Array()
	remap.resize(verts.size())
	var kept := PackedVector3Array()
	for i in verts.size():
		if used.has(i):
			remap[i] = kept.size()
			kept.append(verts[i])
		else:
			remap[i] = -1
	if kept.size() == verts.size():
		return remap
	var old_faces := faces
	var old_edges := edges
	verts = kept
	faces = []
	edges = []
	_edge_index = {}
	for f in old_faces:
		var nf := PackedInt32Array()
		for i in f:
			nf.append(remap[i])
		add_face(nf)
	for e in old_edges:
		_add_edge(remap[e.x], remap[e.y])
	return remap


# --- extrude -------------------------------------------------------------------
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
	job_set(job, amount)


## The region's rim: edges in exactly one selected face, [a, b] as that face
## runs them. Shared by extrude and inset, which build the same topology and
## differ only in which way the new ring moves.
func _region(sel_f: Dictionary) -> Dictionary:
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
	return {"rim": rim, "rim_verts": rim_verts, "region_verts": region_verts}


## Duplicate the rim, move the region's faces onto the copy, and wall the gap:
## returns old vertex -> the vertex the region now uses.
func _region_split(sel_f: Dictionary, reg: Dictionary) -> Dictionary:
	var map := {}
	for v in reg.region_verts:
		map[v] = add_vert(verts[v]) if reg.rim_verts.has(v) else v
	var new_faces: Array[PackedInt32Array] = []
	for f in sel_f:
		var nf := PackedInt32Array()
		for i in faces[f]:
			nf.append(map[i])
		new_faces.append(nf)
	remove_faces(sel_f)
	for nf in new_faces:
		add_face(nf)
	for e in reg.rim:
		add_face(PackedInt32Array([e[0], e[1], map[e[1]], map[e[0]]]))
	return map


func _extrude_faces(sel_f: Dictionary, along_normals: bool) -> Dictionary:
	# Rim vertices are duplicated so the walls have something to stand on;
	# inside vertices move in place.
	var reg := _region(sel_f)
	# Directions are taken before anything moves or is renumbered.
	var region_n := Vector3.ZERO
	for f in sel_f:
		region_n += face_normal_raw(f)
	region_n = region_n.normalized() if region_n.length_squared() > 0.0 else Vector3.UP
	var dirs := {}
	for v in reg.region_verts:
		dirs[v] = vertex_normal(v, sel_f) if along_normals else region_n
	var map := _region_split(sel_f, reg)
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


# --- inset -----------------------------------------------------------------------
#
# Faces only, as a region (Blender's default): the rim is copied and the copy
# slides inward in the faces' plane, so a ring of walls appears around the
# region, flat at first. THICKNESS is the ring's width, measured square to
# each rim edge; DEPTH lifts (or sinks) the inner region along its normals.

func inset_begin(sel_f: Dictionary) -> Dictionary:
	if sel_f.is_empty():
		return {}
	var reg := _region(sel_f)
	# Which face each rim edge belongs to, for its plane.
	var rim_face := {}
	for f in sel_f:
		var idx := faces[f]
		for i in idx.size():
			rim_face[Vector2i(idx[i], idx[(i + 1) % idx.size()])] = f
	var inward := {}   # rim vertex -> Array of inward unit vectors, one per rim edge
	for e in reg.rim:
		var a: int = e[0]
		var b: int = e[1]
		var n := face_normal(rim_face[Vector2i(a, b)])
		var i := n.cross(verts[b] - verts[a]).normalized()
		for v in [a, b]:
			if not inward.has(v):
				inward[v] = []
			inward[v].append(i)
	var dirs := {}
	var dirs2 := {}
	for v in reg.region_verts:
		dirs2[v] = vertex_normal(v, sel_f)
		if not inward.has(v):
			dirs[v] = Vector3.ZERO
			continue
		var list: Array = inward[v]
		var sum := Vector3.ZERO
		for i in list:
			sum += i
		if sum.length_squared() < 1e-10:
			dirs[v] = Vector3.ZERO
			continue
		var d := sum.normalized()
		# Two edges meeting at an angle: go further along the bisector so the
		# ring is THICKNESS wide square to both.
		var k := 1.0
		if list.size() == 2:
			k = maxf(d.dot(list[0]), 0.2)
		dirs[v] = d / k
	var map := _region_split(sel_f, reg)
	var job := _job(map, dirs)
	var dir2 := PackedVector3Array()
	for v in map:
		dir2.append(dirs2[v])
	job.dir2 = dir2
	return job


# --- bevel -----------------------------------------------------------------------
#
# Edges, one segment. Each selected edge (it must have a face on both sides)
# becomes a strip; AMOUNT is how far its new edges sit from the old one,
# square to it, in each face. Around every vertex of a selected edge, each
# face corner is rebuilt from which of its two edges are selected:
#
#   both      a new corner point inside the face, AMOUNT from both edges
#   one       a point sliding along the other edge, AMOUNT from the selected one
#   neither   the slide points its edges already have (from the faces across
#             them), with the old vertex kept between only if one is missing
#
# The strips are quads between the two faces' new edges, and whatever hole
# that leaves at a vertex (the corner of a cube with all three edges bevelled
# leaves a triangle) is filled with a face. Unused old vertices go.

func bevel_begin(sel_e: Dictionary) -> Dictionary:
	var efm := edge_face_map()
	var sel := {}
	for e in sel_e:
		var key: Vector2i = edges[e]
		if efm[key].size() == 2:
			sel[key] = true
	if sel.is_empty():
		return {}
	var bev := {}
	for k in sel:
		bev[k.x] = true
		bev[k.y] = true
	var face_n: Array[Vector3] = []
	for f in faces.size():
		face_n.append(face_normal(f))
	var is_sel := func(a: int, b: int) -> bool:
		return sel.has(Vector2i(mini(a, b), maxi(a, b)))

	# Pass 1: which edges get a slide point at which end, and how far it
	# travels per unit of AMOUNT (1 / sin of its angle to the selected edge).
	var slide_rate := {}   # Vector2i(v, b): [sum, count]
	for f in faces.size():
		var idx := faces[f]
		var n := idx.size()
		for i in n:
			var v := idx[i]
			if not bev.has(v):
				continue
			var a := idx[(i - 1 + n) % n]
			var b := idx[(i + 1) % n]
			var s_in: bool = is_sel.call(a, v)
			var s_out: bool = is_sel.call(v, b)
			if s_in and not s_out:
				_bevel_rate(slide_rate, v, b, a)
			elif s_out and not s_in:
				_bevel_rate(slide_rate, v, a, b)

	var moving := PackedInt32Array()
	var base := PackedVector3Array()
	var dir := PackedVector3Array()
	var limit := PackedFloat32Array()
	var slide := {}        # Vector2i(v, b) -> new vertex
	for k in slide_rate:
		var v: int = k.x
		var b: int = k.y
		var d := verts[b] - verts[v]
		var length := d.length()
		var rate: float = slide_rate[k][0] / slide_rate[k][1]
		var ni := add_vert(verts[v])
		slide[k] = ni
		moving.append(ni)
		base.append(verts[v])
		dir.append(d / length * rate)
		limit.append(length * (0.49 if bev.has(b) else 0.98) / rate)

	# Pass 2: every face, rebuilt corner by corner.
	var corner := {}       # Vector2i(f, v) -> the vertex face f now has at v
	var new_faces: Array[PackedInt32Array] = []
	for f in faces.size():
		var idx := faces[f]
		var n := idx.size()
		var seq := PackedInt32Array()
		for i in n:
			var v := idx[i]
			if not bev.has(v):
				seq.append(v)
				continue
			var a := idx[(i - 1 + n) % n]
			var b := idx[(i + 1) % n]
			var s_in: bool = is_sel.call(a, v)
			var s_out: bool = is_sel.call(v, b)
			if s_in and s_out:
				var i1 := face_n[f].cross(verts[v] - verts[a]).normalized()
				var i2 := face_n[f].cross(verts[b] - verts[v]).normalized()
				var dd := i1 + i2
				dd = dd.normalized() if dd.length_squared() > 1e-10 else i1
				var k := maxf(dd.dot(i1), 0.2)
				var ni := add_vert(verts[v])
				moving.append(ni)
				base.append(verts[v])
				dir.append(dd / k)
				limit.append(minf((verts[a] - verts[v]).length(), (verts[b] - verts[v]).length()) * 0.49)
				corner[Vector2i(f, v)] = ni
				seq.append(ni)
			elif s_in:
				corner[Vector2i(f, v)] = slide[Vector2i(v, b)]
				seq.append(slide[Vector2i(v, b)])
			elif s_out:
				corner[Vector2i(f, v)] = slide[Vector2i(v, a)]
				seq.append(slide[Vector2i(v, a)])
			else:
				var has_in := slide.has(Vector2i(v, a))
				var has_out := slide.has(Vector2i(v, b))
				if has_in:
					seq.append(slide[Vector2i(v, a)])
				if not (has_in and has_out):
					seq.append(v)
				if has_out:
					seq.append(slide[Vector2i(v, b)])
		new_faces.append(seq)

	# The strips, one per selected edge, wound against both faces' new edges.
	for k in sel:
		var fs: Array = efm[k]
		var fa: int = fs[0]
		var fb: int = fs[1]
		var x: int = k.x
		var y: int = k.y
		if not face_runs(fa, x, y):
			var t := fa
			fa = fb
			fb = t
		new_faces.append(PackedInt32Array([corner[Vector2i(fa, y)], corner[Vector2i(fa, x)],
				corner[Vector2i(fb, x)], corner[Vector2i(fb, y)]]))

	faces = []
	edges = []
	_edge_index = {}
	for nf in new_faces:
		add_face(nf)
	_bevel_fill_holes(bev, verts.size() - moving.size())

	var remap := compact()
	var sel_out := {}
	var keep := PackedInt32Array()
	var keep_base := PackedVector3Array()
	var keep_dir := PackedVector3Array()
	var keep_limit := PackedFloat32Array()
	for i in moving.size():
		var ni: int = remap[moving[i]]
		if ni < 0:
			continue
		keep.append(ni)
		keep_base.append(base[i])
		keep_dir.append(dir[i])
		keep_limit.append(limit[i])
		sel_out[ni] = true
	return {"moving": keep, "base": keep_base, "dir": keep_dir, "limit": keep_limit, "sel_verts": sel_out}


func _bevel_rate(rate: Dictionary, v: int, along: int, from_sel: int) -> void:
	var d := (verts[along] - verts[v]).normalized()
	var u := (verts[from_sel] - verts[v]).normalized()
	var r := 1.0 / maxf(d.cross(u).length(), 0.1)
	var k := Vector2i(v, along)
	if not rate.has(k):
		rate[k] = [0.0, 0]
	rate[k][0] += r
	rate[k][1] += 1


## Fill the holes a bevel leaves: boundary loops whose every vertex is new
## (index >= `first_new`) or a bevelled vertex. A mesh's own open border has
## other vertices on it, so it is never filled.
func _bevel_fill_holes(bev: Dictionary, first_new: int) -> void:
	var directed := {}
	for f in faces:
		for i in f.size():
			directed[Vector2i(f[i], f[(i + 1) % f.size()])] = true
	var hole_next := {}
	for e in directed:
		if directed.has(Vector2i(e.y, e.x)):
			continue
		var ok_a: bool = e.x >= first_new or bev.has(e.x)
		var ok_b: bool = e.y >= first_new or bev.has(e.y)
		if ok_a and ok_b:
			hole_next[e.y] = e.x
	var seen := {}
	for start in hole_next.keys():
		if seen.has(start):
			continue
		var loop := PackedInt32Array()
		var cur: int = start
		var closed := false
		while hole_next.has(cur) and not seen.has(cur):
			seen[cur] = true
			loop.append(cur)
			cur = hole_next[cur]
			if cur == start:
				closed = true
				break
		if closed and loop.size() >= 3:
			add_face(loop)
