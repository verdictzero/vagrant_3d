class_name SceneFile
extends RefCounted
## Scenes on disk, and OBJ out.
##
## A scene is JSON in the app's own storage (user://scenes/), the same
## record the undo history keeps: objects in tree order with their parent's
## index, local transform and mesh. OBJ goes to the shared Documents folder
## (Documents/Vagrant3D/ on Android, where a file manager or desktop Blender
## can reach it), or to user://exports/ where that cannot be written.

const DIR := "user://scenes/"
const EXT := ".v3d.json"
const VERSION := 1


static func list() -> PackedStringArray:
	DirAccess.make_dir_recursive_absolute(DIR)
	var out := PackedStringArray()
	for f in DirAccess.get_files_at(DIR):
		if f.ends_with(EXT):
			out.append(f.trim_suffix(EXT))
	out.sort()
	return out


static func next_name() -> String:
	var taken := {}
	for n in list():
		taken[n] = true
	var i := 1
	while taken.has("SCENE %03d" % i):
		i += 1
	return "SCENE %03d" % i


## A name the file system takes: no slashes or the other characters some
## systems refuse, no leading or trailing space.
static func clean_name(n: String) -> String:
	var out := n.strip_edges()
	for ch in ["/", "\\", ":", "*", "?", "\"", "<", ">", "|"]:
		out = out.replace(ch, "")
	return out.strip_edges()


static func path_of(scene_name: String) -> String:
	return DIR + scene_name + EXT


## `snap` is the editor's snapshot: { objects: [{name, group, parent, xf, data}] }.
static func save(scene_name: String, snap: Dictionary, matcap: int) -> bool:
	DirAccess.make_dir_recursive_absolute(DIR)
	var objs := []
	for r in snap.objects:
		var xf: Transform3D = r.xf
		var b := xf.basis
		objs.append({"name": r.name, "group": r.group, "parent": r.parent,
				"xf": [b.x.x, b.x.y, b.x.z, b.y.x, b.y.y, b.y.z, b.z.x, b.z.y, b.z.z,
					xf.origin.x, xf.origin.y, xf.origin.z],
				"mesh": (r.data as MeshData).to_dict(), "modifiers": r.get("mods", []), "smooth": r.get("smooth", false)})
	var doc := {"format": "vagrant3d", "version": VERSION, "matcap": matcap, "objects": objs}
	var f := FileAccess.open(path_of(scene_name), FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(doc, "\t"))
	return true


## The objects of a saved scene, as snapshot records, plus its matcap; {} if
## it cannot be read.
static func load_scene(scene_name: String) -> Dictionary:
	var f := FileAccess.open(path_of(scene_name), FileAccess.READ)
	if f == null:
		return {}
	var doc = JSON.parse_string(f.get_as_text())
	if not (doc is Dictionary) or doc.get("format", "") != "vagrant3d":
		return {}
	var recs := []
	for o in doc.get("objects", []):
		var a: Array = o.xf
		var xf := Transform3D(Basis(Vector3(a[0], a[1], a[2]), Vector3(a[3], a[4], a[5]), Vector3(a[6], a[7], a[8])),
				Vector3(a[9], a[10], a[11]))
		var mods: Array = []
		for mod in o.get("modifiers", []):
			var m: Dictionary = mod
			# JSON reads every number back as a float.
			for k in ["levels", "count", "axis"]:
				if m.has(k):
					m[k] = int(m[k])
			mods.append(m)
		recs.append({"name": String(o.name), "group": bool(o.group), "parent": int(o.parent), "xf": xf,
				"data": MeshData.from_dict(o.mesh), "mods": mods, "smooth": bool(o.get("smooth", false))})
	return {"objects": recs, "matcap": int(doc.get("matcap", 0))}


static func delete(scene_name: String) -> void:
	DirAccess.remove_absolute(path_of(scene_name))


## Every mesh object in world space, one OBJ object each, as it shows: with
## its modifiers. Faces wind
## counter-clockwise seen from outside, which is OBJ's convention, and Y is
## up, which is OBJ's too (Blender turns it to Z up on import by default).
static func obj_text(meshes: Array) -> String:
	var lines := PackedStringArray(["# Vagrant 3D"])
	var offset := 1
	for o in meshes:
		var so := o as SceneObject
		if not so.has_mesh():
			continue
		lines.append("o " + String(so.name).replace(" ", "_"))
		var xf := so.global_transform
		var m: MeshData = so.evaluated if so.evaluated != null else so.data
		for v in m.verts:
			var w := xf * v
			lines.append("v %.6f %.6f %.6f" % [w.x, w.y, w.z])
		for face in m.faces:
			var parts := PackedStringArray(["f"])
			for i in face:
				parts.append(str(i + offset))
			lines.append(" ".join(parts))
		offset += m.verts.size()
	return "\n".join(lines) + "\n"


## Write the OBJ; returns the path written, or "" on failure. `dir_override`
## is for tests.
static func export_obj(scene_name: String, meshes: Array, dir_override := "") -> String:
	var dirs: Array[String] = []
	if dir_override != "":
		dirs.append(dir_override)
	else:
		var docs := OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
		if docs != "":
			dirs.append(docs.path_join("Vagrant3D"))
		dirs.append("user://exports")
	var text := obj_text(meshes)
	for d in dirs:
		if DirAccess.make_dir_recursive_absolute(d) != OK and not DirAccess.dir_exists_absolute(d):
			continue
		var path := d.path_join(scene_name.replace(" ", "_") + ".obj")
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f == null:
			continue
		f.store_string(text)
		f.close()
		return path
	return ""
