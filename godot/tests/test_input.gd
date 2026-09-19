extends RefCounted
## Which connected controllers drive the game (see input_setup.gd).

var t

const InputSetup := preload("res://scripts/input_setup.gd")


func test_racing_wheels_and_flight_gear_are_not_gamepads() -> void:
	# Their pedals and throttles rest at full travel, which reads as sticks held down.
	for name in ["Logitech G920 Driving Force Racing Wheel for Xbox One", "Thrustmaster T300RS",
			"Fanatec CSL Elite Pedals", "Saitek Pro Flight Rudder Pedals", "Thrustmaster HOTAS Warthog Throttle",
			"Logitech Extreme 3D Pro Joystick"]:
		t.check(not InputSetup.is_gamepad_name(name), name)


func test_ordinary_controllers_are_gamepads() -> void:
	for name in ["Xbox Series Controller", "XInput Gamepad (GLFW)", "PS5 Controller", "DualSense Wireless Controller",
			"Nintendo Switch Pro Controller", "Steam Deck", "8BitDo Pro 2"]:
		t.check(InputSetup.is_gamepad_name(name), name)
