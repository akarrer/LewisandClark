"""Region data, generated Region worlds, and Legs between Regions."""

from __future__ import annotations

import random

import pytest
from lewis_clark import assets, legs
from lewis_clark.region import build_world
from lewis_clark.state import GameState

REGION_IDS = list(assets.REGIONS)


# ------------------------------------------------------------------ data


def test_start_region_exists():
    assert assets.START_REGION in assets.REGIONS


def test_every_leg_leads_to_a_known_region():
    for rid, r in assets.REGIONS.items():
        for leg in r["legs"]:
            assert leg["to"] in assets.REGIONS, f"{rid} -> {leg['to']}"
            assert leg["options"], f"{rid} -> {leg['to']} has no options"


def test_route_runs_from_start_to_the_pacific():
    seen, rid = [], assets.START_REGION
    while True:
        seen.append(rid)
        outs = assets.REGIONS[rid]["legs"]
        if not outs:
            break
        rid = outs[0]["to"]
        assert rid not in seen, "route loops"
    assert set(seen) == set(assets.REGIONS)
    assert any(lm["id"] == "fort_clatsop" for lm in assets.REGIONS[seen[-1]]["landmarks"])


def test_landmark_ids_unique_and_waypoints_valid():
    ids = [lm["id"] for r in assets.REGIONS.values() for lm in r["landmarks"]]
    assert len(ids) == len(set(ids))
    for r in assets.REGIONS.values():
        for lm in r["landmarks"]:
            if "waypoint" in lm:
                assert 0 <= lm["waypoint"] < len(assets.WAYPOINTS)


def test_slice_region_holds_its_historical_landmarks():
    ids = [lm["id"] for lm in assets.REGIONS["sioux_country"]["landmarks"]]
    assert ids == ["council_bluff", "floyds_bluff", "calumet_bluff", "bad_river"]


# ------------------------------------------------------------------ worlds


def test_world_generation_is_deterministic():
    a, b = build_world("sioux_country"), build_world("sioux_country")
    assert a.tiles == b.tiles and a.landmarks == b.landmarks and a.spawn == b.spawn


def test_regions_look_different():
    assert build_world("lower_missouri").tiles != build_world("sioux_country").tiles


@pytest.mark.parametrize("rid", REGION_IDS)
def test_every_landmark_and_the_landing_can_be_walked_to(rid):
    world = build_world(rid)
    assert world.walkable(*world.spawn)
    for lm in world.landmarks:
        assert world.reachable(world.spawn, (lm["wx"], lm["wy"])), lm["id"]
    assert world.reachable(world.spawn, world.landing)


@pytest.mark.parametrize("rid", REGION_IDS)
def test_landmarks_run_upstream_in_route_order(rid):
    world = build_world(rid)
    ys = [lm["wy"] for lm in world.landmarks]
    assert ys == sorted(ys, reverse=True)
    assert world.spawn[1] > ys[0] and world.landing[1] < ys[-1]


# ------------------------------------------------------------------ legs


def test_options_come_from_region_data():
    opts = legs.options_from("lower_missouri")
    assert [o.name for o in opts] == ["Up the Missouri", "Overland Trail"]
    assert all(o.to == "sioux_country" for o in opts)
    assert legs.options_from("columbia") == []


def test_take_leg_pays_travels_and_arrives():
    s = GameState(current_month=5, current_day=20, food=90, health=90, morale=70)
    s.minute_of_day = 20 * 60
    opt = legs.options_from("lower_missouri")[1]  # Overland Trail, 64 days
    legs.take_leg(s, opt, random.Random(1))
    assert s.current_region == "sioux_country"
    assert (s.current_month, s.current_day) == (7, 23)
    assert (s.food, s.health, s.morale) == (77, 84, 70)
    assert s.minute_of_day == legs.ARRIVAL_MINUTE
    assert not s.winter_locked
    assert any("Left The Lower Missouri by the Overland Trail" in j for j in s.journal)


def test_arrival_preview_does_not_change_state():
    s = GameState(current_month=5, current_day=17)
    opt = legs.options_from("lower_missouri")[0]  # Up the Missouri, 78 days
    assert legs.arrival_str(s, opt) == "August 3, 1804"  # Council Bluff, historically
    assert (s.current_month, s.current_day) == (5, 17)


@pytest.mark.parametrize(
    "rid, depart, arrive",
    [
        ("lower_missouri", (1804, 5, 17), (1804, 8, 3)),  # Council Bluff
        ("sioux_country", (1804, 8, 6), (1804, 10, 26)),  # Mandan villages
        ("upper_missouri", (1805, 4, 28), (1805, 6, 3)),  # Marias River
        ("great_falls", (1805, 6, 6), (1805, 7, 27)),  # Three Forks
        ("shoshone_country", (1805, 7, 30), (1805, 9, 9)),  # Travelers' Rest
        ("bitterroots", (1805, 9, 12), (1805, 10, 22)),  # Celilo Falls
    ],
)
def test_steady_legs_track_the_historical_calendar(rid, depart, arrive):
    y, m, d = depart
    s = GameState(current_region=rid, current_year=y, current_month=m, current_day=d)
    p = legs.plan(s, legs.options_from(rid)[0])
    assert p.arrive == arrive and not p.winter_lock and p.winter_until is None


def test_late_departure_to_open_country_is_winter_locked():
    s = GameState(current_region="shoshone_country", current_month=8, current_day=30, current_year=1805)
    opt = legs.options_from("shoshone_country")[0]  # 41 days -> Oct 10
    assert legs.winter_lock_risk(s, opt) is False
    s.current_month, s.current_day = 9, 25  # 41 days -> Nov 5
    assert legs.winter_lock_risk(s, opt) is True
    health = s.health
    legs.take_leg(s, opt)
    assert s.current_region == "bitterroots"
    assert (s.current_year, s.current_month, s.current_day) == (1806, 3, 1)
    assert s.health < health and not s.winter_locked


def test_reaching_winter_quarters_in_winter_is_safe():
    s = GameState(current_region="sioux_country", current_month=9, current_day=20)
    opt = legs.options_from("sioux_country")[1]  # 92 days -> late December
    assert legs.winter_lock_risk(s, opt) is False
    legs.take_leg(s, opt)
    assert s.current_month == 12 and s.current_region == "mandan_villages"


def test_leaving_winter_quarters_late_winters_there_first():
    s = GameState(current_region="mandan_villages", current_month=10, current_day=29, food=80)
    opt = legs.options_from("mandan_villages")[0]  # 18 days would land in November
    p = legs.plan(s, opt)
    assert p.winter_until == (1805, 4, 7) and p.arrive == (1805, 4, 25) and not p.winter_lock
    legs.take_leg(s, opt)
    assert (s.current_year, s.current_month, s.current_day) == (1805, 4, 25)
    assert s.food == 80 + legs.WINTERING_FOOD + opt.food
    assert any("winters at The Mandan Villages" in j for j in s.journal)


def test_leaving_winter_quarters_in_good_weather_goes_straight_away():
    s = GameState(current_region="mandan_villages", current_month=5, current_day=1, current_year=1805)
    p = legs.plan(s, legs.options_from("mandan_villages")[0])
    assert p.winter_until is None and p.arrive == (1805, 5, 19)
