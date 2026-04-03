"""Structured game data loaded from JSON (single object; also applied to :mod:`lewis_clark.assets`)."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Dict, List, Tuple


@dataclass
class GameConfig:
    """All configuration normally exposed as attributes on :mod:`lewis_clark.assets`.

    Palette colour names are stored in ``palette`` and flattened onto *module* by
    :func:`lewis_clark.config.apply_game_config`.
    """

    SW: int
    SH: int
    FPS: int
    HEX_COLS: int
    HEX_ROWS: int
    palette: Dict[str, Tuple[int, int, int]]
    SEASON_COL: Dict[str, Any]
    SEASON_BG: Dict[str, Any]
    TERRITORIES: Any
    TERR_FILLS: Dict[str, Tuple[int, int, int]]
    WAYPOINTS: Any
    WP_HEX: Dict[int, Any]
    HEX_WP: Dict[Any, int]
    WP_GENERIC: Any
    RIVER_PATHS: List[List[Tuple[int, int]]]
    TERRAIN_DATA: Dict[str, Any]
    ROUTE_OPTIONS: Dict[Any, Any]
    STARTING_INVENTORY: Dict[str, Any]
    TRADE_GOOD_VALUES: Dict[str, Any]
    TRIBES: Any
    TRIBE_AT_WAYPOINT: Dict[int, str]
    TRIBE_LOCS: Dict[str, Tuple[int, int]]
    RESOURCES: List[Any]
    RUMOURS: List[Any]
    SPECIAL_CHARACTERS: Any
    EVENTS: Any
    CINE_SCENES: Any
    HEX_CONTENTS: Dict[Any, Any]
