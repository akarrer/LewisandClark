"""InputState: raw keyboard / controller events -> actions and held movement."""

from __future__ import annotations

import math

import pygame
import pytest
from lewis_clark import iso
from lewis_clark.input import GAMEPAD, KEYBOARD, STICK_DEADZONE, Action, InputState


def key_down(key, mod=0):
    return pygame.event.Event(pygame.KEYDOWN, key=key, mod=mod, unicode="", scancode=0)


def key_up(key):
    return pygame.event.Event(pygame.KEYUP, key=key, mod=0, unicode="", scancode=0)


def pad_down(button):
    return pygame.event.Event(pygame.CONTROLLERBUTTONDOWN, button=button, instance_id=0)


def pad_up(button):
    return pygame.event.Event(pygame.CONTROLLERBUTTONUP, button=button, instance_id=0)


def stick(axis, fraction):
    return pygame.event.Event(
        pygame.CONTROLLERAXISMOTION, axis=axis, value=int(fraction * 32767), instance_id=0
    )


@pytest.fixture
def inp():
    return InputState()


# ------------------------------------------------------------------ keyboard


@pytest.mark.parametrize(
    "key, action",
    [
        (pygame.K_RETURN, Action.CONFIRM),
        (pygame.K_SPACE, Action.CONFIRM),
        (pygame.K_e, Action.INTERACT),
        (pygame.K_ESCAPE, Action.MENU),
        (pygame.K_m, Action.TOGGLE_MAP),
        (pygame.K_TAB, Action.TOGGLE_MAP),
        (pygame.K_RIGHT, Action.NEXT),
        (pygame.K_F2, Action.MAP_MODE_REGION),
    ],
)
def test_key_emits_action(inp, key, action):
    assert inp.handle_event(key_down(key)) == [action]


def test_movement_key_emits_no_action_but_is_held(inp):
    assert inp.handle_event(key_down(pygame.K_s)) == []
    assert inp.move_vector() == (0.0, 1.0)


def test_ctrl_s_saves_without_being_a_plain_binding(inp):
    assert inp.handle_event(key_down(pygame.K_s, pygame.KMOD_LCTRL)) == [Action.SAVE]


def test_ctrl_shift_combos_are_left_to_window_shortcuts(inp):
    assert inp.handle_event(key_down(pygame.K_EQUALS, pygame.KMOD_LCTRL | pygame.KMOD_LSHIFT)) == []


def test_key_up_stops_movement(inp):
    inp.handle_event(key_down(pygame.K_w))
    inp.handle_event(key_up(pygame.K_w))
    assert inp.move_vector() == (0.0, 0.0)


def test_diagonal_is_unit_length(inp):
    inp.handle_event(key_down(pygame.K_w))
    inp.handle_event(key_down(pygame.K_d))
    x, y = inp.move_vector()
    assert math.hypot(x, y) == pytest.approx(1.0)
    assert x > 0 > y


def test_duplicate_direction_keys_do_not_speed_up(inp):
    inp.handle_event(key_down(pygame.K_w))
    inp.handle_event(key_down(pygame.K_UP))
    assert inp.move_vector() == (0.0, -1.0)


def test_opposing_keys_cancel(inp):
    inp.handle_event(key_down(pygame.K_a))
    inp.handle_event(key_down(pygame.K_d))
    assert inp.move_vector() == (0.0, 0.0)


def test_focus_loss_releases_held_keys(inp):
    inp.handle_event(key_down(pygame.K_d))
    inp.handle_event(pygame.event.Event(pygame.WINDOWFOCUSLOST))
    assert inp.move_vector() == (0.0, 0.0)


# ------------------------------------------------------------------ gamepad


@pytest.mark.parametrize(
    "button, action",
    [
        (pygame.CONTROLLER_BUTTON_A, Action.CONFIRM),
        (pygame.CONTROLLER_BUTTON_B, Action.BACK),
        (pygame.CONTROLLER_BUTTON_START, Action.MENU),
        (pygame.CONTROLLER_BUTTON_BACK, Action.TOGGLE_MAP),
    ],
)
def test_button_emits_action(inp, button, action):
    assert inp.handle_event(pad_down(button)) == [action]


def test_shoulder_emits_every_bound_action(inp):
    got = inp.handle_event(pad_down(pygame.CONTROLLER_BUTTON_RIGHTSHOULDER))
    assert got == [Action.NEXT, Action.ZOOM_IN]


def test_dpad_is_held_movement(inp):
    inp.handle_event(pad_down(pygame.CONTROLLER_BUTTON_DPAD_LEFT))
    assert inp.move_vector() == (-1.0, 0.0)
    inp.handle_event(pad_up(pygame.CONTROLLER_BUTTON_DPAD_LEFT))
    assert inp.move_vector() == (0.0, 0.0)


def test_stick_inside_deadzone_is_still(inp):
    inp.handle_event(stick(pygame.CONTROLLER_AXIS_LEFTX, STICK_DEADZONE * 0.9))
    assert inp.move_vector() == (0.0, 0.0)


def test_stick_full_tilt_is_full_speed(inp):
    inp.handle_event(stick(pygame.CONTROLLER_AXIS_LEFTX, 1.0))
    x, y = inp.move_vector()
    assert x == pytest.approx(1.0) and y == pytest.approx(0.0)


def test_stick_keeps_analog_magnitude(inp):
    inp.handle_event(stick(pygame.CONTROLLER_AXIS_LEFTY, 0.6))
    _, y = inp.move_vector()
    assert 0.0 < y < 1.0


def test_keys_override_stick(inp):
    inp.handle_event(stick(pygame.CONTROLLER_AXIS_LEFTX, 1.0))
    inp.handle_event(key_down(pygame.K_w))
    assert inp.move_vector() == (0.0, -1.0)


def test_hints_follow_last_device(inp):
    inp.handle_event(key_down(pygame.K_e))
    assert inp.last_device == KEYBOARD and inp.hint(Action.INTERACT) == "E"
    inp.handle_event(pad_down(pygame.CONTROLLER_BUTTON_A))
    assert inp.last_device == GAMEPAD and inp.hint(Action.INTERACT) == "A"


# ------------------------------------------------------------------ iso mapping


@pytest.mark.parametrize(
    "screen, world",
    [
        ((0, -1), (-1, -1)),  # W: into the grid
        ((0, 1), (1, 1)),  # S
        ((-1, 0), (-1, 1)),  # A
        ((1, 0), (1, -1)),  # D
    ],
)
def test_screen_direction_matches_original_wasd_mapping(screen, world):
    wx, wy = iso.screen_dir_to_world(*screen)
    s = 2**-0.5
    assert (wx, wy) == pytest.approx((world[0] * s, world[1] * s))


def test_screen_direction_preserves_magnitude():
    wx, wy = iso.screen_dir_to_world(0.3, -0.4)
    assert math.hypot(wx, wy) == pytest.approx(0.5)
