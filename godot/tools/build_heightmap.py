"""Build the Council Bluff heightmap from USGS 1-arc-second elevation tiles.

Reads the two tiles fetched by fetch_assets.py (they meet at 96°W, right at the
bluff), cuts a square around the historical Council Bluff site, resamples it to
the terrain grid, and writes:

  data/terrain/council_bluff.height   float32 LE (N×N): game-space heights in metres, river carved
  data/terrain/council_bluff.river    float32 LE (N×N): distance to the 1804 river centreline, metres
  data/terrain/council_bluff.json     provenance, scale, and the river course
  data/terrain/council_bluff_preview.png   shaded relief with the river, for planning by eye

The real 7 km square is compressed to a 1 km game map (1 px of the preview = 1 m);
heights keep half their real relief. The modern floodplain is smoothed and the
Missouri is laid on a hand-drawn 1804 course that runs right under Council Bluff,
where Lewis and Clark camped; today the river is several kilometres east.

Run:  python godot/tools/build_heightmap.py
Data: USGS 3D Elevation Program, public domain.
"""

from __future__ import annotations

import json
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
TILES = ROOT / "assets" / "third_party" / "elevation"
OUT = ROOT / "data" / "terrain"

# Historical Council Bluff (Fort Atkinson State Historical Park), Washington County, Nebraska.
CENTER_LAT, CENTER_LON = 41.455, -96.005
HALF_KM = 3.5
GRID = 257  # vertices per side; matches Terrain.RES + 1
GAME_SIZE = 1024.0  # metres on a side in game
VERTICAL_SCALE = 0.5
FLOODPLAIN_Y = 1.2  # game height of the bottomland above the water
RIVER_HALF_WIDTH = 40.0
# The 1804 Missouri, in game metres (x east, z south; north is -z). Hand-placed.
RIVER_1804 = [(600, -40), (560, 110), (480, 250), (478, 390), (500, 520), (540, 640),
              (600, 760), (690, 860), (820, 915), (960, 915), (1080, 900)]

Image.MAX_IMAGE_PIXELS = None


def read_tile(name: str):
    im = Image.open(TILES / name)
    west, north = im.tag_v2[33922][3], im.tag_v2[33922][4]
    dx, dy = im.tag_v2[33550][0], im.tag_v2[33550][1]
    return im, west, north, dx, dy


def sample_region(lat0, lat1, lon0, lon1, n):
    """Bilinear-sample elevations on an n×n lat/lon grid (row 0 = north)."""
    tiles = [read_tile("USGS_1_n42w097_20220218.tif"), read_tile("USGS_1_n42w096_20221218.tif")]
    lats = np.linspace(lat1, lat0, n)
    lons = np.linspace(lon0, lon1, n)
    out = np.zeros((n, n), dtype=np.float64)
    for im, west, north, dx, dy in tiles:
        w, h = im.size
        cols = (lons - west) / dx
        rows = (north - lats) / dy
        inside_c = (cols >= 0) & (cols < w - 1)
        inside_r = (rows >= 0) & (rows < h - 1)
        if not inside_c.any() or not inside_r.any():
            continue
        c0, c1 = int(math.floor(cols[inside_c].min())), int(math.ceil(cols[inside_c].max())) + 1
        r0, r1 = int(math.floor(rows[inside_r].min())), int(math.ceil(rows[inside_r].max())) + 1
        block = np.array(im.crop((c0, r0, c1, r1)), dtype=np.float64)
        for j in np.nonzero(inside_r)[0]:
            fy = rows[j] - r0
            y0 = int(fy); ty = fy - y0
            for i in np.nonzero(inside_c)[0]:
                fx = cols[i] - c0
                x0 = int(fx); tx = fx - x0
                v = (block[y0, x0] * (1 - tx) * (1 - ty) + block[y0, x0 + 1] * tx * (1 - ty)
                     + block[y0 + 1, x0] * (1 - tx) * ty + block[y0 + 1, x0 + 1] * tx * ty)
                out[j, i] = v
    return out


def catmull_rom(points, steps):
    pts = [points[0]] + list(points) + [points[-1]]
    out = []
    for i in range(1, len(pts) - 2):
        p0, p1, p2, p3 = (np.array(pts[j], dtype=np.float64) for j in (i - 1, i, i + 1, i + 2))
        for s in range(steps):
            u = s / steps
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * u + (2 * p0 - 5 * p1 + 4 * p2 - p3) * u * u
                              + (-p0 + 3 * p1 - 3 * p2 + p3) * u ** 3))
    out.append(np.array(points[-1], dtype=np.float64))
    return np.array(out)


def river_distance(gx, gz, poly):
    """Distance from every grid point to the river polyline."""
    best = np.full(gx.shape, np.inf)
    for a, b in zip(poly[:-1], poly[1:]):
        ab = b - a
        L2 = max(float(ab @ ab), 1e-9)
        u = np.clip(((gx - a[0]) * ab[0] + (gz - a[1]) * ab[1]) / L2, 0.0, 1.0)
        dx = gx - (a[0] + u * ab[0])
        dz = gz - (a[1] + u * ab[1])
        best = np.minimum(best, np.hypot(dx, dz))
    return best


