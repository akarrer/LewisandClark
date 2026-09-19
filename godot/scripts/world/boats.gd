class_name Boats
extends Node3D
## The Corps' fleet moored at the landing: the 55-foot keelboat (stern cabin,
## gunwale lockers that stood up as a breastwork, a 32-foot mast with its square
## sail furled) and the red and white pirogues, rocking a little in the current.
## Built procedurally until the commissioned models (see ADR-0008).

const WOOD := Color(0.55, 0.40, 0.25)
const TAR := Color(0.13, 0.11, 0.09)
const CANVAS := Color(0.82, 0.78, 0.68)

var _hulls: Array[Node3D] = []


static func fleet(terrain: Terrain) -> Boats:
	var b := Boats.new()
	b.name = "Fleet"
	var start: Vector3 = terrain.points["start"]
	var to_water := terrain.toward_river(start.x, start.z)
	var along := Vector3(-to_water.z, 0.0, to_water.x)
	var moorings := [[0.0, keelboat(), 7.0], [-26.0, pirogue(Color(0.58, 0.16, 0.11)), 4.5], [-42.0, pirogue(Color(0.86, 0.83, 0.75)), 4.5]]
	for m in moorings:
		var p := _mooring(terrain, start + along * float(m[0]), to_water, float(m[2]))
		var hull: Node3D = m[1]
		# Hulls are built bow toward +X; point the bow upriver along the bank.
		hull.transform = Transform3D(Basis.looking_at(along, Vector3.UP) * Basis(Vector3.UP, PI / 2.0), p)
		b.add_child(hull)
		b._hulls.append(hull)
		# Made fast to a stake on the bar: bow line slanting down to the sand.
		var bow := p + along * (7.8 if hull.name == "Keelboat" else 5.6) + Vector3(0, 0.9, 0)
		var stake := bow - to_water * (float(m[2]) + 2.5) + along * 1.5
		stake.y = terrain.height_at(stake.x, stake.z)
		b.add_child(Props.cylinder(0.05, 0.9, WOOD.darkened(0.3), stake + Vector3(0, 0.3, 0)))
		b.add_child(_line(bow, stake + Vector3(0, 0.6, 0)))
	return b


static func _mooring(terrain: Terrain, from: Vector3, to_water: Vector3, inset: float) -> Vector3:
	## Walk from the bank toward the river until the hull's inboard side clears the edge.
	var p := from
	for i in 200:
		if terrain.river_distance(p.x, p.z) < terrain.river_half_width() - inset:
			break
		p += to_water
	return Vector3(p.x, Terrain.WATER_Y - 0.35, p.z)


func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for i in _hulls.size():
		var h := _hulls[i]
		h.rotation.z = sin(t * 0.7 + i * 1.3) * 0.012
		h.rotation.x = sin(t * 0.5 + i * 2.1) * 0.008
		h.position.y = Terrain.WATER_Y - 0.35 + sin(t * 0.9 + i) * 0.02


static func keelboat() -> Node3D:
	var boat := Node3D.new()
	boat.name = "Keelboat"
	var length := 16.8
	var beam := 2.5
	boat.add_child(hull_mesh(length, beam, 1.15, WOOD, TAR, WOOD.darkened(0.15)))
	var deck_y := 0.5
	# Stern cabin, lockers along both gunwales, a bow deck.
	boat.add_child(Props.box(Vector3(3.4, 1.15, 2.0), WOOD.lightened(0.08), Vector3(-length / 2.0 + 2.6, deck_y + 0.55, 0)))
	boat.add_child(Props.box(Vector3(3.6, 0.08, 2.2), WOOD.darkened(0.25), Vector3(-length / 2.0 + 2.6, deck_y + 1.15, 0)))
	for side in [-1.0, 1.0]:
		boat.add_child(Props.box(Vector3(8.6, 0.55, 0.38), WOOD.lightened(0.04), Vector3(1.2, deck_y + 0.28, side * (beam / 2.0 - 0.3))))
	# Mast, yard with the square sail furled, and a few shrouds.
	var mast_x := 2.2
	boat.add_child(Props.cylinder(0.12, 9.6, WOOD.darkened(0.1), Vector3(mast_x, deck_y + 4.8, 0), 0.07))
	var yard := Props.cylinder(0.06, 5.2, WOOD.darkened(0.1), Vector3(mast_x, deck_y + 7.6, 0))
	yard.rotation_degrees = Vector3(90, 0, 0)
	boat.add_child(yard)
	var sail := Props.cylinder(0.2, 4.6, CANVAS, Vector3(mast_x, deck_y + 7.4, 0), 0.16)
	sail.rotation_degrees = Vector3(90, 0, 0)
	boat.add_child(sail)
	for fore in [-1.0, 1.0]:
		for side in [-1.0, 1.0]:
			boat.add_child(_line(Vector3(mast_x, deck_y + 9.2, 0), Vector3(mast_x + fore * 2.2, deck_y + 0.2, side * (beam / 2.0 - 0.15))))
	# The colours at the stern.
	var staff := Vector3(-length / 2.0 + 0.4, deck_y, 0)
	boat.add_child(Props.cylinder(0.035, 3.2, WOOD.darkened(0.3), staff + Vector3(0, 1.6, 0)))
	# Streaming aft (-X) from the staff so it reads from the bank.
	for i in 7:
		var col := Color(0.72, 0.12, 0.12) if i % 2 == 0 else Color(0.93, 0.91, 0.86)
		boat.add_child(Props.box(Vector3(1.1, 0.09, 0.02), col, staff + Vector3(-0.58, 3.05 - i * 0.09, 0)))
	boat.add_child(Props.box(Vector3(0.46, 0.36, 0.025), Color(0.12, 0.18, 0.42), staff + Vector3(-0.26, 2.92, 0)))
	# Oars shipped along the lockers.
	for i in 6:
		var side := -1.0 if i % 2 == 0 else 1.0
		var oar := Props.box(Vector3(4.2, 0.05, 0.08), WOOD.lightened(0.15), Vector3(0.4 + (i / 2) * 1.6, deck_y + 0.62, side * (beam / 2.0 - 0.3)))
		oar.rotation_degrees.y = side * 4.0
		boat.add_child(oar)
	return boat


