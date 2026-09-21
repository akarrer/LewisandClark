class_name RiverDrift
extends Node3D
## Driftwood running down the river. Whole cottonwoods come off the cutbanks
## above and ride the current past, half under and turning slowly, each pushing
## a little white water ahead of it.
##
## The journals mention it on nearly every page of this stretch -- "a great
## deal of drift wood running" -- and it is the plainest sign from a bank that
## the river is going somewhere.

const SPEED := 1.35            # m/s: rather slower than the current itself
const UPSTREAM := 200.0        # where a log is put back when it has gone by
const DOWNSTREAM := 170.0      # how far past the Leader it runs before that

var terrain: Terrain
var watch: Node3D

var _logs: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


func build(p_terrain: Terrain, p_watch: Node3D) -> void:
	name = "RiverDrift"
	terrain = p_terrain
	watch = p_watch
	_rng.randomize()
	# How much timber this Region's river carries ("river" in its wildlife data).
	var river: Dictionary = terrain.region.wildlife().get("river", {}) if terrain.region != null else {}
	var wake_mesh := _wake_mesh()
	for i in int(river.get("drift_logs", 0)):
		var node := Node3D.new()
		node.name = "Drift%d" % i
		var timber := MeshInstance3D.new()
		timber.mesh = _log_mesh(_rng)
		# The trunk is built along X; the node's +Z is downstream, and so is the
		# wake quad, so turn the timber to match.
		timber.rotation.y = -PI / 2.0
		timber.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		node.add_child(timber)
		var wake := MeshInstance3D.new()
		wake.name = "Wake"
		wake.mesh = wake_mesh
		wake.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(wake)
		add_child(node)
		var d := {"node": node, "phase": _rng.randf() * TAU, "roll": _rng.randf_range(-0.12, 0.12),
				"speed": SPEED * _rng.randf_range(0.8, 1.25), "sink": _rng.randf_range(0.14, 0.28),
				# Most lie along the current; some come down broadside, as they do.
				"yaw": _rng.randf_range(-0.9, 0.9), "placed": false}
		# Launched here rather than on the first frame, so that anything asking
		# where the drift is at start-up -- the autopilot, for one -- finds it.
		# From the landing, not from the Leader: he may not have been put down
		# yet, and a log launched from the origin lands out on the prairie.
		_launch(d, terrain.points["start"])
		_logs.append(d)


func _process(delta: float) -> void:
	if watch == null:
		return
	var t := Time.get_ticks_msec() / 1000.0
	var here := watch.global_position
	for d in _logs:
		var node: Node3D = d["node"]
		if not bool(d["placed"]):
			_launch(d, here)
			continue
		var down := terrain.downriver(node.position.x, node.position.z)
		node.position += down * float(d["speed"]) * delta
		var p := node.position
		# Recycled when it has run past, or when the channel has carried it out
		# of the water -- the river bends, and a straight drift will beach itself.
		var gone := (p - here).dot(down) > DOWNSTREAM
		if gone or not _in_channel(p):
			_launch(d, here)
			continue
		var ph: float = d["phase"]
		node.position.y = Terrain.WATER_Y - 0.35 - float(d["sink"]) + sin(t * 0.6 + ph) * 0.05
		node.rotation.y = atan2(down.x, down.z) + float(d["yaw"]) + sin(t * 0.09 + ph) * 0.22
		node.rotation.z = sin(t * 0.31 + ph) * 0.09 + float(d["roll"])
		node.rotation.x = sin(t * 0.22 + ph * 1.7) * 0.05


