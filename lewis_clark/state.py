"""Persistent expedition state."""

from __future__ import annotations

import calendar
import copy
from dataclasses import dataclass, field, fields
from typing import Any, Dict, List

from lewis_clark import assets
from lewis_clark.hex_grid import get_season


def new_party() -> dict:
    from lewis_clark.corps import new_party as _new_party

    return _new_party()


@dataclass
class GameState:
    current_wp: int = 0
    food: int = 100
    health: int = 100
    morale: int = 80
    current_month: int = 5
    current_year: int = 1804
    journal: List[str] = field(default_factory=list)
    completed_objectives: List[int] = field(default_factory=list)
    tribe_relations: Dict = field(default_factory=dict)
    inventory: Dict = field(default_factory=dict)
    characters: Dict = field(default_factory=dict)
    discoveries: int = 0
    peaceful_tribes: int = 0
    traded_tribes: List[str] = field(default_factory=list)
    route_taken: List[str] = field(default_factory=list)
    events_seen: List[str] = field(default_factory=list)
    game_over: bool = False
    victory: bool = False
    hex_col: int = 27
    hex_row: int = 12
    hex_trail: List = field(default_factory=list)
    visited_hexes: List = field(default_factory=list)
    used_resources: List = field(default_factory=list)
    # P1 — active character ability cooldowns (char_key -> hexes until ready)
    char_cooldowns: Dict = field(default_factory=dict)
    clark_route_buffer: int = 0
    scout_preview: bool = False
    # P2 — event trigger chain queue [{event_id, hexes_remaining}]
    pending_triggers: List = field(default_factory=list)
    # P3 — calendar deadline state
    winter_locked: bool = False
    # P4 — regional reputation shared across tribe regions
    tribal_reputation: int = 50
    # Open world — Calendar day, Day Clock, and where the Corps is
    current_day: int = 14
    minute_of_day: int = 8 * 60
    current_region: str = ""
    landmarks_visited: List[str] = field(default_factory=list)
    # The Corps — named Companions' health/Conditions, headcount, Endings
    party: Dict = field(default_factory=dict)
    corps_strength: int = -1
    zero_morale_days: int = 0
    ending: str = ""

    def __post_init__(self):
        if not self.tribe_relations:
            self.tribe_relations = {k: v["relation"] for k, v in assets.TRIBES.items()}
        if not self.inventory:
            self.inventory = copy.copy(assets.STARTING_INVENTORY)
        if not self.characters:
            self.characters = copy.deepcopy(assets.SPECIAL_CHARACTERS)
        if not self.hex_trail:
            self.hex_trail = [(self.hex_col, self.hex_row)]
        if not self.visited_hexes:
            self.visited_hexes = [(self.hex_col, self.hex_row)]
        if not self.current_region:
            self.current_region = assets.START_REGION
        if not self.party:
            self.party = new_party()
        if self.corps_strength < 0:
            self.corps_strength = assets.CONDITIONS["corps"]["starting_strength"]

    @property
    def season(self):
        return get_season(self.current_month)

    @property
    def date_str(self):
        M = [
            "",
            "January",
            "February",
            "March",
            "April",
            "May",
            "June",
            "July",
            "August",
            "September",
            "October",
            "November",
            "December",
        ]
        return f"{M[self.current_month]} {self.current_year}"

    @property
    def full_date_str(self):
        return f"{calendar.month_name[self.current_month]} {self.current_day}, {self.current_year}"

    @property
    def clock_str(self):
        return f"{self.minute_of_day // 60:02d}:{self.minute_of_day % 60:02d}"

    def advance_date(self, days=14):
        """Move the Calendar forward by whole days (month and year roll over)."""
        self.current_day += int(days)
        while True:
            dim = calendar.monthrange(self.current_year, self.current_month)[1]
            if self.current_day <= dim:
                break
            self.current_day -= dim
            self.current_month += 1
            if self.current_month > 12:
                self.current_month = 1
                self.current_year += 1

    def advance_minutes(self, minutes):
        """Run the Day Clock forward; each midnight passed advances the Calendar."""
        total = self.minute_of_day + int(minutes)
        days, self.minute_of_day = divmod(total, 24 * 60)
        if days:
            self.advance_date(days)

    def sit_out_winter(self) -> int:
        """Winter Lock: the Corps halts until March and pays for it. Returns health lost."""
        months_to_march = (3 - self.current_month) % 12 or 12
        penalty = min(months_to_march * 6, 40)
        self.health = max(5, self.health - penalty)
        self.food = max(0, self.food - months_to_march * 4)
        self.morale = max(0, self.morale - months_to_march * 3)
        if self.current_month >= 3:  # caught in autumn: the thaw is next year
            self.current_year += 1
        self.current_month = 3
        self.current_day = 1
        self.winter_locked = False
        self.clamp()
        return penalty

    def add_journal(self, e):
        self.journal.append(f"[{self.date_str}] {e}")

    def clamp(self):
        self.food = max(0, min(100, self.food))
        self.health = max(0, min(100, self.health))
        self.morale = max(0, min(100, self.morale))

    def apply_effect(self, effect, chars_active):
        self.food += effect.get("food", 0)
        self.health += effect.get("health", 0)
        self.morale += effect.get("morale", 0)
        for item, qty in effect.get("inventory", {}).items():
            self.inventory[item] = max(0, self.inventory.get(item, 0) + qty)
        for item, qty in effect.get("inventory_gain", {}).items():
            self.inventory[item] = self.inventory.get(item, 0) + qty
        for ck, bonus in effect.get("char_bonus", {}).items():
            if chars_active.get(ck):
                self.food += bonus.get("food", 0)
                self.health += bonus.get("health", 0)
                self.morale += bonus.get("morale", 0)
        if chars_active.get("york"):
            self.morale += 2
        if chars_active.get("sacagawea"):
            self.food += 3
        if chars_active.get("drouillard"):
            self.inventory["Furs"] = self.inventory.get("Furs", 0) + 1
        self.clamp()

    def to_dict(self) -> dict[str, Any]:
        """Serialize for save files; keys match :meth:`from_dict` expectations."""
        out: dict[str, Any] = {}
        for f in fields(self):
            if f.name == "characters":
                out["characters"] = {
                    k: {"active": v["active"]} for k, v in self.characters.items()
                }
            else:
                out[f.name] = getattr(self, f.name)
        return out

    # Save file may omit these; :meth:`from_dict` applies defaults or rebuilds structure.
    _SAVE_OPTIONAL_KEYS = frozenset(
        {
            "characters",
            "events_seen",
            "hex_col",
            "hex_row",
            "hex_trail",
            "used_resources",
            "visited_hexes",
            "char_cooldowns",
            "clark_route_buffer",
            "scout_preview",
            "pending_triggers",
            "winter_locked",
            "tribal_reputation",
            "current_day",
            "minute_of_day",
            "current_region",
            "landmarks_visited",
            "party",
            "corps_strength",
            "zero_morale_days",
            "ending",
        }
    )

    @classmethod
    def _required_save_keys(cls) -> frozenset[str]:
        return frozenset(f.name for f in fields(cls)) - cls._SAVE_OPTIONAL_KEYS

    @classmethod
    def from_dict(cls, d: dict[str, Any]) -> GameState:
        required = cls._required_save_keys()
        missing = required - d.keys()
        if missing:
            raise KeyError(f"Save data missing keys: {sorted(missing)}")
        s = cls.__new__(cls)
        for k in required:
            setattr(s, k, d[k])
        s.events_seen = d.get("events_seen", [])
        cw = s.current_wp
        s.hex_col = d.get("hex_col", assets.WP_HEX[cw][0])
        s.hex_row = d.get("hex_row", assets.WP_HEX[cw][1])
        s.hex_trail = d.get("hex_trail", [(s.hex_col, s.hex_row)])
        s.visited_hexes = d.get("visited_hexes", [(s.hex_col, s.hex_row)])
        s.used_resources = d.get("used_resources", [])
        s.char_cooldowns = d.get("char_cooldowns", {})
        s.clark_route_buffer = d.get("clark_route_buffer", 0)
        s.scout_preview = d.get("scout_preview", False)
        s.pending_triggers = d.get("pending_triggers", [])
        s.winter_locked = d.get("winter_locked", False)
        s.tribal_reputation = d.get("tribal_reputation", 50)
        s.current_day = d.get("current_day", 1)
        s.minute_of_day = d.get("minute_of_day", 8 * 60)
        s.current_region = d.get("current_region") or _region_for_waypoint(cw)
        s.landmarks_visited = d.get("landmarks_visited", [])
        s.party = d.get("party") or new_party()
        s.corps_strength = d.get("corps_strength", assets.CONDITIONS["corps"]["starting_strength"])
        s.zero_morale_days = d.get("zero_morale_days", 0)
        s.ending = d.get("ending", "")
        s.characters = copy.deepcopy(assets.SPECIAL_CHARACTERS)
        for k, v in d.get("characters", {}).items():
            if k in s.characters:
                s.characters[k]["active"] = v["active"]
        return s


def _region_for_waypoint(wp: int) -> str:
    """Region a pre-open-world save belongs in: the last one whose Landmarks the Corps has reached."""
    found = assets.START_REGION
    for rid, region in assets.REGIONS.items():
        wps = [lm["waypoint"] for lm in region["landmarks"] if "waypoint" in lm]
        if wps and min(wps) <= wp:
            found = rid
    return found
