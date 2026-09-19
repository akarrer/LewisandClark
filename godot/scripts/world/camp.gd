class_name Camp
extends Node3D
## The Corps' camp above the landing: a fire ring with a kettle on its tripod,
## canvas tents, bedrolls, the cargo put ashore in kegs and crates, a drying rack
## and a woodpile. Built procedurally until the commissioned props (ADR-0008);
## the live night camp of the title screen is this scene at dusk.

const CANVAS := Color(0.80, 0.76, 0.66)
const WOOD := Color(0.48, 0.34, 0.20)
const ROPE := Color(0.42, 0.35, 0.24)
const IRON := Color(0.17, 0.16, 0.15)

var fire_light: OmniLight3D
var _flames: GPUParticles3D
var _rng := RandomNumberGenerator.new()


static func pitch(terrain: Terrain) -> Camp:
	## On dry ground a little back from the water, facing the river.
	var c := Camp.new()
	c.name = "Camp"
	c._rng.seed = 1804
	var here: Vector3 = terrain.points["camp"]
	var to_water := terrain.toward_river(here.x, here.z)
	c.position = here
	c.rotation.y = atan2(-to_water.x, -to_water.z)  # the fire faces the river
	c._build(terrain, here)
	return c


func _build(terrain: Terrain, here: Vector3) -> void:
	_build_fire()
	# Two tents set back from the fire, and bedrolls closer in.
	for i in 2:
		var tent := _tent()
		tent.position = Vector3(-4.5 + i * 9.0, 0, -5.0 - i * 1.2)
		tent.rotation.y = deg_to_rad(_rng.randf_range(-14.0, 14.0)) + (0.25 if i == 0 else -0.25)
		add_child(tent)
	for i in 5:
		var roll := Props.cylinder(0.22, 1.75, CANVAS.darkened(0.15), Vector3.ZERO)
		roll.rotation_degrees = Vector3(0, _rng.randf_range(-20, 20), 90)
		var a := -0.9 + i * 0.45
		roll.position = Vector3(sin(a) * 3.4, 0.2, cos(a) * 3.4)
		add_child(roll)
	# Cargo ashore: kegs and crates stacked clear of the tide line.
	for i in 6:
		var keg := Props.cylinder(0.32, 0.72, WOOD.darkened(0.1), Vector3.ZERO)
		keg.position = Vector3(3.2 + (i % 3) * 0.75, 0.36 + (0.72 if i >= 3 else 0.0), -2.6 + floor(i / 3.0) * 0.1)
		add_child(keg)
		for band in [-0.2, 0.2]:
			var hoop := Props.cylinder(0.335, 0.07, IRON, keg.position + Vector3(0, band, 0))
			add_child(hoop)
	for i in 4:
		var crate := Props.box(Vector3(0.8, 0.55, 0.6), WOOD.lightened(0.05), Vector3(-3.4 - (i % 2) * 0.9, 0.28 + (0.55 if i >= 2 else 0.0), -2.2))
		crate.rotation_degrees.y = _rng.randf_range(-12, 12)
		add_child(crate)
	# A rack of drying meat, and the woodpile.
	add_child(_rack())
	for i in 9:
		var log_ := Props.cylinder(0.09, _rng.randf_range(0.9, 1.3), WOOD.darkened(0.25), Vector3(-1.6 + (i % 3) * 0.2, 0.09 + floor(i / 3.0) * 0.18, 3.6 + (i % 3) * 0.05))
		log_.rotation_degrees = Vector3(0, 90 + _rng.randf_range(-6, 6), 90)
		add_child(log_)


