class_name Foliage
extends Node3D
## Scatters the Quaternius nature models over the terrain with MultiMeshes,
## chunked so each chunk can be culled by distance (grass near, trees far).

const NATURE := "res://assets/third_party/nature/"
const CHUNK := 64.0
## Thin scatters -- flowers, rocks, bushes, driftwood, the ravine understory --
## batch over a much coarser grid than the grass. At 64 m a scatter of a thousand
## things over the map lands one or two instances in each of a thousand
## MultiMeshes, which is a thousand draw calls to draw almost nothing.
const COARSE_CHUNK := 256.0
const FLOWER_RANGE := 130.0

var terrain: Terrain
var rng := RandomNumberGenerator.new()

# kind -> {chunk_key -> Array[Transform3D]} per mesh variant
var _buckets := {}
var _meshes := {}
var _groves := FastNoiseLite.new()

## Wind and look per kind: sway (m at the top), flutter, translucency, tint, colour variation.
const PROFILES := {
	"cottonwood": {"sway": 0.35, "flutter": 1.0, "translucency": 0.45, "tint": Color(0.98, 1.0, 0.80), "variation": 0.14},
	"grove": {"sway": 0.22, "flutter": 0.8, "translucency": 0.35, "tint": Color(0.86, 0.95, 0.78), "variation": 0.12},
	"bush": {"sway": 0.08, "flutter": 0.6, "translucency": 0.35, "tint": Color(0.92, 1.0, 0.82), "variation": 0.16},
	# The kit's grass models are spring green. On the uplands in August the prairie
	# has cured to straw; only the swales and the river bottom hold their colour.
	# ``cured`` is what a fully burnt-off clump is multiplied by, blended per
	# instance, so the whole field is still one material and one draw call.
	"grass": {"sway": 0.14, "flutter": 0.3, "translucency": 0.4, "tint": Color(0.74, 0.85, 0.60),
		"cured": Color(1.46, 1.22, 0.86), "variation": 0.2},
	"flowers": {"sway": 0.10, "flutter": 0.3, "translucency": 0.3, "tint": Color(1, 1, 1), "variation": 0.1},
	"willow": {"sway": 0.18, "flutter": 1.3, "translucency": 0.45, "tint": Color(0.82, 0.95, 0.78), "variation": 0.12},
	"driftwood": {"sway": 0.0, "flutter": 0.0, "translucency": 0.0, "tint": Color(1, 1, 1), "variation": 0.08, "bark_tint": Color(2.1, 2.0, 1.85)},
	"rock": {},
	# The wooded ravines that cut the loess bluffs: shaded, damper, and green well
	# into August when the open prairie above them has gone to straw.
	"understory": {"sway": 0.10, "flutter": 0.5, "translucency": 0.5, "tint": Color(0.80, 0.98, 0.70), "variation": 0.16},
	"fungus": {"sway": 0.0, "flutter": 0.0, "translucency": 0.0, "tint": Color(1.05, 0.98, 0.9), "variation": 0.12},
	# Wildflower stands. Every flower in the kit shares one atlas, so the model
	# chosen decides the colour and these tints only nudge it: the yellow models
	# toward gold rather than orange, the purple ones a shade cooler.
	"sunflower": {"sway": 0.19, "flutter": 0.3, "translucency": 0.12, "tint": Color(0.86, 1.02, 1.30), "variation": 0.16},
	"coneflower": {"sway": 0.13, "flutter": 0.3, "translucency": 0.32, "tint": Color(1.00, 0.92, 1.10), "variation": 0.18},
	"goldenrod": {"sway": 0.17, "flutter": 0.4, "translucency": 0.25, "tint": Color(1.38, 1.26, 0.58), "variation": 0.15},
	"yarrow": {"sway": 0.09, "flutter": 0.25, "translucency": 0.3, "tint": Color(1.22, 1.20, 1.12), "variation": 0.10},
}

