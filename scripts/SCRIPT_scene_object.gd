class_name SceneObject
extends Node3D
## One object in the scene: a MeshData and the MeshInstance3D that shows it,
## or a GROUP, which is an object with no mesh that exists to hold children.
## The hierarchy IS the node tree: a child SceneObject is a parented object.

const MATCAP_SHADER := preload("res://shaders/SHADER_matcap.gdshader")

static var _material: ShaderMaterial
static var matcap_index := 0

var data: MeshData
var mesh_instance: MeshInstance3D
var is_group := false


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
	mesh_instance.mesh = data.build_mesh()


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