def hillshade(z, cell):
    gy, gx = np.gradient(z, cell)
    slope = np.pi / 2 - np.arctan(np.hypot(gx, gy))
    aspect = np.arctan2(-gx, gy)
    az, alt = np.radians(315), np.radians(45)
    shade = np.sin(alt) * np.sin(slope) + np.cos(alt) * np.cos(slope) * np.cos(az - aspect)
    return np.clip(shade, 0, 1)


def main() -> int:
    dlat = HALF_KM / 111.0
    dlon = HALF_KM / (111.32 * math.cos(math.radians(CENTER_LAT)))
    lat0, lat1 = CENTER_LAT - dlat, CENTER_LAT + dlat
    lon0, lon1 = CENTER_LON - dlon, CENTER_LON + dlon
    z = sample_region(lat0, lat1, lon0, lon1, GRID)
    raw_min = float(z.min())
    if (z <= -1000).any() or (z == 0).any():
        print("warning: gaps in elevation data", file=sys.stderr)
    base = float(z.min())
    rel = z - base

    # Smooth away the modern floodplain (gravel-pit lake, road and levee embankments):
    # everything near floodplain level blends toward a gently rolling bottomland,
    # fading back to the real surface a few metres up so the bluff foot has no step.
    east = rel[:, int(GRID * 0.7):]
    flood = float(np.median(east))
    rng = np.random.default_rng(1804)
    roll = rng.normal(0.0, 1.0, (GRID // 16 + 2, GRID // 16 + 2))
    roll = np.array(Image.fromarray(roll.astype(np.float32)).resize((GRID, GRID), Image.BICUBIC)) * 0.6
    w = np.clip((rel - (flood + 3.0)) / 9.0, 0.0, 1.0)
    w = w * w * (3 - 2 * w)
    rel = (flood + roll) * (1 - w) + rel * w

    # Hand-touched: modern embankments standing on the floodplain east of the bluff.
    yy, xx = np.mgrid[0:GRID, 0:GRID] / (GRID - 1)
    for cx, cy, rx, ry in [(0.49, 0.36, 0.085, 0.11), (0.49, 0.255, 0.03, 0.03)]:
        d = np.sqrt(((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2)
        k = np.clip(1.4 - d, 0.0, 1.0)
        k = k * k * (3 - 2 * k)
        rel = rel * (1 - k) + (flood + roll) * k
    rel = rel.astype(np.float32)

    # Game space: floodplain just above the water, half the real relief.
    game = (rel - flood) * VERTICAL_SCALE + FLOODPLAIN_Y
    gz, gx = np.mgrid[0:GRID, 0:GRID] * (GAME_SIZE / (GRID - 1))
    dist = river_distance(gx, gz, catmull_rom(RIVER_1804, 24))
    k = np.clip(dist / RIVER_HALF_WIDTH, 0.0, 1.0)
    channel = -3.2 + (0.4 + 3.2) * k * k
    bank = np.clip((dist - RIVER_HALF_WIDTH) / 30.0, 0.0, 1.0)
    bank = bank * bank * (3 - 2 * bank)
    game = np.where(dist < RIVER_HALF_WIDTH, channel, 0.5 * (1 - bank) + game * bank).astype(np.float32)

    OUT.mkdir(parents=True, exist_ok=True)
    game.astype("<f4").tofile(OUT / "council_bluff.height")
    dist.astype("<f4").tofile(OUT / "council_bluff.river")
    meta = {
        "source": "USGS 3DEP 1 arc-second: USGS_1_n42w097_20220218, USGS_1_n42w096_20221218 (public domain)",
        "bbox": {"south": lat0, "north": lat1, "west": lon0, "east": lon1},
        "real_size_m": HALF_KM * 2000.0,
        "grid": GRID,
        "row0": "north",
        "base_elevation_m": base,
        "floodplain_m": flood,
        "game_size_m": GAME_SIZE,
        "vertical_scale": VERTICAL_SCALE,
        "floodplain_y": FLOODPLAIN_Y,
        "river_half_width_m": RIVER_HALF_WIDTH,
        "river_1804": RIVER_1804,
        "relief_m": float(rel.max()),
        "historical_council_bluff": {"lat": 41.4556, "lon": -96.0161},
    }
    (OUT / "council_bluff.json").write_text(json.dumps(meta, indent=1), encoding="utf-8")

    cell = HALF_KM * 2000.0 / (GRID - 1)
    shade = hillshade(game.astype(np.float64) / VERTICAL_SCALE, cell)
    tint = (game - game.min()) / max(1e-6, game.max() - game.min())
    rgb = np.stack([0.35 + 0.55 * tint, 0.45 + 0.35 * tint, 0.30 + 0.2 * tint], -1) * (0.35 + 0.65 * shade[..., None])
    water = dist < RIVER_HALF_WIDTH
    rgb[water] = [0.25, 0.35, 0.45]
    img = Image.fromarray((np.clip(rgb, 0, 1) * 255).astype(np.uint8)).resize((1024, 1024), Image.BILINEAR)
    img.save(OUT / "council_bluff_preview.png")
    print(f"game heights {game.min():.1f}..{game.max():.1f} m; wrote {OUT}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
