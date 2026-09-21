class_name Dust
extends GPUParticles3D
## Dust off dry ground under a boot: on the sandbars and the worn paths, where
## there is no sod to hold it down. Nothing rises off the prairie itself.

var leader: CorpsFigure
var terrain: Terrain


func build(p_terrain: Terrain, p_leader: CorpsFigure) -> void:
	name = "Dust"
	terrain = p_terrain
	leader = p_leader
	amount = 30
	lifetime = 1.6
	local_coords = false
	emitting = false
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visibility_aabb = AABB(Vector3(-6, -1, -6), Vector3(12, 6, 12))

	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.22
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 40.0
	pm.initial_velocity_min = 0.2
	pm.initial_velocity_max = 0.7
	pm.gravity = Vector3(0.25, 0.1, 0.1)   # it drifts off downwind rather than falling
	pm.damping_min = 0.4
	pm.damping_max = 0.9
	pm.scale_min = 0.6
	pm.scale_max = 1.6
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
	ramp.colors = PackedColorArray([Color(0.72, 0.64, 0.50, 0.0), Color(0.74, 0.66, 0.52, 0.30),
			Color(0.78, 0.72, 0.60, 0.0)])
	var tex := GradientTexture1D.new()
	tex.gradient = ramp
	pm.color_ramp = tex
	process_material = pm

	var puff := QuadMesh.new()
	puff.size = Vector2(0.5, 0.5)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = Props.puff_texture()
	m.disable_receive_shadows = true
	puff.material = m
	draw_pass_1 = puff


func _process(_delta: float) -> void:
	if leader == null:
		return
	var p := leader.global_position
	# Bare ground: the bars by the river, or the ways worn between the places.
	var by_river := terrain.river_distance(p.x, p.z) - terrain.river_half_width() < 26.0
	var above_water := p.y > Terrain.WATER_Y + 0.2
	emitting = leader.ground_speed() > 2.2 and by_river and above_water
	global_position = Vector3(p.x, terrain.height_at(p.x, p.z) + 0.1, p.z)
