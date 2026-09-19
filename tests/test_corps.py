"""The Corps: Companion health and Conditions, Corps Strength, and Endings."""

from __future__ import annotations

import random

import pytest
from lewis_clark import assets, corps, legs
from lewis_clark.state import GameState


class FixedRng:
    """Every roll comes up ``value``; weighted picks take the first option."""

    def __init__(self, value):
        self.value = value

    def random(self):
        return self.value

    def choices(self, population, weights):
        return [population[0]]


ALWAYS, NEVER = FixedRng(0.0), FixedRng(0.99)


@pytest.fixture
def s():
    return GameState()


# ---------------------------------------------------------------- roster


def test_new_expedition_roster(s):
    assert set(s.party) == set(assets.SPECIAL_CHARACTERS)
    assert all(m["health"] == 100 and m["alive"] and not m["conditions"] for m in s.party.values())
    assert s.corps_strength == assets.CONDITIONS["corps"]["starting_strength"]
    assert corps.followers(s) == ["clark", "york", "drouillard"]
    assert not corps.is_active(s, "sacagawea")


def test_sacagawea_joins_at_fort_mandan(s):
    s.current_wp = 4
    corps.update_roster(s)
    assert corps.is_active(s, "sacagawea")
    assert s.journal[-1].endswith("Sacagawea joins the Corps.")
    corps.update_roster(s)
    assert sum("joins the Corps" in j for j in s.journal) == 1


# ------------------------------------------------------------ conditions


def test_condition_blocks_ability_and_slows(s):
    corps.add_condition(s, "clark", "wounded")
    assert not corps.can_use_ability(s, "clark")
    assert corps.move_multiplier(s, "clark") == pytest.approx(0.8)
    assert corps.can_use_ability(s, "york")
    assert "Clark is wounded." in s.journal[-1]


def test_condition_runs_its_course_then_regen(s):
    corps.add_condition(s, "york", "wounded")  # -1/day for 10 days
    corps.pass_days(s, 10, NEVER)
    assert s.party["york"]["health"] == 90
    assert not corps.has_condition(s, "york", "wounded")
    assert any("York is no longer wounded." in j for j in s.journal)
    corps.pass_days(s, 3, NEVER)
    assert s.party["york"]["health"] == 93


def test_catching_it_again_restarts_the_course(s):
    corps.add_condition(s, "york", "sick")
    corps.pass_days(s, 4, NEVER)
    corps.add_condition(s, "york", "sick")
    assert s.party["york"]["conditions"] == [{"id": "sick", "days": 6}]


def test_healthy_companions_stay_capped(s):
    corps.pass_days(s, 5, NEVER)
    assert s.party["lewis"]["health"] == 100


# ------------------------------------------------------------- starvation


def test_field_rations_and_starvation(s):
    s.food = 3
    corps.pass_days(s, 1, NEVER, rations=True)  # 3 -> 1
    assert not corps.has_condition(s, "clark", "starving")
    corps.pass_days(s, 2, NEVER, rations=True)  # 1 -> 0: two days with nothing
    assert s.food == 0 and corps.has_condition(s, "clark", "starving")
    assert s.party["clark"]["health"] == 96
    s.food = 50
    corps.pass_days(s, 1, NEVER, rations=True)
    assert not corps.has_condition(s, "clark", "starving")


def test_day_clock_eats_one_ration_per_midnight(s):
    s.minute_of_day, s.food = 23 * 60, 50
    corps.pass_minutes(s, 30, NEVER)
    assert s.food == 50
    corps.pass_minutes(s, 60, NEVER)
    assert s.food == 48 and s.clock_str == "00:30"


def test_leg_without_enough_food_starves_the_final_days():
    s = GameState(food=6)
    opt = legs.options_from("lower_missouri")[0]  # 78 days, -8 food
    assert legs.starving_days(s, opt) == 20
    legs.take_leg(s, opt, NEVER)
    assert s.food == 0
    assert corps.has_condition(s, "clark", "starving")
    assert s.party["clark"]["health"] == 100 - 20 * 2
    assert s.health == 100 - 20
    assert not s.ending


