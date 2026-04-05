"""2D drawing helpers (pygame)."""

from __future__ import annotations

import pygame

from lewis_clark import assets

# Scaled parchment per panel size — avoids visible tile seams from repeating IMG_PARCHMENT_TILE.
_PARCH_SCALE_CACHE: dict[tuple[int, int], pygame.Surface] = {}
_PARCH_CACHE_MAX = 64


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


def panel_title_metrics(title_font=None, title_strip_h=None):
    """Font and title-band height for :func:`draw_panel` (default = tiny band)."""
    tf = title_font or assets.F["tiny_b"]
    if title_strip_h is not None:
        return tf, title_strip_h
    if title_font is None:
        return tf, 20
    return tf, max(22, tf.get_height() + 10)


def draw_panel(
    surf,
    rect,
    fill=assets.UI_PANEL,
    border=assets.UI_BORDER,
    radius=3,
    title=None,
    accent=None,
    corners=True,
    title_font=None,
    title_strip_h=None,
):
    """Panel with parchment texture, optional title strip, corner brackets."""
    r = pygame.Rect(rect)

    sh = alpha_surf(r.w + 5, r.h + 5, (0, 0, 0), 90)
    surf.blit(sh, (r.x + 3, r.y + 3))

    pygame.draw.rect(surf, fill, r, border_radius=radius)

    tex = getattr(assets, "IMG_PARCHMENT_TILE", None) or getattr(
        assets, "TEX_PARCHMENT", None
    )
    if tex:
        tw, th = tex.get_size()
        if tw > 0 and th > 0:
            key = (r.w, r.h)
            parch_overlay = _PARCH_SCALE_CACHE.get(key)
            if parch_overlay is None:
                parch_overlay = pygame.transform.smoothscale(
                    tex, (max(1, r.w), max(1, r.h))
                )
                if len(_PARCH_SCALE_CACHE) >= _PARCH_CACHE_MAX:
                    _PARCH_SCALE_CACHE.clear()
                _PARCH_SCALE_CACHE[key] = parch_overlay
        else:
            parch_overlay = pygame.Surface((r.w, r.h), pygame.SRCALPHA)
        parch_overlay.set_alpha(255)
        surf.blit(parch_overlay, r.topleft, special_flags=pygame.BLEND_MULT)

    # Fine horizontal grain only — diagonal lines produced vertical banding when blended.
    grain_s = pygame.Surface((r.w, r.h), pygame.SRCALPHA)
    for y in range(0, r.h, 5):
        a = 5 if (y // 5) % 2 == 0 else 4
        pygame.draw.line(grain_s, (255, 255, 255, a), (0, y), (r.w, y), 1)
    for y in range(2, r.h, 5):
        pygame.draw.line(grain_s, (0, 0, 0, 3), (0, y), (r.w, y), 1)
    surf.blit(grain_s, r.topleft)

    pygame.draw.rect(surf, darken(fill, 0.4), r, border_radius=radius)
    pygame.draw.rect(surf, border, r, 1, border_radius=radius)
    hi_r = pygame.Rect(r.x + 1, r.y + 1, r.w - 2, 1)
    pygame.draw.rect(surf, lighten(fill, 1.6), hi_r)
    bot_r = pygame.Rect(r.x + 1, r.bottom - 2, r.w - 2, 1)
    pygame.draw.rect(surf, darken(fill, 0.3), bot_r)

    if title:
        tf, th = panel_title_metrics(title_font, title_strip_h)
        strip = pygame.Rect(r.x, r.y, r.w, th)
        ac = accent or border
        pygame.draw.rect(surf, darken(ac, 0.35), strip, border_radius=radius)
        pygame.draw.line(surf, ac, (r.x, r.y + th), (r.right, r.y + th), 1)
        pygame.draw.line(
            surf, lighten(ac, 0.6),
            (r.x + 4, r.y + th + 1), (r.right - 4, r.y + th + 1), 1,
        )
        draw_text(
            surf,
            title,
            tf,
            lighten(ac, 1.4),
            (r.centerx, r.y + th // 2),
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
    val_col = assets.RED2 if value < 25 else assets.AMBER if value < 50 else colour
    us = getattr(assets, "UI_SCALE", 1.0)
    gap = max(2, int(3 * us))
    line_h = max(
        assets.F["small"].get_height(),
        assets.F["header"].get_height(),
    )
    text_y = y - gap - line_h
    # Clip label/value row so glyphs never bleed into neighbouring columns.
    line_top = text_y - 1
    text_clip = pygame.Rect(x, line_top, w, y - line_top)
    prev_clip = surf.get_clip()
    surf.set_clip(text_clip.clip(prev_clip))
    try:
        draw_text(
            surf,
            icon + label,
            assets.F["small"],
            lbl_col,
            (x + 2, text_y),
            anchor="topleft",
        )
        draw_text(
            surf,
            f"{value}",
            assets.F["header"],
            val_col,
            (x + w - 2, text_y),
            anchor="topright",
        )
    finally:
        surf.set_clip(prev_clip)
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
