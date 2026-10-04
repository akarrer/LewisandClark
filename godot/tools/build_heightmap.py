"""Build the Council Bluff heightmap from USGS 1-arc-second elevation tiles.

Reads the two tiles fetched by fetch_assets.py (they meet at 96°W, right at the
bluff), cuts a square around the historical Council Bluff site, resamples it to
the terrain grid, and writes:

  data/terrain/council_bluff.height   float32 LE (N×N): game-space heights in metres, river carved
  data/terrain/council_bluff.river    float32 LE (N×N): RIVER_HALF_WIDTH + signed distance to the waterline
                                      (below RIVER_HALF_WIDTH is water), metres
  data/terrain/council_bluff.flow     float32 LE (N×N): distance to the 1804 centreline; the current runs along it
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
# The landing, kept a beach whatever the bend does there (Region point "start").
LANDING = (530.0, 765.0)
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


def river_frame(gx, gz, poly):
    """For every grid point: distance to the centreline, signed lateral offset
    (positive to the left looking downriver), arc length along it, and the index
    of the nearest centreline segment."""
    best = np.full(gx.shape, np.inf)
    lat = np.zeros(gx.shape)
    along = np.zeros(gx.shape)
    seg = np.zeros(gx.shape, dtype=np.int32)
    run = 0.0
    for i, (a, b) in enumerate(zip(poly[:-1], poly[1:])):
        ab = b - a
        L = max(float(np.hypot(*ab)), 1e-9)
        u = np.clip(((gx - a[0]) * ab[0] + (gz - a[1]) * ab[1]) / (L * L), 0.0, 1.0)
        dx = gx - (a[0] + u * ab[0])
        dz = gz - (a[1] + u * ab[1])
        d = np.hypot(dx, dz)
        closer = d < best
        best = np.where(closer, d, best)
        side = np.sign(ab[0] * dz - ab[1] * dx)
        lat = np.where(closer, d * np.where(side == 0, 1.0, side), lat)
        along = np.where(closer, run + u * L, along)
        seg = np.where(closer, i, seg)
        run += L
    return best, lat, along, seg


def noise1d(s, spacing, rng, octaves=2):
    """Smooth random wiggle along the river, roughly in [-1, 1]."""
    out = np.zeros_like(s)
    amp = 1.0
    total = 0.0
    for _ in range(octaves):
        n = int(s.max() / spacing) + 3
        knots = np.convolve(rng.normal(0.0, 1.0, n), [0.25, 0.5, 0.25], mode="same")
        out += amp * np.interp(s, np.arange(n) * spacing, knots)
        total += amp
        amp *= 0.45
        spacing *= 0.38
    return out / total * 1.6


def signed_shore_distance(water, cell):
    """Distance from every grid point to the waterline, negative in the water.
    Brute force over the cells on the other side of the line: a few seconds on
    a 257 grid, and nothing beyond numpy."""
    edge = np.zeros_like(water)
    for dj, di in ((0, 1), (0, -1), (1, 0), (-1, 0)):
        edge |= water != np.roll(np.roll(water, dj, 0), di, 1)
    out = np.zeros(water.shape)
    for want in (True, False):
        targets = np.argwhere(edge & (water != want)).astype(np.float64)
        pts = np.argwhere(water == want)
        if len(targets) == 0 or len(pts) == 0:
            continue
        best = np.full(len(pts), np.inf)
        for k in range(0, len(targets), 256):
            t = targets[k:k + 256]
            d = np.hypot(pts[:, 0:1] - t[None, :, 0], pts[:, 1:2] - t[None, :, 1]).min(axis=1)
            best = np.minimum(best, d)
        dist = (best - 0.5) * cell   # the line runs between a wet cell and a dry one
        out[pts[:, 0], pts[:, 1]] = -dist if want else dist
    return out


# Mid-channel bars: (arc length m, lateral offset m, half-length, half-width, crest y).
# Laid by eye on the preview, in the wider reaches and clear of the landing.
ISLANDS = [
    (150.0, 8.0, 110.0, 20.0, 0.5),
    (420.0, -12.0, 70.0, 14.0, -0.7),     # under water: a shoal, pale through the silt
    (930.0, 10.0, 120.0, 22.0, 0.45),
    (1150.0, -6.0, 60.0, 12.0, -0.65),
]


def carve_river(land, gx, gz, poly, rng, landing):
    """The 1804 Missouri in the bottomland: a channel that is not one width or
    one shape. On the outside of a bend the current undercuts a steep bank and
    runs deep against it; on the inside it lays down a broad, low point bar; in
    the wider reaches it drops bars in mid-channel, some standing clear of the
    water. The waterline wanders. Returns heights, the distance to the
    centreline (the current follows it) and the arc length along it."""
    dist, lat, s, seg = river_frame(gx, gz, poly)
    # The bottom by the river stands clear of the bars: low spots in it would
    # otherwise read as stray sand out in the grass.
    land = np.where(dist < 200.0, np.maximum(land, FLOODPLAIN_Y - 0.2), land)
    # Curvature of the centreline, smoothed over about a hundred metres.
    d = np.diff(poly, axis=0)
    heading = np.unwrap(np.arctan2(d[:, 1], d[:, 0]))
    seglen = np.hypot(d[:, 0], d[:, 1])
    kappa = np.gradient(heading) / np.maximum(seglen, 1e-6)
    win = max(1, int(100.0 / max(float(seglen.mean()), 1e-6)))
    kappa = np.convolve(kappa, np.ones(win) / win, mode="same")
    # With x east and z south a growing heading turns from +x toward +z: seen on
    # the map (north up) that is a turn to the left. Positive is a left-hand bend.
    k = kappa[seg]
    bend = np.clip(np.abs(k) * 260.0, 0.0, 1.0)
    # The outside of a left-hand bend is the right bank (lat < 0), and vice versa.
    outside = np.where(k > 0, lat < 0, lat > 0)
    width = np.clip(42.0 + 11.0 * noise1d(s, 160.0, rng), 31.0, 60.0)
    rag_l = 4.5 * noise1d(s, 45.0, rng)
    rag_r = 4.5 * noise1d(s, 45.0, rng)
    half = width + np.where(lat > 0, rag_l, rag_r)
    # The inside of a bend is crowded by its bar; the outside is scoured wider --
    # but not into the bluffs, which hold the old line, so a man can still walk
    # the bottom at their foot.
    half = half * np.where(outside, 1.0 + 0.08 * bend, 1.0 - 0.28 * bend)
    half = np.where(land > FLOODPLAIN_Y + 1.5, np.minimum(half, RIVER_HALF_WIDTH - 2.0), half)
    # cut: 1 = undercut bank, 0 = point bar; straight reaches lie in between.
    cut = np.where(outside, 0.5 + 0.5 * bend, 0.5 - 0.5 * bend)
    # The landing is a beach the boats can be run up on, whatever the bend says.
    # Stretched along the bank, on the landing's own side, not a disc.
    li, lj = int(round(landing[1] / (GAME_SIZE / (GRID - 1)))), int(round(landing[0] / (GAME_SIZE / (GRID - 1))))
    s_land, side_land = s[li, lj], np.sign(lat[li, lj])
    beach = 1.0 - np.clip((np.abs(s - s_land) - 55.0 - 20.0 * noise1d(s, 30.0, rng)) / 45.0, 0.0, 1.0)
    beach = beach * (np.sign(lat) == side_land)
    inside_bar = (1.0 - cut) * bend       # how much of a point bar the bend itself builds
    cut = cut * (1.0 - beach)
    cut = cut * cut * (3 - 2 * cut)

    W = -0.35
    DEEP = -3.4
    r = np.clip(np.abs(lat) / half, 0.0, 1.0)            # 0 mid-channel, 1 at the waterline
    # Across the bed: deep right up to a cut bank, shoaling slowly off a bar.
    g_cut = 1.0 - r ** 3
    g_bar = (1.0 - r) ** 1.5
    g = g_bar + (g_cut - g_bar) * cut
    edge_y = W - 0.18 * cut                               # a cut bank's toe stands in water
    bed = edge_y + (DEEP - edge_y) * g
    for s0, u0, length, wide, top in ISLANDS:
        q = np.hypot((s - s0) / length, (lat - u0) / wide)
        q = q + 0.08 * noise1d(s * 3.1 + s0, 20.0, rng)   # ragged
        bed = np.maximum(bed, top - (top - DEEP) * np.clip(q, 0.0, 1.0) ** 2 * 1.4)

    beyond = np.abs(lat) - half                           # metres out from the waterline
    # Point bar: sand rising gently out of the water, a swale and a ridge where
    # each flood left a new edge, then the grassed bottom.
    bar_w = 14.0 + 52.0 * inside_bar + 6.0 * beach   # the camp stood on the grassed bottom, not the sand
    swale = 0.1 * np.sin(beyond / 6.5 + s * 0.01) * np.clip(beyond / 8.0, 0.0, 1.0)
    bar = W + 1.0 * np.clip(beyond / np.maximum(bar_w, 1.0), 0.0, 1.0) + swale
    blend = np.clip((beyond - bar_w) / 16.0, 0.0, 1.0)
    blend = blend * blend * (3 - 2 * blend)
    bar = bar + (land - bar) * blend
    # Cut bank: a steep face straight up out of the water to a natural levee,
    # then the bottom as it was -- or the bluff, which the river is gnawing at.
    top = np.minimum(np.maximum(land, FLOODPLAIN_Y + 0.4 + 1.0 * bend), FLOODPLAIN_Y + 4.5)
    face = np.clip(beyond / 6.0, 0.0, 1.0)
    face = face * face * (3 - 2 * face)
    levee = np.clip((beyond - 6.0) / 30.0, 0.0, 1.0)
    # Then a bench of bottom at the top of the face before any rise behind it.
    top = np.minimum(top, FLOODPLAIN_Y + 0.4 + 1.0 * bend)
    rise = np.clip((beyond - 18.0) / 22.0, 0.0, 1.0)
    rise = rise * rise * (3 - 2 * rise)
    bank_cut = np.where(beyond < 6.0, edge_y + (top - edge_y) * face,
                        np.where(land > top, top + (land - top) * rise,
                                 np.maximum(land, top + (land - top) * levee)))
    banks = bar + (bank_cut - bar) * cut
    # The bluffs themselves are loess the river only works at the foot of: past
    # the face, high ground keeps its own shape.
    banks = np.where((beyond > 40.0) & (land > FLOODPLAIN_Y + 3.0), np.maximum(banks, land), banks)
    game = np.where(beyond < 0.0, bed, banks)
    far = np.clip((beyond - 90.0) / 30.0, 0.0, 1.0)       # far from the river, nothing changes
    game = game + (land - game) * far
    return game.astype(np.float32), dist.astype(np.float32), s


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
    game, flow, along = carve_river(game, gx, gz, catmull_rom(RIVER_1804, 24),
                                    np.random.default_rng(1804 * 2), LANDING)
    water = game < -0.35
    river = (RIVER_HALF_WIDTH + signed_shore_distance(water, GAME_SIZE / (GRID - 1))).astype(np.float32)

    OUT.mkdir(parents=True, exist_ok=True)
    game.astype("<f4").tofile(OUT / "council_bluff.height")
    river.astype("<f4").tofile(OUT / "council_bluff.river")
    flow.astype("<f4").tofile(OUT / "council_bluff.flow")
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
    rgb[water] = [0.25, 0.35, 0.45]
    rgb[(~water) & (game < 0.75) & (river < RIVER_HALF_WIDTH + 120.0)] = [0.80, 0.74, 0.58]  # bars
    print(f"river length {along.max():.0f} m")
    img = Image.fromarray((np.clip(rgb, 0, 1) * 255).astype(np.uint8)).resize((1024, 1024), Image.BILINEAR)
    img.save(OUT / "council_bluff_preview.png")
    print(f"game heights {game.min():.1f}..{game.max():.1f} m; wrote {OUT}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
