extends Node3D
## The spike: Sioux Country near Council Bluff, August 1804.
## Builds the world, the Corps, and runs the Day Clock and Trail Moments.

const GAME_MINUTES_PER_SECOND := 2.0  # 2 in-game hours per real minute
## While a staged Scenario plays out around the Leader the Day Clock slows to
## this share of itself: a few real minutes of talk at the fire should be half an
## hour of evening, not five hours of it.
const SCENE_TIME := 0.1

var state := ExpeditionState.new()
## Which Region is loaded. `--region=<id>` on the command line picks another,
## which is how a Region is proved to cost data and not code (ADR-0014).
var terrain := Terrain.new(Region.load_region(Region.wanted()))
var foliage := Foliage.new()
var sky := SkyAndWeather.new()
var hud := Hud.new()
var leader: Leader
var corps := {}  # key -> CorpsFigure (leader included)
var director: TrailMomentDirector
var prairie_dogs: Node3D
var stores: Stores
## Every man of the Corps, simulated (ADR-0010). ``corps`` above is the figures
## walking the Region; this is the roll they are drawn from.
var the_corps: Corps
var morning_report: MorningReportScreen
## Scenarios (ADR-0005) staged in the world: the one running, its stage, and
## the prompt its choices come up on.
var scenarios: Array[Scenario] = []
var scenario: Scenario
var stage: ScenarioStage
var scenario_prompt: ScenarioPrompt
var _scenario_waiting := false
var _scenario_rng := RandomNumberGenerator.new()
## The date being lived, as "1804-08-01": the Corps resolves a day at the
## midnight that ends it, and needs to know which day that was.
var _today := ""
## The worst of the day's rain and the heat of it, for the Corps at midnight.
var _day_storm := 0.0
var _day_high := 0.0
## The sergeants report at first light; the HUD says so once a morning.
var _report_due := true
var inventory: InventoryScreen
var map_screen: MapScreen
var _emptied: Array[String] = []
var smoke: GPUParticles3D

var _clock := 0.0
var _time := 0.0
var _nearby: Interactable
var _moment: Dictionary = {}  # the running Moment's def + progress


func _ready() -> void:
	terrain.name = "Terrain"
	add_child(terrain)
	terrain.build()
	foliage.name = "Foliage"
	add_child(foliage)
	foliage.build(terrain)
	sky.name = "Sky"
	add_child(sky)
	sky.build()
	add_child(hud)

	_spawn_corps()
	add_child(Wildlife.populate(terrain, leader))
	_place_world_features()
	sky.follow = leader.camera
	for grass in GrassField.fields(terrain, leader.camera):
		add_child(grass)
	var dust := Dust.new()
	dust.build(terrain, leader)
	add_child(dust)
	var hoppers := Hoppers.new()
	hoppers.build(terrain, leader)
	add_child(hoppers)
	var river_life := RiverLife.new()
	river_life.build(terrain, leader)
	add_child(river_life)
	var drift := RiverDrift.new()
	drift.build(terrain, leader)
	add_child(drift)
	var river_surface := terrain.get_node_or_null("Missouri")
	if river_surface is Water:
		(river_surface as Water).follow = leader.camera

	var mist := RiverMist.new()
	mist.build(terrain)
	mist.follow = leader.camera
	add_child(mist)

	var butterflies := Butterflies.new()
	butterflies.build(terrain)
	butterflies.follow = leader.camera
	add_child(butterflies)

	var motes := Motes.new()
	motes.build(terrain)
	motes.follow = leader.camera
	add_child(motes)

	director = TrailMomentDirector.new(TrailMomentDirector.load_defs("res://data/trail_moments.json"))
	state.journal_added.connect(hud.toast)
	state.add_journal("The Corps comes ashore below Council Bluff.")

	if "--autopilot" in OS.get_cmdline_user_args():
		var ap = load("res://scripts/debug/autopilot.gd").new()
		ap.name = "Autopilot"
		add_child(ap)
		ap.begin(self)


