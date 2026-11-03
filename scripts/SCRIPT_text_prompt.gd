class_name TextPrompt
extends Control
## A one-line text question: a title, a field, OK and CANCEL. On Android the
## field brings up the on-screen keyboard when it takes focus. Enter is OK,
## Escape is CANCEL.

const T := preload("res://scripts/SCRIPT_ui_tokens.gd")
const Chamfer := preload("res://scripts/SCRIPT_chamfer_panel.gd")

signal submitted(text: String)
signal cancelled

const W := 420.0
const H := 132.0

var title := ""
var line: LineEdit
var buttons: RowList


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	size = Vector2(W, H)
	visible = false
	line = LineEdit.new()
	line.position = Vector2(T.PAD, 34.0)
	line.size = Vector2(W - T.PAD * 2, T.ROW_H)
	line.add_theme_font_override("font", Fonts.ui())
	line.add_theme_font_size_override("font_size", T.FS_ROW)
	line.add_theme_color_override("font_color", T.COL_NAME)
	line.add_theme_color_override("caret_color", T.COL_CURSOR)
	line.add_theme_color_override("selection_color", Color(1, 1, 1, 0.25))
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0, 0, 0, 0.6)
	box.border_color = T.COL_TAG
	box.set_border_width_all(1)
	box.set_corner_radius_all(0)
	box.content_margin_left = 8.0
	box.content_margin_right = 8.0
	line.add_theme_stylebox_override("normal", box)
	var focus := box.duplicate()
	focus.border_color = T.COL_CURSOR
	line.add_theme_stylebox_override("focus", focus)
	line.text_submitted.connect(func(_t: String) -> void: _ok())
	add_child(line)
	buttons = RowList.new()
	buttons.horizontal = true
	buttons.set_items([{"id": "OK", "text": "OK"}, {"id": "CANCEL", "text": "CANCEL"}])
	buttons.tapped.connect(func(id: Variant) -> void:
		if id == "OK":
			_ok()
		else:
			cancel())
	add_child(buttons)


func ask(question: String, text: String) -> void:
	title = question
	line.text = text
	visible = true
	buttons.size = buttons.content_size()
	buttons.position = Vector2(W - T.PAD * 0.5 - buttons.size.x, H - T.ROW_H - 10.0)
	line.grab_focus()
	line.select_all()
	queue_redraw()


func cancel() -> void:
	if not visible:
		return
	visible = false
	line.release_focus()
	cancelled.emit()


func _ok() -> void:
	if not visible:
		return
	visible = false
	line.release_focus()
	submitted.emit(line.text)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		cancel()
		accept_event()


func _draw() -> void:
	var pts := Chamfer.chamfer_points(size, T.ROW_CUT)
	draw_colored_polygon(pts, Color(T.PANEL_BG, 0.96))
	var ring := pts.duplicate()
	ring.append(pts[0])
	draw_polyline(ring, T.PANEL_BORDER, T.BORDER, true)
	var f: Font = Fonts.ui()
	draw_string(f, Vector2(T.PAD, 24.0), title, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FS_LABEL, T.COL_TAG)
