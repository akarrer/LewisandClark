class_name Interactable
extends Node3D
## Something the Leader can walk up to and act on. The Leader's nearest one in
## range shows a prompt; pressing interact calls ``on_interact``.

var label := "Interact"
var radius := 4.0
var enabled := true
var on_interact: Callable


func _enter_tree() -> void:
	add_to_group("interactable")


func interact() -> void:
	if enabled and on_interact.is_valid():
		on_interact.call()


# ---------------------------------------------------------------- builders


static func landmark_marker(pos: Vector3, title: String) -> Interactable:
	## A flagstaff with a 15-star banner and a glowing ring on the ground.
	var it := Interactable.new()
	it.name = "Landmark_" + title.replace(" ", "")
	it.position = pos
	it.label = "Visit " + title
	it.radius = 6.0
	it.add_child(Props.cylinder(0.07, 7.0, Color(0.36, 0.26, 0.16), Vector3(0, 3.5, 0)))
	var stripes := Node3D.new()
	stripes.position = Vector3(0.95, 6.3, 0)
	for i in 7:
		var col := Color(0.72, 0.12, 0.12) if i % 2 == 0 else Color(0.93, 0.91, 0.86)
		stripes.add_child(Props.box(Vector3(1.8, 0.14, 0.02), col, Vector3(0, -i * 0.14, 0)))
	stripes.add_child(Props.box(Vector3(0.75, 0.56, 0.03), Color(0.12, 0.18, 0.42), Vector3(-0.52, -0.21, 0)))
	it.add_child(stripes)
	var r := Props.ring(3.0, Color(1.0, 0.8, 0.35))
	r.position.y = 0.15
	it.add_child(r)
	return it


static func prairie_dog_town(pos: Vector3, terrain: Terrain) -> Node3D:
	var town := Node3D.new()
	town.name = "PrairieDogTown"
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 16:
		var off := Vector3(rng.randf_range(-14, 14), 0, rng.randf_range(-14, 14))
		var p := pos + off
		p.y = terrain.height_at(p.x, p.z)
		town.add_child(Props.sphere(0.9, Color(0.56, 0.44, 0.30), p, Vector3(1.2, 0.35, 1.2)))
		var dog := Node3D.new()
		dog.name = "Dog%d" % i
		dog.position = p + Vector3(0.15, 0.1, 0)
		dog.add_child(Props.cylinder(0.09, 0.32, Color(0.66, 0.52, 0.34), Vector3(0, 0.16, 0), 0.07))
		dog.add_child(Props.sphere(0.07, Color(0.62, 0.48, 0.32), Vector3(0, 0.36, 0.02)))
		dog.set_meta("phase", rng.randf() * TAU)
		dog.set_meta("base_y", dog.position.y)
		town.add_child(dog)
	return town


static func animate_prairie_dogs(town: Node3D, time: float, alarmed: bool) -> void:
	for c in town.get_children():
		if c.has_meta("phase"):
			var up := sin(time * 0.7 + float(c.get_meta("phase")))
			var h := -0.35 if alarmed else (0.0 if up > -0.2 else -0.35)
			c.position.y = lerpf(c.position.y, float(c.get_meta("base_y")) + h, 0.15)


static func elk(color := Color(0.50, 0.36, 0.22)) -> Node3D:
	var e := Node3D.new()
	var dark := color.darkened(0.35)
	e.add_child(Props.box(Vector3(0.7, 0.75, 1.9), color, Vector3(0, 1.35, 0)))
	e.add_child(Props.box(Vector3(0.36, 0.9, 0.36), dark, Vector3(0, 1.85, 0.9)))
	e.get_child(1).rotation_degrees.x = -35.0
	e.add_child(Props.box(Vector3(0.3, 0.3, 0.6), color, Vector3(0, 2.25, 1.35)))
	for side in [-0.2, 0.2]:
		var antler := Props.cylinder(0.03, 0.9, Color(0.82, 0.76, 0.62), Vector3(side, 2.75, 1.2))
		antler.rotation_degrees = Vector3(-20, 0, side * 120.0)
		e.add_child(antler)
	for lx in [-0.25, 0.25]:
		for lz in [-0.7, 0.7]:
			e.add_child(Props.cylinder(0.06, 1.0, dark, Vector3(lx, 0.5, lz)))
	return e
