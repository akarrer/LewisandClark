extends RefCounted
## The moon the Corps would have seen (see sky.gd).

var t

const SkyScript := preload("res://scripts/world/sky.gd")


func test_julian_day_matches_known_epochs() -> void:
	t.check(absf(SkyScript.julian_day(2000, 1, 1) - 2451544.5) < 0.001, "2000-01-01")
	t.check(absf(SkyScript.julian_day(1804, 8, 3) - 2380171.5) < 0.001, "the council at Council Bluff")


func test_moon_phase_finds_new_and_full_moons() -> void:
	# New moon 2024-01-11, full moon 2024-01-25 (both well recorded).
	var new_moon := SkyScript.moon_phase_for(2024, 1, 11)
	t.check(min(new_moon, 1.0 - new_moon) < 0.05, "new moon, got %f" % new_moon)
	t.check(absf(SkyScript.moon_phase_for(2024, 1, 25) - 0.5) < 0.05, "full moon")


func test_perseids_swell_in_august() -> void:
	t.check(SkyScript.meteors_for(8, 12) > SkyScript.meteors_for(8, 30) * 3.0, "peak around the 12th")
	t.check(SkyScript.meteors_for(3, 12) < 0.05, "quiet in March")
