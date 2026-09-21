class_name Terrain
extends Node3D
## Council Bluff country from real elevation data (USGS 3DEP), compressed from a
## 7 km square to a 1 km game map at half relief, with the Missouri laid on its
## 1804 course under the bluff. Baked by tools/build_heightmap.py.
##
## Game axes: x east, z south (north is -z). One grid cell is 4 m.

const SIZE := 1024.0  # metres
const RES := 256  # cells per side
const WATER_Y := 0.0
## The default terrain data; a Region names its own (see region.gd).
const DATA := "res://data/terrain/council_bluff"

var meta := {}
var _heights := PackedFloat32Array()
var _river := PackedFloat32Array()
var _tint := FastNoiseLite.new()

## Named places other systems look up (Landmarks, Trail Moment spots, the start).
var points := {}


## The Region this terrain carries, and where its data lives.
var region: Region
var data_path := DATA


func _init(p_region: Region = null) -> void:
	_tint.seed = 91
	_tint.frequency = 1.0 / 90.0
	region = p_region
	if region != null and region.terrain_path != "":
		data_path = region.terrain_path
	load_data()


func load_data() -> void:
	meta = JSON.parse_string(FileAccess.get_file_as_string(data_path + ".json"))
	_heights = FileAccess.get_file_as_bytes(data_path + ".height").to_float32_array()
	_river = FileAccess.get_file_as_bytes(data_path + ".river").to_float32_array()
	assert(_heights.size() == (RES + 1) * (RES + 1), "heightmap size mismatch")


func build() -> void:
	define_points()
	var mesh := _build_mesh()
	var mi := MeshInstance3D.new()
	mi.name = "Ground"
	mi.mesh = mesh
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/world/ground.gdshader")
	var camp: Vector3 = points.get("camp", Vector3(-1000, 0, -1000))
	mat.set_shader_parameter("camp", Vector2(camp.x, camp.z))
	var edge: Vector3 = points.get("landing_edge", camp)
	mat.set_shader_parameter("trace_a", Vector2(camp.x, camp.z))
	mat.set_shader_parameter("trace_b", Vector2(edge.x, edge.z))
	var bluff: Vector3 = points.get("council_bluff", edge)
	mat.set_shader_parameter("trace_c", Vector2(bluff.x, bluff.z))
	mi.material_override = mat
	add_child(mi)
	add_child(_build_distant_hills(mat))

	var body := StaticBody3D.new()
	body.name = "GroundBody"
	var shape := CollisionShape3D.new()
	shape.shape = mesh.create_trimesh_shape()
	body.add_child(shape)
	add_child(body)

	add_child(_build_water())


# ------------------------------------------------------------------ sampling


func _grid(arr: PackedFloat32Array, x: float, z: float) -> float:
	var fx := clampf(x / SIZE * RES, 0.0, RES - 0.001)
	var fz := clampf(z / SIZE * RES, 0.0, RES - 0.001)
	var i := int(fx)
	var j := int(fz)
	var tx := fx - i
	var tz := fz - j
	var w := RES + 1
	var a := arr[j * w + i]
	var b := arr[j * w + i + 1]
	var c := arr[(j + 1) * w + i]
	var d := arr[(j + 1) * w + i + 1]
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), tz)


func height_at(x: float, z: float) -> float:
	return _grid(_heights, x, z)


func river_distance(x: float, z: float) -> float:
	return _grid(_river, x, z)


func river_half_width() -> float:
	return float(meta["river_half_width_m"])


func normal_at(x: float, z: float) -> Vector3:
	var e := 2.0
	var n := Vector3(height_at(x - e, z) - height_at(x + e, z), 2.0 * e, height_at(x, z - e) - height_at(x, z + e))
	return n.normalized()


func is_dry(x: float, z: float) -> bool:
	return river_distance(x, z) > river_half_width() + 4.0


func downriver(x: float, z: float) -> Vector3:
	## Horizontal direction the water runs: along the channel, and southward.
	## The same field water.gdshader takes the current from, so a wake on the
	## surface and the streaks in it agree about which way is down.
	var to_water := toward_river(x, z)
	var along := Vector3(-to_water.z, 0.0, to_water.x)
	return align_downstream(along)


func align_downstream(along: Vector3) -> Vector3:
	return along if along.z >= 0.0 else -along


func on_ground(x: float, z: float) -> Vector3:
	## The point on the surface at these map coordinates.
	return Vector3(x, height_at(x, z), z)


