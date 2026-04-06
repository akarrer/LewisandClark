"""One-time / script-driven 8-bit style PNG generation for committed repo assets.

Authoring rules (Dwarf Fortress–like):
- Native portrait size 48×60; terrain hex tiles 160×148; scale in-game with nearest-neighbor.
- Keep palettes small (roughly 16–32 colours); flat fills; 1px outlines; no gradients.
- Waypoint sprites ~56×56; animal icons 32×32; cinematic panels 840×900 (matches ART_W×SH at SW=1400).
"""

from __future__ import annotations

import math
from pathlib import Path

import pygame

_REPO = Path(__file__).resolve().parent.parent
IMG_DIR = _REPO / "assets" / "images"
ANIMAL_DIR = IMG_DIR / "animals"

_SW, _SH = 1400, 900
_ART_W = int(_SW * 0.60)  # 840
_CINE_SIZE = (_ART_W, _SH)


def _hex_poly(cx: float, cy: float, r: float) -> list[tuple[int, int]]:
    pts = []
    for i in range(6):
        a = math.radians(60 * i - 30)
        pts.append((int(cx + r * math.cos(a)), int(cy + r * math.sin(a))))
    return pts


# Light mat behind bust + ink lines for DF-style readability (not brown-on-brown).
_MAT = (248, 240, 220)
_INK = (18, 14, 12)
_HAIR = (22, 18, 14)


def _portrait_base(s: pygame.Surface, outer: tuple[int, int, int]) -> None:
    s.fill((*outer, 255))
    pygame.draw.rect(s, _MAT, (5, 5, 38, 50))
    pygame.draw.rect(s, _INK, (5, 5, 38, 50), 1)
    pygame.draw.rect(s, _INK, (0, 0, 48, 60), 2)


def bake_portrait_york() -> pygame.Surface:
    s = pygame.Surface((48, 60), pygame.SRCALPHA)
    _portrait_base(s, (95, 48, 38))
    # Face — darker outline vs mat
    for y in range(15, 37):
        for x in range(14, 34):
            s.set_at((x, y), (95, 62, 42))
    pygame.draw.rect(s, _INK, (12, 14, 24, 24), 1)
    pygame.draw.rect(s, (40, 28, 18), (9, 7, 30, 11))
    pygame.draw.rect(s, _HAIR, (13, 5, 22, 8))
    s.set_at((17, 23), _INK)
    s.set_at((27, 23), _INK)
    pygame.draw.rect(s, (38, 32, 26), (8, 36, 32, 20))
    pygame.draw.line(s, _INK, (24, 36), (24, 54), 1)
    return s


def bake_portrait_drouillard() -> pygame.Surface:
    s = pygame.Surface((48, 60), pygame.SRCALPHA)
    _portrait_base(s, (42, 58, 72))
    pygame.draw.polygon(s, (55, 42, 28), [(24, 7), (9, 19), (39, 19)])
    pygame.draw.polygon(s, _INK, [(24, 7), (9, 19), (39, 19)], 1)
    for y in range(17, 35):
        for x in range(14, 34):
            s.set_at((x, y), (105, 72, 50))
    pygame.draw.rect(s, _INK, (12, 16, 24, 20), 1)
    s.set_at((17, 25), _INK)
    s.set_at((27, 25), _INK)
    pygame.draw.rect(s, (32, 85, 42), (9, 35, 30, 19))
    pygame.draw.rect(s, _INK, (9, 35, 30, 19), 1)
    return s


def bake_portrait_sacagawea() -> pygame.Surface:
    s = pygame.Surface((48, 60), pygame.SRCALPHA)
    _portrait_base(s, (115, 55, 42))
    pygame.draw.rect(s, (38, 26, 18), (7, 15, 7, 22))
    pygame.draw.rect(s, (38, 26, 18), (34, 15, 7, 22))
    for y in range(15, 33):
        for x in range(15, 33):
            s.set_at((x, y), (145, 105, 78))
    pygame.draw.rect(s, _INK, (14, 14, 20, 20), 1)
    s.set_at((19, 24), _INK)
    s.set_at((27, 24), _INK)
    pygame.draw.rect(s, (75, 48, 35), (11, 35, 26, 18))
    pygame.draw.rect(s, _INK, (11, 35, 26, 18), 1)
    return s


