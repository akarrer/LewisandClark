class_name CorpsFigure
extends CharacterBody3D
## A walking member of the Corps: the Quaternius mannequin (placeholder until the
## commissioned characters), tinted per person, with locomotion animations that
## follow the body's ground speed.

const LIBRARY := "res://assets/third_party/animation/universal_animation_library_standard/Animation Library[Standard]/Godot/AnimationLibrary_Godot_Standard.glb"
const GRAVITY := 18.0

var key := ""
var display_name := ""
var coat := Color(0.3, 0.35, 0.5)
var hat := true
var model: Node3D
var anim: AnimationPlayer
var _current_anim := ""
var _face_dir := Vector3.FORWARD

## Each person's own way of moving, fixed per key (see _init_gait): stride length
## sets cadence (long legs step slower), height scales the body, phase keeps
## their walk cycle out of step with everyone else's.
var stride := 1.0
var height := 1.0
var phase := 0.0
var gait_rng := RandomNumberGenerator.new()
## Build overrides: York was described as a tall, strongly built man.
const BUILDS := {"york": {"height": 1.07, "stride": 1.1}, "lewis": {"height": 1.02}}

## Period dress per person for outfit.gdshader (placeholder until commissioned models).
## Unlisted keys get the enlisted man's kit in their own coat colour.
const OUTFITS := {
	"lewis": {"cut": "coat", "cocked": true, "hair": Color(0.36, 0.25, 0.15), "coat": Color(0.13, 0.17, 0.30), "facing": Color(0.55, 0.13, 0.11), "breeches": Color(0.72, 0.64, 0.46), "legs": Color(0.10, 0.08, 0.07)},
	"clark": {"hair": Color(0.55, 0.26, 0.12), "facing": Color(0.30, 0.22, 0.14), "waistcoat": Color(0.70, 0.62, 0.48), "legs": Color(0.36, 0.27, 0.18), "skin": Color(0.84, 0.64, 0.52)},
	"york": {"queue": false, "hair": Color(0.08, 0.06, 0.05), "facing": Color(0.22, 0.17, 0.13), "breeches": Color(0.34, 0.30, 0.24), "legs": Color(0.24, 0.18, 0.13), "skin": Color(0.30, 0.20, 0.15)},
	"drouillard": {"queue": false, "hair": Color(0.07, 0.06, 0.05), "facing": Color(0.52, 0.40, 0.27), "waistcoat": null, "breeches": Color(0.50, 0.40, 0.27), "legs": Color(0.46, 0.36, 0.24), "skin": Color(0.62, 0.45, 0.33)},
	# A French trader living among the Oto: a trade coat gone brown, leggings.
	"trader": {"cut": "coat", "queue": false, "hair": Color(0.20, 0.14, 0.09), "coat": Color(0.36, 0.27, 0.18), "facing": Color(0.30, 0.22, 0.15), "waistcoat": null, "breeches": Color(0.46, 0.37, 0.25), "legs": Color(0.42, 0.33, 0.22), "skin": Color(0.78, 0.58, 0.45)},
	"messenger": {"cut": "shirt", "hair": Color(0.05, 0.05, 0.05), "facing": Color(0.62, 0.18, 0.14), "waistcoat": null, "stock": null, "breeches": Color(0.48, 0.38, 0.26), "legs": Color(0.44, 0.34, 0.23), "skin": Color(0.58, 0.40, 0.29)},
}


func setup(p_key: String, p_name: String, p_coat: Color, p_hat := true) -> void:
	key = p_key
	display_name = p_name
	coat = p_coat
	hat = p_hat


func _ready() -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.8
	shape.shape = capsule
	shape.position.y = 0.9
	add_child(shape)
	# The Corps walk through one another rather than shoving (layer 2, colliding
	# only with the world on layer 1), so a man standing still never blocks the Leader.
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.6
	floor_max_angle = deg_to_rad(52.0)

	model = (load(LIBRARY) as PackedScene).instantiate()
	add_child(model)
	_init_gait()
	model.rotation.y = PI  # the mannequin faces +Z; start facing north (-Z)
	model.scale = Vector3.ONE * height
	anim = model.find_children("*", "AnimationPlayer", true, false)[0]
	var mesh: MeshInstance3D = model.find_children("*", "MeshInstance3D", true, false)[0]
	# Cloth over the mannequin's muscles, and the skirt of his frock or coat.
	mesh.mesh = Clothes.dress(mesh.mesh, _cut())
	var outfit := _outfit_material()
	for s in mesh.mesh.get_surface_count():
		mesh.set_surface_override_material(s, outfit)
	var skeleton: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
	skeleton.add_child(RelaxedHands.new())
	if hat:
		_add_hat(skeleton)
	_add_rifle(skeleton)
	_add_accoutrements(skeleton)
	play("Idle")


func _outfit() -> Dictionary:
	return OUTFITS.get(key, OUTFITS["messenger"] if key.begins_with("messenger") else {})


func _cut() -> String:
	## A hunting frock unless the outfit says otherwise (see Clothes.CUTS).
	return str(_outfit().get("cut", "frock"))


