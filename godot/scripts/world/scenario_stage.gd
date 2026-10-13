class_name ScenarioStage
extends Node3D
## A Scenario staged in the world rather than in a panel: its cast walk in from
## one named place to another and stand there, and its cues -- guns fired, a
## salute returned -- happen where they happened. The Scenario itself decides
## nothing here (scripts/rules/scenario.gd).

var terrain: Terrain
var leader: Node3D
var cast: Array[Walker] = []
var meet := Vector3.ZERO
var from := Vector3.ZERO
var radius := 14.0


static func stage(scenario: Scenario, p_terrain: Terrain, p_leader: Node3D) -> ScenarioStage:
	var s := ScenarioStage.new()
	s.name = "Stage_" + scenario.id
	s.terrain = p_terrain
	s.leader = p_leader
	var spec: Dictionary = scenario.def.get("stage", {})
	s.from = p_terrain.points[str(spec["from"])]
	s.meet = p_terrain.points[str(spec["to"])]
	s.radius = float(spec.get("radius", 14.0))
	var camp: Vector3 = p_terrain.points.get("camp", s.meet)
	var route := p_terrain.find_route(s.from, s.meet)
	var n := 0
	for part in scenario.def.get("cast", []):
		for i in int(part.get("count", 1)):
			var w := Walker.new()
			var key := str(part["outfit"])
			if key == "messenger":
				key = "messenger_%d" % n
			w.setup(key, str(part["name"]), Color(0.45, 0.36, 0.25), bool(part.get("hat", false)))
			# A loose file coming in, then a loose knot standing, not a column.
			var rng := RandomNumberGenerator.new()
			rng.seed = hash(scenario.id) + n
			var spread := Vector3(rng.randf_range(-4.0, 4.0), 0.0, rng.randf_range(-4.0, 4.0))
			var start := p_terrain.on_ground(s.from.x + spread.x - n * 1.4, s.from.z + spread.z)
			w.position = start + Vector3(0, 0.5, 0)
			w.pace = rng.randf_range(1.9, 2.3)
			for p in route:
				w.route.append(p + spread * 0.5)
			var ring := Vector3.FORWARD.rotated(Vector3.UP, n * 2.4) * (2.0 + 0.45 * n)
			w.route.append(p_terrain.on_ground(s.meet.x + ring.x, s.meet.z + ring.z))
			w.face_toward = camp
			s.add_child(w)
			s.cast.append(w)
			n += 1
	return s


func move_to(point: Vector3, p_radius: float) -> void:
	## Walk the same people on to a new place: from their fire to the council.
	meet = point
	radius = p_radius
	var n := 0
	for w in cast:
		var route := terrain.find_route(w.global_position, point)
		w.route.clear()
		for p in route:
			w.route.append(p)
		# Seated in a half-ring facing the captains under the sail.
		var ring := Vector3.FORWARD.rotated(Vector3.UP, PI * 0.5 + n * (PI / maxf(1.0, cast.size() - 1))) * (4.5 + 0.6 * (n % 2))
		w.route.append(terrain.on_ground(point.x + ring.x, point.z + ring.z))
		w.face_toward = point
		n += 1


func arrived() -> bool:
	for w in cast:
		if not w.arrived():
			return false
	return true


func leader_close() -> bool:
	return leader != null and Vector2(leader.global_position.x - meet.x, leader.global_position.z - meet.z).length() < radius


func play_cues(cues: Array[String]) -> void:
	for cue in cues:
		match cue:
			"their_guns":
				# A ragged feu de joie from the rise as they come in sight.
				for i in 7:
					var p := from + Vector3(randf_range(-9, 9), 0, randf_range(-9, 9))
					_shot(terrain.on_ground(p.x, p.z) + Vector3(0, 1.6, 0), 0.25 + i * randf_range(0.2, 0.55))
			"salute":
				# The swivel gun on the keelboat's bow.
				var bow: Vector3 = terrain.points.get("mooring_0", meet)
				_shot(bow + Vector3(0, 2.0, 0), 0.6, 2.2)


func _shot(at: Vector3, after: float, size := 1.0) -> void:
	## A flash and a round puff of white powder smoke that swells and drifts.
	# A soft billboard, not a ball: a sphere read as a white orb against dusk.
	var puff := Sprite3D.new()
	puff.texture = Props.puff_texture()
	puff.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	puff.shaded = false
	puff.transparent = true
	puff.pixel_size = 0.01
	puff.modulate = Color(0.90, 0.89, 0.86, 0.0)
	puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	puff.position = at
	puff.scale = Vector3.ONE * 0.3 * size
	add_child(puff)
	var flash := OmniLight3D.new()
	flash.light_color = Color(1.0, 0.8, 0.5)
	flash.light_energy = 0.0
	flash.omni_range = 6.0 * size
	flash.position = at
	add_child(flash)
	var tw := create_tween()
	tw.tween_interval(after)
	tw.tween_callback(func():
		puff.modulate.a = 0.8
		flash.light_energy = 6.0)
	tw.tween_property(flash, "light_energy", 0.0, 0.12)
	tw.parallel().tween_property(puff, "scale", Vector3.ONE * 5.5 * size, 4.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.parallel().tween_property(puff, "position", at + Vector3(1.5, 1.2, 0.5) * size, 3.5)
	tw.parallel().tween_property(puff, "modulate:a", 0.0, 3.5).set_ease(Tween.EASE_IN)
	tw.tween_callback(puff.queue_free)
	tw.tween_callback(flash.queue_free)
