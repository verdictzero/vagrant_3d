class_name Matcaps
extends RefCounted
## The sixteen built-in matcaps, in gallery order. vendor/matcaps/SOURCES.txt
## says where each came from. The first is the default clay.

const DIR := "res://vendor/matcaps/"
const LIST := [
	"MATCAP_00_clay_grey", "MATCAP_01_clay_light", "MATCAP_02_soft_grey", "MATCAP_03_porcelain",
	"MATCAP_04_dark_rim", "MATCAP_05_chrome", "MATCAP_06_dark_metal", "MATCAP_07_matte_black",
	"MATCAP_08_red_clay", "MATCAP_09_orange", "MATCAP_10_gold", "MATCAP_11_green",
	"MATCAP_12_teal", "MATCAP_13_blue", "MATCAP_14_purple", "MATCAP_15_skin",
]

static var _cache: Dictionary = {}


static func count() -> int:
	return LIST.size()


static func path(i: int) -> String:
	return DIR + LIST[i] + ".png"


## The gallery label: the slug with its number and underscores gone.
static func label(i: int) -> String:
	return LIST[i].substr(10).replace("_", " ").to_upper()


static func texture(i: int) -> Texture2D:
	var p := path(i)
	if not _cache.has(p):
		_cache[p] = load(p) if ResourceLoader.exists(p) else null
	return _cache[p]
