"""Region worlds: the walkable ground generated for one Region of the route.

A Region is laid out as a stretch of river running "upstream" from the bottom
of the world (``y`` = length) to the top (``y`` = 0). The Corps arrives at the
downstream end, the Region's Landmarks sit along the east bank in route order,
and the landing at the upstream end is where a Leg to the next Region begins.

Generation is seeded by the Region id, so a Region looks the same every time.
Everything here is plain data (no pygame) so it can be tested headless.
"""

from __future__ import annotations

import random
import zlib
from collections import deque
from dataclasses import dataclass, field

from lewis_clark import assets

# Tile ids
GRASS, DIRT, WATER, SAND, ROCK = range(5)
WALKABLE = frozenset({GRASS, DIRT, SAND})

WIDTH = 36  # tiles across the river valley

# Per-biome ground colour, scatter densities (per tile), and wildlife.
BIOMES = {
    "woodland": {"grass": (74, 108, 52), "trees": 0.07, "rocks": 0.012, "species": ("elk",)},
    "prairie": {"grass": (132, 134, 72), "trees": 0.008, "rocks": 0.01, "species": ("buffalo", "buffalo", "elk")},
    "mountain": {"grass": (88, 102, 72), "trees": 0.045, "rocks": 0.05, "species": ("elk",)},
    "coast": {"grass": (58, 96, 62), "trees": 0.09, "rocks": 0.02, "species": ("elk",)},
}


@dataclass
class RegionWorld:
    region_id: str
    name: str
    biome: str
    width: int
    height: int
    tiles: list[list[int]]
    props: list[tuple[float, float, str]]
    spawn: tuple[float, float]
    landmarks: list[dict]  # {id, name, desc, waypoint?, wx, wy}
    landing: tuple[float, float]
    wildlife_spawns: list[tuple[float, float, str]] = field(default_factory=list)

    def walkable(self, wx: float, wy: float) -> bool:
        if wx < 0 or wy < 0:
            return False
        tx, ty = int(wx), int(wy)
        if not (0 <= tx < self.width and 0 <= ty < self.height):
            return False
        return self.tiles[ty][tx] in WALKABLE

    def reachable(self, a: tuple[float, float], b: tuple[float, float]) -> bool:
        """Is there a walkable 4-connected tile path from ``a`` to ``b``?"""
        start, goal = (int(a[0]), int(a[1])), (int(b[0]), int(b[1]))
        if not (self.walkable(*a) and self.walkable(*b)):
            return False
        seen = {start}
        queue = deque([start])
        while queue:
            x, y = queue.popleft()
            if (x, y) == goal:
                return True
            for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if (nx, ny) not in seen and self.walkable(nx + 0.5, ny + 0.5):
                    seen.add((nx, ny))
                    queue.append((nx, ny))
        return False


def region(region_id: str) -> dict:
    return assets.REGIONS[region_id]


def build_world(region_id: str) -> RegionWorld:
    data = region(region_id)
    biome = BIOMES.get(data.get("biome", "woodland"), BIOMES["woodland"])
    rng = random.Random(zlib.crc32(region_id.encode()))
    w, h = WIDTH, int(data.get("length", 72))

    tiles = [[GRASS] * w for _ in range(h)]
    river = []  # river centre x for each row
    rx = w // 3
    for y in range(h):
        rx = max(3, min(w // 2, rx + rng.choice((-1, 0, 0, 1))))
        river.append(rx)
        for dx in (-1, 0, 1):
            tiles[y][rx + dx] = WATER
        for dx in (-2, 2):
            tiles[y][rx + dx] = SAND

    for y in range(h):
        for x in range(w):
            if tiles[y][x] == GRASS and rng.random() < biome["rocks"]:
                tiles[y][x] = ROCK
            elif tiles[y][x] == GRASS and rng.random() < 0.02:
                tiles[y][x] = DIRT

    def bank_spot(y: int, near: int = 3, far: int = 6) -> tuple[int, int]:
        """A tile on the east bank of row ``y``, cleared so it is walkable."""
        x = min(w - 2, river[y] + rng.randint(near, far))
        tiles[y][x] = DIRT
        return x, y

    sx, sy = bank_spot(h - 3, 3, 4)
    spawn = (sx + 0.5, sy + 0.5)

    marks = data["landmarks"]
    top, bottom = 10, h - 10
    landmarks = []
    for i, lm in enumerate(marks):
        t = i / max(1, len(marks) - 1) if len(marks) > 1 else 0.5
        y = int(round(bottom - t * (bottom - top)))
        x, y = bank_spot(y)
        landmarks.append({**lm, "wx": x + 0.5, "wy": y + 0.5})

    lx, ly = bank_spot(2, 3, 3)
    landing = (lx + 0.5, ly + 0.5)

    # Keep clearings around points of interest free of rocks.
    for px, py in [spawn, landing] + [(m["wx"], m["wy"]) for m in landmarks]:
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                x, y = int(px) + dx, int(py) + dy
                if 0 <= x < w and 0 <= y < h and tiles[y][x] == ROCK:
                    tiles[y][x] = GRASS

    occupied = {(int(px), int(py)) for px, py in [spawn, landing]}
    occupied |= {(int(m["wx"]), int(m["wy"])) for m in landmarks}
    props = []
    for y in range(h):
        for x in range(w):
            if tiles[y][x] == GRASS and (x, y) not in occupied and rng.random() < biome["trees"]:
                props.append((x + 0.5, y + 0.5, "tree"))

    wildlife = []
    for _ in range(max(3, h // 14)):
        for _attempt in range(50):
            x, y = rng.randrange(w), rng.randrange(h)
            if tiles[y][x] == GRASS:
                wildlife.append((x + 0.5, y + 0.5, rng.choice(biome["species"])))
                break

    return RegionWorld(
        region_id=region_id,
        name=data["name"],
        biome=data.get("biome", "woodland"),
        width=w,
        height=h,
        tiles=tiles,
        props=props,
        spawn=spawn,
        landmarks=landmarks,
        landing=landing,
        wildlife_spawns=wildlife,
    )
