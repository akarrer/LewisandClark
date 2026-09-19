class_name GrassField
extends GPUParticles3D
## Dense prairie grass drawn on the GPU in a ring around the camera. The particle
## shader places clumps on a world-anchored grid, so grass doesn't swim as you walk.

## Rings of grass around the camera, finer and fuller near it:
## [name, rows, spacing (m), inner radius (m), blades per clump, blade width, clump scale, casts shadows]
## Only the near ring casts shadows; beyond ~20 m blade shadows are sub-pixel.
const RINGS := [
	["GrassNear", 110, 0.4, 0.0, 12, 1.0, 1.0, true],
	["GrassField", 200, 0.4, 20.0, 6, 1.35, 1.0, false],
	["GrassFar", 216, 0.6, 38.0, 5, 1.8, 1.2, false],
]

var follow: Node3D
var rows := 200
var spacing := 0.4


static func fields(terrain: Terrain, follow_node: Node3D) -> Array[GrassField]:
	var out: Array[GrassField] = []
	for r in RINGS:
		var f := GrassField.new()
		f.rows = r[1]
		f.spacing = r[2]
		f.build(terrain, r[3], r[7], r[4], r[5], r[6])
		f.name = r[0]
		f.follow = follow_node
		out.append(f)
	return out


func build(terrain: Terrain, min_dist := 0.0, shadows := false, blades := 8, widen := 1.0, clump_scale := 1.0) -> void:
	name = "GrassField"
	amount = rows * rows
	lifetime = 1000.0
	explosiveness = 1.0
	fixed_fps = 0
	local_coords = false
	# Blades shade each other and the ground: the difference between a lawn and a prairie.
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var half := rows * spacing * 0.5 + 4.0
	visibility_aabb = AABB(Vector3(-half, -60, -half), Vector3(half * 2, 160, half * 2))

	var pm := ShaderMaterial.new()
	pm.shader = load("res://scripts/world/grass_field.gdshader")
	pm.set_shader_parameter("height_tex", _texture(terrain._heights))
	pm.set_shader_parameter("river_tex", _texture(terrain._river))
	pm.set_shader_parameter("map_size", Terrain.SIZE)
	pm.set_shader_parameter("cell", Terrain.SIZE / Terrain.RES)
	pm.set_shader_parameter("spacing", spacing)
	pm.set_shader_parameter("clump_scale", clump_scale)
	pm.set_shader_parameter("rows", rows)
	pm.set_shader_parameter("river_clear", terrain.river_half_width() + 14.0)  # keep off the sandbars
	pm.set_shader_parameter("max_dist", rows * spacing * 0.5 - 2.0)
	pm.set_shader_parameter("min_dist", min_dist)
	var camp: Vector3 = terrain.points.get("camp", Vector3(-1000, 0, -1000))
	pm.set_shader_parameter("camp", Vector2(camp.x, camp.z))
	var edge: Vector3 = terrain.points.get("landing_edge", camp)
	pm.set_shader_parameter("trace_a", Vector2(camp.x, camp.z))
	pm.set_shader_parameter("trace_b", Vector2(edge.x, edge.z))
	pm.set_shader_parameter("fade_out", r_is_last(min_dist))  # inner rings hand off with a hard edge
	process_material = pm

	# Further rings: fewer, wider blades with the same silhouette.
	var mesh := clump_mesh(blades, 3, widen)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/world/grass_blades.gdshader")
	mat.set_shader_parameter("floodplain_y", float(terrain.meta["floodplain_y"]))
	mesh.surface_set_material(0, mat)
	draw_pass_1 = mesh


func _process(_delta: float) -> void:
	if follow:
		var p := follow.global_position
		global_position = Vector3(snappedf(p.x, spacing), 0.0, snappedf(p.z, spacing))


static func r_is_last(min_dist: float) -> bool:
	return min_dist >= RINGS[-1][3]


static func _texture(data: PackedFloat32Array) -> ImageTexture:
	var n := Terrain.RES + 1
	var img := Image.create_from_data(n, n, false, Image.FORMAT_RF, data.to_byte_array())
	return ImageTexture.create_from_image(img)


static func clump_mesh(blades := 12, seed_value := 3, widen := 1.0) -> ArrayMesh:
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
		var width := rng.randf_range(0.022, 0.045) * widen
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
