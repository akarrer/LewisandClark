"""UI widgets."""

from __future__ import annotations

import pygame

from lewis_clark import assets
from lewis_clark.drawing import (
    alpha_surf,
    darken,
    draw_corner_brackets,
    lighten,
)


def _text_width(font: pygame.font.Font, text: str) -> int:
    return font.size(text)[0]


def _truncate_to_width(font: pygame.font.Font, text: str, max_w: int) -> str:
    """Shorten *text* with an ellipsis so rendered width ≤ *max_w*."""
    if max_w <= 0:
        return ""
    if _text_width(font, text) <= max_w:
        return text
    ell = "…"
    if _text_width(font, ell) > max_w:
        return ""
    lo, hi = 0, len(text)
    while lo < hi:
        mid = (lo + hi + 1) // 2
        cand = text[:mid].rstrip() + ell
        if _text_width(font, cand) <= max_w:
            lo = mid
        else:
            hi = mid - 1
    return text[:lo].rstrip() + ell if lo > 0 else ell


class Button:
    def __init__(
        self,
        rect,
        label,
        fill=assets.UI_CARD2,
        fill_h=assets.GOLD,
        text_col=assets.PARCH_DARK,
        text_h=assets.INK,
        font=None,
        sub=None,
        sub_font=None,
    ):
        self.rect = pygame.Rect(rect)
        self.label = label
        self.fill = fill
        self.fill_h = fill_h
        self.text_col = text_col
        self.text_h = text_h
        self.font = font or assets.F["btn"]
        self.sub_font = sub_font
        self.sub = sub
        self.hovered = False
        self.disabled = False
        self._press_frame = 0  # brief flash on click

    def draw(self, surf):
        r = self.rect
        if self.disabled:
            col = darken(self.fill, 0.55)
            tcol = assets.DIM
            border = assets.UI_GROOVE
        elif self.hovered:
            col = self.fill_h
            tcol = self.text_h
            border = assets.GOLD2
        else:
            col = self.fill
            tcol = self.text_col
            border = assets.UI_BORDER

        # Drop shadow
        sh = alpha_surf(r.w + 3, r.h + 3, (0, 0, 0), 70)
        surf.blit(sh, (r.x + 2, r.y + 2))
        # Main face
        pygame.draw.rect(surf, col, r, border_radius=4)
        # Parchment texture + wood-grain overlay
        tex = getattr(assets, "TEX_PARCHMENT", None)
        if tex:
            btn_tex = pygame.Surface((r.w, r.h), pygame.SRCALPHA)
            for ty in range(0, r.h, tex.get_height()):
                for tx in range(0, r.w, tex.get_width()):
                    btn_tex.blit(tex, (tx, ty))
            btn_tex.set_alpha(12)
            surf.blit(btn_tex, r.topleft)
        gs = pygame.Surface((r.w, r.h), pygame.SRCALPHA)
        for y in range(0, r.h, 6):
            a = 6 if (y // 6) % 2 == 0 else 5
            pygame.draw.line(gs, (255, 255, 255, a), (0, y), (r.w, y), 1)
        surf.blit(gs, r.topleft)
        # Emboss: bright top edge, dark bottom edge
        pygame.draw.line(
            surf, lighten(col, 1.7), (r.x + 2, r.y + 1), (r.right - 2, r.y + 1), 1
        )
        pygame.draw.line(
            surf,
            darken(col, 0.5),
            (r.x + 2, r.bottom - 2),
            (r.right - 2, r.bottom - 2),
            1,
        )
        # Border
        pygame.draw.rect(surf, border, r, 1, border_radius=4)
        # Corner brackets on hover
        if self.hovered and not self.disabled:
            draw_corner_brackets(surf, r, assets.GOLD2, size=5, width=1)
        # Text — fit inside rect (fonts scale with window; fixed pixel rects overflow otherwise)
        pad = max(3, min(10, r.w // 48 + 2))
        max_tw = max(0, r.w - 2 * pad)
        sub_font = self.sub_font or assets.F["small"]
        main = _truncate_to_width(self.font, self.label, max_tw)
        ts = self.font.render(main, True, tcol)
        if self.sub:
            sub_t = _truncate_to_width(
                sub_font,
                self.sub,
                max_tw,
            )
            ss = sub_font.render(
                sub_t, True, lighten(tcol, 0.8) if not self.disabled else assets.DIM
            )
            fh = ts.get_height()
            gap = max(2, min(6, r.h // 12))
            sh = ss.get_height()
            total = fh + gap + sh
            top = r.centery - total // 2
            if top < r.y + pad:
                top = r.y + pad
            if top + total > r.bottom - pad:
                top = max(r.y + pad, r.bottom - pad - total)
            tr = ts.get_rect(centerx=r.centerx, top=top)
            sr = ss.get_rect(centerx=r.centerx, top=top + fh + gap)
        else:
            tr = ts.get_rect(center=r.center)
            if tr.height > r.h - 2 * pad:
                tr.centery = r.centery
            tr.clamp_ip(r.inflate(-pad, -pad))
        ts_sh = self.font.render(main, True, darken(col, 0.3))
        old_clip = surf.get_clip()
        clip_inner = r.inflate(-2, -2)
        surf.set_clip(clip_inner if clip_inner.w > 0 and clip_inner.h > 0 else r)
        try:
            surf.blit(ts_sh, tr.move(1, 1))
            surf.blit(ts, tr)
            if self.sub:
                surf.blit(ss, sr)
        finally:
            surf.set_clip(old_clip)

    def handle(self, event):
        if event.type == pygame.MOUSEMOTION:
            self.hovered = self.rect.collidepoint(event.pos)
        if event.type == pygame.MOUSEBUTTONDOWN and event.button == 1:
            if self.rect.collidepoint(event.pos) and not self.disabled:
                return True
        return False
