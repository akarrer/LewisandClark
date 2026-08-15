"""Unit tests for the four AAA gameplay systems (require loaded config):

* P1 — active character abilities (``AbilitiesMixin._use_ability`` / cooldowns)
* P2 — event trigger chains (``_plant_triggers`` / ``_check_pending_triggers``)
* P3 — calendar hard deadlines (``_check_calendar_gates`` / winter lock)
* P4 — tribal reputation web (``_propagate_tribal_reputation``)

The mixin methods live on ``GameScreen`` but only touch ``self.state`` plus a
handful of UI callbacks, so we exercise them against a minimal host stub instead
of constructing a full pygame screen.
"""

from __future__ import annotations

import pytest
from lewis_clark import assets
from lewis_clark.screens.game.mixin_abilities import AbilitiesMixin
from lewis_clark.state import GameState


class _Host(AbilitiesMixin):
    """Minimal stand-in for GameScreen: real state, no-op UI callbacks."""

    def __init__(self, state: GameState, next_event: dict | None = None):
        self.state = state
        self.pending_event = None
        self._next_event = next_event
        self.journal_updates = 0
        self.travel_ui_builds = 0
        self.objective_checks = 0
        self.event_ui_for = None

    def _update_journal(self):
        self.journal_updates += 1

    def _check_objectives(self):
        self.objective_checks += 1

    def _build_travel_ui(self):
        self.travel_ui_builds += 1

    def _build_event_ui(self, ev):
        self.event_ui_for = ev

    def _pick_event(self):
        return self._next_event


def _event(event_id: str) -> dict:
    ev = next((e for e in assets.EVENTS if e["id"] == event_id), None)
    assert ev is not None, f"fixture event {event_id!r} missing from config"
    return ev


def _solo_state(active_key: str) -> GameState:
    """State with only one character active, to isolate ability effects from
    passive character bonuses in ``apply_effect``."""
    s = GameState()
    for k in s.characters:
        s.characters[k]["active"] = k == active_key
    return s


# --------------------------------------------------------------------- P1

def test_use_ability_sets_cooldown_and_route_buffer():
    host = _Host(_solo_state("clark"))
    host._use_ability("clark")
    ab = assets.SPECIAL_CHARACTERS["clark"]["active_ability"]
    assert host.state.char_cooldowns["clark"] == ab["cooldown"]
    assert host.state.clark_route_buffer == ab["route_buffer"]
    # UI/journal side effects fired exactly once.
    assert host.travel_ui_builds == 1
    assert host.journal_updates == 1
    assert host.state.journal, "ability should append a journal entry"


def test_use_ability_applies_effect_isolated():
    host = _Host(_solo_state("clark"))
    before = host.state.morale
    host._use_ability("clark")
    gain = assets.SPECIAL_CHARACTERS["clark"]["active_ability"]["effect"].get("morale", 0)
    assert host.state.morale == min(100, before + gain)


def test_lewis_ability_adds_discoveries():
    host = _Host(_solo_state("lewis"))
    ab = assets.SPECIAL_CHARACTERS["lewis"]["active_ability"]
    assert ab.get("discoveries", 0) > 0  # guards the fixture
    host._use_ability("lewis")
    assert host.state.discoveries == ab["discoveries"]


def test_use_ability_unknown_char_is_noop():
    host = _Host(GameState())
    host._use_ability("napoleon")  # no active_ability
    assert host.state.char_cooldowns == {}
    assert host.travel_ui_builds == 0


def test_decrement_cooldowns_floors_at_zero():
    s = GameState()
    s.char_cooldowns = {"lewis": 4, "clark": 0}
    s.clark_route_buffer = 3
    host = _Host(s)
    host._decrement_char_cooldowns()
    assert s.char_cooldowns["lewis"] == 3
    assert s.char_cooldowns["clark"] == 0  # never goes negative
    assert s.clark_route_buffer == 2


# --------------------------------------------------------------------- P2

def test_plant_triggers_from_choice():
    s = GameState()
    host = _Host(s)
    host._plant_triggers(_event("grizzly"), 0)
    assert len(s.pending_triggers) == 1
    trig = s.pending_triggers[0]
    assert trig["event_id"] == "wounded_recovery"
    assert trig["hexes_remaining"] == 3


def test_plant_triggers_dedupes():
    s = GameState()
    host = _Host(s)
    host._plant_triggers(_event("grizzly"), 0)
    host._plant_triggers(_event("grizzly"), 0)
    assert len(s.pending_triggers) == 1


def test_pending_trigger_counts_down_without_firing():
    s = GameState()
    s.pending_triggers = [{"event_id": "wounded_recovery", "hexes_remaining": 3}]
    host = _Host(s)
    host._check_pending_triggers()
    assert host.event_ui_for is None
    assert s.pending_triggers[0]["hexes_remaining"] == 2


