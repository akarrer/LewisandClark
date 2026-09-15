class_name Terrain
extends Node3D
## Council Bluff country, about 1 km square: the Missouri winding north through a
## floodplain, loess bluffs rising on the west bank, rolling prairie beyond.
##
## Placeholder shape from noise until the USGS elevation tile replaces
## ``height_at`` (ADR-0007). Everything else — mesh, colours, collision, the
## named points — reads from ``height_at``, so swapping the source is local.

const SIZE := 1024.0  # metres
const RES := 256  # cells per side (4 m)
const WATER_Y := 0.0

var _hills := FastNoiseLite.new()
var _detail := FastNoiseLite.new()
var _bluff_noise := FastNoiseLite.new()
var _tint := FastNoiseLite.new()

## Named places other systems look up (Landmarks, Trail Moment spots, the start).
var points := {}


func _init() -> void:
	_hills.seed = 1804
	_hills.frequency = 1.0 / 320.0
	_detail.seed = 7
	_detail.frequency = 1.0 / 70.0
	_bluff_noise.seed = 33
	_bluff_noise.frequency = 1.0 / 140.0
	_tint.seed = 91
	_tint.frequency = 1.0 / 90.0


func build() -> void:
	_define_points()
	var mesh := _build_mesh()
	var mi := MeshInstance3D.new()
	mi.name = "Ground"
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 1.0
	mi.material_override = mat
	add_child(mi)

	var body := StaticBody3D.new()
	body.name = "GroundBody"
	var shape := CollisionShape3D.new()
	shape.shape = mesh.create_trimesh_shape()
	body.add_child(shape)
	add_child(body)

	add_child(_build_water())


# ------------------------------------------------------------------ shape


func river_x(z: float) -> float:
	return 560.0 + sin(z / 190.0) * 70.0 + sin(z / 61.0) * 14.0


func river_half_width(z: float) -> float:
	return 42.0 + sin(z / 97.0) * 8.0


func bluff_x(z: float) -> float:
	return river_x(z) - 170.0 + _bluff_noise.get_noise_1d(z) * 35.0


func height_at(x: float, z: float) -> float:
	var rx := river_x(z)
	var hw := river_half_width(z)
	var d := absf(x - rx)

	# Rolling prairie.
	var h := 3.0 + _hills.get_noise_2d(x, z) * 7.0 + _detail.get_noise_2d(x, z) * 1.6

	# Floodplain flattens toward the river.
	var plain := clampf((d - hw) / 140.0, 0.0, 1.0)
	h = lerpf(1.2 + _detail.get_noise_2d(x, z) * 0.5, h, smoothstep(0.0, 1.0, plain))

	# The channel.
	if d < hw:
		var k := d / hw
		h = lerpf(-3.2, 0.4, k * k)

	# Loess bluffs on the west bank, taller toward the north (Council Bluff).
	var bx := bluff_x(z)
	if x < bx:
		var rise := smoothstep(0.0, 1.0, clampf((bx - x) / 45.0, 0.0, 1.0))
		var tall := 22.0 + 16.0 * smoothstep(0.55, 0.8, z / SIZE)
		h += rise * (tall + _detail.get_noise_2d(x * 1.7, z * 1.7) * 3.0)

	# A lone ridge out west where smoke can rise.
	var ridge := Vector2(x - 150.0, z - 430.0)
	h += 16.0 * exp(-ridge.length_squared() / (2.0 * 70.0 * 70.0))
	return h


func normal_at(x: float, z: float) -> Vector3:
	var e := 2.0
	var n := Vector3(height_at(x - e, z) - height_at(x + e, z), 2.0 * e, height_at(x, z - e) - height_at(x, z + e))
	return n.normalized()


func is_dry(x: float, z: float) -> bool:
	return absf(x - river_x(z)) > river_half_width(z) + 4.0


func _define_points() -> void:
	var start_z := 90.0
	points["start"] = _on_ground(river_x(start_z) - river_half_width(start_z) - 40.0, start_z)
	var bz := 790.0
	points["council_bluff"] = _on_ground(bluff_x(bz) - 38.0, bz)
	var pz := 420.0
	points["prairie_dog_town"] = _on_ground(river_x(pz) - river_half_width(pz) - 85.0, pz)
	points["smoke_ridge"] = _on_ground(150.0, 430.0)


func _on_ground(x: float, z: float) -> Vector3:
	return Vector3(x, height_at(x, z), z)


# ------------------------------------------------------------------ mesh


func _color_at(x: float, z: float, h: float, n: Vector3) -> Color:
	var d := absf(x - river_x(z)) - river_half_width(z)
	var slope := 1.0 - n.y
	var t := _tint.get_noise_2d(x, z) * 0.5 + 0.5
	# August prairie: tawny gold with greener swales.
	var grass := Color(0.62, 0.58, 0.30).lerp(Color(0.42, 0.50, 0.24), t * 0.7)
	if h < 2.5:
		grass = grass.lerp(Color(0.34, 0.46, 0.22), 0.45)  # greener floodplain
	var c := grass
	if d < 0.0:
		c = Color(0.30, 0.26, 0.20)  # riverbed
	elif d < 10.0:
		c = Color(0.76, 0.68, 0.50)  # sandbar
	elif d < 22.0:
		c = Color(0.76, 0.68, 0.50).lerp(grass, (d - 10.0) / 12.0)
	if slope > 0.28:
		var loess := Color(0.66, 0.52, 0.34)
		c = c.lerp(loess, clampf((slope - 0.28) / 0.25, 0.0, 1.0))
	return c


func _build_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step := SIZE / RES
	for j in RES + 1:
		for i in RES + 1:
			var x := i * step
			var z := j * step
			var h := height_at(x, z)
			var n := normal_at(x, z)
			st.set_color(_color_at(x, z, h, n))
			st.set_normal(n)
			st.add_vertex(Vector3(x, h, z))
	for j in RES:
		for i in RES:
			var a := j * (RES + 1) + i
			var b := a + 1
			var c := a + RES + 1
			var d := c + 1
			st.add_index(a); st.add_index(b); st.add_index(c)
			st.add_index(b); st.add_index(d); st.add_index(c)
	return st.commit()


func _build_water() -> MeshInstance3D:
	var plane := PlaneMesh.new()
	plane.size = Vector2(SIZE, SIZE)
	plane.subdivide_width = 8
	plane.subdivide_depth = 8
	var mi := MeshInstance3D.new()
	mi.name = "Missouri"
	mi.mesh = plane
	mi.position = Vector3(SIZE / 2.0, WATER_Y - 0.35, SIZE / 2.0)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/world/water.gdshader")
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
