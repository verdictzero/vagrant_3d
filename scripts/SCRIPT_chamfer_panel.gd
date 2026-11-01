@tool
class_name ChamferPanel
extends Control
## The house frame: 45-degree CUT corners, never rounded. Top-right and
## bottom-left cut by default, the other two square. docs/DOC_ui_style.md s6.

const T := preload("res://scripts/SCRIPT_ui_tokens.gd")

@export var bg_color: Color = T.PANEL_BG:
	set(v): bg_color = v; queue_redraw()
@export var border_color: Color = T.PANEL_BORDER:
	set(v): border_color = v; queue_redraw()
@export var border_width: float = T.BORDER:
	set(v): border_width = v; queue_redraw()
@export var cut_size: float = T.CUT:
	set(v): cut_size = v; queue_redraw()
@export var cut_top_left := false:
	set(v): cut_top_left = v; queue_redraw()
@export var cut_top_right := true:
	set(v): cut_top_right = v; queue_redraw()
@export var cut_bottom_right := false:
	set(v): cut_bottom_right = v; queue_redraw()
@export var cut_bottom_left := true:
	set(v): cut_bottom_left = v; queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var pts := chamfer_points(size, cut_size, cut_top_left, cut_top_right,
			cut_bottom_right, cut_bottom_left)
	draw_colored_polygon(pts, bg_color)
	var outline := pts.duplicate()
	outline.append(pts[0])
	draw_polyline(outline, border_color, border_width, true)


## The chamfered outline of a `s`-sized box, clockwise from the upper-left.
static func chamfer_points(s: Vector2, cut: float, tl := false, tr := true,
		br := false, bl := true) -> PackedVector2Array:
	var c: float = clampf(cut, 0.0, minf(s.x, s.y) * 0.5)
	var pts := PackedVector2Array()
	if tl:
		pts.append(Vector2(0.0, c)); pts.append(Vector2(c, 0.0))
	else:
		pts.append(Vector2(0.0, 0.0))
	if tr:
		pts.append(Vector2(s.x - c, 0.0)); pts.append(Vector2(s.x, c))
	else:
		pts.append(Vector2(s.x, 0.0))
	if br:
		pts.append(Vector2(s.x, s.y - c)); pts.append(Vector2(s.x - c, s.y))
	else:
		pts.append(Vector2(s.x, s.y))
	if bl:
		pts.append(Vector2(c, s.y)); pts.append(Vector2(0.0, s.y - c))
	else:
		pts.append(Vector2(0.0, s.y))
	return pts


## Draw a cursor box (fill + 2px border, small cut) into `canvas` at `rect`.
static func draw_cursor_box(canvas: CanvasItem, rect: Rect2, border: Color,
		fill: Color = T.SEL_BG, cut: float = T.SEL_CUT) -> void:
	var pts := chamfer_points(rect.size, cut)
	for i in pts.size():
		pts[i] += rect.position
	if fill.a > 0.0:
		canvas.draw_colored_polygon(pts, fill)
	var outline := pts.duplicate()
	outline.append(pts[0])
	canvas.draw_polyline(outline, border, T.BORDER, true)
