#!/usr/bin/env bash
# Build the Android APK.
#
#   ./tools/TOOL_build_apk.sh            -> build/vagrant3d_debug.apk
#   ./tools/TOOL_build_apk.sh release    -> build/vagrant3d_release.apk (needs a keystore in Editor Settings)
#
# export_presets.cfg is gitignored (it is where Godot writes keystore paths),
# so the preset is written here from a heredoc every run. Debug builds sign
# with the editor's own debug keystore. Needs: Godot 4.7, its Android export
# templates, and an Android SDK with adb and apksigner (Editor Settings >
# Export > Android > Android SDK Path).
#
# Install: adb install -r build/vagrant3d_debug.apk
set -euo pipefail
cd "$(dirname "$0")/.."

MODE="${1:-debug}"
GODOT="${GODOT:-godot}"
OUT="build/vagrant3d_${MODE}.apk"
mkdir -p build

cat > export_presets.cfg <<'CFGEOF'
[preset.0]

name="Android"
platform="Android"
runnable=true
advanced_options=false
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter=""
exclude_filter=""
export_path="build/vagrant3d.apk"
patches=PackedStringArray()
encryption_include_filters=""
encryption_exclude_filters=""
seed=0
encrypt_pck=false
encrypt_directory=false
script_export_mode=2

[preset.0.options]

custom_template/debug=""
custom_template/release=""
gradle_build/use_gradle_build=false
gradle_build/export_format=0
architectures/armeabi-v7a=false
architectures/arm64-v8a=true
architectures/x86=false
architectures/x86_64=false
version/code=1
version/name="0.1"
package/unique_name="zero.verdict.vagrant3d"
package/name="Vagrant 3D"
package/signed=true
package/app_category=7
package/show_in_app_library=true
graphics/opengl_debug=false
xr_features/xr_mode=0
screen/immersive_mode=true
screen/support_small=true
screen/support_normal=true
screen/support_large=true
screen/support_xlarge=true
user_data_backup/allow=false
command_line/extra_args=""
apk_expansion/enable=false
permissions/vibrate=false
permissions/custom_permissions=PackedStringArray()
CFGEOF

FLAG="--export-debug"
[ "$MODE" = "release" ] && FLAG="--export-release"

"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --path . "$FLAG" "Android" "$OUT"
ls -la "$OUT"
