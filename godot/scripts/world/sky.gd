class_name SkyAndWeather
extends Node3D
## Sun, sky, fog and storms, driven by the Day Clock hour and a storm amount.

var sun := DirectionalLight3D.new()
var env := Environment.new()
var sky_mat := ShaderMaterial.new()
var storm := 0.0  # 0 clear .. 1 full storm
var _storm_target := 0.0
var _storm_hold := 0.0
var _flash := 0.0
var rain: GPUParticles3D
var rain_mat: StandardMaterial3D
var _wet := 0.0
## Set from the Day Clock's date (see moon_phase_for / meteors_for).
var moon_phase := 0.6
var meteor_rate := 0.02
var follow: Node3D  # rain follows this (the camera)
var _rng := RandomNumberGenerator.new()

## Time-of-day palette: hour, zenith, horizon, glow, light colour, light energy, ambient.
const KEYS := [
	[0.0, Color(0.02, 0.03, 0.08), Color(0.07, 0.09, 0.17), Color(0.10, 0.12, 0.20), Color(0.55, 0.62, 0.85), 0.32, 0.35],
	[4.6, Color(0.02, 0.03, 0.08), Color(0.07, 0.09, 0.17), Color(0.10, 0.12, 0.20), Color(0.55, 0.62, 0.85), 0.32, 0.35],
	[5.6, Color(0.12, 0.16, 0.32), Color(0.86, 0.52, 0.40), Color(1.00, 0.55, 0.30), Color(1.00, 0.56, 0.32), 0.40, 0.45],
	[7.0, Color(0.28, 0.46, 0.74), Color(0.95, 0.80, 0.66), Color(1.00, 0.75, 0.50), Color(1.00, 0.82, 0.62), 0.95, 0.75],
	[10.0, Color(0.20, 0.42, 0.80), Color(0.68, 0.79, 0.90), Color(1.00, 0.90, 0.75), Color(1.00, 0.97, 0.92), 1.25, 1.00],
	[16.0, Color(0.20, 0.42, 0.80), Color(0.68, 0.79, 0.90), Color(1.00, 0.90, 0.75), Color(1.00, 0.97, 0.92), 1.25, 1.00],
	[18.3, Color(0.25, 0.41, 0.70), Color(0.98, 0.78, 0.55), Color(1.00, 0.62, 0.30), Color(1.00, 0.72, 0.45), 1.00, 0.85],
	[19.5, Color(0.17, 0.21, 0.45), Color(0.98, 0.50, 0.30), Color(1.00, 0.45, 0.20), Color(1.00, 0.50, 0.30), 0.45, 0.55],
	[20.6, Color(0.05, 0.06, 0.16), Color(0.30, 0.20, 0.30), Color(0.50, 0.25, 0.30), Color(0.55, 0.62, 0.85), 0.25, 0.38],
	[24.0, Color(0.02, 0.03, 0.08), Color(0.07, 0.09, 0.17), Color(0.10, 0.12, 0.20), Color(0.55, 0.62, 0.85), 0.32, 0.35],
]


func build() -> void:
	sun.name = "Sun"
	sun.shadow_enabled = true
	# Four cascades out to the far treeline, blended, with a soft penumbra that
	# widens with distance from the caster (the sun's real ~0.5 degree disc).
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 420.0
	sun.directional_shadow_split_1 = 0.04
	sun.directional_shadow_split_2 = 0.12
	sun.directional_shadow_split_3 = 0.35
	sun.directional_shadow_blend_splits = true
	sun.light_angular_distance = 0.5
	sun.shadow_blur = 1.2
	add_child(sun)

	sky_mat.shader = load("res://scripts/world/sky.gdshader")
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.process_mode = Sky.PROCESS_MODE_REALTIME
	sky.radiance_size = Sky.RADIANCE_SIZE_256  # realtime skies only support 256
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.4
	env.fog_enabled = true
	env.fog_density = 0.0006
	env.fog_sky_affect = 0.15
	env.fog_aerial_perspective = 0.4
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.6
	env.ssao_power = 1.4
	# Screen-space reflections: the banks, trees and boats mirrored in the river.
	env.ssr_enabled = true
	env.ssr_max_steps = 96
	env.ssr_fade_in = 0.1
	env.ssr_fade_out = 1.5
	env.ssr_depth_tolerance = 0.4
	# Bounce light: sunlit grass warming the undersides of canopies and bodies.
	env.ssil_enabled = true
	env.ssil_radius = 6.0
	env.ssil_intensity = 1.0
	# Volumetric fog for light shafts through the cottonwoods and morning mist
	# pooling in the bottomland (density driven by the hour in update()).
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.004
	env.volumetric_fog_albedo = Color(0.92, 0.9, 0.86)
	env.volumetric_fog_anisotropy = 0.65
	env.volumetric_fog_length = 180.0
	env.volumetric_fog_detail_spread = 2.0
	env.volumetric_fog_ambient_inject = 0.35
	env.volumetric_fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.08
	env.adjustment_contrast = 1.04
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
	rain.amount = 14000
	rain.lifetime = 1.2
	rain.visibility_aabb = AABB(Vector3(-40, -30, -40), Vector3(80, 60, 80))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(35, 1, 35)
	pm.direction = Vector3(0.5, -1, 0.18)  # driven aslant by the storm wind
	pm.spread = 4.0
	pm.initial_velocity_min = 28.0
	pm.initial_velocity_max = 36.0
	pm.gravity = Vector3(0, -9.8, 0)
	rain.process_material = pm
	var streak := QuadMesh.new()
	streak.size = Vector2(0.008, 0.42)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.75, 0.8, 0.9, 0.18)
	m.proximity_fade_enabled = true  # no fat streaks right in front of the lens
	m.proximity_fade_distance = 5.0
	rain_mat = m
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	streak.material = m
	rain.draw_pass_1 = streak
	rain.emitting = false
	add_child(rain)


