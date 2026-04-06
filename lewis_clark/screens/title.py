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
        self._sparks: list[list] = []
        self._shooting_stars: list[list] = []
        self._spark_rng = random.Random(0)
        self.start_btn = Button(
            (assets.SW // 2 - 160, assets.SH - 180, 320, 54),
            "\u2691  BEGIN EXPEDITION  \u2691",
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
        self.on_resize()

    def on_resize(self):
        W, H = assets.SW, assets.SH
        us = getattr(assets, "UI_SCALE", 1.0)

        def sz(n: float) -> int:
            return max(1, int(round(n * us)))

        self.start_btn.rect = pygame.Rect(
            W // 2 - sz(160), H - sz(180), sz(320), sz(54)
        )
        self.load_btn.rect = pygame.Rect(W // 2 - sz(120), H - sz(112), sz(240), sz(38))

    def draw(self, surf):
        f = self.frame
        t = f * 0.018
        self.frame += 1
        W, H = assets.SW, assets.SH

        title_bg = getattr(assets, "IMG_TITLE_BG", None)
        if title_bg is not None:
            if title_bg.get_size() != (W, H):
                title_bg = pygame.transform.smoothscale(title_bg, (W, H))
            surf.blit(title_bg, (0, 0))
        else:
            # ── Parallax sky ─────────────────────────────────────────────────
            for i in range(int(H * 0.62)):
                frac = i / (H * 0.62)
                r = int(10 + frac * 18)
                g = int(7 + frac * 12)
                b = int(4 + frac * 8)
                pygame.draw.line(surf, (r, g, b), (0, i), (W, i))

        # ── Aurora borealis ──────────────────────────────────────────────────
        aurora_s = pygame.Surface((W, int(H * 0.35)), pygame.SRCALPHA)
        for band in range(5):
            band_y_base = int(H * (0.06 + band * 0.05))
            for x in range(0, W, 4):
                wave = math.sin(x * 0.005 + t * 0.8 + band * 1.2) * 25
                wave += math.sin(x * 0.012 + t * 0.5 + band * 0.7) * 12
                by = int(band_y_base + wave)
                bh = int(15 + math.sin(x * 0.008 + t + band) * 8)
                if band < 2:
                    col = (20, 80 + band * 20, 40, 34)
                elif band < 4:
                    col = (15, 60, 80 + band * 10, 30)
                else:
                    col = (50, 20, 60, 26)
                pygame.draw.rect(aurora_s, col, (x, by, 5, bh))
        surf.blit(aurora_s, (0, 0))

        # ── Stars with diffraction spikes ────────────────────────────────────
        rng7 = random.Random(42)
        for si in range(160):
            sx7 = rng7.randint(0, W)
            sy7 = rng7.randint(0, int(H * 0.42))
            bv9 = rng7.randint(60, 180)
            tw8 = int(math.sin(t * 2.5 + sx7 * 0.1 + sy7 * 0.07) * 25)
            bv10 = max(20, min(220, bv9 + tw8))

            if si < 8:
                spike_len = rng7.randint(3, 6)
                sc = (bv10, bv10, int(bv10 * 0.85))
                pygame.draw.circle(surf, sc, (sx7, sy7), 2)
                for dx, dy in [
                    (spike_len, 0),
                    (-spike_len, 0),
                    (0, spike_len),
                    (0, -spike_len),
                ]:
                    spike_s = pygame.Surface(
                        (abs(dx) * 2 + 3, abs(dy) * 2 + 3), pygame.SRCALPHA
                    )
                    scx, scy = abs(dx) + 1, abs(dy) + 1
                    pygame.draw.line(
                        spike_s,
                        (*sc, 100),
                        (scx, scy),
                        (scx + dx, scy + dy),
                        1,
                    )
                    surf.blit(spike_s, (sx7 - abs(dx) - 1, sy7 - abs(dy) - 1))
            else:
                pygame.draw.circle(
                    surf,
                    (bv10, bv10, int(bv10 * 0.85)),
                    (sx7, sy7),
                    1,
                )

        # ── Shooting stars ───────────────────────────────────────────────────
        if f % 180 < 2 and self._spark_rng.random() < 0.5:
            sx = self._spark_rng.randint(W // 4, W * 3 // 4)
            sy = self._spark_rng.randint(0, int(H * 0.25))
            self._shooting_stars.append([sx, sy, 4.0, 2.5, 30])
        alive_ss = []
        for ss in self._shooting_stars:
            ss[0] += ss[2]
            ss[1] += ss[3]
            ss[4] -= 1
            if ss[4] > 0:
                alpha = min(255, ss[4] * 8)
                trail_s = pygame.Surface((20, 4), pygame.SRCALPHA)
                pygame.draw.line(
                    trail_s,
                    (255, 255, 220, alpha),
                    (0, 2),
                    (18, 2),
                    2,
                )
                surf.blit(trail_s, (int(ss[0]) - 18, int(ss[1]) - 2))
                pygame.draw.circle(
                    surf,
                    (255, 255, 240),
                    (int(ss[0]), int(ss[1])),
                    2,
                )
                alive_ss.append(ss)
        self._shooting_stars = alive_ss

        # Moon
        mx4, my4 = int(W * 0.80), int(H * 0.14)
        moon_glow = pygame.Surface((100, 100), pygame.SRCALPHA)
        for gr in range(45, 0, -3):
            a = int((1.0 - gr / 45.0) * 15)
            pygame.draw.circle(moon_glow, (200, 190, 150, a), (50, 50), gr)
        surf.blit(moon_glow, (mx4 - 50, my4 - 50))
        pygame.draw.circle(surf, (216, 204, 160), (mx4, my4), 38)
        pygame.draw.circle(surf, (18, 18, 24), (mx4 + 14, my4 - 20), 26)

        # Parallax mountain layers
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

        # ── Atmospheric fog layers ───────────────────────────────────────────
        fog_s = pygame.Surface((W, int(H * 0.12)), pygame.SRCALPHA)
        for fy in range(fog_s.get_height()):
            fog_alpha = int(math.sin(fy / fog_s.get_height() * math.pi) * 18)
            if fog_alpha > 0:
                x_off = int(math.sin(t * 0.3 + fy * 0.02) * 30)
                pygame.draw.line(
                    fog_s,
                    (140, 160, 170, fog_alpha),
                    (x_off, fy),
                    (W + x_off, fy),
                )
        surf.blit(fog_s, (0, int(H * 0.52)))

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

        for ri6 in range(int(H * 0.60), int(H * 0.66)):
            sh6 = math.sin(ri6 * 0.12 + t * 2) * 0.35 + 0.55
            moon_ref = max(0, 1.0 - abs(ri6 - H * 0.62) / (H * 0.03))
            ref_r = int(16 + sh6 * 20 + moon_ref * 15)
            ref_g = int(30 + sh6 * 14 + moon_ref * 12)
            ref_b = int(40 + sh6 * 12 + moon_ref * 8)
            pygame.draw.line(
                surf,
                (min(255, ref_r), min(255, ref_g), min(255, ref_b)),
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

        # ── Campfire with spark particles ────────────────────────────────────
        fgx, fgy = int(W * 0.22), int(H * 0.70)

        glow_s = pygame.Surface((180, 120), pygame.SRCALPHA)
        for gr2 in range(6, 0, -1):
            glow_a = int(15 + gr2 * 6 + math.sin(t * 5) * 4)
            pygame.draw.ellipse(
                glow_s,
                (40 + gr2 * 12, 20 + gr2 * 6, 4, min(255, glow_a)),
                (90 - gr2 * 15, 60 - gr2 * 10, gr2 * 30, gr2 * 20),
            )
        surf.blit(glow_s, (fgx - 90, fgy - 60))

        for fi7 in range(5):
            fof4 = fi7 * 5 - 10
            flk4 = int(math.sin(t * 8 + fi7 * 1.2) * 4)
            flame_h = 14 + int(math.sin(t * 6 + fi7) * 3)
            pygame.draw.ellipse(
                surf,
                (220, 120, 16),
                (fgx + fof4 - 4 + flk4, fgy - 18 - flame_h // 2, 8, flame_h),
            )
            pygame.draw.ellipse(
                surf,
                (245, 215, 40),
                (fgx + fof4 - 2 + flk4, fgy - 24 - flame_h // 3, 5, flame_h - 4),
            )
            if fi7 == 2:
                pygame.draw.ellipse(
                    surf,
                    (255, 250, 200),
                    (fgx + fof4 - 1 + flk4, fgy - 28, 3, 8),
                )

        pygame.draw.line(surf, (26, 18, 8), (fgx - 20, fgy + 2), (fgx + 20, fgy - 4), 5)
        pygame.draw.line(surf, (26, 18, 8), (fgx - 15, fgy - 4), (fgx + 25, fgy + 2), 5)

        rng_s = self._spark_rng
        if rng_s.random() < 0.6:
            self._sparks.append(
                [
                    fgx + rng_s.randint(-8, 8),
                    fgy - 20,
                    rng_s.uniform(-0.5, 0.5),
                    rng_s.uniform(-2.0, -4.0),
                    rng_s.randint(20, 50),
                    rng_s.uniform(1.0, 2.5),
                ]
            )
        alive_sparks = []
        for sp in self._sparks:
            sp[0] += sp[2]
            sp[1] += sp[3]
            sp[3] += 0.03
            sp[4] -= 1
            if sp[4] > 0:
                sa = min(255, sp[4] * 6)
                sc = (
                    min(255, 220 + int(sp[5] * 15)),
                    min(255, int(100 + sp[4] * 2)),
                    min(255, int(sp[4] * 1.5)),
                )
                spark_s = pygame.Surface((4, 4), pygame.SRCALPHA)
                pygame.draw.circle(
                    spark_s, (*sc, sa), (2, 2), max(1, int(sp[5] * sp[4] / 30))
                )
                surf.blit(spark_s, (int(sp[0]) - 2, int(sp[1]) - 2))
                alive_sparks.append(sp)
        self._sparks = alive_sparks

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

        # ── Title text with decorative flourishes ────────────────────────────
        rule_y = int(H * 0.28)

        def _draw_flourish(surf, cx, cy, direction, col):
            """Decorative scrollwork curl."""
            pts = []
            for i in range(12):
                a = i * 0.5 * direction
                r_val = 4 + i * 0.8
                pts.append(
                    (
                        int(cx + math.cos(a) * r_val * direction),
                        int(cy + math.sin(a) * r_val * 0.5),
                    )
                )
            if len(pts) >= 2:
                pygame.draw.lines(surf, col, False, pts, 1)

        pygame.draw.line(
            surf,
            assets.PARCH_EDGE,
            (W // 2 - 240, rule_y),
            (W // 2 + 240, rule_y),
            1,
        )
        for ox in [-240, 240]:
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
        _draw_flourish(surf, W // 2 - 256, rule_y, -1, assets.PARCH_EDGE)
        _draw_flourish(surf, W // 2 + 256, rule_y, 1, assets.PARCH_EDGE)

        title_y = int(H * 0.32)
        ts7 = assets.F["huge"].render("LEWIS & CLARK", True, assets.INK)
        surf.blit(ts7, ts7.get_rect(centerx=W // 2 + 2, top=title_y + 2))
        ts8 = assets.F["huge"].render("LEWIS & CLARK", True, assets.GOLD)
        surf.blit(ts8, ts8.get_rect(centerx=W // 2, top=title_y))

        sub_y = title_y + ts8.get_height() + 4
        ts9 = assets.F["display"].render("EXPEDITION", True, assets.INK)
        surf.blit(ts9, ts9.get_rect(centerx=W // 2 + 2, top=sub_y + 2))
        ts10 = assets.F["display"].render("EXPEDITION", True, assets.GOLD2)
        surf.blit(ts10, ts10.get_rect(centerx=W // 2, top=sub_y))

        tag_y = sub_y + ts10.get_height() + 8

        pygame.draw.line(
            surf,
            assets.PARCH_EDGE,
            (W // 2 - 180, tag_y - 8),
            (W // 2 + 180, tag_y - 8),
            1,
        )
        _draw_flourish(surf, W // 2 - 180, tag_y - 8, -1, assets.GOLD_DIM)
        _draw_flourish(surf, W // 2 + 180, tag_y - 8, 1, assets.GOLD_DIM)

        draw_text(
            surf,
            "Corps of Discovery  \u00b7  1804\u20131806",
            assets.F["year"],
            assets.PARCH_EDGE,
            (W // 2, tag_y + 4),
            anchor="midtop",
        )
        pygame.draw.line(
            surf,
            assets.PARCH_EDGE,
            (W // 2 - 180, tag_y + 24),
            (W // 2 + 180, tag_y + 24),
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
                "\u2014 President Thomas Jefferson, 1803",
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
