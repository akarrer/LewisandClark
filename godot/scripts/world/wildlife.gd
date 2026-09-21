class_name Wildlife
extends Node3D
## Game seen at a distance: elk grazing the uplands in small herds and deer at
## the woodland edges (Clark noted both around Council Bluff; bison weren't seen
## until late August, further upriver). Scenery only: they drift as they graze,
## lift their heads now and then, and move off if the Leader comes close.

const ELK := Color(0.56, 0.40, 0.25)
const DEER := Color(0.62, 0.44, 0.28)

## Which animals live in a Region, and how many, is the Region's to say (the
## "wildlife" block of its data file, ADR-0014). What stays here is how each
## kind looks, where it keeps, and how it moves. Anything the Region leaves out
## is not placed. Kinds are always placed in the order below.
##
## How each herd animal keeps: the ground it wants, how far from the named places
## it stays, how loosely a group stands, and its size against an elk.
const HERDS := {
	"elk": {"ground": "upland", "clear_of": 140.0, "spread": 16.0, "size": 1.0},
	"deer": {"ground": "edge", "clear_of": 90.0, "spread": 6.0, "size": 0.62},
}
## Every group a Region may ask for, and the fields each one must give.
const GROUPS := {
	"herds": [],
	"flocks": ["count"],
	"waders": ["count"],
	"pelicans": ["on_bar", "afloat"],
	"swallows": ["at", "count"],
	"soarers": ["over", "vultures", "hawks"],
	"river": ["fish_rise_every", "drift_logs"],
}

var terrain: Terrain
var watch: Node3D  # the Leader
var _animals: Array[Dictionary] = []
var _flocks: Array[Dictionary] = []
var _waders: Array[Dictionary] = []
var _pelicans: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
## Off while the autopilot frames scenery shots, so the animals hold still for it.
var shy := true


static func populate(t: Terrain, leader: Node3D) -> Wildlife:
	var w := Wildlife.new()
	w.name = "Wildlife"
	w.terrain = t
	w.watch = leader
	var spec := t.region.wildlife() if t.region != null else {}
	w._rng.seed = int(spec.get("seed", 1804))
	for herd in spec.get("herds", []):
		w._place_herds(herd)
	if spec.has("flocks"):
		w._place_flocks(spec["flocks"])
	if spec.has("waders"):
		w._place_waders(spec["waders"])
	if spec.has("pelicans"):
		w._place_pelicans(spec["pelicans"])
	if spec.has("swallows"):
		w._place_swallows(spec["swallows"])
	if spec.has("soarers"):
		w._place_soarers(spec["soarers"])
	return w


func _place_herds(spec: Dictionary) -> void:
	## Groups of one kind, each kind on its own ground: elk out on open upland,
	## deer in twos and threes where the groves meet open ground. Both well away
	## from the landing and the landmarks.
	var kind := str(spec["kind"])
	var how: Dictionary = HERDS[kind]
	var size: Array = spec["size"]
	var spread := float(how["spread"])
	var placed := 0
	for attempt in 400:
		if placed >= int(spec["groups"]):
			break
		var c := Vector3(_rng.randf_range(40, 980), 0, _rng.randf_range(40, 980))
		if not terrain.walkable(c.x, c.z) or not _keeps_to(c, str(how["ground"])):
			continue
		if _near_points(c, float(how["clear_of"])):
			continue
		for i in _rng.randi_range(int(size[0]), int(size[1])):
			var animal: Node3D
			if kind == "elk":
				animal = quadruped(ELK, i == 0, true)
			else:
				animal = quadruped(DEER, i == 0 and _rng.randf() < 0.5, false)
			_add(animal, c + Vector3(_rng.randf_range(-spread, spread), 0, _rng.randf_range(-spread, spread)), float(how["size"]))
		placed += 1