func _launch(d: Dictionary, here: Vector3) -> void:
	## Put the log back up the reach, out of sight behind the Leader, on water
	## deep enough that it is floating rather than aground.
	##
	## Walked up the channel a step at a time rather than laid off in a straight
	## line: the river bends, and two hundred metres of straight line up the
	## reach from here comes out on the far bank.
	var node: Node3D = d["node"]
	# Out onto the channel first. ``here`` is wherever the Leader is, which is
	# almost always the bank, and sweeping across from there only ever finds
	# more bank.
	var p := here
	for i in 40:
		if terrain.river_distance(p.x, p.z) < 5.0:
			break
		p += terrain.toward_river(p.x, p.z) * 6.0
	# Then up the reach a step at a time rather than laid off in a straight line:
	# the river bends, and two hundred metres of straight line comes out on the
	# far bank.
	var back := UPSTREAM * _rng.randf_range(0.5, 1.0)
	var walked := 0.0
	while walked < back:
		p -= terrain.downriver(p.x, p.z) * 8.0
		walked += 8.0
	# And out across the channel, as far as there is water to lie in.
	var down := terrain.downriver(p.x, p.z)
	var across := Vector3(-down.z, 0.0, down.x)
	var want := _rng.randf_range(-1.0, 1.0) * terrain.river_half_width() * 0.7
	var placed := p
	for i in 12:
		if _in_channel(p + across * want):
			placed = p + across * want
			break
		want *= 0.7
	if not _in_channel(placed):
		node.visible = false
		return
	node.position = Vector3(placed.x, Terrain.WATER_Y - 0.35 - float(d["sink"]), placed.z)
	node.visible = true
	d["placed"] = true


func _in_channel(p: Vector3) -> bool:
	return terrain.river_distance(p.x, p.z) < terrain.river_half_width() - 6.0 \
			and terrain.height_at(p.x, p.z) < Terrain.WATER_Y - 0.9


static func _log_mesh(rng: RandomNumberGenerator) -> Mesh:
	## A drowned cottonwood: a long trunk tapering to a broken end, a stub of
	## root at the butt and a branch or two still on it, bleached by the water.
	# Bleached only along the crown, where it has ridden out of the water; the
	# rest of it is wet bark.
	var pale := Color(0.58, 0.54, 0.46)
	var bark := Color(0.26, 0.22, 0.17)
	var length := rng.randf_range(3.0, 6.2)
	var radius := rng.randf_range(0.15, 0.24)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_limb(st, Vector3(-length * 0.5, 0, 0), Vector3(length * 0.5, 0, 0), radius, radius * 0.55, bark, pale)
	for i in rng.randi_range(1, 3):
		var at := rng.randf_range(-0.3, 0.42) * length
		# Mostly out and down. A log riding with its branches in the air looks
		# like a paper dart; what is left on one that has come down a river is
		# broken off short and half in the water.
		var dir := Vector3(rng.randf_range(0.2, 0.8), rng.randf_range(-0.5, 0.25),
				rng.randf_range(-1.0, 1.0)).normalized()
		var limb := rng.randf_range(0.5, 1.2)
		_limb(st, Vector3(at, 0, 0), Vector3(at, 0, 0) + dir * limb, radius * 0.45, radius * 0.12, bark, pale)
	st.generate_normals()
	var mesh := st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 0.92
	mesh.surface_set_material(0, mat)
	return mesh


static func _limb(st: SurfaceTool, a: Vector3, b: Vector3, ra: float, rb: float, bark: Color, pale: Color) -> void:
	## A tapered length of timber from a to b, darker on the underside where it
	## rides in the water and bleached along the top where the sun has had it.
	var axis := (b - a)
	var up := Vector3.UP if absf(axis.normalized().y) < 0.9 else Vector3.FORWARD
	var side := axis.cross(up).normalized()
	var other := axis.cross(side).normalized()
	var faces := 7
	for j in faces:
		var t0 := float(j) / faces * TAU
		var t1 := float(j + 1) / faces * TAU
		var p0 := a + (side * cos(t0) + other * sin(t0)) * ra
		var p1 := a + (side * cos(t1) + other * sin(t1)) * ra
		var q0 := b + (side * cos(t0) + other * sin(t0)) * rb
		var q1 := b + (side * cos(t1) + other * sin(t1)) * rb
		for v in [p0, q0, q1, p0, q1, p1]:
			var top := smoothstep(0.35, 1.0, v.y / maxf(ra, 0.01) * 0.5 + 0.5)
			st.set_color(bark.lerp(pale, top))
			st.add_vertex(v)


static func _wake_mesh() -> Mesh:
	## The little white water a log pushes ahead of itself, on the same shader as
	## the wakes off the snags.
	var quad := PlaneMesh.new()
	quad.size = Vector2(2.6, 6.0)
	quad.orientation = PlaneMesh.FACE_Y
	quad.center_offset = Vector3(0, 0, 3.0)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/world/wake.gdshader")
	mat.set_shader_parameter("strength", 0.34)
	# The river is one huge transparent surface and sorts over these unless told.
	mat.render_priority = 7
	quad.surface_set_material(0, mat)
	return quad
