extends RefCounted
## The sun over Council Bluff, by the almanac (see sky.gd solar_position).

var t

const SkyScript := preload("res://scripts/world/sky.gd")


func test_the_sun_stands_highest_at_midday() -> void:
	# 41.5 N in early August: near 70 degrees up at noon.
	var noon: Vector2 = SkyScript.solar_position(8, 3, 13.0)
	t.check(noon.x > 58.0 and noon.x < 75.0, "high summer sun, got %.0f" % noon.x)
	var morning: Vector2 = SkyScript.solar_position(8, 3, 8.0)
	t.check(morning.x < noon.x, "lower at eight in the morning")


func test_summer_days_are_longer_than_winter_ones() -> void:
	var summer := SkyScript.day_length(6, 21)
	var winter := SkyScript.day_length(12, 21)
	t.check(summer > 14.5 and summer < 15.6, "midsummer about fifteen hours, got %.1f" % summer)
	t.check(winter > 8.6 and winter < 9.6, "midwinter about nine, got %.1f" % winter)
	t.check(SkyScript.day_length(8, 3) > 13.0, "early August is still long")


func test_the_sun_rises_in_the_east_and_sets_in_the_west() -> void:
	var dawn: Vector2 = SkyScript.solar_position(8, 3, 6.5)
	var dusk: Vector2 = SkyScript.solar_position(8, 3, 19.5)
	t.check(dawn.y > 45.0 and dawn.y < 115.0, "rises about east, got %.0f" % dawn.y)
	t.check(dusk.y > 245.0 and dusk.y < 315.0, "sets about west, got %.0f" % dusk.y)
