#!/usr/bin/env python3
"""Build lewis_1804_crop_control_points.json by snapping graticule guesses to ink on the scan.

The 1804 plate is not Web Mercator; Mercator+homography was misleading. We place many
(lon,lat) knots on a 5° grid, seed positions with a rough plate linearization, then
move each to the centroid of darkest pixels in a small window (the engraved grid).
"""

from __future__ import annotations

import json
import math
import os
import sys
from pathlib import Path

os.environ.setdefault("SDL_VIDEODRIVER", "dummy")

import numpy as np
import pygame  # noqa: E402

pygame.init()
pygame.display.set_mode((1, 1))

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

FULL_W, FULL_H = 2460, 3081
LON_SHEET_W, LON_SHEET_E = 145.0, 70.0
LAT_SHEET_N, LAT_SHEET_S = 65.0, 25.0
_PHI = math.radians(42.0)
LON_E_POS = 90.1 - 100.0 / (69.0 * math.cos(_PHI))  # ~88.15 °W magnitude (bitmap math)
LON_SLICE_W = 145.0
LAT_NORTH = 50.0
CAMP_DUBOIS_LAT = 38.87
LAT_SOUTH = CAMP_DUBOIS_LAT - 100.0 / 69.0

# Signed geographic bounds of the crop (west negative)
LON_W = -145.0
LON_E = -LON_E_POS
OUT_JSON = ROOT / "assets" / "map_georef" / "lewis_1804_crop_control_points.json"


def _load_gray_crop() -> np.ndarray:
    p = ROOT / "assets" / "images" / ".source_louisiana1804a.jpg"
    if not p.exists():
        p = Path("/tmp/louisiana1804.jpg")
    surf = pygame.image.load(str(p))
    arr = pygame.surfarray.array3d(surf)
    r = arr[:, :, 0].astype(np.float64)
    gch = arr[:, :, 1].astype(np.float64)
    b = arr[:, :, 2].astype(np.float64)
    return 0.299 * r + 0.587 * gch + 0.114 * b


def _crop_array(g: np.ndarray) -> np.ndarray:
    w, h = g.shape
    span = LON_SHEET_W - LON_SHEET_E
    x_left = int(round(w * (LON_SHEET_W - LON_SLICE_W) / span))
    x_right = int(round(w * (LON_SHEET_W - LON_E_POS) / span))
    cw = max(1, x_right - x_left)
    y0 = int(round((LAT_SHEET_N - LAT_NORTH) * h / (LAT_SHEET_N - LAT_SHEET_S)))
    y1 = int(round((LAT_SHEET_N - LAT_SOUTH) * h / (LAT_SHEET_N - LAT_SHEET_S)))
    ch = y1 - y0
    return np.ascontiguousarray(g[x_left : x_left + cw, y0 : y0 + ch])


def _linear_seed(lon: float, lat: float, w: int, h: int) -> tuple[float, float]:
    """Rough equirectangular seed in crop pixels (same as early linear overlay)."""
    x = (lon - LON_W) / (LON_E - LON_W) * (w - 1)
    y = (LAT_NORTH - lat) / (LAT_NORTH - LAT_SOUTH) * (h - 1)
    return x, y


def _snap(gc: np.ndarray, x0: float, y0: float, win: int, thresh: float, max_shift: float) -> tuple[float, float] | None:
    """Return centroid of dark ink near (x0,y0), or None."""
    gw, gh = gc.shape[0], gc.shape[1]
    xi = int(round(x0))
    yi = int(round(y0))
    x1 = max(0, xi - win)
    x2 = min(gw, xi + win + 1)
    y1 = max(0, yi - win)
    y2 = min(gh, yi + win + 1)
    patch = gc[x1:x2, y1:y2]
    if patch.size == 0:
        return None
    mask = patch < thresh
    if mask.sum() < 10:
        mask = patch < thresh + 12
    if mask.sum() < 6:
        return None
    ys, xs = np.where(mask)
    cx = x1 + float(xs.mean())
    cy = y1 + float(ys.mean())
    if math.hypot(cx - x0, cy - y0) > max_shift:
        return None
    return cx, cy


def main() -> None:
    g = _load_gray_crop()
    gc = _crop_array(g)
    gw, gh = gc.shape[0], gc.shape[1]
    print("gray crop", gw, gh, "range", float(gc.min()), float(gc.max()))

    lons = [float(x) for x in range(-145, -85, 5)]
    lats = [float(x) for x in range(37, 51)]

    pts: list[dict[str, float]] = []
    for lat in lats:
        for lon in lons:
            if lon < LON_W or lon > LON_E or lat < LAT_SOUTH or lat > LAT_NORTH:
                continue
            x0, y0 = _linear_seed(lon, lat, gw, gh)
            if not (0 <= x0 < gw and 0 <= y0 < gh):
                continue
            snapped = _snap(gc, x0, y0, win=48, thresh=88.0, max_shift=28.0)
            if snapped is None:
                continue
            sx, sy = snapped
            pts.append({"lon": lon, "lat": lat, "x": round(sx, 2), "y": round(sy, 2)})

    pts.sort(key=lambda r: (r["lat"], r["lon"]))
    print("snapped control points:", len(pts))
    if len(pts) < 10:
        print("Too few points; adjust thresh/win or check source image path.")
        sys.exit(1)

    payload = {
        "comment": "Auto-snapped graticule knots on the LOC scan; quadratic fit in map_georef_1804.py",
        "control_points": pts,
    }
    OUT_JSON.parent.mkdir(parents=True, exist_ok=True)
    OUT_JSON.write_text(json.dumps(payload, indent=2), encoding="utf-8")
    print("Wrote", OUT_JSON)


if __name__ == "__main__":
    main()