func toward_river(x: float, z: float) -> Vector3:
	## Horizontal direction in which the river gets closer.
	var e := 6.0
	var g := Vector3(river_distance(x + e, z) - river_distance(x - e, z), 0.0, river_distance(x, z + e) - river_distance(x, z - e))
	return -g.normalized() if g.length() > 0.0001 else Vector3.FORWARD


const MAX_WALK_SLOPE_DEG := 40.0


func walkable(x: float, z: float) -> bool:
	## Dry, and gentle enough to walk up. Samples the four cells around the point so
	## a diagonal cliff can't slip between grid lines.
	if not is_dry(x, z):
		return false
	var min_ny := cos(deg_to_rad(MAX_WALK_SLOPE_DEG))
	for o in [Vector2(-2, -2), Vector2(2, -2), Vector2(-2, 2), Vector2(2, 2)]:
		if normal_at(x + o.x, z + o.y).y < min_ny:
			return false
	return true


func is_bottomland(x: float, z: float) -> bool:
	return height_at(x, z) < float(meta["floodplain_y"]) + 2.5


# ------------------------------------------------------------------ places


func _search(rect: Rect2, score: Callable) -> Vector3:
	## Best-scoring dry grid point inside ``rect`` (x, z in metres).
	var best := Vector3.ZERO
	var best_score := -INF
	var step := SIZE / RES
	var x := rect.position.x
	while x <= rect.end.x:
		var z := rect.position.y
		while z <= rect.end.y:
			if is_dry(x, z):
				var s: float = score.call(x, z)
				if s > best_score:
					best_score = s
					best = Vector3(x, height_at(x, z), z)
			z += step
		x += step
	return best


func afloat(from: Vector3, to_water: Vector3, inset: float, draught: float) -> Vector3:
	## Walk out from the bank until there is both water enough under the hull and
	## room enough beside it. The second test alone is a planform distance from
	## the middle of the channel, and the channel is wide enough here that it
	## leaves a boat sitting up on a dry bar.
	var p := from
	for i in 400:
		var deep := height_at(p.x, p.z) < WATER_Y - 0.35 - draught
		if deep and river_distance(p.x, p.z) < river_half_width() - inset:
			break
		p += to_water
	return Vector3(p.x, WATER_Y - 0.35, p.z)


func define_points() -> void:
	## Where this Region's named places are. The rules live in its data file, not
	## here, so a new Region costs a heightmap and a JSON file (ADR-0014).
	if region == null:
		region = Region.load_region("council_bluff")
	points = region.resolve_points(self)


func find_route(from: Vector3, goal: Vector3) -> Array[Vector3]:
	## Breadth-first walking route over the 4 m grid, avoiding water and ground steeper than 40°.
	## Returns waypoints ending at ``goal``; empty if there is no way on foot.
	var tr := self
	var n := Terrain.RES + 1
	var cell := Terrain.SIZE / Terrain.RES
	var s := Vector2i(clampi(roundi(from.x / cell), 0, n - 1), clampi(roundi(from.z / cell), 0, n - 1))
	var g := Vector2i(clampi(roundi(goal.x / cell), 0, n - 1), clampi(roundi(goal.z / cell), 0, n - 1))
	var prev := {s: s}
	var queue: Array[Vector2i] = [s]
	var head := 0
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		if c == g:
			break
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nb: Vector2i = c + d
			if nb.x < 0 or nb.y < 0 or nb.x >= n or nb.y >= n or prev.has(nb):
				continue
			var wx := nb.x * cell
			var wz := nb.y * cell
			if not tr.is_dry(wx, wz):
				continue
			if not tr.walkable(wx, wz):
				continue
			prev[nb] = c
			queue.append(nb)
	var route: Array[Vector3] = []
	if not prev.has(g):
		return route
	var c2 := g
	while c2 != s:
		route.push_front(Vector3(c2.x * cell, 0, c2.y * cell))
		c2 = prev[c2]
	# Thin to every third cell; the controller smooths between them.
	var thin: Array[Vector3] = []
	for i in range(0, route.size(), 3):
		thin.append(route[i])
	thin.append(goal)
	return thin


# ------------------------------------------------------------------ mesh