func _keeps_to(c: Vector3, ground: String) -> bool:
	if ground == "upland":
		return not terrain.is_bottomland(c.x, c.z)
	# The edge: back from the river, where the bottomland groves give out.
	var d := terrain.river_distance(c.x, c.z) - terrain.river_half_width()
	return d >= 60.0 and d <= 180.0


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
	_loaf(delta, t)
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
		# The gait is wound on by how far it has actually walked, so the legs and
		# the ground can never disagree however the speed changes.
		var gait: float = float(a.get("gait", 0.0)) + speed * delta * 2.4
		a["gait"] = gait
		_step_legs(n, gait, speed, fleeing)
		# Head down to graze, up to look around (and up while running).
		var neck: Node3D = n.get_node("Neck")
		var down := 0.0 if fleeing else (1.0 if grazing and sin(t * 0.9 + ph * 3.0) > -0.6 else 0.0)
		neck.rotation.x = lerpf(neck.rotation.x, deg_to_rad(lerpf(-10.0, 62.0, down)), delta * 2.0)
		if fleeing:
			n.position.y += absf(sin(t * 9.0 + ph)) * 0.12
		var tail: Node3D = n.get_node_or_null("Tail")
		if tail != null:
			tail.rotation.x = deg_to_rad(-52.0 if fleeing else 0.0) + sin(t * 1.7 + ph) * 0.12


static func _step_legs(animal: Node3D, gait: float, speed: float, running: bool) -> void:
	## Diagonal pairs together, which is how a walking or trotting animal moves.
	## The lower leg tucks on the way forward and straightens on the drive.
	var swing := clampf(speed / 2.6, 0.0, 1.0) * (0.62 if running else 0.4)
	var legs := ["LegFL", "LegFR", "LegHL", "LegHR"]
	var offsets := [0.0, PI, PI, 0.0]
	for i in 4:
		var hip: Node3D = animal.get_node_or_null(legs[i])
		if hip == null:
			continue
		var phase: float = gait + float(offsets[i])
		hip.rotation.x = sin(phase) * swing
		var knee: Node3D = hip.get_node_or_null("Knee")
		if knee != null:
			knee.rotation.x = -maxf(sin(phase + 0.9), 0.0) * swing * 1.25


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
	# Legs on hips that swing, with a knee below: a straight cylinder nailed to
	# the body is why they looked like they were gliding over the ground.
	for lx in [-0.18, 0.18]:
		for lz in [-0.6, 0.62]:
			var hip := Node3D.new()
			hip.name = "Leg%s%s" % ["F" if lz > 0.0 else "H", "R" if lx > 0.0 else "L"]
			hip.position = Vector3(lx, 1.04, lz)
			a.add_child(hip)
			hip.add_child(Props.cylinder(0.058, 0.54, dark, Vector3(0, -0.27, 0), 0.045))
			var knee := Node3D.new()
			knee.name = "Knee"
			knee.position = Vector3(0, -0.54, 0)
			hip.add_child(knee)
			knee.add_child(Props.cylinder(0.042, 0.46, dark, Vector3(0, -0.23, 0), 0.028))
			knee.add_child(Props.box(Vector3(0.085, 0.07, 0.14), dark.darkened(0.35), Vector3(0, -0.48, 0.02)))
	# A short tail, carried down until something startles it.
	var tail := Node3D.new()
	tail.name = "Tail"
	tail.position = Vector3(0, 1.32, -0.82)
	a.add_child(tail)
	tail.add_child(_blob(Vector3(0.11, 0.26, 0.11), coat.darkened(0.2), Vector3(0, -0.12, -0.02)))
	var neck := Node3D.new()
	neck.name = "Neck"
	neck.position = Vector3(0, 1.45, 0.8)
	a.add_child(neck)
	var n := _blob(Vector3(0.3, 0.72, 0.34), dark.lightened(0.15), Vector3(0, 0.32, 0.12))
	n.rotation_degrees.x = 30.0
	neck.add_child(n)
	var head := _blob(Vector3(0.24, 0.26, 0.5), coat, Vector3(0, 0.68, 0.36))
	neck.add_child(head)
	var muzzle := _blob(Vector3(0.15, 0.16, 0.26), coat.darkened(0.22), Vector3(0, 0.63, 0.6))
	neck.add_child(muzzle)
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


func _place_flocks(spec: Dictionary) -> void:
	## Birds wheeling over the river and the bluffs: too far off to identify,
	## which is what you see of them from the ground.
	for f in int(spec["count"]):
		var centre := Vector3(_rng.randf_range(200, 800), 0, _rng.randf_range(200, 800))
		centre.y = terrain.height_at(centre.x, centre.z) + _rng.randf_range(40, 90)
		var flock := Node3D.new()
		flock.name = "Flock%d" % f
		add_child(flock)
		var birds: Array[Node3D] = []
		for i in _rng.randi_range(4, 8):
			var b := _bird(Color(0.12, 0.11, 0.10) if f % 2 == 0 else Color(0.35, 0.33, 0.30))
			b.position = Vector3(_rng.randf_range(-22, 22), _rng.randf_range(-6, 6), _rng.randf_range(-22, 22))
			flock.add_child(b)
			birds.append(b)
		_flocks.append({
			"node": flock, "centre": centre, "radius": _rng.randf_range(60, 130),
			"speed": _rng.randf_range(0.05, 0.11), "phase": _rng.randf() * TAU, "birds": birds,
		})


