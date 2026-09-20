class_name Wildlife
extends Node3D
## Game seen at a distance: elk grazing the uplands in small herds and deer at
## the woodland edges (Clark noted both around Council Bluff; bison weren't seen
## until late August, further upriver). Scenery only: they drift as they graze,
## lift their heads now and then, and move off if the Leader comes close.

const ELK := Color(0.56, 0.40, 0.25)
const DEER := Color(0.62, 0.44, 0.28)

var terrain: Terrain
var watch: Node3D  # the Leader
var _animals: Array[Dictionary] = []
var _flocks: Array[Dictionary] = []
var _waders: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
## Off while the autopilot frames scenery shots, so the animals hold still for it.
var shy := true


static func populate(t: Terrain, leader: Node3D) -> Wildlife:
	var w := Wildlife.new()
	w.name = "Wildlife"
	w.terrain = t
	w.watch = leader
	w._rng.seed = 1804
	w._place_herds()
	w._place_flocks()
	w._place_waders()
	w._place_swallows()
	return w


func _place_herds() -> void:
	# Elk out on open upland, well away from the landing and the landmarks.
	var herds := 0
	for attempt in 400:
		if herds >= 4:
			break
		var c := Vector3(_rng.randf_range(40, 980), 0, _rng.randf_range(40, 980))
		if terrain.is_bottomland(c.x, c.z) or not terrain.walkable(c.x, c.z) or _near_points(c, 140.0):
			continue
		for i in _rng.randi_range(5, 9):
			_add(quadruped(ELK, i == 0, true), c + Vector3(_rng.randf_range(-16, 16), 0, _rng.randf_range(-16, 16)), 1.0)
		herds += 1
	# Deer in twos and threes where the groves meet open ground.
	var groups := 0
	for attempt in 400:
		if groups >= 5:
			break
		var c := Vector3(_rng.randf_range(40, 980), 0, _rng.randf_range(40, 980))
		var d := terrain.river_distance(c.x, c.z) - terrain.river_half_width()
		if d < 60.0 or d > 180.0 or not terrain.walkable(c.x, c.z) or _near_points(c, 90.0):
			continue
		for i in _rng.randi_range(2, 3):
			_add(quadruped(DEER, i == 0 and _rng.randf() < 0.5, false), c + Vector3(_rng.randf_range(-6, 6), 0, _rng.randf_range(-6, 6)), 0.62)
		groups += 1


func _near_points(p: Vector3, r: float) -> bool:
	for k in terrain.points:
		var q: Vector3 = terrain.points[k]
		if Vector2(p.x - q.x, p.z - q.z).length() < r:
			return true
	return false


func _add(animal: Node3D, p: Vector3, size: float) -> void:
	animal.scale = Vector3.ONE * size * _rng.randf_range(0.9, 1.08)
	p.y = terrain.height_at(p.x, p.z)
	animal.position = p
	add_child(animal)
	_animals.append({
		"node": animal, "home": p, "pos": p, "heading": _rng.randf() * TAU,
		"phase": _rng.randf() * 100.0, "speed": _rng.randf_range(0.08, 0.2), "flee": 0.0,
	})


