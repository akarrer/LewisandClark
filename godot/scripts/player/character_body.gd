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
	floor_snap_length = 0.6
	floor_max_angle = deg_to_rad(52.0)

	model = (load(LIBRARY) as PackedScene).instantiate()
	add_child(model)
	model.rotation.y = PI  # the mannequin faces +Z; start facing north (-Z)
	anim = model.find_children("*", "AnimationPlayer", true, false)[0]
	var mesh: MeshInstance3D = model.find_children("*", "MeshInstance3D", true, false)[0]
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = coat
	body_mat.roughness = 0.9
	var joint_mat := StandardMaterial3D.new()
	joint_mat.albedo_color = coat.darkened(0.45)
	joint_mat.roughness = 0.9
	mesh.set_surface_override_material(0, body_mat)
	if mesh.mesh.get_surface_count() > 1:
		mesh.set_surface_override_material(1, joint_mat)
	if hat:
		_add_hat(model.find_children("*", "Skeleton3D", true, false)[0])
	play("Idle")


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


func play(name: String, blend := 0.25) -> void:
	if name != _current_anim and anim.has_animation(name):
		anim.play(name, blend)
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
	elif speed < 2.4:
		play("Walk")
		anim.speed_scale = speed / 1.6
	elif speed < 5.0:
		play("Jog_Fwd")
		anim.speed_scale = speed / 3.8
	else:
		play("Sprint")
		anim.speed_scale = speed / 6.0


func ground_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()
