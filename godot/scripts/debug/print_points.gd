extends SceneTree
func _init() -> void:
	var tr := Terrain.new()
	tr.define_points()
	for k in tr.points:
		var p: Vector3 = tr.points[k]
		print("%-18s x=%.0f z=%.0f y=%.1f river=%.0f slope_ny=%.2f" % [k, p.x, p.z, p.y, tr.river_distance(p.x, p.z), tr.normal_at(p.x, p.z).y])
	tr.free()
	quit()
