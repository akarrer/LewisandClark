class_name Butterflies
extends GPUParticles3D
## Butterflies over the grass by day, on the same trick as the fireflies: anchored
## to the camera on a world grid so they drift past rather than swimming with the
## view. Nothing is drawn after dark, when the fireflies have the air (motes.gd).

const SPAN := 34.0  # cube of air around the camera, in metres

var follow: Node3D


func build(terrain: Terrain) -> void:
	name = "Butterflies"
	# Sparse on purpose. Seventy of them in a twenty-four metre cube read as a
	# swarm; what you actually see over a prairie is one at a time.
	amount = 26
	lifetime = 1000.0
	explosiveness = 1.0
	fixed_fps = 0
	local_coords = false
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visibility_aabb = AABB(Vector3(-SPAN, -SPAN, -SPAN), Vector3(SPAN * 2, SPAN * 2, SPAN * 2))

	var pm := ShaderMaterial.new()
	pm.shader = load("res://scripts/world/butterflies_place.gdshader")
	pm.set_shader_parameter("span", SPAN)
	pm.set_shader_parameter("height_tex", GrassField._texture(terrain._heights))
	pm.set_shader_parameter("river_tex", GrassField._texture(terrain._river))
	pm.set_shader_parameter("map_size", Terrain.SIZE)
	pm.set_shader_parameter("river_clear", terrain.river_half_width() + 8.0)
	process_material = pm

	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)  # the shader sizes each one by species
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/world/butterflies.gdshader")
	quad.material = mat
	draw_pass_1 = quad


func _process(_delta: float) -> void:
	if follow:
		var p := follow.global_position
		global_position = Vector3(snappedf(p.x, 2.0), snappedf(p.y, 2.0), snappedf(p.z, 2.0))
