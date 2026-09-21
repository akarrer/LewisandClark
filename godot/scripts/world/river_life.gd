class_name RiverLife
extends Node3D
## The river is not still. Fish rise: most only swirl and leave a ring, some roll
## their backs out of the water, and now and then one comes clear of it
## altogether and falls back with a splash. All of it is set where there is open
## water to rise in and in front of the Leader, where he would see it.
##
## The Corps lived off this river. Clark counts catfish by the dozen in a night,
## so it is not empty water they are walking beside.

const RINGS := 14
const FISH := 5
## Seconds between rises, on average: how full of fish this Region's river is
## ("river" in its wildlife data). None there, and nothing rises.
var rise_every := 0.0
## Of a rise: a back breaking the surface, and clear of the water altogether.
## Not constants, so the autopilot can ask for one on demand (--fish).
var roll_chance := 0.3
var jump_chance := 0.14

var terrain: Terrain
var watch: Node3D

var _rings: Array[MeshInstance3D] = []
var _live: Array[Dictionary] = []
var _fish: Array[MeshInstance3D] = []
var _moving: Array[Dictionary] = []
var _splash: GPUParticles3D
var _next := 1.0
var _rng := RandomNumberGenerator.new()


func build(p_terrain: Terrain, p_watch: Node3D) -> void:
	name = "RiverLife"
	terrain = p_terrain
	watch = p_watch
	_rng.randomize()
	var river: Dictionary = terrain.region.wildlife().get("river", {}) if terrain.region != null else {}
	rise_every = float(river.get("fish_rise_every", 0.0))
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(1.0, 1.0)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/world/ring.gdshader")
	# The river is one huge transparent surface and sorts after these unless told.
	mat.render_priority = 8
	mesh.surface_set_material(0, mat)
	for i in RINGS:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.visible = false
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_rings.append(mi)
	# Channel catfish: slate above, pale below, which is all you see of one.
	var fish_mesh := _fish_mesh(0.52, Color(0.24, 0.26, 0.24), Color(0.74, 0.72, 0.62))
	for i in FISH:
		var f := MeshInstance3D.new()
		f.mesh = fish_mesh
		f.visible = false
		add_child(f)
		_fish.append(f)
	_splash = _splash_burst()
	add_child(_splash)


func _process(delta: float) -> void:
	if watch == null or rise_every <= 0.0:
		return
	_next -= delta
	if _next <= 0.0:
		_next = _rng.randf_range(rise_every * 0.4, rise_every * 1.6)
		rise()
	_move_fish(delta)
	for r in _live.duplicate():
		r["age"] = float(r["age"]) + delta
		var life: float = float(r["life"])
		var mi: MeshInstance3D = r["node"]
		if float(r["age"]) >= life:
			mi.visible = false
			_live.erase(r)
			continue
		var t: float = float(r["age"]) / life
		mi.scale = Vector3.ONE * lerpf(0.25, float(r["spread"]), sqrt(t))
		(mi.get_surface_override_material(0) as ShaderMaterial).set_shader_parameter("fade", 1.0 - t)


func rise() -> void:
	## Something comes up under the surface where the Leader can see it.
	# On the water in front of the Leader, near enough to see the ring spread.
	var here := watch.global_position
	var facing := -watch.global_transform.basis.z
	for attempt in 16:
		var a := _rng.randf() * TAU
		var d := _rng.randf_range(5.0, 22.0)
		var p := Vector3(here.x + cos(a) * d, 0, here.z + sin(a) * d)
		if terrain.river_distance(p.x, p.z) > terrain.river_half_width() - 3.0:
			continue  # not open water
		var toward := Vector3(p.x - here.x, 0, p.z - here.z).normalized()
		if toward.dot(Vector3(facing.x, 0, facing.z).normalized()) < 0.1:
			continue  # behind him, where he would not see it rise
		_ring_at(p)
		var kind := _rng.randf()
		if kind < jump_chance:
			_send_fish(p, toward, true)
		elif kind < jump_chance + roll_chance:
			_send_fish(p, toward, false)
		return


func _ring_at(p: Vector3) -> void:
	var free_ring: MeshInstance3D = null
	for mi in _rings:
		if not mi.visible:
			free_ring = mi
			break
	if free_ring == null:
		return
	# Just clear of the surface, or the water sorts in front of it.
	free_ring.position = Vector3(p.x, Terrain.WATER_Y - 0.2, p.z)
	free_ring.visible = true
	var m := (free_ring.mesh as PlaneMesh).surface_get_material(0).duplicate()
	free_ring.set_surface_override_material(0, m)
	_live.append({"node": free_ring, "age": 0.0, "life": _rng.randf_range(2.2, 3.4),
			"spread": _rng.randf_range(2.4, 4.5)})