## The flowers of this reach in high summer, in stands of one kind rather than
## mixed evenly through the grass — sunflowers down in the bottoms, purple
## coneflower and blazing star on the dry upland, goldenrod coming on in the
## draws, yarrow underfoot everywhere. Lewis pressed all of them that season.
## ``low`` keeps a species to the bottomland; false keeps it to the upland.
const WILDFLOWERS := [
	{"kind": "sunflower", "variants": ["flower_group_2", "flower_single_2", "flower_petal_3"], "seed": 311,
		"freq": 1.0 / 30.0, "threshold": 0.32, "tries": 26000, "smin": 0.45, "smax": 0.8,
		"stretch": Vector3(1.0, 1.45, 1.0), "low": true},
	{"kind": "coneflower", "variants": ["flower_petal_2", "flower_petal_4"], "seed": 512,
		"freq": 1.0 / 22.0, "threshold": 0.36, "tries": 24000, "smin": 0.3, "smax": 0.55,
		"stretch": Vector3(1.0, 1.2, 1.0), "low": false},
	{"kind": "goldenrod", "variants": ["plant_1", "plant_2"], "seed": 733,
		"freq": 1.0 / 34.0, "threshold": 0.34, "tries": 20000, "smin": 0.35, "smax": 0.7,
		"stretch": Vector3(0.85, 1.7, 0.85), "low": false},
	{"kind": "yarrow", "variants": ["flower_petal_1", "clover_1"], "seed": 947,
		"freq": 1.0 / 18.0, "threshold": 0.28, "tries": 26000, "smin": 0.3, "smax": 0.5,
		"stretch": Vector3(1.0, 1.0, 1.0), "low": true},
]


func build(t: Terrain) -> void:
	terrain = t
	rng.seed = 42
	_groves.seed = 77
	_groves.frequency = 1.0 / 90.0
	_scatter_cottonwoods()
	_scatter_groves()
	_scatter_driftwood()
	_scatter_sandbar()
	_scatter_far_country()
	_scatter_beaver_sign()
	_scatter_draw_understory()
	_scatter("bush", ["bush_1", "bush_with_flowers_1"], 1400, 0.8, 1.2, _bush_ok, 260.0, 0.25)
	# Loess country has few stones: an occasional weathered boulder, mostly in the draws.
	_scatter("rock", ["rock_medium_1", "rock_medium_2", "rock_medium_3"], 220, 0.4, 1.0, _rock_ok, 320.0, 0.55)
	# The GPU grass field carries the prairie; these taller clumps and flowers are accents.
	_scatter_grass_clumps()
	_scatter("flowers", ["flower_group_1", "flower_single_1", "flower_group_2", "clover_1"], 5200, 0.35, 0.6, _flower_ok, 70.0)
	_scatter_wildflowers()
	_flush()


func _mesh(name: String, kind: String) -> Mesh:
	var key := name + "|" + kind
	if not _meshes.has(key):
		var scene: PackedScene = load(NATURE + name + ".glb")
		var inst := scene.instantiate()
		var mi: MeshInstance3D = inst.find_children("*", "MeshInstance3D", true, false)[0]
		_meshes[key] = _with_wind(_summer_leaves(mi.mesh), PROFILES.get(kind, {}))
		inst.free()
	return _meshes[key]


func _with_wind(mesh: Mesh, profile: Dictionary) -> Mesh:
	## Swap each textured surface's material for the wind shader, keeping its texture.
	if profile.is_empty():
		return mesh
	var out: Mesh = mesh.duplicate()
	var height := maxf(mesh.get_aabb().end.y, 0.5)
	for s in out.get_surface_count():
		var m := out.surface_get_material(s) as BaseMaterial3D
		if m == null or m.albedo_texture == null:
			continue
		var bark := m.resource_name.to_lower().contains("bark")
		var sm := ShaderMaterial.new()
		sm.shader = preload("res://scripts/world/foliage.gdshader")
		sm.set_shader_parameter("albedo_tex", m.albedo_texture)
		sm.set_shader_parameter("tint", profile.get("bark_tint", Color(1.25, 1.18, 1.1)) if bark else (m.albedo_color * profile["tint"]))
		sm.set_shader_parameter("sway", profile["sway"])
		sm.set_shader_parameter("plant_height", height)
		sm.set_shader_parameter("flutter", 0.0 if bark else profile["flutter"])
		sm.set_shader_parameter("translucency", 0.0 if bark else profile["translucency"])
		sm.set_shader_parameter("variation", 0.04 if bark else profile["variation"])
		sm.set_shader_parameter("alpha_cut", 0.0 if bark else 0.5)
		sm.set_shader_parameter("bark", 1.0 if bark else 0.0)
		sm.set_shader_parameter("cured", Color(1, 1, 1) if bark else profile.get("cured", Color(1, 1, 1)))
		out.surface_set_material(s, sm)
	return out


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


