"""Scrollable journal-style text panel."""

from __future__ import annotations

import pygame

from lewis_clark import assets
from lewis_clark.drawing import (
    alpha_surf,
    darken,
    draw_corner_brackets,
    lighten,
)


class ScrollPanel:
    """Scrollable text panel — aged vellum paper, ruled ink lines."""

    def __init__(self, rect, bg=assets.UI_PANEL, border=assets.UI_BORDER):
        self.rect = pygame.Rect(rect)
        self.bg = bg
        self.border = border
        self.lines = []
        self.scroll = 0
        self.content_h = 0
        self._items = []
        self._dirty = True

    def set_lines(self, lines):
        self.lines = lines
        self.scroll = 0
        self._dirty = True

    def _render(self):
        pad = 10
        w = self.rect.w - 2 * pad - 10
        y = pad
        items = []
        for text, font, colour in self.lines:
            words = text.split()
            line = ""
            for word in words:
                test = (line + " " + word).strip()
                if font.size(test)[0] <= w:
                    line = test
                else:
                    if line:
                        items.append((line, font, colour, y))
                        y += font.get_height() + 2
                    line = word
            if line:
                items.append((line, font, colour, y))
                y += font.get_height() + 5
        self.content_h = y + pad
        self._items = items
        self._dirty = False

    def draw(self, surf):
        if self._dirty:
            self._render()
        r = self.rect
        sh = alpha_surf(r.w + 3, r.h + 3, (0, 0, 0), 90)
        surf.blit(sh, (r.x + 2, r.y + 2))
        paper_col = (28, 18, 7)
        pygame.draw.rect(surf, paper_col, r, border_radius=3)
        for li in range(0, r.h, 14):
            pygame.draw.line(
                surf, (36, 24, 10), (r.x + 6, r.y + li), (r.right - 6, r.y + li), 1
            )
        pygame.draw.line(
            surf, (60, 30, 10), (r.x + 22, r.y + 4), (r.x + 22, r.bottom - 4), 1
        )
        clip_r = pygame.Rect(r.x + 1, r.y + 1, r.w - 2, r.h - 2)
        old_clip = surf.get_clip()
        surf.set_clip(clip_r)
        for text, font, colour, y in self._items:
            sy = r.y + y - self.scroll
            if sy > r.bottom:
                break
            if sy > r.y - font.get_height():
                ts_sh = font.render(text, True, (0, 0, 0))
                surf.blit(ts_sh, (r.x + 26, sy + 1))
                ts = font.render(text, True, colour)
                surf.blit(ts, (r.x + 25, sy))
        surf.set_clip(old_clip)
        pygame.draw.rect(surf, self.border, r, 1, border_radius=3)
        pygame.draw.rect(
            surf, darken(self.border, 0.5), r.inflate(1, 1), 1, border_radius=3
        )
        pygame.draw.line(
            surf,
            lighten(paper_col, 1.8),
            (r.x + 2, r.y + 1),
            (r.right - 2, r.y + 1),
            1,
        )
        if self.content_h > r.h:
            bar_h = max(18, int(r.h**2 / self.content_h))
            bar_y = int(self.scroll / max(1, self.content_h - r.h) * (r.h - bar_h))
            bar_r = pygame.Rect(r.right - 6, r.y + bar_y + 2, 4, bar_h - 4)
            pygame.draw.rect(surf, assets.UI_CARD3, bar_r, border_radius=2)
            pygame.draw.rect(surf, assets.UI_BORD_HI, bar_r, 1, border_radius=2)
        draw_corner_brackets(surf, r, assets.UI_BORD_HI, size=6, width=1)

    def handle(self, event):
        if event.type == pygame.MOUSEWHEEL:
            if self.rect.collidepoint(pygame.mouse.get_pos()):
                max_scroll = max(0, self.content_h - self.rect.h)
                self.scroll = max(0, min(max_scroll, self.scroll - event.y * 16))