def bake_portrait_inactive() -> pygame.Surface:
    s = pygame.Surface((48, 60), pygame.SRCALPHA)
    _portrait_base(s, (48, 48, 55))
    pygame.draw.circle(s, (95, 95, 102), (24, 23), 12)
    pygame.draw.circle(s, _INK, (24, 23), 12, 1)
    pygame.draw.rect(s, (95, 95, 102), (12, 31, 24, 20))
    pygame.draw.rect(s, _INK, (12, 31, 24, 20), 1)
    pygame.draw.line(s, (165, 50, 50), (14, 17), (34, 37), 2)
    return s


def bake_portrait_lewis() -> pygame.Surface:
    s = pygame.Surface((48, 60), pygame.SRCALPHA)
    _portrait_base(s, (38, 48, 78))
    pygame.draw.rect(s, (28, 38, 95), (9, 8, 30, 13))
    pygame.draw.rect(s, _INK, (9, 8, 30, 13), 1)
    for y in range(15, 33):
        for x in range(14, 32):
            s.set_at((x, y), (210, 175, 140))
    pygame.draw.rect(s, _INK, (12, 15, 22, 20), 1)
    s.set_at((17, 24), _INK)
    s.set_at((27, 24), _INK)
    pygame.draw.rect(s, (42, 38, 32), (8, 34, 32, 20))
    pygame.draw.rect(s, _INK, (8, 34, 32, 20), 1)
    return s


def bake_portrait_clark() -> pygame.Surface:
    s = pygame.Surface((48, 60), pygame.SRCALPHA)
    _portrait_base(s, (35, 72, 48))
    pygame.draw.rect(s, (115, 58, 32), (9, 6, 30, 14))
    pygame.draw.rect(s, _INK, (9, 6, 30, 14), 1)
    for y in range(15, 33):
        for x in range(14, 32):
            s.set_at((x, y), (200, 155, 118))
    pygame.draw.rect(s, _INK, (12, 15, 22, 20), 1)
    s.set_at((17, 24), _INK)
    s.set_at((27, 24), _INK)
    pygame.draw.rect(s, (28, 62, 38), (8, 34, 32, 20))
    pygame.draw.rect(s, _INK, (8, 34, 32, 20), 1)
    return s


def bake_portrait_jefferson() -> pygame.Surface:
    s = pygame.Surface((48, 60), pygame.SRCALPHA)
    _portrait_base(s, (52, 42, 95))
    pygame.draw.rect(s, (235, 228, 210), (6, 6, 36, 13))
    pygame.draw.rect(s, _INK, (6, 6, 36, 13), 1)
    pygame.draw.rect(s, (235, 220, 200), (8, 12, 32, 22))
    pygame.draw.rect(s, _INK, (8, 12, 32, 22), 1)
    pygame.draw.rect(s, (48, 40, 35), (8, 34, 32, 20))
    pygame.draw.rect(s, _INK, (8, 34, 32, 20), 1)
    s.set_at((18, 21), _INK)
    s.set_at((28, 21), _INK)
    return s


def bake_portrait_napoleon() -> pygame.Surface:
    s = pygame.Surface((48, 60), pygame.SRCALPHA)
    _portrait_base(s, (28, 28, 55))
    pygame.draw.polygon(s, (35, 32, 48), [(24, 5), (7, 16), (41, 16)])
    pygame.draw.polygon(s, _INK, [(24, 5), (7, 16), (41, 16)], 1)
    for y in range(15, 32):
        for x in range(14, 32):
            s.set_at((x, y), (235, 205, 175))
    pygame.draw.rect(s, _INK, (12, 15, 22, 19), 1)
    pygame.draw.rect(s, (42, 38, 115), (7, 34, 34, 20))
    pygame.draw.rect(s, _INK, (7, 34, 34, 20), 1)
    return s


def bake_portrait_corps() -> pygame.Surface:
    s = pygame.Surface((48, 60), pygame.SRCALPHA)
    _portrait_base(s, (72, 62, 35))
    pygame.draw.polygon(s, (28, 24, 18), [(8, 39), (24, 13), (40, 39)])
    pygame.draw.polygon(s, _INK, [(8, 39), (24, 13), (40, 39)], 1)
    pygame.draw.rect(s, (220, 38, 38), (19, 9, 10, 8))
    pygame.draw.rect(s, _INK, (19, 9, 10, 8), 1)
    pygame.draw.rect(s, (48, 42, 32), (10, 38, 28, 15))
    pygame.draw.rect(s, _INK, (10, 38, 28, 15), 1)
    pygame.draw.circle(s, (55, 75, 42), (24, 49), 7)
    pygame.draw.circle(s, _INK, (24, 49), 7, 1)
    return s