func _add(kind: String, variant: String, pos: Vector3, scale: float, tilt := Vector3.UP, visibility := 0.0, stretch := Vector3.ONE, chunk := CHUNK, cure := -1.0) -> void:
	var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(stretch * scale)
	if tilt != Vector3.UP:
		basis = Basis(Quaternion(Vector3.UP, tilt.normalized())) * basis
	var key := "%s|%s|%d|%d" % [kind, variant, int(pos.x / chunk), int(pos.z / chunk)]
	if not _buckets.has(key):
		_buckets[key] = {"variant": variant, "kind": kind, "visibility": visibility, "xforms": [], "cures": []}
	_buckets[key]["xforms"].append(Transform3D(basis, pos))
	if cure >= 0.0:
		_buckets[key]["cures"].append(cure)


func _flush() -> void:
	var tally := {}
	for key in _buckets:
		var b: Dictionary = _buckets[key]
		tally[b["kind"]] = int(tally.get(b["kind"], 0)) + b["xforms"].size()
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		var cures: Array = b["cures"]
		mm.use_colors = cures.size() == b["xforms"].size()
		mm.mesh = _mesh(b["variant"], b["kind"])
		mm.instance_count = b["xforms"].size()
		for i in mm.instance_count:
			mm.set_instance_transform(i, b["xforms"][i])
			if mm.use_colors:
				mm.set_instance_color(i, Color(cures[i], 0.0, 0.0, 1.0))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.set_meta("kind", b["kind"])
		if b["visibility"] > 0.0:
			mmi.visibility_range_end = b["visibility"]
			mmi.visibility_range_end_margin = 12.0
			mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		if str(key).begins_with("grass") or str(key).begins_with("flowers") 				or str(key).begins_with("yarrow") or str(key).begins_with("coneflower") 				or str(key).begins_with("sunflower") or str(key).begins_with("goldenrod") 				or str(key).begins_with("fungus"):
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
	if OS.is_stdout_verbose():
		print("foliage: %s in %d multimeshes" % [tally, _buckets.size()])
	_buckets.clear()


func _random_point() -> Vector3:
	var x := rng.randf() * Terrain.SIZE
	var z := rng.randf() * Terrain.SIZE
	return Vector3(x, terrain.height_at(x, z), z)


func _scatter(kind: String, variants: Array, attempts: int, smin: float, smax: float, ok: Callable, visibility: float, sink := 0.05, chunk := COARSE_CHUNK) -> void:
	for i in attempts:
		var p := _random_point()
		if ok.call(p):
			var n := terrain.normal_at(p.x, p.z)
			var scale := rng.randf_range(smin, smax)
			# Tilting to the slope lifts a model off its base, so bed it in by its size.
			_add(kind, variants[rng.randi() % variants.size()], p - Vector3(0, sink * scale, 0), scale, n, visibility,
					Vector3.ONE, chunk)


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


func _flower_ok(p: Vector3) -> bool:
	## Wildflowers drift in patches rather than evenly.
	return _grass_ok(p) and _groves.get_noise_2d(p.x * 2.3 + 500.0, p.z * 2.3) > 0.15


func _grass_ok(p: Vector3) -> bool:
	return _dist_to_river(p) > 14.0 and terrain.normal_at(p.x, p.z).y > 0.8


func _bush_ok(p: Vector3) -> bool:
	var d := _dist_to_river(p)
	return d > 10.0 and (d < 90.0 or _in_draw(p)) and rng.randf() < 0.6 and not _near_point(p, 10.0)


func _rock_ok(p: Vector3) -> bool:
	return _dist_to_river(p) > 8.0 and terrain.normal_at(p.x, p.z).y < 0.93 and not _near_point(p, 8.0)


