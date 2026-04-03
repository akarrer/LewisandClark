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
    ):
        self.rect = pygame.Rect(rect)
        self.label = label
        self.fill = fill
        self.fill_h = fill_h
        self.text_col = text_col
        self.text_h = text_h
        self.font = font or assets.F["btn"]
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
        for i in range(0, r.w + r.h, 10):
            pygame.draw.line(gs, (255, 255, 255, 6), (i, 0), (max(0, i - r.h), r.h))
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
        # Text
        ts = self.font.render(self.label, True, tcol)
        tr = ts.get_rect(center=r.center)
        if self.sub:
            tr.centery = r.centery - 7
        # Subtle text shadow
        ts_sh = self.font.render(self.label, True, darken(col, 0.3))
        surf.blit(ts_sh, tr.move(1, 1))
        surf.blit(ts, tr)
        if self.sub:
            ss = assets.F["tiny"].render(
                self.sub, True, lighten(tcol, 0.8) if not self.disabled else assets.DIM
            )
            surf.blit(ss, ss.get_rect(centerx=r.centerx, top=r.centery + 5))

    def handle(self, event):
        if event.type == pygame.MOUSEMOTION:
            self.hovered = self.rect.collidepoint(event.pos)
        if event.type == pygame.MOUSEBUTTONDOWN and event.button == 1:
            if self.rect.collidepoint(event.pos) and not self.disabled:
                return True
        return False