static func pirogue(paint: Color) -> Node3D:
	var boat := Node3D.new()
	boat.name = "Pirogue"
	var length := 12.0
	var beam := 2.2
	boat.add_child(hull_mesh(length, beam, 0.85, paint, TAR, WOOD))
	for i in 5:
		boat.add_child(Props.box(Vector3(0.22, 0.06, beam * 0.9), WOOD, Vector3(-4.0 + i * 2.0, 0.28, 0)))
	boat.add_child(Props.box(Vector3(1.6, 0.5, 1.2), CANVAS.darkened(0.2), Vector3(-0.5, 0.45, 0)))  # cargo under a tarpaulin
	for i in 4:
		var side := -1.0 if i % 2 == 0 else 1.0
		var oar := Props.box(Vector3(3.4, 0.045, 0.07), WOOD.lightened(0.15), Vector3(-2.6 + (i / 2) * 3.4, 0.4, side * 1.2))
		oar.rotation_degrees.y = side * 62.0
		oar.rotation_degrees.z = -6.0
		boat.add_child(oar)
	return boat


static func hull_mesh(length: float, beam: float, depth: float, topside: Color, bottom: Color, inside: Color) -> MeshInstance3D:
	## A lofted plank hull, bow toward +X: transom stern, pointed rising bow,
	## flat bottom and near-vertical sides. The waterline sits at y = 0.
	var sections := 28
	var ring := 10
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows: Array = []
	for i in sections + 1:
		var t := float(i) / sections
		var bow := clampf((1.0 - t) / 0.3, 0.0, 1.0)
		var half := beam / 2.0 * sqrt(bow) * (0.8 + 0.2 * smoothstep(0.0, 0.3, t))
		var gun := 0.42 + 0.45 * pow(t, 5.0) + 0.1 * pow(1.0 - t, 4.0)
		var d := depth * (0.55 + 0.45 * sqrt(bow))
		var row: Array = []
		for j in ring + 1:
			var u := float(j) / ring * 2.0 - 1.0
			var z := half * u
			var y := gun - d * (1.0 - pow(absf(u), 5.0))
			row.append(Vector3((t - 0.5) * length, y, z))
		rows.append(row)
	# Outer skin (tarred below the waterline) and the inner planking.
	for pass_i in 2:
		var shrink := 1.0 if pass_i == 0 else 0.93
		var lift := 0.0 if pass_i == 0 else 0.06
		for i in sections:
			for j in ring:
				var q := [rows[i][j], rows[i + 1][j], rows[i + 1][j + 1], rows[i][j + 1]]
				for k in 4:
					q[k] = Vector3(q[k].x, q[k].y + lift, q[k].z * shrink)
				var tris := [0, 1, 2, 0, 2, 3] if pass_i == 0 else [0, 2, 1, 0, 3, 2]
				for idx in tris:
					var v: Vector3 = q[idx]
					var c := inside
					if pass_i == 0:
						c = bottom if v.y < 0.05 else topside
						if absf(v.y - 0.36) < 0.05:
							c = topside.darkened(0.3)  # rubbing strake
					st.set_color(c)
					st.add_vertex(v)
	# Transom.
	var stern: Array = rows[0]
	for j in ring:
		for v in [stern[0].lerp(stern[ring], 0.5) + Vector3(0, 0.1, 0), stern[j + 1], stern[j]]:
			st.set_color(topside.darkened(0.1))
			st.add_vertex(v)
	# Floorboards.
	var floor_y := -depth * 0.35
	for i in sections:
		var a: Vector3 = rows[i][2]
		var b: Vector3 = rows[i + 1][2]
		var c2: Vector3 = rows[i + 1][ring - 2]
		var d2: Vector3 = rows[i][ring - 2]
		for v in [a, c2, b, a, d2, c2]:
			st.set_color(inside.darkened(0.2))
			st.add_vertex(Vector3(v.x, floor_y, v.z * 0.9))
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 0.85
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	return mi


static func _line(a: Vector3, b: Vector3) -> MeshInstance3D:
	## A rope from a to b (cylinders are built along +Y).
	var mi := Props.cylinder(0.012, a.distance_to(b), Color(0.25, 0.2, 0.14))
	var dir := (b - a).normalized()
	var up := Vector3.FORWARD if absf(dir.y) > 0.99 else Vector3.UP
	mi.transform = Transform3D(Basis.looking_at(dir, up) * Basis(Vector3.RIGHT, -PI / 2.0), (a + b) / 2.0)
	return mi
