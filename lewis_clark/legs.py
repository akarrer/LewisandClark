"""Legs: journeys between Regions taken on the Expedition Map.

A Leg costs Calendar days and supplies. Inside a Region the Day Clock runs at two
in-game hours per real minute, so a Region only takes a day or two of Calendar
time; Leg lengths in ``REGIONS.json`` carry the rest, calibrated so the steady
option reaches each Region near its historical date after a short stay.

Winter is decided when the Corps departs:
- leaving **winter quarters** on a Leg that would arrive in winter, the Corps
  winters where it is until the Region's ``winter_until`` date, then sets out;
- otherwise, arriving between November and February anywhere but winter quarters
  means **Winter Lock** — the Corps is caught on the way and pays for it.
"""

from __future__ import annotations

import calendar
import copy
import random
from dataclasses import dataclass

from lewis_clark import assets, corps

WINTER_MONTHS = frozenset({11, 12, 1, 2})
ARRIVAL_MINUTE = 8 * 60  # the Corps makes landfall in the morning
WINTERING_FOOD = -10  # a winter in quarters is lean but survivable


@dataclass(frozen=True)
class LegOption:
    to: str
    name: str
    tag: str
    days: int
    food: int
    health: int
    morale: int
    risk: str
    desc: str

    @property
    def destination_name(self) -> str:
        return assets.REGIONS[self.to]["name"]


@dataclass(frozen=True)
class LegPlan:
    winter_until: tuple[int, int, int] | None  # wintering in quarters first, until this date
    depart: tuple[int, int, int]
    arrive: tuple[int, int, int]
    winter_lock: bool


def options_from(region_id: str) -> list[LegOption]:
    """Every way out of ``region_id``, destination by destination."""
    out = []
    for leg in assets.REGIONS[region_id].get("legs", []):
        for o in leg["options"]:
            out.append(
                LegOption(
                    to=leg["to"],
                    name=o["name"],
                    tag=o["tag"],
                    days=int(o["days"]),
                    food=int(o.get("food", 0)),
                    health=int(o.get("health", 0)),
                    morale=int(o.get("morale", 0)),
                    risk=o.get("risk", "low"),
                    desc=o.get("desc", ""),
                )
            )
    return out


def _ymd(s) -> tuple[int, int, int]:
    return s.current_year, s.current_month, s.current_day


def _arrival_month(s, days: int) -> int:
    probe = copy.copy(s)
    probe.advance_date(days)
    return probe.current_month


def _winter_until(s, month: int, day: int) -> tuple[int, int, int]:
    """The next ``month``/``day`` on or after the current date."""
    year = s.current_year
    if (s.current_month, s.current_day) > (month, day):
        year += 1
    return year, month, day


def plan(state, option: LegOption) -> LegPlan:
    """What taking ``option`` now would mean, without changing ``state``."""
    origin = assets.REGIONS[state.current_region]
    dest = assets.REGIONS[option.to]
    probe = copy.copy(state)
    wait = None
    if (
        origin.get("winter_quarters")
        and "winter_until" in origin
        and _arrival_month(probe, option.days) in WINTER_MONTHS
    ):
        wait = _winter_until(probe, *origin["winter_until"])
        probe.current_year, probe.current_month, probe.current_day = wait
    depart = _ymd(probe)
    probe.advance_date(option.days)
    lock = probe.current_month in WINTER_MONTHS and not dest.get("winter_quarters", False)
    return LegPlan(winter_until=wait, depart=depart, arrive=_ymd(probe), winter_lock=lock)


def date_str(ymd: tuple[int, int, int]) -> str:
    y, m, d = ymd
    return f"{calendar.month_name[m]} {d}, {y}"


def arrival_str(state, option: LegOption) -> str:
    return date_str(plan(state, option).arrive)


def winter_lock_risk(state, option: LegOption) -> bool:
    return plan(state, option).winter_lock


def starving_days(state, option: LegOption) -> int:
    """Days at the end of a Leg the Corps would go without food, if supplies can't cover it."""
    if option.food >= 0:
        return 0
    short = max(0, -option.food - state.food)
    return round(option.days * short / -option.food)


def _days_until(state, ymd: tuple[int, int, int]) -> int:
    probe = copy.copy(state)
    days = 0
    while _ymd(probe) < ymd:
        probe.advance_date(1)
        days += 1
    return days


def take_leg(state, option: LegOption, rng: random.Random | None = None) -> None:
    """Resolve a Leg against the shared state: winter if need be, pay, travel, arrive."""
    rng = rng or random.Random()
    origin = assets.REGIONS[state.current_region]["name"]
    p = plan(state, option)

    if p.winter_until:
        state.food += WINTERING_FOOD
        state.clamp()
        state.add_journal(f"The Corps winters at {origin} until {date_str(p.winter_until)}.")
        corps.pass_days(state, _days_until(state, p.winter_until), rng)
        if state.ending:
            return

    hungry = starving_days(state, option)
    state.food += option.food
    state.health += option.health
    state.morale += option.morale
    state.clamp()
    state.route_taken.append(f"{state.current_region}->{option.to}:{option.name}")
    state.add_journal(
        f"Left {origin} by the {option.name} — {option.days} days to {option.destination_name}."
    )
    corps.leg_hazards(state, option, rng)
    corps.pass_days(state, option.days, rng, starving_days=hungry)
    state.minute_of_day = ARRIVAL_MINUTE

    if p.winter_lock and not state.ending:
        state.winter_locked = True
        state.add_journal(
            "Winter closes in before the Corps reaches shelter. We must halt until spring."
        )
        corps.winter_lock_hardship(state, rng)
        lost = state.sit_out_winter()
        state.add_journal(f"The thaw comes at last. The winter cost {lost} health.")

    state.current_region = option.to
    state.add_journal(f"The Corps arrives in {option.destination_name}.")
