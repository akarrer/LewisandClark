extends SceneTree
## Prints bounds and triangle counts of the imported nature models (dev tool).

func _init() -> void:
	var dir := "res://assets/third_party/nature/"
	var files := DirAccess.get_files_at(dir)
	var seen := {}
	for f in files:
		if not f.ends_with(".glb"):
			continue
		var base := f.get_basename().rsplit("_", true, 1)[0]
		var scene: PackedScene = load(dir + f)
		var root := scene.instantiate()
		var aabb := AABB()
		var tris := 0
		var first := true
		for mi in root.find_children("*", "MeshInstance3D", true, false):
			var m: Mesh = mi.mesh
			for s in m.get_surface_count():
				var arr := m.surface_get_arrays(s)
				var idx = arr[Mesh.ARRAY_INDEX]
				tris += (idx.size() if idx != null else arr[Mesh.ARRAY_VERTEX].size()) / 3
			var box: AABB = mi.transform * m.get_aabb()
			aabb = box if first else aabb.merge(box)
			first = false
		print("%-28s size=(%.1f, %.1f, %.1f) tris=%d mats=%d" % [f, aabb.size.x, aabb.size.y, aabb.size.z, tris, root.find_children("*", "MeshInstance3D", true, false).size()])
		root.free()
	var lib: PackedScene = load("res://assets/third_party/animation/universal_animation_library_standard/Animation Library[Standard]/Godot/AnimationLibrary_Godot_Standard.glb")
	var inst := lib.instantiate()
	_print_tree(inst, 0)
	inst.free()
	quit()

func _print_tree(n: Node, depth: int) -> void:
	if depth > 3:
		return
	var extra := ""
	if n is AnimationPlayer:
		extra = " anims=%d" % (n as AnimationPlayer).get_animation_list().size()
	if n is MeshInstance3D:
		extra = " aabb=%s" % str((n as MeshInstance3D).get_aabb().size)
	print("  ".repeat(depth) + n.name + " <" + n.get_class() + ">" + extra)
	for c in n.get_children():
		_print_tree(c, depth + 1)
