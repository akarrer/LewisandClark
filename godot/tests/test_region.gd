extends RefCounted
## A Region is a heightmap plus a data file (ADR-0014). These hold that true:
## every Region file resolves, names a landing, and asks only for places it names.

var t


func _regions() -> Array[String]:
	var ids: Array[String] = []
	for f in DirAccess.get_files_at(Region.DIR):
		if f.ends_with(".json"):
			ids.append(f.get_basename())
	return ids


func test_every_region_names_a_landing():
	for id in _regions():
		var r := Region.load_region(id)
		var terrain := Terrain.new(r)
		terrain.define_points()
		t.check(terrain.points.has("start"), "%s names no start" % id)
		terrain.free()


func test_every_place_is_on_the_map():
	for id in _regions():
		var terrain := Terrain.new(Region.load_region(id))
		terrain.define_points()
		for name in terrain.points:
			var p: Vector3 = terrain.points[name]
			t.check(p.x >= 0.0 and p.x <= Terrain.SIZE and p.z >= 0.0 and p.z <= Terrain.SIZE,
					"%s: %s is off the map at %s" % [id, name, p])
		terrain.free()


func test_features_stand_at_named_places():
	for id in _regions():
		var r := Region.load_region(id)
		var terrain := Terrain.new(r)
		terrain.define_points()
		for key in r.data.get("features", {}):
			var f := r.feature(key)
			for field in ["at", "from"]:
				if f.has(field):
					t.check(terrain.points.has(str(f[field])),
							"%s: feature %s stands at unnamed place %s" % [id, key, f[field]])
		if r.has_feature("fleet"):
			for i in 3:
				t.check(terrain.points.has("mooring_%d" % i), "%s has a fleet but no mooring_%d" % [id, i])
		if r.has_feature("camp"):
			t.check(terrain.points.has("camp"), "%s has a camp but no camp place" % id)
		terrain.free()


func test_council_bluff_places_are_where_they_were():
	# The refactor moved these searches from code into data; they must not move.
	var terrain := Terrain.new(Region.load_region("council_bluff"))
	terrain.define_points()
	t.check(terrain.points["council_bluff"].distance_to(Vector3(432, 12.8, 532)) < 1.0, "council bluff moved")
	t.check(terrain.points["start"].distance_to(Vector3(524, 1.2, 780)) < 1.0, "landing moved")
	terrain.free()
