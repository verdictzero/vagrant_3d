extends Node3D
## The editor, laid out the way Blender is: the header across the top, the
## tool column down the left, the hierarchy over the properties down the
## right, the view in the middle with the axes ball in its corner. Objects,
## groups, primitives, the three element modes, tools, snapping, matcaps.
##
## Two pointers, told apart by event class:
##   fingers  InputEventScreenTouch/Drag   camera (1 orbits, 2 pan + pinch),
##                                         taps select, drags move in MOVE
##   pen      InputEventMouse*             picks, hovers, box-selects, moves;
##                                         never moves the camera
## A desktop mouse is a pen. Middle-drag orbits and the wheel zooms, for a desk.

const T := preload("res://scripts/SCRIPT_ui_tokens.gd")
const Chamfer := preload("res://scripts/SCRIPT_chamfer_panel.gd")
const Rows := preload("res://scripts/SCRIPT_row_list.gd")
const Overlay := preload("res://scripts/SCRIPT_viewport_overlay.gd")
const Grid := preload("res://scripts/SCRIPT_matcap_grid.gd")
const ToolWin := preload("res://scripts/SCRIPT_tool_window.gd")
const Gizmo := preload("res://scripts/SCRIPT_nav_gizmo.gd")

enum Mode { OBJECT, EDIT }
enum Elem { VERT, EDGE, FACE }
enum Pointer { SELECT, MOVE, TOOL }

const RIGHT_W := 250.0
const LEFT_W := 48.0
const TOOL_ROW := 44.0
const BAR_H := T.ROW_H + 12.0
const PEN_RADIUS := 12.0
const FINGER_RADIUS := 24.0
const SNAP_RADIUS := 22.0
const TAP_SLOP := 10.0
const TAP_TIME := 0.35
const POPOVER_W := 272.0

const PRIMITIVES := ["PLANE", "CUBE", "CYLINDER", "SPHERE"]
const TOOLS := ["TRANSLATE", "ROTATE", "EXTRUDE", "EXTRUDE NORMALS"]
const TOOLS_LATER := ["BEVEL", "INSET"]
## The tool column, per mode. SELECT and MOVE are pointers; the rest are tools.
const TOOLBAR := {
	Mode.OBJECT: [["SELECT", &"select"], ["MOVE", &"move"], ["ROTATE", &"rotate"], ["DELETE", &"delete"]],
	Mode.EDIT: [["SELECT", &"select"], ["MOVE", &"move"], ["ROTATE", &"rotate"], ["EXTRUDE", &"extrude"],
		["EXTRUDE NORMALS", &"extrude_normals"], ["BEVEL", &"bevel"], ["INSET", &"inset"], ["DELETE", &"delete"]],
}
const TOOL_UNITS_PER_PX := 0.0025   # times the camera distance
const ROT_DEG_PER_PX := 0.5
const ROT_STEP := 5.0
const STEPS := [1.0, 0.5, 0.25, 0.1]

# --- state -------------------------------------------------------------------

var mode: Mode = Mode.OBJECT
var elem: Elem = Elem.VERT
var pointer: Pointer = Pointer.SELECT

var sel_objects: Array[SceneObject] = []
var active_object: SceneObject = null
var sel_verts: Dictionary = {}
var sel_edges: Dictionary = {}
var sel_faces: Dictionary = {}

var hover_object: SceneObject = null
var hover_kind: int = -1
var hover_index: int = -1
var pen_hover_valid := false
var pen_hover_pos := Vector2.ZERO

var box_active := false
var _box_from := Vector2.ZERO
var _box_to := Vector2.ZERO

var view_rect := Rect2()

# Snapping. On by default: moves land on the grid unless you turn it off.
var snap_on := true
var snap_targets: Dictionary = {"INCREMENT": true, "VERTEX": false, "EDGE": false, "FACE": false}
var snap_step := 0.25
var snap_absolute := true     # positions land ON the grid, not just in steps of it
var snap_self := false        # in EDIT, the object's own unselected elements count
var snap_hit: Dictionary = {} # {point, kind} while a move is held to a target

# Tools. One runs at a time, live, until APPLY or CANCEL (or anything that
# changes the selection or mode, which applies it). See "tools" below.
var current_tool := "TRANSLATE"
var tool_job: Dictionary = {}
var _tool_backup: MeshData
var _tool_sel_backup: Array = []
var _tool_drag_from: Array = []
var _tool_drag_origin := Vector2.ZERO

# --- nodes -------------------------------------------------------------------

@onready var world_root: Node3D = $Scene
@onready var orbit: OrbitCamera = $OrbitCamera
@onready var ui: CanvasLayer = $UI

var right_panel: ChamferPanel
var props_panel: ChamferPanel
var top_panel: ChamferPanel
var left_panel: ChamferPanel
var hierarchy: RowList
var props_list: RowList
var toolbar: RowList
var mode_list: RowList
var elem_list: RowList
var add_bar: RowList
var add_menu: RowList
var toggle_list: RowList
var gizmo: NavGizmo
var proj_list: RowList
var overlay: ViewportOverlay
var popover: ChamferPanel
var popover_kind := ""
var snap_menu: RowList
var matcap_grid: MatcapGrid
var tool_window: ToolWindow
var _headings: Array[Label] = []

# --- gesture bookkeeping -----------------------------------------------------

var _touches: Dictionary = {}       # index -> {pos, start, time, cancelled}
var _pinch_center := Vector2.ZERO
var _pinch_dist := 0.0
var _finger_moving := false
var _pen_down := false
var _pen_start := Vector2.ZERO
var _pen_dragging := false
var _pen_moving := false
var _pen_tooling := false
var _finger_tooling := false
var _middle_down := false
var _move_plane := Plane()
var _move_start := Vector3.ZERO
var _move_pivot := Vector3.ZERO
var _move_obj_start: Dictionary = {}    # SceneObject -> global_position
var _move_vert_start := PackedVector3Array()
var _moving_set: Dictionary = {}        # objects a snap must not target


func _ready() -> void:
	_build_world()
	_build_ui()
	get_viewport().size_changed.connect(_layout)
	_layout()
	_refresh_lists()


func camera() -> Camera3D:
	return orbit.camera


# --- world ---------------------------------------------------------------------

func _build_world() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = T.WORLD_BG
	add_child(env)
	add_child(_grid())
	SceneObject.material()


func _grid() -> MeshInstance3D:
	var im := ImmediateMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	im.surface_begin(Mesh.PRIMITIVE_LINES, mat)
	for i in range(-10, 11):
		var c := T.AXIS if i == 0 else T.GRID
		im.surface_set_color(c)
		im.surface_add_vertex(Vector3(i, 0, -10)); im.surface_add_vertex(Vector3(i, 0, 10))
		im.surface_add_vertex(Vector3(-10, 0, i)); im.surface_add_vertex(Vector3(10, 0, i))
	im.surface_end()
	var mi := MeshInstance3D.new()
	mi.name = "Grid"
	mi.mesh = im
	return mi


# --- ui ------------------------------------------------------------------------

