"""Load game configuration from JSON files in the config/ directory."""

from __future__ import annotations

import json
from dataclasses import fields
from pathlib import Path
from typing import Any, Dict, List

from lewis_clark.game_config import GameConfig

_REPO_ROOT = Path(__file__).resolve().parent.parent
_CONFIG = _REPO_ROOT / "config"


def _path(name: str) -> Path:
    return _CONFIG / f"{name}.json"


def _load(name: str) -> Any:
    with open(_path(name), encoding="utf-8") as f:
        return json.load(f)


def _hydrate_season_dict(d: Dict[str, Any]) -> Dict[str, Any]:
    return {k: tuple(v) if isinstance(v, list) else v for k, v in d.items()}


def _hydrate_terrain_data(d: Dict[str, Any]) -> Dict[str, Any]:
    out: Dict[str, Any] = {}
    for k, sub in d.items():
        sub = dict(sub)
        if "col" in sub and isinstance(sub["col"], list):
            sub["col"] = tuple(sub["col"])
        out[k] = sub
    return out


def _parse_wp_hex(raw: Dict[str, Any]) -> Dict[int, Any]:
    return {int(k): tuple(v) for k, v in raw.items()}


def _parse_route_options(raw: Dict[str, Any]) -> Dict[Any, Any]:
    def key_from_str(s: str):
        s = s.strip()
        if s.startswith("[") and s.endswith("]"):
            s = s[1:-1]
        parts = [int(x.strip()) for x in s.split(",")]
        return tuple(parts)

    return {key_from_str(k): v for k, v in raw.items()}


def _parse_tribe_at_wp(raw: Dict[str, Any]) -> Dict[int, str]:
    return {int(k): v for k, v in raw.items()}


def _hydrate_resources(raw: List[Any]) -> List[Any]:
    rows = []
    for row in raw:
        coord, rtype, name, desc, effect = row
        rows.append((tuple(coord), rtype, name, desc, effect))
    return rows


def _hydrate_rumours(raw: List[Any]) -> List[Any]:
    return [(tuple(pair), text) for pair, text in raw]


def _hydrate_cine_scenes(raw: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    for scene in raw:
        acc = scene.get("accent")
        if isinstance(acc, list) and len(acc) == 3:
            scene["accent"] = tuple(acc)
    return raw


def load_game_config() -> GameConfig:
    """Load all JSON game data into a :class:`GameConfig` instance."""
    d = _load("display")
    pal = _load("palette")
    palette = {name: tuple(triple) for name, triple in pal.items()}
    wp_hex = _parse_wp_hex(_load("WP_HEX"))
    return GameConfig(
        SW=d["SW"],
        SH=d["SH"],
        FPS=d["FPS"],
        HEX_COLS=d["HEX_COLS"],
        HEX_ROWS=d["HEX_ROWS"],
        palette=palette,
        SEASON_COL=_hydrate_season_dict(_load("SEASON_COL")),
        SEASON_BG=_hydrate_season_dict(_load("SEASON_BG")),
        TERRITORIES=_load("TERRITORIES"),
        TERR_FILLS={k: tuple(v) for k, v in _load("TERR_FILLS").items()},
        WAYPOINTS=_load("WAYPOINTS"),
        WP_HEX=wp_hex,
        HEX_WP={v: k for k, v in wp_hex.items()},
        WP_GENERIC=_load("WP_GENERIC"),
        RIVER_PATHS=[[tuple(p) for p in path] for path in _load("RIVER_PATHS")],
        TERRAIN_DATA=_hydrate_terrain_data(_load("TERRAIN_DATA")),
        ROUTE_OPTIONS=_parse_route_options(_load("ROUTE_OPTIONS")),
        STARTING_INVENTORY=_load("STARTING_INVENTORY"),
        TRADE_GOOD_VALUES=_load("TRADE_GOOD_VALUES"),
        TRIBES=_load("TRIBES"),
        TRIBE_AT_WAYPOINT=_parse_tribe_at_wp(_load("TRIBE_AT_WAYPOINT")),
        TRIBE_LOCS={k: tuple(v) for k, v in _load("TRIBE_LOCS").items()},
        RESOURCES=_hydrate_resources(_load("RESOURCES")),
        RUMOURS=_hydrate_rumours(_load("RUMOURS")),
        SPECIAL_CHARACTERS=_load("SPECIAL_CHARACTERS"),
        EVENTS=_load("EVENTS"),
        CINE_SCENES=_hydrate_cine_scenes(_load("CINE_SCENES")),
        HEX_CONTENTS={},
    )


def apply_game_config(module: Any, cfg: GameConfig) -> None:
    """Copy every value from *cfg* onto *module* (palette keys become top-level attributes)."""
    for f in fields(cfg):
        val = getattr(cfg, f.name)
        if f.name == "palette":
            for name, triple in val.items():
                setattr(module, name, triple)
        else:
            setattr(module, f.name, val)
    module.game_config = cfg


def load_all(module: Any) -> None:
    """Populate *module* (typically :mod:`lewis_clark.assets`) with config globals."""
    cfg = load_game_config()
    apply_game_config(module, cfg)