func _process(delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	_fly(delta, t)
	_wade(delta, t)
	var leader := watch.global_position if watch else Vector3.INF
	for a in _animals:
		var n: Node3D = a["node"]
		var pos: Vector3 = a["pos"]
		var home: Vector3 = a["home"]
		var ph: float = a["phase"]
		# Wary: a man on foot inside ~45 m sends them trotting off, away from him.
		var away := Vector3(pos.x - leader.x, 0, pos.z - leader.z)
		if shy and away.length() < 45.0:
			a["flee"] = 6.0
			a["heading"] = lerp_angle(float(a["heading"]), atan2(away.x, away.z), 0.1)
		a["flee"] = maxf(float(a["flee"]) - delta, 0.0)
		var fleeing := float(a["flee"]) > 0.0
		# Grazing: a slow wander that turns back toward home range.
		var drift := sin(t * 0.05 + ph) * 0.6
		var to_home := Vector3(home.x - pos.x, 0, home.z - pos.z)
		if to_home.length() > 30.0 and not fleeing:
			a["heading"] = lerp_angle(float(a["heading"]), atan2(to_home.x, to_home.z), delta * 0.5)
		a["heading"] = float(a["heading"]) + drift * delta * 0.2
		var grazing := sin(t * 0.3 + ph) > -0.3
		var speed := 5.0 if fleeing else (float(a["speed"]) if grazing else 0.0)
		var h := float(a["heading"])
		pos += Vector3(sin(h), 0, cos(h)) * speed * delta
		if not terrain.walkable(pos.x, pos.z):
			a["heading"] = h + PI * 0.5  # turn from water and cliffs
			pos = a["pos"]
		pos.y = terrain.height_at(pos.x, pos.z)
		a["pos"] = pos
		n.position = pos
		n.rotation.y = h
		# Head down to graze, up to look around (and up while running).
		var neck: Node3D = n.get_node("Neck")
		var down := 0.0 if fleeing else (1.0 if grazing and sin(t * 0.9 + ph * 3.0) > -0.6 else 0.0)
		neck.rotation.x = lerpf(neck.rotation.x, deg_to_rad(lerpf(-10.0, 62.0, down)), delta * 2.0)
		if fleeing:
			n.position.y += absf(sin(t * 9.0 + ph)) * 0.12


static func quadruped(coat: Color, antlered: bool, rump_patch: bool) -> Node3D:
	## An elk/deer silhouette built along +Z (head forward), shoulder ~1.45 m.
	var a := Node3D.new()
	var dark := coat.darkened(0.45)
	var body := _blob(Vector3(0.62, 0.68, 1.7), coat, Vector3(0, 1.22, 0))
	body.name = "Body"
	a.add_child(body)
	a.add_child(_blob(Vector3(0.66, 0.72, 0.7), coat.darkened(0.12), Vector3(0, 1.3, 0.55)))  # shoulders
	if rump_patch:
		a.add_child(_blob(Vector3(0.5, 0.52, 0.35), Color(0.86, 0.78, 0.60), Vector3(0, 1.26, -0.74)))
	for lx in [-0.18, 0.18]:
		for lz in [-0.6, 0.62]:
			var leg := Props.cylinder(0.055, 1.02, dark, Vector3(lx, 0.5, lz), 0.035)
			a.add_child(leg)
	var neck := Node3D.new()
	neck.name = "Neck"
	neck.position = Vector3(0, 1.45, 0.8)
	a.add_child(neck)
	var n := _blob(Vector3(0.3, 0.72, 0.34), dark.lightened(0.15), Vector3(0, 0.32, 0.12))
	n.rotation_degrees.x = 30.0
	neck.add_child(n)
	var head := _blob(Vector3(0.24, 0.26, 0.52), coat, Vector3(0, 0.68, 0.38))
	neck.add_child(head)
	for side in [-1.0, 1.0]:
		var ear := Props.box(Vector3(0.05, 0.16, 0.08), coat, Vector3(side * 0.12, 0.84, 0.22))
		ear.rotation_degrees.z = side * -25.0
		neck.add_child(ear)
	if antlered:
		var bone := Color(0.78, 0.72, 0.58)
		for side in [-1.0, 1.0]:
			var beam := Props.cylinder(0.025, 1.1, bone, Vector3(side * 0.22, 1.2, 0.05), 0.012)
			beam.rotation_degrees = Vector3(-35, 0, side * -28.0)
			neck.add_child(beam)
			for k in 3:
				var tine := Props.cylinder(0.014, 0.34, bone, Vector3(side * (0.18 + k * 0.06), 1.0 + k * 0.2, 0.2 - k * 0.12), 0.006)
				tine.rotation_degrees = Vector3(40, 0, side * -10.0)
				neck.add_child(tine)
	for c in a.find_children("*", "GeometryInstance3D", true, false):
		(c as GeometryInstance3D).visibility_range_end = 700.0
	return a


static func _blob(size: Vector3, color: Color, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 12
	sm.rings = 6
	mi.mesh = sm
	mi.scale = size
	mi.position = pos
	mi.material_override = Props.mat(color)
	return mi


# ---------------------------------------------------------------- birds


func _place_flocks() -> void:
	## Birds wheeling over the river and the bluffs: too far off to identify,
	## which is what you see of them from the ground.
	for f in 3:
		var centre := Vector3(_rng.randf_range(200, 800), 0, _rng.randf_range(200, 800))
		centre.y = terrain.height_at(centre.x, centre.z) + _rng.randf_range(40, 90)
		var flock := Node3D.new()
		flock.name = "Flock%d" % f
		add_child(flock)
		var birds: Array[Node3D] = []
		for i in _rng.randi_range(7, 14):
			var b := _bird(Color(0.12, 0.11, 0.10) if f % 2 == 0 else Color(0.35, 0.33, 0.30))
			b.position = Vector3(_rng.randf_range(-22, 22), _rng.randf_range(-6, 6), _rng.randf_range(-22, 22))
			flock.add_child(b)
			birds.append(b)
		_flocks.append({
			"node": flock, "centre": centre, "radius": _rng.randf_range(60, 130),
			"speed": _rng.randf_range(0.05, 0.11), "phase": _rng.randf() * TAU, "birds": birds,
		})


func _place_swallows() -> void:
	## Cliff swallows hawking low over the water under the bluff. They nest in
	## the loess itself; the Corps found their nests all along these banks.
	var under_bluff: Vector3 = terrain.points.get("council_bluff", Vector3(512, 0, 512))
	# Close under the rim, where the nests are, rather than away over the water.
	var centre := under_bluff + terrain.toward_river(under_bluff.x, under_bluff.z) * 20.0
	centre.y = maxf(under_bluff.y - 3.0, Terrain.WATER_Y + 4.0)
	var flock := Node3D.new()
	flock.name = "Swallows"
	add_child(flock)
	var birds: Array[Node3D] = []
	for i in 16:
		var b := _bird(Color(0.16, 0.15, 0.20))
		b.scale = Vector3.ONE * 0.45          # a swallow is a handful of nothing
		b.position = Vector3(_rng.randf_range(-18, 18), _rng.randf_range(-3, 3), _rng.randf_range(-18, 18))
		b.set_meta("jink", _rng.randf() * 100.0)
		flock.add_child(b)
		birds.append(b)
	_flocks.append({
		"node": flock, "centre": centre, "radius": 26.0, "speed": 0.5,
		"phase": _rng.randf() * TAU, "birds": birds, "swallows": true,
	})


func _fly(delta: float, t: float) -> void:
	for f in _flocks:
		var node: Node3D = f["node"]
		var a: float = f["phase"] + t * float(f["speed"])
		var r: float = f["radius"] * (0.8 + 0.2 * sin(t * 0.07 + float(f["phase"])))
		var centre: Vector3 = f["centre"]
		node.position = centre + Vector3(cos(a) * r, sin(t * 0.09 + float(f["phase"])) * 8.0, sin(a) * r)
		node.rotation.y = -a  # lead with the beak, banking into the turn
		node.rotation.z = sin(t * 0.09 + float(f["phase"])) * 0.25
		var i := 0
		for b in f["birds"]:
			i += 1
			if f.get("swallows", false):
				# Swallows do not glide in circles: they jink after flies.
				var j: float = float(b.get_meta("jink"))
				b.position = Vector3(
					sin(t * (1.7 + j * 0.02) + j) * 17.0,
					sin(t * (1.1 + j * 0.01) + j * 2.0) * 3.0,
					cos(t * (1.3 + j * 0.03) + j * 1.5) * 17.0)
				b.rotation.y = t * (1.3 + j * 0.03) + j * 1.5
				b.rotation.z = sin(t * 2.6 + j) * 0.7   # banking hard
				b.get_node("L").rotation.z = sin(t * 11.0 + j) * 0.7
				b.get_node("R").rotation.z = -sin(t * 11.0 + j) * 0.7
				continue
			# Each bird flaps at its own rate, with glides between.
			var flap := sin(t * (5.5 + float(i % 5) * 0.7) + float(i))
			var beat := maxf(flap, -0.3) * 0.5
			b.get_node("L").rotation.z = beat
			b.get_node("R").rotation.z = -beat
			b.position.y += sin(t * 0.8 + float(i)) * delta * 0.4


static func _bird(colour: Color) -> Node3D:
	## Two swept wings and a body: a silhouette, seen from below at a distance.
	var b := Node3D.new()
	b.add_child(Props.box(Vector3(0.18, 0.14, 0.75), colour, Vector3(0, 0, 0)))
	for side in [["L", 1.0], ["R", -1.0]]:
		var pivot := Node3D.new()
		pivot.name = side[0]
		b.add_child(pivot)
		var wing := Props.box(Vector3(1.05, 0.04, 0.34), colour, Vector3(float(side[1]) * 0.55, 0, -0.05))
		wing.rotation_degrees.y = float(side[1]) * -14.0  # swept back
		pivot.add_child(wing)
	for c in b.find_children("*", "GeometryInstance3D", true, false):
		var g := c as GeometryInstance3D
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		g.visibility_range_end = 500.0
	return b


# ---------------------------------------------------------------- waders


func _place_waders() -> void:
	## Herons and egrets standing in the shallows. The Corps shot a great egret at
	## this very place on 2 August 1804, and found herons in numbers upriver.
	var placed := 0
	for attempt in 3000:
		if placed >= 5:
			break
		var p := Vector3(_rng.randf_range(40, 980), 0, _rng.randf_range(40, 980))
		var edge := terrain.river_distance(p.x, p.z) - terrain.river_half_width()
		# Standing in the margin: water at their feet, not out in the channel.
		if edge > 1.0 or edge < -7.0:
			continue
		p.y = Terrain.WATER_Y - 0.35
		var bird := _wader(_rng.randf() < 0.4)
		bird.position = p
		bird.rotation.y = _rng.randf() * TAU
		add_child(bird)
		_waders.append({"node": bird, "home": p, "phase": _rng.randf() * 100.0, "flight": 0.0})
		placed += 1


func _wade(delta: float, t: float) -> void:
	var leader := watch.global_position if watch else Vector3.INF
	for w in _waders:
		var n: Node3D = w["node"]
		var ph: float = w["phase"]
		var flight: float = w["flight"]
		var home: Vector3 = w["home"]
		if shy and flight <= 0.0 and Vector2(n.position.x - leader.x, n.position.z - leader.z).length() < 26.0:
			w["flight"] = 9.0  # up and away, with a slow heavy wingbeat
			n.rotation.y = atan2(n.position.x - leader.x, n.position.z - leader.z)
		if flight > 0.0:
			w["flight"] = flight - delta
			var gone := 9.0 - flight
			n.position += -n.global_transform.basis.z * delta * 7.0
			n.position.y = home.y + minf(gone * 2.2, 14.0) * (1.0 if flight > 1.0 else 0.0)
			var beat := sin(t * 5.0) * 0.55
			n.get_node("WingL").rotation.z = beat
			n.get_node("WingR").rotation.z = -beat
			n.get_node("Neck").rotation.x = deg_to_rad(-70.0)  # neck folded back in flight
			if flight - delta <= 0.0:
				# Come down again somewhere else along the margin.
				n.position = home
				n.rotation.y = _rng.randf() * TAU
				n.get_node("Neck").rotation.x = 0.0
		else:
			# Standing: the neck moves, now and then a step, and a stab at the water.
			var stab: float = maxf(sin(t * 0.23 + ph) - 0.93, 0.0) * 14.0
			n.get_node("Neck").rotation.x = deg_to_rad(lerpf(-8.0, 62.0, clampf(stab, 0.0, 1.0)))
			n.position.y = home.y + sin(t * 0.7 + ph) * 0.01
			n.rotation.y += sin(t * 0.11 + ph * 2.0) * delta * 0.25
			for wing in ["WingL", "WingR"]:
				n.get_node(wing).rotation.z = 0.0


static func _wader(egret: bool) -> Node3D:
	## A heron or an egret: long legs, a deep body, wings folded along it, a neck
	## that folds and straightens, and a dagger of a bill.
	var plumage := Color(0.90, 0.89, 0.85) if egret else Color(0.52, 0.56, 0.62)
	var dark := plumage.darkened(0.3)
	var b := Node3D.new()
	for side in [-0.07, 0.07]:
		b.add_child(Props.cylinder(0.016, 0.66, Color(0.30, 0.27, 0.20), Vector3(side, 0.33, 0)))
		# Backward-bending hock, as a wading bird's leg does.
		var shin := Props.cylinder(0.014, 0.2, Color(0.30, 0.27, 0.20), Vector3(side, 0.08, 0.06))
		shin.rotation_degrees.x = 22.0
		b.add_child(shin)
	# A deep body, tail sloping down behind.
	b.add_child(_blob(Vector3(0.26, 0.3, 0.66), plumage, Vector3(0, 0.76, -0.02)))
	var tail := _blob(Vector3(0.16, 0.12, 0.3), dark, Vector3(0, 0.72, -0.4))
	tail.rotation_degrees.x = 18.0
	b.add_child(tail)
	# Wings folded flat along the body, not held out like arms.
	for w in [["WingL", 1.0], ["WingR", -1.0]]:
		var pivot := Node3D.new()
		pivot.name = w[0]
		pivot.position = Vector3(float(w[1]) * 0.1, 0.8, -0.02)
		b.add_child(pivot)
		var wing := _blob(Vector3(0.07, 0.24, 0.62), dark, Vector3(float(w[1]) * 0.02, -0.02, -0.04))
		pivot.add_child(wing)
	var neck := Node3D.new()
	neck.name = "Neck"
	neck.position = Vector3(0, 0.88, 0.18)
	b.add_child(neck)
	# Long and thin, leaning a little forward over the water.
	var column := _blob(Vector3(0.085, 0.56, 0.1), plumage, Vector3(0, 0.26, 0.03))
	column.rotation_degrees.x = 8.0
	neck.add_child(column)
	var head := _blob(Vector3(0.1, 0.12, 0.2), plumage, Vector3(0, 0.55, 0.1))
	neck.add_child(head)
	if not egret:
		# The heron's black head plume.
		var plume := _blob(Vector3(0.04, 0.05, 0.22), Color(0.12, 0.12, 0.14), Vector3(0, 0.58, -0.02))
		neck.add_child(plume)
	var bill := Props.cylinder(0.014, 0.26, Color(0.86, 0.76, 0.32), Vector3(0, 0.55, 0.28), 0.002)
	bill.rotation_degrees.x = 86.0
	neck.add_child(bill)
	for c in b.find_children("*", "GeometryInstance3D", true, false):
		var g := c as GeometryInstance3D
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		g.visibility_range_end = 420.0
	return b

