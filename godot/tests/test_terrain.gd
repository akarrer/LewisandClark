extends RefCounted
## Terrain from real elevation data: the places the story needs are where they should be.

var t


func _terrain() -> Terrain:
	var tr := Terrain.new()
	tr.define_points()
	return tr


func test_heightmap_loaded_from_usgs_bake() -> void:
	var tr := _terrain()
	t.check(str(tr.meta.get("source", "")).begins_with("USGS"), "provenance recorded")
	t.check(tr.height_at(900, 300) < 3.0, "the east is Missouri bottomland")
	t.check(tr.height_at(150, 600) > 25.0, "the west is loess upland")
	tr.free()


func test_named_points_exist_and_are_dry() -> void:
	var tr := _terrain()
	for key in ["start", "council_bluff", "bluff_approach", "prairie_dog_town", "smoke_ridge"]:
		t.check(tr.points.has(key), "missing " + key)
		var p: Vector3 = tr.points[key]
		t.check(p != Vector3.ZERO, key + " not found")
		t.check(tr.is_dry(p.x, p.z), key + " is in the river")
	tr.free()


func test_council_bluff_overlooks_the_river() -> void:
	var tr := _terrain()
	var bluff: Vector3 = tr.points["council_bluff"]
	t.check(bluff.y > 10.0, "bluff top only %.1f m" % bluff.y)
	t.check(tr.river_distance(bluff.x, bluff.z) < 160.0, "bluff %.0f m from the river" % tr.river_distance(bluff.x, bluff.z))
	t.check(tr.points["start"].y < 4.0, "start should be down on the bottomland")
	t.check(tr.points["start"].z > bluff.z, "start is south (downriver) of the bluff")
	tr.free()


func test_walkable_spots_are_not_cliffs() -> void:
	var tr := _terrain()
	for key in ["start", "prairie_dog_town", "council_bluff"]:
		var p: Vector3 = tr.points[key]
		t.check(tr.normal_at(p.x, p.z).y > 0.85, key + " is too steep")
	tr.free()


func test_river_channel_below_water_and_banks_above() -> void:
	var tr := _terrain()
	var course: Array = tr.meta["river_1804"]
	for i in range(1, course.size() - 2):
		var p: Array = course[i]
		t.check(tr.height_at(p[0], p[1]) < Terrain.WATER_Y, "channel dry at %s" % str(p))
	var bluff: Vector3 = tr.points["council_bluff"]
	t.check(tr.toward_river(bluff.x, bluff.z).x > 0.0, "the river lies east of Council Bluff")
	tr.free()


func test_story_places_are_reachable_on_foot() -> void:
	var tr := _terrain()
	var start: Vector3 = tr.points["start"]
	for key in ["council_bluff", "prairie_dog_town", "smoke_ridge"]:
		var route := tr.find_route(start, tr.points[key])
		t.check(not route.is_empty(), "no walking route from the start to " + key)
	tr.free()
