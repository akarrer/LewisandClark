class_name Hoppers
extends GPUParticles3D
## Grasshoppers flushing out of the grass ahead of whoever is walking through it.
## They only fly where there is grass to flush them from, and only when the
## Leader is moving at a pace that would disturb them.

var leader: CorpsFigure
var terrain: Terrain


func build(p_terrain: Terrain, p_leader: CorpsFigure) -> void:
	name = "Hoppers"
	terrain = p_terrain
	leader = p_leader
	amount = 28
	lifetime = 1.4
	local_coords = false
	emitting = false
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visibility_aabb = AABB(Vector3(-8, -2, -8), Vector3(16, 8, 16))

	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(1.1, 0.25, 1.1)
	pm.direction = Vector3(0, 0.75, 1)
	pm.spread = 55.0
	pm.initial_velocity_min = 2.4
	pm.initial_velocity_max = 5.0
	pm.gravity = Vector3(0, -9.0, 0)
	pm.angular_velocity_min = -220.0
	pm.angular_velocity_max = 220.0
	pm.scale_min = 0.7
	pm.scale_max = 1.3
	process_material = pm

	# A speck with a pale flash of hindwing, seen for half a second.
	var body := BoxMesh.new()
	body.size = Vector3(0.05, 0.028, 0.1)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.52, 0.42, 0.20)
	m.roughness = 0.9
	body.material = m
	draw_pass_1 = body


func _process(_delta: float) -> void:
	if leader == null:
		return
	var p := leader.global_position
	# Ahead of the walker, where the grass is: not on the bars, not in the river.
	var ahead := p - leader.global_transform.basis.z * 1.4
	var dry := terrain.river_distance(ahead.x, ahead.z) - terrain.river_half_width() > 18.0
	emitting = leader.ground_speed() > 1.6 and dry and ahead.y > Terrain.WATER_Y + 0.5
	global_position = Vector3(ahead.x, terrain.height_at(ahead.x, ahead.z) + 0.25, ahead.z)