func _scatter_cottonwoods() -> void:
	## Cottonwoods crowd the river in groves, with open meadow between them and
	## brush and saplings underneath.
	var variants := ["twisted_tree_1", "twisted_tree_2", "twisted_tree_3", "twisted_tree_4", "twisted_tree_5"]
	for i in 5200:
		var p := _random_point()
		var d := _dist_to_river(p)
		if d < 10.0 or d > 170.0 or _near_point(p, 16.0) or not terrain.walkable(p.x, p.z):
			continue
		var grove := _groves.get_noise_2d(p.x, p.z)
		var near_water := 1.0 - d / 170.0
		if rng.randf() > near_water * smoothstep(-0.15, 0.35, grove) * 0.9:
			continue
		# Old giants on the banks, younger trees further back; each crown stretched
		# and leaning its own way so the groves don't read as copies.
		var size := lerpf(0.55, 1.0, pow(rng.randf(), 1.5)) * lerpf(0.85, 1.25, near_water)
		var stretch := Vector3(rng.randf_range(0.85, 1.25), rng.randf_range(0.9, 1.45), 1.0)
		stretch.z = stretch.x * rng.randf_range(0.85, 1.15)
		var lean := Vector3(rng.randf_range(-0.12, 0.12), 1.0, rng.randf_range(-0.12, 0.12))
		_add("cottonwood", variants[rng.randi() % variants.size()], p - Vector3(0, 0.3, 0), size, lean, 0.0, stretch)
		for u in rng.randi_range(0, 3):
			var off := Vector3(rng.randf_range(-7, 7), 0, rng.randf_range(-7, 7))
			var q := Vector3(p.x + off.x, terrain.height_at(p.x + off.x, p.z + off.z), p.z + off.z)
			if _dist_to_river(q) > 8.0:
				var under: String = ["bush_1", "bush_with_flowers_1", "plant_1", "tree_5"][rng.randi() % 4]
				var kind := "grove" if under == "tree_5" else "bush"
				_add(kind, under, q - Vector3(0, 0.1, 0), rng.randf_range(0.5, 0.9), Vector3.UP, 220.0)


func _scatter_groves() -> void:
	## Groves of smaller trees (bur oak country) in the ravines of the uplands.
	var variants := ["tree_1", "tree_2", "tree_3", "tree_4", "tree_5"]
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
			# The odd lightning-struck snag, not a burned forest.
			var v: String = ["dead_tree_1", "dead_tree_3"][rng.randi() % 2] if rng.randf() < 0.08 else variants[rng.randi() % variants.size()]
			var stretch := Vector3(rng.randf_range(0.85, 1.2), rng.randf_range(0.85, 1.3), rng.randf_range(0.85, 1.2))
			_add("grove", v, p - Vector3(0, 0.2, 0), rng.randf_range(0.7, 1.15), Vector3.UP, 0.0, stretch, COARSE_CHUNK)


func _scatter_driftwood() -> void:
	## Bleached driftwood stranded on the sandbars, and snags - whole trees jammed
	## in the riverbed, angled downstream - that made the Missouri so dangerous.
	var variants := ["dead_tree_2", "dead_tree_4", "dead_tree_5"]
	for i in 3000:
		var p := _random_point()
		var d := _dist_to_river(p)
		if d > -2.0 and d < 12.0:
			# Lying on the bar: tipped onto its side, trunk along a random heading.
			var ang := rng.randf() * TAU
			var side := Vector3(cos(ang), rng.randf_range(0.05, 0.2), sin(ang))
			_add("driftwood", variants[rng.randi() % variants.size()], p - Vector3(0, 0.3, 0), rng.randf_range(0.35, 0.8),
					side, 900.0, Vector3.ONE, COARSE_CHUNK)
		elif d > -24.0 and d < -6.0 and rng.randf() < 0.08:
			# A snag: rooted underwater, leaning 30-60 degrees out of the current.
			var ang := rng.randf() * TAU
			var lean := Vector3(cos(ang), rng.randf_range(0.6, 1.6), sin(ang))
			var bed := Vector3(p.x, Terrain.WATER_Y - 1.2, p.z)
			_add("driftwood", variants[rng.randi() % variants.size()], bed, rng.randf_range(0.4, 0.7), lean, 900.0,
					Vector3.ONE, COARSE_CHUNK)