func _color_at(x: float, z: float, h: float, n: Vector3) -> Color:
	var d := river_distance(x, z) - river_half_width()
	var slope := 1.0 - n.y
	var t := _tint.get_noise_2d(x, z) * 0.5 + 0.5
	# August prairie: tawny gold uplands, greener bottomland and swales.
	var grass := Color(0.62, 0.58, 0.30).lerp(Color(0.42, 0.50, 0.24), t * 0.7)
	if is_bottomland(x, z):
		grass = grass.lerp(Color(0.34, 0.46, 0.22), 0.5)
	# Alpha marks prairie, which the ground shader dresses as grass.
	var c := grass
	if d < 0.0:
		c = Color(0.50, 0.43, 0.32, 0.0)  # riverbed: wet sand and silt, seen through the shallows
	elif d < 10.0:
		c = Color(0.76, 0.68, 0.50, 0.0)  # sandbar
	elif d < 22.0:
		c = Color(0.76, 0.68, 0.50, 0.0).lerp(grass, (d - 10.0) / 12.0)
	# Only the steepest cuts show bare loess; the bluffs themselves are grassed.
	if slope > 0.3:
		var loess := Color(0.66, 0.52, 0.34, 0.0)
		c = c.lerp(loess, clampf((slope - 0.3) / 0.2, 0.0, 1.0))
	return c


func _build_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step := SIZE / RES
	for j in RES + 1:
		for i in RES + 1:
			var x := i * step
			var z := j * step
			var h := _heights[j * (RES + 1) + i]
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


var _skirt_noise: FastNoiseLite


func skirt_height(x: float, z: float) -> float:
	## The country beyond the playable kilometre: edge heights carried outward,
	## rising into hazy hills with distance. Inside the map this is height_at.
	if _skirt_noise == null:
		_skirt_noise = FastNoiseLite.new()
		_skirt_noise.seed = 404
		_skirt_noise.frequency = 1.0 / 700.0
	var cx := clampf(x, 0.0, SIZE)
	var cz := clampf(z, 0.0, SIZE)
	var out := Vector2(x - cx, z - cz).length()
	var h := height_at(cx, cz)
	h = lerpf(h, 12.0 + _skirt_noise.get_noise_2d(x, z) * 45.0 + out * 0.012, smoothstep(0.0, 900.0, out))
	if out > 0.0 and out < 1.0:
		h -= 0.4  # meet the playable edge just below it
	return h


func _build_distant_hills(mat: Material) -> MeshInstance3D:
	## Built from skirt_height() on a coarse grid.
	var noise := _skirt_noise if _skirt_noise != null else FastNoiseLite.new()
	noise.seed = 404
	noise.frequency = 1.0 / 700.0
	_skirt_noise = noise
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step := 64.0
	var lo := -2048.0
	var n := int((SIZE - 2.0 * lo) / step) + 1
	var verts: Array[Vector3] = []
	for j in n:
		for i in n:
			var x := lo + i * step
			var z := lo + j * step
			verts.append(Vector3(x, skirt_height(x, z), z))
	for j in n:
		for i in n:
			var v := verts[j * n + i]
			var e := verts[j * n + mini(i + 1, n - 1)] - verts[j * n + maxi(i - 1, 0)]
			var f := verts[mini(j + 1, n - 1) * n + i] - verts[maxi(j - 1, 0) * n + i]
			var nor := f.cross(e).normalized()
			if nor.y < 0.0:
				nor = -nor
			var slope := 1.0 - nor.y
			var c := Color(0.60, 0.56, 0.32).lerp(Color(0.42, 0.48, 0.26), noise.get_noise_2d(v.x * 3.0, v.z * 3.0) * 0.5 + 0.5)
			c = c.lerp(Color(0.62, 0.50, 0.33, 0.0), clampf(slope * 3.0, 0.0, 1.0))
			st.set_color(c)
			st.set_normal(nor)
			st.add_vertex(v)
	for j in n - 1:
		for i in n - 1:
			var a := j * n + i
			var inside := verts[a].x >= 0.0 and verts[a].x + step <= SIZE and verts[a].z >= 0.0 and verts[a].z + step <= SIZE
			if inside:
				continue
			st.add_index(a); st.add_index(a + 1); st.add_index(a + n)
			st.add_index(a + 1); st.add_index(a + n + 1); st.add_index(a + n)
	var mi := MeshInstance3D.new()
	mi.name = "DistantHills"
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _build_water() -> MeshInstance3D:
	## See water.gd: a ring grid centred on the camera, not a plane over the map.
	return Water.build(self)