func _send_fish(p: Vector3, toward: Vector3, jump: bool) -> void:
	## A roll shows the back for a moment and is gone; a jump comes clear of the
	## water, turns over and falls back. Either way the fish travels while it is
	## up, because one that rises straight and drops back reads as a puppet.
	var free_fish: MeshInstance3D = null
	for f in _fish:
		if not f.visible:
			free_fish = f
			break
	if free_fish == null:
		return
	# Off at an angle to the way the Leader is looking, not straight at him.
	var heading := toward.rotated(Vector3.UP, _rng.randf_range(-2.2, 2.2))
	heading.y = 0.0
	heading = heading.normalized()
	free_fish.visible = true
	free_fish.position = Vector3(p.x, Terrain.WATER_Y - 0.5, p.z)
	free_fish.scale = Vector3.ONE * _rng.randf_range(0.8, 1.6)
	_moving.append({
		"node": free_fish, "from": Vector3(p.x, Terrain.WATER_Y - 0.35, p.z),
		"heading": heading, "age": 0.0,
		"life": _rng.randf_range(0.9, 1.25) if jump else _rng.randf_range(0.55, 0.85),
		"reach": _rng.randf_range(1.8, 3.2) if jump else _rng.randf_range(0.7, 1.4),
		"height": _rng.randf_range(0.45, 0.85) if jump else _rng.randf_range(0.05, 0.11),
		"jump": jump, "roll": _rng.randf_range(-2.6, 2.6),
	})


func _move_fish(delta: float) -> void:
	for m in _moving.duplicate():
		var age: float = float(m["age"]) + delta
		m["age"] = age
		var life: float = float(m["life"])
		var n: MeshInstance3D = m["node"]
		var from: Vector3 = m["from"]
		var heading: Vector3 = m["heading"]
		var reach: float = float(m["reach"])
		var height: float = float(m["height"])
		if age >= life:
			n.visible = false
			_moving.erase(m)
			var land := from + heading * reach
			_ring_at(land)
			if bool(m["jump"]):
				_splash.global_position = Vector3(land.x, Terrain.WATER_Y - 0.3, land.z)
				_splash.restart()
			continue
		var t := age / life
		# A parabola over the water, with the body lying along its own path.
		var lift := 4.0 * t * (1.0 - t)
		var pos := from + heading * reach * t
		pos.y = Terrain.WATER_Y - 0.35 + lift * height - 0.1 * (1.0 - lift)
		n.position = pos
		var climb := (1.0 - 2.0 * t) * height * 2.6 / maxf(reach, 0.1)
		n.rotation = Vector3(0.0, atan2(heading.x, heading.z) - PI / 2.0, 0.0)
		n.rotate_object_local(Vector3.FORWARD, atan2(climb, 1.0))
		# A roller shows its back and holds it; a jumper turns over as it goes.
		n.rotate_object_local(Vector3.RIGHT, float(m["roll"]) * (t if bool(m["jump"]) else 1.0))


func _splash_burst() -> GPUParticles3D:
	## The water thrown up where a fish falls back in.
	var p := GPUParticles3D.new()
	p.name = "Splash"
	p.amount = 26
	p.lifetime = 0.9
	p.one_shot = true
	p.emitting = false
	p.explosiveness = 0.95
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-2, -1, -2), Vector3(4, 4, 4))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.12
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 42.0
	pm.initial_velocity_min = 1.4
	pm.initial_velocity_max = 3.0
	pm.gravity = Vector3(0, -9.0, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.2
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	ramp.colors = PackedColorArray([Color(0.92, 0.92, 0.88, 0.9), Color(0.88, 0.87, 0.82, 0.7),
			Color(0.82, 0.80, 0.76, 0.0)])
	var tex := GradientTexture1D.new()
	tex.gradient = ramp
	pm.color_ramp = tex
	p.process_material = pm
	var drop := SphereMesh.new()
	drop.radius = 0.035
	drop.height = 0.07
	drop.radial_segments = 6
	drop.rings = 3
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.90, 0.90, 0.86)
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.35
	drop.material = m
	p.draw_pass_1 = drop
	return p


static func _fish_mesh(length: float, back: Color, belly: Color) -> Mesh:
	## A river fish in profile: deep a third of the way back, tapering to the
	## wrist of the tail, flattened side to side, with a forked tail. Dark on the
	## back and pale underneath, which is the whole of what you see from a bank.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 16
	var around := 10
	var rows: Array = []
	for i in rings + 1:
		var u := float(i) / rings
		var girth := sin(pow(u, 0.7) * PI) * 0.5 + 0.015
		var row: Array = []
		for j in around + 1:
			var a := float(j) / around * TAU
			# Long and round rather than deep: a catfish, not a sunfish.
			row.append(Vector3((u - 0.35) * length, cos(a) * girth * length * 0.34,
					sin(a) * girth * length * 0.26))
		rows.append(row)
	for i in rings:
		for j in around:
			var q := [rows[i][j], rows[i + 1][j], rows[i + 1][j + 1], rows[i][j + 1]]
			for idx in [0, 1, 2, 0, 2, 3]:
				var v: Vector3 = q[idx]
				var shade := back if v.y > 0.0 else back.lerp(belly, clampf(-v.y / (length * 0.09), 0.0, 1.0))
				st.set_color(shade)
				st.add_vertex(v)
	# The tail: two lobes off the wrist, and a low dorsal along the back.
	var wrist := 0.65 * length
	for lobe in [1.0, -1.0]:
		for v in [Vector3(wrist, 0, 0), Vector3(wrist + length * 0.26, float(lobe) * length * 0.15, 0),
				Vector3(wrist + length * 0.12, float(lobe) * length * 0.02, 0)]:
			st.set_color(back.darkened(0.15))
			st.add_vertex(v)
	for v in [Vector3(-length * 0.08, length * 0.055, 0), Vector3(length * 0.12, length * 0.13, 0),
			Vector3(length * 0.2, length * 0.05, 0)]:
		st.set_color(back.darkened(0.1))
		st.add_vertex(v)
	st.generate_normals()
	var mesh := st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 0.28
	mat.metallic = 0.15
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, mat)
	return mesh
