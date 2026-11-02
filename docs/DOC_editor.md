# The editor

Objects and groups in a hierarchy, four primitives, OBJECT and EDIT mode
with VERT / EDGE / FACE, SELECT and MOVE, snapping, matcaps. Android first,
S Pen aware, laid out for a tablet or a foldable. The UI speaks the house
style: `DOC_ui_style.md` is the why, `DOC_ui_design_tokens.md` the numbers.
This project's design space is 1600x900, the sheet's 1280x720 at 0.8.

## What's where

| Path | Role |
|---|---|
| `scenes/SCENE_editor.tscn` | The one scene |
| `scripts/SCRIPT_editor.gd` | Modes, selection, picking, moving, snapping, gestures, popovers, the layout |
| `scripts/SCRIPT_mesh_data.gd` | `MeshData`: verts, edges, faces; the primitives; the ArrayMesh |
| `scripts/SCRIPT_scene_object.gd` | `SceneObject`: a Node3D with a MeshData, or a group. The hierarchy is the node tree. The shared matcap material |
| `scripts/SCRIPT_orbit_camera.gd` | Orbit, pan, zoom |
| `scripts/SCRIPT_row_list.gd` | Rows with one cursor box: icons, tree lines, values, on/off marks; tap, hold-or-drag to lift a row |
| `scripts/SCRIPT_icons.gd` | Blender's icon vocabulary redrawn as mono line glyphs |
| `scripts/SCRIPT_matcaps.gd`, `scripts/SCRIPT_matcap_grid.gd` | The sixteen matcaps and the gallery |
| `shaders/SHADER_matcap.gdshader` | The matcap shader |
| `scripts/SCRIPT_tool_window.gd` | The tool window: a slider and a number per property, APPLY, CANCEL |
| `scripts/SCRIPT_viewport_overlay.gd` | Wires, selection, hover, the box, the snap mark, group axes, the status line |
| `scripts/SCRIPT_chamfer_panel.gd` | The cut-corner frame |
| `scripts/SCRIPT_ui_tokens.gd` | The greys and sizes, by name |
| `scripts/autoload/AUTOLOAD_fonts.gd` | `Fonts.ui()` words, `Fonts.clock()` numbers |
| `vendor/matcaps/` | The matcaps; `SOURCES.txt` says where from |
| `tests/TEST_*.gd`, `tests/RENDER_editor.gd` | Headless tests and the screenshot harness, below |
| `tools/TOOL_build_apk.sh` | Writes the export preset and builds the APK |

## The screen

Blender's shape. The header across the top: OBJECT / EDIT, VERT / EDGE /
FACE, ADD (a menu of the primitives and GROUP), and at the right end SNAP
and SHADING, which open popovers under it. The tool column down the left,
icons only, changing with the mode. The hierarchy over the properties down
the right, each half the height. The view is what is left, with the axes
ball in its top-right corner and ORTHO under it.

## The view

Perspective by default. ORTHO under the axes ball toggles orthographic.
The ball shows the three axes as the camera sees them, positive ends
lettered and filled, negative ends hollow: tap an end to look from there
(+X is RIGHT, -X LEFT, +Y TOP, -Y BOTTOM, +Z FRONT, -Z BACK), tap the same
end again to flip to its opposite, drag the ball to orbit. An axis view is
orthographic by itself and the next orbit brings perspective back, the way
Blender's auto perspective does. The status line reads the view first:
FRONT ORTHO, USER PERSP.

## Pointers

Fingers and the pen are told apart by event class, and nothing is emulated
between them (`project.godot` `[input_devices]`).

| | Finger | S Pen (and a desktop mouse) |
|---|---|---|
| Tap | select what is under it, or clear | the same, with a tighter radius |
| Drag in SELECT | orbit | box select |
| Drag in MOVE | move the selection in the view plane | the same |
| Two fingers | pan; pinch zooms | — |
| Hover | — | crosshair; the element under it brightens |
| Middle drag / wheel | — | orbit / zoom, for a desk |

Tools are the column on the left; see Tools.

## Hierarchy and properties

Tap a row to select the object. Press and hold, or drag sideways, to lift a
row; drop it on another row to parent under it, keeping its place in the
world; drop it below the rows to send it back to the root. An object cannot
be dropped on its own descendant. Children hang off a `|_` line under their
parent, and a parent with more children below carries its line past them.
When the rows outgrow the panel, a drag up or down them scrolls, as does
the bar at the right edge or a wheel.

The properties panel under it shows the active object: its name and type,
location, rotation, and mesh counts or child count. Read-only for now; it
will grow into Blender's properties editor.

**Groups** are objects with no mesh. ADD > GROUP with objects selected wraps
them: the group sits at their centre and they become its children. With
nothing selected it is an empty group at the origin. A group shows as plain
axes in the view and can be picked by them; it cannot be edited.

## Snapping

On by default. SNAP on the bar opens the menu:

| Row | Does |
|---|---|
| SNAP | The whole thing on or off; the bar's SNAP is lit while on |
| INCREMENT / VERTEX / EDGE / FACE | What to snap to; any mix. A vertex under the pointer beats an edge beats a face; none of them within reach falls back to the increment |
| STEP | The increment: 1 / 0.5 / 0.25 / 0.1, tapped round |
| ABSOLUTE GRID | On: positions land on the grid. Off: moves go in steps from where they started |
| SNAP TO SELF | In EDIT, the object's own unselected vertices, edges and faces count as targets |

While a move is held to a target, a square mark sits on it in the view.

## Tools and the tool window

The tool column on the left is SELECT, MOVE, then the tools the mode has,
then DELETE. In OBJECT mode: ROTATE. In EDIT mode: ROTATE, EXTRUDE,
EXTRUDE NORMALS, BEVEL and INSET. A tool that cannot run on what is
selected is dimmed. Select something, tap a tool: it runs at once at zero
and the **tool window** comes up in the bottom-left of the view: the tool's
name, one row per property with a slider to pull and the value as a number,
then APPLY and CANCEL. Every tool uses the same window; it only differs in
which rows it shows. A drag in the view while a tool is the pointer drives
it too, and starts it again if none is running. With snapping on, lengths go in STEP increments and
angles in 5 degree steps. Anything that moves on, such as another
selection, a mode change or another tool, applies the live one first.

| Tool | Rows | Does |
|---|---|---|
| TRANSLATE | X Y Z | Moves the selection by a world offset. **A MOVE drag is this tool**: the window comes up with the live offset and stays for fine adjustment |
| ROTATE | X Y Z, degrees | Turns the selection about its centre. A drag in the view turns about the world axis the camera looks down most |
| EXTRUDE | AMOUNT | Faces: the region rises along its normal, its rim grows walls, the old faces go. Edges: each grows a quad. Vertices: each grows a wire edge |
| EXTRUDE NORMALS | AMOUNT | The same, but every vertex moves along its own normal |
| BEVEL, INSET | | Listed, not built yet |

`scripts/SCRIPT_tool_window.gd` is the window; the jobs are in
`scripts/SCRIPT_editor.gd` under "tools", and the extrude operations are
`MeshData.extrude_begin` / `extrude_set` in `scripts/SCRIPT_mesh_data.gd`.

## Shading

SHADING opens the gallery: sixteen matcaps, the clay grey first and the
default. One tap changes every object; there is one material.

## Tests

```
godot --headless --path . --import
godot --headless --path . --script res://tests/TEST_ui_tokens.gd
godot --headless --path . --script res://tests/TEST_mesh_data.gd
godot --headless --path . --script res://tests/TEST_editor.gd
```
