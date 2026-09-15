extends Node
## Registers the game's input actions for keyboard/mouse and controller.
## Mirrors the Action set from the Pygame build (lewis_clark/input.py).

const STICK_DEADZONE := 0.25

## "keyboard" or "gamepad" — whichever the player touched last, for on-screen hints.
var last_device := "keyboard"

const HINTS := {
	"keyboard": {"interact": "E", "sprint": "Shift", "toggle_map": "M", "menu": "Esc"},
	"gamepad": {"interact": "A", "sprint": "L3", "toggle_map": "View", "menu": "Start"},
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
		last_device = "gamepad"
	elif event is InputEventKey or event is InputEventMouseButton:
		last_device = "keyboard"


func hint(action: String) -> String:
	return HINTS[last_device].get(action, action)