func _place_swallows(spec: Dictionary) -> void:
	## Cliff swallows hawking low over the water under the bluff. They nest in
	## the loess itself; the Corps found their nests all along these banks.
	if not terrain.points.has(str(spec["at"])):
		return
	var under_bluff: Vector3 = terrain.points[str(spec["at"])]
	# Close under the rim, where the nests are, rather than away over the water.
	var centre := under_bluff + terrain.toward_river(under_bluff.x, under_bluff.z) * 20.0
	centre.y = maxf(under_bluff.y - 3.0, Terrain.WATER_Y + 4.0)
	var flock := Node3D.new()
	flock.name = "Swallows"
	add_child(flock)
	var birds: Array[Node3D] = []
	# Nine, not sixteen, and over half again the ground: a knot of them hawking
	# under the rim reads as a swarm of flies at anything under fifty yards.
	for i in int(spec["count"]):
		var b := _bird(Color(0.16, 0.15, 0.20))
		b.scale = Vector3.ONE * 0.45          # a swallow is a handful of nothing
		b.position = Vector3(_rng.randf_range(-26, 26), _rng.randf_range(-4, 4), _rng.randf_range(-26, 26))
		b.set_meta("jink", _rng.randf() * 100.0)
		flock.add_child(b)
		birds.append(b)
	_flocks.append({
		"node": flock, "centre": centre, "radius": 34.0, "speed": 0.4,
		"phase": _rng.randf() * TAU, "birds": birds, "swallows": true,
	})


func _place_soarers(spec: Dictionary) -> void:
	## Turkey vultures over the bluffs and a hawk hunting the prairie. They ride
	## the thermal off the loess face for an hour at a time without a wingbeat,
	## holding the wings up in a shallow V and rocking from side to side, which
	## is how you tell a vulture from a hawk when it is only a shape in the sky.
	if not terrain.points.has(str(spec["over"])):
		return
	var bluff: Vector3 = terrain.points[str(spec["over"])]
	var vultures := int(spec["vultures"])
	for i in vultures + int(spec["hawks"]):
		var vulture := i < vultures
		var centre := bluff + Vector3(_rng.randf_range(-170, 170), 0, _rng.randf_range(-170, 170))
		centre.y = terrain.height_at(centre.x, centre.z) + _rng.randf_range(65, 125)
		var node := Node3D.new()
		node.name = "Soarer%d" % i
		add_child(node)
		var bird := _raptor(vulture)
		node.add_child(bird)
		var one: Array[Node3D] = [bird]
		_flocks.append({
			"node": node, "centre": centre, "radius": _rng.randf_range(38, 75),
			"speed": _rng.randf_range(0.05, 0.095), "phase": _rng.randf() * TAU,
			"birds": one, "soar": true, "dihedral": 0.3 if vulture else 0.05,
		})


static func _raptor(vulture: bool) -> Node3D:
	## Seen from underneath at a few hundred feet: a body, long broad wings with
	## the primaries spread like fingers at the tip, and a fanned tail.
	var colour := Color(0.11, 0.10, 0.10) if vulture else Color(0.30, 0.24, 0.18)
	var b := Node3D.new()
	b.add_child(Props.box(Vector3(0.16, 0.14, 0.62), colour, Vector3.ZERO))
	b.add_child(Props.box(Vector3(0.34 if vulture else 0.26, 0.03, 0.26 if vulture else 0.42),
			colour.lightened(0.08), Vector3(0, 0, -0.45)))
	for side in [["L", 1.0], ["R", -1.0]]:
		var pivot := Node3D.new()
		pivot.name = side[0]
		b.add_child(pivot)
		var sx := float(side[1])
		pivot.add_child(Props.box(Vector3(0.72, 0.035, 0.34), colour, Vector3(sx * 0.4, 0, -0.02)))
		for k in 4:
			var finger := Props.box(Vector3(0.34, 0.025, 0.07), colour,
					Vector3(sx * 0.92, 0, -0.14 + k * 0.1))
			finger.rotation_degrees.y = sx * (-14.0 + k * 8.0)
			pivot.add_child(finger)
	for c in b.find_children("*", "GeometryInstance3D", true, false):
		var g := c as GeometryInstance3D
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		g.visibility_range_end = 900.0
	return b


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
					sin(t * (1.7 + j * 0.02) + j) * 26.0,
					sin(t * (1.1 + j * 0.01) + j * 2.0) * 4.5,
					cos(t * (1.3 + j * 0.03) + j * 1.5) * 26.0)
				b.rotation.y = t * (1.3 + j * 0.03) + j * 1.5
				b.rotation.z = sin(t * 2.6 + j) * 0.7   # banking hard
				b.get_node("L").rotation.z = sin(t * 11.0 + j) * 0.7
				b.get_node("R").rotation.z = -sin(t * 11.0 + j) * 0.7
				continue
			if f.get("soar", false):
				# No wingbeat at all: the V is held and the whole bird rocks.
				var dih: float = f["dihedral"]
				var rock := sin(t * 0.5 + float(f["phase"])) * 0.15
				b.get_node("L").rotation.z = dih + rock
				b.get_node("R").rotation.z = -dih + rock
				b.rotation.z = rock * 1.6
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