func _on_bar(p: Vector3, min_above: float) -> bool:
	## Dry sand: above the river surface by ``min_above`` m, in the channel or the
	## bare margin beside it (not the grassed bottomland).
	return p.y > Terrain.WATER_Y - 0.35 + min_above and _dist_to_river(p) < 22.0


func _scatter_sandbar() -> void:
	## Life on the bars: sandbar-willow thickets and cottonwood seedlings along
	## the landward edge, wiry grass tufts, and pebbles in the wet margin.
	# Bars are a small part of the map, so most random points miss them.
	for i in 9000:
		var p := _random_point()
		if not _on_bar(p, 0.45) or _near_point(p, 26.0) or _groves.get_noise_2d(p.x * 1.7, p.z * 1.7) < -0.2:
			continue
		# A thicket: a handful of tall, narrow willow clumps close together.
		for k in rng.randi_range(3, 7):
			var q := p + Vector3(rng.randf_range(-3.5, 3.5), 0, rng.randf_range(-3.5, 3.5))
			q.y = terrain.height_at(q.x, q.z)
			if not _on_bar(q, 0.3):
				continue
			# Sizes from knee-high suckers to two-metre stems, each leaning its own way.
			var narrow := rng.randf_range(0.4, 0.8)
			var lean := Vector3(rng.randf_range(-0.14, 0.14), 1.0, rng.randf_range(-0.14, 0.14))
			# Three kinds of stem in a thicket, or it reads as one bush repeated.
			if rng.randf() < 0.18:
				# A young cottonwood among the willows: it grows as a tree, not a stem,
				# so it does not take the willow's narrow-and-tall stretch.
				_add("grove", "tree_5", q - Vector3(0, 0.1, 0), rng.randf_range(0.22, 0.38), lean, 260.0,
						Vector3(0.9, rng.randf_range(1.0, 1.25), 0.9))
			else:
				var kind: String = "bush_with_flowers_1" if rng.randf() < 0.25 else "bush_1"
				_add("willow", kind, q - Vector3(0, 0.1, 0), rng.randf_range(0.4, 1.35), lean, 260.0,
						Vector3(narrow, rng.randf_range(1.2, 2.4), narrow * rng.randf_range(0.85, 1.2)))
		if rng.randf() < 0.45:
			var q2 := p + Vector3(rng.randf_range(-5, 5), 0, rng.randf_range(-5, 5))
			q2.y = terrain.height_at(q2.x, q2.z)
			_add("grove", "tree_5", q2 - Vector3(0, 0.1, 0), rng.randf_range(0.28, 0.45), Vector3.UP, 260.0, Vector3(0.8, 1.3, 0.8))
	var tufts := ["grass_wispy_1", "grass_wispy_2", "tall_grass_1"]
	var stones := ["pebble_round_1", "pebble_round_2", "pebble_round_3", "pebble_round_4", "rock_path_round_small_1", "rock_path_round_small_2"]
	for i in 26000:
		var p := _random_point()
		if not _on_bar(p, 0.0):
			continue
		var above := p.y - (Terrain.WATER_Y - 0.35)
		if above > 0.5 and rng.randf() < 0.35:
			# Sandbar tufts stand in the wet and stay green.
			_add("grass", tufts[rng.randi() % tufts.size()], p - Vector3(0, 0.05, 0), rng.randf_range(0.35, 0.7),
					Vector3.UP, 70.0, Vector3.ONE, CHUNK, 0.12)
		elif above < 0.6 and rng.randf() < 0.75:
			_add("rock", stones[rng.randi() % stones.size()], p - Vector3(0, 0.03, 0), rng.randf_range(0.35, 0.8), Vector3.UP, 55.0)


