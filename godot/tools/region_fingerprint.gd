extends SceneTree
## Builds a Region's foliage and wildlife and prints a count per kind and a hash
## of where everything stands, so a refactor can prove it places exactly what it
## placed before:
##   godot --headless --path godot -s tools/region_fingerprint.gd [-- --region=<id>]
## The river's fish and drift are placed afresh every run, so only counted.
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
	_print(tally)
	print("FOLIAGE HASH ", h)
	var w := Wildlife.populate(t, null)
	root.add_child(w)
	tally = {}
	h = 0
	for n in w.find_children("*", "Node3D", true, false):
		if n.get_parent() == w or n.get_parent().get_parent() == w:
			# Unnamed nodes get engine names that differ run to run.
			var k := "animal" if str(n.name).begins_with("@") else str(n.name).rstrip("0123456789")
			tally["wild:" + k] = int(tally.get("wild:" + k, 0)) + 1
			h = hash([h, str(n.position), str(n.get_parent().position), str(n.scale)])
	var life := RiverLife.new()
	life.build(t, null)
	var drift := RiverDrift.new()
	drift.build(t, null)
	tally["river:rise_every"] = life.get("rise_every")
	tally["river:drift_logs"] = drift.get_child_count()
	_print(tally)
	print("WILDLIFE HASH ", h)
	quit()


func _print(tally: Dictionary) -> void:
	var keys := tally.keys()
	keys.sort()
	for k in keys:
		print("%s %s" % [k, tally[k]])
