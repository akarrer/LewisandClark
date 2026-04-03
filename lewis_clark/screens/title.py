"""Title screen."""

from __future__ import annotations

import math
import random

import pygame
from lewis_clark import assets
from lewis_clark.drawing import (
    draw_text,
)
from lewis_clark.ui.button import Button


class TitleScreen:
    def __init__(self, on_start, on_load):
        self.on_start = on_start
        self.on_load = on_load
        self.frame = 0
        self.start_btn = Button(
            (assets.SW // 2 - 160, assets.SH - 180, 320, 54),
            "⚑  BEGIN EXPEDITION  ⚑",
            fill=assets.GOLD,
            fill_h=assets.GOLD2,
            text_col=assets.INK,
            text_h=assets.INK,
            font=assets.F["btn_lg"],
        )
        self.load_btn = Button(
            (assets.SW // 2 - 120, assets.SH - 112, 240, 38),
            "Load Saved Expedition",
            fill=assets.UI_CARD2,
            text_col=assets.PARCH_DARK,
        )

    def draw(self, surf):
        f = self.frame
        t = f * 0.018
        self.frame += 1
        W, H = assets.SW, assets.SH

        # ── Parallax sky ─────────────────────────────────────────────────────
        for i in range(int(H * 0.62)):
            frac = i / (H * 0.62)
            r = int(12 + frac * 20)
            g = int(9 + frac * 14)
            b = int(5 + frac * 8)
            pygame.draw.line(surf, (r, g, b), (0, i), (W, i))

        # Stars
        rng7 = random.Random(42)
        for _ in range(130):
            sx7, sy7 = rng7.randint(0, W), rng7.randint(0, int(H * 0.40))
            bv9 = rng7.randint(60, 150)
            tw8 = int(math.sin(t * 2.5 + sx7 * 0.1) * 20)
            bv10 = max(20, min(200, bv9 + tw8))
            pygame.draw.circle(surf, (bv10, bv10, int(bv10 * 0.85)), (sx7, sy7), 1)

        # Moon
        mx4, my4 = int(W * 0.80), int(H * 0.14)
        pygame.draw.circle(surf, (216, 204, 160), (mx4, my4), 38)
        pygame.draw.circle(surf, (18, 18, 24), (mx4 + 14, my4 - 20), 26)

        # Parallax layers
        pan1 = int(math.sin(t * 0.12) * 8)
        for mxf, myf, mwf, mc in [
            (0.82, 0.30, 0.18, (20, 16, 8)),
            (0.60, 0.26, 0.16, (16, 16, 8)),
            (0.38, 0.28, 0.14, (20, 16, 8)),
            (0.18, 0.24, 0.12, (16, 16, 8)),
        ]:
            mx5 = (mxf + pan1 / W) * W
            my5 = myf * H
            mw5 = mwf * W
            pygame.draw.polygon(
                surf,
                mc,
                [
                    (int(mx5 - mw5), int(H * 0.62)),
                    (int(mx5), int(my5)),
                    (int(mx5 + mw5), int(H * 0.62)),
                ],
            )

        # River valley + foreground
        pan2 = int(math.sin(t * 0.18) * 12)
        riv_pts = [(0, H)]
        for rx2 in range(0, W + 8, 8):
            ry2 = int(
                H * 0.58
                + math.sin((rx2 + pan2) * 0.008) * 18
                + math.sin((rx2 + pan2) * 0.022) * 8
            )
            riv_pts.append((rx2, ry2))
        riv_pts.append((W, H))
        pygame.draw.polygon(surf, (26, 44, 16), riv_pts)
        # River shimmer
        for ri6 in range(int(H * 0.60), int(H * 0.66)):
            sh6 = math.sin(ri6 * 0.12 + t * 2) * 0.35 + 0.55
            pygame.draw.line(
                surf,
                (int(16 + sh6 * 20), int(30 + sh6 * 14), int(40 + sh6 * 12)),
                (0, ri6),
                (W, ri6),
            )
        pan3 = int(math.sin(t * 0.25) * 16)
        fg_pts = [(0, H)]
        for rx3 in range(0, W + 8, 8):
            ry3 = int(
                H * 0.68
                + math.sin((rx3 + pan3) * 0.012) * 12
                + math.sin((rx3 + pan3) * 0.03) * 6
            )
            fg_pts.append((rx3, ry3))
        fg_pts.append((W, H))
        pygame.draw.polygon(surf, (14, 24, 8), fg_pts)

        # Campfire
        fgx, fgy = int(W * 0.22), int(H * 0.70)
        for gr2 in range(5, 0, -1):
            gs2 = pygame.Surface((gr2 * 28, gr2 * 18), pygame.SRCALPHA)
            pygame.draw.ellipse(
                gs2, (24 + gr2 * 8, 12 + gr2 * 4, 2, 50), (0, 0, gr2 * 28, gr2 * 18)
            )
            surf.blit(gs2, (fgx - gr2 * 14, fgy - gr2 * 8))
        for fi7 in range(4):
            fof4 = fi7 * 6 - 9
            flk4 = int(math.sin(t * 7 + fi7) * 5)
            pygame.draw.ellipse(
                surf, (208, 112, 16), (fgx + fof4 - 5 + flk4, fgy - 20, 10, 14)
            )
            pygame.draw.ellipse(
                surf, (240, 208, 32), (fgx + fof4 - 3 + flk4, fgy - 28, 6, 12)
            )
        pygame.draw.line(surf, (26, 18, 8), (fgx - 20, fgy + 2), (fgx + 20, fgy - 4), 5)
        pygame.draw.line(surf, (26, 18, 8), (fgx - 15, fgy - 4), (fgx + 25, fgy + 2), 5)
        for fx5, fy7, c6 in [
            (fgx - 50, fgy - 5, (10, 14, 8)),
            (fgx + 42, fgy - 8, (10, 14, 8)),
            (fgx - 18, fgy - 12, (12, 16, 8)),
        ]:
            pygame.draw.circle(surf, c6, (fx5, fy7 - 8), 6)
            pygame.draw.rect(surf, c6, (fx5 - 8, fy7 - 2, 16, 14))

        # Keelboat silhouette
        bx5 = int(W * 0.65 - (f * 0.5) % W)
        by5 = int(H * 0.615)
        pygame.draw.polygon(
            surf,
            (8, 12, 8),
            [
                (bx5 - 55, by5),
                (bx5 - 38, by5 - 12),
                (bx5 + 55, by5 - 12),
                (bx5 + 62, by5),
            ],
        )
        pygame.draw.line(surf, (12, 16, 8), (bx5 + 8, by5 - 12), (bx5 + 8, by5 - 52), 3)
        for fi8 in range(4):
            fx6 = bx5 + 8 + fi8 * 10
            fy8 = by5 - 52 + fi8 * 2 + int(math.sin(t * 4 + fi8 * 0.8) * 4)
            pygame.draw.line(
                surf,
                (106, 12, 14) if fi8 % 2 == 0 else (160, 144, 112),
                (bx5 + 8, by5 - 52),
                (fx6 + 10, fy8),
                2,
            )

        # ── Title text ────────────────────────────────────────────────────────
        rule_y = int(H * 0.28)
        pygame.draw.line(
            surf, assets.PARCH_EDGE, (W // 2 - 220, rule_y), (W // 2 + 220, rule_y), 1
        )
        for ox in [-220, 220]:
            pygame.draw.polygon(
                surf,
                assets.GOLD,
                [
                    (W // 2 + ox, rule_y),
                    (W // 2 + ox + 8, rule_y - 4),
                    (W // 2 + ox + 16, rule_y),
                    (W // 2 + ox + 8, rule_y + 4),
                ],
            )

        title_y = int(H * 0.32)
        ts7 = assets.F["huge"].render("LEWIS & CLARK", True, assets.INK)
        surf.blit(ts7, ts7.get_rect(centerx=W // 2 + 2, top=title_y + 2))
        ts8 = assets.F["huge"].render("LEWIS & CLARK", True, assets.GOLD)
        surf.blit(ts8, ts8.get_rect(centerx=W // 2, top=title_y))

        sub_y = title_y + 58
        ts9 = assets.F["display"].render("EXPEDITION", True, assets.INK)
        surf.blit(ts9, ts9.get_rect(centerx=W // 2 + 2, top=sub_y + 2))
        ts10 = assets.F["display"].render("EXPEDITION", True, assets.GOLD2)
        surf.blit(ts10, ts10.get_rect(centerx=W // 2, top=sub_y))

        tag_y = sub_y + 52
        pygame.draw.line(
            surf,
            assets.PARCH_EDGE,
            (W // 2 - 160, tag_y - 8),
            (W // 2 + 160, tag_y - 8),
            1,
        )
        draw_text(
            surf,
            "Corps of Discovery  ·  1804–1806",
            assets.F["year"],
            assets.PARCH_EDGE,
            (W // 2, tag_y + 4),
            anchor="midtop",
        )
        pygame.draw.line(
            surf,
            assets.PARCH_EDGE,
            (W // 2 - 160, tag_y + 22),
            (W // 2 + 160, tag_y + 22),
            1,
        )

        if f > 80:
            alpha3 = min(255, (f - 80) * 6)
            qa = min(255, alpha3)
            qc = (
                max(0, int(106 * qa / 255)),
                max(0, int(80 * qa / 255)),
                max(0, int(40 * qa / 255)),
            )
            draw_text(
                surf,
                '"The object of your mission is to explore the Missouri River..."',
                assets.F["body_i"],
                qc,
                (W // 2, tag_y + 44),
                anchor="midtop",
            )
            draw_text(
                surf,
                "— President Thomas Jefferson, 1803",
                assets.F["tiny"],
                qc,
                (W // 2, tag_y + 64),
                anchor="midtop",
            )

        self.start_btn.draw(surf)
        self.load_btn.draw(surf)

    def handle(self, event, on_start, on_load):
        if self.start_btn.handle(event):
            on_start()
        if self.load_btn.handle(event):
            on_load()


# ═══════════════════════════════════════════════════════════════════════════════
#  GAME SCREEN
