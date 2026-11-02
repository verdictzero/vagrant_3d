class_name TransformGizmo
extends RefCounted
## Blender's transform gizmos at the selection's pivot: MOVE arrows, SCALE
## handles (the same shafts, square ends), ROTATE rings, each on one world
## axis, and a centre handle for a free move or an even scale. Drawn at a
## fixed size on screen, whatever the zoom. Without colour the axes are told
## apart by their letters, as on the axes ball.

const T := preload("res://scripts/SCRIPT_ui_tokens.gd")

const LEN := 92.0           # px, pivot to arrow tip, and the rings' radius
const SHAFT_FROM := 0.22
const HEAD := 10.0
const CENTRE := 9.0
const RING_SEGS := 48
const MIN_SHAFT := 18.0     # px; an axis pointing at the camera hides
const AXES := [Vector3.RIGHT, Vector3.UP, Vector3.BACK]
const NAMES := ["X", "Y", "Z"]

var kind := ""              # "MOVE", "ROTATE", "SCALE", or "" for none
var pivot := Vector3.ZERO
var camera: Camera3D
var viewport_h := 900.0


func visible() -> bool:
	return kind != "" and camera != null and not camera.is_position_behind(pivot)


## World units per screen pixel at the pivot.
func world_per_px() -> float:
	if camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		return camera.size / viewport_h
	var depth := (pivot - camera.global_position).dot(-camera.global_basis.z)
	return maxf(depth, 0.05) * 2.0 * tan(deg_to_rad(camera.fov) * 0.5) / viewport_h


func centre() -> Vector2:
	return camera.unproject_position(pivot)


## A shaft's screen ends for axis `i`, or [] when it points at the camera.
func shaft(i: int) -> Array:
	var k := world_per_px() * LEN
	var tip: Vector3 = pivot + AXES[i] * k
	if camera.is_position_behind(tip):
		return []
	var a := camera.unproject_position(pivot + AXES[i] * k * SHAFT_FROM)
	var b := camera.unproject_position(tip)
	if centre().distance_to(b) < MIN_SHAFT:
		return []
	return [a, b]


## Ring `i`, round axis i, as a closed screen polyline.
func ring(i: int) -> PackedVector2Array:
	var k := world_per_px() * LEN
	var u: Vector3 = AXES[(i + 1) % 3]
	var v: Vector3 = AXES[(i + 2) % 3]
	var pts := PackedVector2Array()
	for s in RING_SEGS + 1:
		var t := TAU * float(s) / float(RING_SEGS)
		var w := pivot + (u * cos(t) + v * sin(t)) * k
		if camera.is_position_behind(w):
			return PackedVector2Array()
		pts.append(camera.unproject_position(w))
	return pts


## The handle under `pos`: "X" "Y" "Z" (an axis), "C" (the centre), or "".
func pick(pos: Vector2, radius: float) -> String:
	if not visible():
		return ""
	if kind != "ROTATE" and centre().distance_to(pos) <= maxf(radius, CENTRE + 4.0):
		return "C"
	var best := ""
	var best_d := radius
	for i in 3:
		var d := INF
		if kind == "ROTATE":
			var pts := ring(i)
			for s in range(pts.size() - 1):
				d = minf(d, Geometry2D.get_closest_point_to_segment(pos, pts[s], pts[s + 1]).distance_to(pos))
		else:
			var sh := shaft(i)
			if sh.is_empty():
				continue
			var tip: Vector2 = sh[1]
			var ext: Vector2 = tip + (tip - centre()).normalized() * HEAD
			d = Geometry2D.get_closest_point_to_segment(pos, sh[0], ext).distance_to(pos)
		if d < best_d:
			best_d = d
			best = NAMES[i]
	return best


func draw(ci: CanvasItem, hover: String, active: String) -> void:
	if not visible():
		return
	var bold: Font = Fonts.ui("bold")
	var c := centre()
	for i in 3:
		var name: String = NAMES[i]
		var lit := name == active or (active == "" and name == hover)
		var col := T.COL_CURSOR if lit else T.COL_READY
		var w := 2.5 if lit else 1.5
		var label_at := Vector2.ZERO
		if kind == "ROTATE":
			var pts := ring(i)
			if pts.is_empty():
				continue
			ci.draw_polyline(pts, T.KEYLINE, w + 2.0, true)
			ci.draw_polyline(pts, col, w, true)
			label_at = pts[6]
		else:
			var sh := shaft(i)
			if sh.is_empty():
				continue
			var a: Vector2 = sh[0]
			var b: Vector2 = sh[1]
			var dir := (b - c).normalized()
			var side := Vector2(-dir.y, dir.x)
			ci.draw_line(a, b, T.KEYLINE, w + 2.0, true)
			ci.draw_line(a, b, col, w, true)
			if kind == "MOVE":
				var tri := PackedVector2Array([b + dir * HEAD, b + side * HEAD * 0.5, b - side * HEAD * 0.5])
				ci.draw_colored_polygon(tri, col)
				label_at = b + dir * (HEAD + 10.0)
			else:
				ci.draw_rect(Rect2(b - Vector2(HEAD, HEAD) * 0.5, Vector2(HEAD, HEAD)), col, true)
				label_at = b + dir * (HEAD + 8.0)
		var tw := bold.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FS_HINT).x
		ci.draw_string_outline(bold, label_at + Vector2(-tw * 0.5, T.FS_HINT * 0.36), name,
				HORIZONTAL_ALIGNMENT_LEFT, -1, T.FS_HINT, 3, Color.BLACK)
		ci.draw_string(bold, label_at + Vector2(-tw * 0.5, T.FS_HINT * 0.36), name,
				HORIZONTAL_ALIGNMENT_LEFT, -1, T.FS_HINT, col)
	if kind != "ROTATE":
		var lit_c := active == "C" or (active == "" and hover == "C")
		var box := Rect2(c - Vector2(CENTRE, CENTRE), Vector2(CENTRE, CENTRE) * 2.0)
		ci.draw_rect(box.grow(1.0), T.KEYLINE, false, 3.0)
		ci.draw_rect(box, T.COL_CURSOR if lit_c else T.COL_READY, false, 2.0 if lit_c else 1.5)
