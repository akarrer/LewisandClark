class_name RiverMist
extends GPUParticles3D
## Mist lying on the river at first light, on the same trick as the fireflies and
## the butterflies: anchored to the camera on a world grid so it drifts past
## rather than swimming with the view.
##
## It is set over the water only, and only while sky.gd says there is mist to
## set: an hour either side of sunrise on a still morning, gone by the time the
## sun is properly up and gone altogether in a wind or a storm.

const SPAN := 70.0   # slab of air around the camera, in metres

var follow: Node3D


func build(terrain: Terrain) -> void:
	name = "RiverMist"
	amount = 120
	lifetime = 1000.0
	explosiveness = 1.0
	fixed_fps = 0
	local_coords = false
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visibility_aabb = AABB(Vector3(-SPAN, -SPAN, -SPAN), Vector3(SPAN * 2, SPAN * 2, SPAN * 2))
	# Behind the fish rings and in front of the water, which is one huge
	# transparent surface and would otherwise sort over the top of it.
	var pm := ShaderMaterial.new()
	pm.shader = load("res://scripts/world/river_mist_place.gdshader")
	pm.set_shader_parameter("span", SPAN)
	pm.set_shader_parameter("height_tex", GrassField._texture(terrain._heights))
	pm.set_shader_parameter("river_tex", GrassField._texture(terrain._river))
	pm.set_shader_parameter("map_size", Terrain.SIZE)
	pm.set_shader_parameter("river_edge", terrain.river_half_width() + 8.0)
	pm.set_shader_parameter("water_y", Terrain.WATER_Y - 0.35)
	process_material = pm

	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)   # the shader sizes each bank itself
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/world/river_mist.gdshader")
	mat.render_priority = 6
	quad.material = mat
	draw_pass_1 = quad


func _process(_delta: float) -> void:
	if follow:
		var p := follow.global_position
		global_position = Vector3(snappedf(p.x, 4.0), Terrain.WATER_Y, snappedf(p.z, 4.0))
