extends Node
## Autoload "Fonts". Pick a font by ROLE, never by filename.
##
##   ui(weight)  Zalando Sans Condensed   words: rows, labels, headings
##   clock()     digital-7 mono           numbers: counts, readouts
##
## Lazy-loaded and cached. Headless (tests) gets null where a font is not
## imported; draw_string treats a null font as the default, which is fine.

const _CLOCK := "res://vendor/fonts/digital-7 (mono).ttf"
const _UI := {
	"medium": "res://vendor/fonts/ZalandoSans/ZalandoSans-CondensedMedium.ttf",
	"bold": "res://vendor/fonts/ZalandoSans/ZalandoSans-CondensedBold.ttf",
}

var _cache: Dictionary = {}


func ui(weight: String = "medium") -> Font:
	return _cached(_UI.get(weight, _UI["medium"]))


func clock() -> Font:
	return _cached(_CLOCK)


func _cached(path: String) -> Font:
	if not _cache.has(path):
		_cache[path] = load(path) if ResourceLoader.exists(path) else ThemeDB.fallback_font
	return _cache[path]