func _scatter_draw_understory() -> void:
	## What grows in the ravines and nowhere else. The uplands here are open
	## prairie and the bottoms are cottonwood, but the draws cutting the bluffs
	## hold shade and damp, and the Corps used them to get up off the river.
	## Ferns and coarse woodland forbs down in the shade, fungus on the dead wood.
	var shade := FastNoiseLite.new()
	shade.seed = 6112
	shade.frequency = 1.0 / 40.0
	for i in 44000:
		var p := _random_point()
		if not _in_draw(p) or _near_point(p, 8.0):
			continue
		var n := terrain.normal_at(p.x, p.z)
		# A real ravine, not a gentle roll of the prairie, and inside the wooded
		# band rather than out on the open upland.
		if n.y > 0.94 or _groves.get_noise_2d(p.x, p.z) < -0.06:
			continue
		# The shaded side of it: north- and east-facing, off the crest.
		var facing := n.z * 0.7 - n.x * 0.5
		if facing < -0.02:
			continue
		var f := shade.get_noise_2d(p.x, p.z)
		if f < 0.05:
			continue
		var scale := rng.randf_range(0.5, 1.0)
		var roll := rng.randf()
		if roll < 0.42:
			# The kit's fern is nine metres across; a wood fern is under a metre.
			_add("understory", "fern_1", p - Vector3(0, 0.02, 0), scale * 0.11, n, 90.0, Vector3.ONE, COARSE_CHUNK)
		elif roll < 0.82:
			# plant_1 and plant_2, not the plant_big pair: those read as agaves,
			# which is the wrong continent.
			_add("understory", "plant_1" if rng.randf() < 0.5 else "plant_2",
					p - Vector3(0, 0.04 * scale, 0), scale * 0.75, n, 90.0, Vector3.ONE, COARSE_CHUNK)
		elif f > 0.22:
			# Fungus keeps to the dampest bottom of the draw.
			_add("fungus", "mushroom_1" if rng.randf() < 0.7 else "mushroom_laetiporus_1",
					p - Vector3(0, 0.02, 0), rng.randf_range(0.3, 0.55), n, 45.0, Vector3.ONE, COARSE_CHUNK)


func _scatter_grass_clumps() -> void:
	## Taller clumps standing out of the GPU grass field. Cured straw on the open
	## upland, still green down in the bottom and in the damp draws.
	var variants := ["tall_grass_1", "grass_wispy_1", "grass_wispy_2"]
	for i in 30000:
		var p := _random_point()
		if not _grass_ok(p):
			continue
		# How far this clump has cured: green in the bottom and near the water,
		# burnt off on the open upland, with the line between them ragged.
		var cure := smoothstep(30.0, 150.0, _dist_to_river(p))
		if terrain.is_bottomland(p.x, p.z):
			cure *= 0.35
		cure = clampf(cure + _groves.get_noise_2d(p.x * 1.7, p.z * 1.7) * 0.18, 0.18, 1.0)
		var n := terrain.normal_at(p.x, p.z)
		var scale := rng.randf_range(0.4, 0.72)
		_add("grass", variants[rng.randi() % variants.size()],
				p - Vector3(0, 0.05 * scale, 0), scale, n, 60.0, Vector3.ONE, CHUNK, cure)


func _scatter_wildflowers() -> void:
	## A stand of one species at a time, each keeping to the ground it likes, so the
	## prairie reads as a patchwork of colour instead of a confetti of it.
	var field := FastNoiseLite.new()
	for spec in WILDFLOWERS:
		field.seed = int(spec["seed"])
		field.frequency = float(spec["freq"])
		var placed := 0
		var low: bool = spec["low"]
		var variants: Array = spec["variants"]
		for i in int(spec["tries"]):
			var p := _random_point()
			if _dist_to_river(p) < 12.0 or terrain.normal_at(p.x, p.z).y < 0.86:
				continue
			if terrain.is_bottomland(p.x, p.z) != low:
				continue
			if field.get_noise_2d(p.x, p.z) < float(spec["threshold"]):
				continue
			if _near_point(p, 9.0):
				continue
			var scale := rng.randf_range(float(spec["smin"]), float(spec["smax"]))
			# A coarse chunk: fine enough that the stands still cull at distance
			# (a flower two hundred yards off is a coloured speck and reads badly),
			# coarse enough that the batching costs a few dozen draw calls, not
			# hundreds, since these are thin scatters.
			_add(spec["kind"], variants[rng.randi() % variants.size()], p - Vector3(0, 0.04 * scale, 0),
					scale, Vector3.UP, FLOWER_RANGE, spec["stretch"], COARSE_CHUNK)
			placed += 1
		if OS.is_stdout_verbose():
			print("foliage: %s x%d" % [spec["kind"], placed])