func _build_ui() -> void:
	overlay = Overlay.new()
	overlay.editor = self
	ui.add_child(overlay)

	right_panel = Chamfer.new()
	right_panel.cut_top_left = true
	right_panel.cut_top_right = false
	right_panel.cut_bottom_left = false
	right_panel.cut_bottom_right = true
	ui.add_child(right_panel)
	props_panel = Chamfer.new()
	props_panel.cut_top_left = true
	props_panel.cut_top_right = false
	props_panel.cut_bottom_left = false
	props_panel.cut_bottom_right = true
	ui.add_child(props_panel)
	top_panel = Chamfer.new()
	top_panel.cut_size = T.ROW_CUT
	ui.add_child(top_panel)
	left_panel = Chamfer.new()
	left_panel.cut_size = T.ROW_CUT
	left_panel.cut_top_right = false
	left_panel.cut_bottom_right = true
	ui.add_child(left_panel)

	_headings.append(_heading("HIERARCHY"))
	hierarchy = Rows.new()
	hierarchy.draggable = true
	hierarchy.tapped.connect(_on_hierarchy_tapped)
	hierarchy.drag_dropped.connect(_on_hierarchy_dropped)
	ui.add_child(hierarchy)

	_headings.append(_heading("PROPERTIES"))
	props_list = Rows.new()
	ui.add_child(props_list)

	toolbar = Rows.new()
	toolbar.icon_only = true
	toolbar.row_h = TOOL_ROW
	toolbar.tapped.connect(_on_toolbar_tapped)
	ui.add_child(toolbar)

	mode_list = _bar([{"id": "OBJECT", "text": "OBJECT", "icon": &"object"},
			{"id": "EDIT", "text": "EDIT", "icon": &"edit"}], _on_mode_tapped)
	elem_list = _bar([{"id": "VERT", "text": "VERT", "icon": &"vert"},
			{"id": "EDGE", "text": "EDGE", "icon": &"edge"},
			{"id": "FACE", "text": "FACE", "icon": &"face"}], _on_elem_tapped)
	add_bar = _bar([{"id": "ADD", "text": "ADD", "icon": &"add"}], _on_toggle_tapped)
	toggle_list = _bar([{"id": "SNAP", "text": "SNAP", "icon": &"snap", "lit": true},
			{"id": "SHADING", "text": "SHADING", "icon": &"shading"}], _on_toggle_tapped)

	gizmo = Gizmo.new()
	gizmo.camera = camera()
	gizmo.axis_tapped.connect(_on_gizmo_axis)
	gizmo.orbited.connect(_orbit)
	ui.add_child(gizmo)
	proj_list = _bar([{"id": "ORTHO", "text": "ORTHO"}], _on_proj_tapped)

	# The popover: one frame that holds the snap menu, the add menu or the
	# matcap gallery.
	popover = Chamfer.new()
	popover.cut_size = T.ROW_CUT
	popover.cut_top_right = false
	popover.cut_bottom_right = true
	popover.visible = false
	ui.add_child(popover)
	snap_menu = Rows.new()
	snap_menu.tapped.connect(_on_snap_tapped)
	snap_menu.visible = false
	ui.add_child(snap_menu)
	add_menu = Rows.new()
	var adds: Array[Dictionary] = []
	for prim in PRIMITIVES:
		adds.append({"id": prim, "text": prim, "icon": StringName(prim.to_lower())})
	adds.append({"id": "GROUP", "text": "GROUP", "icon": &"group"})
	add_menu.set_items(adds)
	add_menu.tapped.connect(_on_add_tapped)
	add_menu.visible = false
	ui.add_child(add_menu)
	matcap_grid = Grid.new()
	matcap_grid.picked.connect(_on_matcap_picked)
	matcap_grid.visible = false
	ui.add_child(matcap_grid)
	tool_window = ToolWin.new()
	tool_window.value_changed.connect(tool_set)
	tool_window.applied.connect(tool_apply)
	tool_window.cancelled.connect(tool_cancel)
	ui.add_child(tool_window)


func _bar(items: Array[Dictionary], handler: Callable) -> RowList:
	var l := Rows.new()
	l.horizontal = true
	l.set_items(items)
	l.tapped.connect(handler)
	ui.add_child(l)
	return l


