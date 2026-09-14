"""Device-agnostic input: raw keyboard / game-controller events -> semantic actions.

Screens never read keys or buttons directly. The App feeds every pygame event to
one :class:`InputState`, which returns the :class:`Action`s that event triggered
(edge-triggered, e.g. "confirm was pressed") and tracks what is held so screens
can ask for a continuous :meth:`InputState.move_vector`.

Controllers use SDL's GameController API, so buttons are positional and uniform
across Xbox, PlayStation, Switch Pro and Steam Deck pads (``A`` = bottom face
button). Mouse events are not actions — they stay with the UI widgets that
hit-test them.
"""

from __future__ import annotations

import math
from enum import Enum, auto

import pygame


class Action(Enum):
    CONFIRM = auto()  # accept / advance / talk
    BACK = auto()  # cancel / close the current overlay
    INTERACT = auto()  # act on what is nearby in the world
    MENU = auto()  # leave to the menu (title) / pause
    TOGGLE_MAP = auto()  # field <-> Expedition Map
    NEXT = auto()
    PREV = auto()
    SAVE = auto()
    ZOOM_IN = auto()
    ZOOM_OUT = auto()
    ZOOM_RESET = auto()
    MAP_MODE_OVERVIEW = auto()
    MAP_MODE_REGION = auto()
    MAP_MODE_HEX = auto()


KEYBOARD = "keyboard"
GAMEPAD = "gamepad"

# Plain key bindings: only match when Ctrl is NOT held (Ctrl+Shift combos are
# reserved for the App's window-size shortcuts).
KEY_BINDINGS: dict[int, tuple[Action, ...]] = {
    pygame.K_RETURN: (Action.CONFIRM,),
    pygame.K_KP_ENTER: (Action.CONFIRM,),
    pygame.K_SPACE: (Action.CONFIRM,),
    pygame.K_e: (Action.INTERACT,),
    pygame.K_ESCAPE: (Action.MENU,),
    pygame.K_BACKSPACE: (Action.BACK,),
    pygame.K_m: (Action.TOGGLE_MAP,),
    pygame.K_TAB: (Action.TOGGLE_MAP,),
    pygame.K_RIGHT: (Action.NEXT,),
    pygame.K_LEFT: (Action.PREV,),
    pygame.K_EQUALS: (Action.ZOOM_IN,),
    pygame.K_KP_PLUS: (Action.ZOOM_IN,),
    pygame.K_MINUS: (Action.ZOOM_OUT,),
    pygame.K_KP_MINUS: (Action.ZOOM_OUT,),
    pygame.K_r: (Action.ZOOM_RESET,),
    pygame.K_F1: (Action.MAP_MODE_OVERVIEW,),
    pygame.K_F2: (Action.MAP_MODE_REGION,),
    pygame.K_F3: (Action.MAP_MODE_HEX,),
}

# Ctrl+key bindings (Shift must not be held).
CTRL_KEY_BINDINGS: dict[int, tuple[Action, ...]] = {
    pygame.K_s: (Action.SAVE,),
}

BUTTON_BINDINGS: dict[int, tuple[Action, ...]] = {
    pygame.CONTROLLER_BUTTON_A: (Action.CONFIRM,),
    pygame.CONTROLLER_BUTTON_B: (Action.BACK,),
    pygame.CONTROLLER_BUTTON_START: (Action.MENU,),
    pygame.CONTROLLER_BUTTON_BACK: (Action.TOGGLE_MAP,),
    pygame.CONTROLLER_BUTTON_Y: (Action.TOGGLE_MAP,),
    pygame.CONTROLLER_BUTTON_RIGHTSHOULDER: (Action.NEXT, Action.ZOOM_IN),
    pygame.CONTROLLER_BUTTON_LEFTSHOULDER: (Action.PREV, Action.ZOOM_OUT),
    pygame.CONTROLLER_BUTTON_RIGHTSTICK: (Action.ZOOM_RESET,),
}

# Held inputs that steer movement, as screen-space unit directions (x right, y down).
MOVE_KEYS: dict[int, tuple[int, int]] = {
    pygame.K_w: (0, -1),
    pygame.K_UP: (0, -1),
    pygame.K_s: (0, 1),
    pygame.K_DOWN: (0, 1),
    pygame.K_a: (-1, 0),
    pygame.K_LEFT: (-1, 0),
    pygame.K_d: (1, 0),
    pygame.K_RIGHT: (1, 0),
}
MOVE_BUTTONS: dict[int, tuple[int, int]] = {
    pygame.CONTROLLER_BUTTON_DPAD_UP: (0, -1),
    pygame.CONTROLLER_BUTTON_DPAD_DOWN: (0, 1),
    pygame.CONTROLLER_BUTTON_DPAD_LEFT: (-1, 0),
    pygame.CONTROLLER_BUTTON_DPAD_RIGHT: (1, 0),
}

STICK_DEADZONE = 0.25  # radial, as a fraction of full deflection
_AXIS_MAX = 32767.0

