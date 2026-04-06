"""Louisiana Territory map cartouche — baked PNG + optional runtime fallback."""

from __future__ import annotations

import math
from pathlib import Path

import pygame

_FONT_DIR = Path(__file__).resolve().parent.parent / "assets" / "fonts"


def _cartouche_font(
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


def render_louisiana_cartouche_surface(
    cw3: int = 525,
    ch3: int = 348,
) -> pygame.Surface:
    """Render the decorative cartouche (matches former canvas section 7). Top-left aligned."""
    cx3 = 0
    cy3 = 0
    w = max(cw3 + 12, cw3 + 8 + 4)
    h = max(ch3 + 12, ch3 + 8 + 4)
    surf = pygame.Surface((w, h), pygame.SRCALPHA)

    sh_s = pygame.Surface((cw3 + 8, ch3 + 8), pygame.SRCALPHA)
    sh_s.fill((0, 0, 0, 60))
    surf.blit(sh_s, (cx3 + 4, cy3 + 4))

    pygame.draw.rect(surf, (215, 198, 148), (cx3, cy3, cw3, ch3))

    for i in range(0, cw3 + ch3, 10):
        pygame.draw.line(
            surf,
            (222, 206, 158),
            (cx3 + i, cy3),
            (cx3 + max(0, i - ch3), cy3 + ch3),
            1,
        )

    pygame.draw.rect(surf, (62, 46, 18), (cx3, cy3, cw3, ch3), 4)
    pygame.draw.rect(surf, (90, 68, 24), (cx3 + 6, cy3 + 6, cw3 - 12, ch3 - 12), 2)
    pygame.draw.rect(surf, (110, 85, 35), (cx3 + 10, cy3 + 10, cw3 - 20, ch3 - 20), 1)

    rope_step = 12
    for edge in range(4):
        if edge == 0:
            pts = [(cx3 + i, cy3 + 3) for i in range(3, cw3 - 3, rope_step)]
        elif edge == 1:
            pts = [(cx3 + i, cy3 + ch3 - 3) for i in range(3, cw3 - 3, rope_step)]
        elif edge == 2:
            pts = [(cx3 + 3, cy3 + i) for i in range(3, ch3 - 3, rope_step)]
        else:
            pts = [(cx3 + cw3 - 3, cy3 + i) for i in range(3, ch3 - 3, rope_step)]
        for j, (rx, ry) in enumerate(pts):
            off = 2 if j % 2 == 0 else -2
            if edge < 2:
                pygame.draw.circle(surf, (90, 68, 30), (rx, ry + off), 2)
            else:
                pygame.draw.circle(surf, (90, 68, 30), (rx + off, ry), 2)

    for ccx, ccy, sdx, sdy in [
        (cx3 + 6, cy3 + 6, 1, 1),
        (cx3 + cw3 - 6, cy3 + 6, -1, 1),
        (cx3 + 6, cy3 + ch3 - 6, 1, -1),
        (cx3 + cw3 - 6, cy3 + ch3 - 6, -1, -1),
    ]:
        pygame.draw.line(surf, (62, 46, 18), (ccx, ccy), (ccx + sdx * 18, ccy), 2)
        pygame.draw.line(surf, (62, 46, 18), (ccx, ccy), (ccx, ccy + sdy * 18), 2)
        curl_pts = []
        for t in range(8):
            a = math.radians(t * 30 * sdx * sdy)
            curl_pts.append(
                (
                    ccx + sdx * (20 + int(math.cos(a) * 6)),
                    ccy + sdy * (2 + int(math.sin(a) * 4)),
                )
            )
        if len(curl_pts) >= 2:
            pygame.draw.lines(surf, (90, 68, 24), False, curl_pts, 1)

    try:
        fct = _cartouche_font(24, italic=True)
        fcb = _cartouche_font(35, bold=True)
        fs = _cartouche_font(16)
        cxm = cx3 + cw3 // 2
        col_body = (78, 56, 20)
        col_title = (40, 28, 8)

        y_line = cy3 + 10
        pygame.draw.line(
            surf,
            (90, 68, 24),
            (cx3 + 28, y_line),
            (cx3 + cw3 - 28, y_line),
            1,
        )

        y_txt = cy3 + 20
        for txt3, fn3, col3 in [
            ("MAP of the", fct, col_body),
            ("LOUISIANA TERRITORY", fcb, col_title),
        ]:
            ts = fn3.render(txt3, True, col3)
            surf.blit(ts, ts.get_rect(centerx=cxm, top=y_txt))
            y_txt += ts.get_height() + 6

        pygame.draw.line(
            surf,
            (90, 68, 24),
            (cx3 + 28, y_txt + 2),
            (cx3 + cw3 - 28, y_txt + 2),
            1,
        )
        y_txt += 14

        for txt3 in [
            "Explored by Capts LEWIS & CLARK",
            "By order of President Jefferson",
            "Anno Domini MDCCCIV",
        ]:
            ts = fct.render(txt3, True, col_body)
            surf.blit(ts, ts.get_rect(centerx=cxm, top=y_txt))
            y_txt += ts.get_height() + 5

        # Space below last line before scale; extra room so bottom border/rope/curls
        # sit below the ruler and “Miles (approx.)” label.
        y_txt += 22
        scale_y = y_txt
        scale_x = cx3 + 36
        scale_w = cw3 - 72
        pygame.draw.line(
            surf, (60, 42, 14), (scale_x, scale_y), (scale_x + scale_w, scale_y), 2
        )
        for si in range(5):
            sx = scale_x + int(si / 4 * scale_w)
            pygame.draw.line(
                surf, (60, 42, 14), (sx, scale_y - 5), (sx, scale_y + 5), 1
            )
            miles = str(si * 100)
            ts = fs.render(miles, True, col_body)
            surf.blit(ts, ts.get_rect(centerx=sx, top=scale_y + 6))
        ts = fs.render("Miles (approx.)", True, col_body)
        surf.blit(
            ts,
            ts.get_rect(centerx=scale_x + scale_w // 2, top=scale_y + 20),
        )
    except Exception:
        pass

    return surf