def bake_title_bg() -> pygame.Surface:
    w, h = _SW, _SH
    s = pygame.Surface((w, h))
    for y in range(h):
        t = y / max(h - 1, 1)
        c = (10 + int(t * 28), 8 + int(t * 32), 22 + int(t * 48))
        pygame.draw.line(s, c, (0, y), (w, y))
    # Chunky hills
    hill = [
        (0, h),
        (0, int(h * 0.52)),
        (int(w * 0.18), int(h * 0.46)),
        (int(w * 0.42), int(h * 0.50)),
        (int(w * 0.68), int(h * 0.44)),
        (w, int(h * 0.48)),
        (w, h),
    ]
    pygame.draw.polygon(s, (6, 22, 14), hill)
    pygame.draw.polygon(s, (18, 38, 28), hill, 4)
    # River blocks
    for i in range(0, 50, 4):
        rx = int(w * (0.22 + i * 0.012))
        ry = int(h * 0.62 + math.sin(i * 0.2) * 10)
        pygame.draw.rect(s, (32, 58, 72), (rx, ry, 8, 4))
    # Moon (chunky)
    pygame.draw.circle(s, (230, 235, 218), (w - 108, 88), 26)
    pygame.draw.circle(s, (200, 205, 190), (w - 108, 88), 22)
    return s


def _terrain_base(terr: str) -> tuple[tuple[int, int, int], tuple[int, int, int]]:
    return {
        "plains": ((210, 192, 125), (165, 145, 78)),
        "river": ((130, 168, 205), (85, 125, 168)),
        "mountain": ((155, 132, 92), (105, 88, 62)),
        "forest": ((110, 145, 78), (65, 95, 55)),
        "coast": ((130, 185, 198), (88, 155, 168)),
    }[terr]