func _scatter_far_country() -> void:
	## Groves out in the country beyond the playable kilometre. Only ever a few
	## pixels tall, so they are single blobs on a MultiMesh, unshadowed.
	var mesh := _far_tree_mesh()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	var xforms: Array[Transform3D] = []
	var tints: Array[Color] = []
	var far := FastNoiseLite.new()
	far.seed = 909
	far.frequency = 1.0 / 260.0
	for i in 26000:
		var x := rng.randf_range(-1700.0, Terrain.SIZE + 1700.0)
		var z := rng.randf_range(-1700.0, Terrain.SIZE + 1700.0)
		var out := Vector2(x - clampf(x, 0.0, Terrain.SIZE), z - clampf(z, 0.0, Terrain.SIZE)).length()
		if out < 40.0:
			continue  # inside the map, or hard against its edge: real trees grow there
		# Clumped into groves and draws, thinning as the country dries out westward.
		if far.get_noise_2d(x, z) < rng.randf_range(-0.1, 0.45):
			continue
		var h := terrain.skirt_height(x, z)
		var size := rng.randf_range(6.0, 13.0) * clampf(1.4 - out / 2600.0, 0.6, 1.2)
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(size * rng.randf_range(0.8, 1.2), size, size * rng.randf_range(0.8, 1.2)))
		xforms.append(Transform3D(basis, Vector3(x, h, z)))
		var g := rng.randf_range(-0.04, 0.05)
		tints.append(Color(0.30 + g, 0.40 + g, 0.24 + g * 0.5))
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
		mm.set_instance_color(i, tints[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "FarCountry"
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.set_meta("kind", "far_country")
	add_child(mmi)


static func _far_tree_mesh() -> ArrayMesh:
	## A crown on a stub of trunk: read as a tree at a kilometre, three dozen triangles.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 3
	var seg := 7
	var pts: Array = []
	for r in rings + 1:
		var v := float(r) / rings
		var y := 0.35 + cos(v * PI) * -0.45 + 0.45
		var rad := sin(v * PI) * 0.5 + 0.02
		var row: Array = []
		for k in seg + 1:
			var a := TAU * k / seg
			row.append(Vector3(cos(a) * rad, y, sin(a) * rad))
		pts.append(row)
	for r in rings:
		for k in seg:
			for v in [pts[r][k], pts[r + 1][k], pts[r + 1][k + 1], pts[r][k], pts[r + 1][k + 1], pts[r][k + 1]]:
				st.add_vertex(v)
	# Trunk.
	for k in seg:
		var a0 := TAU * k / seg
		var a1 := TAU * (k + 1) / seg
		var w := 0.06
		var quad := [Vector3(cos(a0) * w, 0, sin(a0) * w), Vector3(cos(a0) * w, 0.4, sin(a0) * w),
				Vector3(cos(a1) * w, 0.4, sin(a1) * w), Vector3(cos(a1) * w, 0, sin(a1) * w)]
		for v in [quad[0], quad[1], quad[2], quad[0], quad[2], quad[3]]:
			st.add_vertex(v)
	st.generate_normals()
	var mesh := st.commit()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 1.0
	m.albedo_color = Color(1, 1, 1)
	mesh.surface_set_material(0, m)
	return mesh


func _scatter_beaver_sign() -> void:
	## Beaver work along the banks: stumps gnawed to a point, chips about the foot
	## of them, and often the tree itself down and pointing at the water. The whole
	## reason anyone in St Louis cared which way this river ran. Stumps and chips
	## go on two MultiMeshes: there are hundreds of them and they are all the same.
	var cut := ["dead_tree_2", "dead_tree_4", "dead_tree_5"]
	var stumps: Array[Transform3D] = []
	var chips: Array[Transform3D] = []
	for i in 4000:
		var p := _random_point()
		var d := _dist_to_river(p)
		# In the willow and cottonwood fringe, within a beaver's haul of the water.
		# Off the open sand: a stump alone on a bar, with no tree it came from, reads
		# as a mistake. Beaver work belongs in the willow and cottonwood fringe.
		if d < 2.0 or d > 26.0 or rng.randf() < 0.55 or _on_bar(p, -0.1):
			continue
		var h := rng.randf_range(0.45, 0.9)
		var lean := Basis(Vector3.RIGHT, deg_to_rad(rng.randf_range(-5, 5))) * Basis(Vector3.UP, rng.randf() * TAU)
		# A cylinder is centred on its origin, so stand it on the ground, not in it.
		stumps.append(Transform3D(lean.scaled(Vector3(rng.randf_range(0.8, 1.4), h / 0.7, rng.randf_range(0.8, 1.4))),
				p + Vector3(0, h * 0.5 - 0.04, 0)))
		for c in rng.randi_range(3, 7):
			var off := Vector3(rng.randf_range(-0.9, 0.9), 0, rng.randf_range(-0.9, 0.9))
			chips.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.7, 1.4)),
					p + off + Vector3(0, 0.02, 0)))
		if rng.randf() < 0.45:
			var toward := terrain.toward_river(p.x, p.z)
			_add("driftwood", cut[rng.randi() % cut.size()], p + Vector3(0, 0.2, 0),
					rng.randf_range(0.3, 0.55), Vector3(toward.x, rng.randf_range(0.05, 0.2), toward.z), 260.0,
					Vector3.ONE, 128.0)
	_batch("BeaverStumps", _stump_mesh(), stumps, 220.0)
	_batch("BeaverChips", _chip_mesh(), chips, 45.0)


