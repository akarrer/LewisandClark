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
var _free_cam: Camera3D
var _debug_t := 0.0
var _blocked := 0


func begin(p_main) -> void:
	main = p_main
	main.leader.look_enabled = false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots_dir = a.substr(8)
	if "--fast-moments" in OS.get_cmdline_user_args():
		main.director.cadence_min = 14.0
		main.director.cadence_max = 20.0
		main.director._schedule()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--days="):
			# Wind the Day Clock on, so the Stores are drawn down and the Journal fills.
			var days := int(a.substr(7))
			print("AP winding on %d days" % days)
			main.state.advance_minutes(days * 24 * 60)
			print("AP provisions left: %d days, food %d" % [
					main.stores.days_of_provisions(main.state.men), main.state.food])
	DirAccess.make_dir_recursive_absolute(shots_dir)
	if "--scenery" in OS.get_cmdline_user_args():
		_steps = _scenery_steps()
		return
	if "--stores" in OS.get_cmdline_user_args():
		main.hud.visible = false
		_steps = [["wait", 1.5]]
		for hold in Stores.HOLDS:
			_steps.append(["stores", hold])
			_steps.append(["wait", 0.4])
			_steps.append(["shot", "stores_" + hold])
		_steps.append(["report"])
		return
	if "--council" in OS.get_cmdline_user_args():
		main.hud.visible = false
		var c := Council.open("council_bluff_1804", main.stores)
		main.council_screen.begin(c)
		_steps = [["wait", 1.0], ["shot", "council_open"]]
		_steps.append(["council_offer", "medals", 5])
		_steps.append(["council_offer", "flags", 1])
		_steps.append(["wait", 0.3])
		_steps.append(["shot", "council_offered"])
		for taken in ["speech", "medals", "air_gun"]:
			_steps.append(["council_take", taken])
			_steps.append(["wait", 0.3])
		_steps.append(["shot", "council_part_way"])
		_steps.append(["council_offer", "powder", 1])
		_steps.append(["council_offer", "whiskey", 2])
		_steps.append(["council_take", "the_ask"])
		_steps.append(["council_offer", "medals", 1])
		_steps.append(["council_offer", "flags", 1])
		_steps.append(["council_offer", "tobacco", 6])
		_steps.append(["council_take", "send_after"])
		_steps.append(["wait", 0.4])
		_steps.append(["shot", "council_verdict"])
		_steps.append(["report"])
		return
	if "--march" in OS.get_cmdline_user_args():
		_steps = _march_steps()
		return
	_steps = [
		["wait", 3.0], ["shot", "start"],
		["walk_to", "prairie_dog_town", 6.0], ["wait", 7.5], ["shot", "prairie_dogs"],
		["walk_to", "bluff_approach", 20.0],
		["walk_to", "council_bluff", 4.0], ["interact"], ["wait", 1.0], ["face_river"], ["wait", 1.2], ["shot", "council_bluff_overlook"],
		["report"],
	]


func _march_steps() -> Array:
	## The Corps on the move, filmed from beside the trail: for judging gait and pace.
	main.director.cadence_min = 1e9
	main.director.cadence_max = 1e9
	main.director._schedule()
	main.hud.visible = false
	var steps: Array = [["wait", 2.0], ["walk_for", "prairie_dog_town", 9.0], ["sidecam"]]
	var frames := 6
	var every := 0.7
	if "--stepoff" in OS.get_cmdline_user_args():
		# From a halt: watch each man step off in his own time.
		steps = [["walk_for", "prairie_dog_town", 6.0], ["wait", 4.0], ["sidecam", "prairie_dog_town"], ["shot", "halt"]]
		frames = 8
		every = 0.35
	for i in frames:
		steps.append(["walk_for", "prairie_dog_town", every])
		steps.append(["shot", "march"])
	steps.append(["report"])
	return steps