def bake_terrain_tile(terr: str, tw: int, th: int) -> pygame.Surface:
    surf = pygame.Surface((tw, th), pygame.SRCALPHA)
    cx_f, cy_f = tw / 2, th / 2
    r = min(tw, th) * 0.42
    pts = _hex_poly(cx_f, cy_f, r)
    hi, lo = _terrain_base(terr)
    mid = tuple((hi[i] + lo[i]) // 2 for i in range(3))
    pygame.draw.polygon(surf, (*mid, 255), pts)
    pygame.draw.polygon(surf, (*lo, 240), pts, 2)
    # 8-bit detail — fixed pattern, no random
    cx, cy = int(cx_f), int(cy_f)
    if terr == "plains":
        for dx, dy in [(-20, -8), (8, 12), (-12, 14), (18, -6)]:
            pygame.draw.circle(
                surf, (mid[0] - 25, mid[1] - 20, mid[2] - 15), (cx + dx, cy + dy), 2
            )
    elif terr == "river":
        for ly in range(-28, 30, 8):
            wy = cy + ly
            pygame.draw.line(
                surf, (160, 198, 228, 200), (cx - 50, wy), (cx + 50, wy), 2
            )
    elif terr == "mountain":
        for ox in (-18, 4, 20):
            pygame.draw.polygon(
                surf,
                (115, 95, 68, 250),
                [(cx + ox, cy + 16), (cx + ox - 4, cy - 18), (cx + ox + 18, cy + 10)],
            )
    elif terr == "forest":
        for ox, oy in [(-16, 4), (8, -8), (14, 10)]:
            pygame.draw.circle(surf, (48, 88, 42, 250), (cx + ox, cy + oy), 8)
    else:
        for fx, fy in [(-20, 6), (10, -10), (18, 14)]:
            pygame.draw.circle(surf, (175, 210, 220, 160), (cx + fx, cy + fy), 2)
    return surf


def bake_waypoint(kind: str, sz: int = 56) -> pygame.Surface:
    s = pygame.Surface((sz, sz), pygame.SRCALPHA)
    cx, cy = sz // 2, sz // 2
    sh = (0, 0, 0, 100)
    if kind == "fort":
        pygame.draw.circle(s, sh, (cx + 2, cy + 2), 22)
        r = 20
        pygame.draw.rect(s, (218, 198, 148), (cx - r, cy - r, r * 2, r * 2))
        pygame.draw.rect(s, (68, 48, 18), (cx - r, cy - r, r * 2, r * 2), 3)
        for bx, by in [
            (cx - r, cy - r),
            (cx + r, cy - r),
            (cx - r, cy + r),
            (cx + r, cy + r),
        ]:
            pygame.draw.circle(s, (68, 48, 18), (bx, by), 6)
            pygame.draw.circle(s, (218, 198, 148), (bx, by), 4)
        pygame.draw.line(
            s, (68, 48, 18), (cx - r + 5, cy - r), (cx - r + 5, cy - r - 16), 2
        )
        pygame.draw.polygon(
            s,
            (150, 28, 28),
            [
                (cx - r + 5, cy - r - 16),
                (cx - r + 18, cy - r - 10),
                (cx - r + 5, cy - r - 6),
            ],
        )
    elif kind == "pass":
        pygame.draw.circle(s, sh, (cx + 2, cy + 2), 20)
        p = [(cx, cy - 22), (cx + 22, cy), (cx, cy + 22), (cx - 22, cy)]
        pygame.draw.polygon(s, (218, 198, 148), p)
        pygame.draw.polygon(s, (68, 48, 18), p, 3)
        pygame.draw.polygon(
            s, (100, 78, 48), [(cx - 8, cy + 6), (cx, cy - 10), (cx + 8, cy + 6)]
        )
    elif kind == "dead_end":
        pygame.draw.circle(s, sh, (cx + 2, cy + 2), 18)
        pygame.draw.circle(s, (88, 32, 32), (cx, cy), 18)
        pygame.draw.circle(s, (130, 44, 44), (cx, cy), 18, 3)
        pygame.draw.line(s, (210, 90, 90), (cx - 10, cy - 10), (cx + 10, cy + 10), 3)
        pygame.draw.line(s, (210, 90, 90), (cx + 10, cy - 10), (cx - 10, cy + 10), 3)
    elif kind == "junction":
        pygame.draw.circle(s, sh, (cx + 2, cy + 2), 20)
        pygame.draw.circle(s, (218, 198, 148), (cx, cy), 20)
        pygame.draw.circle(s, (68, 48, 18), (cx, cy), 20, 3)
        for ang in (270, 30, 150):
            rad = math.radians(ang)
            ex = cx + int(math.cos(rad) * 14)
            ey = cy - int(math.sin(rad) * 14)
            pygame.draw.line(s, (68, 48, 18), (cx, cy), (ex, ey), 3)
    else:
        pygame.draw.circle(s, sh, (cx + 2, cy + 2), 22)
        pygame.draw.circle(s, (218, 198, 148), (cx, cy), 22)
        pygame.draw.circle(s, (68, 48, 18), (cx, cy), 22, 3)
        pygame.draw.circle(s, (68, 48, 18), (cx, cy), 7)
    return s


def _cine_bg_grad(
    surf: pygame.Surface, top: tuple[int, int, int], bot: tuple[int, int, int]
) -> None:
    w, h = surf.get_size()
    for y in range(h):
        t = y / max(h - 1, 1)
        c = tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3))
        pygame.draw.line(surf, c, (0, y), (w, y))


