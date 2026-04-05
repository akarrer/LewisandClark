"""Hex map view."""

from __future__ import annotations

import math
import random
from pathlib import Path

import pygame

from lewis_clark import assets
from lewis_clark.hex_grid import (
    hex_neighbours,
    hex_terrain,
    world_to_hex,
    wp_display_name,
)
from lewis_clark.textures import gen_parchment

_FONT_DIR = Path(__file__).resolve().parent.parent / "assets" / "fonts"


class MapView:
    MAP_RECT = pygame.Rect(0, 50, 920, 400)  # overwritten by :meth:`set_map_rect`
    HEX_SIZE  = 80      # circumradius in pixels on the large canvas
    CANVAS_W  = 4600    # pre-rendered map canvas width
    CANVAS_H  = 2500    # pre-rendered map canvas height

    # Terrain colours — rich parchment palette per terrain type
    TERR_FILL = {
        "plains":   (212, 200, 140),
        "river":    (168, 196, 220),
        "mountain": (176, 152, 112),
        "forest":   (148, 176, 120),
        "coast":    (160, 200, 210),
    }
    TERR_BORDER = {
        "plains":   (160, 148,  96),
        "river":    (100, 140, 170),
        "mountain": (120, 100,  72),
        "forest":   ( 96, 128,  80),
        "coast":    (100, 152, 168),
    }
    TERR_ICON = {
        "plains":  "·",
        "river":   "≈",
        "mountain":"▲",
        "forest":  "♣",
        "coast":   "~",
    }

    def __init__(self):
        # Start zoomed to show full map
        self.zoom        = 0.38
        self.pan_x       = 0    # pixel offset into canvas
        self.pan_y       = 0
        self.hover_hex   = None
        self.hover_wp    = None
        self._drag_start = None
        self._drag_pan   = None
        self.frame       = 0
        self._particles  = []
        self._canvas     = None   # lazily built
        self._canvas_dirty = True # rebuild when state changes
        self._map_overlay_us = None  # UI_SCALE used for scaled cartouche / compass cache
        self._scaled_cartouche = None
        self._scaled_compass = None
        self.MAP_RECT = pygame.Rect(
            0, 50, max(120, assets.SW - 500), max(120, assets.SH - 120)
        )

    def set_map_rect(self, rect: pygame.Rect) -> None:
        self.MAP_RECT = pygame.Rect(rect)

    # ── hex pixel geometry ────────────────────────────────────────────────────
    @staticmethod
    def hex_center(col, row, size=None):
        """Pixel centre of hex on the large canvas."""
        s = size or MapView.HEX_SIZE
        x = int(s * math.sqrt(3) * (col + 0.5*(row % 2))) + int(s * math.sqrt(3) * 0.5)
        y = int(s * 1.5 * row) + s
        return x, y

    @staticmethod
    def hex_poly_abs(col, row, size=None, shrink=0):
        """Absolute pixel corners of hex on large canvas."""
        s = (size or MapView.HEX_SIZE) - shrink
        cx, cy = MapView.hex_center(col, row, size or MapView.HEX_SIZE)
        pts = []
        for i in range(6):
            a = math.radians(60*i - 30)
            pts.append((int(cx + s*math.cos(a)), int(cy + s*math.sin(a))))
        return pts

    def canvas_to_screen(self, cx, cy):
        """Canvas pixel → screen pixel."""
        R = self.MAP_RECT
        sx = int((cx - self.pan_x) * self.zoom) + R.x
        sy = int((cy - self.pan_y) * self.zoom) + R.y
        return sx, sy

    def screen_to_canvas(self, sx, sy):
        """Screen pixel → canvas pixel."""
        R = self.MAP_RECT
        cx = (sx - R.x) / self.zoom + self.pan_x
        cy = (sy - R.y) / self.zoom + self.pan_y
        return cx, cy

    def _waypoint_sprite_blt(self, surf, wx2, wy2, wp_type):
        """Blit static 8-bit waypoint art if available; else caller draws vector style."""
        wps = getattr(assets, "IMG_WAYPOINTS", None) or {}
        key = "fort" if wp_type in ("fort", "start") else wp_type
        im = wps.get(key) or wps.get("camp")
        if im is None:
            return False
        iw, ih = im.get_size()
        surf.blit(im, (wx2 - iw // 2, wy2 - ih // 2))
        return True

    def screen_hex(self, sx, sy):
        """Screen pixel → which hex (col, row)."""
        cx, cy = self.screen_to_canvas(sx, sy)
        s = self.HEX_SIZE
        # Invert hex_center: approximate then refine
        best = None; best_d = 1e9
        # Estimate
        row_est = int(cy / (s * 1.5))
        col_est = int((cx - s*math.sqrt(3)*0.5) / (s*math.sqrt(3)) - 0.5*(row_est%2))
        for dr in range(-2, 3):
            for dc in range(-2, 3):
                c2 = col_est+dc; r2 = row_est+dr
                if 0 <= c2 < assets.HEX_COLS and 0 <= r2 < assets.HEX_ROWS:
                    hx, hy = self.hex_center(c2, r2)
                    d = (cx-hx)**2 + (cy-hy)**2
                    if d < best_d: best_d=d; best=(c2,r2)
        return best or (0,0)

    def hex_screen_pos(self, col, row):
        """Screen pixel centre of hex (convenience)."""
        cx, cy = self.hex_center(col, row)
        return self.canvas_to_screen(cx, cy)

    def hex_radius_screen(self):
        """Hex radius in screen pixels at current zoom."""
        return max(4, int(self.HEX_SIZE * self.zoom))

    @staticmethod
    def _map_font(size, bold=False, italic=False):
        """Load a font for map labels, preferring the bundled EB Garamond."""
        garamond = _FONT_DIR / (
            "EBGaramond-Italic.ttf" if italic else "EBGaramond.ttf"
        )
        try:
            if garamond.exists():
                f = pygame.font.Font(str(garamond), size)
                if bold:
                    f.set_bold(True)
                return f
        except Exception:
            pass
        return pygame.font.SysFont("Georgia", size, bold=bold, italic=italic)

    # ── canvas build ──────────────────────────────────────────────────────────
    @staticmethod
    def _catmull_rom(points, steps=14):
        """Smooth curve through points using Catmull-Rom spline."""
        result = []
        n = len(points)
        for i in range(n-1):
            p0 = points[max(0,i-1)]
            p1 = points[i]
            p2 = points[i+1]
            p3 = points[min(n-1,i+2)]
            for t in range(steps):
                tn=t/steps; t2=tn*tn; t3=t2*tn
                x=0.5*((2*p1[0])+(-p0[0]+p2[0])*tn+(2*p0[0]-5*p1[0]+4*p2[0]-p3[0])*t2+(-p0[0]+3*p1[0]-3*p2[0]+p3[0])*t3)
                y=0.5*((2*p1[1])+(-p0[1]+p2[1])*tn+(2*p0[1]-5*p1[1]+4*p2[1]-p3[1])*t2+(-p0[1]+3*p1[1]-3*p2[1]+p3[1])*t3)
                result.append((int(x),int(y)))
        result.append(points[-1])
        return result

    @staticmethod
    def _wobble_pts(pts, seed, amount=3):
        """Add hand-drawn wobble to polygon points."""
        rng = random.Random(seed)
        out = []
        for i, (px, py) in enumerate(pts):
            dx = rng.gauss(0, amount * 0.4)
            dy = rng.gauss(0, amount * 0.4)
            out.append((int(px + dx), int(py + dy)))
        return out

    @staticmethod
    def _draw_hachures(surf, cx, cy, peak_x, peak_y, base_w, col, rng, count=7):
        """Cartographic hachure marks radiating down from a peak."""
        for i in range(count):
            t = (i + 0.5) / count
            bx = peak_x + int((t - 0.5) * base_w * 1.8)
            by = cy + int(base_w * 0.6)
            length = rng.uniform(0.4, 0.8)
            ex = int(peak_x + (bx - peak_x) * length)
            ey = int(peak_y + (by - peak_y) * length)
            pygame.draw.line(surf, col, (peak_x, peak_y), (ex, ey), 1)

    def _build_canvas(self, state):
        """Render the full hex map to a large Surface. Called once, cached."""
        s = state

        surf = pygame.Surface((self.CANVAS_W, self.CANVAS_H))

        if assets.TEX_MAP_PARCHMENT is None:
            assets.TEX_MAP_PARCHMENT = gen_parchment(
                self.CANVAS_W, self.CANVAS_H, seed=55
            )
        surf.blit(assets.TEX_MAP_PARCHMENT, (0, 0))

        water_overlay = pygame.Surface(
            (self.CANVAS_W, self.CANVAS_H), pygame.SRCALPHA
        )
        water_overlay.fill((140, 170, 200, 60))
        surf.blit(water_overlay, (0, 0))

        edge_dark = 80
        for i in range(edge_dark):
            t = 1.0 - i / edge_dark
            a = int(t * t * 50)
            if a < 1:
                continue
            c = (60, 40, 15, a)
            W, H = self.CANVAS_W, self.CANVAS_H
            pygame.draw.line(surf, c, (0, i), (W, i))
            pygame.draw.line(surf, c, (0, H - 1 - i), (W, H - 1 - i))
            pygame.draw.line(surf, c, (i, 0), (i, H))
            pygame.draw.line(surf, c, (W - 1 - i, 0), (W - 1 - i, H))

        # ── 1. Hex terrain fills + textures ───────────────────────────────────
        hex_tiles = getattr(assets, "IMG_TERRAIN_HEX", None) or {}

        for row in range(assets.HEX_ROWS):
            for col in range(assets.HEX_COLS):
                terr = hex_terrain(col, row)
                pts = self.hex_poly_abs(col, row)
                fill = self.TERR_FILL[terr]
                border = self.TERR_BORDER[terr]
                cx, cy = self.hex_center(col, row)

                tile_im = hex_tiles.get(terr)
                if tile_im is not None:
                    tw, th = tile_im.get_size()
                    surf.blit(tile_im, (cx - tw // 2, cy - th // 2))
                else:
                    pygame.draw.polygon(surf, fill, pts)

                rng = random.Random(col * 100 + row * 7)
                proc = tile_im is None
                if proc and terr == "plains":
                    for _ in range(15):
                        gx = cx + rng.randint(-36, 36)
                        gy = cy + rng.randint(-24, 24)
                        ink = (
                            fill[0] - 25 + rng.randint(-5, 5),
                            fill[1] - 18 + rng.randint(-5, 5),
                            fill[2] - 10,
                        )
                        ink = tuple(max(0, min(255, c)) for c in ink)
                        for _ in range(rng.randint(2, 4)):
                            bx = gx + rng.randint(-3, 3)
                            angle = rng.uniform(-0.4, 0.4)
                            blen = rng.randint(5, 12)
                            ex = bx + int(math.sin(angle) * 2)
                            ey = gy - blen
                            pygame.draw.line(surf, ink, (bx, gy), (ex, ey), 1)

                    for _ in range(rng.randint(12, 25)):
                        dx = cx + rng.randint(-34, 34)
                        dy = cy + rng.randint(-22, 22)
                        dc = (
                            fill[0] - 15 + rng.randint(-8, 8),
                            fill[1] - 10 + rng.randint(-8, 8),
                            fill[2] - 5,
                        )
                        dc = tuple(max(0, min(255, c)) for c in dc)
                        surf.set_at((dx, dy), dc)

                    if rng.random() < 0.35:
                        fx = cx + rng.randint(-20, 20)
                        fy = cy + rng.randint(-14, 14)
                        fc = rng.choice([
                            (180, 140, 80), (160, 120, 70), (190, 160, 100),
                        ])
                        pygame.draw.circle(surf, fc, (fx, fy), 2)

                elif proc and terr == "river":
                    for wl in range(-30, 32, 5):
                        wy = cy + wl + int(
                            math.sin((col * 1.3 + row * 0.9) * 0.7) * 5
                        )
                        c_w = (
                            115 + rng.randint(-8, 8),
                            150 + rng.randint(-8, 8),
                            185 + rng.randint(-8, 8),
                        )
                        pygame.draw.line(surf, c_w, (cx - 38, wy), (cx + 38, wy), 1)

                    for wl2 in range(-20, 22, 8):
                        alpha_s = pygame.Surface((50, 3), pygame.SRCALPHA)
                        alpha_s.fill((200, 218, 235, 40))
                        surf.blit(alpha_s, (cx - 25, cy + wl2))

                    for _ in range(3):
                        wx = cx + rng.randint(-30, 30)
                        wy = cy + rng.randint(-20, 20)
                        ww = rng.randint(6, 14)
                        pygame.draw.line(
                            surf, (180, 200, 220),
                            (wx, wy), (wx + ww, wy), 1,
                        )

                elif proc and terr == "mountain":
                    peaks = [(-28, 8), (-6, -10), (16, 4), (30, 12)]
                    for px_m, py_m in peaks[:rng.randint(2, 4)]:
                        mx = cx + px_m
                        my = cy + py_m
                        sz = rng.randint(16, 24)

                        shadow_c = (
                            min(255, fill[0] + 15), fill[1] - 5,
                            max(0, fill[2] - 15),
                        )
                        pygame.draw.polygon(
                            surf, shadow_c,
                            [(mx - sz, my + sz), (mx + 2, my - sz - 6),
                             (mx + sz + 4, my + sz)],
                        )
                        main_c = (
                            fill[0] + 8, fill[1] + 6,
                            min(255, fill[2] + 8),
                        )
                        main_c = tuple(max(0, min(255, c)) for c in main_c)
                        pygame.draw.polygon(
                            surf, main_c,
                            [(mx - sz + 2, my + sz - 2), (mx, my - sz),
                             (mx + sz - 2, my + sz - 2)],
                        )
                        pygame.draw.polygon(
                            surf, border,
                            [(mx - sz + 2, my + sz - 2), (mx, my - sz),
                             (mx + sz - 2, my + sz - 2)], 2,
                        )

                        self._draw_hachures(
                            surf, cx, cy, mx, my - sz, sz,
                            (border[0] - 10, border[1] - 10, border[2]),
                            rng, count=rng.randint(5, 9),
                        )

                        cap_w = rng.randint(5, 8)
                        cap_h = rng.randint(6, 10)
                        pygame.draw.polygon(
                            surf, (240, 238, 234),
                            [(mx - cap_w, my - sz + cap_h),
                             (mx, my - sz - 4),
                             (mx + cap_w, my - sz + cap_h)],
                        )
                        pygame.draw.polygon(
                            surf, (200, 195, 185),
                            [(mx - cap_w, my - sz + cap_h),
                             (mx, my - sz - 4),
                             (mx + cap_w, my - sz + cap_h)], 1,
                        )

                elif proc and terr == "forest":
                    tree_positions = [
                        (-22, -12), (0, -22), (22, -10),
                        (-14, 6), (14, 8), (0, 18),
                        (-28, 0), (28, 2),
                    ]
                    n_trees = rng.randint(4, 7)
                    for tx, ty in tree_positions[:n_trees]:
                        tree_x = cx + tx + rng.randint(-3, 3)
                        tree_y = cy + ty + rng.randint(-3, 3)

                        trunk_h = rng.randint(6, 10)
                        pygame.draw.line(
                            surf, (90, 65, 30),
                            (tree_x, tree_y + 8),
                            (tree_x, tree_y + 8 + trunk_h), 2,
                        )

                        canopy_r = rng.randint(8, 13)
                        canopy_c = (
                            min(255, fill[0] + rng.randint(5, 15)),
                            min(255, fill[1] + rng.randint(8, 18)),
                            fill[2] + rng.randint(0, 8),
                        )
                        canopy_c = tuple(max(0, min(255, c)) for c in canopy_c)
                        pygame.draw.circle(
                            surf, canopy_c,
                            (tree_x, tree_y), canopy_r,
                        )
                        for sub in range(rng.randint(2, 4)):
                            sx = tree_x + rng.randint(-6, 6)
                            sy = tree_y + rng.randint(-6, 4)
                            sr = rng.randint(4, 7)
                            sc = (
                                canopy_c[0] + rng.randint(-10, 10),
                                canopy_c[1] + rng.randint(-10, 10),
                                canopy_c[2] + rng.randint(-5, 5),
                            )
                            sc = tuple(max(0, min(255, c)) for c in sc)
                            pygame.draw.circle(surf, sc, (sx, sy), sr)

                        ink_c = (
                            max(0, fill[0] - 30),
                            max(0, fill[1] - 25),
                            max(0, fill[2] - 15),
                        )
                        pygame.draw.circle(
                            surf, ink_c,
                            (tree_x, tree_y), canopy_r, 1,
                        )

                elif proc and terr == "coast":
                    for wl in range(-24, 26, 8):
                        r_arc = 24 + abs(wl) // 3
                        arc_r = pygame.Rect(cx - r_arc, cy + wl - 4, r_arc * 2, 12)
                        try:
                            pygame.draw.arc(
                                surf, (120, 165, 190), arc_r, 0, math.pi, 2,
                            )
                        except Exception:
                            pass

                    for _ in range(rng.randint(8, 15)):
                        fx = cx + rng.randint(-32, 32)
                        fy = cy + rng.randint(-20, 20)
                        pygame.draw.circle(surf, (190, 210, 225), (fx, fy), 1)

                    for _ in range(3):
                        sx = cx + rng.randint(-28, 28)
                        sy = cy + rng.randint(-16, 16)
                        sw = rng.randint(4, 10)
                        pygame.draw.line(
                            surf, (140, 175, 195),
                            (sx, sy), (sx + sw, sy + rng.randint(-2, 2)), 1,
                        )

                wobbled = self._wobble_pts(pts, col * 31 + row * 97, amount=2)
                bord_alpha = pygame.Surface(
                    (self.HEX_SIZE * 3, self.HEX_SIZE * 3), pygame.SRCALPHA,
                )
                local_wobbled = [
                    (p[0] - cx + self.HEX_SIZE * 3 // 2,
                     p[1] - cy + self.HEX_SIZE * 3 // 2)
                    for p in wobbled
                ]
                pygame.draw.polygon(
                    bord_alpha, (*border, 100), local_wobbled, 1,
                )
                surf.blit(
                    bord_alpha,
                    (cx - self.HEX_SIZE * 3 // 2, cy - self.HEX_SIZE * 3 // 2),
                )

        # ── 2. Smooth river overlays ───────────────────────────────────────────
        RIVER_STYLES = [
            # (shadow_col, main_col, highlight_col, shadow_w, main_w, hi_w, name, name_col)
            ((100,140,190), ( 88,138,195), (210,228,245), 22, 14,  4,
             "Missouri R.", (60,100,160)),
            ((110,148,188), ( 96,144,195), (210,228,240), 18, 11,  3,
             "Platte R.",   (60,100,160)),
            ((108,148,185), ( 90,138,190), (208,226,242), 16, 10,  3,
             "Yellowstone R.",(60,100,160)),
            ((112,148,185), ( 94,140,192), (208,224,240), 14,  9,  2,
             "Arkansas R.", (60,100,160)),
        ]
        for path, (sh_c,mn_c,hi_c,sh_w,mn_w,hi_w,rname,name_c) in zip(assets.RIVER_PATHS, RIVER_STYLES):
            pts_raw = [self.hex_center(c,r) for c,r in path]
            smooth  = self._catmull_rom(pts_raw, steps=16)
            if len(smooth) < 2: continue
            # Shadow (width)
            pygame.draw.lines(surf, sh_c, False, smooth, sh_w)
            # Main river body
            pygame.draw.lines(surf, mn_c, False, smooth, mn_w)
            # Highlight centre
            pygame.draw.lines(surf, hi_c, False, smooth, hi_w)
            try:
                mid = smooth[len(smooth) // 2]
                fn_r = self._map_font(14, italic=True)
                ts_r = fn_r.render(rname, True, name_c)
                ts_sh = fn_r.render(rname, True, (180, 195, 215))
                surf.blit(ts_sh, ts_sh.get_rect(center=(mid[0] + 1, mid[1] - 19)))
                surf.blit(ts_r, ts_r.get_rect(center=(mid[0], mid[1] - 20)))
            except Exception:
                pass

        # ── 3. Mountain ridge decorations (extra hachure on mountain terrain) ──
        ridge_wxy = [(0.13,0.48),(0.14,0.40),(0.15,0.34),(0.16,0.28),(0.17,0.22),
                     (0.18,0.26),(0.19,0.20),(0.20,0.24),(0.21,0.17),(0.22,0.21),
                     (0.23,0.26),(0.24,0.30),(0.25,0.36),(0.26,0.42)]
        for wx,wy in ridge_wxy:
            col_r,row_r = world_to_hex(wx,wy)
            rx,ry = self.hex_center(col_r,row_r)
            # Large back-ridge line
            pygame.draw.line(surf,(120,94,58),(rx-40,ry+14),(rx+40,ry+14),3)
            # Three peaks
            for mi,sz in [(-28,22),(0,28),(28,20)]:
                mx=rx+mi
                pygame.draw.polygon(surf,(150,122,82),[(mx-sz,ry+sz//2+4),(mx,ry-sz),(mx+sz,ry+sz//2+4)])
                pygame.draw.polygon(surf,(100,76,46),[(mx-sz,ry+sz//2+4),(mx,ry-sz),(mx+sz,ry+sz//2+4)],2)
                pygame.draw.polygon(surf,(242,240,236),[(mx-7,ry-sz+9),(mx,ry-sz-4),(mx+7,ry-sz+9)])

        # ── 4. Territory name labels ───────────────────────────────────────────
        TERR_LABEL_POS = {
            "ILLINOIS" :(0.875,0.62), "MISSOURI" :(0.755,0.62), "IOWA"     :(0.655,0.445),
            "NEBRASKA" :(0.540,0.445),"KANSAS"   :(0.540,0.570),"DAKOTA"   :(0.430,0.295),
            "MONTANA"  :(0.290,0.265),"IDAHO"    :(0.158,0.405),"OREGON"   :(0.070,0.345),
            "WASHINGTON":(0.062,0.185),
        }
        try:
            fn_terr = self._map_font(22, italic=True)
            fn_terr_sm = self._map_font(16, italic=True)
            for name, (lx_n, ly_n) in TERR_LABEL_POS.items():
                c_n, r_n = world_to_hex(lx_n, ly_n)
                px_n, py_n = self.hex_center(c_n, r_n)
                fn_use = fn_terr if len(name) <= 8 else fn_terr_sm

                spaced = "  ".join(name)
                ts_sh = fn_use.render(spaced, True, (190, 170, 120))
                surf.blit(ts_sh, ts_sh.get_rect(center=(px_n + 1, py_n + 1)))
                ts_main = fn_use.render(spaced, True, (80, 58, 24))
                surf.blit(ts_main, ts_main.get_rect(center=(px_n, py_n)))
        except Exception:
            pass

        # ── 5. Visited trail ──────────────────────────────────────────────────
        if len(s.hex_trail) >= 2:
            trail_pts = [self.hex_center(c,r) for c,r in s.hex_trail]
            smooth_trail = self._catmull_rom(trail_pts, steps=8)
            # Outer glow
            pygame.draw.lines(surf,(200,120,40),False,smooth_trail,20)
            # Main red ink line
            pygame.draw.lines(surf,(168,52,16),False,smooth_trail,11)
            # Parchment centre
            pygame.draw.lines(surf,(230,190,150),False,smooth_trail,4)
            # Footstep dots at each hex centre
            for pt in trail_pts:
                pygame.draw.circle(surf,(168,52,16),pt,6)
                pygame.draw.circle(surf,(230,190,150),pt,3)

        # ── 6. Waypoint markers ───────────────────────────────────────────────
        try:
            fn_wp_i = self._map_font(12, italic=True)
        except Exception:
            fn_wp_i = None

        for i,wp in enumerate(assets.WAYPOINTS):
            wc,wr = assets.WP_HEX[i]
            wx2,wy2 = self.hex_center(wc,wr)
            wp_type = wp.get("type","camp")

            if not self._waypoint_sprite_blt(surf, wx2, wy2, wp_type):
                # Drop shadow
                pygame.draw.circle(surf,(0,0,0),(wx2+3,wy2+3),24)

                if wp_type in ("fort","start"):
                    sq=26
                    pygame.draw.rect(surf,(218,198,148),(wx2-sq,wy2-sq,sq*2,sq*2))
                    pygame.draw.rect(surf,(68,48,18),(wx2-sq,wy2-sq,sq*2,sq*2),4)
                    # Corner bastions
                    for bx3,by3 in [(wx2-sq,wy2-sq),(wx2+sq,wy2-sq),(wx2-sq,wy2+sq),(wx2+sq,wy2+sq)]:
                        pygame.draw.circle(surf,(68,48,18),(bx3,by3),8)
                        pygame.draw.circle(surf,(218,198,148),(bx3,by3),5)
                    # Flag
                    pygame.draw.line(surf,(68,48,18),(wx2-sq+6,wy2-sq),(wx2-sq+6,wy2-sq-24),2)
                    pygame.draw.polygon(surf,(160,20,20),[(wx2-sq+6,wy2-sq-24),(wx2-sq+22,wy2-sq-16),(wx2-sq+6,wy2-sq-8)])

                elif wp_type == "pass":
                    sz_p=24
                    pygame.draw.polygon(surf,(218,198,148),
                        [(wx2,wy2-sz_p),(wx2+sz_p,wy2),(wx2,wy2+sz_p),(wx2-sz_p,wy2)])
                    pygame.draw.polygon(surf,(68,48,18),
                        [(wx2,wy2-sz_p),(wx2+sz_p,wy2),(wx2,wy2+sz_p),(wx2-sz_p,wy2)],3)
                    # Mountain peak inside
                    pygame.draw.polygon(surf,(100,78,48),[(wx2-10,wy2+8),(wx2,wy2-12),(wx2+10,wy2+8)])

                elif wp_type == "dead_end":
                    pygame.draw.circle(surf,(80,30,30),(wx2,wy2),20)
                    pygame.draw.circle(surf,(120,40,40),(wx2,wy2),20,3)
                    pygame.draw.line(surf,(200,80,80),(wx2-12,wy2-12),(wx2+12,wy2+12),4)
                    pygame.draw.line(surf,(200,80,80),(wx2+12,wy2-12),(wx2-12,wy2+12),4)

                elif wp_type == "junction":
                    # Y-fork symbol
                    pygame.draw.circle(surf,(218,198,148),(wx2,wy2),20)
                    pygame.draw.circle(surf,(68,48,18),(wx2,wy2),20,3)
                    for ang_j in [270,30,150]:
                        ex_j=wx2+int(math.cos(math.radians(ang_j))*16)
                        ey_j=wy2+int(math.sin(math.radians(ang_j))*16)
                        pygame.draw.line(surf,(68,48,18),(wx2,wy2),(ex_j,ey_j),3)

                else:
                    # Camp circle
                    pygame.draw.circle(surf,(218,198,148),(wx2,wy2),22)
                    pygame.draw.circle(surf,(68,48,18),(wx2,wy2),22,3)
                    pygame.draw.circle(surf,(68,48,18),(wx2,wy2),7)

            # Generic label (shown until visited)
            if fn_wp_i:
                generic = assets.WP_GENERIC.get(wp_type,"Settlement")
                ts_g = fn_wp_i.render(generic,True,(90,68,32))
                # Background pill
                g_r = ts_g.get_rect(centerx=wx2,top=wy2+30)
                pill = pygame.Rect(g_r.x-4,g_r.y-2,g_r.w+8,g_r.h+4)
                pygame.draw.rect(surf,(218,200,155),pill,border_radius=3)
                surf.blit(ts_g,g_r)

        # ── 7. Decorative double-line map border ─────────────────────────────
        W, H = self.CANVAS_W, self.CANVAS_H
        pygame.draw.rect(surf, (80, 58, 20), (0, 0, W, H), 5)
        pygame.draw.rect(surf, (120, 90, 35), (8, 8, W - 16, H - 16), 2)
        pygame.draw.rect(surf, (60, 42, 14), (14, 14, W - 28, H - 28), 1)
        for corner_x, corner_y, sx, sy in [
            (14, 14, 1, 1), (W - 14, 14, -1, 1),
            (14, H - 14, 1, -1), (W - 14, H - 14, -1, -1),
        ]:
            for arm_len in [20, 16]:
                pygame.draw.line(
                    surf, (80, 58, 20),
                    (corner_x, corner_y),
                    (corner_x + sx * arm_len, corner_y), 2,
                )
                pygame.draw.line(
                    surf, (80, 58, 20),
                    (corner_x, corner_y),
                    (corner_x, corner_y + sy * arm_len), 2,
                )
            pygame.draw.polygon(
                surf, (140, 100, 30),
                [
                    (corner_x + sx * 3, corner_y + sy * 3),
                    (corner_x + sx * 8, corner_y + sy * 3),
                    (corner_x + sx * 3, corner_y + sy * 8),
                ],
            )

        self._canvas = surf
        self._canvas_dirty = False
        return surf

    # ── particles ─────────────────────────────────────────────────────────────
    def _tick_particles(self, sx, sy):
        if random.random() < 0.35:
            ang = random.uniform(0,math.pi*2); spd=random.uniform(0.4,1.4)
            self._particles.append([sx,sy,math.cos(ang)*spd,math.sin(ang)*spd-1.4,
                                    random.uniform(0.6,1.0),random.uniform(1.5,3.5)])
        alive=[]
        for p in self._particles:
            p[0]+=p[2];p[1]+=p[3];p[4]-=0.018;p[3]-=0.04
            if p[4]>0: alive.append(p)
        self._particles=alive

    def _draw_particles(self,surf):
        for p in self._particles:
            t=p[4]
            pygame.draw.circle(surf,(min(255,int(200+t*55)),min(255,int(t*180)),min(255,int(t*40))),
                               (int(p[0]),int(p[1])),max(1,int(p[5]*t)))

    # ── main draw ─────────────────────────────────────────────────────────────
    def draw(self, surf, state):
        R  = self.MAP_RECT
        z  = self.zoom
        s  = state
        self.frame += 1

        # Rebuild canvas if trail changed (first move)
        if self._canvas is None or self._canvas_dirty:
            self._build_canvas(state)

        clip_save = surf.get_clip()
        surf.set_clip(R)

        # ── Blit zoomed canvas window ─────────────────────────────────────────
        # Calculate which portion of the canvas is visible
        vis_w = int(R.w / z)
        vis_h = int(R.h / z)
        # Clamp pan
        self.pan_x = max(0, min(self.CANVAS_W - vis_w, self.pan_x))
        self.pan_y = max(0, min(self.CANVAS_H - vis_h, self.pan_y))

        src_rect = pygame.Rect(int(self.pan_x), int(self.pan_y), vis_w, vis_h)
        # Scale the visible portion to screen size
        if vis_w > 0 and vis_h > 0:
            try:
                sub = self._canvas.subsurface(
                    src_rect.clip(pygame.Rect(0,0,self.CANVAS_W,self.CANVAS_H)))
                scaled = pygame.transform.scale(sub, (R.w, R.h))
                surf.blit(scaled, R.topleft)
            except Exception as _blit_e:
                surf.fill((80,70,50), R)
                print('MapView blit error:', _blit_e)

        # ── Dynamic overlay — drawn every frame on screen coords ──────────────
        visited_set = set(tuple(h) for h in s.visited_hexes)
        cur_hex     = (s.hex_col, s.hex_row)
        neighbours  = set(hex_neighbours(s.hex_col, s.hex_row))
        pulse       = abs(math.sin(self.frame * 0.07))
        r_sc        = self.hex_radius_screen()

        # ── Fog of war: sepia wash on unvisited hexes ──────────────────────
        for row in range(assets.HEX_ROWS):
            for col in range(assets.HEX_COLS):
                hkey = (col, row)
                if hkey in visited_set or hkey == cur_hex:
                    continue
                if hkey in neighbours:
                    continue
                sx9, sy9 = self.hex_screen_pos(col, row)
                if not R.inflate(r_sc * 4, r_sc * 4).collidepoint(sx9, sy9):
                    continue
                pts_sc = [
                    self.canvas_to_screen(*p)
                    for p in self.hex_poly_abs(col, row)
                ]
                fog_s = pygame.Surface(
                    (r_sc * 4 + 4, r_sc * 4 + 4), pygame.SRCALPHA,
                )
                local_pts = [
                    (p[0] - sx9 + r_sc * 2 + 2, p[1] - sy9 + r_sc * 2 + 2)
                    for p in pts_sc
                ]
                shimmer = int(12 * math.sin(self.frame * 0.06 + col * 0.3 + row * 0.2))
                fog_a = max(120, min(195, 158 + shimmer))
                pygame.draw.polygon(
                    fog_s, (180, 165, 130, fog_a), local_pts,
                )
                surf.blit(fog_s, (sx9 - r_sc * 2 - 2, sy9 - r_sc * 2 - 2))

        if r_sc > 8:
            try:
                fog_font = self._map_font(max(7, int(8 * z)), italic=True)
                fog_rng = random.Random(777)
                for row in range(0, assets.HEX_ROWS, 5):
                    for col in range(0, assets.HEX_COLS, 8):
                        hkey = (col, row)
                        if hkey in visited_set or hkey == cur_hex:
                            continue
                        sx9, sy9 = self.hex_screen_pos(col, row)
                        if not R.collidepoint(sx9, sy9):
                            continue
                        label = fog_rng.choice([
                            "Terra Incognita", "Unexplored",
                            "Parts Unknown", "Uncharted",
                        ])
                        ts = fog_font.render(label, True, (150, 130, 95))
                        surf.blit(ts, ts.get_rect(center=(sx9, sy9)))
            except Exception:
                pass

        for row in range(assets.HEX_ROWS):
            for col in range(assets.HEX_COLS):
                sx9, sy9 = self.hex_screen_pos(col, row)
                if not R.inflate(r_sc*4,r_sc*4).collidepoint(sx9,sy9): continue

                hkey = (col,row)
                is_cur      = hkey == cur_hex
                is_visited  = hkey in visited_set
                is_reachable= hkey in neighbours and not s.game_over
                is_hover    = hkey == self.hover_hex
                pts_sc = [
                    self.canvas_to_screen(*p) for p in self.hex_poly_abs(col, row)
                ]

                if is_cur:
                    # Solid amber hex fill
                    hs = pygame.Surface((r_sc*4+4,r_sc*4+4),pygame.SRCALPHA)
                    local_pts=[(p[0]-sx9+r_sc*2+2,p[1]-sy9+r_sc*2+2) for p in pts_sc]
                    pygame.draw.polygon(hs,(220,155,20,200),local_pts)
                    surf.blit(hs,(sx9-r_sc*2-2,sy9-r_sc*2-2))
                    # Thick bright border
                    pygame.draw.polygon(surf,(255,200,40),pts_sc,max(3,int(4*z)))
                    # Multiple pulsing rings
                    for ring_r_off,ring_w,ring_col in [
                        (int(8+pulse*8),  2, (220,80,20)),
                        (int(16+pulse*6), 2, (220,120,20)),
                        (int(24+pulse*4), 1, (180,100,20)),
                    ]:
                        pygame.draw.circle(surf,ring_col,(sx9,sy9),r_sc+ring_r_off,ring_w)
                    # Bold crosshair lines
                    ch_len = r_sc+18
                    for dx_c,dy_c in [(ch_len,0),(-ch_len,0),(0,ch_len),(0,-ch_len)]:
                        pygame.draw.line(surf,(220,80,20),(sx9,sy9),(sx9+dx_c,sy9+dy_c),3)
                    # Central dot
                    pygame.draw.circle(surf,(255,255,200),(sx9,sy9),max(4,int(6*z)))
                    pygame.draw.circle(surf,(180,60,10),(sx9,sy9),max(4,int(6*z)),1)
                    self._tick_particles(sx9,sy9)

                elif is_reachable:
                    # Gold highlight on reachable hexes
                    hs = pygame.Surface((r_sc*4,r_sc*4),pygame.SRCALPHA)
                    local_pts=[(p[0]-sx9+r_sc*2,p[1]-sy9+r_sc*2) for p in pts_sc]
                    a_val = 120 if is_hover else 60
                    c_val = (220,180,40,a_val) if is_hover else (180,150,30,a_val)
                    pygame.draw.polygon(hs,c_val,local_pts)
                    surf.blit(hs,(sx9-r_sc*2,sy9-r_sc*2))
                    border_col = (240,200,60) if is_hover else (160,128,40)
                    pygame.draw.polygon(surf,border_col,pts_sc,
                                        max(2,int(3*z)) if is_hover else max(1,int(2*z)))

                    # Hover tooltip
                    if is_hover:
                        terr  = hex_terrain(col,row)
                        tdata = assets.TERRAIN_DATA[terr]
                        content = assets.HEX_CONTENTS.get(hkey)
                        parts=[]
                        if tdata["food"]:   parts.append(f"food {tdata['food']:+d}")
                        if tdata["health"]: parts.append(f"hp {tdata['health']:+d}")
                        if tdata["morale"]: parts.append(f"mor {tdata['morale']:+d}")
                        parts.append(f"{tdata['days']}d")
                        tip_lines=[tdata["label"], "  ".join(parts)]
                        if content and content["type"]!="waypoint":
                            tip_lines.append(f"↳ {content.get('name','?')[:28]}")
                        try:
                            ft = self._map_font(max(9, int(10 * z)))
                            tw=max(ft.size(l)[0] for l in tip_lines)+16
                            th=len(tip_lines)*15+10
                            tip_r=pygame.Rect(sx9-tw//2,sy9-r_sc-th-6,tw,th)
                            tip_r.x=max(R.x+2,min(R.right-tw-2,tip_r.x))
                            tip_r.y=max(R.y+2,tip_r.y)
                            pygame.draw.rect(surf,(200,180,120),tip_r,border_radius=3)
                            pygame.draw.rect(surf,(120,90,30),tip_r,1,border_radius=3)
                            for ti2,tl2 in enumerate(tip_lines):
                                col_t2=(58,40,8) if ti2==0 else (100,72,32)
                                ts_t2=ft.render(tl2,True,col_t2)
                                surf.blit(ts_t2,(tip_r.x+7,tip_r.y+5+ti2*15))
                        except: pass

                elif is_visited:
                    # Faint ink border on visited
                    pygame.draw.polygon(surf,(100,80,40),pts_sc,max(1,int(1.5*z)))

                # Content markers on visited hexes (drawn dynamically in case used)
                if is_visited or is_cur:
                    content = assets.HEX_CONTENTS.get(hkey)
                    if content:
                        ctype=content["type"]
                        if ctype=="tribe":
                            pygame.draw.circle(surf,(60,140,80),(sx9,sy9),max(4,int(7*z)))
                            pygame.draw.circle(surf,(30,90,50),(sx9,sy9),max(4,int(7*z)),1)
                        elif ctype=="resource":
                            already=any(tuple(u)==(col,row) for u in s.used_resources)
                            if not already:
                                pygame.draw.circle(surf,(200,160,30),(sx9,sy9),max(3,int(5*z)))
                        elif ctype=="rumour":
                            pygame.draw.circle(surf,(160,100,160),(sx9,sy9),max(3,int(4*z)))

        # ── Waypoint markers — dynamic overlay (show revealed names etc.) ─────
        for i,wp in enumerate(assets.WAYPOINTS):
            wc,wr = assets.WP_HEX[i]
            sx9,sy9 = self.hex_screen_pos(wc,wr)
            if not R.collidepoint(sx9,sy9): continue
            sz9 = max(8,int(22*z))
            is_cur_wp  = i==s.current_wp
            is_vis_wp  = i<s.current_wp or tuple(assets.WP_HEX[i]) in visited_set
            is_hov_wp  = (wc,wr)==self.hover_hex
            wp_type    = wp.get("type","camp")
            is_dead    = wp_type=="dead_end" and wp["revealed"]

            # Pulsing ring for current
            if is_cur_wp:
                pr2=int(sz9+5+pulse*7)
                pygame.draw.circle(surf,(200,60,20),(sx9,sy9),pr2,3)
            elif is_hov_wp and is_vis_wp:
                pygame.draw.circle(surf,(220,180,40),(sx9,sy9),sz9+4,2)

            # Name label — revealed or generic
            show_lbl = is_hov_wp or is_cur_wp or is_vis_wp or z>=0.4
            if show_lbl:
                disp = wp_display_name(i, s.visited_hexes)
                try:
                    fw = self._map_font(max(8, int(12 * z)), bold=is_cur_wp)
                    lbl_col=(180,40,20) if is_cur_wp else ((120,40,40) if is_dead else (58,40,8))
                    box_w=fw.size(disp)[0]+14
                    lbl_y=sy9-sz9-20 if sy9>R.y+50 else sy9+sz9+6
                    box_r=pygame.Rect(sx9-box_w//2,lbl_y-4,box_w,fw.get_height()+8)
                    pygame.draw.rect(surf,(230,215,170),box_r,border_radius=3)
                    border_c=(180,40,20) if is_cur_wp else ((100,30,30) if is_dead else (100,75,30))
                    pygame.draw.rect(surf,border_c,box_r,1,border_radius=3)
                    ts_lbl=fw.render(disp,True,lbl_col)
                    surf.blit(ts_lbl,ts_lbl.get_rect(center=(sx9,lbl_y+fw.get_height()//2+2)))
                except: pass

        # ── Particles ─────────────────────────────────────────────────────────
        self._draw_particles(surf)

        us = float(getattr(assets, "UI_SCALE", 1.0))

        # Zoom label metrics (scaled with window — keeps cartouche / zoom spacing)
        zi_w = max(80, int(round(120 * us)))
        zi_h = max(8, int(round(12 * us)))
        fz_sz = max(10, int(round(15 * us)))
        try:
            fz = self._map_font(fz_sz)
        except Exception:
            fz = self._map_font(max(8, fz_sz - 1))
        zi_lbl_h = fz.get_height() + max(3, int(round(5 * us)))

        # ── Louisiana Territory cartouche (static PNG; bottom-left, above zoom)
        cart_img = getattr(assets, "IMG_LOUISIANA_CARTOUCHE", None)
        if cart_img is None:
            if not hasattr(self, "_louisiana_cartouche_fallback"):
                from lewis_clark.louisiana_cartouche import (
                    render_louisiana_cartouche_surface,
                )

                self._louisiana_cartouche_fallback = render_louisiana_cartouche_surface()
            cart_img = self._louisiana_cartouche_fallback
        # Overlay size vs UI_SCALE: cartouche −2/3 area (×⅓), compass −¼ (×¾)
        _cart_us = us * (1.0 / 3.0)
        _rose_us = us * 0.75
        if self._map_overlay_us != us:
            self._map_overlay_us = us
            ctw, cth = cart_img.get_size()
            self._scaled_cartouche = pygame.transform.smoothscale(
                cart_img,
                (
                    max(1, int(round(ctw * _cart_us))),
                    max(1, int(round(cth * _cart_us))),
                ),
            )
            rose = getattr(assets, "IMG_COMPASS_ROSE", None)
            if rose is None:
                if not hasattr(self, "_compass_rose_fallback"):
                    from lewis_clark.compass_rose import render_compass_rose_surface

                    self._compass_rose_fallback = render_compass_rose_surface(48)
                rose = self._compass_rose_fallback
            iw0, ih0 = rose.get_size()
            self._scaled_compass = pygame.transform.smoothscale(
                rose,
                (
                    max(1, int(round(iw0 * _rose_us))),
                    max(1, int(round(ih0 * _rose_us))),
                ),
            )
        cart_draw = self._scaled_cartouche
        rose_draw = self._scaled_compass
        sch = cart_draw.get_height()
        gap_cz = max(4, int(round(10 * us)))
        cart_x = R.x + max(6, int(round(10 * us)))
        zoom_stack = zi_lbl_h + zi_h + max(6, int(round(10 * us)))
        cart_y = R.bottom - zoom_stack - gap_cz - sch
        cart_y = max(R.y + max(4, int(round(8 * us))), cart_y)
        surf.blit(cart_draw, (cart_x, cart_y))

        # ── Compass rose (static PNG; procedural fallback if missing) ───────
        iw2, ih2 = rose_draw.get_size()
        off_c = max(16, int(round(62 * _rose_us)))
        cx = R.right - off_c
        cy = R.bottom - off_c
        surf.blit(rose_draw, (cx - iw2 // 2, cy - ih2 // 2))

        # ── Zoom indicator (bottom-left of map) ──────────────────────────────
        zoom_pct = int(self.zoom / 1.8 * 100)
        zi_x = R.x + max(6, int(round(10 * us)))
        zi_y = R.bottom - zi_h - max(6, int(round(10 * us)))
        pygame.draw.rect(surf, (100, 84, 50), (zi_x, zi_y, zi_w, zi_h), border_radius=2)
        pygame.draw.rect(
            surf, (200, 172, 100), (zi_x, zi_y, int(zi_w * zoom_pct / 100), zi_h), border_radius=2
        )
        pygame.draw.rect(surf, (140, 112, 60), (zi_x, zi_y, zi_w, zi_h), 1, border_radius=2)
        try:
            lbl = fz.render("ZOOM  scroll\u2195  R=reset", True, (42, 32, 14))
            lbl_sh = fz.render("ZOOM  scroll\u2195  R=reset", True, (220, 200, 150))
            ly = zi_y - zi_lbl_h
            surf.blit(lbl_sh, (zi_x + 1, ly + 1))
            surf.blit(lbl, (zi_x, ly))
        except Exception:
            pass

        surf.set_clip(clip_save)
        pygame.draw.rect(surf, (60, 42, 14), R.inflate(2, 2), 3)
        pygame.draw.rect(surf, assets.UI_BORDER, R, 1)

    # ── handle ────────────────────────────────────────────────────────────────
    def handle(self, event, state, on_hex_click):
        R    = self.MAP_RECT
        mpos = pygame.mouse.get_pos()
        z    = self.zoom

        if event.type == pygame.MOUSEMOTION:
            self.hover_hex=None; self.hover_wp=None
            if R.collidepoint(mpos):
                hc=self.screen_hex(*mpos)
                if hc and 0 <= hc[0] < assets.HEX_COLS and 0 <= hc[1] < assets.HEX_ROWS:
                    self.hover_hex=hc
                if self._drag_start:
                    dx=(mpos[0]-self._drag_start[0])/z
                    dy=(mpos[1]-self._drag_start[1])/z
                    self.pan_x=max(0,self._drag_pan[0]-dx)
                    self.pan_y=max(0,self._drag_pan[1]-dy)

        if event.type==pygame.MOUSEBUTTONDOWN and R.collidepoint(mpos):
            if event.button==3:
                self._drag_start=mpos; self._drag_pan=(self.pan_x,self.pan_y)
            elif event.button==1:
                hc=self.screen_hex(*mpos)
                if hc: on_hex_click(*hc)

        if event.type==pygame.MOUSEBUTTONUP and event.button==3:
            self._drag_start=None

        if event.type==pygame.MOUSEWHEEL and R.collidepoint(mpos):
            # Zoom toward mouse cursor, clamped range
            wx0,wy0=self.screen_to_canvas(*mpos)
            factor=1.2 if event.y>0 else 1/1.2
            self.zoom=max(0.18,min(1.8,z*factor))
            sx_off=mpos[0]-R.x; sy_off=mpos[1]-R.y
            self.pan_x=max(0,wx0-sx_off/self.zoom)
            self.pan_y=max(0,wy0-sy_off/self.zoom)

    def zoom_in(self):
        R = self.MAP_RECT
        cx = self.pan_x + (R.w/self.zoom)/2
        cy = self.pan_y + (R.h/self.zoom)/2
        self.zoom = min(1.8, self.zoom * 1.25)
        self.pan_x = max(0, cx - (R.w/self.zoom)/2)
        self.pan_y = max(0, cy - (R.h/self.zoom)/2)

    def zoom_out(self):
        R = self.MAP_RECT
        cx = self.pan_x + (R.w/self.zoom)/2
        cy = self.pan_y + (R.h/self.zoom)/2
        self.zoom = max(0.18, self.zoom / 1.25)
        self.pan_x = max(0, cx - (R.w/self.zoom)/2)
        self.pan_y = max(0, cy - (R.h/self.zoom)/2)

    def zoom_reset(self):
        self.zoom = 0.38
        sx, sy = self.hex_center(*assets.WP_HEX[0])   # Camp Dubois
        R = self.MAP_RECT
        self.pan_x = max(0, sx - (R.w/self.zoom)/2)
        self.pan_y = max(0, sy - (R.h/self.zoom)/2)

    def invalidate(self):
        """Call after trail/visited changes to rebuild canvas."""
        self._canvas_dirty=True

    def centre_on_hex(self, col, row):
        """Pan map so hex (col,row) is centred in the viewport."""
        R = self.MAP_RECT
        cx, cy = self.hex_center(col, row)
        self.pan_x = max(0, cx - (R.w / self.zoom) / 2)
        self.pan_y = max(0, cy - (R.h / self.zoom) / 2)

