extends Node3D
## The spike: Sioux Country near Council Bluff, August 1804.
## Builds the world, the Corps, and runs the Day Clock and Trail Moments.

const GAME_MINUTES_PER_SECOND := 2.0  # 2 in-game hours per real minute
const COUNCIL_BLUFF_TEXT := "Council Bluff — a high bluff above the river where the Corps will hold its first council with the Otoe and Missouria."

var state := ExpeditionState.new()
var terrain := Terrain.new()
var foliage := Foliage.new()
var sky := SkyAndWeather.new()
var hud := Hud.new()
var leader: Leader
var corps := {}  # key -> CorpsFigure (leader included)
var director: TrailMomentDirector
var prairie_dogs: Node3D
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
	_place_world_features()
	sky.follow = leader.camera

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
	var bluff := Interactable.landmark_marker(terrain.points["council_bluff"], "Council Bluff")
	bluff.on_interact = func():
		if state.visit_landmark("council_bluff", COUNCIL_BLUFF_TEXT):
			bluff.enabled = false
			bluff.label = ""
			for c in bluff.get_children():
				if c is MeshInstance3D and c.mesh is TorusMesh:
					c.visible = false
	add_child(bluff)

	prairie_dogs = Interactable.prairie_dog_town(terrain.points["prairie_dog_town"], terrain)
	add_child(prairie_dogs)

	smoke = Props.smoke_column()
	smoke.name = "RidgeSmoke"
	smoke.position = terrain.points["smoke_ridge"] + Vector3(0, 0.5, 0)
	smoke.emitting = false
	add_child(smoke)


# --------------------------------------------------------------------- loop


func _process(delta: float) -> void:
	_time += delta
	_clock += delta * GAME_MINUTES_PER_SECOND
	if _clock >= 1.0:
		var whole := int(_clock)
		_clock -= whole
		state.advance_minutes(whole)

	sky.update(state.hour(), delta)
	Interactable.animate_prairie_dogs(prairie_dogs, _time, _leader_near(terrain.points["prairie_dog_town"], 10.0) and leader.ground_speed() > 2.5)

	var started := director.update(delta, leader.ground_speed() > 0.5, _moment_context())
	if started != "":
		_start_moment(started)
	_run_moment(delta)

	_nearby = _find_nearby()
	var prompt := ""
	if _nearby:
		prompt = "[%s]  %s" % [GameInput.hint("interact"), _nearby.label]
	elif _moment.has("hint"):
		prompt = _moment["hint"]
	hud.update(state, delta, prompt)
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


func _bark(speaker: String, secs: float) -> void:
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
	var town: Vector3 = terrain.points["prairie_dog_town"]
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
		state.add_journal(enc["text"])
		herd.enabled = false
		var tw := create_tween()
		tw.tween_property(herd, "position", herd.position + fwd * 60.0 + Vector3(0, -3, 0), 6.0)
		tw.tween_callback(herd.queue_free)
		if not _moment.is_empty():
			_moment["done_action"] = true
	add_child(herd)


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