func _spawn_corps() -> void:
	var start: Vector3 = terrain.points["start"]
	leader = Leader.new()
	leader.name = "Lewis"
	leader.setup("lewis", "Lewis", Color(0.20, 0.27, 0.45))
	leader.position = start + Vector3(0, 0.5, 0)
	leader._yaw = 0.0  # face north, upriver toward Council Bluff
	add_child(leader)
	corps["lewis"] = leader
	var line := [
		["clark", "Clark", Color(0.55, 0.42, 0.26), true],
		["york", "York", Color(0.36, 0.27, 0.20), true],
		["drouillard", "Drouillard", Color(0.30, 0.40, 0.26), false],
		["floyd", "Sgt. Floyd", Color(0.28, 0.32, 0.40), true],
		["private1", "Pvt. Collins", Color(0.33, 0.33, 0.36), true],
		["private2", "Pvt. Shannon", Color(0.40, 0.35, 0.30), false],
	]
	for i in line.size():
		var f := Follower.new()
		f.name = line[i][1]
		f.setup(line[i][0], line[i][1], line[i][2], line[i][3])
		f.leader = leader
		f.place = i + 1
		f.position = start + Vector3(0.8 * (1 if i % 2 else -1), 0.5, (i + 1) * 2.2)
		leader.trail.push_front(f.position)
		add_child(f)
		leader.spring.add_excluded_object(f.get_rid())
		corps[line[i][0]] = f


func _place_world_features() -> void:
	## Everything here is asked for by the Region's data file (see region.gd);
	## this reads the request and builds it. A Region that wants no camp, or a
	## council somewhere else, changes its file and not this function.
	var region := terrain.region
	var mark := region.feature("landmark")
	if not mark.is_empty():
		var at: Vector3 = terrain.points[str(mark["at"])]
		var bluff := Interactable.landmark_marker(at, str(mark["name"]))
		bluff.on_interact = func():
			if state.visit_landmark(str(mark["at"]), str(mark["journal"])):
				bluff.enabled = false
				bluff.label = ""
				for c in bluff.get_children():
					if c is Decal:
						c.visible = false
		add_child(bluff)

	if region.has_feature("fleet"):
		add_child(Boats.fleet(terrain))
	if region.has_feature("camp"):
		add_child(Camp.pitch(terrain))

	stores = Stores.load_manifest()
	the_corps = Corps.load_corps()
	_today = _date_key()
	_count_the_corps()
	state.day_passed.connect(_feed_the_corps)
	state.day_passed.connect(func(_d): sky.set_day(Weather.day_pattern(state.current_month, state.current_day),
			state.current_month, state.current_day))
	sky.set_day(Weather.day_pattern(state.current_month, state.current_day), state.current_month, state.current_day)
	inventory = InventoryScreen.new()
	inventory.build(stores)
	add_child(inventory)
	map_screen = MapScreen.new()
	map_screen.build(terrain, leader)
	add_child(map_screen)
	for id in Scenario.all_ids():
		scenarios.append(Scenario.load_scenario(id))
	_scenario_rng.randomize()
	scenario_prompt = ScenarioPrompt.new()
	scenario_prompt.build(hud)
	scenario_prompt.chosen.connect(_scenario_chosen)
	add_child(scenario_prompt)
	morning_report = MorningReportScreen.new()
	morning_report.build()
	morning_report.closed.connect(_report_closed)
	add_child(morning_report)

	# The mainsail stretched on poles at the camp, where the council sits
	# (data/scenarios/council_bluff_1804.json).
	var meet := region.feature("council")
	if not meet.is_empty():
		var awning := Props.awning(terrain.points[str(meet["at"])], terrain)
		awning.name = "CouncilAwning"
		add_child(awning)

	# What the Corps has taken and is writing up: a skin on its frame by the fire.
	# Which ones, and what the Journal says of them, is the Region's business.
	for raw in region.data.get("features", {}).get("discoveries", []):
		var spec: Dictionary = raw
		var off: Array = spec.get("offset", [0, 0])
		var anchor: Vector3 = terrain.points[str(spec["at"])]
		var found := Interactable.specimen(terrain.on_ground(anchor.x + float(off[0]), anchor.z + float(off[1])),
				str(spec["label"]))
		var disc_id := str(spec["id"])
		found.on_interact = func():
			if state.add_discovery(disc_id, str(spec["journal"])):
				found.enabled = false
				found.label = ""
				for c in found.get_children():
					if c is Decal:
						c.visible = false
		add_child(found)

	var town := region.feature("prairie_dog_town")
	if not town.is_empty():
		prairie_dogs = Interactable.prairie_dog_town(terrain.points[str(town["at"])], terrain)
		add_child(prairie_dogs)

	# Fires standing over the far country, so the land reads as inhabited before
	# anyone is met. Where and how many is the Region's business.
	var towns := region.feature("village_smokes")
	if not towns.is_empty():
		var from: Vector3 = terrain.points[str(towns["from"])]
		var bear: Array = towns.get("bearing", [0, 1])
		var spread: Array = towns.get("spread", [0, 0])
		for i in int(towns.get("count", 3)):
			var far_smoke := Props.village_smoke()
			far_smoke.name = "VillageSmoke%d" % i
			var dist := float(towns.get("first", 430.0)) + i * float(towns.get("apart", 60.0))
			var vx := from.x + float(bear[0]) * dist + (i - 1) * float(spread[0])
			var vz := from.z + float(bear[1]) * dist + (i - 1) * float(spread[1])
			far_smoke.position = Vector3(vx, terrain.skirt_height(vx, vz) + 2.0, vz)
			add_child(far_smoke)

	var ridge := region.feature("ridge_smoke")
	if not ridge.is_empty():
		smoke = Props.smoke_column()
		smoke.name = "RidgeSmoke"
		smoke.position = terrain.points[str(ridge["at"])] + Vector3(0, 0.5, 0)
		smoke.emitting = false
		add_child(smoke)


