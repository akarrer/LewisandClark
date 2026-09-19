class_name Motes
extends GPUParticles3D
## The air close by: seeds, chaff and insects drifting in the light by day,
## fireflies blinking over the bottomland after dark. Anchored to the camera on
## a world grid so they don't swim as you walk, and lit entirely in the shader
## (they are too small to shade).

const SPAN := 34.0  # cube of air around the camera, in metres

var follow: Node3D


func build(terrain: Terrain) -> void:
	name = "Motes"
	amount = 700
	lifetime = 1000.0
	explosiveness = 1.0
	fixed_fps = 0
	local_coords = false
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visibility_aabb = AABB(Vector3(-SPAN, -SPAN, -SPAN), Vector3(SPAN * 2, SPAN * 2, SPAN * 2))

	var pm := ShaderMaterial.new()
	pm.shader = load("res://scripts/world/motes_place.gdshader")
	pm.set_shader_parameter("span", SPAN)
	pm.set_shader_parameter("count", amount)
	# Fireflies keep to the grass, so they never read as stars against the sky.
	pm.set_shader_parameter("height_tex", GrassField._texture(terrain._heights))
	pm.set_shader_parameter("river_tex", GrassField._texture(terrain._river))
	pm.set_shader_parameter("map_size", Terrain.SIZE)
	pm.set_shader_parameter("river_clear", terrain.river_half_width() + 16.0)
	process_material = pm

	var quad := QuadMesh.new()
	quad.size = Vector2(0.05, 0.05)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/world/motes.gdshader")
	quad.material = mat
	draw_pass_1 = quad


func _process(_delta: float) -> void:
	if follow:
		var p := follow.global_position
		global_position = Vector3(snappedf(p.x, 2.0), snappedf(p.y, 2.0), snappedf(p.z, 2.0))
