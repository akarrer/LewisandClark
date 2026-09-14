"""The Corps: named Companions' health and Conditions, Corps Strength, and Endings.

Food, morale and the rank-and-file's health (``state.health``) are shared by the
whole Corps. Each named Companion also has their own health and Conditions; a
Condition drains health day by day, may slow them or block their Ability, and
wears off after its course. A Companion at 0 health dies.

Time only moves forward through :func:`pass_days` (and :func:`pass_minutes` for
the Day Clock), so every day that passes — walking a Region, on a Leg, or
wintering — ticks the Corps the same way.

Endings are checked as days pass and stored on ``state.ending``.
"""

from __future__ import annotations

import random

from lewis_clark import assets

LEADER_DIED = "leader_died"
CORPS_COLLAPSED = "corps_collapsed"
MUTINY = "mutiny"
LOST_SEASON = "lost_season"
REACHED_PACIFIC = "reached_pacific"


def rules() -> dict:
    return assets.CONDITIONS["corps"]


def condition(cid: str) -> dict:
    return assets.CONDITIONS["conditions"][cid]


# ---------------------------------------------------------------- roster


def new_party() -> dict:
    return {
        key: {"health": 100, "conditions": [], "alive": True}
        for key in assets.SPECIAL_CHARACTERS
    }


def name(key: str) -> str:
    return assets.SPECIAL_CHARACTERS[key]["name"]


def is_active(state, key: str) -> bool:
    """With the Corps and alive."""
    return bool(state.characters.get(key, {}).get("active")) and state.party[key]["alive"]


def active_companions(state) -> list[str]:
    return [k for k in state.party if is_active(state, k)]


def followers(state) -> list[str]:
    """Active Companions walking behind the Leader."""
    leader = rules()["leader"]
    return [k for k in active_companions(state) if k != leader]


def update_roster(state) -> None:
    """Companions join when the Corps reaches the waypoint they joined at."""
    for key, data in assets.SPECIAL_CHARACTERS.items():
        ch = state.characters[key]
        if not ch.get("active") and state.party[key]["alive"] and state.current_wp >= data.get("joined_at", 0):
            ch["active"] = True
            state.add_journal(f"{data['name']} joins the Corps.")


# ------------------------------------------------------------ conditions


def has_condition(state, key: str, cid: str) -> bool:
    return any(c["id"] == cid for c in state.party[key]["conditions"])


def add_condition(state, key: str, cid: str) -> None:
    """Give ``key`` a Condition, or restart its course if they already have it."""
    member = state.party[key]
    if not member["alive"]:
        return
    days = condition(cid)["days"]
    for c in member["conditions"]:
        if c["id"] == cid:
            c["days"] = days
            return
    member["conditions"].append({"id": cid, "days": days})
    state.add_journal(f"{name(key)} is {condition(cid)['name'].lower()}.")


def clear_condition(state, key: str, cid: str) -> None:
    state.party[key]["conditions"] = [c for c in state.party[key]["conditions"] if c["id"] != cid]


def can_use_ability(state, key: str) -> bool:
    if not is_active(state, key):
        return False
    return not any(condition(c["id"])["blocks_ability"] for c in state.party[key]["conditions"])


def move_multiplier(state, key: str) -> float:
    mult = 1.0
    for c in state.party[key]["conditions"]:
        mult = min(mult, condition(c["id"])["move_mult"])
    return mult


def _damage(state, key: str, amount: int) -> None:
    member = state.party[key]
    member["health"] = max(0, min(100, member["health"] + amount))
    if member["health"] == 0 and member["alive"]:
        member["alive"] = False
        member["conditions"] = []
        state.add_journal(f"{name(key)} has died.")


# ------------------------------------------------------------------ time


def pass_minutes(state, minutes: int, rng: random.Random) -> None:
    """Run the Day Clock; every midnight crossed is a day passed in the field."""
    total = state.minute_of_day + int(minutes)
    days, state.minute_of_day = divmod(total, 24 * 60)
    if days:
        pass_days(state, days, rng, rations=True)


def pass_days(state, days: int, rng: random.Random, starving_days: int = 0, rations: bool = False) -> None:
    """Advance the Calendar ``days`` days, ticking the Corps each day.

    ``rations`` eats the daily ration from shared food (the field; Legs pay
    their food up front). On a Leg, ``starving_days`` marks how many of the
    final days the Corps had nothing left to eat.
    """
    r = rules()
    for i in range(int(days)):
        state.advance_date(1)
        if rations:
            state.food = max(0, state.food - r["daily_ration"])
        starving = state.food == 0 if rations else i >= days - starving_days
        _tick_day(state, rng, starving)
        if state.ending:
            return


def _tick_day(state, rng: random.Random, starving: bool) -> None:
    r = rules()
    for key in active_companions(state):
        member = state.party[key]
        if starving and not has_condition(state, key, "starving"):
            add_condition(state, key, "starving")
        elif not starving and has_condition(state, key, "starving"):
            clear_condition(state, key, "starving")

        change = 0
        still = []
        for c in member["conditions"]:
            change += condition(c["id"])["health_per_day"]
            if c["days"] is None:
                still.append(c)
                continue
            c["days"] -= 1
            if c["days"] > 0:
                still.append(c)
            else:
                state.add_journal(f"{name(key)} is no longer {condition(c['id'])['name'].lower()}.")
        member["conditions"] = still
        if change == 0 and not starving:
            change = r["companion_regen_per_day"]
        _damage(state, key, change)

    if starving:
        state.health = max(0, state.health + r["corps_health_per_starving_day"])
    chance = r["attrition_chance_starving"] if starving else (
        r["attrition_chance_low_health"] if state.health < r["low_health_below"] else 0.0
    )
    if chance and rng.random() < chance:
        state.corps_strength = max(0, state.corps_strength - 1)
        cause = "hunger" if starving else "sickness"
        state.add_journal(f"A man of the Corps is lost to {cause}. {state.corps_strength} remain.")

    state.zero_morale_days = state.zero_morale_days + 1 if state.morale <= 0 else 0
    check_ending(state)


# ---------------------------------------------------------------- hazards


def leg_hazards(state, option, rng: random.Random) -> None:
    """A Leg's risk: each Companion may pick up a Condition fitting the terrain."""
    table = assets.CONDITIONS["leg_hazards"]
    chance = table["chance_per_companion"].get(option.risk, 0.0)
    weights = table["by_tag"].get(option.tag, {"wounded": 1})
    ids, w = list(weights), list(weights.values())
    for key in active_companions(state):
        if rng.random() < chance:
            add_condition(state, key, rng.choices(ids, w)[0])


def winter_lock_hardship(state, rng: random.Random) -> None:
    """Caught by winter: frostbite, and without supplies the season is lost."""
    r = rules()
    if state.food < r["lost_season_food_below"]:
        state.ending = state.ending or LOST_SEASON
        return
    for key in active_companions(state):
        if rng.random() < r["winter_lock_frostbite_chance"]:
            add_condition(state, key, "frostbitten")


# ---------------------------------------------------------------- endings


def check_ending(state) -> str:
    if state.ending:
        return state.ending
    r = rules()
    if not state.party[r["leader"]]["alive"]:
        state.ending = LEADER_DIED
    elif state.corps_strength < r["collapse_below"]:
        state.ending = CORPS_COLLAPSED
    elif state.zero_morale_days >= r["mutiny_after_days"]:
        state.ending = MUTINY
    elif r["pacific_landmark"] in state.landmarks_visited:
        state.ending = REACHED_PACIFIC
    return state.ending
