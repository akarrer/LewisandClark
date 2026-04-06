"""Intro cinematic."""

from __future__ import annotations

import math
import random

import pygame
from lewis_clark import assets
from lewis_clark.drawing import (
    blend,
    darken,
    draw_text,
    lighten,
)
from lewis_clark.ui.button import Button


def _wrap_lines_pixel(font, text: str, max_w: int) -> list[str]:
    """Word-wrap *text* to lines no wider than *max_w* pixels (matches :func:`draw_text` logic)."""
    if max_w <= 0:
        return []
    stripped = text.strip()
    if not stripped:
        return []
    lines: list[str] = []
    line = ""
    for w in stripped.split():
        test = (line + " " + w).strip()
        if font.size(test)[0] <= max_w:
            line = test
        else:
            if line:
                lines.append(line)
            if font.size(w)[0] <= max_w:
                line = w
            else:
                # Single word wider than the pane — hard-break by characters
                chunk = ""
                for ch in w:
                    cand = chunk + ch
                    if font.size(cand)[0] <= max_w:
                        chunk = cand
                    else:
                        if chunk:
                            lines.append(chunk)
                        chunk = ch
                line = chunk
    if line:
        lines.append(line)
    return lines


class CinematicScreen:
    ART_W = int(assets.SW * 0.60)

    def __init__(self, on_done):
        self.on_done = on_done
        self.idx = 0
        self.cine_line = 0
        self.cine_char = 0
        self.pause = 0
        self.frame = 0
        self.next_btn = Button(
            (assets.SW * 3 // 5 + 120, assets.SH - 58, 180, 38),
            "NEXT  ▶",
            fill=assets.UI_CARD2,
            fill_h=assets.GOLD,
            text_col=assets.PARCH,
            text_h=assets.INK,
        )
        self.back_btn = Button(
            (assets.SW * 3 // 5 + 10, assets.SH - 58, 100, 38),
            "◀ BACK",
            fill=assets.UI_PANEL,
            text_col=assets.DIM2,
        )
        self.skip_btn = Button(
            (assets.SW - 90, assets.SH - 28, 78, 20),
            "Skip All",
            fill=assets.UI_BG,
            text_col=assets.DIM,
            font=assets.F["small"],
        )
        self.begin_btn = Button(
            (assets.SW * 3 // 5 + 50, assets.SH - 62, 280, 46),
            "⚑  BEGIN THE EXPEDITION  ⚑",
            fill=assets.GOLD,
            fill_h=assets.GOLD2,
            text_col=assets.INK,
            text_h=assets.INK,
            font=assets.F["btn_lg"],
        )
        self.on_resize()

    def on_resize(self):
        type(self).ART_W = int(assets.SW * 0.60)
        sw, sh = assets.SW, assets.SH
        us = getattr(assets, "UI_SCALE", 1.0)

        def sz(n: float) -> int:
            return max(1, int(round(n * us)))

        self.next_btn.rect = pygame.Rect(
            sw * 3 // 5 + sz(120), sh - sz(58), sz(180), sz(38)
        )
        self.back_btn.rect = pygame.Rect(
            sw * 3 // 5 + sz(10), sh - sz(58), sz(100), sz(38)
        )
        self.skip_btn.rect = pygame.Rect(sw - sz(90), sh - sz(28), sz(78), sz(20))
        self.begin_btn.rect = pygame.Rect(
            sw * 3 // 5 + sz(50), sh - sz(62), sz(280), sz(46)
        )

    @property
    def scene(self):
        return assets.CINE_SCENES[self.idx]

    def advance(self):
        if self.idx < len(assets.CINE_SCENES) - 1:
            self.idx += 1
            self.cine_line = 0
            self.cine_char = 0
            self.pause = 0

    def retreat(self):
        if self.idx > 0:
            self.idx -= 1
            self.cine_line = 0
            self.cine_char = 0
            self.pause = 0

    def draw(self, surf):
        sd = self.scene
        t = self.frame * 0.022
        self.frame += 1

        # ── Left: art panel ───────────────────────────────────────────────────
        art_surf = pygame.Surface((self.ART_W, assets.SH))
        self._draw_scene(art_surf, sd["id"], t)
        self._blit_scene_figure(art_surf, sd)
        surf.blit(art_surf, (0, 0))

        # Fade illustration into text column — avoids a harsh vertical band at ART_W (~60% screen).
        blend_w = min(36, max(10, self.ART_W // 5))
        grad = pygame.Surface((blend_w, assets.SH), pygame.SRCALPHA)
        bg = assets.UI_BG
        for bx in range(blend_w):
            t = (bx + 1) / blend_w
            a = int(85 * t)
            pygame.draw.line(grad, (*bg[:3], a), (bx, 0), (bx, assets.SH), 1)
        surf.blit(grad, (self.ART_W - blend_w, 0))

        # Accent border between art and text
        acc = sd["accent"]
        pygame.draw.rect(surf, acc, (self.ART_W, 0, 3, assets.SH))
        pygame.draw.rect(surf, darken(acc, 0.6), (self.ART_W + 3, 0, 1, assets.SH))

        # ── Right: text panel ─────────────────────────────────────────────────
        rx = self.ART_W + 20
        rw = assets.SW - rx - 12

        surf.fill(
            assets.UI_BG, (self.ART_W + 4, 0, assets.SW - self.ART_W - 4, assets.SH)
        )

        us = getattr(assets, "UI_SCALE", 1.0)

        def sz(n: float) -> int:
            return max(1, int(round(n * us)))

        # Bottom layout: nav row, gap, dedicated "Did you know" band
        nav_row_top = assets.SH - sz(58)
        fact_h = sz(100)
        fact_gap = sz(12)
        fact_top = nav_row_top - fact_gap - fact_h
        narr_bottom = fact_top - sz(8)

        # Year/location badge (large)
        badge_h = sz(40)
        badge_pad = sz(12)
        pygame.draw.rect(surf, acc, (rx, 16, rw - 8, badge_h), border_radius=3)
        badge_txt = f"{sd['year']}   ·   {sd['location']}"
        draw_text(
            surf,
            badge_txt,
            assets.F["subhead"],
            darken(acc, 0.2),
            (rx + badge_pad, 16 + badge_h // 2),
            anchor="midleft",
            max_w=rw - badge_pad * 2 - 8,
        )

        # Title
        ty = 16 + badge_h + sz(10)
        draw_text(
            surf,
            sd["title"],
            assets.F["cine"],
            assets.PARCH,
            (rx + 1, ty + 1),
            max_w=rw - 8,
        )
        draw_text(
            surf, sd["title"], assets.F["cine"], assets.PARCH, (rx, ty), max_w=rw - 8
        )
        title_line_y = ty + sz(46)
        pygame.draw.line(surf, acc, (rx, title_line_y), (rx + rw - 8, title_line_y), 2)

        # Narration: pixel-based wrap (character-count textwrap left ~1/4 pane unused with serif fonts)
        narr_font = assets.F["narr"]
        narr_max_w = rw - 8

        narr = sd["narration"]
        ny = title_line_y + sz(12)
        line_h = narr_font.get_height() + sz(4)
        prev_clip = surf.get_clip()
        narr_clip = pygame.Rect(rx, ny, rw - 8, max(0, narr_bottom - ny))
        if narr_clip.h > 0 and narr_clip.w > 0:
            surf.set_clip(narr_clip.clip(prev_clip))

        try:
            for li, line in enumerate(narr):
                if li < self.cine_line:
                    for wl in _wrap_lines_pixel(narr_font, line, narr_max_w):
                        draw_text(surf, wl, narr_font, assets.PARCH_DARK, (rx, ny))
                        ny += line_h
                    ny += sz(6)
                elif li == self.cine_line:
                    partial = line[: self.cine_char]
                    if partial:
                        for wl in _wrap_lines_pixel(narr_font, partial, narr_max_w):
                            draw_text(surf, wl, narr_font, assets.PARCH, (rx, ny))
                            ny += line_h
                    if self.cine_char % 20 < 11:
                        draw_text(surf, "▌", narr_font, acc, (rx + 2, ny))
                    break
        finally:
            surf.set_clip(prev_clip)

        # Dedicated "Did you know" band
        fact = sd.get("fact", "")
        if fact:
            fx = rx - 2
            fy2 = fact_top
            fw = rw - 6
            header_h = sz(22)
            fact_r = pygame.Rect(fx, fy2, fw, fact_h)
            pygame.draw.rect(surf, assets.UI_CARD, fact_r, border_radius=4)
            pygame.draw.rect(surf, acc, fact_r, 1, border_radius=4)
            badge2 = pygame.Rect(fx, fy2, fw, header_h)
            pygame.draw.rect(surf, acc, badge2, border_radius=4)
            draw_text(
                surf,
                "DID YOU KNOW",
                assets.F["subhead"],
                darken(acc, 0.2),
                (fx + sz(10), fy2 + header_h // 2),
                anchor="midleft",
            )
            body_top = fy2 + header_h + sz(6)
            draw_text(
                surf,
                fact,
                assets.F["body"],
                assets.GOLD,
                (fx + sz(8), body_top),
                max_w=fw - sz(16),
            )

        # Advance typewriter state
        if self.pause > 0:
            self.pause -= 1
        elif self.cine_line < len(narr):
            self.cine_char += 3
            if self.cine_char >= len(narr[self.cine_line]):
                self.cine_line += 1
                self.cine_char = 0
                self.pause = 20

        narr_done = self.cine_line >= len(narr)
        pulse_t = abs(math.sin(self.frame * 0.07))

        # Nav buttons — pulse primary when narration finished (replaces separate flashing text)
        if self.idx < len(assets.CINE_SCENES) - 1:
            saved_fill = self.next_btn.fill
            if narr_done:
                self.next_btn.fill = blend(
                    assets.UI_CARD2, assets.GOLD, 0.3 + pulse_t * 0.55
                )
            self.next_btn.draw(surf)
            self.next_btn.fill = saved_fill
            primary_btn = self.next_btn
        else:
            saved_fill = self.begin_btn.fill
            if narr_done:
                self.begin_btn.fill = blend(
                    assets.GOLD, assets.GOLD2, 0.15 + pulse_t * 0.75
                )
            self.begin_btn.draw(surf)
            self.begin_btn.fill = saved_fill
            primary_btn = self.begin_btn

        # Progress indicators — to the right of NEXT / BEGIN
        n_scenes = len(assets.CINE_SCENES)
        dot_s = sz(14)
        dot_gap = sz(6)
        total_dots_w = n_scenes * dot_s + max(0, n_scenes - 1) * dot_gap
        margin_right = sz(12)
        dot_x_end = assets.SW - margin_right
        dot_x_start = max(primary_btn.rect.right + sz(14), dot_x_end - total_dots_w)
        dot_y = primary_btn.rect.centery - dot_s // 2
        for di in range(n_scenes):
            dcol = (
                acc
                if di == self.idx
                else assets.PARCH_EDGE
                if di < self.idx
                else assets.UI_BORDER
            )
            dot_x2 = dot_x_start + di * (dot_s + dot_gap)
            pygame.draw.rect(surf, dcol, (dot_x2, dot_y, dot_s, dot_s), border_radius=3)

        if self.idx > 0:
            self.back_btn.draw(surf)
        self.skip_btn.draw(surf)

    def _blit_scene_figure(self, art_surf, sd):
        """Corner portrait for the scene speaker / focus (roster or cinematic-only figure)."""
        fk = sd.get("figure")
        if not fk:
            return
        ports = getattr(assets, "IMG_PORTRAITS", None) or {}
        figs = getattr(assets, "IMG_FIGURES", None) or {}
        im = ports.get(fk) or figs.get(fk)
        if im is None:
            return
        acc = sd["accent"]
        w, h = 64, 80
        sc = pygame.transform.scale(im, (w, h))
        art_surf.blit(sc, (12, 12))
        pygame.draw.rect(art_surf, darken(acc, 0.35), (12, 12, w, h), 2)

    def _draw_scene(self, surf, scene_id, t):
        """Draw the art scene (static 8-bit panel if present, else procedural fallback)."""
        W, H = surf.get_size()
        cine = getattr(assets, "IMG_CINEMATIC", None) or {}
        static = cine.get(scene_id)
        if static is not None:
            scaled = pygame.transform.scale(static, (W, H))
            surf.blit(scaled, (0, 0))
        else:
            dispatch = {
                "secret_message": self._scene_jefferson,
                "napoleon": self._scene_napoleon,
                "lewis_prepares": self._scene_lewis,
                "clark_recruited": self._scene_clark,
                "corps_assembled": self._scene_camp,
                "the_river": self._scene_river,
                "depart": self._scene_departure,
            }
            fn = dispatch.get(scene_id, self._scene_river)
            fn(surf, W, H, t)
        # Film grain
        if self.frame % 5 < 2:
            rng2 = random.Random(self.frame // 5)
            for _ in range(40):
                gx, gy = rng2.randint(0, W - 1), rng2.randint(0, H - 1)
                v2 = surf.get_at((gx, gy))
                surf.set_at((gx, gy), tuple(max(0, c - 20) for c in v2[:3]))
        # Border
        pygame.draw.rect(surf, assets.INK_LT, (0, 0, W, H), 3)

    # ── Scene helpers ─────────────────────────────────────────────────────────
    # ═══════════════════════════════════════════════════════════════════════════
    #  SCENE HELPERS
    # ═══════════════════════════════════════════════════════════════════════════
    def _sky_grad(self, surf, W, H, stops, h_end=None):
        if h_end is None:
            h_end = H
        n = len(stops)
        for y in range(h_end):
            seg = y / h_end * (n - 1)
            lo = int(seg)
            hi = min(n - 1, lo + 1)
            f2 = seg - lo
            col = tuple(
                min(255, max(0, int(stops[lo][i] + (stops[hi][i] - stops[lo][i]) * f2)))
                for i in range(3)
            )
            pygame.draw.line(surf, col, (0, y), (W, y))

    def _ground(self, surf, W, H, layers):
        for base_frac, col, freq, amp in layers:
            pts = [(0, H)]
            for x in range(0, W + 4, 4):
                y = int(
                    H * base_frac
                    + math.sin(x * freq) * amp
                    + math.sin(x * freq * 2.3) * amp * 0.4
                )
                pts.append((x, y))
            pts.append((W, H))
            pygame.draw.polygon(surf, col, pts)

    def _glow(self, surf, cx, cy, r_max, col, alpha_peak=120):
        """Soft radial glow using SRCALPHA surface."""
        gs = pygame.Surface((r_max * 2, r_max * 2), pygame.SRCALPHA)
        for r in range(r_max, 0, -2):
            a = int(alpha_peak * (1 - r / r_max) ** 1.8)
            pygame.draw.circle(gs, (*col, min(255, a)), (r_max, r_max), r)
        surf.blit(gs, (cx - r_max, cy - r_max), special_flags=pygame.BLEND_RGBA_ADD)

    def _flame(self, surf, cx, cy, t, seed=0, size=1.0):
        fk = int(math.sin(t * 7.2 + seed) * 4 * size)
        # Outer glow
        for r in range(int(28 * size), 2, -4):
            a = int(80 * (1 - r / (28 * size)) ** 1.5)
            gs = pygame.Surface((r * 2, r * 2), pygame.SRCALPHA)
            g_val = min(255, int(16 + (28 * size - r) * 3))
            pygame.draw.ellipse(
                gs, (g_val, g_val // 3, 2, a), (0, 0, r * 2, int(r * 1.3))
            )
            surf.blit(
                gs,
                (cx - r + fk, cy - int(r * 0.6)),
                special_flags=pygame.BLEND_RGBA_ADD,
            )
        # Candle body
        cw = max(3, int(5 * size))
        ch = max(14, int(24 * size))
        pygame.draw.rect(surf, (220, 210, 170), (cx - cw // 2, cy, cw, ch))
        pygame.draw.line(
            surf, (180, 160, 120), (cx - cw // 2, cy), (cx - cw // 2, cy + ch), 1
        )
        # Flame — three layers
        fw = max(4, int(8 * size))
        fh = max(10, int(18 * size))
        pygame.draw.ellipse(
            surf, (200, 90, 8), (cx - fw + fk, cy - fh, fw * 2, int(fh * 1.4))
        )
        pygame.draw.ellipse(
            surf, (240, 190, 20), (cx - fw // 2 + fk, cy - fh - 4, fw, fh)
        )
        pygame.draw.ellipse(
            surf, (255, 255, 200), (cx - 2 + fk, cy - fh - 8, 4, int(fh * 0.5))
        )

    def _campfire(self, surf, cx, cy, t, seed=0, size=1.2):
        """Full campfire with logs, coals, and tall flames."""
        # Coal bed glow
        for r in range(int(22 * size), 2, -3):
            a = int(90 * (1 - r / (22 * size)) ** 1.6)
            gs = pygame.Surface((r * 2, r * 2), pygame.SRCALPHA)
            pygame.draw.ellipse(gs, (200, 80, 4, a), (0, 0, r * 2, r))
            surf.blit(gs, (cx - r, cy - r // 2), special_flags=pygame.BLEND_RGBA_ADD)
        # Logs — two crossed
        lw = int(5 * size)
        pygame.draw.line(
            surf,
            (32, 18, 6),
            (cx - int(22 * size), cy + 2),
            (cx + int(22 * size), cy - 4),
            lw,
        )
        pygame.draw.line(
            surf,
            (28, 16, 4),
            (cx - int(18 * size), cy - 4),
            (cx + int(18 * size), cy + 2),
            lw,
        )
        pygame.draw.line(
            surf,
            (48, 28, 10),
            (cx - int(22 * size) + 2, cy + 1),
            (cx + int(22 * size) - 2, cy - 3),
            2,
        )
        # Multiple flame tongues
        for i, off in enumerate([-int(10 * size), 0, int(10 * size)]):
            fk2 = int(math.sin(t * 6 + i * 2.1 + seed) * 5 * size)
            fh2 = int((24 + i * 4) * size + math.sin(t * 5 + i) * 4)
            fw2 = max(4, int(7 * size))
            pygame.draw.ellipse(
                surf, (190, 80, 6), (cx + off - fw2 + fk2, cy - fh2, fw2 * 2, fh2 + 8)
            )
            pygame.draw.ellipse(
                surf,
                (230, 160, 18),
                (cx + off - fw2 // 2 + fk2, cy - fh2 + 4, fw2, fh2 - 4),
            )
            pygame.draw.ellipse(
                surf,
                (255, 230, 80),
                (cx + off - 2 + fk2, cy - fh2 + 8, 4, max(4, fh2 - 10)),
            )

    def _person_detailed(
        self,
        surf,
        cx,
        cy,
        scale,
        coat,
        skin,
        hat_col=(12, 10, 8),
        seated=False,
        facing=1,
        arm_up=False,
    ):
        """Richer person silhouette — coat, skin-tone head, hat detail."""
        s = scale
        # Shadow
        shw = int(18 * s)
        gs = pygame.Surface((shw * 2, 8), pygame.SRCALPHA)
        pygame.draw.ellipse(gs, (0, 0, 0, 60), (0, 0, shw * 2, 8))
        surf.blit(gs, (cx - shw, cy + 2))
        # Legs
        if not seated:
            for lx, la in [
                (cx - int(5 * s), int(28 * s)),
                (cx + int(5 * s), int(30 * s)),
            ]:
                pygame.draw.line(
                    surf, coat, (lx, cy), (lx + facing * 3, cy + la), max(2, int(7 * s))
                )
            # Boots
            for lx in [cx - int(5 * s), cx + int(5 * s)]:
                pygame.draw.ellipse(
                    surf,
                    (14, 10, 6),
                    (lx - int(4 * s), cy + int(24 * s), int(10 * s), int(6 * s)),
                )
        else:
            pygame.draw.line(
                surf,
                coat,
                (cx - int(4 * s), cy),
                (cx + facing * int(22 * s), cy + int(6 * s)),
                max(2, int(7 * s)),
            )
        # Coat/torso
        pygame.draw.polygon(
            surf,
            coat,
            [
                (cx - int(11 * s), cy),
                (cx - int(11 * s), cy - int(28 * s)),
                (cx, cy - int(30 * s)),
                (cx + int(11 * s), cy - int(28 * s)),
                (cx + int(11 * s), cy),
            ],
        )
        # Coat lapels / lighter front
        pygame.draw.polygon(
            surf,
            lighten(coat, 1.3),
            [
                (cx - int(4 * s), cy - int(28 * s)),
                (cx, cy - int(30 * s)),
                (cx + int(4 * s), cy - int(28 * s)),
                (cx, cy - int(10 * s)),
            ],
        )
        # Arms
        arm_y = cy - int(22 * s)
        if arm_up:
            pygame.draw.line(
                surf,
                coat,
                (cx + int(10 * s), arm_y),
                (cx + int(26 * s), arm_y - int(20 * s)),
                max(2, int(6 * s)),
            )
        else:
            pygame.draw.line(
                surf,
                coat,
                (cx - int(10 * s), arm_y),
                (cx - int(26 * s), arm_y + int(14 * s)),
                max(2, int(5 * s)),
            )
            pygame.draw.line(
                surf,
                coat,
                (cx + int(10 * s), arm_y),
                (cx + int(26 * s), arm_y + int(12 * s)),
                max(2, int(5 * s)),
            )
        # Cravat / white collar
        pygame.draw.polygon(
            surf,
            (220, 210, 190),
            [
                (cx - int(3 * s), cy - int(28 * s)),
                (cx, cy - int(26 * s)),
                (cx + int(3 * s), cy - int(28 * s)),
            ],
        )
        # Neck + head
        pygame.draw.line(
            surf,
            skin,
            (cx, cy - int(30 * s)),
            (cx, cy - int(38 * s)),
            max(2, int(5 * s)),
        )
        pygame.draw.circle(surf, skin, (cx, cy - int(44 * s)), int(10 * s))
        # Hair / wig detail
        pygame.draw.arc(
            surf,
            lighten(skin, 0.7),
            (cx - int(10 * s), cy - int(54 * s), int(20 * s), int(14 * s)),
            0,
            math.pi,
            2,
        )
        # Tricorn hat
        brim_w = int(16 * s)
        pygame.draw.polygon(
            surf,
            hat_col,
            [
                (cx - brim_w, cy - int(52 * s)),
                (cx, cy - int(68 * s)),
                (cx + brim_w, cy - int(52 * s)),
            ],
        )
        pygame.draw.rect(
            surf, hat_col, (cx - int(8 * s), cy - int(52 * s), int(16 * s), int(4 * s))
        )
        # Hat cockade
        pygame.draw.circle(
            surf, (160, 16, 16), (cx + brim_w - 4, cy - int(52 * s)), int(3 * s)
        )

    def _keelboat(self, surf, cx, cy, scale, t, flag_col=(136, 16, 16)):
        """Detailed keelboat with cabin, mast, rigging, flag."""
        s = scale
        hw = int(90 * s)
        hh = int(14 * s)
        # Hull shadow
        pygame.draw.ellipse(surf, (0, 0, 0), (cx - hw, cy, hw * 2, int(hh * 0.6)))
        # Hull
        hull_pts = [
            (cx - hw, cy),
            (cx - int(60 * s), cy - hh),
            (cx + hw, cy - hh),
            (cx + int(96 * s), cy),
        ]
        pygame.draw.polygon(surf, (22, 14, 6), hull_pts)
        pygame.draw.polygon(surf, (38, 22, 8), hull_pts, 2)
        # Waterline highlight
        pygame.draw.line(
            surf,
            (60, 80, 100),
            (cx - int(50 * s), cy - 1),
            (cx + int(70 * s), cy - 1),
            1,
        )
        # Cabin
        cab_x = cx - int(20 * s)
        cab_y = cy - hh
        cab_w = int(60 * s)
        cab_h = int(24 * s)
        pygame.draw.rect(surf, (30, 18, 8), (cab_x, cab_y - cab_h, cab_w, cab_h))
        pygame.draw.rect(surf, (48, 28, 10), (cab_x, cab_y - cab_h, cab_w, cab_h), 2)
        # Cabin windows (glowing amber)
        for wx2 in [cab_x + int(8 * s), cab_x + int(28 * s), cab_x + int(48 * s)]:
            pygame.draw.rect(
                surf,
                (180, 110, 16),
                (wx2, cab_y - cab_h + int(6 * s), int(10 * s), int(10 * s)),
            )
            pygame.draw.rect(
                surf,
                (80, 50, 6),
                (wx2, cab_y - cab_h + int(6 * s), int(10 * s), int(10 * s)),
                1,
            )
        # Mast
        mast_x = cx + int(8 * s)
        mast_top = cy - hh - int(80 * s)
        pygame.draw.line(
            surf, (26, 16, 6), (mast_x, cy - hh), (mast_x, mast_top), max(2, int(4 * s))
        )
        # Boom
        pygame.draw.line(
            surf,
            (26, 16, 6),
            (mast_x, mast_top + int(10 * s)),
            (mast_x - int(44 * s), mast_top + int(10 * s)),
            2,
        )
        # Rigging
        for rx2 in [cx - int(30 * s), cx + int(50 * s)]:
            pygame.draw.line(surf, (20, 14, 6), (mast_x, mast_top), (rx2, cy - hh), 1)
        # Animated flag
        flag_pts = []
        for fi in range(8):
            fx6 = mast_x + fi * int(5 * s)
            fy6 = mast_top + int(fi * 2 * s) + int(math.sin(t * 4 + fi * 0.7) * 4 * s)
            flag_pts.append((fx6, fy6))
        if len(flag_pts) >= 2:
            pygame.draw.lines(surf, flag_col, False, flag_pts, max(2, int(3 * s)))
        # Steering oar
        pygame.draw.line(
            surf,
            (28, 16, 6),
            (cx + int(70 * s), cy - int(6 * s)),
            (cx + int(96 * s), cy + int(10 * s)),
            max(2, int(3 * s)),
        )

    def _water_shimmer(self, surf, W, y_start, y_end, t, base_col, depth=True):
        """Animated water with shimmer and depth."""
        for yi in range(y_start, y_end):
            d = (yi - y_start) / (y_end - y_start)
            sh = (
                math.sin(yi * 0.08 + t * 2.2) * 0.3
                + math.sin(yi * 0.13 + t * 1.4) * 0.2
                + 0.5
            )
            if depth:
                r = min(255, max(0, int(base_col[0] * (0.6 + d * 0.4) + sh * 18)))
                g = min(255, max(0, int(base_col[1] * (0.6 + d * 0.4) + sh * 14)))
                b = min(255, max(0, int(base_col[2] * (0.8 + d * 0.2) + sh * 20)))
            else:
                r, g, b = (
                    min(255, max(0, int(base_col[i] + sh * 20))) for i in range(3)
                )
            pygame.draw.line(surf, (r, g, b), (0, yi), (W, yi))

    def _stone_wall(self, surf, W, H, base_col, light_x=None):
        """Detailed stone wall with mortar lines and candlelight wash."""
        for row in range(0, H, 22):
            offset = (row // 22) % 2 * 32
            for col in range(-offset, W + 48, 48):
                shade = 8 + (row // 22 + col // 48) % 7
                if light_x:
                    dist = abs(col + 24 - light_x) / W
                    shade = int(shade * (1.8 - dist * 1.4))
                r = min(255, max(0, int(base_col[0] * shade / 18)))
                g = min(255, max(0, int(base_col[1] * shade / 18)))
                b = min(255, max(0, int(base_col[2] * shade / 18)))
                stone_r = pygame.Rect(col + 1, row + 1, 46, 20)
                pygame.draw.rect(surf, (r, g, b), stone_r)
                # Mortar highlight top
                pygame.draw.line(
                    surf,
                    (min(255, r + 12), min(255, g + 8), min(255, b + 6)),
                    (stone_r.x, stone_r.y),
                    (stone_r.right, stone_r.y),
                    1,
                )
                # Mortar shadow left
                pygame.draw.line(
                    surf,
                    (max(0, r - 6), max(0, g - 4), max(0, b - 3)),
                    (stone_r.x, stone_r.y),
                    (stone_r.x, stone_r.bottom),
                    1,
                )

    def _curtain(self, surf, x, y, w, h, col, t, side="left"):
        """Heavy velvet curtain with folds."""
        fold_w = w // 5
        for i in range(5):
            fx = x + i * fold_w
            sway = int(math.sin(t * 0.4 + i * 0.8) * 3)
            c_shade = 0.7 + (i % 2) * 0.3
            c2 = tuple(min(255, int(v * c_shade)) for v in col)
            pts = [
                (fx + sway, y),
                (fx + fold_w // 2 + sway, y + h // 4),
                (fx + sway, y + h // 2),
                (fx + fold_w // 2 + sway, y + h * 3 // 4),
                (fx + sway, y + h),
            ]
            if i < 4:
                rect_pts = [
                    (fx + sway, y),
                    (fx + fold_w + sway, y),
                    (fx + fold_w, y + h),
                    (fx, y + h),
                ]
                pygame.draw.polygon(surf, c2, rect_pts)
            if i > 0:
                pygame.draw.lines(surf, darken(col, 0.4), False, pts, 2)
        # Valance
        pygame.draw.rect(surf, darken(col, 0.6), (x, y, w, int(h * 0.08)))
        pygame.draw.rect(surf, darken(col, 0.4), (x, y, w, int(h * 0.08)), 2)

    # ═══════════════════════════════════════════════════════════════════════════
    #  SCENE 1 — Jefferson's Secret Message
    #  Deep candlelit study. Focussed on the glowing document.
    # ═══════════════════════════════════════════════════════════════════════════
    def _scene_jefferson(self, surf, W, H, t):
        # Background — near-black
        surf.fill((8, 5, 3))

        # Stone walls with warm candlelight wash from right
        self._stone_wall(surf, W, H, (30, 20, 10), light_x=int(W * 0.78))

        # Large arched window left — night sky with stars and moon
        wx, wy = int(W * 0.07), 20
        ww, wh = int(W * 0.32), int(H * 0.66)
        # Window reveal (deep stone sill)
        pygame.draw.rect(surf, (18, 12, 6), (wx - 12, wy - 12, ww + 24, wh + 24))
        # Night sky
        pygame.draw.rect(surf, (4, 6, 16), (wx, wy, ww, wh))
        pygame.draw.ellipse(surf, (4, 6, 16), (wx, wy - ww // 2, ww, ww))
        # Stars — fixed seed so they don't flicker position
        rng3 = random.Random(99)
        for _ in range(60):
            sx9 = wx + rng3.randint(4, ww - 4)
            sy9 = wy + rng3.randint(4, int(wh * 0.80))
            bv = rng3.randint(80, 220)
            tw2 = int(math.sin(t * 2.4 + sx9 * 0.09) * 22)
            bv2 = max(30, min(240, bv + tw2))
            r2 = 1 if bv < 140 else 2
            pygame.draw.circle(
                surf, (bv2, bv2, min(255, int(bv2 * 0.88))), (sx9, sy9), r2
            )
        # Moon — crescent
        mx_w = wx + int(ww * 0.72)
        my_w = wy + int(wh * 0.18)
        pygame.draw.circle(surf, (210, 205, 155), (mx_w, my_w), 26)
        pygame.draw.circle(surf, (4, 6, 16), (mx_w + 16, my_w - 12), 20)
        # Window glazing bars
        pygame.draw.line(
            surf, (22, 16, 8), (wx + ww // 2, wy), (wx + ww // 2, wy + wh), 5
        )
        pygame.draw.line(
            surf, (22, 16, 8), (wx, wy + wh // 3), (wx + ww, wy + wh // 3), 4
        )
        pygame.draw.line(
            surf, (22, 16, 8), (wx, wy + wh * 2 // 3), (wx + ww, wy + wh * 2 // 3), 4
        )
        # Window frame
        pygame.draw.rect(surf, (32, 22, 10), (wx, wy, ww, wh), 4)
        pygame.draw.ellipse(surf, (32, 22, 10), (wx, wy - ww // 2, ww, ww), 4)

        # Heavy curtains framing window
        self._curtain(
            surf, wx - 12, wy - 12, int(W * 0.08), int(H * 0.75), (48, 12, 8), t, "left"
        )

        # Desk — rich mahogany, large and central
        dx = int(W * 0.35)
        dy = int(H * 0.60)
        dw = int(W * 0.62)
        # Desk shadow on floor
        gs_d = pygame.Surface((dw + 20, 28), pygame.SRCALPHA)
        pygame.draw.ellipse(gs_d, (0, 0, 0, 80), (0, 0, dw + 20, 28))
        surf.blit(gs_d, (dx - 10, dy + 18))
        # Desk surface — green baize top
        pygame.draw.rect(surf, (24, 36, 16), (dx, dy, dw, 20))
        pygame.draw.rect(surf, (38, 52, 24), (dx + 2, dy + 2, dw - 4, 16))
        # Desk front panel
        pygame.draw.rect(surf, (44, 24, 8), (dx, dy + 20, dw, 24))
        pygame.draw.rect(surf, (58, 34, 12), (dx, dy + 20, dw, 24), 2)
        # Decorative panel insets
        for px9 in [dx + 20, dx + dw // 2 - 30, dx + dw - 80]:
            pygame.draw.rect(surf, (52, 30, 10), (px9, dy + 23, 58, 16))
            pygame.draw.rect(surf, (68, 42, 14), (px9, dy + 23, 58, 16), 1)
        # Desk legs — turned
        for lx9 in [dx + 12, dx + dw - 12]:
            for seg in range(5):
                sw2 = 8 if seg % 2 == 0 else 12
                sy9b = dy + 44 + seg * 16
                pygame.draw.rect(surf, (36, 18, 6), (lx9 - sw2 // 2, sy9b, sw2, 14))

        # The DOCUMENT — hero prop, large and luminous
        doc_x = dx + int(dw * 0.18)
        doc_y = dy - int(H * 0.28)
        doc_w, doc_h = int(W * 0.24), int(H * 0.26)
        # Document glow on desk
        self._glow(surf, doc_x + doc_w // 2, doc_y + doc_h, doc_w, (200, 180, 80), 60)
        # Paper shadow
        pygame.draw.rect(surf, (4, 3, 2), (doc_x + 6, doc_y + 6, doc_w, doc_h))
        # Paper — aged parchment
        for yi in range(doc_h):
            frac = yi / doc_h
            r9 = int(232 - frac * 12)
            g9 = int(216 - frac * 18)
            b9 = int(110 - frac * 14)
            pygame.draw.line(
                surf, (r9, g9, b9), (doc_x, doc_y + yi), (doc_x + doc_w, doc_y + yi)
            )
        pygame.draw.rect(surf, (140, 100, 28), (doc_x, doc_y, doc_w, doc_h), 3)
        # Red wax seal — prominent
        seal_x = doc_x + doc_w - 30
        seal_y = doc_y + doc_h - 28
        pygame.draw.circle(surf, (80, 10, 10), (seal_x + 2, seal_y + 2), 18)
        pygame.draw.circle(surf, (180, 20, 20), (seal_x, seal_y), 18)
        pygame.draw.circle(surf, (200, 40, 40), (seal_x, seal_y), 18, 2)
        pygame.draw.circle(surf, (220, 80, 60), (seal_x - 6, seal_y - 6), 6)
        js9 = assets.F["subhead"].render("J", True, (220, 160, 40))
        surf.blit(js9, js9.get_rect(center=(seal_x, seal_y)))
        # CONFIDENTIAL stamp — red, diagonal
        cf9 = assets.F["header"].render("CONFIDENTIAL", True, (160, 24, 24))
        cf9r = pygame.transform.rotate(cf9, -12)
        surf.blit(cf9r, cf9r.get_rect(center=(doc_x + doc_w // 2, doc_y + doc_h // 2)))
        # Writing lines
        for li in range(14):
            lw9b = int(doc_w * 0.72) + random.Random(li * 7).randint(-20, 28)
            160 if li > self.frame // 4 % 14 else 220
            pygame.draw.line(
                surf,
                (58, 40, 8),
                (doc_x + 18, doc_y + 20 + li * 13),
                (doc_x + 18 + lw9b, doc_y + 20 + li * 13),
                1,
            )

        # Animated quill — writing
        qx9 = doc_x + int(doc_w * 0.68) + int(math.sin(t * 1.8) * 12)
        qy9 = doc_y + int(doc_h * 0.52) + int(math.cos(t * 1.8) * 8)
        # Quill shaft
        pygame.draw.line(surf, (200, 180, 60), (qx9, qy9), (qx9 - 52, qy9 + 80), 3)
        # Feather barbs
        for fi9 in range(9):
            frac = fi9 / 9
            fx9a = int(qx9 - frac * 48)
            fy9a = int(qy9 + frac * 74)
            fan = int((6 + fi9 * 2.5) * (1 - frac * 0.3))
            pygame.draw.line(
                surf, (180, 158, 38), (fx9a, fy9a), (fx9a - fan, fy9a - fan // 2), 1
            )
            pygame.draw.line(
                surf, (160, 138, 28), (fx9a, fy9a), (fx9a + fan // 2, fy9a - fan), 1
            )
        # Ink tip
        pygame.draw.circle(surf, (8, 6, 4), (qx9, qy9), 3)
        # Ink blot growing (animated)
        blot_r = max(1, int(abs(math.sin(t * 0.3)) * 4) + 1)
        pygame.draw.circle(surf, (12, 8, 4), (qx9 + 2, qy9 + 2), blot_r)

        # Inkwell
        iw_x = doc_x + int(doc_w * 0.88)
        iw_y = doc_y - 8
        pygame.draw.ellipse(surf, (8, 6, 4), (iw_x - 14, iw_y - 4, 28, 20))
        pygame.draw.ellipse(surf, (18, 12, 6), (iw_x - 14, iw_y - 4, 28, 20), 2)
        pygame.draw.ellipse(surf, (4, 4, 12), (iw_x - 10, iw_y, 20, 10))  # ink surface

        # Three candelabras — tall, ornate
        for cn_x, cn_y, cn_h in [
            (dx + int(dw * 0.06), dy - 58, 50),
            (dx + int(dw * 0.82), dy - 60, 52),
            (wx + ww + int(W * 0.07), int(H * 0.38), 44),
        ]:
            # Stand
            pygame.draw.line(
                surf, (60, 44, 16), (cn_x, cn_y + cn_h), (cn_x, cn_y + cn_h + 32), 4
            )
            pygame.draw.ellipse(
                surf, (52, 38, 14), (cn_x - 16, cn_y + cn_h + 28, 32, 10)
            )
            # Bobeche (wax catcher)
            pygame.draw.ellipse(surf, (64, 48, 18), (cn_x - 10, cn_y + cn_h - 4, 20, 8))
            # Three arms
            for arm_a in [-28, 0, 28]:
                arm_x = cn_x + int(math.sin(math.radians(arm_a)) * 14)
                self._flame(
                    surf, arm_x, cn_y + arm_a // 8, t, seed=cn_x + arm_a, size=0.9
                )

        # Jefferson — detailed seated silhouette
        jeff_x = dx + int(dw * 0.40)
        jeff_y = dy + 4
        self._person_detailed(
            surf,
            jeff_x,
            jeff_y,
            0.88,
            (20, 14, 8),
            (150, 120, 80),
            seated=True,
            facing=-1,
        )

        # Bookshelf — right wall, large and detailed
        shx = int(W * 0.80)
        shy = int(H * 0.08)
        sh_w = int(W * 0.18)
        sh_h = int(H * 0.46)
        pygame.draw.rect(surf, (16, 10, 4), (shx, shy, sh_w, sh_h))
        pygame.draw.rect(surf, (28, 18, 8), (shx, shy, sh_w, sh_h), 3)
        for shelf in range(6):
            sy_s = shy + shelf * sh_h // 6
            pygame.draw.rect(surf, (34, 22, 10), (shx, sy_s, sh_w, 4))
            for bk in range(7):
                bx_b = shx + 3 + bk * int(sh_w / 7.2)
                bh_b = int(sh_h / 6) - 6 + random.Random(shelf * 10 + bk).randint(-4, 8)
                bc_b = [
                    (72, 20, 20),
                    (20, 40, 56),
                    (32, 54, 16),
                    (56, 32, 10),
                    (12, 32, 56),
                    (52, 20, 20),
                    (28, 52, 20),
                ][bk % 7]
                pygame.draw.rect(
                    surf, bc_b, (bx_b, sy_s - bh_b + 4, int(sh_w / 7.2) - 2, bh_b)
                )
                # Book spine line
                pygame.draw.line(
                    surf,
                    darken(bc_b, 0.6),
                    (bx_b, sy_s - bh_b + 4),
                    (bx_b, sy_s + 4),
                    1,
                )
                # Title line
                pygame.draw.line(
                    surf,
                    lighten(bc_b, 1.4),
                    (bx_b + 2, sy_s - bh_b + 8),
                    (bx_b + int(sh_w / 7.2) - 4, sy_s - bh_b + 8),
                    1,
                )

        # Floor — dark wood planks
        for fi9b in range(int(H * 0.82), H, 14):
            pygame.draw.line(surf, (16, 10, 4), (0, fi9b), (W, fi9b))
            pygame.draw.line(surf, (20, 12, 5), (0, fi9b + 1), (W, fi9b + 1))

        # Location caption
        draw_text(
            surf,
            "The White House Study  ·  Washington City  ·  January 18, 1803",
            assets.F["small_i"],
            assets.INK_FAINT,
            (W // 2, H - 18),
            anchor="midbottom",
        )

    # ═══════════════════════════════════════════════════════════════════════════
    #  SCENE 2 — Napoleon Sells a Continent
    #  Grand Parisian palace. Treaty table. Flags and chandelier.
    # ═══════════════════════════════════════════════════════════════════════════
    def _scene_napoleon(self, surf, W, H, t):
        surf.fill((10, 7, 4))
        # Grand vaulted ceiling — arched stonework
        for yi in range(int(H * 0.18)):
            d = yi / int(H * 0.18)
            c = tuple(int(v * (0.3 + d * 0.5)) for v in (42, 36, 18))
            pygame.draw.line(surf, c, (0, yi), (W, yi))

        # Gilded decorative cornice
        for xi in range(0, W, 32):
            pygame.draw.rect(surf, (64, 52, 18), (xi, int(H * 0.17), 28, 12))
            pygame.draw.rect(surf, (90, 72, 24), (xi + 4, int(H * 0.17) + 2, 20, 8))

        # Ornate columns with gilded capitals
        for cx_c in [int(W * f) for f in [0.06, 0.24, 0.62, 0.80, 0.96]]:
            # Fluted shaft
            for fl in range(6):
                shade = 0.7 + fl * 0.06
                pygame.draw.line(
                    surf,
                    tuple(int(v * shade) for v in (44, 36, 16)),
                    (cx_c - 9 + fl * 3, int(H * 0.18)),
                    (cx_c - 9 + fl * 3, int(H * 0.74)),
                    3,
                )
            # Capital — Corinthian-ish
            pygame.draw.polygon(
                surf,
                (80, 64, 22),
                [
                    (cx_c - 20, int(H * 0.18)),
                    (cx_c - 12, int(H * 0.12)),
                    (cx_c + 12, int(H * 0.12)),
                    (cx_c + 20, int(H * 0.18)),
                ],
            )
            pygame.draw.polygon(
                surf,
                (100, 80, 28),
                [
                    (cx_c - 20, int(H * 0.18)),
                    (cx_c - 12, int(H * 0.12)),
                    (cx_c + 12, int(H * 0.12)),
                    (cx_c + 20, int(H * 0.18)),
                ],
                2,
            )
            # Acanthus leaves hint
            pygame.draw.arc(
                surf, (90, 72, 24), (cx_c - 16, int(H * 0.13), 14, 10), 0, math.pi, 2
            )
            pygame.draw.arc(
                surf, (90, 72, 24), (cx_c + 2, int(H * 0.13), 14, 10), 0, math.pi, 2
            )

        # Grand chandelier — central, elaborate
        chx, chy = W // 2, 14
        # Chain
        pygame.draw.line(surf, (64, 54, 20), (W // 2, 0), (chx, chy), 3)
        # Main body
        pygame.draw.ellipse(surf, (72, 58, 22), (chx - 30, chy - 10, 60, 22))
        pygame.draw.ellipse(surf, (88, 70, 26), (chx - 30, chy - 10, 60, 22), 2)
        # Three tiers of arms
        for tier, n_arms, r_arm in [(0, 8, 38), (1, 6, 26), (2, 4, 16)]:
            tier_y = chy + 8 + tier * 14
            pygame.draw.ellipse(
                surf, (64, 52, 18), (chx - r_arm - 4, tier_y - 4, r_arm * 2 + 8, 10)
            )
            for a in range(n_arms):
                ang = a * 2 * math.pi / n_arms
                ax_c = chx + int(math.cos(ang) * r_arm)
                ay_c = tier_y + int(math.sin(ang) * 4)
                pygame.draw.line(surf, (56, 44, 14), (chx, tier_y), (ax_c, ay_c), 2)
                self._flame(surf, ax_c, ay_c, t, seed=tier * 100 + a, size=0.7)
        # Crystal drops
        for i in range(16):
            ang = i * math.pi * 2 / 16
            cx_d = chx + int(math.cos(ang) * 34)
            cy_d = chy + 24 + int(math.sin(ang) * 3)
            pygame.draw.line(
                surf, (180, 200, 220), (cx_d, cy_d), (cx_d + 1, cy_d + 8), 1
            )

        # Tricolor flags — France — flanking
        for fx_f, flip in [(int(W * 0.14), -1), (int(W * 0.84), 1)]:
            pygame.draw.line(
                surf, (44, 30, 12), (fx_f, int(H * 0.12)), (fx_f, int(H * 0.56)), 4
            )
            for xi, col_f in enumerate([(28, 44, 96), (240, 240, 240), (180, 20, 24)]):
                px_f = fx_f + flip * (xi * 14)
                pygame.draw.rect(
                    surf,
                    col_f,
                    (
                        px_f,
                        int(H * 0.12),
                        14,
                        int(H * 0.28) + int(math.sin(t * 2 + xi) * 4),
                    ),
                )

        # Parquet floor — perspective
        floor_y = int(H * 0.72)
        for fi_f in range(0, W, 28):
            for fj_f in range(floor_y, H, 20):
                c_f = (
                    (30, 22, 8)
                    if ((fi_f // 28) + (fj_f // 20)) % 2 == 0
                    else (24, 16, 5)
                )
                pygame.draw.rect(surf, c_f, (fi_f, fj_f, 26, 18))
                pygame.draw.rect(surf, (18, 12, 4), (fi_f, fj_f, 26, 18), 1)
        # Floor reflection from chandelier
        self._glow(surf, W // 2, floor_y, int(W * 0.3), (180, 140, 40), 30)

        # Large wall map — left
        mx_m, my_m, mw_m, mh_m = (
            int(W * 0.08),
            int(H * 0.20),
            int(W * 0.32),
            int(H * 0.36),
        )
        pygame.draw.rect(surf, (20, 14, 6), (mx_m - 6, my_m - 6, mw_m + 12, mh_m + 12))
        pygame.draw.rect(
            surf, (72, 54, 18), (mx_m - 6, my_m - 6, mw_m + 12, mh_m + 12), 3
        )
        # Parchment map
        for yi in range(mh_m):
            c_m = (int(200 - yi * 0.4), int(180 - yi * 0.5), int(90 - yi * 0.2))
            pygame.draw.line(surf, c_m, (mx_m, my_m + yi), (mx_m + mw_m, my_m + yi))
        # Louisiana territory blob
        lp_m = [
            (mx_m + int(mw_m * f[0]), my_m + int(mh_m * f[1]))
            for f in [
                (0.12, 0.80),
                (0.18, 0.15),
                (0.58, 0.08),
                (0.88, 0.22),
                (0.92, 0.82),
                (0.55, 0.90),
            ]
        ]
        pygame.draw.polygon(surf, (136, 112, 48), lp_m)
        pygame.draw.polygon(surf, (80, 60, 20), lp_m, 2)
        ml_m = assets.F["tiny_b"].render("LOUISIANA", True, (60, 42, 12))
        surf.blit(ml_m, ml_m.get_rect(center=(mx_m + mw_m // 2, my_m + mh_m // 2)))
        ml2 = assets.F["tiny"].render("828,000 square miles", True, (80, 60, 20))
        surf.blit(ml2, ml2.get_rect(center=(mx_m + mw_m // 2, my_m + mh_m // 2 + 14)))

        # Treaty table — long, mahogany
        tx_t, ty_t, tw_t, th_t = (
            int(W * 0.10),
            int(H * 0.52),
            int(W * 0.80),
            int(H * 0.08),
        )
        # Table shadow
        pygame.draw.ellipse(surf, (0, 0, 0), (tx_t + 8, ty_t + th_t + 4, tw_t, 16))
        # Table surface
        for yi in range(th_t):
            refl = math.sin(yi / th_t * math.pi) * 0.4
            c_t = (int(44 + refl * 20), int(24 + refl * 10), int(8 + refl * 4))
            pygame.draw.line(surf, c_t, (tx_t, ty_t + yi), (tx_t + tw_t, ty_t + yi))
        pygame.draw.rect(surf, (62, 38, 14), (tx_t, ty_t, tw_t, th_t), 3)
        # Table legs
        for lx_t in [tx_t + 24, tx_t + tw_t - 24]:
            pygame.draw.rect(
                surf, (36, 18, 6), (lx_t - 8, ty_t + th_t, 16, H - ty_t - th_t)
            )

        # Treaty document — centre table, open
        dc_x, dc_y = tx_t + int(tw_t * 0.38), ty_t - int(H * 0.14)
        dc_w, dc_h = int(W * 0.24), int(H * 0.16)
        self._glow(surf, dc_x + dc_w // 2, dc_y + dc_h, dc_w // 2, (200, 180, 60), 50)
        pygame.draw.rect(surf, (6, 4, 2), (dc_x + 6, dc_y + 6, dc_w, dc_h))
        for yi in range(dc_h):
            c_dc = (int(236 - yi * 0.4), int(220 - yi * 0.6), int(108 - yi * 0.3))
            pygame.draw.line(surf, c_dc, (dc_x, dc_y + yi), (dc_x + dc_w, dc_y + yi))
        pygame.draw.rect(surf, (140, 100, 24), (dc_x, dc_y, dc_w, dc_h), 3)
        dt_t = assets.F["subhead"].render("LOUISIANA TERRITORY", True, (58, 38, 8))
        surf.blit(dt_t, dt_t.get_rect(centerx=dc_x + dc_w // 2, top=dc_y + 8))
        ds_t = assets.F["header"].render("$15,000,000", True, (100, 70, 14))
        surf.blit(ds_t, ds_t.get_rect(centerx=dc_x + dc_w // 2, bottom=dc_y + dc_h - 8))
        for li in range(7):
            lw_t = int(dc_w * 0.72) + random.Random(li * 13).randint(-16, 20)
            pygame.draw.line(
                surf,
                (70, 46, 14),
                (dc_x + 14, dc_y + 28 + li * 11),
                (dc_x + 14 + lw_t, dc_y + 28 + li * 11),
                1,
            )
        # Big red seal
        pygame.draw.circle(surf, (80, 10, 10), (dc_x + dc_w - 24, dc_y + dc_h - 22), 20)
        pygame.draw.circle(
            surf, (190, 22, 22), (dc_x + dc_w - 24, dc_y + dc_h - 22), 20
        )
        pygame.draw.circle(
            surf, (210, 50, 40), (dc_x + dc_w - 24, dc_y + dc_h - 22), 20, 2
        )
        fr_t = assets.F["small_b" if "small_b" in assets.F else "small"].render(
            "R", True, (220, 160, 40)
        )
        surf.blit(fr_t, fr_t.get_rect(center=(dc_x + dc_w - 24, dc_y + dc_h - 22)))

        # Candelabras on table
        for cn_t in [tx_t + int(tw_t * 0.08), tx_t + int(tw_t * 0.88)]:
            pygame.draw.line(surf, (60, 44, 14), (cn_t, ty_t - 8), (cn_t, ty_t - 48), 4)
            pygame.draw.ellipse(surf, (52, 38, 12), (cn_t - 12, ty_t - 12, 24, 8))
            for arm in [-14, 0, 14]:
                self._flame(surf, cn_t + arm, ty_t - 50, t, seed=cn_t + arm, size=0.85)

        # Figures — three silhouettes in period dress
        # Napoleon (shorter, assertive, right side of doc)
        self._person_detailed(
            surf,
            tx_t + int(tw_t * 0.60),
            ty_t + 2,
            0.88,
            (30, 18, 8),
            (180, 140, 90),
            seated=False,
            facing=-1,
            arm_up=True,
        )
        # Livingston and Monroe (American, left side)
        self._person_detailed(
            surf,
            tx_t + int(tw_t * 0.28),
            ty_t + 2,
            0.84,
            (18, 28, 48),
            (160, 130, 85),
            seated=False,
            facing=1,
        )
        self._person_detailed(
            surf,
            tx_t + int(tw_t * 0.38),
            ty_t + 2,
            0.80,
            (20, 26, 44),
            (155, 125, 80),
            seated=True,
            facing=1,
        )

        draw_text(
            surf,
            "Tuileries Palace, Paris  ·  April 30, 1803  ·  828,000 square miles for three cents an acre",
            assets.F["small_i"],
            assets.INK_FAINT,
            (W // 2, H - 18),
            anchor="midbottom",
        )

    # ═══════════════════════════════════════════════════════════════════════════
    #  SCENE 3 — Lewis Prepares
    #  Pre-dawn. Arsenal courtyard. Equipment everywhere.
    # ═══════════════════════════════════════════════════════════════════════════
    def _scene_lewis(self, surf, W, H, t):
        # Pre-dawn sky — deep blue to grey-green
        self._sky_grad(
            surf,
            W,
            H,
            [(6, 8, 18), (10, 14, 28), (16, 22, 32), (20, 28, 24), (18, 24, 16)],
            h_end=int(H * 0.44),
        )
        # Stars fading
        rng_l = random.Random(42)
        for _ in range(35):
            sx_l = rng_l.randint(0, W)
            sy_l = rng_l.randint(0, int(H * 0.36))
            bv_l = rng_l.randint(40, 130)
            pygame.draw.circle(
                surf, (bv_l, bv_l, min(255, int(bv_l * 0.9))), (sx_l, sy_l), 1
            )
        # River beyond — dark blue
        self._water_shimmer(
            surf, W, int(H * 0.52), int(H * 0.60), t, (20, 40, 68), depth=False
        )
        # Ground — stone courtyard
        self._ground(
            surf, W, H, [(0.44, (32, 28, 18), 0.004, 6), (0.60, (24, 22, 14), 0.006, 4)]
        )
        # Cobblestones
        for ci_s in range(0, W, 28):
            for cj_s in range(int(H * 0.52), H, 18):
                offset = (cj_s // 18) % 2 * 14
                c_s = (
                    (24, 20, 12) if (ci_s // 28 + cj_s // 18) % 3 == 0 else (20, 16, 10)
                )
                pygame.draw.rect(surf, c_s, (ci_s + offset, cj_s, 26, 16))
                pygame.draw.rect(surf, (14, 10, 5), (ci_s + offset, cj_s, 26, 16), 1)

        # Arsenal building — Federal style
        bx_a, by_a, bw_a, bh_a = (
            int(W * 0.26),
            int(H * 0.06),
            int(W * 0.62),
            int(H * 0.46),
        )
        # Building shadow
        pygame.draw.rect(surf, (8, 6, 4), (bx_a + 10, by_a + 10, bw_a + 10, bh_a + 10))
        # Brick facade
        for row_b in range(0, bh_a, 10):
            offset_b = (row_b // 10) % 2 * 14
            shade_b = 16 + row_b % 4
            for col_b in range(-offset_b, bw_a, 28):
                r_b = min(255, int(shade_b * 2.2))
                g_b = int(shade_b * 1.1)
                b_b = int(shade_b * 0.8)
                pygame.draw.rect(
                    surf, (r_b, g_b, b_b), (bx_a + col_b, by_a + row_b, 26, 8)
                )
        # Pediment
        pygame.draw.polygon(
            surf,
            (36, 28, 16),
            [
                (bx_a - 12, by_a),
                (bx_a + bw_a // 2, by_a - int(H * 0.06)),
                (bx_a + bw_a + 12, by_a),
            ],
        )
        pygame.draw.polygon(
            surf,
            (48, 38, 20),
            [
                (bx_a - 12, by_a),
                (bx_a + bw_a // 2, by_a - int(H * 0.06)),
                (bx_a + bw_a + 12, by_a),
            ],
            2,
        )
        # Columns
        for cx_a in [bx_a + int(bw_a * f) for f in [0.10, 0.30, 0.50, 0.70, 0.90]]:
            pygame.draw.rect(surf, (38, 30, 14), (cx_a - 8, by_a - 4, 16, bh_a + 8))
            pygame.draw.rect(surf, (52, 42, 18), (cx_a - 8, by_a - 4, 16, bh_a + 8), 1)
        # Glowing windows — amber interior light
        for wi_a in range(bx_a + int(bw_a * 0.12), bx_a + bw_a - 20, int(bw_a * 0.22)):
            wh_a2 = int(H * 0.14)
            # Glow
            self._glow(surf, wi_a + 14, by_a + wh_a2, 24, (180, 100, 12), 40)
            pygame.draw.rect(surf, (180, 108, 14), (wi_a, by_a + 20, 28, wh_a2))
            pygame.draw.rect(surf, (200, 130, 20), (wi_a, by_a + 20, 28, wh_a2), 1)
            # Arch top
            pygame.draw.ellipse(surf, (180, 108, 14), (wi_a, by_a + 10, 28, 24))
            pygame.draw.ellipse(surf, (200, 130, 20), (wi_a, by_a + 10, 28, 24), 1)
            # Glazing bars
            pygame.draw.line(
                surf,
                (24, 16, 6),
                (wi_a + 14, by_a + 10),
                (wi_a + 14, by_a + 20 + wh_a2),
                2,
            )
            pygame.draw.line(
                surf,
                (24, 16, 6),
                (wi_a, by_a + 24 + wh_a2 // 2),
                (wi_a + 28, by_a + 24 + wh_a2 // 2),
                1,
            )
        # Main entrance arch
        da_x = bx_a + bw_a // 2
        pygame.draw.ellipse(surf, (14, 10, 5), (da_x - 28, by_a + bh_a - 70, 56, 48))
        pygame.draw.rect(surf, (14, 10, 5), (da_x - 28, by_a + bh_a - 46, 56, 48))
        pygame.draw.ellipse(
            surf, (220, 120, 14), (da_x - 20, by_a + bh_a - 64, 40, 36)
        )  # interior light
        pygame.draw.ellipse(surf, (24, 16, 6), (da_x - 28, by_a + bh_a - 70, 56, 48), 3)

        # Equipment scattered in courtyard — large and prominent
        ground_y = int(H * 0.54)
        # Stacked barrels — left
        for bi_e, (bx_e, by_e) in enumerate(
            [
                (int(W * 0.04), ground_y - 32),
                (int(W * 0.09), ground_y - 32),
                (int(W * 0.065), ground_y - 58),
            ]
        ):
            pygame.draw.ellipse(surf, (56, 32, 10), (bx_e, by_e, 40, 28))
            pygame.draw.ellipse(surf, (72, 44, 14), (bx_e, by_e, 40, 28), 2)
            for si_e in [0.28, 0.50, 0.72]:
                pygame.draw.line(
                    surf,
                    (72, 44, 14),
                    (bx_e, by_e + int(28 * si_e)),
                    (bx_e + 40, by_e + int(28 * si_e)),
                    1,
                )
        # Crates
        for cx_e, cy_e, cw_e, ch_e in [
            (int(W * 0.14), ground_y - 28, 44, 28),
            (int(W * 0.19), ground_y - 22, 36, 22),
        ]:
            pygame.draw.rect(surf, (46, 28, 8), (cx_e, cy_e, cw_e, ch_e))
            pygame.draw.rect(surf, (64, 40, 14), (cx_e, cy_e, cw_e, ch_e), 2)
            pygame.draw.line(
                surf, (28, 16, 4), (cx_e, cy_e), (cx_e + cw_e, cy_e + ch_e), 1
            )
            pygame.draw.line(
                surf, (28, 16, 4), (cx_e + cw_e, cy_e), (cx_e, cy_e + ch_e), 1
            )
            # Stencil
            cs_e = assets.F["tiny"].render("LEWIS & CLARK", True, (36, 22, 8))
            surf.blit(cs_e, (cx_e + 4, cy_e + 4))
        # Iron-frame boat (the famous Experiment) — prominently displayed
        boat_x = int(W * 0.60)
        boat_y = ground_y - 28
        pygame.draw.polygon(
            surf,
            (60, 50, 40),
            [
                (boat_x, boat_y),
                (boat_x - int(W * 0.18), boat_y),
                (boat_x - int(W * 0.18), boat_y - 24),
                (boat_x - int(W * 0.08), boat_y - 32),
                (boat_x + int(W * 0.04), boat_y - 24),
                (boat_x, boat_y),
            ],
        )
        for bri in range(6):
            pygame.draw.line(
                surf,
                (48, 40, 28),
                (boat_x - int(W * 0.16) + bri * int(W * 0.035), boat_y),
                (boat_x - int(W * 0.14) + bri * int(W * 0.035), boat_y - 28),
                2,
            )
        pygame.draw.polygon(
            surf,
            (78, 64, 44),
            [
                (boat_x, boat_y),
                (boat_x - int(W * 0.18), boat_y),
                (boat_x - int(W * 0.18), boat_y - 24),
                (boat_x - int(W * 0.08), boat_y - 32),
                (boat_x + int(W * 0.04), boat_y - 24),
            ],
            2,
        )
        boat_lbl = assets.F["tiny_b"].render("EXPERIMENT", True, (60, 44, 16))
        surf.blit(boat_lbl, (boat_x - int(W * 0.13), boat_y - 18))
        # Musket rack — right
        rrx_m = int(W * 0.90)
        rry_m = ground_y - int(H * 0.22)
        pygame.draw.line(surf, (44, 30, 10), (rrx_m, rry_m), (rrx_m, ground_y), 5)
        pygame.draw.line(
            surf, (36, 24, 8), (rrx_m - 24, rry_m + 4), (rrx_m + 24, rry_m + 4), 4
        )
        pygame.draw.line(
            surf,
            (36, 24, 8),
            (rrx_m - 24, rry_m + int(H * 0.14)),
            (rrx_m + 24, rry_m + int(H * 0.14)),
            4,
        )
        for mi_m in range(7):
            mx_m = rrx_m - 18 + mi_m * 6
            pygame.draw.line(
                surf, (50, 34, 12), (mx_m, rry_m + 8), (mx_m + 2, ground_y - 4), 2
            )
            pygame.draw.rect(surf, (38, 26, 8), (mx_m - 2, rry_m + 4, 6, 6))

        # Lewis — full-scale, examining a rifle
        self._person_detailed(
            surf,
            int(W * 0.48),
            ground_y,
            1.02,
            (20, 28, 52),
            (165, 130, 90),
            seated=False,
            facing=-1,
            arm_up=True,
        )

        # Torch on wall — illuminating scene
        torch_x = int(W * 0.26)
        torch_y = int(H * 0.44)
        pygame.draw.line(
            surf, (44, 28, 8), (torch_x, torch_y), (torch_x - 4, torch_y + 28), 4
        )
        self._glow(surf, torch_x, torch_y, int(W * 0.22), (180, 90, 10), 35)
        self._flame(surf, torch_x, torch_y, t, seed=200, size=1.4)

        draw_text(
            surf,
            "Harpers Ferry Arsenal  ·  Summer 1803  ·  193 lbs of portable soup",
            assets.F["small_i"],
            assets.INK_FAINT,
            (W // 2, H - 18),
            anchor="midbottom",
        )

    # ═══════════════════════════════════════════════════════════════════════════
    #  SCENE 4 — Clark is Recruited
    #  Intimate night scene. One man. One lantern. One letter.
    # ═══════════════════════════════════════════════════════════════════════════
    def _scene_clark(self, surf, W, H, t):
        surf.fill((4, 5, 8))
        # Deep night sky — Milky Way suggestion
        self._sky_grad(
            surf,
            W,
            H,
            [(4, 5, 12), (8, 9, 20), (12, 14, 28), (8, 10, 20)],
            h_end=int(H * 0.55),
        )
        # Many stars — Indiana Territory night
        rng_c = random.Random(77)
        for _ in range(120):
            sx_c = rng_c.randint(0, W)
            sy_c = rng_c.randint(0, int(H * 0.52))
            bv_c = rng_c.randint(40, 200)
            tw_c = int(math.sin(t * 2.2 + sx_c * 0.07) * 22)
            bv2_c = max(20, min(220, bv_c + tw_c))
            r_c2 = 2 if bv_c > 160 else 1
            pygame.draw.circle(
                surf, (bv2_c, bv2_c, min(255, int(bv2_c * 0.86))), (sx_c, sy_c), r_c2
            )
        # Milky Way band (faint)
        for yi in range(int(H * 0.06), int(H * 0.42), 2):
            band_x = int(W * 0.35) + int(math.sin(yi * 0.02) * 60)
            for _ in range(12):
                bx_mw = band_x + random.Random(yi + _).randint(
                    -int(W * 0.22), int(W * 0.22)
                )
                by_mw = yi + random.Random(yi + _ * 3).randint(-2, 2)
                if 0 <= bx_mw < W:
                    bv_mw = random.Random(yi + _ * 7).randint(20, 60)
                    pygame.draw.circle(surf, (bv_mw, bv_mw, bv_mw), (bx_mw, by_mw), 1)

        # Rolling terrain — Indiana hills
        self._ground(
            surf,
            W,
            H,
            [
                (0.52, (18, 28, 12), 0.005, 22),
                (0.66, (14, 22, 8), 0.008, 14),
                (0.82, (10, 16, 4), 0.014, 8),
            ],
        )
        # Ohio River distant — faint reflection
        for yi in range(int(H * 0.56), int(H * 0.62)):
            sh_r = math.sin(yi * 0.15 + t * 1.6) * 0.25 + 0.35
            c_r = (int(8 + sh_r * 16), int(12 + sh_r * 14), int(22 + sh_r * 24))
            pygame.draw.line(surf, c_r, (0, yi), (W, yi))

        # Log farmhouse — back right, dark
        fhx_c, fhy_c = int(W * 0.52), int(H * 0.26)
        fhw_c, fhh_c = int(W * 0.38), int(H * 0.32)
        pygame.draw.rect(surf, (8, 6, 3), (fhx_c + 8, fhy_c + 8, fhw_c + 8, fhh_c + 8))
        for log_c in range(0, fhh_c, 11):
            c_log = (20 + log_c % 8, 12 + log_c % 6, 4 + log_c % 3)
            pygame.draw.rect(surf, c_log, (fhx_c, fhy_c + log_c, fhw_c, 9))
        # Roof
        pygame.draw.polygon(
            surf,
            (16, 12, 6),
            [
                (fhx_c - 10, fhy_c),
                (fhx_c + fhw_c // 2, fhy_c - int(H * 0.08)),
                (fhx_c + fhw_c + 10, fhy_c),
            ],
        )
        # Chimney
        ch_x = fhx_c + int(fhw_c * 0.65)
        ch_top = fhy_c - int(H * 0.08) - 12
        pygame.draw.rect(surf, (22, 14, 7), (ch_x, ch_top, 18, fhy_c - ch_top + 8))
        # Chimney smoke
        for spi in range(5):
            sm_x = ch_x + 9 + int(math.sin(t * 1.3 + spi) * 7)
            sm_y = ch_top - spi * 20 - int(math.cos(t + spi * 0.7) * 6)
            a_sm = max(0, min(255, 60 - spi * 10))
            gs_sm = pygame.Surface((20, 16), pygame.SRCALPHA)
            pygame.draw.ellipse(
                gs_sm, (a_sm, a_sm, int(a_sm * 0.9), a_sm), (0, 0, 20, 16)
            )
            surf.blit(gs_sm, (sm_x - 10, sm_y - 8))
        # Warm windows
        for wx_c in [fhx_c + 14, fhx_c + fhw_c - 40]:
            self._glow(surf, wx_c + 12, fhy_c + 32, 30, (160, 90, 12), 35)
            pygame.draw.rect(surf, (180, 102, 14), (wx_c, fhy_c + 18, 24, 36))
            pygame.draw.rect(surf, (24, 14, 6), (wx_c, fhy_c + 18, 24, 36), 2)
            pygame.draw.line(
                surf, (24, 14, 6), (wx_c + 12, fhy_c + 18), (wx_c + 12, fhy_c + 54), 1
            )
            pygame.draw.line(
                surf, (24, 14, 6), (wx_c, fhy_c + 36), (wx_c + 24, fhy_c + 36), 1
            )
        # Fence — split rail
        for fx_c in range(0, W, 52):
            fy_c = int(H * 0.62) + random.Random(fx_c).randint(-3, 5)
            pygame.draw.line(
                surf,
                (22, 14, 5),
                (fx_c, fy_c),
                (fx_c + 50, fy_c + random.Random(fx_c + 1).randint(-2, 3)),
                3,
            )
            pygame.draw.line(
                surf, (18, 12, 4), (fx_c + 6, fy_c - 8), (fx_c + 6, fy_c + 16), 4
            )
            pygame.draw.line(
                surf,
                (22, 14, 5),
                (fx_c, fy_c + 8),
                (fx_c + 50, fy_c + 8 + random.Random(fx_c + 2).randint(-2, 3)),
                3,
            )

        # CLARK — foreground, intimate, reading by lantern
        clark_x, clark_y = int(W * 0.30), int(H * 0.66)
        # Large warm glow from lantern — illuminates whole foreground
        self._glow(surf, clark_x + 52, clark_y - 44, int(W * 0.24), (180, 90, 14), 55)
        # Lantern — detailed
        lnx_c, lny_c = clark_x + 54, clark_y - 48
        pygame.draw.line(surf, (40, 26, 8), (lnx_c, lny_c - 28), (lnx_c, lny_c - 8), 3)
        pygame.draw.rect(surf, (36, 24, 8), (lnx_c - 10, lny_c - 8, 20, 32))
        pygame.draw.rect(surf, (52, 36, 12), (lnx_c - 10, lny_c - 8, 20, 32), 2)
        pygame.draw.rect(surf, (180, 110, 16), (lnx_c - 7, lny_c - 4, 14, 24))
        # Lantern glass panes
        for pi_l in range(4):
            pygame.draw.line(
                surf,
                (36, 22, 6),
                (lnx_c - 10 + pi_l * 7, lny_c - 8),
                (lnx_c - 10 + pi_l * 7, lny_c + 24),
                1,
            )
        pygame.draw.rect(surf, (48, 32, 10), (lnx_c - 12, lny_c + 22, 24, 6))
        self._flame(surf, lnx_c, lny_c + 2, t, seed=999, size=0.8)

        # The letter — luminous, detailed
        let_x, let_y = clark_x + 18, clark_y - 56
        let_w, let_h = int(W * 0.14), int(H * 0.13)
        self._glow(
            surf, let_x + let_w // 2, let_y + let_h // 2, let_w // 2, (220, 190, 80), 40
        )
        pygame.draw.rect(surf, (6, 4, 2), (let_x + 4, let_y + 4, let_w, let_h))
        for yi in range(let_h):
            c_let = (int(230 - yi * 0.5), int(214 - yi * 0.6), int(102 - yi * 0.3))
            pygame.draw.line(
                surf, c_let, (let_x, let_y + yi), (let_x + let_w, let_y + yi)
            )
        pygame.draw.rect(surf, (120, 88, 18), (let_x, let_y, let_w, let_h), 2)
        # Writing lines
        for li_l in range(8):
            lw_l = int(let_w * 0.78) + random.Random(li_l * 11).randint(-8, 12)
            pygame.draw.line(
                surf,
                (62, 42, 10),
                (let_x + 8, let_y + 12 + li_l * 10),
                (let_x + 8 + lw_l, let_y + 12 + li_l * 10),
                1,
            )
        # "Dear Friend" salutation highlight
        df_l = assets.F["tiny_b"].render("Dear Friend,", True, (80, 56, 14))
        surf.blit(df_l, (let_x + 8, let_y + 10))

        # Clark reading
        self._person_detailed(
            surf,
            clark_x,
            clark_y,
            1.0,
            (16, 24, 60),
            (170, 130, 88),
            seated=False,
            facing=1,
        )

        # Log he's sitting on / fence post
        pygame.draw.ellipse(surf, (24, 14, 6), (clark_x - 28, clark_y, 56, 18))
        pygame.draw.rect(surf, (20, 12, 5), (clark_x - 28, clark_y + 8, 56, 14))

        # Fireflies — small glowing dots in foreground
        rng_ff = random.Random(int(t * 3) % 100)
        for _ in range(8):
            ffx = rng_ff.randint(0, W)
            ffy = rng_ff.randint(int(H * 0.55), H - 20)
            ffa = rng_ff.randint(40, 180)
            gs_ff = pygame.Surface((8, 8), pygame.SRCALPHA)
            pygame.draw.circle(gs_ff, (ffa, min(255, ffa + 40), 20, ffa), (4, 4), 3)
            surf.blit(gs_ff, (ffx - 4, ffy - 4), special_flags=pygame.BLEND_RGBA_ADD)

        draw_text(
            surf,
            "Clarksville, Indiana Territory  ·  June 19, 1803  ·  He said yes the same day",
            assets.F["small_i"],
            assets.INK_FAINT,
            (W // 2, H - 18),
            anchor="midbottom",
        )

    # ═══════════════════════════════════════════════════════════════════════════
    #  SCENE 5 — The Corps of Discovery
    #  Camp Dubois. Winter night. Many fires. The keelboat.
    # ═══════════════════════════════════════════════════════════════════════════
    def _scene_camp(self, surf, W, H, t):
        # Deep winter night
        self._sky_grad(
            surf,
            W,
            H,
            [(6, 8, 16), (10, 13, 26), (14, 18, 34), (10, 14, 26)],
            h_end=int(H * 0.50),
        )
        rng_cp = random.Random(55)
        for _ in range(80):
            sx_cp = rng_cp.randint(0, W)
            sy_cp = rng_cp.randint(0, int(H * 0.46))
            bv_cp = rng_cp.randint(30, 150)
            pygame.draw.circle(
                surf, (bv_cp, bv_cp, min(255, int(bv_cp * 0.88))), (sx_cp, sy_cp), 1
            )
        # Full moon — large, bright
        mx_cp, my_cp = int(W * 0.82), int(H * 0.12)
        for mr_cp in range(56, 4, -6):
            a_cp = int(80 * (1 - mr_cp / 56) ** 2.2)
            ms_cp = pygame.Surface((mr_cp * 2, mr_cp * 2), pygame.SRCALPHA)
            pygame.draw.circle(ms_cp, (220, 215, 160, a_cp), (mr_cp, mr_cp), mr_cp)
            surf.blit(ms_cp, (mx_cp - mr_cp, my_cp - mr_cp))
        pygame.draw.circle(surf, (220, 212, 158), (mx_cp, my_cp), 34)
        pygame.draw.circle(surf, (200, 195, 140), (mx_cp, my_cp), 34, 2)
        # Moon crescent shadow
        pygame.draw.circle(surf, (12, 16, 28), (mx_cp + 18, my_cp - 14), 26)
        # Moon reflection on river
        for mri in range(8):
            mriy = int(H * 0.50) + mri * 12
            mriw = max(2, int(22 - mri * 2))
            mrix = int(mx_cp + math.sin(t * 0.9 + mri * 0.4) * (mri * 3))
            pygame.draw.ellipse(
                surf, (180, 170, 110), (mrix - mriw, mriy - 4, mriw * 2, 8)
            )

        # Terrain
        self._ground(
            surf,
            W,
            H,
            [
                (0.50, (20, 34, 12), 0.005, 16),
                (0.64, (16, 28, 10), 0.009, 10),
                (0.78, (12, 20, 7), 0.016, 6),
            ],
        )
        # Missouri River — wide, shimmering
        self._water_shimmer(surf, W, int(H * 0.46), int(H * 0.56), t, (16, 32, 54))

        # THE KEELBOAT — hero of the scene, large and detailed
        self._keelboat(surf, int(W * 0.52), int(H * 0.49), 0.82, t, (136, 16, 16))
        # Torchlight on keelboat
        self._glow(surf, int(W * 0.52), int(H * 0.46), int(W * 0.18), (160, 80, 12), 40)

        # TENTS — line of them along bank
        for ti_t, (tx_t2, ty_t2) in enumerate(
            [
                (int(W * f), int(H * 0.42))
                for f in [0.04, 0.12, 0.18, 0.28, 0.36, 0.64, 0.72, 0.82, 0.90]
            ]
        ):
            tent_col2 = (48, 38, 18) if ti_t % 3 != 1 else (42, 32, 14)
            pole_h = int(H * 0.10) + random.Random(ti_t * 3).randint(-8, 8)
            # Tent
            pygame.draw.polygon(
                surf,
                tent_col2,
                [
                    (tx_t2 - int(W * 0.044), ty_t2 + 14),
                    (tx_t2, ty_t2 - pole_h),
                    (tx_t2 + int(W * 0.044), ty_t2 + 14),
                ],
            )
            pygame.draw.polygon(
                surf,
                lighten(tent_col2, 1.2),
                [
                    (tx_t2 - int(W * 0.044), ty_t2 + 14),
                    (tx_t2, ty_t2 - pole_h),
                    (tx_t2 + int(W * 0.044), ty_t2 + 14),
                ],
                1,
            )
            # Guy ropes
            pygame.draw.line(
                surf,
                (32, 22, 8),
                (tx_t2, ty_t2 - pole_h),
                (tx_t2 - int(W * 0.06), ty_t2 + 14),
                1,
            )
            pygame.draw.line(
                surf,
                (32, 22, 8),
                (tx_t2, ty_t2 - pole_h),
                (tx_t2 + int(W * 0.06), ty_t2 + 14),
                1,
            )
            # Tent flag pole
            pygame.draw.line(
                surf,
                (36, 24, 8),
                (tx_t2, ty_t2 - pole_h),
                (tx_t2, ty_t2 - pole_h - 24),
                2,
            )

        # CAMPFIRES — three prominent ones
        for cf_x, cf_y, cf_s in [
            (int(W * 0.16), int(H * 0.44), 1.4),
            (int(W * 0.44), int(H * 0.43), 1.6),
            (int(W * 0.76), int(H * 0.44), 1.3),
        ]:
            self._campfire(surf, cf_x, cf_y, t, seed=cf_x, size=cf_s)
            # Fire light on ground
            self._glow(surf, cf_x, cf_y, int(W * 0.10), (180, 80, 8), 30)

        # CORPS MEMBERS around fires — silhouettes
        for pi_c, (px_c, py_c, sc_c, fc_c) in enumerate(
            [
                (int(W * 0.10), int(H * 0.44), (0.72), (28, 18, 10)),
                (int(W * 0.20), int(H * 0.44), (0.68), (22, 14, 8)),
                (int(W * 0.24), int(H * 0.44), (0.64), (26, 16, 8)),
                (int(W * 0.38), int(H * 0.43), (0.70), (20, 16, 8)),
                (int(W * 0.50), int(H * 0.43), (0.66), (24, 14, 8)),
                (int(W * 0.70), int(H * 0.44), (0.72), (22, 18, 10)),
                (int(W * 0.80), int(H * 0.44), (0.68), (28, 14, 8)),
            ]
        ):
            self._person_detailed(
                surf,
                px_c,
                py_c,
                sc_c,
                fc_c,
                (100 + pi_c * 8, 80 + pi_c * 6, 50),
                seated=(pi_c % 2 == 0),
                facing=(1 if pi_c % 2 == 0 else -1),
            )

        # Corps banner — strung between poles
        bp1_x, bp2_x = int(W * 0.36), int(W * 0.62)
        bp_y = int(H * 0.36)
        pygame.draw.line(
            surf, (38, 24, 8), (bp1_x, bp_y), (bp1_x, bp_y + int(H * 0.12)), 4
        )
        pygame.draw.line(
            surf, (38, 24, 8), (bp2_x, bp_y), (bp2_x, bp_y + int(H * 0.12)), 4
        )
        # Waving banner
        banner_pts = []
        for xi in range(bp2_x - bp1_x):
            bx_b = bp1_x + xi
            by_b = bp_y + int(math.sin(t * 2.8 + xi * 0.04) * 6)
            banner_pts.append((bx_b, by_b))
        if len(banner_pts) > 1:
            pygame.draw.lines(surf, (160, 20, 20), False, banner_pts, 3)
            # Banner fill
            for yi in range(22):
                if yi < banner_pts[0][1] - bp_y + 22:
                    row_pts = [
                        (bx, by + yi)
                        for bx, by in banner_pts[::4]
                        if by + yi < bp_y + 26
                    ]
                    if len(row_pts) > 1:
                        pygame.draw.lines(surf, (148, 16, 18), False, row_pts, 2)
        bn_txt = assets.F["tiny_b"].render("CORPS OF DISCOVERY", True, (220, 190, 80))
        surf.blit(
            bn_txt, bn_txt.get_rect(centerx=(bp1_x + bp2_x) // 2, centery=bp_y + 12)
        )

        draw_text(
            surf,
            "Camp Dubois, Illinois  ·  Winter 1803–1804  ·  33 permanent members",
            assets.F["small_i"],
            assets.INK_FAINT,
            (W // 2, H - 18),
            anchor="midbottom",
        )

    # ═══════════════════════════════════════════════════════════════════════════
    #  SCENE 6 — The Missouri River
    #  Vast. Dark. Alive. The river at night from a bluff.
    # ═══════════════════════════════════════════════════════════════════════════
    def _scene_river(self, surf, W, H, t):
        # Night sky — deep indigo
        self._sky_grad(
            surf,
            W,
            H,
            [(6, 7, 18), (9, 11, 26), (12, 16, 32), (10, 13, 28), (8, 10, 22)],
            h_end=int(H * 0.54),
        )
        # Dense stars
        rng_rv = random.Random(88)
        for _ in range(140):
            sx_rv = rng_rv.randint(0, W)
            sy_rv = rng_rv.randint(0, int(H * 0.50))
            bv_rv = rng_rv.randint(30, 200)
            tw_rv = int(math.sin(t * 1.9 + sx_rv * 0.05) * 20)
            bv2_rv = max(15, min(220, bv_rv + tw_rv))
            r_rv = 2 if bv_rv > 170 else 1
            pygame.draw.circle(
                surf,
                (bv2_rv, bv2_rv, min(255, int(bv2_rv * 0.88))),
                (sx_rv, sy_rv),
                r_rv,
            )

        # Large moon with full halo — perfect circle over river
        mx_rv, my_rv = int(W * 0.72), int(H * 0.16)
        for mr_rv in range(72, 4, -6):
            a_rv = int(90 * (1 - mr_rv / 72) ** 2.0)
            ms_rv = pygame.Surface((mr_rv * 2, mr_rv * 2), pygame.SRCALPHA)
            pygame.draw.circle(ms_rv, (220, 210, 155, a_rv), (mr_rv, mr_rv), mr_rv)
            surf.blit(
                ms_rv,
                (mx_rv - mr_rv, my_rv - mr_rv),
                special_flags=pygame.BLEND_RGBA_ADD,
            )
        pygame.draw.circle(surf, (228, 218, 164), (mx_rv, my_rv), 36)
        pygame.draw.circle(surf, (210, 200, 148), (mx_rv, my_rv), 36, 2)
        pygame.draw.circle(surf, (8, 11, 22), (mx_rv + 18, my_rv - 16), 24)  # crescent

        # Distant bluffs receding in atmospheric haze — 3 layers
        for layer, (b_col, b_freq, b_amp, b_frac) in enumerate(
            [
                ((18, 28, 12), 0.004, 28, 0.44),
                ((14, 22, 10), 0.006, 18, 0.48),
                ((10, 16, 8), 0.009, 12, 0.52),
            ]
        ):
            pts_b = [(0, H)]
            for xi in range(0, W + 4, 4):
                yi_b = int(
                    H * b_frac
                    + math.sin(xi * b_freq) * b_amp
                    + math.sin(xi * b_freq * 2.3) * b_amp * 0.4
                )
                pts_b.append((xi, yi_b))
            pts_b.append((W, H))
            pygame.draw.polygon(surf, b_col, pts_b)
            # Atmospheric haze at top of each bluff
            haze = pygame.Surface((W, 4), pygame.SRCALPHA)
            haze.fill((*b_col, 30))
            surf.blit(haze, (0, int(H * b_frac) - 2))

        # The MISSOURI — vast, full lower half
        river_y = int(H * 0.44)
        self._water_shimmer(surf, W, river_y, H, t, (14, 28, 52), depth=True)
        # Moonpath on water — bright shimmering road
        for mpi in range(18):
            mp_y = river_y + mpi * int((H - river_y) / 18)
            mp_w = max(3, int(30 + mpi * 4))
            mp_x = int(mx_rv + math.sin(t * 0.7 + mpi * 0.3) * (mpi * 3))
            brightness = max(30, 140 - mpi * 7)
            pygame.draw.ellipse(
                surf,
                (brightness, int(brightness * 0.9), int(brightness * 0.6)),
                (mp_x - mp_w, mp_y - 3, mp_w * 2, 6),
            )

        # THREE BOATS on river — keelboat + 2 pirogues, lit by torchlight
        for bi_r, (bfx, bfy, bsc) in enumerate(
            [
                (int(W * 0.18), int(H * 0.465), 0.60),
                (int(W * 0.50), int(H * 0.48), 0.85),
                (int(W * 0.76), int(H * 0.470), 0.56),
            ]
        ):
            bx_r = int(bfx + math.sin(t * 0.35 + bi_r * 1.3) * 4)
            self._keelboat(surf, bx_r, bfy, bsc, t, (136, 16, 16))
            # Torch glow
            self._glow(
                surf, bx_r, bfy - int(50 * bsc), int(W * 0.08), (160, 80, 10), 28
            )

        # NATIVE FIRES on both banks — distant, numerous
        for nf_x, nf_y in [
            (int(W * f), int(H * 0.44)) for f in [0.02, 0.06, 0.10, 0.90, 0.94, 0.98]
        ]:
            self._campfire(surf, nf_x, nf_y, t, seed=nf_x, size=0.8)
            # Tiny figure
            self._person_detailed(
                surf,
                nf_x + 12,
                nf_y,
                0.38,
                (8, 12, 6),
                (100, 80, 50),
                seated=True,
                facing=(1 if nf_x < W // 2 else -1),
            )

        # Foreground bank — we're on the bluff looking down
        fg_pts = [(0, H)]
        for xi in range(0, W + 4, 4):
            yi_fg = int(H * 0.86 + math.sin(xi * 0.018) * 8 + math.sin(xi * 0.06) * 4)
            fg_pts.append((xi, yi_fg))
        fg_pts.append((W, H))
        pygame.draw.polygon(surf, (8, 14, 6), fg_pts)
        # Some tall grass on bank
        for gi in range(0, W, 14):
            gy_g = int(H * 0.84) + random.Random(gi).randint(-4, 4)
            gh_g = random.Random(gi + 1).randint(8, 22)
            pygame.draw.line(
                surf,
                (16, 26, 8),
                (gi, gy_g),
                (gi + random.Random(gi + 2).randint(-4, 4), gy_g - gh_g),
                1,
            )

        draw_text(
            surf,
            "The Louisiana Territory  ·  Spring 1804  ·  2,341 miles of river",
            assets.F["small_i"],
            assets.INK_FAINT,
            (W // 2, H - 18),
            anchor="midbottom",
        )

    # ═══════════════════════════════════════════════════════════════════════════
    #  SCENE 7 — Set Forth
    #  Golden dawn. All three boats. The crowd waving. History beginning.
    # ═══════════════════════════════════════════════════════════════════════════
    def _scene_departure(self, surf, W, H, t):
        # Dawn sky — spectacular gradient
        dawn_stops = [
            (8, 6, 4),
            (18, 12, 6),
            (38, 22, 6),
            (72, 44, 8),
            (110, 68, 10),
            (152, 96, 14),
            (186, 126, 18),
            (208, 148, 24),
            (196, 134, 20),
            (162, 106, 16),
        ]
        self._sky_grad(surf, W, H, dawn_stops, h_end=int(H * 0.52))

        # Clouds lit from below — salmon and gold
        rng_dp = random.Random(33)
        for ci_dp in range(12):
            cx_dp = rng_dp.randint(0, W)
            cy_dp = rng_dp.randint(int(H * 0.06), int(H * 0.36))
            cw_dp = rng_dp.randint(60, 180)
            ch_dp = rng_dp.randint(14, 38)
            sway = int(math.sin(t * 0.2 + ci_dp) * 3)
            # Cloud base dark
            cs_dp = pygame.Surface((cw_dp, ch_dp), pygame.SRCALPHA)
            pygame.draw.ellipse(cs_dp, (120, 80, 20, 60), (0, 0, cw_dp, ch_dp))
            surf.blit(cs_dp, (cx_dp + sway, cy_dp))
            # Cloud top bright
            cs2_dp = pygame.Surface((cw_dp, ch_dp), pygame.SRCALPHA)
            pygame.draw.ellipse(
                cs2_dp, (240, 180, 60, 80), (0, ch_dp // 3, cw_dp, ch_dp * 2 // 3)
            )
            surf.blit(cs2_dp, (cx_dp + sway, cy_dp))

        # THE SUN rising — dramatic, just cresting horizon
        sun_x, sun_y = int(W * 0.54), int(H * 0.50 + math.sin(t * 0.08) * 3)
        # Sun corona — wide golden rays
        for ray in range(28):
            ang_r = math.radians(ray * (360 / 28))
            ray_len = 90 + int(math.sin(t * 1.5 + ray) * 22) + int(ray % 3 * 8)
            ex_r = sun_x + int(math.cos(ang_r) * ray_len)
            ey_r = sun_y + int(math.sin(ang_r) * ray_len)
            brightness_r = max(0, 90 - abs(ray - 14) * 4)
            if brightness_r > 0:
                pygame.draw.line(
                    surf,
                    (brightness_r + 80, brightness_r // 2 + 30, 4),
                    (sun_x, sun_y),
                    (ex_r, ey_r),
                    1,
                )
        # Sun disk — concentric
        for sr in range(52, 0, -8):
            frac_r = (52 - sr) / 52
            r_sun = min(255, int(120 + frac_r * 110))
            g_sun = min(255, int(60 + frac_r * 100))
            b_sun = 4
            pygame.draw.circle(surf, (r_sun, g_sun, b_sun), (sun_x, sun_y), sr)
        # Sun glare
        self._glow(surf, sun_x, sun_y, int(W * 0.28), (220, 140, 30), 50)

        # River — assets.GOLD SHIMMER — entire lower half
        for yi_dp in range(int(H * 0.48), H):
            d_dp = (yi_dp - H * 0.48) / (H * 0.52)
            sh_dp = (
                math.sin(yi_dp * 0.06 + t * 2.8) * 0.4
                + math.sin(yi_dp * 0.11 + t * 1.6) * 0.2
                + 0.5
            )
            r_dp = min(255, max(0, int(52 + sh_dp * 60 - d_dp * 20)))
            g_dp = min(255, max(0, int(36 + sh_dp * 40 - d_dp * 14)))
            b_dp = min(255, max(0, int(8 + sh_dp * 16 - d_dp * 6)))
            pygame.draw.line(surf, (r_dp, g_dp, b_dp), (0, yi_dp), (W, yi_dp))
        # Sun column on water
        for sci in range(22):
            sc_y = int(H * 0.52 + sci * int(H * 0.48 / 22))
            sc_w = max(2, int(18 + sci * 3))
            sc_x = int(sun_x + math.sin(t * 0.8 + sci * 0.25) * (sci * 2))
            pygame.draw.ellipse(
                surf, (180, 120, 20), (sc_x - sc_w, sc_y - 4, sc_w * 2, 8)
            )

        # Treeline silhouette
        tree_pts_dp = [(0, H)]
        for xi_dp in range(0, W + 6, 6):
            base = int(
                H * 0.46 + math.sin(xi_dp * 0.018) * 10 + math.sin(xi_dp * 0.06) * 5
            )
            # Individual tree crowns
            if xi_dp % 18 == 0:
                base -= random.Random(xi_dp).randint(4, 22)
            tree_pts_dp.append((xi_dp, base))
        tree_pts_dp.append((W, H))
        pygame.draw.polygon(surf, (8, 10, 4), tree_pts_dp)
        # Tree trunks
        for ti_dp in range(0, W, 18):
            ty_dp = int(H * 0.46 + math.sin(ti_dp * 0.018) * 10)
            pygame.draw.line(surf, (14, 12, 6), (ti_dp, ty_dp), (ti_dp, ty_dp + 12), 2)

        # THE KEELBOAT — large, central, departing rightward
        kx_dp = int((W * 0.34 + self.frame * 0.18) % (W * 1.4)) - int(W * 0.1)
        ky_dp = int(H * 0.49)
        self._keelboat(surf, kx_dp, ky_dp, 0.96, t, (180, 20, 20))
        # Keelboat golden reflection
        self._glow(surf, kx_dp, ky_dp, int(W * 0.12), (160, 100, 20), 25)
        # Cannon smoke puff (departure salute)
        cannon_x = kx_dp - int(W * 0.12)
        cannon_y = ky_dp - int(H * 0.04)
        for smi in range(5):
            sm_age = (self.frame // 3 + smi * 7) % 40
            sm_x = cannon_x + sm_age * 3 + int(math.sin(sm_age * 0.3) * 8)
            sm_y = cannon_y - sm_age * 2
            sm_r = min(40, 8 + sm_age * 1.5)
            a_sm2 = max(0, 100 - sm_age * 3)
            gs_sm2 = pygame.Surface((int(sm_r) * 2, int(sm_r) * 2), pygame.SRCALPHA)
            pygame.draw.circle(
                gs_sm2, (180, 160, 140, a_sm2), (int(sm_r), int(sm_r)), int(sm_r)
            )
            surf.blit(gs_sm2, (int(sm_x - sm_r), int(sm_y - sm_r)))

        # TWO PIROGUES flanking
        for pri, (pfx, pfy, psc) in enumerate(
            [
                (kx_dp - int(W * 0.18), int(H * 0.492), 0.62),
                (kx_dp + int(W * 0.16), int(H * 0.488), 0.58),
            ]
        ):
            px_dp = pfx + int(math.sin(t * 0.4 + pri) * 4)
            self._keelboat(surf, px_dp, pfy, psc, t, (180, 20, 20))

        # CROWD ON SHORE — waving farewell, prominent
        crowd_y_dp = int(H * 0.46)
        # Ground (shore)
        pygame.draw.rect(
            surf, (14, 18, 8), (0, crowd_y_dp + 2, int(W * 0.46), H - crowd_y_dp - 2)
        )
        pygame.draw.rect(surf, (10, 14, 6), (0, crowd_y_dp + 2, int(W * 0.46), 4))
        for pi_dp in range(38):
            px_dp2 = pi_dp * int(W * 0.46 / 38) + 4
            py_dp = crowd_y_dp + random.Random(pi_dp * 3).randint(0, 6)
            # Wave animation — everyone waves at different phases
            wave_amp = math.sin(t * 2.8 + pi_dp * 0.6) * 10
            coat_c = [(24, 18, 10), (18, 14, 8), (20, 16, 8), (22, 18, 10)][pi_dp % 4]
            self._person_detailed(
                surf,
                px_dp2,
                py_dp,
                0.48,
                coat_c,
                (150, 120, 80),
                seated=False,
                facing=1,
                arm_up=(int(wave_amp) > 2),
            )
            # Hats waving
            if random.Random(pi_dp * 7 + int(t)).randint(0, 3) == 0:
                hat_x = px_dp2 + int(math.sin(t * 3 + pi_dp) * 8)
                hat_y = py_dp - int(0.48 * 64) - int(abs(wave_amp)) * 2
                pygame.draw.ellipse(surf, (14, 10, 6), (hat_x - 8, hat_y - 4, 16, 8))

        # Flags and banners on shore
        for fl_x in [int(W * 0.12), int(W * 0.28), int(W * 0.40)]:
            pygame.draw.line(
                surf, (32, 20, 8), (fl_x, crowd_y_dp - 4), (fl_x, crowd_y_dp - 52), 3
            )
            for fli in range(4):
                fx_fl = fl_x + fli * 10
                crowd_y_dp - 52 + fli * 3 + int(math.sin(t * 3.5 + fli * 0.8) * 5)
                fc_fl = (160, 20, 20) if fli % 2 == 0 else (200, 180, 130)
                pygame.draw.rect(surf, fc_fl, (fx_fl, crowd_y_dp - 52, 10, 16))
            # Stars and stripes hint
            for si_fl in range(3):
                pygame.draw.line(
                    surf,
                    (200, 180, 130),
                    (fl_x + si_fl * 8 + 2, crowd_y_dp - 52),
                    (fl_x + si_fl * 8 + 2, crowd_y_dp - 36),
                    1,
                )

        # Date stamp — dramatic
        dt_dp = assets.F["title"].render(
            "MAY 14, 1804  ·  4 O'CLOCK IN THE AFTERNOON", True, assets.GOLD
        )
        dt_sh = assets.F["title"].render(
            "MAY 14, 1804  ·  4 O'CLOCK IN THE AFTERNOON", True, (0, 0, 0)
        )
        surf.blit(dt_sh, dt_sh.get_rect(centerx=W // 2 + 2, bottom=H - 30))
        surf.blit(dt_dp, dt_dp.get_rect(centerx=W // 2, bottom=H - 30))
        ds_dp = assets.F["body_i"].render(
            "Camp Dubois, Illinois  ·  The Great Adventure Begins",
            True,
            assets.PARCH_EDGE,
        )
        surf.blit(ds_dp, ds_dp.get_rect(centerx=W // 2, bottom=H - 14))

    def handle(self, event):
        if event.type == pygame.KEYDOWN:
            if event.key in (pygame.K_RETURN, pygame.K_SPACE, pygame.K_RIGHT):
                if self.cine_line >= len(self.scene["narration"]):
                    if self.idx < len(assets.CINE_SCENES) - 1:
                        self.advance()
                    else:
                        self.on_done()
                else:
                    # Skip typewriter — show all text immediately
                    self.cine_line = len(self.scene["narration"])
                    self.cine_char = 0
            elif event.key == pygame.K_LEFT:
                self.retreat()
            elif event.key == pygame.K_ESCAPE:
                self.on_done()

        if self.skip_btn.handle(event):
            self.on_done()
        if self.back_btn.handle(event) and self.idx > 0:
            self.retreat()

        if self.idx < len(assets.CINE_SCENES) - 1:
            if self.next_btn.handle(event):
                self.advance()
        else:
            if self.begin_btn.handle(event):
                self.on_done()


# ═══════════════════════════════════════════════════════════════════════════════
#  TITLE SCREEN