func _place_pelicans(spec: Dictionary) -> void:
	## A raft of white pelicans loafing on a bar. On 8 August 1804, a little above
	## here, the Corps came on "a flock of several hundred" of them, and Lewis
	## poured water into a dead one's pouch to measure it: five gallons.
	var bar := Vector3.INF
	for attempt in 6000:
		var p := Vector3(_rng.randf_range(60, 960), 0, _rng.randf_range(60, 960))
		# Out on the dry sand of a bar, off the grass and well away from the camp.
		if terrain.height_at(p.x, p.z) < Terrain.WATER_Y - 0.2:
			continue
		var edge := terrain.river_distance(p.x, p.z) - terrain.river_half_width()
		if edge > 2.0 or edge < -30.0 or _near_points(p, 60.0):
			continue
		bar = Vector3(p.x, terrain.height_at(p.x, p.z), p.z)
		break
	if bar == Vector3.INF:
		return
	var heading := _rng.randf() * TAU
	for i in int(spec["on_bar"]):
		var a := _rng.randf() * TAU
		var r := sqrt(_rng.randf()) * 7.5
		var p := bar + Vector3(cos(a) * r, 0, sin(a) * r)
		p.y = maxf(terrain.height_at(p.x, p.z), Terrain.WATER_Y - 0.28)
		var bird := _pelican()
		bird.name = "Pelican%d" % i
		bird.position = p
		# A loafing flock nearly all faces the same way, into the wind.
		bird.rotation.y = heading + _rng.randf_range(-0.6, 0.6)
		add_child(bird)
		_pelicans.append({"node": bird, "home": p, "phase": _rng.randf() * 100.0, "flight": 0.0,
				"preen": _rng.randf_range(0.2, 1.4)})
	# And a few off the bar on the water, riding high the way they do.
	var toward := terrain.toward_river(bar.x, bar.z)
	for i in int(spec["afloat"]):
		var p := bar + toward * (14.0 + i * 5.0) + Vector3(_rng.randf_range(-5, 5), 0, _rng.randf_range(-5, 5))
		p.y = Terrain.WATER_Y - 0.62      # body riding on the surface, legs under it
		var bird := _pelican()
		bird.name = "PelicanSwim%d" % i
		bird.position = p
		bird.rotation.y = heading + _rng.randf_range(-1.2, 1.2)
		add_child(bird)
		_pelicans.append({"node": bird, "home": p, "phase": _rng.randf() * 100.0, "flight": 0.0,
				"preen": _rng.randf_range(0.2, 1.4)})