func _scenery_steps() -> Array:
	## Fixed viewpoints at fixed hours, for before/after comparisons of the look.
	main.director.cadence_min = 1e9
	main.director.cadence_max = 1e9
	main.director._schedule()
	main.hud.visible = false
	main.leader.input_enabled = false
	main.barks_enabled = false
	if main.has_node("Wildlife"):
		(main.get_node("Wildlife") as Wildlife).shy = false
	var tr: Terrain = main.terrain
	# Stand beside the flag, not on it, so the pole doesn't split the frame.
	var bluff: Vector3 = tr.points["council_bluff"] + Vector3(0, 0, 8)
	var dogs: Vector3 = tr.points["prairie_dog_town"]
	var start: Vector3 = tr.points["start"]
	var ridge: Vector3 = tr.points["smoke_ridge"]
	var steps: Array = [["wait", 2.0]]
	# A spot among the cottonwoods ~60 m from the water, upriver of the start.
	var grove := start
	var best := INF
	for dx in range(-120, 121, 8):
		for dz in range(-240, -120, 8):
			var gx := start.x + dx
			var gz := start.z + dz
			var d := absf(tr.river_distance(gx, gz) - 62.0)
			if tr.walkable(gx, gz) and d < best:
				best = d
				grove = Vector3(gx, 0, gz)
	# On the sandbar, a few metres from the water's edge.
	var bank := start
	best = INF
	for dx in range(-160, 161, 4):
		for dz in range(-200, 41, 4):
			var bx := start.x + dx
			var bz := start.z + dz
			var d := absf(tr.river_distance(bx, bz) - tr.river_half_width() - 4.0)
			if tr.walkable(bx, bz) and d < best:
				best = d
				bank = Vector3(bx, 0, bz)
	var to_water: Vector3 = tr.toward_river(bank.x, bank.z)
	var bank_yaw := rad_to_deg(atan2(-to_water.x, -to_water.z)) + 50.0  # upriver, across the water
	# On the bank beside the keelboat.
	var keel := start
	var quay := start
	if main.has_node("Fleet"):
		keel = main.get_node("Fleet").get_child(0).global_position
		var inland := -tr.toward_river(keel.x, keel.z)
		quay = keel
		for i in 120:
			quay += inland
			if tr.walkable(quay.x, quay.z):
				break
		quay += inland * 3.0 + Vector3(-inland.z, 0, inland.x) * 9.0
	# 130 m downhill of the first elk herd, looking up at it.
	var herd := start
	var herd_eye := start
	if main.has_node("Wildlife") and main.get_node("Wildlife").get_child_count() > 0:
		herd = main.get_node("Wildlife").get_child(0).position
		var space: PhysicsDirectSpaceState3D = main.get_world_3d().direct_space_state
		var target := herd + Vector3(0, 1.2, 0)
		# Outside the ~45 m at which they flush, or the herd is gone before the shot.
		for r in range(95, 55, -10):
			var found := false
			for k in 24:
				var ang := k * TAU / 24.0
				var e := herd + Vector3(cos(ang), 0, sin(ang)) * r
				if not tr.walkable(e.x, e.z):
					continue
				var eye := Vector3(e.x, tr.height_at(e.x, e.z) + 2.5, e.z)
				if space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, target)).is_empty():
					herd_eye = e
					found = true
					break
			if found:
				break
		_log.append("herd at %s, viewed from %s" % [herd, herd_eye])
	# A willow thicket on a bar, seen from the sand a few metres off.
	var thicket := bank
	var willows: MultiMeshInstance3D = null
	for c in main.foliage.get_children():
		if c is MultiMeshInstance3D and c.multimesh.instance_count > 6 and c.get_meta("kind", "") == "willow":
			willows = c
			break
	if willows:
		thicket = willows.multimesh.get_instance_transform(0).origin
	var thicket_eye := thicket + (tr.toward_river(thicket.x, thicket.z) * 9.0).rotated(Vector3.UP, 1.1)
	# The camp, seen from the riverward side.
	var camp := start
	var camp_eye := start
	if main.has_node("Camp"):
		camp = main.get_node("Camp").global_position
		camp_eye = camp + tr.toward_river(camp.x, camp.z) * 11.0 + Vector3(2, 0, 2)
	# Aimed at the moon. Its night bearing is fixed in sky.gd (pitch -40, yaw 35),
	# and the sky has not yet been wound forward to night when these are built.
	var moon_dir := Basis.from_euler(Vector3(deg_to_rad(-40.0), deg_to_rad(35.0), 0.0)).z
	var moon_yaw := rad_to_deg(atan2(-moon_dir.x, -moon_dir.z))
	var moon_pitch := rad_to_deg(asin(clampf(moon_dir.y, -1.0, 1.0)))
	# A heron in the shallows, seen from 30 m: outside the range at which it flushes.
	var wader := bank
	var wader_eye := bank
	if main.has_node("Wildlife"):
		for c in main.get_node("Wildlife").get_children():
			if c.has_node("Neck") and c.has_node("WingL"):
				wader = c.position
				break
		# Somewhere with a clear sight of it, not behind a snag.
		var space2: PhysicsDirectSpaceState3D = main.get_world_3d().direct_space_state
		var target2 := Vector3(wader.x, wader.y + 0.9, wader.z)
		for r in [12.0, 16.0, 20.0]:
			var radius := float(r)
			var found2 := false
			for k in 20:
				var ang2 := k * TAU / 20.0
				var e2: Vector3 = wader + Vector3(cos(ang2), 0, sin(ang2)) * radius
				if not tr.walkable(e2.x, e2.z):
					continue
				var eye2 := Vector3(e2.x, tr.height_at(e2.x, e2.z) + 1.7, e2.z)
				if space2.intersect_ray(PhysicsRayQueryParameters3D.create(eye2, target2)).is_empty():
					wader_eye = e2
					found2 = true
					break
			if found2:
				break
	# A beaver-cut stump on the bank, from a few paces off.
	var beaver := bank
	var beaver_eye := bank
	for c in main.foliage.get_children():
		if c is MultiMeshInstance3D and c.name == "BeaverStumps" and c.multimesh.instance_count > 0:
			beaver = c.multimesh.get_instance_transform(0).origin
			var away := (bank - beaver)
			away.y = 0.0
			# The camera sits a spring-arm behind the Leader, so stand well back.
			beaver_eye = beaver + away.normalized() * 7.0
			break
	var args := OS.get_cmdline_user_args()
	if not "--corps" in args:
		for f in main.corps.values():
			if f != main.leader:
				f.visible = false
				f.process_mode = Node.PROCESS_MODE_DISABLED
	# name, x, z, yaw (0 = north, 90 = west, -90 = east), pitch, hour, storm
	var views := [
		["river_morning", start.x, start.z, 5.0, -6.0, 7.5, 0.0],
		# Facing the Leader (who faces north at the start); with --corps, the Corps behind.
		["portrait", start.x, start.z, 180.0, -4.0, 9.0, 0.0],
		["landing", start.x, start.z, _yaw_to(start, main.get_node("Fleet").get_child(0).global_position if main.has_node("Fleet") else start) , -6.0, 8.5, 0.0],
		["keelboat", quay.x, quay.z, _yaw_to(quay, keel), -4.0, 9.5, 0.0],
		["camp", camp_eye.x, camp_eye.z, _yaw_to(camp_eye, camp), -6.0, 9.0, 0.0],
		["camp_close", camp.x + 5.0, camp.z + 7.0, _yaw_to(camp + Vector3(5, 0, 7), camp), -8.0, 9.5, 0.0],
		["camp_night", camp_eye.x, camp_eye.z, _yaw_to(camp_eye, camp), -4.0, 22.0, 0.0],
		["cottonwoods", grove.x, grove.z, -20.0, -2.0, 10.0, 0.0],
		["sunrise_grove", grove.x, grove.z, -90.0, 4.0, 6.4, 0.0],
		["elk_herd", herd_eye.x, herd_eye.z, _yaw_to(herd_eye, herd), 0.0, 17.5, 0.0, 6.5],
		["riverbank", bank.x, bank.z, bank_yaw, -10.0, 16.0, 0.0],
		["wader", wader_eye.x, wader_eye.z, _yaw_to(wader_eye, wader), -3.0, 10.5, 0.0],
		["beaver", beaver_eye.x, beaver_eye.z, _yaw_to(beaver_eye, beaver), -28.0, 11.0, 0.0, 5.0],
		["bar_willows", thicket_eye.x, thicket_eye.z, _yaw_to(thicket_eye, thicket), -4.0, 15.0, 0.0],
		["prairie_noon", dogs.x, dogs.z, 90.0, -8.0, 13.0, 0.0],
		["hilltop_vista", ridge.x, ridge.z, -60.0, 2.0, 11.0, 0.0],
		["bluff_sunset_east", bluff.x, bluff.z, -90.0, -10.0, 19.2, 0.0],
		["bluff_sunset_west", bluff.x, bluff.z, 100.0, 4.0, 19.2, 0.0],
		["landmark", bluff.x, bluff.z, 0.0, -10.0, 17.0, 0.0],
		["skyward", bluff.x, bluff.z, -60.0, 22.0, 11.0, 0.0],
		["storm", dogs.x, dogs.z, 20.0, -4.0, 15.0, 1.0],
		["lightning", dogs.x, dogs.z, 20.0, 12.0, 15.0, 1.0],
		["night", bluff.x, bluff.z, -90.0, 8.0, 23.0, 0.0],
		["night_sky", bluff.x, bluff.z, 20.0, 30.0, 1.5, 0.0, 2.6],
		["moon", bluff.x, bluff.z, moon_yaw, moon_pitch, 1.5, 0.0, 5.5],
	]
	for a in args:
		if a.begins_with("--only="):
			views = views.filter(func(v): return v[0] == a.substr(7))
	if "--no-glow" in args:
		main.sky.env.glow_enabled = false
	if "--no-grass" in args:
		for n in ["GrassNear", "GrassField", "GrassFar"]:
			main.get_node(n).visible = false
	if "--no-foliage" in args:
		main.foliage.visible = false
	if "--plain-ground" in args:
		var plain := StandardMaterial3D.new()
		plain.vertex_color_use_as_albedo = true
		plain.vertex_color_is_srgb = true
		main.terrain.get_node("Ground").material_override = plain
	if "--no-water" in args:
		main.terrain.get_node("Missouri").visible = false
	if "--no-hills" in args:
		main.terrain.get_node("DistantHills").visible = false
	if "--no-corps" in args:
		main.leader.visible = false
	if "--no-ssao" in args:
		main.sky.env.ssao_enabled = false
	if "--no-ssil" in args:
		main.sky.env.ssil_enabled = false
	if "--no-vfog" in args:
		main.sky.env.volumetric_fog_enabled = false
	if "--no-grass-shadow" in args:
		main.get_node("GrassNear").cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if "--no-far-grass" in args:
		main.get_node("GrassField").visible = false
		main.get_node("GrassFar").visible = false
	for v in views:
		steps.append(["view"] + v)
		steps.append(["wait", 8.0 if "--hold" in args else 2.5])
		if v[0] == "lightning":
			steps.append(["await_bolt", 25.0])  # shoot the instant one falls
		steps.append(["shot", v[0]])
	steps.append(["report"])
	return steps


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
			var to: Vector3 = main.terrain.toward_river(l.global_position.x, l.global_position.z)
			l._yaw = rad_to_deg(atan2(-to.x, -to.z))
			l._pitch = -16.0
			_next()
		"report":
			_report()
			_next()
		"view":
			var l: Leader = main.leader
			var x: float = s[2]
			var z: float = s[3]
			var pos := Vector3(x, main.terrain.height_at(x, z) + 0.3, z)
			l.global_position = pos
			l.velocity = Vector3.ZERO
			l._yaw = s[4]
			l._pitch = s[5]
			l.camera_rig.global_position = pos + Vector3(0, 1.65, 0)
			# A view can ask for a higher eye than a man's; the Leader's own rig is
			# pinned to his head, so those are shot on a free camera instead.
			var eye_height: float = float(s[8]) if s.size() > 8 else 0.0
			if eye_height > 2.0:
				if _free_cam == null:
					_free_cam = Camera3D.new()
					_free_cam.fov = 62.0
					_free_cam.far = 1600.0
					main.add_child(_free_cam)
				_free_cam.global_position = pos + Vector3(0, eye_height, 0)
				_free_cam.rotation = Vector3(deg_to_rad(float(s[5])), deg_to_rad(float(s[4])), 0.0)
				_free_cam.make_current()
				main.sky.follow = _free_cam
			else:
				l.camera.make_current()
				main.sky.follow = l.camera
			l.trail.clear()
			l.trail.append(pos)
			main.state.minute_of_day = int(float(s[6]) * 60.0)
			main._clock = 0.0
			main.sky._storm_target = s[7]
			main.sky.storm = s[7]
			main.sky._storm_hold = 999.0 if s[7] > 0.0 else 0.0
			_log.append("view " + str(s[1]))
			_next()
		"walk_for":
			_wait += delta
			_drive_toward(_point(s[1]), 1.0, delta)
			if _wait >= s[2]:
				_wait = 0.0
				_step += 1  # keep walking into the next step
		"sidecam":
			# A fixed camera 11 m to the side of the trail and a little ahead,
			# looking back at the line as it passes.
			var l: Leader = main.leader
			var fwd := Vector3(l.velocity.x, 0, l.velocity.z).normalized()
			if fwd.length() < 0.1 and s.size() > 1:
				var goal := _point(s[1])
				fwd = Vector3(goal.x - l.global_position.x, 0, goal.z - l.global_position.z).normalized()
			if fwd.length() < 0.1:
				fwd = l.camera_forward()
			var side := fwd.cross(Vector3.UP)
			var eye := l.global_position + side * 11.0 + fwd * 2.0
			eye.y = main.terrain.height_at(eye.x, eye.z) + 1.7
			var cam := Camera3D.new()
			cam.fov = 50.0
			main.add_child(cam)
			var look := l.global_position - fwd * 7.0 + Vector3(0, 1.0, 0)
			cam.look_at_from_position(eye, look, Vector3.UP)
			cam.make_current()
			main.sky.follow = cam
			_next()
		"stores":
			var inv: InventoryScreen = main.inventory
			inv.open = true
			inv.visible = true
			inv._hold = str(s[1])
			inv._build_holds()
			inv._fill()
			_next()
		"council_take":
			main.council_screen._take(str(s[1]))
			_next()
		"council_offer":
			main.council_screen.council.offer(str(s[1]), int(s[2]))
			main.council_screen._refresh()
			_next()
		"await_bolt":
			_wait += delta
			if main.sky._bolt_left > 0.01 or _wait > float(s[1]):
				_wait = 0.0
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


