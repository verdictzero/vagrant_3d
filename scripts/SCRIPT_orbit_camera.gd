class_name OrbitCamera
extends Node3D
## A camera on a stick: yaw and pitch about `target`, `distance` back.
## Fingers drive it (one drags to orbit, two pan and pinch); the pen never does.
## Perspective or orthographic; the six axis views (FRONT, BACK, LEFT, RIGHT,
## TOP, BOTTOM) are yaw/pitch pairs, and snapping to one turns orthographic
## by itself, the way Blender's auto perspective does, until the next orbit.

var target := Vector3.ZERO
var yaw := -0.6
var pitch := -0.5
var distance := 8.0
var ortho := false
var auto_ortho := false   # ortho because of an axis view; the next orbit undoes it

@onready var camera: Camera3D = $Camera3D

const PITCH_MIN := -PI * 0.5
const PITCH_MAX := PI * 0.5
const DIST_MIN := 0.5
const DIST_MAX := 200.0
const AXIS_EPS := 0.001

## Godot looks down -Z: FRONT is the camera on +Z looking at the origin.
const VIEWS := {
	"FRONT": [0.0, 0.0],
	"BACK": [PI, 0.0],
	"RIGHT": [PI * 0.5, 0.0],
	"LEFT": [-PI * 0.5, 0.0],
	"TOP": [0.0, -PI * 0.5],
	"BOTTOM": [0.0, PI * 0.5],
}
## Which view each axis end is seen from: +X is RIGHT, and so on.
const AXIS_VIEW := {
	Vector3.RIGHT: "RIGHT", Vector3.LEFT: "LEFT", Vector3.UP: "TOP",
	Vector3.DOWN: "BOTTOM", Vector3.BACK: "FRONT", Vector3.FORWARD: "BACK",
}
const OPPOSITE := {"FRONT": "BACK", "BACK": "FRONT", "RIGHT": "LEFT", "LEFT": "RIGHT",
		"TOP": "BOTTOM", "BOTTOM": "TOP"}


func _ready() -> void:
	apply()


func apply() -> void:
	global_position = target
	rotation = Vector3(pitch, yaw, 0.0)
	camera.position = Vector3(0.0, 0.0, distance)
	if ortho:
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		# The same framing at the target as the perspective camera has.
		camera.size = 2.0 * distance * tan(deg_to_rad(camera.fov) * 0.5)
	else:
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE


## Screen-space drag in design pixels. Orbiting leaves an auto-ortho view.
func orbit(delta: Vector2) -> void:
	yaw = wrapf(yaw - delta.x * 0.008, -PI, PI)
	pitch = clampf(pitch - delta.y * 0.008, PITCH_MIN, PITCH_MAX)
	if auto_ortho:
		ortho = false
		auto_ortho = false
	apply()


func pan(delta: Vector2) -> void:
	var k := distance * 0.0016
	target += -camera.global_basis.x * delta.x * k + camera.global_basis.y * delta.y * k
	apply()


## ratio > 1 moves in.
func zoom(ratio: float) -> void:
	distance = clampf(distance / ratio, DIST_MIN, DIST_MAX)
	apply()


func set_ortho(on: bool) -> void:
	ortho = on
	auto_ortho = false
	apply()


## The axis view the camera is on, or "" for a user view.
func view_name() -> String:
	for k in VIEWS:
		var v: Array = VIEWS[k]
		if absf(wrapf(yaw - v[0], -PI, PI)) < AXIS_EPS and absf(pitch - v[1]) < AXIS_EPS:
			return k
	return ""


## Snap to a named view, orthographic. With `flip`, the same view again
## flips to its opposite, the way a second tap on the gizmo does in Blender.
func set_view(view: String, flip := true) -> void:
	if flip and view_name() == view:
		view = OPPOSITE[view]
	var v: Array = VIEWS[view]
	yaw = v[0]
	pitch = v[1]
	if not ortho:
		auto_ortho = true
	ortho = true
	apply()


## Look from the given axis end: +X is the RIGHT view, +Z is FRONT.
func view_from_axis(axis: Vector3) -> void:
	set_view(AXIS_VIEW[axis])
