#!/usr/bin/env python3
"""Crop the 1804 Louisiana sheet and mark expedition points on map_west_of_camp_dubois_1804.jpg."""

from __future__ import annotations

import math
import os
import urllib.request
from pathlib import Path

os.environ.setdefault("SDL_VIDEODRIVER", "dummy")

import pygame  # noqa: E402

pygame.init()
pygame.display.set_mode((1, 1))

ROOT = Path(__file__).resolve().parents[1]
MAP_PATH = ROOT / "assets" / "images" / "map_west_of_camp_dubois_1804.jpg"
FONT_PATH = ROOT / "assets" / "fonts" / "EBGaramond.ttf"

# Allow `python3 scripts/foo.py` without installing the package
import sys

if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from lewis_clark.map_georef_1804 import MapGeoRef1804  # noqa: E402

FULL_W, FULL_H = 2460, 3081
FULL_MAP_URL = "https://upload.wikimedia.org/wikipedia/commons/b/b1/Louisiana1804a.jpg"
# Full sheet graticule (per scan)
LON_SHEET_W, LON_SHEET_E = 145.0, 70.0
LAT_SHEET_N, LAT_SHEET_S = 65.0, 25.0

# Cropped slice: eastern edge ~100 mi east of Camp Dubois; northern edge 50°N;
# western edge: full sheet at 145°W so the engraved Pacific Ocean is visible (a tight ~126°W crop
#   put the Columbia marker on the frame edge with no visible water — the 1804 art is west of the mouth).
# southern edge: 100 statute miles south of Camp Dubois (~69 mi/° latitude).
_PHI = math.radians(42.0)
LON_E = 90.1 - 100.0 / (69.0 * math.cos(_PHI))  # ~88.15°W
LAT_NORTH = 50.0
CAMP_DUBOIS_LAT = 38.87
LAT_SOUTH = CAMP_DUBOIS_LAT - 100.0 / 69.0

# Where the Columbia River meets the Pacific (Columbia Bar); marker only — crop uses LON_SLICE_W below.
COLUMBIA_MEETS_PACIFIC_LAT = 46.252
COLUMBIA_MEETS_PACIFIC_LON = -124.058  # WGS84: west longitude negative

LON_SLICE_W = 145.0  # match full scan west edge (positive °W label on plate, for bitmap crop only)

# Main stem of the Columbia (lat, lon°), north → south — WGS84; west longitude negative.
COLUMBIA_RIVER_WAYPOINTS: tuple[tuple[float, float], ...] = (
    (50.02, -116.18),
    (49.88, -116.95),
    (49.55, -117.75),
    (49.15, -118.35),
    (48.75, -118.85),
    (48.40, -119.25),
    (48.05, -119.55),
    (47.75, -119.90),
    (47.45, -120.25),
    (47.20, -120.65),
    (47.00, -121.10),
    (46.85, -121.65),
    (46.70, -122.25),
    (46.55, -122.90),
    (46.42, -123.45),
    (46.33, -123.95),
    (COLUMBIA_MEETS_PACIFIC_LAT, COLUMBIA_MEETS_PACIFIC_LON),
)

MARKERS: tuple[tuple[str, float, float], ...] = (
    ("Camp Dubois", CAMP_DUBOIS_LAT, -90.10),  # Wood River / Mississippi–Missouri
    ("Columbia River & Pacific", COLUMBIA_MEETS_PACIFIC_LAT, COLUMBIA_MEETS_PACIFIC_LON),
    ("Fort Clatsop", 46.131, -123.883),  # Columbia estuary, Oregon (NPS site)
)


def _ensure_full_map_surface() -> pygame.Surface:
    cache = ROOT / "assets" / "images" / ".source_louisiana1804a.jpg"
    tmp = Path("/tmp/louisiana1804.jpg")
    if cache.exists():
        return pygame.image.load(str(cache))
    if tmp.exists():
        return pygame.image.load(str(tmp))
    cache.parent.mkdir(parents=True, exist_ok=True)
    req = urllib.request.Request(
        FULL_MAP_URL,
        headers={"User-Agent": "LewisandClarkAssetBake/1.0 (educational game; +https://github.com/)"},
    )
    with urllib.request.urlopen(req, timeout=120) as resp:
        cache.write_bytes(resp.read())
    return pygame.image.load(str(cache))


