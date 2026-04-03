"""Load (and optionally generate) PNG game art under assets/images/."""

from __future__ import annotations

import math
import random
from pathlib import Path

import pygame

from lewis_clark import assets
from lewis_clark.textures import gen_parchment_tile

_REPO = Path(__file__).resolve().parent.parent
IMG_DIR = _REPO / "assets" / "images"

_FILENAMES = {
    "title": "title_bg.png",
    "parchment": "parchment_tile.png",
    "terrains": {
        "plains": "terrain_plains.png",
        "river": "terrain_river.png",
        "mountain": "terrain_mountain.png",
        "forest": "terrain_forest.png",
        "coast": "terrain_coast.png",
    },
    "portraits": {
        "york": "portrait_york.png",
        "drouillard": "portrait_drouillard.png",
        "sacagawea": "portrait_sacagawea.png",
        "inactive": "portrait_inactive.png",
    },
}


def _hex_polygon(cx: float, cy: float, r: float) -> list[tuple[int, int]]:
    pts = []
    for i in range(6):
        a = math.radians(60 * i - 30)
        pts.append((int(cx + r * math.cos(a)), int(cy + r * math.sin(a))))
    return pts


def _build_title_bg(w: int, h: int) -> pygame.Surface:
    surf = pygame.Surface((w, h))
    for y in range(h):
        t = y / max(h - 1, 1)
        r = int(8 + t * 35)
        g = int(6 + t * 40)
        b = int(18 + t * 55)
        pygame.draw.line(surf, (r, g, b), (0, y), (w, y))
    # Hills
    hill_pts = [(0, h), (0, int(h * 0.55)), (int(w * 0.2), int(h * 0.48)),
                (int(w * 0.45), int(h * 0.52)), (int(w * 0.72), int(h * 0.44)),
                (w, int(h * 0.5)), (w, h)]
    pygame.draw.polygon(surf, (4, 18, 12), hill_pts)
    pygame.draw.polygon(surf, (20, 35, 28), hill_pts, 2)
    # River sheen
    for i in range(40):
        rx = int(w * (0.25 + i * 0.012))
        ry = int(h * 0.62 + math.sin(i * 0.35) * 8)
        pygame.draw.circle(surf, (30, 55, 70), (rx, ry), 2)
    # Moon
    pygame.draw.circle(surf, (240, 245, 230), (w - 110, 95), 28)
    pygame.draw.circle(surf, (210, 215, 200), (w - 102, 92), 26)
    return surf