func _build_fire() -> void:
	## A ring of stones, burnt logs, flame and ember particles, and the light they throw.
	for i in 9:
		var a := TAU * i / 9.0
		var stone := Props.box(Vector3(0.26, 0.2, 0.22), Color(0.34, 0.32, 0.30), Vector3(cos(a) * 0.72, 0.08, sin(a) * 0.72))
		stone.rotation_degrees.y = rad_to_deg(a)
		add_child(stone)
	for i in 3:
		var a := TAU * i / 3.0 + 0.4
		var burnt := Props.cylinder(0.075, 1.0, Color(0.16, 0.13, 0.11), Vector3(cos(a) * 0.2, 0.12, sin(a) * 0.2))
		burnt.rotation_degrees = Vector3(72, rad_to_deg(a), 0)
		add_child(burnt)
	# The kettle on its tripod.
	for i in 3:
		var a := TAU * i / 3.0 + 0.9
		var pole := Props.cylinder(0.035, 2.0, WOOD.darkened(0.3), Vector3(cos(a) * 0.62, 0.95, sin(a) * 0.62))
		pole.rotation_degrees = Vector3(rad_to_deg(atan2(0.62, 1.9)) * cos(a), 0, -rad_to_deg(atan2(0.62, 1.9)) * sin(a))
		add_child(pole)
	var kettle := Props.cylinder(0.26, 0.34, IRON.lightened(0.08), Vector3(0, 0.95, 0), 0.22)
	add_child(kettle)
	add_child(Props.cylinder(0.01, 0.75, IRON, Vector3(0, 1.5, 0)))  # the chain

	_flames = GPUParticles3D.new()
	_flames.name = "Flames"
	_flames.amount = 90
	_flames.lifetime = 1.1
	_flames.position = Vector3(0, 0.1, 0)
	_flames.visibility_aabb = AABB(Vector3(-1.5, 0, -1.5), Vector3(3, 4, 3))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.26
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 12.0
	pm.initial_velocity_min = 0.8
	pm.initial_velocity_max = 1.6
	pm.gravity = Vector3(0, 0.7, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.2
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	ramp.colors = PackedColorArray([Color(1.0, 0.85, 0.35, 1.0), Color(1.0, 0.42, 0.10, 0.8), Color(0.25, 0.12, 0.08, 0.0)])
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	pm.color_ramp = ramp_tex
	_flames.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.26, 0.4)
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	fm.vertex_color_use_as_albedo = true
	fm.albedo_color = Color(1.15, 0.8, 0.45)
	fm.disable_receive_shadows = true
	fm.albedo_texture = Props.puff_texture()
	quad.material = fm
	_flames.draw_pass_1 = quad
	add_child(_flames)

	# Smoke drifting up off the fire.
	var smoke := GPUParticles3D.new()
	smoke.name = "Smoke"
	smoke.amount = 26
	smoke.lifetime = 5.0
	smoke.preprocess = 5.0
	smoke.position = Vector3(0, 0.6, 0)
	smoke.visibility_aabb = AABB(Vector3(-3, 0, -3), Vector3(6, 10, 6))
	var sp := ParticleProcessMaterial.new()
	sp.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	sp.emission_sphere_radius = 0.2
	sp.direction = Vector3(0.35, 1, 0.1)
	sp.spread = 14.0
	sp.initial_velocity_min = 0.7
	sp.initial_velocity_max = 1.2
	sp.gravity = Vector3(0.4, 0.25, 0.1)
	sp.scale_min = 0.6
	sp.scale_max = 1.8
	var sramp := Gradient.new()
	sramp.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	sramp.colors = PackedColorArray([Color(0.45, 0.42, 0.40, 0.0), Color(0.5, 0.48, 0.46, 0.22), Color(0.6, 0.6, 0.6, 0.0)])
	var stex := GradientTexture1D.new()
	stex.gradient = sramp
	sp.color_ramp = stex
	smoke.process_material = sp
	var squad := QuadMesh.new()
	squad.size = Vector2(1.1, 1.1)
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	sm.vertex_color_use_as_albedo = true
	sm.albedo_texture = Props.puff_texture()
	squad.material = sm
	smoke.draw_pass_1 = squad
	add_child(smoke)

	fire_light = OmniLight3D.new()
	fire_light.name = "FireLight"
	fire_light.position = Vector3(0, 0.8, 0)
	fire_light.light_color = Color(1.0, 0.62, 0.28)
	fire_light.omni_range = 16.0
	fire_light.light_energy = 3.0
	fire_light.shadow_enabled = true
	add_child(fire_light)


func _process(_delta: float) -> void:
	# The fire breathes: the light flickers with the flames.
	var t := Time.get_ticks_msec() / 1000.0
	fire_light.light_energy = 2.6 + sin(t * 7.3) * 0.5 + sin(t * 2.1) * 0.35


func _tent() -> Node3D:
	## A canvas A-frame over a ridge pole, pegged down.
	var tent := Node3D.new()
	var length := 2.9
	var half := 1.15
	var height := 1.5
	var slant := sqrt(half * half + height * height)
	# Each panel runs from the ridge down to its eave: rotate about X so the
	# panel's +Z lies along (0, -height, ±half).
	var pitch_deg := rad_to_deg(atan2(height, half))
	for side in [-1.0, 1.0]:
		var panel := Props.box(Vector3(length, 0.04, slant), CANVAS, Vector3(0, height * 0.5, side * half * 0.5))
		panel.rotation_degrees.x = pitch_deg if side > 0.0 else 180.0 - pitch_deg
		tent.add_child(panel)
	# The ridge pole lies along the tent (cylinders are built along Y).
	var ridge := Props.cylinder(0.045, length + 0.5, WOOD.darkened(0.2), Vector3(0, height, 0))
	ridge.rotation_degrees.z = 90.0
	tent.add_child(ridge)
	for x in [-1.0, 1.0]:
		tent.add_child(Props.cylinder(0.04, height, WOOD.darkened(0.2), Vector3(x * length * 0.5, height * 0.5, 0)))
		for side in [-1.0, 1.0]:
			var peg := Vector3(x * (length * 0.5 + 0.5), 0.0, side * (half + 0.55))
			tent.add_child(Props.cylinder(0.025, 0.3, WOOD.darkened(0.35), peg + Vector3(0, 0.15, 0)))
			tent.add_child(Camp._guy(Vector3(x * length * 0.5, height + 0.02, 0), peg + Vector3(0, 0.22, 0)))
	return tent


func _rack() -> Node3D:
	## Two forked uprights and a cross pole hung with strips of meat.
	var rack := Node3D.new()
	rack.position = Vector3(5.2, 0, 2.4)
	for x in [-1.0, 1.0]:
		rack.add_child(Props.cylinder(0.05, 1.6, WOOD.darkened(0.2), Vector3(x * 1.1, 0.8, 0)))
	var bar := Props.cylinder(0.04, 2.4, WOOD.darkened(0.2), Vector3(0, 1.55, 0))
	bar.rotation_degrees.z = 90.0
	rack.add_child(bar)
	for i in 7:
		var strip := Props.box(Vector3(0.1, 0.44, 0.02), Color(0.45, 0.19, 0.14), Vector3(-0.9 + i * 0.3, 1.3, 0))
		strip.rotation_degrees.y = _rng.randf_range(-16, 16)
		rack.add_child(strip)
	return rack


static func _guy(a: Vector3, b: Vector3) -> MeshInstance3D:
	var mi := Props.cylinder(0.008, a.distance_to(b), ROPE)
	var dir := (b - a).normalized()
	var up := Vector3.FORWARD if absf(dir.y) > 0.99 else Vector3.UP
	mi.transform = Transform3D(Basis.looking_at(dir, up) * Basis(Vector3.RIGHT, -PI / 2.0), (a + b) / 2.0)
	return mi
