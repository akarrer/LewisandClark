extends RefCounted
## Terrain: named places are where the story needs them.

var t


func _terrain() -> Terrain:
	var tr := Terrain.new()
	tr._define_points()
	return tr


func test_named_points_exist_and_are_dry() -> void:
	var tr := _terrain()
	for key in ["start", "council_bluff", "prairie_dog_town", "smoke_ridge"]:
		t.check(tr.points.has(key), "missing " + key)
		var p: Vector3 = tr.points[key]
		t.check(tr.is_dry(p.x, p.z), key + " is in the river")
		t.check(p.x > 20.0 and p.x < Terrain.SIZE - 20.0 and p.z > 20.0 and p.z < Terrain.SIZE - 20.0, key + " near the edge")
	tr.free()


func test_council_bluff_stands_above_the_river() -> void:
	var tr := _terrain()
	var bluff: Vector3 = tr.points["council_bluff"]
	t.check(bluff.y > 20.0, "bluff top only %.1f m" % bluff.y)
	t.check(tr.points["start"].y < 6.0, "start should be down on the floodplain")
	tr.free()


func test_start_and_prairie_dog_town_are_walkable_ground() -> void:
	var tr := _terrain()
	for key in ["start", "prairie_dog_town"]:
		var p: Vector3 = tr.points[key]
		t.check(tr.normal_at(p.x, p.z).y > 0.9, key + " is too steep")
	tr.free()


func test_river_is_below_water_and_banks_above() -> void:
	var tr := _terrain()
	for z in [100.0, 400.0, 800.0]:
		var rx := tr.river_x(z)
		t.check(tr.height_at(rx, z) < Terrain.WATER_Y, "channel dry at z=%d" % z)
		t.check(tr.height_at(rx + tr.river_half_width(z) + 20.0, z) > Terrain.WATER_Y, "east bank flooded at z=%d" % z)
	tr.free()
