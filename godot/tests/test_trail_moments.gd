extends RefCounted
## TrailMomentDirector: cadence, variety, placement, requirements.

var t

const ALL := ["lewis", "clark", "york", "drouillard", "floyd"]


func _director(seed_value: int = 1) -> TrailMomentDirector:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return TrailMomentDirector.new(TrailMomentDirector.load_defs("res://data/trail_moments.json"), rng)


func _ctx(pos := Vector3(9999, 0, 9999), hour := 12.0, companions: Array = ALL) -> Dictionary:
	return {"position": pos, "points": {"prairie_dog_town": Vector3(0, 0, 0), "smoke_ridge": Vector3(500, 0, 500)},
		"companions": companions, "hour": hour}


func _walk(d: TrailMomentDirector, seconds: float, ctx: Dictionary, walking := true) -> String:
	var elapsed := 0.0
	while elapsed < seconds:
		var got := d.update(0.5, walking, ctx)
		if got != "":
			return got
		elapsed += 0.5
	return ""


func test_six_moments_defined() -> void:
	var d := _director()
	t.eq(d.defs.size(), 6)
	var kinds := {}
	for m in d.defs:
		kinds[m["kind"]] = true
	t.eq(kinds.size(), 6, "one of each kind")


func test_nothing_before_the_cadence() -> void:
	var d := _director()
	t.eq(_walk(d, 59.0, _ctx()), "")


func test_a_random_moment_by_ninety_seconds_of_walking() -> void:
	var d := _director()
	t.check(_walk(d, 90.5, _ctx()) != "")


func test_standing_still_does_not_count() -> void:
	var d := _director()
	t.eq(_walk(d, 300.0, _ctx(), false), "")


func test_one_at_a_time() -> void:
	var d := _director()
	var first := _walk(d, 91.0, _ctx())
	t.eq(_walk(d, 400.0, _ctx()), "", "blocked while active")
	d.finish(first)
	t.check(_walk(d, 91.0, _ctx()) != "", "resumes after finish")


func test_no_repeats_and_no_same_speaker_twice_running() -> void:
	for seed_value in range(1, 30):
		var d := _director(seed_value)
		var seen: Array = []
		var speakers: Array = []
		for i in 6:
			var id := _walk(d, 91.0, _ctx())
			if id == "":
				break
			d.finish(id)
			t.check(id not in seen, "repeat %s (seed %d)" % [id, seed_value])
			seen.append(id)
			speakers.append(d.last_speaker)
		for i in range(1, speakers.size()):
			t.check(speakers[i] != speakers[i - 1], "same speaker twice (seed %d): %s" % [seed_value, str(speakers)])


func test_placed_moment_fires_in_radius_immediately() -> void:
	var d := _director()
	t.eq(d.update(0.1, true, _ctx(Vector3(30, 0, 20))), "prairie_dogs")
	d.finish("prairie_dogs")
	t.eq(d.update(0.1, true, _ctx(Vector3(30, 0, 20))), "", "only once")


func test_requirements_and_hours() -> void:
	var d := _director()
	var ctx := _ctx(Vector3(9999, 0, 9999), 22.0, ["lewis", "clark", "york"])
	var seen: Array = []
	for i in 8:
		var id := _walk(d, 91.0, ctx)
		if id == "":
			break
		seen.append(id)
		d.finish(id)
	t.check("elk_tracks" not in seen, "needs Drouillard")
	t.check("floyd_pain" not in seen, "needs Floyd")
	t.check("thunderstorm" not in seen, "storms only 9-19h")
	t.check("prairie_dogs" not in seen, "placed moments never random")
