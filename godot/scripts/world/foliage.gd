class_name Foliage
extends Node3D
## Scatters the Quaternius nature models over the terrain with MultiMeshes,
## chunked so each chunk can be culled by distance (grass near, trees far).

const NATURE := "res://assets/third_party/nature/"
const CHUNK := 64.0

var terrain: Terrain
var rng := RandomNumberGenerator.new()

# kind -> {chunk_key -> Array[Transform3D]} per mesh variant
var _buckets := {}
var _meshes := {}


func build(t: Terrain) -> void:
	terrain = t
	rng.seed = 42
	_scatter_cottonwoods()
	_scatter_groves()
	_scatter("bush", ["bush_1", "bush_with_flowers_1"], 1400, 0.8, 1.2, _bush_ok, 260.0)
	_scatter("rock", ["rock_medium_1", "rock_medium_2", "rock_medium_3"], 500, 0.5, 1.3, _rock_ok, 320.0)
	_scatter("grass", ["tall_grass_1", "grass_wispy_1", "grass_wispy_2", "grass_1"], 90000, 0.45, 0.85, _grass_ok, 95.0)
	_scatter("flowers", ["flower_group_1", "flower_single_1", "flower_group_2", "clover_1"], 6000, 0.35, 0.6, _grass_ok, 110.0)
	_flush()


func _mesh(name: String) -> Mesh:
	if not _meshes.has(name):
		var scene: PackedScene = load(NATURE + name + ".glb")
		var inst := scene.instantiate()
		var mi: MeshInstance3D = inst.find_children("*", "MeshInstance3D", true, false)[0]
		_meshes[name] = _summer_leaves(mi.mesh)
		inst.free()
	return _meshes[name]


func _summer_leaves(mesh: Mesh) -> Mesh:
	## The kit's twisted-tree leaves are autumn red; August cottonwoods are green.
	var out: Mesh = null
	for s in mesh.get_surface_count():
		var m := mesh.surface_get_material(s) as BaseMaterial3D
		if m and m.resource_name.begins_with("Leaves_TwistedTree"):
			if out == null:
				out = mesh.duplicate()
			var green := m.duplicate() as BaseMaterial3D
			green.albedo_texture = load(NATURE + "tree_1_Leaves_NormalTree_C.png")
			green.albedo_color = Color(1.0, 1.0, 0.82)
			out.surface_set_material(s, green)
	return out if out != null else mesh


func _add(kind: String, variant: String, pos: Vector3, scale: float, tilt := Vector3.UP, visibility := 0.0) -> void:
	var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * scale)
	if tilt != Vector3.UP:
		basis = Basis(Quaternion(Vector3.UP, tilt.normalized())) * basis
	var key := "%s|%s|%d|%d" % [kind, variant, int(pos.x / CHUNK), int(pos.z / CHUNK)]
	if not _buckets.has(key):
		_buckets[key] = {"variant": variant, "visibility": visibility, "xforms": []}
	_buckets[key]["xforms"].append(Transform3D(basis, pos))


func _flush() -> void:
	for key in _buckets:
		var b: Dictionary = _buckets[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _mesh(b["variant"])
		mm.instance_count = b["xforms"].size()
		for i in mm.instance_count:
			mm.set_instance_transform(i, b["xforms"][i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		if b["visibility"] > 0.0:
			mmi.visibility_range_end = b["visibility"]
			mmi.visibility_range_end_margin = 12.0
			mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		if str(key).begins_with("grass") or str(key).begins_with("flowers"):
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
	_buckets.clear()


func _random_point() -> Vector3:
	var x := rng.randf() * Terrain.SIZE
	var z := rng.randf() * Terrain.SIZE
	return Vector3(x, terrain.height_at(x, z), z)


func _scatter(kind: String, variants: Array, attempts: int, smin: float, smax: float, ok: Callable, visibility: float) -> void:
	for i in attempts:
		var p := _random_point()
		if ok.call(p):
			var n := terrain.normal_at(p.x, p.z)
			_add(kind, variants[rng.randi() % variants.size()], p - Vector3(0, 0.05, 0), rng.randf_range(smin, smax), n, visibility)


func _dist_to_river(p: Vector3) -> float:
	return terrain.river_distance(p.x, p.z) - terrain.river_half_width()


func _in_draw(p: Vector3) -> bool:
	## Wooded ravines cut into the loess uplands: moderately steep, above the bottomland.
	var ny := terrain.normal_at(p.x, p.z).y
	return ny < 0.97 and ny > 0.75 and not terrain.is_bottomland(p.x, p.z)


func _near_point(p: Vector3, radius: float) -> bool:
	for key in terrain.points:
		var q: Vector3 = terrain.points[key]
		if Vector2(p.x - q.x, p.z - q.z).length() < radius:
			return true
	return false


func _grass_ok(p: Vector3) -> bool:
	return _dist_to_river(p) > 14.0 and terrain.normal_at(p.x, p.z).y > 0.8


func _bush_ok(p: Vector3) -> bool:
	var d := _dist_to_river(p)
	return d > 10.0 and (d < 90.0 or _in_draw(p)) and rng.randf() < 0.6 and not _near_point(p, 10.0)


func _rock_ok(p: Vector3) -> bool:
	return _dist_to_river(p) > 8.0 and terrain.normal_at(p.x, p.z).y < 0.93 and not _near_point(p, 8.0)


func _scatter_cottonwoods() -> void:
	## Big cottonwoods crowd the river's edge.
	var variants := ["twisted_tree_1", "twisted_tree_2", "twisted_tree_3", "twisted_tree_4", "twisted_tree_5"]
	for i in 2600:
		var p := _random_point()
		var d := _dist_to_river(p)
		if d < 12.0 or d > 150.0 or _near_point(p, 16.0):
			continue
		if rng.randf() > 1.0 - d / 150.0:
			continue
		_add("cottonwood", variants[rng.randi() % variants.size()], p - Vector3(0, 0.3, 0), rng.randf_range(0.55, 0.95), Vector3.UP, 0.0)


func _scatter_groves() -> void:
	## Groves of smaller trees (bur oak country) in the ravines of the uplands.
	var variants := ["tree_1", "tree_2", "tree_3", "tree_4", "tree_5", "dead_tree_1", "dead_tree_3"]
	for g in 900:
		var p := _random_point()
		if not _in_draw(p) or rng.randf() > 0.55:
			continue
		for i in rng.randi_range(1, 4):
			var x := p.x + rng.randf_range(-12.0, 12.0)
			var zz := p.z + rng.randf_range(-12.0, 12.0)
			p = Vector3(x, terrain.height_at(x, zz), zz)
			if _dist_to_river(p) < 12.0 or _near_point(p, 12.0) or not _in_draw(p):
				continue
			_add("grove", variants[rng.randi() % variants.size()], p - Vector3(0, 0.2, 0), rng.randf_range(0.7, 1.15), Vector3.UP, 0.0)
