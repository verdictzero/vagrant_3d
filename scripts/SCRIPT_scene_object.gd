class_name SceneObject
extends Node3D
## One object in the scene: a MeshData and the MeshInstance3D that shows it,
## or a GROUP, which is an object with no mesh that exists to hold children.
## The hierarchy IS the node tree: a child SceneObject is a parented object.
##
## `data` is the cage you edit. `modifiers` run on it in order, and what
## the view draws is the result, `evaluated`; nothing changes the cage until
## a modifier is applied. Each modifier is a Dictionary:
##   { type: "SUBDIVISION", show, levels }
##   { type: "MIRROR", show, axes: [x, y, z] }
##   { type: "ARRAY", show, count, axis, gap }

const MATCAP_SHADER := preload("res://shaders/SHADER_matcap.gdshader")

static var _material: ShaderMaterial
static var matcap_index := 0

var data: MeshData
var mesh_instance: MeshInstance3D
var is_group := false
var modifiers: Array = []
var smooth := false
var evaluated: MeshData
## The object-mode wire, worked out once per rebuild: each edge's ends and
## the faces either side of it (as centre and normal), so the overlay can
## draw only the edges of faces turned to the camera.
var wire: Array = []

const MODIFIER_TYPES := ["SUBDIVISION", "MIRROR", "ARRAY"]
const MAX_LEVELS := 3


static func new_modifier(type: String) -> Dictionary:
	match type:
		"SUBDIVISION": return {"type": type, "show": true, "levels": 1}
		"MIRROR": return {"type": type, "show": true, "axes": [true, false, false]}
		"ARRAY": return {"type": type, "show": true, "count": 2, "axis": 0, "gap": 1.0}
	return {}


static func apply_modifier(m: MeshData, mod: Dictionary) -> MeshData:
	match mod.type:
		"SUBDIVISION":
			return m.subdivided(clampi(int(mod.levels), 0, MAX_LEVELS))
		"MIRROR":
			var out := m
			for a in 3:
				if mod.axes[a]:
					out = out.mirrored(a)
			return out
		"ARRAY":
			return m.arrayed(int(mod.count), int(mod.axis), float(mod.gap))
	return m


## The cage with every shown modifier run on it.
func evaluate() -> MeshData:
	var m := data
	for mod in modifiers:
		if mod.get("show", true):
			m = apply_modifier(m, mod)
	return m


## What the overlay draws as this object's wire in OBJECT mode: the result,
## unless that is too many lines to draw every frame, then the cage.
func display_mesh() -> MeshData:
	return evaluated if evaluated != null and evaluated.edge_count() <= 3000 else data


static func create(object_name: String, mesh_data: MeshData) -> SceneObject:
	var o := SceneObject.new()
	o.name = object_name
	o.data = mesh_data
	o.mesh_instance = MeshInstance3D.new()
	o.mesh_instance.name = "Mesh"
	o.mesh_instance.material_override = material()
	o.add_child(o.mesh_instance)
	o.rebuild()
	return o


static func create_group(object_name: String) -> SceneObject:
	var o := create(object_name, MeshData.new())
	o.is_group = true
	return o


## The one matcap material every object shares.
static func material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = MATCAP_SHADER
		set_matcap(matcap_index)
	return _material


static func set_matcap(i: int) -> void:
	matcap_index = i
	material().set_shader_parameter("matcap", Matcaps.texture(i))


func rebuild() -> void:
	evaluated = evaluate()
	mesh_instance.mesh = evaluated.build_mesh(smooth)
	_build_wire()


func _build_wire() -> void:
	wire = []
	var m := display_mesh()
	var efm := m.edge_face_map()
	var fc := PackedVector3Array()
	var fn := PackedVector3Array()
	for f in m.face_count():
		fc.append(m.face_center(f))
		fn.append(m.face_normal(f))
	for e in efm:
		var sides := []
		for f in efm[e]:
			sides.append([fc[f], fn[f]])
		wire.append([m.verts[e.x], m.verts[e.y], sides])


func has_mesh() -> bool:
	return not is_group and data != null and data.face_count() > 0


## Direct SceneObject children, in tree order.
func child_objects() -> Array[SceneObject]:
	var out: Array[SceneObject] = []
	for c in get_children():
		if c is SceneObject:
			out.append(c)
	return out


func is_descendant_of(other: Node) -> bool:
	var n := get_parent()
	while n != null:
		if n == other:
			return true
		n = n.get_parent()
	return false