# ------------------------------------------------------------ death & endings


def test_companion_death(s):
    s.party["drouillard"]["health"] = 3
    corps.add_condition(s, "drouillard", "sick")
    corps.pass_days(s, 1, NEVER)
    assert not s.party["drouillard"]["alive"]
    assert "drouillard" not in corps.followers(s)
    assert "Drouillard has died." in s.journal[-1]
    assert not s.ending


def test_leader_death_ends_the_expedition(s):
    s.party["lewis"]["health"] = 2
    corps.add_condition(s, "lewis", "sick")
    corps.pass_days(s, 5, NEVER)
    assert s.ending == corps.LEADER_DIED


def test_starving_attrition_collapses_the_corps(s):
    s.food = 0
    s.corps_strength = 13
    corps.pass_days(s, 3, ALWAYS, rations=True)
    assert s.corps_strength == 11
    assert s.ending == corps.CORPS_COLLAPSED
    assert any("lost to hunger" in j for j in s.journal)


def test_sustained_zero_morale_is_mutiny(s):
    s.morale = 0
    corps.pass_days(s, 4, NEVER)
    assert not s.ending
    corps.pass_days(s, 1, NEVER)
    assert s.ending == corps.MUTINY


def test_reaching_fort_clatsop_is_an_ending(s):
    s.landmarks_visited.append("fort_clatsop")
    assert corps.check_ending(s) == corps.REACHED_PACIFIC


# ------------------------------------------------------------ Legs & winter


def test_risky_leg_hazards_fit_the_terrain(s):
    opt = next(o for o in legs.options_from("shoshone_country") if o.risk == "very_high")
    corps.leg_hazards(s, opt, ALWAYS)
    for key in corps.active_companions(s):
        assert corps.has_condition(s, key, "exhausted")  # first of the mountain table


def test_lucky_leg_has_no_hazards(s):
    opt = legs.options_from("lower_missouri")[0]
    corps.leg_hazards(s, opt, NEVER)
    assert all(not s.party[k]["conditions"] for k in s.party)


def test_winter_lock_without_supplies_loses_the_season():
    s = GameState(current_region="shoshone_country", current_month=9, current_day=25, current_year=1805, food=15)
    opt = legs.options_from("shoshone_country")[0]  # -10 food, lands in November
    legs.take_leg(s, opt, NEVER)
    assert s.ending == corps.LOST_SEASON


def test_winter_lock_with_supplies_brings_frostbite():
    s = GameState(current_region="shoshone_country", current_month=9, current_day=25, current_year=1805)
    legs.take_leg(s, legs.options_from("shoshone_country")[0], ALWAYS)
    assert not s.ending or s.ending != corps.LOST_SEASON
    assert all(corps.has_condition(s, k, "frostbitten") for k in corps.active_companions(s))


def test_wintering_in_quarters_lets_the_wounded_heal():
    s = GameState(current_region="mandan_villages", current_month=10, current_day=29)
    corps.add_condition(s, "clark", "wounded")
    legs.take_leg(s, legs.options_from("mandan_villages")[0], NEVER)
    assert not corps.has_condition(s, "clark", "wounded")
    assert s.party["clark"]["health"] == 100
    assert not s.ending


# ------------------------------------------------------------------ saves


def test_party_survives_a_save_roundtrip(s):
    corps.add_condition(s, "york", "frostbitten")
    s.corps_strength = 20
    loaded = GameState.from_dict(s.to_dict())
    assert loaded.party == s.party and loaded.corps_strength == 20


def test_old_save_gets_a_fresh_party(s):
    d = s.to_dict()
    for k in ("party", "corps_strength", "zero_morale_days", "ending"):
        d.pop(k)
    loaded = GameState.from_dict(d)
    assert loaded.party == corps.new_party() and loaded.ending == ""


def test_real_rng_is_accepted(s):
    corps.pass_days(s, 30, random.Random(7), rations=True)
    assert s.food == 40