def test_pending_trigger_fires_at_zero():
    s = GameState()
    s.pending_triggers = [{"event_id": "wounded_recovery", "hexes_remaining": 1}]
    host = _Host(s)
    host._check_pending_triggers()
    assert host.event_ui_for is not None
    assert host.event_ui_for["id"] == "wounded_recovery"
    assert host.pending_event is host.event_ui_for
    assert s.pending_triggers == []


def test_only_one_trigger_fires_per_move():
    s = GameState()
    s.pending_triggers = [
        {"event_id": "wounded_recovery", "hexes_remaining": 1},
        {"event_id": "frostbite_crisis", "hexes_remaining": 1},
    ]
    host = _Host(s)
    host._check_pending_triggers()
    # One fires; the other is decremented and retained for a later move.
    assert host.event_ui_for["id"] == "wounded_recovery"
    assert len(s.pending_triggers) == 1
    assert s.pending_triggers[0]["event_id"] == "frostbite_crisis"


def test_pending_trigger_unknown_event_is_dropped():
    s = GameState()
    s.pending_triggers = [{"event_id": "no_such_event", "hexes_remaining": 1}]
    host = _Host(s)
    host._check_pending_triggers()
    assert host.event_ui_for is None
    assert s.pending_triggers == []


# --------------------------------------------------------------------- P3

def test_winter_lock_penalizes_when_stuck_in_rockies():
    s = GameState(current_month=11)
    s.current_wp = 3  # not past the Bitterroots (wp 5)
    health_before = s.health
    host = _Host(s)
    host._check_calendar_gates()
    # Penalty applied and corps fast-forwarded to spring.
    assert s.health < health_before
    assert s.current_month == 3
    # winter_locked is set then cleared by the penalty resolution.
    assert s.winter_locked is False
    assert any("WINTER" in j for j in s.journal)


def test_winter_lock_does_not_refire_after_thaw():
    s = GameState(current_month=11)
    s.current_wp = 3
    host = _Host(s)
    host._check_calendar_gates()
    entries_after_first = len(s.journal)
    host._check_calendar_gates()  # now month == 3, should be a no-op
    assert len(s.journal) == entries_after_first


def test_no_winter_lock_past_bitterroots():
    s = GameState(current_month=11)
    s.current_wp = 6  # cleared the mountains
    host = _Host(s)
    host._check_calendar_gates()
    assert s.winter_locked is False
    assert s.current_month == 11
    assert s.health == 100


def test_no_winter_lock_before_november():
    s = GameState(current_month=10)
    s.current_wp = 0
    host = _Host(s)
    host._check_calendar_gates()
    assert s.winter_locked is False
    assert s.current_month == 10


# --------------------------------------------------------------------- P4

def _region_of(key: str) -> str:
    return assets.TRIBES[key]["region"]


def _same_region_peers(key: str) -> list[str]:
    region = _region_of(key)
    return [k for k in assets.TRIBES if k != key and _region_of(k) == region]


def test_reputation_ripples_to_same_region_only():
    acting = "Missouri"  # plains region, has peers
    peers = _same_region_peers(acting)
    assert peers, "fixture expects Missouri to share a region with other tribes"
    outsiders = [k for k in assets.TRIBES if _region_of(k) != _region_of(acting)]

    s = GameState()
    baseline = dict(s.tribe_relations)
    host = _Host(s)
    delta = 12
    host._propagate_tribal_reputation(acting, delta)

    ripple = max(1, abs(delta) // 4)
    for k in peers:
        assert s.tribe_relations[k] == min(100, baseline[k] + ripple)
    for k in outsiders:
        assert s.tribe_relations[k] == baseline[k]
    # Acting tribe's own relation is the caller's responsibility, untouched here.
    assert s.tribe_relations[acting] == baseline[acting]
    assert s.tribal_reputation == 50 + ripple


def test_reputation_below_threshold_is_noop():
    s = GameState()
    baseline = dict(s.tribe_relations)
    host = _Host(s)
    host._propagate_tribal_reputation("Missouri", 5)  # |delta| < 8
    assert s.tribe_relations == baseline
    assert s.tribal_reputation == 50


def test_reputation_negative_ripple_clamps_at_zero():
    acting = "Missouri"
    peers = _same_region_peers(acting)
    s = GameState()
    for k in peers:
        s.tribe_relations[k] = 1
    host = _Host(s)
    host._propagate_tribal_reputation(acting, -20)
    for k in peers:
        assert s.tribe_relations[k] == 0  # clamped, not negative


def test_reputation_positive_ripple_clamps_at_hundred():
    acting = "Missouri"
    peers = _same_region_peers(acting)
    s = GameState()
    for k in peers:
        s.tribe_relations[k] = 99
    host = _Host(s)
    host._propagate_tribal_reputation(acting, 40)
    for k in peers:
        assert s.tribe_relations[k] == 100  # clamped, not 99 + 10
