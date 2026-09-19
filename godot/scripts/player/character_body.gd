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
	"lewis": {"hair": Color(0.36, 0.25, 0.15), "coat": Color(0.13, 0.17, 0.30), "facing": Color(0.55, 0.13, 0.11), "breeches": Color(0.72, 0.64, 0.46), "legs": Color(0.10, 0.08, 0.07)},
	"clark": {"hair": Color(0.55, 0.26, 0.12), "facing": Color(0.30, 0.22, 0.14), "waistcoat": Color(0.70, 0.62, 0.48), "legs": Color(0.36, 0.27, 0.18), "skin": Color(0.84, 0.64, 0.52)},
	"york": {"hair": Color(0.08, 0.06, 0.05), "facing": Color(0.22, 0.17, 0.13), "breeches": Color(0.34, 0.30, 0.24), "legs": Color(0.24, 0.18, 0.13), "skin": Color(0.30, 0.20, 0.15)},
	"drouillard": {"hair": Color(0.07, 0.06, 0.05), "facing": Color(0.52, 0.40, 0.27), "waistcoat": null, "breeches": Color(0.50, 0.40, 0.27), "legs": Color(0.46, 0.36, 0.24), "skin": Color(0.62, 0.45, 0.33)},
	"messenger": {"hair": Color(0.05, 0.05, 0.05), "facing": Color(0.62, 0.18, 0.14), "waistcoat": null, "stock": null, "breeches": Color(0.48, 0.38, 0.26), "legs": Color(0.44, 0.34, 0.23), "skin": Color(0.58, 0.40, 0.29)},
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
	var outfit := _outfit_material()
	for s in mesh.mesh.get_surface_count():
		mesh.set_surface_override_material(s, outfit)
	var skeleton: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
	if hat:
		_add_hat(skeleton)
	_add_rifle(skeleton)
	play("Idle")


func _outfit_material() -> ShaderMaterial:
	var o: Dictionary = OUTFITS.get(key, OUTFITS["messenger"] if key.begins_with("messenger") else {})
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
	return m


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


func _add_hat(skeleton: Skeleton3D) -> void:
	var attach := BoneAttachment3D.new()
	attach.bone_name = "DEF-head"
	skeleton.add_child(attach)
	var felt := StandardMaterial3D.new()
	felt.albedo_color = Color(0.12, 0.10, 0.09)
	felt.roughness = 1.0
	var brim := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.2; bm.bottom_radius = 0.2; bm.height = 0.02
	brim.mesh = bm
	brim.material_override = felt
	brim.position = Vector3(0, 0.2, 0)
	attach.add_child(brim)
	var crown := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.1; cm.bottom_radius = 0.12; cm.height = 0.14
	crown.mesh = cm
	crown.material_override = felt
	crown.position = Vector3(0, 0.27, 0)
	attach.add_child(crown)


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


func apply_locomotion(move_velocity: Vector3, delta: float) -> void:
	## Move with gravity, face the direction of travel, and pick the animation.
	velocity.x = move_velocity.x
	velocity.z = move_velocity.z
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