func _heading(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", Fonts.ui())
	l.add_theme_font_size_override("font_size", T.FS_LABEL)
	l.add_theme_color_override("font_color", T.COL_TAG)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(l)
	return l


func _layout() -> void:
	var s := get_viewport().get_visible_rect().size
	var m := float(T.MARGIN)
	var pad := float(T.PAD)
	# Right column: the hierarchy over the properties, half each.
	var rx := s.x - m - RIGHT_W
	var col_h := s.y - m * 2.0
	var half := (col_h - T.GUTTER) * 0.5
	right_panel.position = Vector2(rx, m)
	right_panel.size = Vector2(RIGHT_W, half)
	props_panel.position = Vector2(rx, m + half + T.GUTTER)
	props_panel.size = Vector2(RIGHT_W, half)
	_headings[0].position = Vector2(rx + pad, m + 10.0)
	hierarchy.position = Vector2(rx + 4.0, m + 10.0 + T.FS_LABEL + 6.0)
	hierarchy.size = Vector2(RIGHT_W - 8.0, right_panel.position.y + right_panel.size.y - 10.0 - hierarchy.position.y)
	_headings[1].position = Vector2(rx + pad, props_panel.position.y + 10.0)
	props_list.position = Vector2(rx + 4.0, props_panel.position.y + 10.0 + T.FS_LABEL + 6.0)
	props_list.size = Vector2(RIGHT_W - 8.0, props_panel.position.y + props_panel.size.y - 10.0 - props_list.position.y)
	# Header, left of the column.
	top_panel.position = Vector2(m, m)
	top_panel.size = Vector2(rx - T.GUTTER - m, BAR_H)
	var ry := m + 6.0
	var x := m + 6.0
	for l in [mode_list, elem_list, add_bar]:
		l.position = Vector2(x, ry)
		l.size = l.content_size()
		x += l.size.x + T.GUTTER
	toggle_list.size = toggle_list.content_size()
	toggle_list.position = Vector2(top_panel.position.x + top_panel.size.x - 6.0 - toggle_list.size.x, ry)
	# Tool column, under the header.
	var top := m + BAR_H + T.GUTTER
	left_panel.position = Vector2(m, top)
	left_panel.size = Vector2(LEFT_W, s.y - top - m)
	toolbar.position = Vector2(m + 2.0, top + 6.0)
	toolbar.size = Vector2(LEFT_W - 4.0, left_panel.size.y - 12.0)
	# What is left is the view, with the axes ball in its top-right corner.
	var vx := m + LEFT_W + T.GUTTER
	view_rect = Rect2(vx, top, rx - T.GUTTER - vx, s.y - top - m)
	gizmo.position = Vector2(view_rect.end.x - NavGizmo.SIZE - 4.0, view_rect.position.y + 4.0)
	proj_list.size = proj_list.content_size()
	proj_list.position = Vector2(gizmo.position.x + (NavGizmo.SIZE - proj_list.size.x) * 0.5,
			gizmo.position.y + NavGizmo.SIZE)
	_place_tool_window()
	_place_popover()


func _refresh_lists() -> void:
	# Hierarchy, depth-first, in tree order, with the tree lines worked out.
	var items: Array[Dictionary] = []
	_walk(world_root, [], items)
	hierarchy.set_items(items)
	var sel := {}
	for o in sel_objects:
		sel[o.get_instance_id()] = true
	hierarchy.set_selected(sel)
	hierarchy.set_active(active_object.get_instance_id() if active_object != null else null)
	# Mode bar.
	mode_list.set_active("OBJECT" if mode == Mode.OBJECT else "EDIT")
	mode_list.items[1].disabled = active_object == null or not active_object.has_mesh()
	for it in elem_list.items:
		it.disabled = mode == Mode.OBJECT
	elem_list.set_active(["VERT", "EDGE", "FACE"][elem] if mode == Mode.EDIT else null)
	_refresh_toolbar()
	toggle_list.items[0].lit = snap_on
	toggle_list.set_active(popover_kind if popover.visible and popover_kind != "ADD" else null)
	add_bar.set_active("ADD" if popover.visible and popover_kind == "ADD" else null)
	proj_list.items[0].lit = orbit.ortho
	proj_list.set_active(null)
	mode_list.queue_redraw()
	elem_list.queue_redraw()
	toggle_list.queue_redraw()
	proj_list.queue_redraw()
	_refresh_snap_menu()
	_refresh_props()


## The tool column: the pointers, then the tools this mode has, then
## DELETE. Tools that cannot run on what is selected are dimmed.
func _refresh_toolbar() -> void:
	var items: Array[Dictionary] = []
	var can_delete: bool = (not sel_objects.is_empty()) if mode == Mode.OBJECT else (not sel_verts.is_empty())
	for entry in TOOLBAR[mode]:
		var id: String = entry[0]
		var dis := false
		match id:
			"SELECT", "MOVE": dis = false
			"DELETE": dis = not can_delete
			_: dis = not tool_available(id) and not (tool_live() and tool_kind() == id)
		items.append({"id": id, "text": id, "icon": entry[1], "disabled": dis})
	toolbar.set_items(items)
	var act := "SELECT"
	if pointer == Pointer.MOVE:
		act = "MOVE"
	elif pointer == Pointer.TOOL:
		act = current_tool
	toolbar.set_active(act if toolbar.index_of(act) >= 0 else null)


## The properties panel: what the active object is and where it sits. A
## first cut; it will grow.
func _refresh_props() -> void:
	var rows: Array[Dictionary] = []
	var o := active_object
	if o == null:
		rows.append({"id": "_none", "text": "NOTHING SELECTED", "inert": true, "disabled": true})
		props_list.set_items(rows)
		return
	rows.append({"id": "_name", "text": o.name, "icon": &"group" if o.is_group else &"mesh", "inert": true})
	rows.append({"id": "_tl", "text": "LOCATION", "heading": true})
	var pos := o.position
	for i in 3:
		rows.append({"id": "_l%d" % i, "text": "XYZ"[i], "value": "%+.2f" % pos[i], "value_clock": true, "inert": true})
	rows.append({"id": "_tr", "text": "ROTATION", "heading": true})
	var rot := o.rotation_degrees
	for i in 3:
		rows.append({"id": "_r%d" % i, "text": "XYZ"[i], "value": "%+.1f" % rot[i], "value_clock": true, "inert": true})
	if o.has_mesh():
		rows.append({"id": "_tm", "text": "MESH", "heading": true})
		rows.append({"id": "_mv", "text": "VERTS", "value": "%03d" % o.data.vert_count(), "value_clock": true, "inert": true})
		rows.append({"id": "_me", "text": "EDGES", "value": "%03d" % o.data.edge_count(), "value_clock": true, "inert": true})
		rows.append({"id": "_mf", "text": "FACES", "value": "%03d" % o.data.face_count(), "value_clock": true, "inert": true})
	elif o.is_group:
		rows.append({"id": "_tg", "text": "GROUP", "heading": true})
		rows.append({"id": "_gc", "text": "CHILDREN", "value": "%03d" % o.child_objects().size(), "value_clock": true, "inert": true})
	props_list.set_items(rows)


func _walk(n: Node, trail: Array, out: Array[Dictionary]) -> void:
	var kids: Array[SceneObject] = []
	for c in n.get_children():
		if c is SceneObject:
			kids.append(c)
	for i in kids.size():
		var c := kids[i]
		var last := i == kids.size() - 1
		out.append({"id": c.get_instance_id(), "text": c.name, "depth": trail.size(),
				"icon": &"group" if c.is_group else &"mesh", "tree": trail.duplicate(), "last": last})
		var t := trail.duplicate()
		t.append(not last)
		_walk(c, t, out)


func objects() -> Array[SceneObject]:
	var out: Array[SceneObject] = []
	_collect(world_root, out)
	return out


func _collect(n: Node, out: Array[SceneObject]) -> void:
	for c in n.get_children():
		if c is SceneObject:
			out.append(c)
			_collect(c, out)


func status_words() -> String:
	var view := orbit.view_name()
	var words: String = (view if view != "" else "USER") + (" ORTHO" if orbit.ortho else " PERSP")
	words += "    " + ("OBJECT" if mode == Mode.OBJECT else "EDIT  " + ["VERT", "EDGE", "FACE"][elem])
	if active_object != null:
		words += "    " + active_object.name
	if snap_on:
		var on: Array = []
		for k in snap_targets:
			if snap_targets[k]:
				on.append(k)
		words += "    SNAP " + " ".join(on)
	return words


func status_counts() -> Array:
	if active_object == null:
		return [["OBJECTS", objects().size()]]
	if active_object.is_group:
		return [["CHILDREN", active_object.child_objects().size()]]
	var d := active_object.data
	if mode == Mode.EDIT:
		return [["V", "%02d/%02d" % [sel_verts.size(), d.vert_count()]],
				["E", "%02d/%02d" % [sel_edges.size(), d.edge_count()]],
				["F", "%02d/%02d" % [sel_faces.size(), d.face_count()]]]
	return [["V", d.vert_count()], ["E", d.edge_count()], ["F", d.face_count()]]


# --- popovers ------------------------------------------------------------------

func open_popover(kind: String) -> void:
	if popover.visible and popover_kind == kind:
		close_popover()
		return
	popover_kind = kind
	popover.visible = true
	snap_menu.visible = kind == "SNAP"
	add_menu.visible = kind == "ADD"
	matcap_grid.visible = kind == "SHADING"
	_refresh_snap_menu()
	matcap_grid.set_active(SceneObject.matcap_index)
	_place_popover()
	_refresh_lists()


func close_popover() -> void:
	if not popover.visible:
		return
	popover.visible = false
	snap_menu.visible = false
	add_menu.visible = false
	matcap_grid.visible = false
	_refresh_lists()


func _place_popover() -> void:
	if not popover.visible:
		return
	var anchor: Vector2
	if popover_kind == "ADD":
		anchor = add_bar.position
	else:
		var i := toggle_list.index_of(popover_kind)
		anchor = toggle_list.position + toggle_list.row_rect(maxi(i, 0)).position
	var top := view_rect.position.y - 2.0
	if popover_kind == "SNAP" or popover_kind == "ADD":
		var menu: RowList = snap_menu if popover_kind == "SNAP" else add_menu
		menu.size = Vector2(POPOVER_W - 8.0, 0.0)
		var h: float = menu.content_size().y
		popover.size = Vector2(POPOVER_W, h + 16.0)
		popover.position = Vector2(clampf(anchor.x, view_rect.position.x, view_rect.end.x - POPOVER_W), top)
		menu.position = popover.position + Vector2(4.0, 8.0)
		menu.size = Vector2(POPOVER_W - 8.0, h)
	else:
		var g := MatcapGrid.grid_size()
		popover.size = g + Vector2(T.PAD * 2, T.PAD * 2)
		popover.position = Vector2(minf(anchor.x, view_rect.end.x - popover.size.x), top)
		matcap_grid.position = popover.position + Vector2(T.PAD, T.PAD)


func _refresh_snap_menu() -> void:
	var rows: Array[Dictionary] = [
		{"id": "SNAP", "text": "SNAP", "icon": &"snap", "on": snap_on},
		{"id": "_t", "text": "TARGET", "heading": true},
		{"id": "INCREMENT", "text": "INCREMENT", "on": snap_targets.INCREMENT, "disabled": not snap_on},
		{"id": "VERTEX", "text": "VERTEX", "icon": &"vert", "on": snap_targets.VERTEX, "disabled": not snap_on},
		{"id": "EDGE", "text": "EDGE", "icon": &"edge", "on": snap_targets.EDGE, "disabled": not snap_on},
		{"id": "FACE", "text": "FACE", "icon": &"face", "on": snap_targets.FACE, "disabled": not snap_on},
		{"id": "_i", "text": "INCREMENT", "heading": true},
		{"id": "STEP", "text": "STEP", "value": "%.2f" % snap_step, "value_clock": true,
				"disabled": not (snap_on and snap_targets.INCREMENT)},
		{"id": "ABSOLUTE", "text": "ABSOLUTE GRID", "on": snap_absolute,
				"disabled": not (snap_on and snap_targets.INCREMENT)},
		{"id": "_o", "text": "OPTIONS", "heading": true},
		{"id": "SELF", "text": "SNAP TO SELF", "on": snap_self, "disabled": not snap_on},
	]
	snap_menu.set_items(rows)


func _on_snap_tapped(id: Variant) -> void:
	match id:
		"SNAP": snap_on = not snap_on
		"INCREMENT", "VERTEX", "EDGE", "FACE": snap_targets[id] = not snap_targets[id]
		"STEP": snap_step = STEPS[(STEPS.find(snap_step) + 1) % STEPS.size()]
		"ABSOLUTE": snap_absolute = not snap_absolute
		"SELF": snap_self = not snap_self
	_refresh_lists()
	_place_popover()


func _on_matcap_picked(i: int) -> void:
	SceneObject.set_matcap(i)
	matcap_grid.set_active(i)


func _on_toggle_tapped(id: Variant) -> void:
	open_popover(id)


# --- rows ----------------------------------------------------------------------

func _on_hierarchy_tapped(id: Variant) -> void:
	var o := instance_from_id(id) as SceneObject
	if o == null:
		return
	select_object(o)


func _on_hierarchy_dropped(from_id: Variant, to_id: Variant) -> void:
	var o := instance_from_id(from_id) as SceneObject
	if o == null:
		return
	var target: Node = world_root
	if to_id != null:
		target = instance_from_id(to_id) as SceneObject
		if target == null:
			return
	reparent_object(o, target)


func _on_add_tapped(id: Variant) -> void:
	close_popover()
	if id == "GROUP":
		add_group()
	else:
		add_primitive(id)


## The tool column. SELECT and MOVE are pointers. A tool makes TOOL the
## pointer and, if it can run on the selection, starts at once.
func _on_toolbar_tapped(id: Variant) -> void:
	match id:
		"SELECT":
			pointer = Pointer.SELECT
		"MOVE":
			pointer = Pointer.MOVE
		"DELETE":
			delete_selected()
		_:
			pointer = Pointer.TOOL
			current_tool = id
			if not (tool_live() and tool_kind() == id):
				tool_start(id)
	_refresh_lists()


func _on_proj_tapped(_id: Variant) -> void:
	orbit.set_ortho(not orbit.ortho)
	_refresh_lists()


func _on_gizmo_axis(axis: Vector3) -> void:
	orbit.view_from_axis(axis)
	_refresh_lists()


## Every orbit goes through here so an axis view's auto-ortho is undone.
func _orbit(delta: Vector2) -> void:
	var was := orbit.ortho
	orbit.orbit(delta)
	if was != orbit.ortho:
		_refresh_lists()


func _on_mode_tapped(id: Variant) -> void:
	set_mode(Mode.OBJECT if id == "OBJECT" else Mode.EDIT)


func _on_elem_tapped(id: Variant) -> void:
	set_elem({"VERT": Elem.VERT, "EDGE": Elem.EDGE, "FACE": Elem.FACE}[id])


# --- tools ---------------------------------------------------------------------
#
# A tool is a JOB: { kind, props, ... }. Its props are what the tool window
# shows and what its sliders edit; the job knows how to put the selection
# where the props say (`_tool_apply_props`), from a record of where things
# were when it started. One job at a time, live until APPLY or CANCEL;
# anything that moves on from the selection applies it first.
#
#   TRANSLATE        X Y Z, world units. A MOVE drag is this tool.
#   ROTATE           X Y Z, degrees, about the selection's centre
#   EXTRUDE          AMOUNT along the region's normal   (EDIT only)
#   EXTRUDE NORMALS  AMOUNT along each vertex's own     (EDIT only)

func tool_available(kind: String) -> bool:
	match kind:
		"TRANSLATE", "ROTATE":
			return has_moveable()
		"EXTRUDE", "EXTRUDE NORMALS":
			return mode == Mode.EDIT and active_object != null and not sel_verts.is_empty()
	return false


func tool_live() -> bool:
	return not tool_job.is_empty()


func tool_kind() -> String:
	return tool_job.get("kind", "")


func tool_values() -> Array:
	var out := []
	for p in tool_job.get("props", []):
		out.append(p.value)
	return out


func tool_value(i: int = 0) -> float:
	return tool_job.props[i].value if tool_live() else 0.0


## Start `kind` on the selection, at zero, and put the window up.
func tool_start(kind: String = current_tool) -> bool:
	_tool_finish()
	if not tool_available(kind):
		return false
	current_tool = kind
	var job := {"kind": kind}
	match kind:
		"EXTRUDE", "EXTRUDE NORMALS":
			_tool_backup = active_object.data.copy()
			_tool_sel_backup = [sel_verts.duplicate(), sel_edges.duplicate(), sel_faces.duplicate()]
			job.extrude = active_object.data.extrude_begin(sel_verts, sel_edges, sel_faces,
					kind == "EXTRUDE NORMALS")
			job.props = [_prop("AMOUNT", 2.0, "", 2)]
			active_object.rebuild()
			tool_job = job
			select_verts(job.extrude.sel_verts)
		"TRANSLATE":
			_tool_record_starts(job)
			job.props = [_prop("X", 4.0, "", 2), _prop("Y", 4.0, "", 2), _prop("Z", 4.0, "", 2)]
			tool_job = job
		"ROTATE":
			_tool_record_starts(job)
			job.props = [_prop("X", 180.0, "°", 1), _prop("Y", 180.0, "°", 1), _prop("Z", 180.0, "°", 1)]
			tool_job = job
	tool_window.show_tool(kind, tool_job.props)
	_place_tool_window()
	_refresh_lists()
	return true


static func _prop(label: String, span: float, unit: String, decimals: int) -> Dictionary:
	return {"label": label, "value": 0.0, "span": span, "unit": unit, "decimals": decimals}


## Where everything was when a transform started, and the pivot it turns on.
func _tool_record_starts(job: Dictionary) -> void:
	var pivot := Vector3.ZERO
	_move_obj_start.clear()
	_moving_set.clear()
	if mode == Mode.OBJECT:
		var roots := _move_roots()
		for o in roots:
			_move_obj_start[o] = o.global_transform
			pivot += o.global_position
		pivot /= float(maxi(roots.size(), 1))
		for o in objects():
			for r in roots:
				if o == r or o.is_descendant_of(r):
					_moving_set[o] = true
	else:
		_move_vert_start = active_object.data.verts.duplicate()
		for i in sel_verts:
			pivot += active_object.global_transform * _move_vert_start[i]
		pivot /= float(maxi(sel_verts.size(), 1))
		_moving_set[active_object] = true
	_move_pivot = pivot
	job.pivot = pivot


## One property from its slider (snapped); the selection follows.
func tool_set(index: int, v: float) -> void:
	if not tool_live():
		return
	tool_job.props[index].value = _tool_snap(v)
	_tool_apply_props()


## All three of a transform's properties at once, from a drag that has
## already done its own snapping.
func tool_set_vector(v: Vector3) -> void:
	if not tool_live() or tool_job.props.size() != 3:
		return
	tool_job.props[0].value = v.x
	tool_job.props[1].value = v.y
	tool_job.props[2].value = v.z
	_tool_apply_props()


func _tool_snap(v: float) -> float:
	if not (snap_on and snap_targets.INCREMENT):
		return v
	return snappedf(v, ROT_STEP if tool_kind() == "ROTATE" else snap_step)


func _tool_apply_props() -> void:
	var vals := tool_values()
	match tool_kind():
		"EXTRUDE", "EXTRUDE NORMALS":
			active_object.data.extrude_set(tool_job.extrude, vals[0])
			active_object.rebuild()
		"TRANSLATE":
			_apply_translate(Vector3(vals[0], vals[1], vals[2]))
		"ROTATE":
			_apply_rotate(Vector3(vals[0], vals[1], vals[2]))
	tool_window.set_values(vals)


func _apply_translate(delta: Vector3) -> void:
	if mode == Mode.OBJECT:
		for o in _move_obj_start:
			if is_instance_valid(o):
				var start: Transform3D = _move_obj_start[o]
				o.global_transform = Transform3D(start.basis, start.origin + delta)
		return
	var o := active_object
	var local := o.global_transform.basis.inverse() * delta
	for i in sel_verts:
		o.data.verts[i] = _move_vert_start[i] + local
	o.rebuild()


func _apply_rotate(degrees: Vector3) -> void:
	var r := Basis.from_euler(degrees * (PI / 180.0))
	var pivot: Vector3 = tool_job.pivot
	var about := Transform3D(r, pivot - r * pivot)
	if mode == Mode.OBJECT:
		for o in _move_obj_start:
			if is_instance_valid(o):
				o.global_transform = about * _move_obj_start[o]
		return
	var o := active_object
	var xf := o.global_transform
	var inv := xf.affine_inverse()
	for i in sel_verts:
		o.data.verts[i] = inv * (about * (xf * _move_vert_start[i]))
	o.rebuild()


func tool_apply() -> void:
	if not tool_live():
		return
	tool_job = {}
	_tool_backup = null
	_move_obj_start.clear()
	_moving_set.clear()
	snap_hit = {}
	tool_window.visible = false
	_refresh_lists()


func tool_cancel() -> void:
	if not tool_live():
		return
	match tool_kind():
		"EXTRUDE", "EXTRUDE NORMALS":
			active_object.data = _tool_backup
			active_object.rebuild()
			sel_verts = _tool_sel_backup[0]
			sel_edges = _tool_sel_backup[1]
			sel_faces = _tool_sel_backup[2]
		"TRANSLATE", "ROTATE":
			if mode == Mode.OBJECT:
				for o in _move_obj_start:
					if is_instance_valid(o):
						o.global_transform = _move_obj_start[o]
			else:
				active_object.data.verts = _move_vert_start.duplicate()
				active_object.rebuild()
	tool_apply()


## Anything that moves on from the selection applies a live tool first.
func _tool_finish() -> void:
	if tool_live():
		tool_apply()


func _place_tool_window() -> void:
	# Above the status line, which stays readable under it.
	tool_window.position = Vector2(view_rect.position.x + 12.0,
			view_rect.end.y - 30.0 - tool_window.size.y)


## A drag in the view with TOOL as the pointer: start the current tool if
## none is running, then the drag drives it. EXTRUDE's amount and ROTATE's
## angle follow the pointer sideways, scaled to the camera's distance so a
## hand's width means about the same at any zoom; ROTATE turns about the
## world axis the camera looks down most. TRANSLATE is the MOVE drag.
func _tool_drag_begin(origin: Vector2) -> bool:
	if not tool_live() and not tool_start(current_tool):
		return false
	_tool_drag_origin = origin
	_tool_drag_from = tool_values()
	if tool_kind() == "TRANSLATE":
		_move_plane = Plane(camera().global_basis.z, _move_pivot)
		var prior := Vector3(_tool_drag_from[0], _tool_drag_from[1], _tool_drag_from[2])
		_move_start = _plane_point(origin, _move_pivot) - prior
	return true


func _tool_drag_update(pos: Vector2) -> void:
	var dx := pos.x - _tool_drag_origin.x
	match tool_kind():
		"EXTRUDE", "EXTRUDE NORMALS":
			tool_set(0, _tool_drag_from[0] + dx * orbit.distance * TOOL_UNITS_PER_PX)
		"ROTATE":
			var fwd := camera().global_basis.z.abs()
			var axis := 0 if fwd.x >= fwd.y and fwd.x >= fwd.z else (1 if fwd.y >= fwd.z else 2)
			tool_set(axis, _tool_drag_from[axis] + dx * ROT_DEG_PER_PX)
		"TRANSLATE":
			move_update(pos)


# --- commands ------------------------------------------------------------------

func add_primitive(kind: String) -> SceneObject:
	var data: MeshData
	match kind:
		"PLANE": data = MeshData.make_plane()
		"CUBE": data = MeshData.make_cube()
		"CYLINDER": data = MeshData.make_cylinder()
		"SPHERE": data = MeshData.make_sphere()
		_: return null
	_tool_finish()
	var o := SceneObject.create(_unique_name(kind.capitalize()), data)
	world_root.add_child(o)
	mode = Mode.OBJECT
	select_object(o)
	return o


## A group. With objects selected it wraps them: the group sits at their
## centre and they become its children, keeping their place in the world.
## With nothing selected it is an empty group at the origin.
func add_group() -> SceneObject:
	_tool_finish()
	var g := SceneObject.create_group(_unique_name("Group"))
	var roots := _move_roots() if mode == Mode.OBJECT else []
	if roots.is_empty():
		world_root.add_child(g)
	else:
		var centre := Vector3.ZERO
		for o in roots:
			centre += o.global_position
		centre /= float(roots.size())
		# The group goes where the first root was, so a group of children of
		# a group stays inside that group.
		roots[0].get_parent().add_child(g)
		g.global_position = centre
		for o in roots:
			o.reparent(g, true)
	mode = Mode.OBJECT
	select_object(g)
	return g


func _unique_name(base: String) -> String:
	var taken := {}
	for o in objects():
		taken[o.name] = true
	if not taken.has(base):
		return base
	var n := 1
	while taken.has("%s %03d" % [base, n]):
		n += 1
	return "%s %03d" % [base, n]


## Parent `o` under `target` (a SceneObject or the root), keeping its place in
## the world. Dropping an object onto its own descendant is refused.
func reparent_object(o: SceneObject, target: Node) -> bool:
	if target == o or (target is SceneObject and (target as SceneObject).is_descendant_of(o)):
		return false
	if o.get_parent() == target:
		return false
	_tool_finish()
	o.reparent(target, true)
	_refresh_lists()
	return true


func select_object(o: SceneObject, add := false) -> void:
	_tool_finish()
	if not add:
		sel_objects.clear()
	if o != null and not sel_objects.has(o):
		sel_objects.append(o)
	if active_object != o:
		_clear_elems()
	active_object = o
	if mode == Mode.EDIT and (o == null or not o.has_mesh()):
		mode = Mode.OBJECT
	_refresh_lists()


func clear_object_selection() -> void:
	_tool_finish()
	sel_objects.clear()
	active_object = null
	_clear_elems()
	if mode == Mode.EDIT:
		mode = Mode.OBJECT
	_refresh_lists()


func set_mode(m: Mode) -> void:
	if m == Mode.EDIT and (active_object == null or not active_object.has_mesh()):
		return
	_tool_finish()
	mode = m
	hover_kind = -1
	hover_object = null
	_refresh_lists()


func set_elem(e: Elem) -> void:
	elem = e
	hover_kind = -1
	_refresh_lists()


func delete_selected() -> void:
	_tool_finish()
	if mode == Mode.OBJECT:
		var doomed := sel_objects.duplicate()
		clear_object_selection()
		for o in doomed:
			if not is_instance_valid(o):
				continue
			# Children keep their place in the world under the deleted one's parent.
			var p: Node = o.get_parent()
			for c in o.child_objects():
				c.reparent(p, true)
			p.remove_child(o)
			o.queue_free()
	else:
		if active_object == null or sel_verts.is_empty():
			return
		active_object.data.delete_verts(sel_verts)
		active_object.rebuild()
		_clear_elems()
	_refresh_lists()


# --- element selection ---------------------------------------------------------

func _clear_elems() -> void:
	sel_verts.clear()
	sel_edges.clear()
	sel_faces.clear()


## Set the selection from a vertex set and derive edges and faces from it.
func select_verts(vs: Dictionary) -> void:
	_clear_elems()
	sel_verts = vs.duplicate()
	var d := active_object.data
	for e in d.edges.size():
		if sel_verts.has(d.edges[e].x) and sel_verts.has(d.edges[e].y):
			sel_edges[e] = true
	for f in d.faces.size():
		var all := true
		for i in d.faces[f]:
			if not sel_verts.has(i):
				all = false
				break
		if all:
			sel_faces[f] = true
	_refresh_lists()


func select_edges(es: Dictionary) -> void:
	var d := active_object.data
	var vs := {}
	for e in es:
		vs[d.edges[e].x] = true
		vs[d.edges[e].y] = true
	select_verts(vs)
	sel_edges = es.duplicate()
	_refresh_lists()


func select_faces(fs: Dictionary) -> void:
	var d := active_object.data
	var vs := {}
	for f in fs:
		for i in d.faces[f]:
			vs[i] = true
	select_verts(vs)
	sel_faces = fs.duplicate()
	sel_edges.clear()
	for f in fs:
		var idx := d.faces[f]
		for i in idx.size():
			sel_edges[d.edge_index(idx[i], idx[(i + 1) % idx.size()])] = true
	_refresh_lists()


# --- picking -------------------------------------------------------------------

func _ray(pos: Vector2) -> Array:
	var cam := camera()
	return [cam.project_ray_origin(pos), cam.project_ray_normal(pos)]


## The object under `pos`: the nearest mesh the ray hits, or failing that a
## group whose origin marker is within `radius`.
func pick_object(pos: Vector2, radius: float = PEN_RADIUS) -> SceneObject:
	var r := _ray(pos)
	var best: SceneObject = null
	var best_t := INF
	for o in objects():
		if o.is_group:
			continue
		var inv := o.global_transform.affine_inverse()
		var lo: Vector3 = inv * r[0]
		var ld: Vector3 = (inv.basis * r[1]).normalized()
		var hit := o.data.ray_hit(lo, ld)
		if hit.is_empty():
			continue
		var wp: Vector3 = o.global_transform * hit.point
		var t: float = (wp - r[0]).length()
		if t < best_t:
			best_t = t
			best = o
	if best != null:
		return best
	var cam := camera()
	var best_d := radius
	for o in objects():
		if not o.is_group or cam.is_position_behind(o.global_position):
			continue
		var d := cam.unproject_position(o.global_position).distance_to(pos)
		if d < best_d:
			best_d = d
			best = o
	return best


func pick_vert(pos: Vector2, radius: float) -> int:
	var o := active_object
	var cam := camera()
	var best := -1
	var best_d := radius
	for i in o.data.verts.size():
		var w := o.global_transform * o.data.verts[i]
		if cam.is_position_behind(w):
			continue
		var d := cam.unproject_position(w).distance_to(pos)
		if d < best_d:
			best_d = d
			best = i
	return best


func pick_edge(pos: Vector2, radius: float) -> int:
	var o := active_object
	var cam := camera()
	var best := -1
	var best_d := radius
	for e in o.data.edges.size():
		var a := o.global_transform * o.data.verts[o.data.edges[e].x]
		var b := o.global_transform * o.data.verts[o.data.edges[e].y]
		if cam.is_position_behind(a) or cam.is_position_behind(b):
			continue
		var p := Geometry2D.get_closest_point_to_segment(pos, cam.unproject_position(a),
				cam.unproject_position(b))
		var d := p.distance_to(pos)
		if d < best_d:
			best_d = d
			best = e
	return best


func pick_face(pos: Vector2) -> int:
	var o := active_object
	var r := _ray(pos)
	var inv := o.global_transform.affine_inverse()
	var hit := o.data.ray_hit(inv * r[0], (inv.basis * r[1]).normalized())
	return hit.face if not hit.is_empty() else -1


func pick_elem(pos: Vector2, radius: float) -> int:
	match elem:
		Elem.VERT: return pick_vert(pos, radius)
		Elem.EDGE: return pick_edge(pos, radius)
		_: return pick_face(pos)


## Select whatever is at `pos`; nothing there clears the selection.
func tap(pos: Vector2, radius: float) -> void:
	if not view_rect.has_point(pos):
		return
	if mode == Mode.OBJECT:
		var o := pick_object(pos, radius)
		if o == null:
			clear_object_selection()
		else:
			select_object(o)
		return
	_tool_finish()
	var i := pick_elem(pos, radius)
	match elem:
		Elem.VERT: select_verts({i: true} if i >= 0 else {})
		Elem.EDGE: select_edges({i: true} if i >= 0 else {})
		_: select_faces({i: true} if i >= 0 else {})


func box_rect() -> Rect2:
	return Rect2(_box_from, _box_to - _box_from).abs()


## Select everything inside the box: objects by origin, verts by position,
## edges and faces when every vertex of theirs is inside.
func box_select(rect: Rect2) -> void:
	var cam := camera()
	if mode == Mode.OBJECT:
		sel_objects.clear()
		for o in objects():
			var w := o.global_position
			if not cam.is_position_behind(w) and rect.has_point(cam.unproject_position(w)):
				sel_objects.append(o)
		if sel_objects.is_empty():
			clear_object_selection()
			return
		if not sel_objects.has(active_object):
			active_object = sel_objects[0]
		_refresh_lists()
		return
	_tool_finish()
	var d := active_object.data
	var inside := {}
	for i in d.verts.size():
		var w := active_object.global_transform * d.verts[i]
		if not cam.is_position_behind(w) and rect.has_point(cam.unproject_position(w)):
			inside[i] = true
	match elem:
		Elem.VERT:
			select_verts(inside)
		Elem.EDGE:
			var es := {}
			for e in d.edges.size():
				if inside.has(d.edges[e].x) and inside.has(d.edges[e].y):
					es[e] = true
			select_edges(es)
		_:
			var fs := {}
			for f in d.faces.size():
				var all := true
				for i in d.faces[f]:
					if not inside.has(i):
						all = false
						break
				if all:
					fs[f] = true
			select_faces(fs)


func update_hover(pos: Vector2, radius: float) -> void:
	hover_object = null
	hover_kind = -1
	hover_index = -1
	if not view_rect.has_point(pos):
		return
	if mode == Mode.OBJECT:
		hover_object = pick_object(pos, radius)
	elif active_object != null:
		hover_index = pick_elem(pos, radius)
		hover_kind = elem if hover_index >= 0 else -1


# --- moving --------------------------------------------------------------------
# The MOVE drag is the TRANSLATE tool with a pointer on it: the drag's
# position on a plane through the pivot, facing the camera, is where the
# pivot goes, snapped to whatever is under the pointer or to the grid.

func has_moveable() -> bool:
	if mode == Mode.OBJECT:
		return not sel_objects.is_empty()
	return active_object != null and not sel_verts.is_empty()


## Objects to move: the selected ones whose ancestors are not also selected.
func _move_roots() -> Array[SceneObject]:
	var out: Array[SceneObject] = []
	for o in sel_objects:
		var covered := false
		for p in sel_objects:
			if p != o and o.is_descendant_of(p):
				covered = true
				break
		if not covered:
			out.append(o)
	return out


func move_begin(pos: Vector2) -> void:
	if not tool_start("TRANSLATE"):
		return
	_move_plane = Plane(camera().global_basis.z, _move_pivot)
	_move_start = _plane_point(pos, _move_pivot)
	snap_hit = {}


func _plane_point(pos: Vector2, fallback: Vector3) -> Vector3:
	var r := _ray(pos)
	var p = _move_plane.intersects_ray(r[0], r[1])
	return p if p != null else fallback


## Where the pivot goes for a pointer at `pos`, with snapping applied: a
## vertex, edge or face under the pointer wins; otherwise the free position,
## held to the grid when INCREMENT is on.
func move_target(pos: Vector2) -> Vector3:
	snap_hit = {}
	if snap_on and (snap_targets.VERTEX or snap_targets.EDGE or snap_targets.FACE):
		var hit := snap_target(pos)
		if not hit.is_empty():
			snap_hit = hit
			return hit.point
	var free: Vector3 = _move_pivot + (_plane_point(pos, _move_start) - _move_start)
	if snap_on and snap_targets.INCREMENT:
		if snap_absolute:
			return free.snapped(Vector3.ONE * snap_step)
		return _move_pivot + (free - _move_pivot).snapped(Vector3.ONE * snap_step)
	return free


func move_update(pos: Vector2) -> void:
	if tool_kind() != "TRANSLATE":
		return
	tool_set_vector(move_target(pos) - _move_pivot)


## The pointer let go; the job stays live, with its numbers up, until
## something moves on.
func move_end() -> void:
	snap_hit = {}


## The nearest snappable thing to `pos` within SNAP_RADIUS, on anything that
## is not being moved: {point, kind} or {}. Vertices beat edges beat faces.
func snap_target(pos: Vector2) -> Dictionary:
	var cam := camera()
	var r := _ray(pos)
	var best := {}
	var best_rank := 9
	var best_d := INF
	for o in objects():
		if o.is_group:
			continue
		var own: bool = _moving_set.has(o)
		if own and not (mode == Mode.EDIT and snap_self and o == active_object):
			continue
		var xf := o.global_transform
		var d := o.data
		if snap_targets.VERTEX:
			for i in d.verts.size():
				if own and sel_verts.has(i):
					continue
				var w := xf * d.verts[i]
				if cam.is_position_behind(w):
					continue
				var dist := cam.unproject_position(w).distance_to(pos)
				if dist <= SNAP_RADIUS and (best_rank > 0 or dist < best_d):
					best = {"point": w, "kind": "VERTEX"}
					best_rank = 0
					best_d = dist
		if snap_targets.EDGE and best_rank > 0:
			for e in d.edges:
				if own and (sel_verts.has(e.x) or sel_verts.has(e.y)):
					continue
				var a := xf * d.verts[e.x]
				var b := xf * d.verts[e.y]
				if cam.is_position_behind(a) or cam.is_position_behind(b):
					continue
				var sa := cam.unproject_position(a)
				var sb := cam.unproject_position(b)
				var p := Geometry2D.get_closest_point_to_segment(pos, sa, sb)
				var dist := p.distance_to(pos)
				if dist <= SNAP_RADIUS and (best_rank > 1 or dist < best_d):
					var t := 0.0 if sa.is_equal_approx(sb) else (p - sa).length() / (sb - sa).length()
					best = {"point": a.lerp(b, t), "kind": "EDGE"}
					best_rank = 1
					best_d = dist
		if snap_targets.FACE and best_rank > 1:
			var inv := xf.affine_inverse()
			var hit := d.ray_hit(inv * r[0], (inv.basis * r[1]).normalized())
			if not hit.is_empty() and not (own and _face_moving(d, hit.face)):
				var w: Vector3 = xf * hit.point
				var dist: float = (w - r[0]).length()
				if best_rank > 2 or dist < best_d:
					best = {"point": w, "kind": "FACE"}
					best_rank = 2
					best_d = dist
	return best


func _face_moving(d: MeshData, f: int) -> bool:
	for i in d.faces[f]:
		if sel_verts.has(i):
			return true
	return false


# --- input ---------------------------------------------------------------------
# A gesture that began in the view keeps its pointer until it lifts, even when
# it crosses a panel: those continuations are taken in `_input`, ahead of the
# GUI. A press anywhere outside an open popover closes it and goes no further.
# Everything else (presses, hover, the wheel) is whatever the panels did not
# take, in `_unhandled_input`.

func _input(event: InputEvent) -> void:
	var touch := event as InputEventScreenTouch
	var drag := event as InputEventScreenDrag
	var click := event as InputEventMouseButton
	var motion := event as InputEventMouseMotion
	var mine := false
	if popover.visible:
		var press_pos: Variant = null
		if touch != null and touch.pressed:
			press_pos = touch.position
		elif click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
			press_pos = click.position
		if press_pos != null and not popover.get_rect().has_point(press_pos) \
				and not toggle_list.get_rect().has_point(press_pos) \
				and not add_bar.get_rect().has_point(press_pos):
			close_popover()
			get_viewport().set_input_as_handled()
			return
	if touch != null and not touch.pressed and _touches.has(touch.index):
		_touch(touch)
		mine = true
	elif drag != null and _touches.has(drag.index):
		_touch_drag(drag)
		mine = true
	elif click != null and not click.pressed and (
			(click.button_index == MOUSE_BUTTON_LEFT and _pen_down)
			or (click.button_index == MOUSE_BUTTON_MIDDLE and _middle_down)):
		_pen_button(click)
		mine = true
	elif motion != null and (_pen_down or _middle_down):
		_pen_motion(motion)
		mine = true
	if mine:
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	var touch := event as InputEventScreenTouch
	var drag := event as InputEventScreenDrag
	var click := event as InputEventMouseButton
	var motion := event as InputEventMouseMotion
	if touch != null:
		_touch(touch)
	elif drag != null:
		_touch_drag(drag)
	elif click != null:
		_pen_button(click)
	elif motion != null:
		_pen_motion(motion)


func _touch(t: InputEventScreenTouch) -> void:
	if t.pressed:
		if not view_rect.has_point(t.position) and _touches.is_empty():
			return
		_touches[t.index] = {"pos": t.position, "start": t.position, "time": 0.0, "cancelled": false}
		if _touches.size() == 2:
			for k in _touches:
				_touches[k].cancelled = true
			if _finger_moving:
				move_end()
				_finger_moving = false
			_finger_tooling = false
			_pinch_reset()
		elif _touches.size() > 2:
			_touches[t.index].cancelled = true
		return
	if not _touches.has(t.index):
		return
	var info: Dictionary = _touches[t.index]
	_touches.erase(t.index)
	if _finger_tooling and _touches.is_empty():
		_finger_tooling = false
		return
	if _finger_moving and _touches.is_empty():
		move_end()
		_finger_moving = false
		return
	if not info.cancelled and info.pos.distance_to(info.start) <= TAP_SLOP \
			and info.time <= TAP_TIME:
		tap(t.position, FINGER_RADIUS)
	if _touches.size() == 1:
		# The finger left behind must lift before it counts for anything again.
		for k in _touches:
			_touches[k].cancelled = true


func _touch_drag(d: InputEventScreenDrag) -> void:
	if not _touches.has(d.index):
		return
	var info: Dictionary = _touches[d.index]
	var prev: Vector2 = info.pos
	info.pos = d.position
	if _touches.size() == 1:
		if info.cancelled:
			return
		var moved: bool = info.pos.distance_to(info.start) > TAP_SLOP
		if _finger_moving:
			move_update(d.position)
		elif _finger_tooling:
			_tool_drag_update(d.position)
		elif pointer == Pointer.MOVE and has_moveable():
			if moved:
				_finger_moving = true
				move_begin(info.start)
				move_update(d.position)
		elif pointer == Pointer.TOOL:
			if moved and _tool_drag_begin(info.start):
				_finger_tooling = true
				_tool_drag_update(d.position)
		else:
			_orbit(d.position - prev)
	elif _touches.size() == 2:
		var keys := _touches.keys()
		var a: Vector2 = _touches[keys[0]].pos
		var b: Vector2 = _touches[keys[1]].pos
		var center := (a + b) * 0.5
		var dist := a.distance_to(b)
		if _pinch_dist > 0.0:
			orbit.pan(center - _pinch_center)
			orbit.zoom(dist / _pinch_dist)
		_pinch_center = center
		_pinch_dist = dist


func _pinch_reset() -> void:
	var keys := _touches.keys()
	if keys.size() < 2:
		_pinch_dist = 0.0
		return
	var a: Vector2 = _touches[keys[0]].pos
	var b: Vector2 = _touches[keys[1]].pos
	_pinch_center = (a + b) * 0.5
	_pinch_dist = a.distance_to(b)


func _process(delta: float) -> void:
	for k in _touches:
		_touches[k].time += delta
	if tool_live():
		_refresh_props()


func _pen_button(c: InputEventMouseButton) -> void:
	match c.button_index:
		MOUSE_BUTTON_LEFT:
			if c.pressed:
				if not view_rect.has_point(c.position):
					return
				_pen_down = true
				_pen_start = c.position
				_pen_dragging = false
				_pen_moving = false
				_pen_tooling = false
			elif _pen_down:
				_pen_down = false
				if _pen_moving:
					move_end()
				elif _pen_tooling:
					_pen_tooling = false
				elif box_active:
					box_active = false
					box_select(box_rect())
				elif not _pen_dragging:
					tap(c.position, PEN_RADIUS)
				_pen_moving = false
		MOUSE_BUTTON_MIDDLE:
			_middle_down = c.pressed and view_rect.has_point(c.position)
		MOUSE_BUTTON_WHEEL_UP:
			if view_rect.has_point(c.position):
				orbit.zoom(1.1)
		MOUSE_BUTTON_WHEEL_DOWN:
			if view_rect.has_point(c.position):
				orbit.zoom(1.0 / 1.1)


func _pen_motion(m: InputEventMouseMotion) -> void:
	pen_hover_valid = view_rect.has_point(m.position)
	pen_hover_pos = m.position
	if _middle_down:
		_orbit(m.relative)
		return
	if not _pen_down:
		update_hover(m.position, PEN_RADIUS)
		return
	if not _pen_dragging:
		if m.position.distance_to(_pen_start) <= TAP_SLOP:
			return
		_pen_dragging = true
		if pointer == Pointer.MOVE and has_moveable():
			_pen_moving = true
			move_begin(_pen_start)
		elif pointer == Pointer.TOOL:
			_pen_tooling = _tool_drag_begin(_pen_start)
		else:
			box_active = true
			_box_from = _pen_start
	if _pen_moving:
		move_update(m.position)
	elif _pen_tooling:
		_tool_drag_update(m.position)
	elif box_active:
		_box_to = m.position