static func julian_day(year: int, month: int, day: int) -> float:
	## Julian Day at noon, by the standard civil-calendar formula.
	var y := year
	var m := month
	if m <= 2:
		y -= 1
		m += 12
	var a := int(floor(y / 100.0))
	var b := 2 - a + int(floor(a / 4.0))
	return floor(365.25 * (y + 4716)) + floor(30.6001 * (m + 1)) + day + b - 1524.5


static func moon_phase_for(year: int, month: int, day: int) -> float:
	## 0 and 1 new, 0.5 full. Counted from the new moon of 2000-01-06, which is
	## as true for 1804 as for now: the Corps navigated by these.
	return fposmod((julian_day(year, month, day) - 2451550.1) / 29.530588853, 1.0)


static func meteors_for(month: int, day: int) -> float:
	## Sporadics most nights; the Perseids swell around 12 August.
	var perseid := exp(-pow(float(day) - 12.0, 2.0) / 60.0) if month == 8 else 0.0
	return 0.02 + 0.5 * perseid


static func palette(hour: float) -> Array:
	## Interpolated [zenith, horizon, glow, light colour, light energy, ambient] for ``hour``.
	var h := fposmod(hour, 24.0)
	for i in range(KEYS.size() - 1):
		var a: Array = KEYS[i]
		var b: Array = KEYS[i + 1]
		if h >= a[0] and h <= b[0]:
			var k := smoothstep(0.0, 1.0, (h - a[0]) / max(b[0] - a[0], 0.001))
			return [a[1].lerp(b[1], k), a[2].lerp(b[2], k), a[3].lerp(b[3], k), a[4].lerp(b[4], k), lerpf(a[5], b[5], k), lerpf(a[6], b[6], k)]
	return [KEYS[0][1], KEYS[0][2], KEYS[0][3], KEYS[0][4], KEYS[0][5], KEYS[0][6]]