def _build_terrain_tile(terr: str, tw: int, th: int) -> pygame.Surface:
    surf = pygame.Surface((tw, th), pygame.SRCALPHA)
    cx_f, cy_f = tw / 2, th / 2
    cx, cy = tw // 2, th // 2
    r = min(tw, th) * 0.42
    pts = _hex_polygon(cx_f, cy_f, r)
    seed = {"plains": 11, "river": 22, "mountain": 33, "forest": 44, "coast": 55}[terr]
    rng = random.Random(seed)

    base = {
        "plains": ((215, 200, 130), (175, 155, 85)),
        "river": ((140, 175, 210), (90, 130, 175)),
        "mountain": ((160, 140, 100), (110, 90, 65)),
        "forest": ((120, 155, 95), (70, 100, 60)),
        "coast": ((140, 195, 205), (95, 160, 175)),
    }[terr]
    hi, lo = base
    mid = tuple((hi[i] + lo[i]) // 2 for i in range(3))
    pygame.draw.polygon(surf, (*mid, 255), pts)

    gloss = pygame.Surface((tw, th), pygame.SRCALPHA)
    pygame.draw.polygon(
        gloss,
        (
            min(255, mid[0] + 35),
            min(255, mid[1] + 28),
            min(255, mid[2] + 18),
            90,
        ),
        _hex_polygon(cx_f, cy_f - r * 0.08, r * 0.55),
    )
    surf.blit(gloss, (0, 0))

    shade = pygame.Surface((tw, th), pygame.SRCALPHA)
    pygame.draw.polygon(
        shade,
        (0, 0, 0, 55),
        _hex_polygon(cx_f + r * 0.12, cy_f + r * 0.15, r * 0.5),
    )
    surf.blit(shade, (0, 0))

    pygame.draw.polygon(surf, (*lo, 220), pts, 2)

    if terr == "plains":
        for _ in range(28):
            gx = int(cx + rng.uniform(-r * 0.75, r * 0.75))
            gy = int(cy + rng.uniform(-r * 0.75, r * 0.75))
            c = tuple(max(0, v - rng.randint(14, 40)) for v in mid)
            pygame.draw.circle(surf, (*c, 200), (gx, gy), 1)
    elif terr == "river":
        for ly in range(-int(r), int(r), 7):
            wy = cy + ly + int(math.sin(ly * 0.09) * 3)
            pygame.draw.line(
                surf,
                (170, 205, 235, 130),
                (int(cx - r * 0.72), wy),
                (int(cx + r * 0.72), wy),
                1,
            )
    elif terr == "mountain":
        for px, py in [(-20, 2), (2, -14), (24, 6)]:
            pygame.draw.polygon(
                surf,
                (120, 100, 72, 235),
                [
                    (cx + px, cy + py + 20),
                    (cx + px - 2, cy + py - 18),
                    (cx + px + 22, cy + py + 10),
                ],
            )
    elif terr == "forest":
        for _ in range(9):
            tx = int(cx + rng.uniform(-r * 0.7, r * 0.7))
            ty = int(cy + rng.uniform(-r * 0.7, r * 0.7))
            pygame.draw.circle(surf, (55, 95, 50, 245), (tx, ty), rng.randint(5, 11))
    else:
        for _ in range(14):
            fx = int(cx + rng.uniform(-r * 0.82, r * 0.82))
            fy = int(cy + rng.uniform(-r * 0.82, r * 0.82))
            pygame.draw.circle(surf, (190, 220, 230, 140), (fx, fy), 1)

    return surf


def _build_portrait(key: str, pw: int, ph: int) -> pygame.Surface:
    surf = pygame.Surface((pw, ph), pygame.SRCALPHA)
    if key == "inactive":
        surf.fill((35, 35, 40, 230))
        pygame.draw.rect(surf, (60, 60, 65), (0, 0, pw, ph), 2)
        cx, cy = pw // 2, ph // 2 - 4
        pygame.draw.circle(surf, (80, 80, 85), (cx, cy - 4), 14)
        pygame.draw.rect(surf, (80, 80, 85), (cx - 16, cy + 6, 32, 28))
        pygame.draw.line(surf, (110, 110, 115), (cx - 8, cy - 8), (cx + 8, cy + 8), 2)
        return surf

    skin = {
        "york": ((92, 64, 48), (120, 85, 52)),
        "drouillard": ((110, 80, 58), (95, 70, 50)),
        "sacagawea": ((140, 105, 78), (120, 90, 70)),
    }[key]
    dark, light = skin
    pygame.draw.rect(surf, (40, 32, 26, 255), (4, 4, pw - 8, ph - 8), border_radius=4)
    cx = pw // 2
    pygame.draw.ellipse(surf, light, (cx - 18, 10, 36, 40))
    pygame.draw.ellipse(surf, dark, (cx - 18, 10, 36, 40), 1)
    pygame.draw.rect(surf, dark, (cx - 20, 38, 40, 34))
    if key == "york":
        pygame.draw.rect(surf, (55, 45, 35), (cx - 22, 6, 44, 10), border_radius=2)
    elif key == "drouillard":
        pygame.draw.polygon(surf, (70, 55, 40), [(cx - 16, 14), (cx, 2), (cx + 16, 14)])
    else:
        for ox in (-14, 14):
            pygame.draw.circle(surf, dark, (cx + ox, 28), 4)

    pygame.draw.rect(surf, (30, 24, 20, 255), (0, 0, pw, ph), 2, border_radius=4)
    return surf


def ensure_png_assets(sw: int, sh: int) -> None:
    """Create assets/images PNGs if missing (idempotent)."""
    IMG_DIR.mkdir(parents=True, exist_ok=True)
    tw, th = 160, 148
    title_path = IMG_DIR / _FILENAMES["title"]
    if not title_path.exists():
        pygame.image.save(_build_title_bg(sw, sh), str(title_path))

    parch_path = IMG_DIR / _FILENAMES["parchment"]
    if not parch_path.exists():
        pygame.image.save(gen_parchment_tile(256, seed=91), str(parch_path))

    for terr, name in _FILENAMES["terrains"].items():
        p = IMG_DIR / name
        if not p.exists():
            pygame.image.save(_build_terrain_tile(terr, tw, th), str(p))

    for pk, name in _FILENAMES["portraits"].items():
        p = IMG_DIR / name
        if not p.exists():
            pygame.image.save(_build_portrait(pk, 64, 80), str(p))


def load_game_images() -> None:
    """After pygame.display.set_mode: load PNGs onto assets (with convert_alpha)."""
    ensure_png_assets(assets.SW, assets.SH)

    def _load(path: Path) -> pygame.Surface | None:
        if not path.exists():
            return None
        try:
            s = pygame.image.load(str(path))
            return s.convert_alpha()
        except Exception:
            return None

    assets.IMG_TITLE_BG = _load(IMG_DIR / _FILENAMES["title"])
    tile = _load(IMG_DIR / _FILENAMES["parchment"])
    assets.IMG_PARCHMENT_TILE = tile
    if tile is not None:
        assets.TEX_PARCHMENT = tile

    assets.IMG_TERRAIN_HEX = {}
    for terr, name in _FILENAMES["terrains"].items():
        im = _load(IMG_DIR / name)
        if im is not None:
            assets.IMG_TERRAIN_HEX[terr] = im

    assets.IMG_PORTRAITS = {}
    for pk, name in _FILENAMES["portraits"].items():
        im = _load(IMG_DIR / name)
        if im is not None:
            assets.IMG_PORTRAITS[pk] = im
