class_name Region
extends RefCounted
## A Region read from data: which terrain it stands on, and where its named
## places are (see ADR-0014). Making a new Region should cost a heightmap and
## one of these files, not new code.
##
## Named places are not baked coordinates. They are search rules -- "the level
## bluff top nearest the river", "flat upland above the floodplain" -- so that
## rebaking a heightmap moves them to where they should now be rather than
## leaving them hanging in the air.

const DIR := "res://data/regions/"

var id := ""
var display_name := ""
var terrain_path := ""
var points: Array = []
var moorings: Array = []
var data := {}


static func load_region(region_id: String) -> Region:
	var path := DIR + region_id + ".json"
	var text := FileAccess.get_file_as_string(path)
	assert(text != "", "no Region file at " + path)
	var parsed = JSON.parse_string(text)
	assert(parsed is Dictionary, "Region file is not an object: " + path)
	var r := Region.new()
	r.data = parsed
	r.id = str(parsed.get("id", region_id))
	r.display_name = str(parsed.get("name", r.id))
	r.terrain_path = str(parsed.get("terrain", ""))
	r.points = parsed.get("points", [])
	r.moorings = parsed.get("moorings", [])
	return r


func resolve_points(terrain: Terrain) -> Dictionary:
	## Work every named place out against the terrain, in file order, so a rule
	## may refer to a place named earlier.
	var found := {}
	for spec in points:
		var name := str(spec.get("name", ""))
		if name == "":
			continue
		found[name] = _resolve(spec, terrain, found)
	return found


func _resolve(spec: Dictionary, terrain: Terrain, found: Dictionary) -> Vector3:
	var rule := str(spec.get("rule", "at"))
	var flood := float(terrain.meta.get("floodplain_y", 0.0))
	match rule:
		"at":
			var a: Array = spec.get("at", [0, 0])
			return terrain.on_ground(float(a[0]), float(a[1]))
		"highest":
			# The hilltop in this rect: where a signal smoke would be seen from.
			return terrain._search(_rect(spec, found), func(x, z): return terrain.height_at(x, z))
		"bluff_top":
			# Level ground well above the floodplain, as near the river as it gets.
			var above := float(spec.get("above_flood", 9.0))
			var level := float(spec.get("level", 0.93))
			return terrain._search(_rect(spec, found), func(x, z):
				var ok := terrain.height_at(x, z) > flood + above and terrain.normal_at(x, z).y > level
				return -terrain.river_distance(x, z) if ok else -INF)
		"flat_upland":
			# The flattest ground above the floodplain: a prairie dog town wants this.
			var above2 := float(spec.get("above_flood", 6.0))
			return terrain._search(_rect(spec, found), func(x, z):
				var h := terrain.height_at(x, z)
				return terrain.normal_at(x, z).y * 50.0 if h > flood + above2 else -INF)
		"level_with":
			# Ground at the same height as another place, and as flat as possible:
			# the way up onto a bluff from behind.
			var ref: Vector3 = found.get(str(spec.get("of", "")), Vector3.ZERO)
			return terrain._search(_rect(spec, found), func(x, z):
				return -absf(terrain.height_at(x, z) - ref.y) - terrain.normal_at(x, z).distance_to(Vector3.UP) * 40.0)
		"bank_stand":
			# Flat ground a set distance back from the water: a landing.
			var want := float(spec.get("from_water", 75.0))
			return terrain._search(_rect(spec, found), func(x, z):
				return terrain.normal_at(x, z).y * 10.0 - absf(terrain.river_distance(x, z) - want) * 0.2)
		"offset_from":
			# So many metres toward the water and so many along the bank from
			# another place. The bank's direction is the river's, not the map's.
			var base: Vector3 = found.get(str(spec.get("of", "")), Vector3.ZERO)
			var to_water := terrain.toward_river(base.x, base.z)
			var along := Vector3(-to_water.z, 0.0, to_water.x)
			var p := base + to_water * float(spec.get("toward_water", 0.0)) + along * float(spec.get("along_bank", 0.0))
			return terrain.on_ground(p.x, p.z)
		"afloat":
			# Out from a place until there is water enough under the hull.
			var from: Vector3 = found.get(str(spec.get("of", "")), Vector3.ZERO)
			var to_water2 := terrain.toward_river(from.x, from.z)
			var along2 := Vector3(-to_water2.z, 0.0, to_water2.x)
			var start := from + along2 * float(spec.get("along_bank", 0.0))
			return terrain.afloat(start, to_water2, float(spec.get("clearance", 5.0)), float(spec.get("draught", 0.6)))
	push_error("Region %s: unknown point rule '%s'" % [id, rule])
	return Vector3.ZERO


func _rect(spec: Dictionary, found: Dictionary) -> Rect2:
	## Either a rect in map metres, or one placed relative to a named place.
	if spec.has("rect"):
		var r: Array = spec["rect"]
		return Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))
	var of: Vector3 = found.get(str(spec.get("rect_of", "")), Vector3.ZERO)
	var off: Array = spec.get("rect_offset", [0, 0])
	var size: Array = spec.get("rect_size", [100, 100])
	return Rect2(of.x + float(off[0]), of.z + float(off[1]), float(size[0]), float(size[1]))
