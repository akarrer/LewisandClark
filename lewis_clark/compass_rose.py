"""Ornate compass rose — shared bake target and optional runtime fallback."""

from __future__ import annotations

import math
from pathlib import Path

import pygame

_FONT_DIR = Path(__file__).resolve().parent.parent / "assets" / "fonts"


def _compass_font(
    size: int, bold: bool = False, italic: bool = False
) -> pygame.font.Font:
    garamond = _FONT_DIR / ("EBGaramond-Italic.ttf" if italic else "EBGaramond.ttf")
    try:
        if garamond.exists():
            f = pygame.font.Font(str(garamond), size)
            if bold:
                f.set_bold(True)
            return f
    except Exception:
        pass
    return pygame.font.SysFont("Georgia", size, bold=bold, italic=italic)


def render_compass_rose_surface(cr: int = 48) -> pygame.Surface:
    """Draw the full compass (matches former :meth:`MapView.draw` logic) onto a transparent surface.

    Center of the rose is at the center of the returned image.
    """
    # 128×128 fits ring (116) plus label margins for N/E/S/W pills.
    w = h = max(128, cr * 2 + 32)
    cx = w // 2
    cy = h // 2
    surf = pygame.Surface((w, h), pygame.SRCALPHA)

    outer_ring = pygame.Surface((cr * 2 + 20, cr * 2 + 20), pygame.SRCALPHA)
    oc = cr + 10
    pygame.draw.circle(outer_ring, (220, 205, 160, 220), (oc, oc), cr + 6)
    pygame.draw.circle(outer_ring, (160, 140, 90, 200), (oc, oc), cr + 6, 2)
    pygame.draw.circle(outer_ring, (196, 178, 128, 230), (oc, oc), cr)
    pygame.draw.circle(outer_ring, (100, 78, 32, 180), (oc, oc), cr, 2)
    pygame.draw.circle(outer_ring, (180, 160, 110, 160), (oc, oc), cr - 4, 1)
    for tick in range(32):
        a = math.radians(tick * 11.25)
        ln = 4 if tick % 8 == 0 else (3 if tick % 4 == 0 else 2)
        r_in = cr - 2 - ln
        r_out = cr - 1
        pygame.draw.line(
            outer_ring,
            (80, 60, 25, 160),
            (oc + int(math.sin(a) * r_in), oc - int(math.cos(a) * r_in)),
            (oc + int(math.sin(a) * r_out), oc - int(math.cos(a) * r_out)),
            1,
        )
    surf.blit(outer_ring, (cx - oc, cy - oc))

    cardinal_len = cr - 8
    inter_len = cr - 18
    crx, cry = cx, cy
    for i in range(8):
        a = math.radians(i * 45)
        is_card = i % 2 == 0
        ln = cardinal_len if is_card else inter_len
        w_ln = 3 if is_card else 2
        tip_x = crx + int(math.sin(a) * ln)
        tip_y = cry - int(math.cos(a) * ln)

        if is_card:
            perp = math.radians(i * 45 + 90)
            bw = 8
            pts_star = [
                (tip_x, tip_y),
                (crx + int(math.sin(perp) * bw), cry - int(math.cos(perp) * bw)),
                (crx, cry),
                (crx - int(math.sin(perp) * bw), cry + int(math.cos(perp) * bw)),
            ]
            dark = (80, 55, 20) if i in (0, 2) else (120, 90, 40)
            light = (200, 170, 100) if i in (0, 2) else (230, 210, 160)
            pygame.draw.polygon(surf, dark, [pts_star[0], pts_star[1], pts_star[2]])
            pygame.draw.polygon(surf, light, [pts_star[0], pts_star[3], pts_star[2]])
            pygame.draw.polygon(surf, (60, 42, 14), pts_star, 1)
        else:
            pygame.draw.line(surf, (100, 75, 30), (crx, cry), (tip_x, tip_y), w_ln)

    fleur_y = cry - cardinal_len - 4
    pygame.draw.polygon(
        surf,
        (180, 40, 20),
        [(crx, fleur_y - 6), (crx - 4, fleur_y), (crx + 4, fleur_y)],
    )
    pygame.draw.circle(surf, (180, 40, 20), (crx, fleur_y - 7), 3)

    for lb9, ag9 in [("N", 0), ("E", 90), ("S", 180), ("W", 270)]:
        dist = cr - 12
        lxc = crx + int(math.sin(math.radians(ag9)) * dist)
        lyc = cry - int(math.cos(math.radians(ag9)) * dist)
        try:
            fc9 = _compass_font(9, bold=True)
            lbl_col = (180, 40, 20) if lb9 == "N" else (58, 40, 8)
            ts9 = fc9.render(lb9, True, lbl_col)
            bg_pill = pygame.Surface(
                (ts9.get_width() + 6, ts9.get_height() + 2), pygame.SRCALPHA
            )
            bg_pill.fill((220, 205, 160, 180))
            surf.blit(
                bg_pill,
                (
                    lxc - bg_pill.get_width() // 2,
                    lyc - bg_pill.get_height() // 2,
                ),
            )
            surf.blit(ts9, ts9.get_rect(center=(lxc, lyc)))
        except Exception:
            pass

    pygame.draw.circle(surf, (140, 100, 30), (crx, cry), 5)
    pygame.draw.circle(surf, (220, 180, 80), (crx, cry), 3)
    pygame.draw.circle(surf, (80, 55, 20), (crx, cry), 5, 1)
    return surf