static func _yaw_to(from: Vector3, to: Vector3) -> float:
	## Camera yaw (0 = north, 90 = west) that looks from ``from`` toward ``to``.
	return rad_to_deg(atan2(-(to.x - from.x), -(to.z - from.z)))


func _point(name: String) -> Vector3:
	if name == "herd":
		var herd = main.get_node_or_null("ElkHerd")
		return herd.global_position if herd else main.leader.global_position
	return main.terrain.points[name]


var _route: Array[Vector3] = []
var _route_goal := Vector3.INF


func _drive_toward(goal: Vector3, arrive: float, delta: float) -> bool:
	var l: Leader = main.leader
	var to_goal := Vector2(goal.x - l.global_position.x, goal.z - l.global_position.z)
	if to_goal.length() < arrive:
		_route_goal = Vector3.INF
		return true
	if goal.distance_to(_route_goal) > 3.0:
		_route = main.terrain.find_route(l.global_position, goal)
		_route_goal = goal
	while _route.size() > 1 and Vector2(_route[0].x - l.global_position.x, _route[0].z - l.global_position.z).length() < 5.0:
		_route.pop_front()
	var p: Vector3 = _route[0] if not _route.is_empty() else goal  # no route: head straight
	_debug_t += delta
	if _debug_t > 15.0:
		_debug_t = 0.0
		print("AP t=%.0f pos=(%.0f,%.1f,%.0f) goal=(%.0f,%.0f) wp=(%.0f,%.0f) route=%d stuck=%.1f floor=%s speed=%.1f" % [_t, l.global_position.x, l.global_position.y, l.global_position.z, goal.x, goal.z, p.x, p.z, _route.size(), _stuck_t, l.is_on_floor(), l.ground_speed()])
	var to := Vector2(p.x - l.global_position.x, p.z - l.global_position.z)
	# Face the target; the Leader walks where the camera looks.
	var desired := rad_to_deg(atan2(-to.x, -to.y))
	l._yaw = lerp_angle_deg(l._yaw, desired, clampf(delta * 3.0, 0.0, 1.0))
	l._pitch = lerpf(l._pitch, -10.0, delta)
	Input.action_press("move_forward", 1.0)
	# Unstick: less than half a metre of progress in a second means blocked —
	# sidestep for a moment, then plan a fresh route from here.
	_stuck_t += delta
	if _stuck_t > 1.0:
		if l.global_position.distance_to(_last_pos) < 0.5:
			_blocked += 1
			_route = main.terrain.find_route(l.global_position, goal)
			print("AP blocked at (%.0f,%.0f) — replanned, %d waypoints" % [l.global_position.x, l.global_position.z, _route.size()])
		else:
			_blocked = 0
		_stuck_t = 0.0
		_last_pos = l.global_position
	if _blocked > 0 and fmod(_t, 1.0) < 0.4:
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
	var speeds := []
	for f in main.corps.values():
		speeds.append("%.1f" % f.ground_speed())
	_log.append("%.1fs shot: %s  cam pitch %.1f yaw %.1f  speeds %s  lead %s" % [_t, path.get_file(), main.leader._pitch, main.leader._yaw, " ".join(speeds), main.leader.global_position.snapped(Vector3.ONE * 0.1)])


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
