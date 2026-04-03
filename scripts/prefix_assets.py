#!/usr/bin/env python3
"""One-off: prefix bare palette/global names with assets. in lewis_clark package."""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
pal = json.load(open(ROOT / "config/palette.json"))
extra = {
    "SW", "SH", "FPS", "F", "HEX_COLS", "HEX_ROWS", "HEX_CONTENTS",
    "SEASON_COL", "SEASON_BG", "TERRITORIES", "TERR_FILLS", "WAYPOINTS", "WP_HEX", "HEX_WP",
    "WP_GENERIC", "RIVER_PATHS", "TERRAIN_DATA", "ROUTE_OPTIONS", "STARTING_INVENTORY",
    "TRADE_GOOD_VALUES", "TRIBES", "TRIBE_AT_WAYPOINT", "TRIBE_LOCS", "RESOURCES",
    "RUMOURS", "SPECIAL_CHARACTERS", "EVENTS", "CINE_SCENES",
}
names = sorted(set(pal.keys()) | extra, key=len, reverse=True)
WB = r"\b"  # word boundary


def prefix_text(text: str) -> str:
    for n in names:
        text = re.sub(r"(?<!\.)" + WB + re.escape(n) + WB, "assets." + n, text)
    while "assets.assets." in text:
        text = text.replace("assets.assets.", "assets.")
    return text


def main():
    for path in (ROOT / "lewis_clark").rglob("*.py"):
        if path.name in ("assets.py", "__init__.py", "config.py"):
            continue
        raw = path.read_text(encoding="utf-8")
        path.write_text(prefix_text(raw), encoding="utf-8")
        print(path.relative_to(ROOT))


if __name__ == "__main__":
    main()