def bake_cinematic(scene_id: str) -> pygame.Surface:
    W, H = _CINE_SIZE
    s = pygame.Surface((W, H))

    def block(x, y, bw, bh, col):
        pygame.draw.rect(s, col, (x, y, bw, bh))

    if scene_id == "secret_message":
        _cine_bg_grad(s, (28, 22, 18), (48, 38, 28))
        block(80, H - 280, 520, 220, (42, 32, 24))
        block(120, H - 420, 120, 160, (55, 42, 30))
        block(260, H - 380, 8, 24, (200, 180, 120))
        pygame.draw.circle(s, (255, 240, 200), (264, H - 392), 16)
        pygame.draw.rect(s, (35, 28, 22), (400, H - 360, 200, 24))
        for i in range(6):
            pygame.draw.line(
                s, (30, 24, 18), (410 + i * 30, H - 352), (410 + i * 30, H - 320), 2
            )
    elif scene_id == "napoleon":
        _cine_bg_grad(s, (40, 35, 55), (22, 18, 35))
        block(100, 80, W - 200, H - 200, (55, 48, 38))
        pygame.draw.rect(s, (75, 105, 140), (140, 200, 240, 160), 4)
        pygame.draw.rect(s, (90, 68, 40), (420, 220, 280, 120), 4)
        for i in range(5):
            pygame.draw.line(
                s, (35, 55, 75), (160 + i * 40, 240), (200 + i * 50, 340), 3
            )
    elif scene_id == "lewis_prepares":
        _cine_bg_grad(s, (55, 62, 85), (35, 40, 55))
        block(120, H - 200, W - 240, 80, (42, 38, 32))
        pygame.draw.rect(s, (85, 72, 58), (W // 2 - 40, H - 420, 80, 200))
        pygame.draw.rect(s, (55, 48, 38), (W // 2 - 8, H - 380, 16, 180))
    elif scene_id == "clark_recruited":
        _cine_bg_grad(s, (70, 65, 55), (40, 38, 32))
        for i, x0 in enumerate([200, W // 2, W - 200]):
            pygame.draw.circle(s, (120 + i * 15, 95, 72), (x0, H // 2), 40)
            pygame.draw.rect(s, (55, 48, 42), (x0 - 30, H // 2 + 20, 60, 120))
        pygame.draw.line(
            s, (42, 38, 32), (W // 2 - 60, H // 2 + 20), (W // 2 + 60, H // 2 + 20), 4
        )
    elif scene_id == "corps_assembled":
        _cine_bg_grad(s, (85, 90, 110), (45, 52, 62))
        for tx in range(120, W - 80, 100):
            pygame.draw.polygon(
                s, (42, 38, 32), [(tx, H - 120), (tx + 40, H - 200), (tx + 80, H - 120)]
            )
            pygame.draw.rect(s, (55, 48, 40), (tx + 20, H - 120, 40, 80))
    elif scene_id == "the_river":
        _cine_bg_grad(s, (110, 125, 145), (55, 70, 88))
        for y in range(400, H, 12):
            pygame.draw.line(s, (65, 110, 145), (0, y), (W, y), 8)
        pygame.draw.ellipse(s, (42, 38, 32), (W // 2 - 120, H // 2 - 40, 240, 100))
        pygame.draw.rect(s, (75, 65, 52), (W // 2 - 8, H // 2 - 20, 16, 100))
    else:  # depart
        _cine_bg_grad(s, (45, 55, 75), (25, 35, 48))
        pygame.draw.ellipse(s, (55, 75, 95), (100, H // 2 - 80, W - 200, 200))
        pygame.draw.polygon(
            s,
            (42, 38, 32),
            [
                (W // 2 - 100, H // 2 + 40),
                (W // 2, H // 2 - 60),
                (W // 2 + 100, H // 2 + 40),
            ],
        )
        pygame.draw.rect(s, (68, 58, 48), (W // 2 - 60, H // 2 + 40, 120, 40))

    pygame.draw.rect(s, (28, 22, 18), (0, 0, W, H), 6)
    return s


def bake_animal(key: str) -> pygame.Surface:
    s = pygame.Surface((32, 32), pygame.SRCALPHA)
    if key == "grizzly":
        s.fill((0, 0, 0, 0))
        pygame.draw.ellipse(s, (92, 62, 38), (4, 8, 24, 20))
        pygame.draw.circle(s, (72, 48, 28), (10, 14), 5)
        pygame.draw.circle(s, (72, 48, 28), (22, 14), 5)
        pygame.draw.polygon(s, (82, 52, 32), [(8, 22), (4, 28), (12, 26)])
        pygame.draw.polygon(s, (82, 52, 32), [(24, 22), (28, 28), (20, 26)])
    elif key == "buffalo":
        pygame.draw.ellipse(s, (48, 42, 38), (4, 10, 24, 16))
        pygame.draw.circle(s, (38, 35, 32), (8, 14), 7)
        pygame.draw.rect(s, (32, 28, 25), (14, 6, 4, 8))
    elif key == "elk":
        pygame.draw.rect(s, (72, 58, 45), (10, 12, 12, 16))
        pygame.draw.polygon(s, (55, 45, 35), [(16, 8), (12, 4), (20, 4)])
        pygame.draw.rect(s, (48, 38, 30), (8, 22, 4, 8))
        pygame.draw.rect(s, (48, 38, 30), (20, 22, 4, 8))
    else:  # generic wildlife
        pygame.draw.circle(s, (88, 72, 55), (16, 18), 10)
        pygame.draw.rect(s, (62, 52, 42), (12, 22, 8, 8))
    pygame.draw.rect(s, (28, 22, 18), (0, 0, 32, 32), 1)
    return s


def bake_parchment_tile(size: int = 256) -> pygame.Surface:
    """Flat parchment tile without runtime noise (8-bit friendly)."""
    surf = pygame.Surface((size, size))
    base = (218, 200, 155)
    surf.fill(base)
    for x in range(0, size, 8):
        for y in range(0, size, 8):
            v = 8 if (x // 8 + y // 8) % 2 == 0 else -6
            c = tuple(max(0, min(255, base[i] + v)) for i in range(3))
            pygame.draw.rect(surf, c, (x, y, 8, 8))
    pygame.draw.rect(surf, (180, 155, 110), (0, 0, size, size), 2)
    return surf


def bake_all_output_dirs() -> None:
    IMG_DIR.mkdir(parents=True, exist_ok=True)
    ANIMAL_DIR.mkdir(parents=True, exist_ok=True)


def bake_all_to_disk() -> None:
    """Write every committed asset file used by the game."""
    from lewis_clark.compass_rose import render_compass_rose_surface
    from lewis_clark.louisiana_cartouche import render_louisiana_cartouche_surface

    bake_all_output_dirs()
    pygame.image.save(
        render_compass_rose_surface(48),
        str(IMG_DIR / "compass_rose.png"),
    )
    pygame.image.save(
        render_louisiana_cartouche_surface(),
        str(IMG_DIR / "louisiana_cartouche.png"),
    )
    pygame.image.save(bake_portrait_york(), str(IMG_DIR / "portrait_york.png"))
    pygame.image.save(
        bake_portrait_drouillard(), str(IMG_DIR / "portrait_drouillard.png")
    )
    pygame.image.save(
        bake_portrait_sacagawea(), str(IMG_DIR / "portrait_sacagawea.png")
    )
    pygame.image.save(bake_portrait_inactive(), str(IMG_DIR / "portrait_inactive.png"))
    pygame.image.save(bake_portrait_lewis(), str(IMG_DIR / "portrait_lewis.png"))
    pygame.image.save(bake_portrait_clark(), str(IMG_DIR / "portrait_clark.png"))
    pygame.image.save(
        bake_portrait_jefferson(), str(IMG_DIR / "portrait_jefferson.png")
    )
    pygame.image.save(bake_portrait_napoleon(), str(IMG_DIR / "portrait_napoleon.png"))
    pygame.image.save(bake_portrait_corps(), str(IMG_DIR / "portrait_corps.png"))
    pygame.image.save(bake_title_bg(), str(IMG_DIR / "title_bg.png"))
    pygame.image.save(bake_parchment_tile(256), str(IMG_DIR / "parchment_tile.png"))
    tw, th = 160, 148
    for terr in ("plains", "river", "mountain", "forest", "coast"):
        pygame.image.save(
            bake_terrain_tile(terr, tw, th),
            str(IMG_DIR / f"terrain_{terr}.png"),
        )
    for kind in ("fort", "pass", "dead_end", "junction", "camp"):
        pygame.image.save(
            bake_waypoint(kind, 56),
            str(IMG_DIR / f"waypoint_{kind}.png"),
        )
    for sid in (
        "secret_message",
        "napoleon",
        "lewis_prepares",
        "clark_recruited",
        "corps_assembled",
        "the_river",
        "depart",
    ):
        pygame.image.save(
            bake_cinematic(sid),
            str(IMG_DIR / f"cine_{sid}.png"),
        )
    for ak in ("grizzly", "buffalo", "elk", "generic"):
        pygame.image.save(
            bake_animal(ak),
            str(ANIMAL_DIR / f"animal_{ak}.png"),
        )


if __name__ == "__main__":
    import os

    os.environ.setdefault("SDL_VIDEODRIVER", "dummy")
    pygame.init()
    bake_all_to_disk()
