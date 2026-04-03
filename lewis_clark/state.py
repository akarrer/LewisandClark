"""Persistent expedition state."""

from __future__ import annotations

import copy
from dataclasses import dataclass, field, fields
from typing import Any, Dict, List

from lewis_clark import assets
from lewis_clark.hex_grid import get_season


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

    def advance_date(self, days=14):
        self.current_month += 1
        if self.current_month > 12:
            self.current_month = 1
            self.current_year += 1

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
        s.characters = copy.deepcopy(assets.SPECIAL_CHARACTERS)
        for k, v in d.get("characters", {}).items():
            if k in s.characters:
                s.characters[k]["active"] = v["active"]
        return s
