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
var _frame_at: Array[float] = []   # when each of those frames ended, for locating hitches
var _skip_frames := 0              # frames a screenshot cost us: ours, not the game's
var _fish_show: RiverLife          # --fish: keep something in the air for the camera
var _fish_t := 0.0
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
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--scenario="):
			# Jump to the Scenario's day and hour, let it choose for itself, walk out
			# to meet its cast, and photograph the evening as it goes.
			var sc := Scenario.load_scenario(a.substr(11))
			var when: Dictionary = sc.def.get("when", {})
			var ymd := str(when.get("date", "1804-08-01")).split("-")
			main.state.current_month = int(ymd[1])
			main.state.current_day = int(ymd[2])
			main.state.minute_of_day = int(float(when.get("after_hour", 12.0)) * 60.0) - 1
			main._today = main._date_key()
			main.scenario_prompt.auto_choose = true
			var meet := str(sc.def.get("stage", {}).get("to", "start"))
			var l: Leader = main.leader
			var from: Vector3 = main.terrain.points.get(str(sc.def.get("stage", {}).get("from", "start")), l.global_position)
			l._yaw = rad_to_deg(atan2(-(from.x - l.global_position.x), -(from.z - l.global_position.z)))
			l._pitch = -4.0
			if sc.def.has("stage"):
				_steps = [["wait", 2.2], ["shot", "opening"], ["wait", 16.0], ["walk_to", meet, 7.0], ["wait", 3.0],
						["shot", "gathered"], ["wait", 30.0], ["shot", "later"], ["wait", 30.0], ["shot", "last"], ["report"]]
				return
			# Unstaged: play the morning, wind on to whatever hour a node waits
			# for, walk to whatever place one waits at, and photograph each.
			_steps = [["wait", 2.5], ["shot", "morning"], ["wait", 12.0]]
			for nid in sc.def["nodes"]:
				var wait := str(sc.def["nodes"][nid].get("wait", ""))
				if wait.begins_with("hour:"):
					_steps.append(["set_hour", float(wait.substr(5)) - 0.05])
					_steps.append(["wait", 5.0])
				elif wait.begins_with("at:"):
					_steps.append(["walk_to", wait.substr(3), 6.0])
					_steps.append(["wait", 7.0])
					_steps.append(["shot", nid])
			_steps.append_array([["wait", 20.0], ["shot", "the_end"], ["report"]])
			return
	if "--slice" in OS.get_cmdline_user_args():
		# The Region's whole content, 1 to 3 August, choosing for itself: the
		# birthday, Floyd's sick call, the Oto coming in, the council, the search
		# for La Liberté, and the badger written up.
		main.scenario_prompt.auto_choose = true
		_steps = [
			["set_hour", 7.9], ["wait", 14.0], ["shot", "aug1_hunters"],
			["set_hour", 18.4], ["wait", 4.0], ["walk_to", "camp", 5.0], ["wait", 14.0], ["shot", "aug1_dinner"],
			["days", 1], ["set_hour", 8.9], ["wait", 12.0], ["shot", "aug2_sick_call"],
			["set_hour", 18.5], ["wait", 6.0], ["walk_to", "oto_meeting", 6.0], ["wait", 30.0], ["shot", "aug2_oto"],
			["days", 1], ["set_hour", 8.4], ["wait", 8.0], ["walk_to", "council_awning", 6.0], ["wait", 60.0],
			["shot", "aug3_council"], ["wait", 75.0],
			["set_hour", 11.9], ["wait", 20.0], ["set_hour", 18.9], ["wait", 16.0], ["shot", "aug3_search"],
			["walk_to", "camp", 4.0], ["wait", 2.0], ["interact"], ["wait", 2.0], ["shot", "aug3_badger"],
			["report"],
		]
		return
	if "--morning-report" in OS.get_cmdline_user_args():
		# The sergeants' report, after however many --days the Corps has lived.
		main.hud.visible = false
		main._open_report()
		_steps = [["wait", 1.0], ["shot", "morning_report"], ["report"]]
		return
	if "--march" in OS.get_cmdline_user_args():
		_steps = _march_steps()
		return
	_steps = [
		["wait", 3.0], ["shot", "start"],
		["walk_to", "bluff_approach", 6.0], ["wait", 7.5], ["shot", "prairie_dogs"],
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
	var steps: Array = [["wait", 2.0], ["walk_for", "bluff_approach", 9.0], ["sidecam"]]
	var frames := 6
	var every := 0.7
	if "--stepoff" in OS.get_cmdline_user_args():
		# From a halt: watch each man step off in his own time.
		steps = [["walk_for", "bluff_approach", 6.0], ["wait", 4.0], ["sidecam", "bluff_approach"], ["shot", "halt"]]
		frames = 8
		every = 0.35
	for i in frames:
		steps.append(["walk_for", "bluff_approach", every])
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
	# A Region names its own places (see region.gd), and only the Slice's first
	# one has all of these. Anything missing falls back to the landing, so the
	# harness still runs against a Region built to prove the data path.
	var here: Vector3 = main.leader.global_position
	var start: Vector3 = tr.points.get("start", here)
	var bluff: Vector3 = tr.points.get("council_bluff", start) + Vector3(0, 0, 8)
	var dogs: Vector3 = tr.points.get("bluff_approach", start)
	var ridge: Vector3 = tr.points.get("smoke_ridge", start)
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
	# Aimed at the moon, at whatever hour of the night it stands highest: it
	# moves now, rising and setting with its phase, so there is no one hour it is
	# always up.
	var st: ExpeditionState = main.state
	var phase := SkyAndWeather.moon_phase_for(st.current_year, st.current_month, st.current_day)
	var moon_hour := 1.5
	var best_el := -90.0
	for q in 41:
		var hh := fposmod(20.0 + q * 0.25, 24.0)
		var mp := SkyAndWeather.moon_position(st.current_month, st.current_day, hh, phase)
		if mp.x > best_el:
			best_el = mp.x
			moon_hour = hh
	var moon_dir := SkyAndWeather.moon_direction(
			SkyAndWeather.moon_position(st.current_month, st.current_day, moon_hour, phase))
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
	var approach: Vector3 = tr.points.get("bluff_approach", start)
	# Stand in the ravine understory itself, looking up the draw.
	var draw_eye := approach
	var draw_at := approach
	for c in main.foliage.get_children():
		if c is MultiMeshInstance3D and c.get_meta("kind", "") == "understory" and c.multimesh.instance_count > 2:
			draw_at = c.multimesh.get_instance_transform(0).origin
			var up_slope: Vector3 = (Vector3(tr.points.get("council_bluff", start)) - draw_at).normalized()
			draw_eye = draw_at - up_slope * 9.0
			draw_eye.y = tr.height_at(draw_eye.x, draw_eye.z)
			break

	# The pelican raft on its bar, from the near bank across the shallows.
	var pelican := bank
	var pelican_eye := bank
	if main.has_node("Wildlife"):
		var raft: Array[Vector3] = []
		for c in main.get_node("Wildlife").get_children():
			if str(c.name).begins_with("Pelican"):
				raft.append(c.position)
		if not raft.is_empty():
			pelican = Vector3.ZERO
			for q in raft:
				pelican += q
			pelican /= raft.size()
			# Stand back off the bar so the whole flock is in frame and none flush.
			var nearest := 1e9
			for k in 36:
				var ang3 := k * TAU / 36.0
				var e3: Vector3 = pelican + Vector3(cos(ang3), 0, sin(ang3)) * 34.0
				if not tr.walkable(e3.x, e3.z):
					continue
				var d3 := e3.distance_to(bank)
				if d3 < nearest:
					nearest = d3
					pelican_eye = e3

	# A log running down the river, from the bank abreast of it.
	var drift := bank
	var drift_eye := bank
	if main.has_node("RiverDrift"):
		for c in main.get_node("RiverDrift").get_children():
			if c is Node3D and (c as Node3D).visible:
				drift = (c as Node3D).position
				# Walk out of the channel from the log itself until there is dry
				# ground to stand on: the drift is launched relative to wherever
				# the Leader started, which is not near this view's bank.
				var eye := drift
				for step in 80:
					eye -= tr.toward_river(eye.x, eye.z) * 4.0
					if tr.height_at(eye.x, eye.z) > Terrain.WATER_Y + 0.25:
						break
				drift_eye = Vector3(eye.x, tr.height_at(eye.x, eye.z), eye.z)
				break

	# A snag standing in the channel, from the bank on the near side of it.
	var snag := bank
	var snag_eye := bank
	for c in main.foliage.get_children():
		if c is MultiMeshInstance3D and c.name == "SnagWakes" and c.multimesh.instance_count > 0:
			# The quad sits downstream of the trunk; back up to the trunk itself.
			var wake_t: Transform3D = c.multimesh.get_instance_transform(0)
			snag = wake_t.origin - wake_t.basis.z * 0.5
			var out := tr.toward_river(bank.x, bank.z)
			snag_eye = snag - out * 26.0
			snag_eye.y = tr.height_at(snag_eye.x, snag_eye.z)
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
		# First light on the water, when the river steams.
		["river_mist", bank.x, bank.z, bank_yaw, -4.0, 6.3, 0.0],
		["wader", wader_eye.x, wader_eye.z, _yaw_to(wader_eye, wader), -3.0, 10.5, 0.0],
		["pelicans", pelican_eye.x, pelican_eye.z, _yaw_to(pelican_eye, pelican), -4.0, 9.0, 0.0],
		["drift", drift_eye.x, drift_eye.z, _yaw_to(drift_eye, drift), -7.0, 12.0, 0.0],
		["snag", snag_eye.x, snag_eye.z, _yaw_to(snag_eye, snag), -6.0, 11.0, 0.0],
		["beaver", beaver_eye.x, beaver_eye.z, _yaw_to(beaver_eye, beaver), -28.0, 11.0, 0.0, 5.0],
		["bar_willows", thicket_eye.x, thicket_eye.z, _yaw_to(thicket_eye, thicket), -4.0, 15.0, 0.0],
		["prairie_noon", dogs.x, dogs.z, 90.0, -8.0, 13.0, 0.0],
		["hilltop_vista", ridge.x, ridge.z, -60.0, 2.0, 11.0, 0.0],
		# Up the wooded draw the Corps used to get off the river onto the bluff.
		["draw", draw_eye.x, draw_eye.z, _yaw_to(draw_eye, draw_at), -4.0, 10.0, 0.0],
		["bluff_sunset_east", bluff.x, bluff.z, -90.0, -10.0, 19.2, 0.0],
		["bluff_sunset_west", bluff.x, bluff.z, 100.0, 4.0, 19.2, 0.0],
		["landmark", bluff.x, bluff.z, 0.0, -10.0, 17.0, 0.0],
		# Inland from the bluff: the Oto village fires standing over the far prairie.
		["village_smoke", bluff.x, bluff.z, 105.0, 1.0, 10.0, 0.0],
		["swallows", bluff.x, bluff.z, _yaw_to(bluff, bluff + tr.toward_river(bluff.x, bluff.z) * 20.0), -18.0, 18.5, 0.0, 3.0],
		["skyward", bluff.x, bluff.z, -60.0, 22.0, 11.0, 0.0],
		["storm", dogs.x, dogs.z, 20.0, -4.0, 15.0, 1.0],
		["lightning", dogs.x, dogs.z, 20.0, 12.0, 15.0, 1.0],
		["night", bluff.x, bluff.z, -90.0, 8.0, 23.0, 0.0],
		["night_sky", bluff.x, bluff.z, 20.0, 30.0, 1.5, 0.0, 2.6],
		["moon", bluff.x, bluff.z, moon_yaw, moon_pitch, moon_hour, 0.0, 5.5],
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
	if "--fish" in args and main.has_node("RiverLife"):
		# Every rise is a jump, and they come often enough that a still catches
		# one in the air rather than waiting on the dice.
		_fish_show = main.get_node("RiverLife") as RiverLife
		_fish_show.jump_chance = 1.0
	if "--map" in args:
		main.map_screen.toggle()         # the sheet open, for a still of it
	if "--glass" in args:
		main.leader.glassing = true      # the spyglass up, for a still of the field
	if "--rifle" in args:
		main.leader.rifle_ready = true
	if "--no-ssr" in args:
		main.sky.env.ssr_enabled = false
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
	if _t > 2.0 and _skip_frames <= 0:
		_frames.append(delta)
		_frame_at.append(_t)
	_skip_frames -= 1
	if _fish_show != null:
		_fish_t -= delta
		if _fish_t <= 0.0:
			_fish_t = 0.35
			_fish_show.rise()
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
		"set_hour":
			main.state.minute_of_day = int(float(s[1]) * 60.0)
			_next()
		"days":
			# Whole days, through the Day Clock, so the Corps lives them.
			main.state.advance_minutes(int(s[1]) * 24 * 60)
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
	# Reading the viewport back and writing a PNG costs over a tenth of a second;
	# that is the harness, not the game, so it must not land in the frame stats.
	# The readback stalls the frame it is on and the one after it.
	_skip_frames = 2
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
	# Where the stutters were, so a hitch can be traced to what was spawning or
	# coming into view at that second rather than guessed at.
	var hitches: Array[String] = []
	for i in _frames.size():
		if _frames[i] > 0.025:
			hitches.append("%.1fs:%.0fms" % [_frame_at[i], _frames[i] * 1000.0])
	if not hitches.is_empty():
		print("hitches (>25ms): %d  %s" % [hitches.size(), " ".join(hitches.slice(0, 40))])
	for line in _log:
		print("  " + line)
	print("JOURNAL")
	for j in main.state.journal:
		print("  " + j)
	get_tree().quit()
