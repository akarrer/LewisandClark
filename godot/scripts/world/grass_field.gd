class_name GrassField
extends GPUParticles3D
## Dense prairie grass drawn on the GPU in a ring around the camera. The particle
## shader places clumps on a world-anchored grid, so grass doesn't swim as you walk.

const ROWS := 200
const SPACING := 0.5

var follow: Node3D


func build(terrain: Terrain) -> void:
	name = "GrassField"
	amount = ROWS * ROWS
	lifetime = 1000.0
	explosiveness = 1.0
	fixed_fps = 0
	local_coords = false
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var half := ROWS * SPACING * 0.5 + 4.0
	visibility_aabb = AABB(Vector3(-half, -60, -half), Vector3(half * 2, 160, half * 2))

	var pm := ShaderMaterial.new()
	pm.shader = load("res://scripts/world/grass_field.gdshader")
	pm.set_shader_parameter("height_tex", _texture(terrain._heights))
	pm.set_shader_parameter("river_tex", _texture(terrain._river))
	pm.set_shader_parameter("map_size", Terrain.SIZE)
	pm.set_shader_parameter("cell", Terrain.SIZE / Terrain.RES)
	pm.set_shader_parameter("spacing", SPACING)
	pm.set_shader_parameter("rows", ROWS)
	pm.set_shader_parameter("river_clear", terrain.river_half_width() + 14.0)  # keep off the sandbars
	pm.set_shader_parameter("max_dist", ROWS * SPACING * 0.5 - 2.0)
	process_material = pm

	var mesh := clump_mesh()
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/world/grass_blades.gdshader")
	mat.set_shader_parameter("floodplain_y", float(terrain.meta["floodplain_y"]))
	mesh.surface_set_material(0, mat)
	draw_pass_1 = mesh


func _process(_delta: float) -> void:
	if follow:
		var p := follow.global_position
		global_position = Vector3(snappedf(p.x, SPACING), 0.0, snappedf(p.z, SPACING))


static func _texture(data: PackedFloat32Array) -> ImageTexture:
	var n := Terrain.RES + 1
	var img := Image.create_from_data(n, n, false, Image.FORMAT_RF, data.to_byte_array())
	return ImageTexture.create_from_image(img)


static func clump_mesh(blades := 8, seed_value := 3) -> ArrayMesh:
	## A clump of tapered, curved blades. UV.y runs 0 at the root to 1 at the tip.
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for b in blades:
		var ang := rng.randf() * TAU
		var dir := Vector3(cos(ang), 0, sin(ang))
		var side := dir.cross(Vector3.UP)
		var base := Vector3(rng.randf_range(-0.12, 0.12), 0, rng.randf_range(-0.12, 0.12))
		var height := rng.randf_range(0.3, 0.85)
		var lean := rng.randf_range(0.05, 0.35)
		var width := rng.randf_range(0.022, 0.045)
		var segs := 2
		var prev_l := Vector3.ZERO
		var prev_r := Vector3.ZERO
		for s in segs + 1:
			var t := float(s) / segs
			var center := base + Vector3.UP * height * t + dir * lean * t * t
			var w := width * (1.0 - t * 0.92)
			var l := center - side * w
			var r := center + side * w
			if s > 0:
				var t0 := float(s - 1) / segs
				for v in [[prev_l, t0], [prev_r, t0], [l, t], [prev_r, t0], [r, t], [l, t]]:
					st.set_normal(Vector3.UP)
					st.set_uv(Vector2(0.5, v[1]))
					st.add_vertex(v[0])
			prev_l = l
			prev_r = r
	return st.commit()
