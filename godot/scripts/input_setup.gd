extends Node
## Registers the game's input actions for keyboard/mouse and controller.
## Mirrors the Action set from the Pygame build (lewis_clark/input.py).

const STICK_DEADZONE := 0.25

## "keyboard" or "gamepad" — whichever the player touched last, for on-screen hints.
var last_device := "keyboard"

## The controller that drives the game, or NO_GAMEPAD. Only one is bound: racing
## wheels, pedals and flight gear stay plugged in on many PCs, and their pedals
## and throttles rest at full travel, which would read as a stick held down.
var gamepad_id := NO_GAMEPAD
const NO_GAMEPAD := 1000
const NOT_GAMEPADS := ["wheel", "pedal", "rudder", "throttle", "hotas", "joystick", "flight", "yoke",
		"g920", "g923", "g29", "g27", "t300", "t150", "t248", "fanatec", "shifter"]


static func is_gamepad_name(joy_name: String) -> bool:
	var n := joy_name.to_lower()
	for word in NOT_GAMEPADS:
		if n.contains(word):
			return false
	return true

const HINTS := {
	"keyboard": {"interact": "E", "sprint": "Shift", "toggle_map": "M", "menu": "Esc", "inventory": "I"},
	"gamepad": {"interact": "A", "sprint": "L3", "toggle_map": "View", "menu": "Start", "inventory": "Y"},
}

func _ready() -> void:
	_axis("move_forward", KEY_W, JOY_AXIS_LEFT_Y, -1.0, KEY_UP)
	_axis("move_back", KEY_S, JOY_AXIS_LEFT_Y, 1.0, KEY_DOWN)
	_axis("move_left", KEY_A, JOY_AXIS_LEFT_X, -1.0, KEY_LEFT)
	_axis("move_right", KEY_D, JOY_AXIS_LEFT_X, 1.0, KEY_RIGHT)
	_axis("look_left", -1, JOY_AXIS_RIGHT_X, -1.0)
	_axis("look_right", -1, JOY_AXIS_RIGHT_X, 1.0)
	_axis("look_up", -1, JOY_AXIS_RIGHT_Y, -1.0)
	_axis("look_down", -1, JOY_AXIS_RIGHT_Y, 1.0)
	_button("sprint", [KEY_SHIFT], [JOY_BUTTON_LEFT_STICK])
	_button("interact", [KEY_E, KEY_ENTER], [JOY_BUTTON_A])
	_button("back", [KEY_BACKSPACE], [JOY_BUTTON_B])
	_button("menu", [KEY_ESCAPE], [JOY_BUTTON_START])
	_button("toggle_map", [KEY_M, KEY_TAB], [JOY_BUTTON_BACK])
	_button("inventory", [KEY_I], [JOY_BUTTON_Y])
	Input.joy_connection_changed.connect(func(_id, _connected): _bind_gamepad())
	_bind_gamepad()


func _bind_gamepad() -> void:
	## Point every controller binding at the first real gamepad (or at nothing).
	gamepad_id = NO_GAMEPAD
	for id in Input.get_connected_joypads():
		if is_gamepad_name(Input.get_joy_name(id)):
			gamepad_id = id
			break
	for action in InputMap.get_actions():
		for ev in InputMap.action_get_events(action):
			if ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
				ev.device = gamepad_id

func _axis(action: String, key: int, axis: int, dir: float, alt_key: int = -1) -> void:
	_ensure(action)
	for k in [key, alt_key]:
		if k != -1:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
	var jm := InputEventJoypadMotion.new()
	jm.axis = axis
	jm.axis_value = dir
	InputMap.action_add_event(action, jm)

func _button(action: String, keys: Array, buttons: Array) -> void:
	_ensure(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)
	for b in buttons:
		var jb := InputEventJoypadButton.new()
		jb.button_index = b
		InputMap.action_add_event(action, jb)

func _ensure(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, STICK_DEADZONE)


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > STICK_DEADZONE):
		if event.device == gamepad_id:
			last_device = "gamepad"
	elif event is InputEventKey or event is InputEventMouseButton:
		last_device = "keyboard"


func hint(action: String) -> String:
	return HINTS[last_device].get(action, action)