# How each action is labelled in on-screen hints, per device.
_HINT_LABELS = {
    KEYBOARD: {
        "move": "WASD / Arrows",
        Action.INTERACT: "E",
        Action.CONFIRM: "Enter",
        Action.TOGGLE_MAP: "M",
        Action.MENU: "Esc",
        Action.BACK: "Backspace",
    },
    GAMEPAD: {
        "move": "L-Stick",
        Action.INTERACT: "A",
        Action.CONFIRM: "A",
        Action.TOGGLE_MAP: "View",
        Action.MENU: "Start",
        Action.BACK: "B",
    },
}


class InputState:
    """Turns the frame's raw events into actions and tracks held movement."""

    def __init__(self):
        self._held_keys: set[int] = set()
        self._held_buttons: set[int] = set()
        self._stick = [0.0, 0.0]  # left stick, normalised -1..1
        self._controllers: dict[int, object] = {}  # instance_id -> Controller
        self.last_device = KEYBOARD

    # ------------------------------------------------------------ devices

    def init_controllers(self) -> None:
        """Enable the GameController subsystem and open pads already plugged in.

        Pads connected later arrive as CONTROLLERDEVICEADDED and are opened in
        :meth:`handle_event`. Safe to call when no controller support exists.
        """
        try:
            from pygame._sdl2 import controller

            controller.init()
            for i in range(controller.get_count()):
                self._open_controller(i)
        except (ImportError, pygame.error):
            pass

    def _open_controller(self, device_index: int) -> None:
        try:
            from pygame._sdl2 import controller

            if not controller.is_controller(device_index):
                return
            pad = controller.Controller(device_index)
            self._controllers[pad.as_joystick().get_instance_id()] = pad
        except (ImportError, pygame.error):
            pass

    @property
    def controller_count(self) -> int:
        return len(self._controllers)

    # ------------------------------------------------------------- events

    def handle_event(self, event: pygame.event.Event) -> list[Action]:
        """Update held state from ``event``; return the actions it triggers."""
        t = event.type
        if t == pygame.KEYDOWN:
            self.last_device = KEYBOARD
            self._held_keys.add(event.key)
            mods = getattr(event, "mod", 0)
            ctrl = bool(mods & pygame.KMOD_CTRL)
            shift = bool(mods & pygame.KMOD_SHIFT)
            if ctrl:
                return [] if shift else list(CTRL_KEY_BINDINGS.get(event.key, ()))
            return list(KEY_BINDINGS.get(event.key, ()))
        if t == pygame.KEYUP:
            self._held_keys.discard(event.key)
            return []
        if t == pygame.CONTROLLERBUTTONDOWN:
            self.last_device = GAMEPAD
            self._held_buttons.add(event.button)
            return list(BUTTON_BINDINGS.get(event.button, ()))
        if t == pygame.CONTROLLERBUTTONUP:
            self._held_buttons.discard(event.button)
            return []
        if t == pygame.CONTROLLERAXISMOTION:
            if event.axis in (pygame.CONTROLLER_AXIS_LEFTX, pygame.CONTROLLER_AXIS_LEFTY):
                i = 0 if event.axis == pygame.CONTROLLER_AXIS_LEFTX else 1
                self._stick[i] = max(-1.0, min(1.0, event.value / _AXIS_MAX))
                if abs(self._stick[i]) > STICK_DEADZONE:
                    self.last_device = GAMEPAD
            return []
        if t == pygame.CONTROLLERDEVICEADDED:
            self._open_controller(event.device_index)
            return []
        if t == pygame.CONTROLLERDEVICEREMOVED:
            self._controllers.pop(getattr(event, "instance_id", None), None)
            self._release_all()
            return []
        if t == getattr(pygame, "WINDOWFOCUSLOST", None):
            # Key-ups are lost while unfocused; never leave the Corps walking.
            self._release_all()
            return []
        return []

    def _release_all(self) -> None:
        self._held_keys.clear()
        self._held_buttons.clear()
        self._stick = [0.0, 0.0]

    # ------------------------------------------------------------- queries

    def move_vector(self) -> tuple[float, float]:
        """Screen-space movement intent (x right, y down), magnitude 0..1.

        Digital inputs give full magnitude; the stick keeps its analog magnitude
        past the radial deadzone, rescaled so walking starts smoothly from 0.
        """
        dx = dy = 0.0
        for k in self._held_keys:
            if k in MOVE_KEYS:
                mx, my = MOVE_KEYS[k]
                dx += mx
                dy += my
        for b in self._held_buttons:
            if b in MOVE_BUTTONS:
                mx, my = MOVE_BUTTONS[b]
                dx += mx
                dy += my
        # Opposing keys (or W + Up) must not add up past one step per axis.
        dx = max(-1.0, min(1.0, dx))
        dy = max(-1.0, min(1.0, dy))
        if dx or dy:
            mag = math.hypot(dx, dy)
            return dx / mag, dy / mag

        sx, sy = self._stick
        mag = math.hypot(sx, sy)
        if mag <= STICK_DEADZONE:
            return 0.0, 0.0
        scaled = min(1.0, (mag - STICK_DEADZONE) / (1.0 - STICK_DEADZONE))
        return sx / mag * scaled, sy / mag * scaled

    def hint(self, action: Action | str) -> str:
        """Label for ``action`` on the device the player is currently using."""
        return _HINT_LABELS[self.last_device].get(action, "")
