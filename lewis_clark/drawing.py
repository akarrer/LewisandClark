"""2D drawing helpers (pygame)."""

from __future__ import annotations

import pygame

from lewis_clark import assets


def hex2rgb(h: str):
    h = h.lstrip("#")
    return tuple(int(h[i : i + 2], 16) for i in (0, 2, 4))


def blend(c1, c2, t):
    return tuple(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(3))


def darken(c, f=0.7):
    return tuple(max(0, min(255, int(v * f))) for v in c)


def lighten(c, f=1.3):
    return tuple(max(0, min(255, int(v * f))) for v in c)


def alpha_surf(w, h, colour, alpha):
    s = pygame.Surface((w, h), pygame.SRCALPHA)
    s.fill((*colour, alpha))
    return s


def draw_text(surf, text, font, colour, pos, anchor="topleft", max_w=None):
    if max_w:
        words = text.split()
        lines = []
        line = ""
        for w in words:
            test = (line + " " + w).strip()
            if font.size(test)[0] <= max_w:
                line = test
            else:
                lines.append(line)
                line = w
        if line:
            lines.append(line)
        y = pos[1]
        for ln in lines:
            s = font.render(ln, True, colour)
            r = s.get_rect(**{anchor: (pos[0], y)})
            surf.blit(s, r)
            y += s.get_height() + 2
        return y
    else:
        s = font.render(text, True, colour)
        r = s.get_rect(**{anchor: pos})
        surf.blit(s, r)
        return r.bottom


def draw_corner_brackets(surf, rect, col=assets.GOLD, size=10, width=2):
    """Ornate corner bracket ornaments — like leather journal binding."""
    x, y, w, h = rect.x, rect.y, rect.w, rect.h
    for cx, cy, sx, sy in [
        (x, y, 1, 1),
        (x + w, y, -1, 1),
        (x, y + h, 1, -1),
        (x + w, y + h, -1, -1),
    ]:
        pygame.draw.line(surf, col, (cx, cy), (cx + sx * size, cy), width)
        pygame.draw.line(surf, col, (cx, cy), (cx, cy + sy * size), width)


def draw_panel(
    surf,
    rect,
    fill=assets.UI_PANEL,
    border=assets.UI_BORDER,
    radius=3,
    title=None,
    accent=None,
    corners=True,
):
    """Panel with wood-grain texture, optional title strip, corner brackets."""
    r = pygame.Rect(rect)
    sh = alpha_surf(r.w + 4, r.h + 4, (0, 0, 0), 80)
    surf.blit(sh, (r.x + 2, r.y + 2))
    pygame.draw.rect(surf, fill, r, border_radius=radius)
    grain_s = pygame.Surface((r.w, r.h), pygame.SRCALPHA)
    for i in range(0, r.w + r.h, 14):
        pygame.draw.line(grain_s, (255, 255, 255, 6), (i, 0), (max(0, i - r.h), r.h))
    surf.blit(grain_s, r.topleft)
    pygame.draw.rect(surf, darken(fill, 0.4), r, border_radius=radius)
    pygame.draw.rect(surf, border, r, 1, border_radius=radius)
    hi_r = pygame.Rect(r.x + 1, r.y + 1, r.w - 2, 1)
    pygame.draw.rect(surf, lighten(fill, 1.6), hi_r)
    if title:
        strip = pygame.Rect(r.x, r.y, r.w, 20)
        ac = accent or border
        pygame.draw.rect(surf, darken(ac, 0.35), strip, border_radius=radius)
        pygame.draw.line(surf, ac, (r.x, r.y + 20), (r.right, r.y + 20), 1)
        draw_text(
            surf,
            title,
            assets.F["tiny_b"],
            lighten(ac, 1.4),
            (r.centerx, r.y + 10),
            anchor="center",
        )
    if corners:
        draw_corner_brackets(surf, r, lighten(border, 1.3), size=8)


def draw_separator(surf, x, y, w, col=assets.UI_BORDER):
    """Horizontal rule with centre diamond — like ink on parchment."""
    mid = x + w // 2
    pygame.draw.line(surf, col, (x + 10, y), (mid - 6, y), 1)
    pygame.draw.line(surf, col, (mid + 6, y), (x + w - 10, y), 1)
    pts = [(mid, y - 4), (mid + 4, y), (mid, y + 4), (mid - 4, y)]
    pygame.draw.polygon(surf, lighten(col, 1.4), pts)


def stat_bar(surf, x, y, w, h, value, colour, label, icon=""):
    """Engraved stat bar — recessed track, bright fill, danger pulse."""
    lbl_col = assets.INK_FAINT if value > 25 else assets.RED2
    draw_text(
        surf, icon + label, assets.F["tiny_b"], lbl_col, (x, y - 13), anchor="topleft"
    )
    val_col = assets.RED2 if value < 25 else assets.AMBER if value < 50 else colour
    draw_text(
        surf,
        f"{value}",
        assets.F["subhead"],
        val_col,
        (x + w, y - 13),
        anchor="topright",
    )
    pygame.draw.rect(
        surf, darken(colour, 0.15), (x - 1, y - 1, w + 2, h + 2), border_radius=2
    )
    pygame.draw.rect(surf, darken(colour, 0.2), (x, y, w, h), border_radius=2)
    if value < 25:
        dz = alpha_surf(w // 4, h, assets.RED_DIM, 60)
        surf.blit(dz, (x, y))
    fw = max(2, int(w * value / 100))
    pygame.draw.rect(surf, val_col, (x, y, fw, h), border_radius=2)
    pygame.draw.rect(surf, lighten(val_col, 1.5), (x, y, fw, 2), border_radius=1)
    for t in [25, 50, 75]:
        tx = x + int(w * t / 100)
        pygame.draw.line(surf, darken(colour, 0.5), (tx, y), (tx, y + h), 1)
    pygame.draw.rect(surf, darken(colour, 0.5), (x, y, w, h), 1, border_radius=2)


def draw_wax_seal(surf, cx, cy, r, col, letter):
    """Small wax seal ornament."""
    pygame.draw.circle(surf, darken(col, 0.6), (cx + 2, cy + 2), r)
    pygame.draw.circle(surf, col, (cx, cy), r)
    pygame.draw.circle(surf, lighten(col, 1.3), (cx, cy), r, 1)
    pygame.draw.circle(surf, lighten(col, 1.6), (cx - r // 3, cy - r // 3), r // 3)
    ts = assets.F["tiny_b"].render(letter, True, darken(col, 0.3))
    surf.blit(ts, ts.get_rect(center=(cx, cy)))
