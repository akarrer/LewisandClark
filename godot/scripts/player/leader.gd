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

## In hand: the rifle off the back (1), and the spyglass to the eye (2). Only one
## at a time -- a man cannot hold both, and the game should not pretend he can.
var rifle_ready := false
var glassing := false
const FOV := 62.0
const FOV_GLASS := 13.0     # about six power, which is what a pocket glass gave
var _fov := FOV
var glass_amount := 0.0

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
	if input_enabled and event.is_action_pressed("take_rifle"):
		rifle_ready = not rifle_ready
		if rifle_ready:
			glassing = false
	elif input_enabled and event.is_action_pressed("spyglass"):
		glassing = not glassing
		if glassing:
			rifle_ready = false
	if event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and look_enabled:
		# Sensitivity follows the field of view, so a narrow field is not a wild
		# one: six power through a hand-held glass is hard enough to hold steady.
		var scale := _fov / FOV
		_yaw -= event.relative.x * 0.12 * scale
		_pitch = clampf(_pitch - event.relative.y * 0.1 * scale, -60.0, 62.0)


func _physics_process(delta: float) -> void:
	var look := Input.get_vector("look_left", "look_right", "look_up", "look_down") if look_enabled else Vector2.ZERO
	_yaw -= look.x * 140.0 * delta
	_pitch = clampf(_pitch - look.y * 90.0 * delta, -60.0, 62.0)

	var move := Vector2.ZERO
	if input_enabled:
		move = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var basis := Basis(Vector3.UP, deg_to_rad(_yaw))
	var dir := basis * Vector3(move.x, 0, move.y)
	var speed := JOG
	if glassing:
		speed = WALK          # nobody runs with a glass to their eye
	elif Input.is_action_pressed("sprint") and input_enabled:
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

	set_rifle_out(1.0 if rifle_ready else 0.0, delta)
	_fov = move_toward(_fov, FOV_GLASS if glassing else FOV, delta * (FOV - FOV_GLASS) * 1.6)
	camera.fov = _fov
	glass_amount = clampf((FOV - _fov) / (FOV - FOV_GLASS), 0.0, 1.0)
	# The glass goes to the eye, so the camera does too: a spyglass held at six
	# power with your own shoulder filling a third of the frame is no use to
	# anybody. In close over the shoulder with the rifle up, further back
	# otherwise.
	var want_length := 0.0 if glassing else (2.6 if rifle_ready else 4.6)
	var ease := clampf(delta * 5.0, 0.0, 1.0)
	spring.spring_length = lerpf(spring.spring_length, want_length, ease)
	spring.position.x = lerpf(spring.position.x, 0.0 if glassing else 0.55, ease)
	# And he is not drawn while you are looking out of his own eyes.
	model.visible = glass_amount < 0.55

	camera_rig.global_position = camera_rig.global_position.lerp(global_position + Vector3(0, 1.65, 0), clampf(delta * 12.0, 0.0, 1.0))
	camera_rig.rotation_degrees.y = _yaw
	camera_rig.get_node("Pitch").rotation_degrees.x = _pitch


func camera_forward() -> Vector3:
	return -Basis(Vector3.UP, deg_to_rad(_yaw)).z
