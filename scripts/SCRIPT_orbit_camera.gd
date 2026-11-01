class_name OrbitCamera
extends Node3D
## A camera on a stick: yaw and pitch about `target`, `distance` back.
## Fingers drive it (one drags to orbit, two pan and pinch); the pen never does.

var target := Vector3.ZERO
var yaw := -0.6
var pitch := -0.5
var distance := 8.0

@onready var camera: Camera3D = $Camera3D

const PITCH_MIN := -1.5
const PITCH_MAX := 1.5
const DIST_MIN := 0.5
const DIST_MAX := 200.0


func _ready() -> void:
	apply()


func apply() -> void:
	global_position = target
	rotation = Vector3(pitch, yaw, 0.0)
	camera.position = Vector3(0.0, 0.0, distance)


## Screen-space drag in design pixels.
func orbit(delta: Vector2) -> void:
	yaw -= delta.x * 0.008
	pitch = clampf(pitch - delta.y * 0.008, PITCH_MIN, PITCH_MAX)
	apply()


func pan(delta: Vector2) -> void:
	var k := distance * 0.0016
	target += -camera.global_basis.x * delta.x * k + camera.global_basis.y * delta.y * k
	apply()


## ratio > 1 moves in.
func zoom(ratio: float) -> void:
	distance = clampf(distance / ratio, DIST_MIN, DIST_MAX)
	apply()
