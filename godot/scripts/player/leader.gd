class_name Leader
extends CorpsFigure
## The Leader (Lewis): third-person movement relative to an orbiting camera.

const WALK := 1.7
const JOG := 4.0
const SPRINT := 6.4

var camera_rig: Node3D
var camera: Camera3D
var _yaw := 0.0
var _pitch := -12.0
var spring: SpringArm3D
var input_enabled := true
## Off while the autopilot frames shots, so a stray mouse or stick can't move the camera.
var look_enabled := true

## Breadcrumbs for the Corps following behind (newest last), one per 0.4 m.
var trail: Array[Vector3] = []


func _ready() -> void:
	super._ready()
	camera_rig = Node3D.new()
	camera_rig.name = "CameraRig"
	camera_rig.top_level = true
	add_child(camera_rig)
	var pitch_node := Node3D.new()
	pitch_node.name = "Pitch"
	camera_rig.add_child(pitch_node)
	spring = SpringArm3D.new()
	spring.spring_length = 4.6
	spring.margin = 0.3
	spring.position = Vector3(0.55, 0.0, 0.0)
	spring.shape = SphereShape3D.new()
	(spring.shape as SphereShape3D).radius = 0.25
	spring.add_excluded_object(get_rid())
	pitch_node.add_child(spring)
	camera = Camera3D.new()
	camera.fov = 62.0
	camera.far = 1600.0
	spring.add_child(camera)
	camera_rig.global_position = global_position + Vector3(0, 1.6, 0)
	trail.append(global_position)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and look_enabled:
		_yaw -= event.relative.x * 0.12
		_pitch = clampf(_pitch - event.relative.y * 0.1, -60.0, 30.0)


func _physics_process(delta: float) -> void:
	var look := Input.get_vector("look_left", "look_right", "look_up", "look_down") if look_enabled else Vector2.ZERO
	_yaw -= look.x * 140.0 * delta
	_pitch = clampf(_pitch - look.y * 90.0 * delta, -60.0, 30.0)

	var move := Vector2.ZERO
	if input_enabled:
		move = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var basis := Basis(Vector3.UP, deg_to_rad(_yaw))
	var dir := basis * Vector3(move.x, 0, move.y)
	var speed := JOG
	if Input.is_action_pressed("sprint") and input_enabled:
		speed = SPRINT
	elif move.length() < 0.55:
		speed = WALK / 0.55  # analog half-tilt walks
	var target := dir * speed if move.length() > 0.05 else Vector3.ZERO
	apply_locomotion(target, delta)
	# The map is 1 km; beyond it is scenery only.
	var inset := 6.0
	global_position.x = clampf(global_position.x, inset, Terrain.SIZE - inset)
	global_position.z = clampf(global_position.z, inset, Terrain.SIZE - inset)

	if trail.is_empty() or global_position.distance_to(trail[-1]) > 0.4:
		trail.append(global_position)
		if trail.size() > 200:
			trail.pop_front()

	camera_rig.global_position = camera_rig.global_position.lerp(global_position + Vector3(0, 1.65, 0), clampf(delta * 12.0, 0.0, 1.0))
	camera_rig.rotation_degrees.y = _yaw
	camera_rig.get_node("Pitch").rotation_degrees.x = _pitch


func camera_forward() -> Vector3:
	return -Basis(Vector3.UP, deg_to_rad(_yaw)).z