def _crop_full_to_slice(src: pygame.Surface) -> pygame.Surface:
    w, h = FULL_W, FULL_H
    span = LON_SHEET_W - LON_SHEET_E
    x_left = int(round(w * (LON_SHEET_W - LON_SLICE_W) / span))
    x_right = int(round(w * (LON_SHEET_W - LON_E) / span))
    cw = max(1, x_right - x_left)
    y0 = int(round((LAT_SHEET_N - LAT_NORTH) * h / (LAT_SHEET_N - LAT_SHEET_S)))
    y1 = int(round((LAT_SHEET_N - LAT_SOUTH) * h / (LAT_SHEET_N - LAT_SHEET_S)))
    ch = y1 - y0
    out = pygame.Surface((cw, ch))
    out.blit(src, (0, 0), (x_left, y0, cw, ch))
    return out


def _draw_columbia_river_highlight(surf: pygame.Surface, geo: MapGeoRef1804, w: int, h: int) -> None:
    pts: list[tuple[int, int]] = []
    for lat, lon in COLUMBIA_RIVER_WAYPOINTS:
        x, y = geo.lonlat_to_px(lon, lat)
        pts.append((max(0, min(w - 1, x)), max(0, min(h - 1, y))))
    if len(pts) < 2:
        return
    lw = max(3, min(10, w // 160))
    glow = max(5, lw + 3)
    # Dark under-stroke then bright line so it reads on sepia / terrain
    pygame.draw.lines(surf, (45, 28, 14), False, pts, glow)
    pygame.draw.lines(surf, (240, 200, 90), False, pts, lw)
    pygame.draw.lines(surf, (255, 230, 150), False, pts, max(1, lw - 2))


def _draw_marker(
    surf: pygame.Surface,
    cx: int,
    cy: int,
    w: int,
    *,
    sepia: tuple[int, int, int],
    cream: tuple[int, int, int],
    gold: tuple[int, int, int],
) -> int:
    r_outer = max(6, min(14, w // 140))
    pygame.draw.circle(surf, gold, (cx, cy), r_outer + 2, 2)
    pygame.draw.circle(surf, sepia, (cx, cy), r_outer, 2)
    pygame.draw.circle(surf, cream, (cx, cy), max(2, r_outer // 3))
    tick = r_outer + 6
    pygame.draw.line(surf, sepia, (cx - tick, cy), (cx + tick, cy), 2)
    pygame.draw.line(surf, sepia, (cx, cy - tick), (cx, cy + tick), 2)
    return r_outer


def main() -> None:
    full = _ensure_full_map_surface()
    img = _crop_full_to_slice(full)
    w, h = img.get_size()
    surf = img.convert()

    # Signed WGS84: west negative. Plate crop uses positive °W magnitudes LON_SLICE_W / LON_E above.
    geo = MapGeoRef1804(-LON_SLICE_W, -LON_E, LAT_NORTH, LAT_SOUTH, w, h)

    _draw_columbia_river_highlight(surf, geo, w, h)

    sepia = (92, 48, 28)
    cream = (252, 245, 230)
    gold = (184, 134, 48)

    font_size = max(14, min(28, w // 70))
    try:
        font = pygame.font.Font(str(FONT_PATH), font_size)
    except OSError:
        font = pygame.font.Font(None, font_size)

    for label, lat, lon in MARKERS:
        cx, cy = geo.lonlat_to_px(lon, lat)
        cx, cy = int(round(cx)), int(round(cy))
        r_outer = _draw_marker(surf, cx, cy, w, sepia=sepia, cream=cream, gold=gold)
        shadow = font.render(label, True, (20, 12, 8))
        text = font.render(label, True, (60, 38, 22))
        tw, th = text.get_size()
        lx = max(4, min(cx - tw // 2, w - tw - 4))
        ly = min(cy + r_outer + 10, h - th - 4)
        surf.blit(shadow, (lx + 1, ly + 1))
        surf.blit(text, (lx, ly))
        print(f"Marked {label!r} at ({cx}, {cy})")

    pygame.image.save(surf, str(MAP_PATH))
    print(f"Wrote {w}×{h} → {MAP_PATH}")


if __name__ == "__main__":
    main()
