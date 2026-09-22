extends SceneTree
## Builds a Region's foliage and prints a count per kind and a hash of every
## instance, so a refactor can prove it grows exactly what it grew before:
##   godot --headless --path godot -s tools/foliage_fingerprint.gd [-- --region=<id>]
func _init() -> void:
	var t := Terrain.new(Region.load_region(Region.wanted()))
	root.add_child(t)
	t.build()
	var f := Foliage.new()
	root.add_child(f)
	f.build(t)
	var tally := {}
	var h := 0
	for c in f.get_children():
		if c is MultiMeshInstance3D:
			var mm: MultiMesh = c.multimesh
			var k := str(c.get_meta("kind", c.name))
			tally[k] = int(tally.get(k, 0)) + mm.instance_count
			for i in mm.instance_count:
				h = hash([h, str(mm.get_instance_transform(i).origin)])
	var keys := tally.keys()
	keys.sort()
	for k in keys:
		print("%s %d" % [k, tally[k]])
	print("HASH ", h)
	quit()