func _loaf(delta: float, t: float) -> void:
	## Standing about, turning the head, preening down onto the back; and away in
	## a line if a man walks up on the bar.
	var leader := watch.global_position if watch else Vector3.INF
	for i in _pelicans.size():
		var w: Dictionary = _pelicans[i]
		var n: Node3D = w["node"]
		var ph: float = w["phase"]
		var flight: float = w["flight"]
		var home: Vector3 = w["home"]
		if shy and flight <= 0.0 and Vector2(n.position.x - leader.x, n.position.z - leader.z).length() < 30.0:
			# They go up raggedly, one after another, not all at once.
			w["flight"] = 11.0 - i * 0.22
			n.rotation.y = atan2(n.position.x - leader.x, n.position.z - leader.z)
		if flight > 0.0:
			w["flight"] = flight - delta
			var gone := (11.0 - i * 0.22) - flight
			n.position += -n.global_transform.basis.z * delta * 8.0
			n.position.y = home.y + minf(maxf(gone, 0.0) * 1.9, 18.0)
			var beat := sin(t * 3.4 + ph) * 0.5
			n.get_node("WingL").rotation.z = beat
			n.get_node("WingR").rotation.z = -beat
			n.get_node("Neck").rotation.x = deg_to_rad(-26.0)
			if flight - delta <= 0.0:
				n.position = home
				n.rotation.y = _rng.randf() * TAU
				n.get_node("Neck").rotation.x = 0.0
		else:
			var preen: float = maxf(sin(t * 0.17 + ph) - float(w["preen"]) * 0.5, 0.0) * 9.0
			n.get_node("Neck").rotation.x = deg_to_rad(lerpf(-4.0, 96.0, clampf(preen, 0.0, 1.0)))
			n.rotation.y += sin(t * 0.09 + ph * 1.7) * delta * 0.18
			n.position.y = home.y + sin(t * 0.5 + ph) * 0.006
			for wing in ["WingL", "WingR"]:
				n.get_node(wing).rotation.z = 0.0


static func _pelican() -> Node3D:
	## Heavy and low: a deep white body, short black-tipped wings folded along it,
	## a thick neck set back on the shoulders and a great pouched bill.
	var white := Color(0.94, 0.93, 0.90)
	var black := Color(0.16, 0.16, 0.18)
	var bill_colour := Color(0.92, 0.66, 0.22)
	var b := Node3D.new()
	for side in [-0.09, 0.09]:
		b.add_child(Props.cylinder(0.022, 0.2, bill_colour.darkened(0.35), Vector3(side, 0.1, 0)))
		b.add_child(_blob(Vector3(0.09, 0.04, 0.16), bill_colour.darkened(0.35), Vector3(side, 0.02, 0.06)))
	b.add_child(_blob(Vector3(0.34, 0.34, 0.86), white, Vector3(0, 0.36, 0)))
	var tail := _blob(Vector3(0.18, 0.1, 0.24), white.darkened(0.08), Vector3(0, 0.34, -0.5))
	tail.rotation_degrees.x = 14.0
	b.add_child(tail)
	for w in [["WingL", 1.0], ["WingR", -1.0]]:
		var pivot := Node3D.new()
		pivot.name = w[0]
		pivot.position = Vector3(float(w[1]) * 0.13, 0.4, -0.04)
		b.add_child(pivot)
		pivot.add_child(_blob(Vector3(0.08, 0.2, 0.74), white, Vector3(0, 0.0, -0.06)))
		# Black primaries showing at the folded tip, which is how you know the bird.
		pivot.add_child(_blob(Vector3(0.07, 0.13, 0.26), black, Vector3(0, -0.02, -0.42)))
	var neck := Node3D.new()
	neck.name = "Neck"
	neck.position = Vector3(0, 0.5, 0.26)
	b.add_child(neck)
	var column := _blob(Vector3(0.15, 0.3, 0.17), white, Vector3(0, 0.13, 0.0))
	column.rotation_degrees.x = 10.0
	neck.add_child(column)
	var head := _blob(Vector3(0.14, 0.15, 0.2), white, Vector3(0, 0.3, 0.06))
	neck.add_child(head)
	# The bill: a long upper mandible with the pouch slung beneath it.
	var upper := Props.cylinder(0.02, 0.56, bill_colour, Vector3(0, 0.3, 0.36), 0.008)
	upper.rotation_degrees.x = 94.0
	neck.add_child(upper)
	var pouch := _blob(Vector3(0.1, 0.13, 0.44), bill_colour.darkened(0.2), Vector3(0, 0.24, 0.36))
	pouch.rotation_degrees.x = 5.0
	neck.add_child(pouch)
	for c in b.find_children("*", "GeometryInstance3D", true, false):
		var g := c as GeometryInstance3D
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		g.visibility_range_end = 380.0
	return b


func _place_waders(spec: Dictionary) -> void:
	## Herons and egrets standing in the shallows. The Corps shot a great egret at
	## this very place on 2 August 1804, and found herons in numbers upriver.
	var placed := 0
	for attempt in 3000:
		if placed >= int(spec["count"]):
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