# --------------------------------------------------------------------- loop


func _process(delta: float) -> void:
	_time += delta
	_clock += delta * GAME_MINUTES_PER_SECOND * (SCENE_TIME if _in_scene() else 1.0)
	if _clock >= 1.0:
		var whole := int(_clock)
		_clock -= whole
		state.advance_minutes(whole)

	sky.moon_phase = SkyAndWeather.moon_phase_for(state.current_year, state.current_month, state.current_day)
	sky.meteor_rate = SkyAndWeather.meteors_for(state.current_month, state.current_day)
	# The Day Clock counts whole minutes, which is what the Journal and the
	# rations want. The sky needs better than that: at two game-minutes a second
	# the sun would step half a degree twice a second, and it reads as a stutter.
	sky.update((state.minute_of_day + _clock) / 60.0, delta)
	_day_storm = maxf(_day_storm, sky.storm)
	_day_high = maxf(_day_high, Weather.temperature_f(state.current_month, state.current_day, state.hour(), sky.cloud_cover, sky.storm))
	if _report_due and state.minute_of_day >= 6 * 60:
		_report_due = false
		hud.toast("The sergeants have made their report.   [%s]" % GameInput.hint("morning_report"))
	# Only if this Region has a dog town; not every one will (see region.gd).
	if prairie_dogs != null:
		var scatter := _leader_near(prairie_dogs.position, 10.0) and leader.ground_speed() > 2.5
		Interactable.animate_prairie_dogs(prairie_dogs, _time, scatter)

	_run_scenario()
	# Trail Moments hold their tongues while a Scenario is being played, not
	# while one waits on the evening.
	var started := "" if scenario != null and not _scenario_waiting else director.update(delta, leader.ground_speed() > 0.5, _moment_context())
	if started != "":
		_start_moment(started)
	_run_moment(delta)

	_nearby = _find_nearby()
	var prompt := ""
	if _nearby:
		prompt = "[%s]  %s" % [GameInput.hint("interact"), _nearby.label]
	elif _moment.has("hint"):
		prompt = _moment["hint"]
	# The map: whatever ground has been walked goes onto it as he walks it.
	map_screen.note(leader.global_position)
	map_screen.set_date("%s   ·   the ground as far as the Corps has come" % state.full_date_str())
	var map_key := Input.is_action_just_pressed("toggle_map") 			or (map_screen.open and Input.is_action_just_pressed("menu"))
	if map_key and not inventory.open and not scenario_prompt.choosing:
		map_screen.toggle()
		# He stands still with the sheet open, as he would.
		leader.input_enabled = not map_screen.open
		leader.look_enabled = not map_screen.open
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if map_screen.open else Input.MOUSE_MODE_CAPTURED
	if Input.is_action_just_pressed("morning_report") and not map_screen.open and not inventory.open 			and not scenario_prompt.choosing:
		if morning_report.open:
			morning_report.close()
		else:
			_open_report()
	if Input.is_action_just_pressed("inventory") and not map_screen.open:
		inventory.toggle()
		# The Leader stands still while the quartermaster looks over the stores.
		leader.input_enabled = not inventory.open
		leader.look_enabled = not inventory.open
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if inventory.open else Input.MOUSE_MODE_CAPTURED
	if has_node("Camp"):
		(get_node("Camp") as Camp).night = sky.night_amount
	hud.update(state, delta, prompt, sky, stores)
	hud.show_spyglass(leader.glass_amount)
	if Input.is_action_just_pressed("interact") and _nearby:
		_nearby.interact()
	if Input.is_action_just_pressed("menu"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _leader_near(p: Vector3, r: float) -> bool:
	return Vector2(leader.global_position.x - p.x, leader.global_position.z - p.z).length() < r


func _find_nearby() -> Interactable:
	var best: Interactable = null
	var best_d := INF
	for n in get_tree().get_nodes_in_group("interactable"):
		var it := n as Interactable
		if not it.enabled or it.label == "":
			continue
		var d := it.global_position.distance_to(leader.global_position)
		if d < it.radius and d < best_d:
			best = it
			best_d = d
	return best


func _moment_context() -> Dictionary:
	return {"position": leader.global_position, "points": terrain.points,
		"companions": corps.keys(), "hour": state.hour()}


# ------------------------------------------------------------ Trail Moments


func _start_moment(id: String) -> void:
	var d: Dictionary = director._def(id)
	_moment = {"def": d, "line": 0, "wait": 0.6, "elapsed": 0.0, "done_lines": false, "done_action": true}
	match d["kind"]:
		"weather":
			sky.start_storm(float(d["weather"]["storm_seconds"]))
		"discovery":
			_moment["done_action"] = false
			_moment["stay"] = 0.0
		"encounter":
			_moment["done_action"] = false
			_spawn_elk(d["encounter"])
		"scenario_hook":
			_moment["done_action"] = false
			_start_smoke(d["scenario_hook"])


func _run_moment(delta: float) -> void:
	if _moment.is_empty():
		return
	var d: Dictionary = _moment["def"]
	_moment["elapsed"] += delta
	# Spoken lines, one after another.
	if not _moment["done_lines"]:
		_moment["wait"] -= delta
		if _moment["wait"] <= 0.0:
			var lines: Array = d["lines"]
			var line: Dictionary = lines[_moment["line"]]
			var secs := clampf(line["text"].length() * 0.065, 3.5, 8.0)
			hud.say(line["speaker"], line["text"], secs)
			_bark(line["speaker"], secs)
			_moment["line"] += 1
			if _moment["line"] >= lines.size():
				_moment["done_lines"] = true
			else:
				_moment["wait"] = secs + float(lines[_moment["line"]].get("delay", 0.4))
	# The Moment's own business.
	match d["kind"]:
		"discovery":
			_tick_discovery(d["discovery"], delta)
		"encounter", "scenario_hook":
			if _moment["elapsed"] > 240.0:
				_moment["done_action"] = true
	if _moment["done_lines"] and _moment["done_action"]:
		director.finish(d["id"])
		_moment = {}


## Off while the autopilot frames scenery shots, so no speech marks float in them.
var barks_enabled := true


func _bark(speaker: String, secs: float) -> void:
	if not barks_enabled:
		return
	for f in corps.values():
		if f.display_name == speaker:
			var label := Label3D.new()
			label.text = "…"
			label.font_size = 64
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			label.no_depth_test = true
			label.position = Vector3(0, 2.3, 0)
			label.modulate = Color(1, 0.95, 0.8)
			label.outline_size = 12
			f.add_child(label)
			get_tree().create_timer(secs).timeout.connect(label.queue_free)


func _tick_discovery(disc: Dictionary, delta: float) -> void:
	# The discovery is made at a named place; a Region without one cannot
	# offer it.
	var place := str(disc.get("place", "prairie_dog_town"))
	if not terrain.points.has(place):
		return
	var town: Vector3 = terrain.points[place]
	if _leader_near(town, float(disc["stay_radius"])):
		_moment["hint"] = disc["prompt"]
		if leader.ground_speed() < 0.5:
			_moment["stay"] += delta
			if _moment["stay"] >= float(disc["stay_seconds"]):
				state.add_discovery(disc["id"], disc["text"])
				_moment.erase("hint")
				_moment["done_action"] = true
	else:
		_moment.erase("hint")
		_moment["stay"] = 0.0
		if not _leader_near(town, 150.0):
			_moment["done_action"] = true


func _spawn_elk(enc: Dictionary) -> void:
	var fwd := leader.camera_forward()
	var p := leader.global_position + fwd * float(enc["distance"])
	for i in 12:  # find dry ground ahead
		if terrain.is_dry(p.x, p.z):
			break
		p += fwd.rotated(Vector3.UP, deg_to_rad(40.0)) * 20.0
	p.y = terrain.height_at(p.x, p.z)
	var herd := Interactable.new()
	herd.name = "ElkHerd"
	herd.position = p
	herd.label = "Hunt the elk"
	herd.radius = 18.0
	var rng := RandomNumberGenerator.new()
	for i in 6:
		var e := Interactable.elk()
		var off := Vector3(rng.randf_range(-9, 9), 0, rng.randf_range(-9, 9))
		e.position = off + Vector3(0, terrain.height_at(p.x + off.x, p.z + off.z) - p.y, 0)
		e.rotation.y = rng.randf() * TAU
		herd.add_child(e)
	# Tracks from the Leader toward the herd.
	var from := leader.global_position
	for i in range(3, int(float(enc["distance"]) / 3.0)):
		var tp := from.lerp(p, i * 3.0 / float(enc["distance"]))
		tp.y = terrain.height_at(tp.x, tp.z) + 0.03
		var track := Props.box(Vector3(0.18, 0.02, 0.28), Color(0.25, 0.2, 0.14), tp)
		track.rotation.y = atan2(p.x - from.x, p.z - from.z)
		track.name = "Track"
		add_child(track)
	herd.on_interact = func():
		state.food = min(100, state.food + int(enc["food"]))
		# An elk is some three hundred pounds of meat on the hoof.
		stores.add("fresh_meat", float(enc["food"]) * 14.0)
		the_corps.hides += 2.0
		state.add_journal(enc["text"])
		herd.enabled = false
		var tw := create_tween()
		tw.tween_property(herd, "position", herd.position + fwd * 60.0 + Vector3(0, -3, 0), 6.0)
		tw.tween_callback(herd.queue_free)
		if not _moment.is_empty():
			_moment["done_action"] = true
	add_child(herd)


func _feed_the_corps(_day: int) -> void:
	## The day just lived, resolved at the midnight that ends it: every man's
	## work, sickness and supper, what the rain got into, and history's own dates
	## (scripts/rules/corps.gd). In a Region the Corps is in camp; a Leg's days
	## will pass with ``travel`` set.
	var lines := the_corps.pass_day({"ended": _today, "travel": false, "storm": _day_storm, "hot_f": _day_high}, stores)
	for line in lines:
		state.add_journal(line)
	_today = _date_key()
	_day_storm = 0.0
	_day_high = 0.0
	_report_due = true
	_count_the_corps()
	# Say when a staple is broached to the last of it.
	for id in ["salt_pork", "corn_hominy", "flour", "whiskey"]:
		if stores.count(id) <= 0 and not _emptied.has(id):
			_emptied.append(id)
			state.add_journal("The last of the %s is gone." % str(stores.find(id).get("name", id)).to_lower())


func _in_scene() -> bool:
	## A Scenario is being played out where the Leader is, not waiting on him
	## somewhere he has not gone.
	if scenario == null:
		return false
	if not _scenario_waiting:
		return true
	# Waiting on the hour or on the Leader to go somewhere, the day goes on as
	# usual; waiting on a cast coming in, only when he is out there with them.
	if stage == null or scenario.waits_for() != "arrival":
		return false
	return Vector2(leader.global_position.x - stage.meet.x, leader.global_position.z - stage.meet.z).length() < 80.0


func _world() -> Dictionary:
	return {"state": state, "corps": the_corps, "stores": stores}


func _run_scenario() -> void:
	## Start whatever Scenario has come due; hold a running one at a node that
	## waits on the world until the world has done it.
	if scenario == null:
		for s in scenarios:
			if s.due(state, terrain.region.id, _world()):
				_start_scenario(s)
				break
		return
	if not scenario.cues.is_empty():
		if stage != null:
			stage.play_cues(scenario.cues)
		scenario.cues.clear()
	if _scenario_waiting and scenario.lapsed(state):
		# Let it go; whoever it staged stays where they stand.
		_scenario_waiting = false
		scenario = null
		return
	if _scenario_waiting and _wait_met(scenario.waits_for()):
		_scenario_waiting = false
		scenario.resume(_world())
		_count_the_corps()
		_speak_node()


func _start_scenario(s: Scenario) -> void:
	scenario = s
	s.begin(_world())
	if s.def.has("stage"):
		# The same people, walked on to the next place, if they are still here:
		# the chiefs who came in last night go up to the council from their fire.
		var spec: Dictionary = s.def["stage"]
		var again := "Stage_" + str(spec.get("reuse", ""))
		if spec.has("reuse") and has_node(again):
			stage = get_node(again) as ScenarioStage
			stage.move_to(terrain.points[str(spec["to"])], float(spec.get("radius", 12.0)))
		else:
			stage = ScenarioStage.stage(s, terrain, leader)
			add_child(stage)
	_advance_scenario()


func _wait_met(wait: String) -> bool:
	match wait:
		"":
			return true
		"arrival":
			return stage != null and stage.arrived() and stage.leader_close()
	if wait.begins_with("hour:"):
		return state.hour() >= float(wait.substr(5))
	if wait.begins_with("at:"):
		var p: Vector3 = terrain.points.get(wait.substr(3), leader.global_position)
		return Vector2(leader.global_position.x - p.x, leader.global_position.z - p.z).length() < 15.0
	return false


func _advance_scenario() -> void:
	if not _wait_met(scenario.waits_for()):
		_scenario_waiting = true
		var hint := str(scenario.node().get("hint", ""))
		if scenario.waits_for() == "arrival":
			hint = str(scenario.def.get("stage", {}).get("prompt", "Go and meet them"))
		if hint != "":
			hud.toast("%s." % hint)
		return
	_speak_node()


func _speak_node() -> void:
	scenario_prompt.play(scenario.lines(), func():
		if scenario.done:
			scenario = null
			return
		leader.input_enabled = false
		leader.look_enabled = false
		scenario_prompt.show_choices(scenario.choices(_world())))


func _scenario_chosen(index: int) -> void:
	leader.input_enabled = true
	leader.look_enabled = true
	var result := scenario.choose(index, _world(), _scenario_rng.randf())
	_count_the_corps()
	scenario_prompt.play(result["reply"], _advance_scenario)


func _count_the_corps() -> void:
	## What the HUD and the older systems read: mouths, fit men, spirits.
	state.men = the_corps.eating()
	state.fit = the_corps.fit_count()
	state.morale = roundi(the_corps.mean_morale())


func _date_key() -> String:
	return "%d-%02d-%02d" % [state.current_year, state.current_month, state.current_day]


func _open_report() -> void:
	morning_report.begin(the_corps, stores, state.full_date_str())
	leader.input_enabled = false
	leader.look_enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _report_closed(lines: Array) -> void:
	for line in lines:
		state.add_journal(str(line))
	_count_the_corps()
	leader.input_enabled = true
	leader.look_enabled = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _start_smoke(hook: Dictionary) -> void:
	smoke.emitting = true
	var p: Vector3 = terrain.points[hook["point"]]
	var meet := Interactable.new()
	meet.name = "Messengers"
	meet.position = p
	meet.label = hook["prompt"]
	meet.radius = float(hook["radius"])
	for i in 2:
		var m := CorpsFigure.new()
		m.setup("messenger%d" % i, "Messenger", Color(0.52, 0.40, 0.30), false)
		m.position = Vector3(-1.2 + i * 2.4, 0.2, 3.0)
		meet.add_child(m)
		m.ready.connect(func(): m.play("Idle_Talking"))
	meet.on_interact = func():
		state.add_journal(hook["text"])
		meet.enabled = false
		smoke.emitting = false
		if not _moment.is_empty():
			_moment["done_action"] = true
	add_child(meet)