func _outfit_material() -> ShaderMaterial:
	var o: Dictionary = _outfit()
	var skin: Color = o.get("skin", Color(0.82, 0.63, 0.51))
	var m := ShaderMaterial.new()
	m.shader = preload("res://scripts/player/outfit.gdshader")
	m.set_shader_parameter("coat", o.get("coat", coat))
	m.set_shader_parameter("facing", o.get("facing", coat.darkened(0.35)))
	m.set_shader_parameter("breeches", o.get("breeches", Color(0.52, 0.43, 0.30)))
	m.set_shader_parameter("legs", o.get("legs", Color(0.32, 0.25, 0.17)))
	m.set_shader_parameter("skin", skin)
	m.set_shader_parameter("hair", o.get("hair", Color(0.28, 0.19, 0.12)))
	# null means "none": no waistcoat under a hunting shirt, bare throat instead of a stock.
	var vest = o.get("waistcoat", Color(0.80, 0.76, 0.66))
	m.set_shader_parameter("has_waistcoat", 0.0 if vest == null else 1.0)
	if vest != null:
		m.set_shader_parameter("waistcoat", vest)
	var stock = o.get("stock", Color(0.88, 0.86, 0.80))
	m.set_shader_parameter("stock", skin if stock == null else stock)
	var cut: Dictionary = Clothes.CUTS.get(_cut(), Clothes.CUTS["frock"])
	m.set_shader_parameter("hem", float(cut["hem"]))
	m.set_shader_parameter("open_front", 1.0 if float(cut["open"]) > 0.0 else 0.0)
	return m


