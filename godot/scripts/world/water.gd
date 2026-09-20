class_name Water
extends MeshInstance3D
## The river surface: a ring grid centred on the camera rather than one flat
## plane over the whole map.
##
## A plane big enough to reach the horizon has to be subdivided for the near
## water, and then spends almost every vertex it has on water a kilometre off.
## Here the spacing grows with the radius, so the swell has four or five
## vertices to a wavelength where it can be seen and almost none where it
## cannot: about 70,000 triangles against the 980,000 a plane needed to look
## the same close up.
##
## Each vertex carries its own ring spacing in UV.x, which is what water.gdshader
## uses to decide how much of the wave train it can draw there.

const SEGMENTS := 192        # around
const NEAR := 0.5            # metres: the innermost ring
const FAR := 2200.0          # far enough to run past the map and the skirt
const GROWTH := 0.045        # each ring is this much wider than the last
const MAX_STEP := 30.0       # ... up to here, so the far rings stay usable

var follow: Node3D


static func build(terrain: Terrain) -> Water:
	var w := Water.new()
	w.name = "Missouri"
	w.mesh = _ring_grid()
	w.position = Vector3(Terrain.SIZE / 2.0, Terrain.WATER_Y - 0.35, Terrain.SIZE / 2.0)
	# The grid moves with the camera, so its bounds cannot be derived from the
	# mesh; give it one big enough to cover wherever it goes.
	w.custom_aabb = AABB(Vector3(-FAR, -40.0, -FAR), Vector3(FAR * 2.0, 80.0, FAR * 2.0))
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/world/water.gdshader")
	mat.set_shader_parameter("river_tex", GrassField._texture(terrain._river))  # the current follows the channel
	mat.set_shader_parameter("map_size", Terrain.SIZE)
	mat.set_shader_parameter("river_half", terrain.river_half_width())
	w.material_override = mat
	w.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return w


func _process(_delta: float) -> void:
	if follow == null:
		return
	# Slide under the camera. The waves are cut from world position, so they stay
	# where they are on the river; only the vertices that draw them move.
	var p := follow.global_position
	global_position = Vector3(p.x, Terrain.WATER_Y - 0.35, p.z)


static func _ring_grid() -> ArrayMesh:
	var radii := PackedFloat32Array()
	var steps := PackedFloat32Array()
	var r := NEAR
	while r < FAR:
		var step := clampf(r * GROWTH, 0.12, MAX_STEP)
		radii.append(r)
		steps.append(step)
		r += step
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# The cap, so there is no hole underfoot when the Leader stands in the river.
	for j in SEGMENTS:
		var a0 := j * TAU / SEGMENTS
		var a1 := (j + 1) * TAU / SEGMENTS
		st.set_uv(Vector2(steps[0], 0.0))
		st.set_normal(Vector3.UP)
		st.add_vertex(Vector3.ZERO)
		st.set_uv(Vector2(steps[0], 0.0))
		st.add_vertex(Vector3(cos(a1) * NEAR, 0.0, sin(a1) * NEAR))
		st.set_uv(Vector2(steps[0], 0.0))
		st.add_vertex(Vector3(cos(a0) * NEAR, 0.0, sin(a0) * NEAR))
	for i in radii.size() - 1:
		var ra: float = radii[i]
		var rb: float = radii[i + 1]
		var sa: float = steps[i]
		var sb: float = steps[i + 1]
		for j in SEGMENTS:
			var a0 := j * TAU / SEGMENTS
			var a1 := (j + 1) * TAU / SEGMENTS
			var p00 := Vector3(cos(a0) * ra, 0.0, sin(a0) * ra)
			var p01 := Vector3(cos(a1) * ra, 0.0, sin(a1) * ra)
			var p10 := Vector3(cos(a0) * rb, 0.0, sin(a0) * rb)
			var p11 := Vector3(cos(a1) * rb, 0.0, sin(a1) * rb)
			# The spacing a vertex carries is the coarser of its ring's radial
			# step and the arc between neighbours, since either can be the limit.
			var ua := maxf(sa, ra * TAU / SEGMENTS)
			var ub := maxf(sb, rb * TAU / SEGMENTS)
			st.set_normal(Vector3.UP)
			for v in [[p00, ua], [p10, ub], [p11, ub], [p00, ua], [p11, ub], [p01, ua]]:
				st.set_uv(Vector2(float(v[1]), 0.0))
				st.add_vertex(v[0])
	return st.commit()
