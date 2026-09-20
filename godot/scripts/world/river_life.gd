class_name RiverLife
extends Node3D
## The river is not still: fish rise and leave a ring that widens and fades.
## Rings are only set where there is water to rise in, within sight of the Leader.

const RISE_EVERY := 1.8   # seconds, on average
const RINGS := 14

var terrain: Terrain
var watch: Node3D

var _rings: Array[MeshInstance3D] = []
var _live: Array[Dictionary] = []
var _next := 1.0
var _rng := RandomNumberGenerator.new()


func build(p_terrain: Terrain, p_watch: Node3D) -> void:
	name = "RiverLife"
	terrain = p_terrain
	watch = p_watch
	_rng.randomize()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(1.0, 1.0)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/world/ring.gdshader")
	# The river is one huge transparent surface and sorts after these unless told.
	mat.render_priority = 8
	# The river is one huge transparent surface and sorts after these unless told.
	mat.render_priority = 8
	mesh.surface_set_material(0, mat)
	for i in RINGS:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.visible = false
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_rings.append(mi)


func _process(delta: float) -> void:
	if watch == null:
		return
	_next -= delta
	if _next <= 0.0:
		_next = _rng.randf_range(RISE_EVERY * 0.4, RISE_EVERY * 1.6)
		_rise()
	for r in _live.duplicate():
		r["age"] = float(r["age"]) + delta
		var life: float = float(r["life"])
		var mi: MeshInstance3D = r["node"]
		if float(r["age"]) >= life:
			mi.visible = false
			_live.erase(r)
			continue
		var t: float = float(r["age"]) / life
		mi.scale = Vector3.ONE * lerpf(0.25, float(r["spread"]), sqrt(t))
		(mi.get_surface_override_material(0) as ShaderMaterial).set_shader_parameter("fade", 1.0 - t)


func _rise() -> void:
	var free_ring: MeshInstance3D = null
	for mi in _rings:
		if not mi.visible:
			free_ring = mi
			break
	if free_ring == null:
		return
	# On the water in front of the Leader, near enough to see the ring spread.
	var here := watch.global_position
	var facing := -watch.global_transform.basis.z
	for attempt in 16:
		var a := _rng.randf() * TAU
		var d := _rng.randf_range(5.0, 22.0)
		var p := Vector3(here.x + cos(a) * d, 0, here.z + sin(a) * d)
		if terrain.river_distance(p.x, p.z) > terrain.river_half_width() - 3.0:
			continue  # not open water
		var toward := Vector3(p.x - here.x, 0, p.z - here.z).normalized()
		if toward.dot(Vector3(facing.x, 0, facing.z).normalized()) < 0.1:
			continue  # behind him, where he would not see it rise
		# Just clear of the surface, or the water sorts in front of it.
		free_ring.position = Vector3(p.x, Terrain.WATER_Y - 0.2, p.z)
		free_ring.visible = true
		var m := (free_ring.mesh as PlaneMesh).surface_get_material(0).duplicate()
		free_ring.set_surface_override_material(0, m)
		_live.append({"node": free_ring, "age": 0.0, "life": _rng.randf_range(2.2, 3.4),
				"spread": _rng.randf_range(2.4, 4.5)})
		return