func update(hour: float, delta: float) -> void:
	# Storm envelope.
	if _storm_hold > 0.0:
		_storm_hold -= delta
		if _storm_hold <= 0.0:
			_storm_target = 0.0
	storm = move_toward(storm, _storm_target, delta / (10.0 if _storm_target > storm else 18.0))
	rain.emitting = storm > 0.25
	rain.amount_ratio = clampf(storm * 1.3, 0.0, 1.0)
	if follow:
		rain.global_position = follow.global_position + Vector3(0, 18, 0)
	_flash = max(0.0, _flash - delta * 3.0)
	if storm > 0.7 and _rng.randf() < delta * 0.18:
		_flash = 1.0

	# Sun path: rises ~5:45, sets ~19:30 in August. At night the light becomes the moon, high in the south-east.
	var day_t := clampf((hour - 5.75) / (19.5 - 5.75), -0.15, 1.15)
	var elevation := sin(day_t * PI)
	var is_day := elevation > 0.02
	var pitch := -rad_to_deg(asin(clampf(elevation, -1.0, 1.0))) * 0.95
	sun.rotation_degrees = Vector3(min(pitch, -1.5) if is_day else -40.0, 150.0 - day_t * 120.0 if is_day else 35.0, 0.0)

	var p := palette(hour)
	var zenith: Color = p[0]
	var horizon: Color = p[1]
	var glow: Color = p[2]
	var light_col: Color = p[3]
	var grey := Color(0.36, 0.38, 0.42)
	zenith = zenith.lerp(grey * 0.8 * (0.3 + 0.7 * p[5]), storm * 0.85)
	horizon = horizon.lerp(grey * (0.3 + 0.7 * p[5]), storm * 0.85)
	var night := 1.0 - smoothstep(0.36, 0.8, p[5])  # full night when ambient is at its floor

	sun.light_color = light_col.lerp(Color(0.6, 0.65, 0.75), storm * 0.6)
	sun.light_energy = p[4] * (1.0 - storm * 0.7) + _flash * 1.8
	sun.shadow_opacity = 1.0 - storm * 0.6

	sky_mat.set_shader_parameter("zenith_color", zenith)
	sky_mat.set_shader_parameter("horizon_color", horizon.lerp(Color.WHITE, _flash * 0.5))
	sky_mat.set_shader_parameter("ground_color", horizon.darkened(0.55))
	sky_mat.set_shader_parameter("glow_color", glow)
	sky_mat.set_shader_parameter("glow_amount", 0.55 if is_day else 0.0)
	sky_mat.set_shader_parameter("sun_color", light_col if is_day else Color.BLACK)
	sky_mat.set_shader_parameter("cloud_darkness", storm)
	sky_mat.set_shader_parameter("cloud_light", Color(1.0, 0.98, 0.95).lerp(glow, 0.35).lerp(Color(0.16, 0.18, 0.26), night))
	sky_mat.set_shader_parameter("cloud_shadow", horizon.lerp(zenith, 0.5).darkened(0.25).lerp(Color(0.04, 0.05, 0.09), night))
	sky_mat.set_shader_parameter("cloud_coverage", lerpf(lerpf(0.42, 0.3, night), 1.0, storm))
	sky_mat.set_shader_parameter("star_amount", night * (1.0 - storm))
	sky_mat.set_shader_parameter("moon_amount", night * (1.0 - storm))
	sky_mat.set_shader_parameter("moon_dir", sun.global_transform.basis.z)
	sky_mat.set_shader_parameter("moon_phase", moon_phase)
	sky_mat.set_shader_parameter("meteor_rate", meteor_rate * night * (1.0 - storm))

	# Rain takes the colour of the sky behind it rather than glowing white.
	var rc := horizon.lerp(Color(0.8, 0.84, 0.9), 0.35).lerp(Color.WHITE, _flash * 0.6)
	rain_mat.albedo_color = Color(rc, 0.1 + storm * 0.22)
	# Sky colour for materials that fake reflections (the river's sheen); see [shader_globals].
	# Cloud shadows on the land (cloud_shadow.gdshaderinc): gone at night, and under
	# a full overcast the whole land is already in shade.
	var coverage := lerpf(lerpf(0.42, 0.3, night), 1.0, storm)
	# Wind the plants lean into: a breathing prairie breeze, half a gale in a storm.
	var gust := 1.0 + 0.35 * sin(Time.get_ticks_msec() / 1000.0 * 0.11) + storm * 2.6
	RenderingServer.global_shader_parameter_set("night_amount", night)
	RenderingServer.global_shader_parameter_set("wind_strength", gust)
	# Ground and plants darken and gleam as the rain soaks in, drying slowly after.
	_wet = move_toward(_wet, clampf(storm * 1.4, 0.0, 1.0), delta / (4.0 if storm > 0.3 else 90.0))
	RenderingServer.global_shader_parameter_set("wetness", _wet)
	RenderingServer.global_shader_parameter_set("cloud_cover", coverage)
	RenderingServer.global_shader_parameter_set("sun_dir", sun.global_transform.basis.z)
	RenderingServer.global_shader_parameter_set("cloud_shadow_strength", 0.55 * smoothstep(0.02, 0.2, elevation) * (1.0 - smoothstep(0.3, 0.8, storm)))
	RenderingServer.global_shader_parameter_set("sky_horizon", horizon.lerp(zenith, 0.3))
	# A storm drains the colour out of the land and flattens it.
	env.tonemap_exposure = 1.05 - storm * 0.18
	# Moonlight drains colour (scotopic vision), so warm grass doesn't glow olive at night.
	env.adjustment_saturation = lerpf(lerpf(1.08, 0.72, storm), 0.5, night)
	env.ambient_light_energy = p[5] * (1.0 - storm * 0.35)
	env.fog_light_color = horizon
	env.fog_density = 0.0006 + storm * 0.006
	# Morning haze pooling in the bottomland.
	var haze := clampf(1.0 - absf(hour - 6.8) / 2.2, 0.0, 1.0)
	env.fog_height = 3.0
	env.fog_height_density = 0.04 * haze
	# Air thick enough to show shafts at the low sun, clearing through the day.
	var low_sun := 1.0 - smoothstep(0.1, 0.45, elevation) if is_day else 0.3
	env.volumetric_fog_density = 0.0012 + 0.004 * low_sun + 0.006 * haze + storm * 0.012
