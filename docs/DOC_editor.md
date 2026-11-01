# The editor, chunk one

Objects in a hierarchy, four primitives, OBJECT and EDIT mode with VERT /
EDGE / FACE, SELECT and MOVE. Android first, S Pen aware. The UI speaks the
house style: `DOC_ui_style.md` is the why, `DOC_ui_design_tokens.md` the
numbers.

## What's where

| Path | Role |
|---|---|
| `scenes/SCENE_editor.tscn` | The one scene |
| `scripts/SCRIPT_editor.gd` | Modes, selection, picking, moving, gestures, the layout |
| `scripts/SCRIPT_mesh_data.gd` | `MeshData`: verts, edges, faces; the primitives; the ArrayMesh |
| `scripts/SCRIPT_scene_object.gd` | `SceneObject`: a Node3D with a MeshData. The hierarchy is the node tree |
| `scripts/SCRIPT_orbit_camera.gd` | Orbit, pan, zoom |
| `scripts/SCRIPT_row_list.gd` | Rows with one cursor box; tap, hold-or-drag to lift a row |
| `scripts/SCRIPT_viewport_overlay.gd` | Wires, selection, hover, the box, the status line |
| `scripts/SCRIPT_chamfer_panel.gd` | The cut-corner frame |
| `scripts/SCRIPT_ui_tokens.gd` | The greys and sizes, by name |
| `scripts/autoload/AUTOLOAD_fonts.gd` | `Fonts.ui()` words, `Fonts.clock()` numbers |
| `tests/TEST_*.gd` | Headless, below |
| `tools/TOOL_build_apk.sh` | Writes the export preset and builds the APK |

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

TOOL is on the bar and disabled: nothing is bound to it yet.

## Hierarchy

Tap a row to select the object. Press and hold, or drag sideways, to lift a
row; drop it on another row to parent under it, keeping its place in the
world; drop it below the rows to send it back to the root. An object cannot
be dropped on its own descendant.

## Tests

```
godot --headless --path . --import
godot --headless --path . --script res://tests/TEST_ui_tokens.gd
godot --headless --path . --script res://tests/TEST_mesh_data.gd
godot --headless --path . --script res://tests/TEST_editor.gd
```
