class_name SkyAndWeather
extends Node3D
## Sun, sky, fog and storms, driven by the Day Clock hour and a storm amount.

var sun := DirectionalLight3D.new()
var env := Environment.new()
var sky_mat := ProceduralSkyMaterial.new()
var storm := 0.0  # 0 clear .. 1 full storm
var _storm_target := 0.0
var _storm_hold := 0.0
var _flash := 0.0
var rain: GPUParticles3D
var follow: Node3D  # rain follows this (the camera)
var _rng := RandomNumberGenerator.new()


func build() -> void:
	sun.name = "Sun"
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 140.0
	add_child(sun)

	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.fog_enabled = true
	env.fog_light_color = Color(0.72, 0.76, 0.80)
	env.fog_density = 0.0009
	env.fog_sky_affect = 0.35
	env.ssao_enabled = false
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	_build_rain()


func start_storm(seconds: float) -> void:
	_storm_target = 1.0
	_storm_hold = seconds


func _build_rain() -> void:
	rain = GPUParticles3D.new()
	rain.name = "Rain"
	rain.amount = 5000
	rain.lifetime = 1.2
	rain.visibility_aabb = AABB(Vector3(-40, -30, -40), Vector3(80, 60, 80))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(35, 1, 35)
	pm.direction = Vector3(0.15, -1, 0)
	pm.spread = 3.0
	pm.initial_velocity_min = 24.0
	pm.initial_velocity_max = 30.0
	pm.gravity = Vector3(0, -9.8, 0)
	rain.process_material = pm
	var streak := QuadMesh.new()
	streak.size = Vector2(0.02, 0.5)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.75, 0.8, 0.9, 0.35)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	streak.material = m
	rain.draw_pass_1 = streak
	rain.emitting = false
	add_child(rain)


func update(hour: float, delta: float) -> void:
	# Storm envelope.
	if _storm_hold > 0.0:
		_storm_hold -= delta
		if _storm_hold <= 0.0:
			_storm_target = 0.0
	storm = move_toward(storm, _storm_target, delta / (10.0 if _storm_target > storm else 18.0))
	rain.emitting = storm > 0.35
	if follow:
		rain.global_position = follow.global_position + Vector3(0, 18, 0)
	_flash = max(0.0, _flash - delta * 3.0)
	if storm > 0.7 and _rng.randf() < delta * 0.18:
		_flash = 1.0

	# Sun path: rises ~5:45, sets ~19:30 in August.
	var day_t := clampf((hour - 5.75) / (19.5 - 5.75), -0.15, 1.15)
	var elevation := sin(day_t * PI)  # -..1
	var pitch := -rad_to_deg(asin(clampf(elevation, -1.0, 1.0))) * 0.95
	# At night the light hangs high (moonlight) instead of pointing up from below.
	sun.rotation_degrees = Vector3(min(pitch, -2.0) if elevation > 0.05 else -38.0, 150.0 - day_t * 120.0, 0.0)
	var low := 1.0 - clampf(elevation * 2.2, 0.0, 1.0)
	var day := clampf(elevation * 4.0 + 0.3, 0.0, 1.0)
	var sun_col := Color(1.0, 0.97, 0.9).lerp(Color(1.0, 0.62, 0.35), low)
	# Below the horizon the "sun" stands in for a cool moonlight, never full dark.
	var moon := Color(0.52, 0.60, 0.85)
	sun.light_color = moon.lerp(sun_col, day).lerp(Color(0.55, 0.62, 0.8), storm * 0.7)
	sun.light_energy = lerpf(0.22, 1.25, day) * (1.0 - storm * 0.75) + _flash * 1.5

	var top_day := Color(0.30, 0.50, 0.80)
	var horizon_day := Color(0.76, 0.80, 0.84)
	var night := Color(0.07, 0.09, 0.18)
	var dusk := Color(0.95, 0.55, 0.35)
	var storm_top := Color(0.22, 0.24, 0.28)
	var storm_hor := Color(0.40, 0.42, 0.45)
	var top := night.lerp(top_day, day)
	var hor := night.lerp(horizon_day.lerp(dusk, low * 0.75), day)
	top = top.lerp(storm_top * max(day, 0.2), storm)
	hor = hor.lerp(storm_hor * max(day, 0.2), storm)
	sky_mat.sky_top_color = top
	sky_mat.sky_horizon_color = hor
	sky_mat.ground_horizon_color = hor
	sky_mat.ground_bottom_color = hor.darkened(0.4)
	sky_mat.sky_energy_multiplier = 1.0 + _flash * 2.0
	env.ambient_light_energy = lerpf(0.45, 1.0, day) * (1.0 - storm * 0.4)
	env.fog_light_color = hor
	env.fog_density = 0.0009 + storm * 0.006
