# The editor

Objects and groups in a hierarchy, four primitives, OBJECT and EDIT mode
with VERT / EDGE / FACE, move, rotate, scale, extrude, inset, bevel, loop
cut, trim (Nomad Sculpt's, orthographic), duplicate, merge and fill,
modifiers (subdivision, mirror, array),
smooth shading, transform gizmos, undo and redo, saving and OBJ export,
snapping, matcaps. Android first,
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
| `scripts/SCRIPT_transform_gizmo.gd` | The move, rotate and scale gizmos: geometry, picking, drawing |
| `scripts/SCRIPT_text_prompt.gd` | The one-line text question: a field, OK, CANCEL |
| `scripts/SCRIPT_scene_file.gd` | Scenes as JSON in user://scenes/, and OBJ export |
| `scripts/SCRIPT_tool_window.gd` | The tool window: a slider and a number per property, APPLY, CANCEL |
| `scripts/SCRIPT_viewport_overlay.gd` | Wires, selection, hover, the box, the snap mark, group axes, the status line |
| `scripts/SCRIPT_chamfer_panel.gd` | The cut-corner frame |
| `scripts/SCRIPT_ui_tokens.gd` | The greys and sizes, by name |
| `scripts/autoload/AUTOLOAD_fonts.gd` | `Fonts.ui()` words, `Fonts.clock()` numbers |
| `vendor/matcaps/` | The matcaps; `SOURCES.txt` says where from |
| `tests/TEST_*.gd`, `tests/RENDER_editor.gd` | Headless tests and the screenshot harness, below |
| `tools/TOOL_build_apk.sh` | Writes the export preset and builds the APK |

## The screen

Blender's shape. The header across the top: FILE, OBJECT / EDIT, VERT /
EDGE / FACE, SELECT (all, none, invert, linked), ADD (the primitives and GROUP), and
at the right end UNDO and REDO, then SNAP and SHADING. FILE, SELECT, ADD,
SNAP and SHADING open popovers under it. The tool column down the left,
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

The properties panel under it shows the active object: its name (tap it to
rename), location, rotation and scale, SHADE SMOOTH, the modifier stack, and
the mesh's counts, or a group's child count. Location,
rotation and scale are fields, the way Blender's are: drag one sideways to
change it, a hundredth of a unit, half a degree or half a percent per
pixel. Each drag is one undo step.

**Renaming.** Double-tap the active object's row in the hierarchy, tap its
name in the properties, or press F2: a field comes up with the on-screen
keyboard. A name in use gets the next free number; characters a name cannot
hold (`. : @ / " %`) are dropped.

## Modifiers

As in Blender, a mesh object keeps the cage you edit and shows the result
of its modifiers run on it in order. ADD MODIFIER in the properties offers:

| Modifier | Settings | Does |
|---|---|---|
| SUBDIVISION | LEVELS 0 to 3 | Catmull-Clark. Every face becomes a quad per corner, each level; a border keeps its line |
| MIRROR | AXIS X, Y, Z | Mirrors across the object's own planes through its origin; vertices on a plane are shared, so the halves join |
| ARRAY | COUNT, AXIS, OFFSET | Copies in a row along an axis, each the mesh's own width times OFFSET from the last (1 is touching) |

Tap a modifier's name to hide or show it. Its settings hang under it: drag
LEVELS, COUNT or OFFSET sideways, or tap LEVELS and COUNT to step them; tap
an AXIS. APPLY runs that modifier into the cage and takes it off the stack;
REMOVE takes it off. Every change is an undo step, and files keep the
stack. Edit mode edits the cage, drawn as the wire over the result; EXPORT
OBJ writes the result.

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
then the one-tap actions: DUPLICATE, in EDIT also MERGE and FILL, and
DELETE. In OBJECT mode the tools are ROTATE, SCALE and TRIM; in EDIT mode
ROTATE, SCALE, EXTRUDE, EXTRUDE NORMALS, INSET, BEVEL, LOOP CUT and TRIM. A tool or action
that cannot run on what is selected is dimmed. Select something, tap a tool: it runs at once at zero
and the **tool window** comes up in the bottom-left of the view: the tool's
name, one row per property with a slider to pull and the value as a number,
then APPLY and CANCEL. Every tool uses the same window; it only differs in
which rows it shows. A drag in the view while a tool is the pointer drives
it too, and starts it again if none is running. With snapping on, moves and extrudes go in STEP
increments, inset and bevel in fifths of a STEP, angles in 5 degree steps
and scale in tenths. Anything that moves on, such as another
selection, a mode change or another tool, applies the live one first.

| Tool | Rows | Does |
|---|---|---|
| TRANSLATE | X Y Z | Moves the selection by a world offset. **A MOVE drag is this tool**: the window comes up with the live offset and stays for fine adjustment |
| ROTATE | X Y Z, degrees | Turns the selection about its centre. A drag in the view turns about the world axis the camera looks down most |
| SCALE | X Y Z, factors | Scales the selection about its centre. A drag in the view scales evenly, by how far the pointer is from the centre against where it started |
| EXTRUDE | AMOUNT | Faces: the region rises along its normal, its rim grows walls, the old faces go. Edges: each grows a quad. Vertices: each grows a wire edge |
| EXTRUDE NORMALS | AMOUNT | The same, but every vertex moves along its own normal |
| INSET | THICKNESS, DEPTH | Faces, as one region: a ring of faces grows inward round it, THICKNESS wide square to each edge; DEPTH lifts or sinks the inner region |
| LOOP CUT | FACTOR | From a selected edge, one cut across the ring of quads it starts, until the ring closes or meets a non-quad or the border. FACTOR slides the cut from one side to the other |
| BEVEL | AMOUNT | Edges with a face on each side, one segment: each becomes a strip, its new edges AMOUNT from the old one in each face; a corner where three bevelled edges meet becomes a triangle. The amount stops before new edges would cross |

`scripts/SCRIPT_tool_window.gd` is the window; the jobs are in
`scripts/SCRIPT_editor.gd` under "tools", and the extrude operations are
`MeshData.extrude_begin` / `extrude_set` in `scripts/SCRIPT_mesh_data.gd`.

MERGE pulls the selected vertices into one at their centre; faces left with
two corners go. FILL is Blender's F: two vertices get an edge; edges round a
hole close it with a face; otherwise the vertices make a face in order round
their centre. A new face turns the way the faces beside it do.

DUPLICATE copies the selection in place (objects with their children, or
in EDIT the selected faces, edges and vertices) and leaves MOVE as the
pointer, so the next drag moves the copy.

## Trim

Nomad Sculpt's trim, orthographic only. Pick TRIM and the view turns
orthographic if it was not (the flash line says so); a bar at the top of
the view picks LASSO or BOX, and CUT INSIDE or KEEP INSIDE. Draw with one
finger or the pen and lift: everything inside the shape, straight through
the mesh along the view, is cut away from the selected objects (the active
one in EDIT), or with KEEP INSIDE everything outside. The cut is filled, so
a closed mesh stays closed: a notch off a side gets a flat wall, a shape
inside the outline bores a tunnel through with walls all round. An open
mesh (a plane) gets a hole and stays open. A second finger cancels the
drawing; a trim drawn in perspective is refused. One undo step per trim.

How: each face is clipped against the shape in view space, faces seen
edge-on are cut by the shape's walls where they cross them, and cut points
are welded so neighbours stay joined. The open loops left on the shape's
walls are unrolled (how far round the shape, how deep), cut at every corner
of the shape so each piece lies flat on one wall, triangulated, and lifted
back (`MeshData.trim`). Faces that are not convex, which trim makes, are
ear-clipped wherever triangles are needed.

## Gizmos

While MOVE is the pointer, arrows sit at the selection's centre; while
ROTATE or SCALE is the tool, rings or square-ended handles do. They keep one
size on screen at any zoom, and are told apart by their letters. Drag an
arrow to move along its world axis (snapped to the grid with snapping on),
a ring to turn about its axis, a handle to scale along it; the centre
square moves freely, or under SCALE scales evenly. A press on a handle wins
over picking. The drag runs the matching tool, so its numbers are in the
tool window and it stays live: drag X, then Y, and both are one move.

## Files

FILE has NEW, SAVE, SAVE AS... (a name of your own; the next free SCENE 001
is offered), the saved scenes to OPEN, and EXPORT OBJ. Scenes save to the
app's own storage; the status
line leads with the name, and a star while there are unsaved changes. NEW
and OPEN are undo steps, so the scene before is an undo away. EXPORT OBJ
writes every mesh in world space to Documents/Vagrant3D/ (desktop Blender
reads it), or to the app's storage where Documents cannot be written; the
flash line says which.

## Undo

Every change is a step: adding, grouping, parenting, deleting, a tool
applied, a property dragged. UNDO and REDO are in the header; a
**two-finger tap** in the view is undo and a **three-finger tap** is redo;
Ctrl+Z and Ctrl+Shift+Z work on a keyboard. With a tool live, undo cancels
it. Undo puts the selection and mode back as they were going into the step,
so undoing an extrude leaves you in EDIT with the face you had picked. The
history keeps 64 steps. Changing mode, selection or view is not a step.

## Keys

For a keyboard on the tablet or at a desk, Blender's: Tab, 1 2 3, G R S,
E, I, Ctrl+B, Ctrl+R, Shift+D, M, F, L, X or Delete, A, Alt+A, Ctrl+I,
Shift+A, F2, Enter, Escape, Ctrl+Z, Ctrl+Shift+Z, Ctrl+S, Ctrl+Shift+S,
Ctrl+N, Ctrl+O, numpad 1 3 7 (with Ctrl for the opposite) and numpad 5.

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
