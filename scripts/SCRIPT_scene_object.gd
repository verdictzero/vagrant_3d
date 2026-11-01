class_name SceneObject
extends Node3D
## One object in the scene: a MeshData and the MeshInstance3D that shows it.
## The hierarchy IS the node tree: a child SceneObject is a parented object.

const T := preload("res://scripts/SCRIPT_ui_tokens.gd")

static var _material: StandardMaterial3D

var data: MeshData
var mesh_instance: MeshInstance3D


static func create(object_name: String, mesh_data: MeshData) -> SceneObject:
	var o := SceneObject.new()
	o.name = object_name
	o.data = mesh_data
	o.mesh_instance = MeshInstance3D.new()
	o.mesh_instance.name = "Mesh"
	o.mesh_instance.material_override = _clay()
	o.add_child(o.mesh_instance)
	o.rebuild()
	return o


static func _clay() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.albedo_color = T.CLAY
		_material.roughness = 1.0
	return _material


func rebuild() -> void:
	mesh_instance.mesh = data.build_mesh()


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