func _hang(skeleton: Skeleton3D, bone: String, at: Transform3D, part: Node3D) -> void:
	## Hang ``part`` on ``bone``, placed where ``at`` puts it in the body's rest
	## pose (the mannequin's own space: +Z forward, +X its left), so the offsets
	## below read as positions on the body and not in each bone's own axes.
	var attach := BoneAttachment3D.new()
	attach.bone_name = bone
	skeleton.add_child(attach)
	var b := skeleton.find_bone(bone)
	part.transform = skeleton.get_bone_global_rest(b).affine_inverse() * at
	attach.add_child(part)
	for c in part.find_children("*", "GeometryInstance3D", true, false):
		(c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


func _add_accoutrements(skeleton: Skeleton3D) -> void:
	## What every man of the Corps carried with his rifle: the shot pouch on its
	## belt over the left shoulder, riding his right hip, and the powder horn
	## slung under his left arm.
	var leather := Color(0.33, 0.22, 0.13)
	var pouch := Node3D.new()
	pouch.name = "ShotPouch"
	pouch.add_child(Props.box(Vector3(0.15, 0.17, 0.05), leather, Vector3.ZERO))
	# The flap, a shade darker, over the top half.
	pouch.add_child(Props.box(Vector3(0.155, 0.09, 0.012), leather.darkened(0.25), Vector3(0, 0.045, 0.03)))
	_hang(skeleton, "DEF-hips", Transform3D(Basis(Vector3.UP, deg_to_rad(-55.0)), Vector3(-0.19, 0.86, 0.02)), pouch)
	var horn := Node3D.new()
	horn.name = "PowderHorn"
	var body := Props.cylinder(0.034, 0.26, Color(0.62, 0.52, 0.36), Vector3.ZERO, 0.010)
	body.rotation_degrees.z = 90.0
	horn.add_child(body)
	horn.add_child(_plug())
	var tip := Props.cylinder(0.008, 0.04, Color(0.18, 0.14, 0.10), Vector3(-0.145, 0, 0))
	tip.rotation_degrees.z = 90.0
	horn.add_child(tip)
	# Lying along his side, butt up and back, tip down and forward.
	var lie := Basis(Vector3.UP, deg_to_rad(70.0)) * Basis(Vector3.FORWARD, deg_to_rad(28.0))
	_hang(skeleton, "DEF-spine.001", Transform3D(lie, Vector3(0.165, 0.99, -0.01)), horn)


func _plug() -> MeshInstance3D:
	## The horn's wooden butt plug.
	var p := Props.cylinder(0.037, 0.022, Color(0.36, 0.26, 0.16), Vector3(0.13, 0, 0))
	p.rotation_degrees.z = 90.0
	return p


func _add_rifle(skeleton: Skeleton3D) -> void:
	## A long rifle slung muzzle-up across the back, riding with the upper spine.
	var attach := BoneAttachment3D.new()
	attach.bone_name = "DEF-spine.003"
	skeleton.add_child(attach)
	var rifle := Node3D.new()
	rifle.name = "Rifle"
	attach.add_child(rifle)
	var wood := Color(0.36, 0.22, 0.12)
	var iron := Color(0.16, 0.15, 0.14)
	# Built along +Y, butt at the origin.
	rifle.add_child(Props.box(Vector3(0.045, 0.34, 0.09), wood, Vector3(0, 0.17, 0)))  # butt stock
	rifle.add_child(Props.box(Vector3(0.035, 0.62, 0.045), wood, Vector3(0, 0.62, 0.01)))  # fore stock
	rifle.add_child(Props.cylinder(0.011, 1.05, iron, Vector3(0, 0.82, 0.03)))  # barrel
	rifle.add_child(Props.box(Vector3(0.05, 0.08, 0.03), iron, Vector3(0, 0.38, 0.03)))  # lock
	var sling := Props.box(Vector3(0.012, 0.9, 0.02), Color(0.42, 0.33, 0.22), Vector3(0, 0.62, -0.035))
	rifle.add_child(sling)
	rifle.position = RIFLE_POS
	rifle.rotation_degrees = RIFLE_ROT
	for c in rifle.get_children():
		(c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


const RIFLE_POS := Vector3(0.18, -0.35, -0.14)
const RIFLE_ROT := Vector3(0, 0, 28)
## Off the back and across the chest at the ready, muzzle forward and up.
const RIFLE_READY_POS := Vector3(-0.02, -0.28, 0.3)
const RIFLE_READY_ROT := Vector3(-72, 26, 14)

## 0 slung, 1 in the hands. Lerped rather than switched, so it comes off the
## shoulder rather than teleporting there.
var rifle_out := 0.0


func set_rifle_out(t: float, delta: float) -> void:
	rifle_out = move_toward(rifle_out, clampf(t, 0.0, 1.0), delta * 3.4)
	var rifle: Node3D = _rifle_node()
	if rifle == null:
		return
	var e := rifle_out * rifle_out * (3.0 - 2.0 * rifle_out)
	rifle.position = RIFLE_POS.lerp(RIFLE_READY_POS, e)
	rifle.rotation_degrees = RIFLE_ROT.lerp(RIFLE_READY_ROT, e)


func _rifle_node() -> Node3D:
	for n in find_children("Rifle", "Node3D", true, false):
		return n as Node3D
	return null


func _add_hat(skeleton: Skeleton3D) -> void:
	var attach := BoneAttachment3D.new()
	attach.bone_name = "DEF-head"
	skeleton.add_child(attach)
	var hat_mesh := MeshInstance3D.new()
	hat_mesh.mesh = Hats.build(Hats.style_for(key, bool(_outfit().get("cocked", false))))
	attach.add_child(hat_mesh)
	if _outfit().get("queue", true):
		_add_queue(attach)


func _add_queue(head: Node3D) -> void:
	## The hair drawn back and tied in a queue at the nape with a black ribbon,
	## as the Army still wore it in 1804.
	var hair: Color = _outfit().get("hair", Color(0.28, 0.19, 0.12))
	var tail := Props.cylinder(0.014, 0.13, hair, Vector3(0, 0.03, -0.112), 0.008)
	tail.rotation_degrees.x = -14.0
	head.add_child(tail)
	var ribbon := Props.cylinder(0.018, 0.03, Color(0.05, 0.05, 0.05), Vector3(0, 0.085, -0.104))
	ribbon.rotation_degrees.x = -14.0
	head.add_child(ribbon)


func _init_gait() -> void:
	gait_rng.seed = hash(key)
	var build: Dictionary = BUILDS.get(key, {})
	height = build.get("height", gait_rng.randf_range(0.95, 1.04))
	stride = build.get("stride", gait_rng.randf_range(0.86, 1.14) * lerpf(1.0, height, 0.8))
	phase = gait_rng.randf()


func play(name: String, blend := 0.25) -> void:
	if name != _current_anim and anim.has_animation(name):
		anim.play(name, blend)
		# Start each cycle at this person's own point, so no two stride in step.
		anim.seek(fposmod(phase + Time.get_ticks_msec() * 0.0007, 1.0) * anim.current_animation_length, false)
		_current_anim = name


## How quickly he gets under way and pulls up, in metres per second per second.
const ACCEL := 15.0
const BRAKE := 19.0


func apply_locomotion(move_velocity: Vector3, delta: float) -> void:
	## Move with gravity, face the direction of travel, and pick the animation.
	##
	## Eased into and out of rather than set outright. A man does not reach a jog
	## in one frame or stop dead in the next, and driving the velocity straight
	## off the keys made the whole thing feel like a cursor.
	var going := Vector3(velocity.x, 0.0, velocity.z)
	var want := Vector3(move_velocity.x, 0.0, move_velocity.z)
	var rate := ACCEL if want.length() > going.length() else BRAKE
	var eased := going.move_toward(want, rate * delta)
	velocity.x = eased.x
	velocity.z = eased.z
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = -1.0
	move_and_slide()

	var flat := Vector3(velocity.x, 0, velocity.z)
	var speed := flat.length()
	if speed > 0.2:
		_face_dir = _face_dir.slerp(flat.normalized(), clampf(delta * 10.0, 0.0, 1.0)).normalized()
		model.look_at(model.global_position - _face_dir, Vector3.UP)
	if speed < 0.25:
		play("Idle")
		anim.speed_scale = 1.0
	elif speed < 2.4 * stride:
		play("Walk")
		anim.speed_scale = speed / (1.6 * stride)
	elif speed < 5.0 * stride:
		play("Jog_Fwd")
		anim.speed_scale = speed / (3.8 * stride)
	else:
		play("Sprint")
		anim.speed_scale = speed / (6.0 * stride)


func ground_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()
