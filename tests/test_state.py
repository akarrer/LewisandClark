"""Unit tests for GameState (require loaded config)."""

from __future__ import annotations

from dataclasses import fields

import pytest
from lewis_clark import assets
from lewis_clark.state import GameState


def _assert_roundtrip_equal(before: GameState, after: GameState) -> None:
    for f in fields(GameState):
        if f.name == "characters":
            assert before.characters.keys() == after.characters.keys()
            for k in before.characters:
                assert before.characters[k]["active"] == after.characters[k]["active"]
        else:
            assert getattr(before, f.name) == getattr(after, f.name)


def test_game_state_defaults_from_config():
    s = GameState()
    assert s.food == 100
    assert s.morale == 80
    assert len(s.tribe_relations) == len(assets.TRIBES)
    assert s.inventory.keys() == assets.STARTING_INVENTORY.keys()
    assert "lewis" in s.characters
    assert "clark" in s.characters
    assert "york" in s.characters


def test_clamp_bounds():
    s = GameState()
    s.food = 150
    s.health = -10
    s.morale = 200
    s.clamp()
    assert s.food == 100
    assert s.health == 0
    assert s.morale == 100


def test_apply_effect_food_and_inventory():
    s = GameState()
    s.apply_effect({"food": -20, "inventory": {"Tobacco": -2}}, {})
    assert s.food == 80
    assert s.inventory["Tobacco"] == assets.STARTING_INVENTORY["Tobacco"] - 2


def test_apply_effect_york_passive_morale():
    s = GameState()
    before = s.morale
    s.apply_effect({}, {"york": True})
    assert s.morale == before + 2


def test_apply_effect_drouillard_furs():
    s = GameState()
    s.apply_effect({}, {"drouillard": True})
    assert s.inventory.get("Furs", 0) >= 1


def test_to_dict_from_dict_roundtrip():
    s = GameState()
    s.add_journal("Test entry")
    s.discoveries = 3
    s.events_seen = ["e1", "e2"]
    s.used_resources = [(1, 2)]
    s.hex_trail = [(s.hex_col, s.hex_row), (s.hex_col + 1, s.hex_row)]
    s.visited_hexes = list(s.hex_trail)
    s.characters["york"]["active"] = False
    d = s.to_dict()
    s2 = GameState.from_dict(d)
    _assert_roundtrip_equal(s, s2)


def test_from_dict_rejects_incomplete_save():
    with pytest.raises(KeyError, match="missing keys"):
        GameState.from_dict({"current_wp": 0})


def test_advance_date_rolls_year():
    s = GameState(current_month=12, current_day=20, current_year=1804)
    s.advance_date(14)
    assert (s.current_year, s.current_month, s.current_day) == (1805, 1, 3)


def test_advance_date_counts_real_month_lengths():
    s = GameState(current_month=2, current_day=28, current_year=1805)
    s.advance_date(1)  # 1805 is not a leap year
    assert (s.current_month, s.current_day) == (3, 1)
    s = GameState(current_month=5, current_day=14, current_year=1804)
    s.advance_date(36)
    assert (s.current_month, s.current_day) == (6, 19)


def test_day_clock_rolls_into_calendar():
    s = GameState(current_month=8, current_day=31, minute_of_day=23 * 60)
    s.advance_minutes(90)
    assert (s.current_month, s.current_day, s.clock_str) == (9, 1, "00:30")


def test_new_game_starts_in_start_region():
    assert GameState().current_region == assets.START_REGION


def test_pre_open_world_save_lands_in_matching_region():
    s = GameState(current_wp=3)
    d = s.to_dict()
    for k in ("current_day", "minute_of_day", "current_region", "landmarks_visited"):
        d.pop(k)
    loaded = GameState.from_dict(d)
    assert loaded.current_region == "sioux_country"
    assert loaded.landmarks_visited == []


def test_sit_out_winter_from_january_keeps_year():
    s = GameState(current_month=1, current_year=1806)
    s.sit_out_winter()
    assert (s.current_year, s.current_month, s.current_day) == (1806, 3, 1)
