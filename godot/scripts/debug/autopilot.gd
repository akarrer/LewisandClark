extends Node
## Plays the spike hands-free for verification: walks the Leader through the
## prairie dog town, answers Trail Moments, climbs Council Bluff, takes
## screenshots, and reports frame times.
##   godot --path godot -- --autopilot --shots=<dir> [--fast-moments]

var main
var shots_dir := ""
var _steps: Array = []
var _step := 0
var _wait := 0.0
var _t := 0.0
var _frames: Array[float] = []
var _log: Array[String] = []
var _target := Vector3.ZERO
var _shot_n := 0
var _stuck_t := 0.0
var _last_pos := Vector3.ZERO
var _storm_shot := false
var _detour := ""


func begin(p_main) -> void:
	main = p_main
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots_dir = a.substr(8)
	if "--fast-moments" in OS.get_cmdline_user_args():
		main.director.cadence_min = 14.0
		main.director.cadence_max = 20.0
		main.director._schedule()
	DirAccess.make_dir_recursive_absolute(shots_dir)
	_steps = [
		["wait", 3.0], ["shot", "start"],
		["walk_to", "prairie_dog_town", 6.0], ["wait", 7.5], ["shot", "prairie_dogs"],
		["walk_to", "council_bluff_base", 30.0],
		["walk_to", "council_bluff", 4.0], ["interact"], ["wait", 1.0], ["face_river"], ["wait", 1.2], ["shot", "council_bluff_overlook"],
		["report"],
	]


func _process(delta: float) -> void:
	_t += delta
	if _t > 2.0:
		_frames.append(delta)
	_watch_moments()
	if _step >= _steps.size():
		return
	var s: Array = _steps[_step]
	match s[0]:
		"wait":
			_release()
			_wait += delta
			if _wait >= s[1]:
				_next()
		"shot":
			_shot(s[1])
			_next()
		"walk_to":
			var p: Vector3 = _point(s[1])
			if _drive_toward(p, float(s[2]), delta):
				_release()
				_next()
		"interact":
			if main._nearby:
				_log.append("interact: " + main._nearby.label)
				main._nearby.interact()
			else:
				_log.append("interact: nothing in range")
			_next()
		"face_river":
			var l: Leader = main.leader
			var rx: float = main.terrain.river_x(l.global_position.z)
			l._yaw = rad_to_deg(atan2(-(rx - l.global_position.x), -0.0001)) if rx > l.global_position.x else l._yaw
			l._pitch = -18.0
			_next()
		"report":
			_report()
			_next()
		"clear_detour":
			_detour = ""
			_next()


func _watch_moments() -> void:
	var m: Dictionary = main._moment
	if m.is_empty():
		return
	var id: String = m["def"]["id"]
	if not m.has("logged"):
		m["logged"] = true
		_log.append("%.0fs moment: %s" % [_t, id])
		get_tree().create_timer(2.5).timeout.connect(func(): _shot("moment_" + id))
	if id == "thunderstorm" and main.sky.storm > 0.8 and not _storm_shot:
		_storm_shot = true
		_shot("storm")
	# Answer the escalating Moments with a detour.
	if id in ["elk_tracks", "smoke_ridge"] and _detour == "" and not m.get("answered", false):
		_detour = id
		var saved := _step
		var target := "herd" if id == "elk_tracks" else "smoke_ridge"
		_steps.insert(saved, ["walk_to", target, 12.0 if id == "elk_tracks" else 10.0])
		_steps.insert(saved + 1, ["interact"])
		_steps.insert(saved + 2, ["wait", 2.0])
		_steps.insert(saved + 3, ["shot", "after_" + id])
		_steps.insert(saved + 4, ["clear_detour"])
		_wait = 0.0
		m["answered"] = true


func _point(name: String) -> Vector3:
	if name == "herd":
		var herd = main.get_node_or_null("ElkHerd")
		return herd.global_position if herd else main.leader.global_position
	if name == "council_bluff_base":
		var b: Vector3 = main.terrain.points["council_bluff"]
		return Vector3(b.x + 90.0, 0, b.z - 60.0)
	return main.terrain.points[name]


func _drive_toward(p: Vector3, arrive: float, delta: float) -> bool:
	var l: Leader = main.leader
	var to := Vector2(p.x - l.global_position.x, p.z - l.global_position.z)
	if to.length() < arrive:
		return true
	# Face the target; the Leader walks where the camera looks.
	var desired := rad_to_deg(atan2(-to.x, -to.y))
	l._yaw = lerp_angle_deg(l._yaw, desired, clampf(delta * 3.0, 0.0, 1.0))
	l._pitch = lerpf(l._pitch, -10.0, delta)
	Input.action_press("move_forward", 1.0)
	# Unstick: if blocked, sidestep for a moment.
	if l.global_position.distance_to(_last_pos) < 0.02:
		_stuck_t += delta
	else:
		_stuck_t = 0.0
	_last_pos = l.global_position
	if _stuck_t > 0.6:
		Input.action_press("move_right", 1.0)
	else:
		Input.action_release("move_right")
	return false


static func lerp_angle_deg(a: float, b: float, w: float) -> float:
	return rad_to_deg(lerp_angle(deg_to_rad(a), deg_to_rad(b), w))


func _release() -> void:
	Input.action_release("move_forward")
	Input.action_release("move_right")


func _next() -> void:
	_step += 1
	_wait = 0.0


func _shot(name: String) -> void:
	_shot_n += 1
	var img := get_viewport().get_texture().get_image()
	var path := "%s/%02d_%s.png" % [shots_dir, _shot_n, name]
	img.save_png(path)
	_log.append("%.0fs shot: %s" % [_t, path.get_file()])


func _report() -> void:
	var sorted := _frames.duplicate()
	sorted.sort()
	var total := 0.0
	for f in _frames:
		total += f
	var avg_fps := _frames.size() / maxf(total, 0.001)
	var worst := sorted.slice(int(sorted.size() * 0.99))
	var worst_ms := 0.0
	for f in worst:
		worst_ms += f
	worst_ms = worst_ms / maxi(worst.size(), 1) * 1000.0
	var vp := get_viewport().get_visible_rect().size
	print("AUTOPILOT REPORT")
	print("resolution %dx%d  avg %.0f fps  1%% low frame %.1f ms (%.0f fps)  over %.0fs" % [vp.x, vp.y, avg_fps, worst_ms, 1000.0 / maxf(worst_ms, 0.001), _t])
	print("draw calls %d  primitives %d" % [RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME), RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)])
	for line in _log:
		print("  " + line)
	print("JOURNAL")
	for j in main.state.journal:
		print("  " + j)
	get_tree().quit()