func _batch(batch_name: String, mesh: Mesh, xforms: Array[Transform3D], visibility: float) -> void:
	if xforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = batch_name
	mmi.multimesh = mm
	# No visibility range here: one MultiMesh spans the whole bank, so a range
	# would measure from the middle of it and cull the lot.
	add_child(mmi)


static func _stump_mesh() -> Mesh:
	## A stump about 0.7 m high, chewed to a blunt point. A smooth cylinder reads
	## as a traffic cone on the sand, so this is faceted the way a beaver leaves
	## it: dark bark up the sides, pale gnawed wood on the cut, and the facets
	## uneven, because the animal works round the trunk a bite at a time.
	var bark := Color(0.38, 0.30, 0.21)
	var wood := Color(0.90, 0.78, 0.55)
	var sides := 9
	var shaft := 0.32      # bark up to here; above it the cut runs to a blunt point
	var height := 0.7
	var rng := RandomNumberGenerator.new()
	rng.seed = 91
	var radii: Array[float] = []
	for i in sides:
		radii.append(0.22 * rng.randf_range(0.88, 1.06))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in sides:
		var j := (i + 1) % sides
		var a := i * TAU / sides
		var b := j * TAU / sides
		var ra: float = radii[i]
		var rb: float = radii[j]
		var p0 := Vector3(cos(a) * ra, 0.0, sin(a) * ra)
		var p1 := Vector3(cos(b) * rb, 0.0, sin(b) * rb)
		var q0 := Vector3(cos(a) * ra * 0.94, shaft, sin(a) * ra * 0.94)
		var q1 := Vector3(cos(b) * rb * 0.94, shaft, sin(b) * rb * 0.94)
		# The bark, still on below the cut.
		for v in [p0, p1, q1, p0, q1, q0]:
			st.set_color(bark.lightened(rng.randf_range(0.0, 0.12)))
			st.add_vertex(v)
		# The gnawed cone above it, each facet a different bite.
		var lift := rng.randf_range(0.88, 1.06)
		var tip := Vector3(0.0, height * lift, 0.0)
		var c := wood.darkened(rng.randf_range(0.0, 0.12))
		for v in [q0, q1, tip]:
			st.set_color(c)
			st.add_vertex(v)
	st.generate_normals()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 0.95
	var mesh := st.commit()
	mesh.surface_set_material(0, m)
	return mesh


static func _chip_mesh() -> Mesh:
	var bm := BoxMesh.new()
	bm.size = Vector3(0.1, 0.03, 0.06)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.80, 0.72, 0.56)
	m.roughness = 0.95
	bm.material = m
	return bm
