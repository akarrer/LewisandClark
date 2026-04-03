"""Hex map view."""

from __future__ import annotations

import math
import random

import pygame

from lewis_clark import assets
from lewis_clark.hex_grid import (
    hex_neighbours,
    hex_terrain,
    world_to_hex,
    wp_display_name,
)


class MapView:
    MAP_RECT = pygame.Rect(0, 50, 920, assets.SH - 50)
    HEX_SIZE = 80  # circumradius in pixels on the large canvas
    CANVAS_W = 4600  # pre-rendered map canvas width
    CANVAS_H = 2500  # pre-rendered map canvas height

    # Terrain colours — rich parchment palette per terrain type
    TERR_FILL = {
        "plains": (212, 200, 140),
        "river": (168, 196, 220),
        "mountain": (176, 152, 112),
        "forest": (148, 176, 120),
        "coast": (160, 200, 210),
    }
    TERR_BORDER = {
        "plains": (160, 148, 96),
        "river": (100, 140, 170),
        "mountain": (120, 100, 72),
        "forest": (96, 128, 80),
        "coast": (100, 152, 168),
    }
    TERR_ICON = {
        "plains": "·",
        "river": "≈",
        "mountain": "▲",
        "forest": "♣",
        "coast": "~",
    }

    def __init__(self):
        # Start zoomed to show full map
        self.zoom = 0.22
        self.pan_x = 0  # pixel offset into canvas
        self.pan_y = 0
        self.hover_hex = None
        self.hover_wp = None
        self._drag_start = None
        self._drag_pan = None
        self.frame = 0
        self._particles = []
        self._canvas = None  # lazily built
        self._canvas_dirty = True  # rebuild when state changes

    # ── hex pixel geometry ────────────────────────────────────────────────────
    @staticmethod
    def hex_center(col, row, size=None):
        """Pixel centre of hex on the large canvas."""
        s = size or MapView.HEX_SIZE
        x = int(s * math.sqrt(3) * (col + 0.5 * (row % 2))) + int(
            s * math.sqrt(3) * 0.5
        )
        y = int(s * 1.5 * row) + s
        return x, y

    @staticmethod
    def hex_poly_abs(col, row, size=None, shrink=0):
        """Absolute pixel corners of hex on large canvas."""
        s = (size or MapView.HEX_SIZE) - shrink
        cx, cy = MapView.hex_center(col, row, size or MapView.HEX_SIZE)
        pts = []
        for i in range(6):
            a = math.radians(60 * i - 30)
            pts.append((int(cx + s * math.cos(a)), int(cy + s * math.sin(a))))
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

    def screen_hex(self, sx, sy):
        """Screen pixel → which hex (col, row)."""
        cx, cy = self.screen_to_canvas(sx, sy)
        s = self.HEX_SIZE
        # Invert hex_center: approximate then refine
        best = None
        best_d = 1e9
        # Estimate
        row_est = int(cy / (s * 1.5))
        col_est = int(
            (cx - s * math.sqrt(3) * 0.5) / (s * math.sqrt(3)) - 0.5 * (row_est % 2)
        )
        for dr in range(-2, 3):
            for dc in range(-2, 3):
                c2 = col_est + dc
                r2 = row_est + dr
                if 0 <= c2 < assets.HEX_COLS and 0 <= r2 < assets.HEX_ROWS:
                    hx, hy = self.hex_center(c2, r2)
                    d = (cx - hx) ** 2 + (cy - hy) ** 2
                    if d < best_d:
                        best_d = d
                        best = (c2, r2)
        return best or (0, 0)

    def hex_screen_pos(self, col, row):
        """Screen pixel centre of hex (convenience)."""
        cx, cy = self.hex_center(col, row)
        return self.canvas_to_screen(cx, cy)

    def hex_radius_screen(self):
        """Hex radius in screen pixels at current zoom."""
        return max(4, int(self.HEX_SIZE * self.zoom))

    # ── canvas build ──────────────────────────────────────────────────────────
    def _build_canvas(self, state):
        """Render the full hex map to a large Surface. Called once, cached."""
        s = state
        set(tuple(h) for h in s.visited_hexes)

        surf = pygame.Surface((self.CANVAS_W, self.CANVAS_H))

        # Background — deep water / blank parchment
        surf.fill((168, 188, 208))

        # ── Draw every hex ────────────────────────────────────────────────────
        for row in range(assets.HEX_ROWS):
            for col in range(assets.HEX_COLS):
                terr = hex_terrain(col, row)
                pts = self.hex_poly_abs(col, row)
                self.hex_poly_abs(col, row, shrink=2)
                fill = self.TERR_FILL[terr]
                border = self.TERR_BORDER[terr]

                # Base fill
                pygame.draw.polygon(surf, fill, pts)

                # Texture — subtle noise per terrain
                cx, cy = self.hex_center(col, row)
                if terr == "plains":
                    # Grass tufts — small dots
                    rng = random.Random(col * 100 + row)
                    for _ in range(6):
                        dx = rng.randint(-28, 28)
                        dy = rng.randint(-16, 16)
                        r_dot = rng.randint(2, 4)
                        c_dot = (fill[0] - 12, fill[1] - 8, fill[2] - 6)
                        pygame.draw.circle(surf, c_dot, (cx + dx, cy + dy), r_dot)
                elif terr == "river":
                    # Water lines
                    for wl in range(-20, 22, 8):
                        wave_y = cy + wl + int(math.sin((col + row) * 0.8) * 3)
                        pygame.draw.line(
                            surf,
                            (140, 172, 200),
                            (cx - 30, wave_y),
                            (cx + 30, wave_y),
                            1,
                        )
                elif terr == "mountain":
                    # Mountain hachure triangles
                    for mi in range(3):
                        mx = cx + (mi - 1) * 22
                        my = cy + 8
                        sz = 16
                        pygame.draw.polygon(
                            surf,
                            (196, 172, 128),
                            [(mx - sz, my + sz), (mx, my - sz), (mx + sz, my + sz)],
                        )
                        pygame.draw.polygon(
                            surf,
                            (140, 116, 80),
                            [(mx - sz, my + sz), (mx, my - sz), (mx + sz, my + sz)],
                            2,
                        )
                        pygame.draw.polygon(
                            surf,
                            (230, 226, 218),
                            [
                                (mx - 6, my - sz + 6),
                                (mx, my - sz - 2),
                                (mx + 6, my - sz + 6),
                            ],
                        )
                elif terr == "forest":
                    # Tree symbols
                    for ti in range(4):
                        tx = cx + (ti % 2) * 26 - 13
                        ty = cy + (ti // 2) * 22 - 11
                        pygame.draw.polygon(
                            surf,
                            (96, 140, 80),
                            [(tx - 10, ty + 8), (tx, ty - 12), (tx + 10, ty + 8)],
                        )
                        pygame.draw.line(
                            surf, (72, 52, 24), (tx, ty + 8), (tx, ty + 16), 3
                        )
                elif terr == "coast":
                    # Wave pattern
                    for wl in range(-18, 20, 9):
                        pygame.draw.arc(
                            surf,
                            (120, 168, 188),
                            (cx - 22, cy + wl - 4, 44, 12),
                            0,
                            math.pi,
                            2,
                        )

                # Hex border
                pygame.draw.polygon(surf, border, pts, 2)

                # Terrain icon — centre of hex
                try:
                    fi = pygame.font.SysFont("Georgia", 18, bold=True)
                    icon = self.TERR_ICON[terr]
                    ts = fi.render(
                        icon,
                        True,
                        (
                            max(0, border[0] - 20),
                            max(0, border[1] - 20),
                            max(0, border[2] - 20),
                        ),
                    )
                    surf.blit(ts, ts.get_rect(center=(cx, cy + 2)))
                except:
                    pass

        # ── River corridors — blue ink lines over hex grid ────────────────────
        INK_RIVER = (80, 120, 168)
        for path in assets.RIVER_PATHS:
            pts_r = [self.hex_center(c, r) for c, r in path]
            if len(pts_r) >= 2:
                pygame.draw.lines(surf, (180, 208, 228), False, pts_r, 14)
                pygame.draw.lines(surf, INK_RIVER, False, pts_r, 5)
                pygame.draw.lines(surf, (200, 220, 240), False, pts_r, 2)

        # ── Mountain ridge symbols on map ─────────────────────────────────────
        ridge = [
            (0.13, 0.48),
            (0.14, 0.40),
            (0.15, 0.34),
            (0.16, 0.28),
            (0.17, 0.22),
            (0.18, 0.26),
            (0.19, 0.20),
            (0.20, 0.24),
            (0.21, 0.17),
            (0.22, 0.21),
            (0.23, 0.26),
            (0.24, 0.30),
            (0.25, 0.36),
            (0.26, 0.42),
        ]
        for wx, wy in ridge[::2]:
            col_r, row_r = world_to_hex(wx, wy)
            rx, ry = self.hex_center(col_r, row_r)
            for mi in [-1, 0, 1]:
                mx = rx + mi * 26
                sz = 18
                pygame.draw.polygon(
                    surf,
                    (160, 136, 96),
                    [(mx - sz, ry + sz // 2), (mx, ry - sz), (mx + sz, ry + sz // 2)],
                )
                pygame.draw.polygon(
                    surf,
                    (100, 78, 52),
                    [(mx - sz, ry + sz // 2), (mx, ry - sz), (mx + sz, ry + sz // 2)],
                    2,
                )
                pygame.draw.polygon(
                    surf,
                    (240, 238, 232),
                    [(mx - 5, ry - sz + 6), (mx, ry - sz - 3), (mx + 5, ry - sz + 6)],
                )

        # ── Territory labels ──────────────────────────────────────────────────
        TERR_LABEL_POS = {
            "Illinois": (0.875, 0.62),
            "Missouri": (0.755, 0.62),
            "Iowa": (0.655, 0.445),
            "Nebraska": (0.540, 0.445),
            "Kansas": (0.540, 0.570),
            "Dakota": (0.430, 0.295),
            "Montana": (0.290, 0.265),
            "Idaho": (0.158, 0.405),
            "Oregon": (0.070, 0.345),
            "Washington": (0.062, 0.185),
        }
        for name, (lx_n, ly_n) in TERR_LABEL_POS.items():
            c_n, r_n = world_to_hex(lx_n, ly_n)
            px_n, py_n = self.hex_center(c_n, r_n)
            try:
                fn = pygame.font.SysFont("Georgia", 22, italic=True)
                ts_sh = fn.render(name.upper(), True, (180, 160, 110))
                ts_lbl = fn.render(name.upper(), True, (80, 58, 24))
                surf.blit(ts_sh, ts_sh.get_rect(center=(px_n + 1, py_n + 1)))
                surf.blit(ts_lbl, ts_lbl.get_rect(center=(px_n, py_n)))
            except:
                pass

        # ── Coord grid ────────────────────────────────────────────────────────
        GRID_COL = (154, 140, 100)
        for col in range(0, assets.HEX_COLS, 4):
            cx2, _ = self.hex_center(col, 0)
            pygame.draw.line(surf, GRID_COL, (cx2, 0), (cx2, self.CANVAS_H), 1)
        for row in range(0, assets.HEX_ROWS, 4):
            _, ry2 = self.hex_center(0, row)
            pygame.draw.line(surf, GRID_COL, (0, ry2), (self.CANVAS_W, ry2), 1)

        # ── Visited trail — drawn on canvas so it persists ────────────────────
        if len(s.hex_trail) >= 2:
            trail_pts = [self.hex_center(c, r) for c, r in s.hex_trail]
            pygame.draw.lines(surf, (160, 56, 20), False, trail_pts, 8)
            pygame.draw.lines(surf, (220, 180, 140), False, trail_pts, 3)

        # ── Static waypoint markers on canvas ────────────────────────────────
        for i, wp in enumerate(assets.WAYPOINTS):
            wc, wr = assets.WP_HEX[i]
            wx2, wy2 = self.hex_center(wc, wr)
            wp_type = wp.get("type", "camp")
            # Draw settlement icon based on type
            if wp_type in ("fort", "start"):
                # Square fort symbol
                sq = 22
                pygame.draw.rect(
                    surf, (210, 190, 140), (wx2 - sq, wy2 - sq, sq * 2, sq * 2)
                )
                pygame.draw.rect(
                    surf, (80, 58, 24), (wx2 - sq, wy2 - sq, sq * 2, sq * 2), 3
                )
                # Bastions at corners
                for bx2, by2 in [
                    (wx2 - sq, wy2 - sq),
                    (wx2 + sq, wy2 - sq),
                    (wx2 - sq, wy2 + sq),
                    (wx2 + sq, wy2 + sq),
                ]:
                    pygame.draw.circle(surf, (80, 58, 24), (bx2, by2), 6)
                    pygame.draw.circle(surf, (210, 190, 140), (bx2, by2), 4)
            elif wp_type == "pass":
                # Diamond pass symbol
                sz_p = 20
                pygame.draw.polygon(
                    surf,
                    (210, 190, 140),
                    [
                        (wx2, wy2 - sz_p),
                        (wx2 + sz_p, wy2),
                        (wx2, wy2 + sz_p),
                        (wx2 - sz_p, wy2),
                    ],
                )
                pygame.draw.polygon(
                    surf,
                    (80, 58, 24),
                    [
                        (wx2, wy2 - sz_p),
                        (wx2 + sz_p, wy2),
                        (wx2, wy2 + sz_p),
                        (wx2 - sz_p, wy2),
                    ],
                    2,
                )
            elif wp_type == "dead_end":
                # X mark
                pygame.draw.line(
                    surf, (140, 60, 60), (wx2 - 18, wy2 - 18), (wx2 + 18, wy2 + 18), 4
                )
                pygame.draw.line(
                    surf, (140, 60, 60), (wx2 + 18, wy2 - 18), (wx2 - 18, wy2 + 18), 4
                )
            else:
                # Circle camp marker
                pygame.draw.circle(surf, (210, 190, 140), (wx2, wy2), 18)
                pygame.draw.circle(surf, (80, 58, 24), (wx2, wy2), 18, 3)
                pygame.draw.circle(surf, (80, 58, 24), (wx2, wy2), 6)

            # Generic name label below marker (revealed or not)
            try:
                fl_w = pygame.font.SysFont("Georgia", 16, italic=True)
                generic = assets.WP_GENERIC.get(wp_type, "Settlement")
                ts_g = fl_w.render(generic, True, (100, 78, 40))
                surf.blit(ts_g, ts_g.get_rect(centerx=wx2, top=wy2 + 26))
            except:
                pass

        # ── Cartouche bottom-left ─────────────────────────────────────────────
        cart_x2 = 20
        cart_y2 = self.CANVAS_H - 150
        cart_w2 = 340
        cart_h2 = 120
        pygame.draw.rect(surf, (200, 180, 120), (cart_x2, cart_y2, cart_w2, cart_h2))
        pygame.draw.rect(surf, (60, 44, 16), (cart_x2, cart_y2, cart_w2, cart_h2), 4)
        pygame.draw.rect(
            surf,
            (80, 60, 20),
            (cart_x2 + 6, cart_y2 + 6, cart_w2 - 12, cart_h2 - 12),
            2,
        )
        try:
            fc_t = pygame.font.SysFont("Georgia", 13, italic=True)
            fc_b = pygame.font.SysFont("Georgia", 18, bold=True)
            for cy2_off, txt2, fn2 in [
                (16, "MAP of the", fc_t),
                (36, "LOUISIANA TERRITORY", fc_b),
                (58, "Explored by Capts LEWIS & CLARK", fc_t),
                (76, "By order of President Jefferson", fc_t),
                (96, "Anno Domini MDCCCIV", fc_t),
            ]:
                col2 = (40, 28, 8) if fn2 == fc_b else (70, 52, 18)
                ts2 = fn2.render(txt2, True, col2)
                surf.blit(
                    ts2,
                    ts2.get_rect(centerx=cart_x2 + cart_w2 // 2, top=cart_y2 + cy2_off),
                )
        except:
            pass

        self._canvas = surf
        self._canvas_dirty = False
        return surf

    # ── particles ─────────────────────────────────────────────────────────────
    def _tick_particles(self, sx, sy):
        if random.random() < 0.35:
            ang = random.uniform(0, math.pi * 2)
            spd = random.uniform(0.4, 1.4)
            self._particles.append(
                [
                    sx,
                    sy,
                    math.cos(ang) * spd,
                    math.sin(ang) * spd - 1.4,
                    random.uniform(0.6, 1.0),
                    random.uniform(1.5, 3.5),
                ]
            )
        alive = []
        for p in self._particles:
            p[0] += p[2]
            p[1] += p[3]
            p[4] -= 0.018
            p[3] -= 0.04
            if p[4] > 0:
                alive.append(p)
        self._particles = alive

    def _draw_particles(self, surf):
        for p in self._particles:
            t = p[4]
            pygame.draw.circle(
                surf,
                (
                    min(255, int(200 + t * 55)),
                    min(255, int(t * 180)),
                    min(255, int(t * 40)),
                ),
                (int(p[0]), int(p[1])),
                max(1, int(p[5] * t)),
            )

    # ── main draw ─────────────────────────────────────────────────────────────
    def draw(self, surf, state):
        R = self.MAP_RECT
        z = self.zoom
        s = state
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
                    src_rect.clip(pygame.Rect(0, 0, self.CANVAS_W, self.CANVAS_H))
                )
                scaled = pygame.transform.scale(sub, (R.w, R.h))
                surf.blit(scaled, R.topleft)
            except Exception as _blit_e:
                surf.fill((80, 70, 50), R)
                print("MapView blit error:", _blit_e)

        # ── Dynamic overlay — drawn every frame on screen coords ──────────────
        visited_set = set(tuple(h) for h in s.visited_hexes)
        cur_hex = (s.hex_col, s.hex_row)
        neighbours = set(hex_neighbours(s.hex_col, s.hex_row))
        pulse = abs(math.sin(self.frame * 0.07))
        r_sc = self.hex_radius_screen()

        for row in range(assets.HEX_ROWS):
            for col in range(assets.HEX_COLS):
                sx9, sy9 = self.hex_screen_pos(col, row)
                if not R.inflate(r_sc * 4, r_sc * 4).collidepoint(sx9, sy9):
                    continue

                hkey = (col, row)
                is_cur = hkey == cur_hex
                is_visited = hkey in visited_set
                is_reachable = hkey in neighbours and not s.game_over
                is_hover = hkey == self.hover_hex
                pts_sc = [
                    self.canvas_to_screen(*p) for p in self.hex_poly_abs(col, row)
                ]
                [
                    self.canvas_to_screen(*p)
                    for p in self.hex_poly_abs(col, row, shrink=4)
                ]

                if is_cur:
                    # Solid amber hex fill
                    hs = pygame.Surface((r_sc * 4 + 4, r_sc * 4 + 4), pygame.SRCALPHA)
                    local_pts = [
                        (p[0] - sx9 + r_sc * 2 + 2, p[1] - sy9 + r_sc * 2 + 2)
                        for p in pts_sc
                    ]
                    pygame.draw.polygon(hs, (220, 155, 20, 200), local_pts)
                    surf.blit(hs, (sx9 - r_sc * 2 - 2, sy9 - r_sc * 2 - 2))
                    # Thick bright border
                    pygame.draw.polygon(
                        surf, (255, 200, 40), pts_sc, max(3, int(4 * z))
                    )
                    # Multiple pulsing rings
                    for ring_r_off, ring_w, ring_col in [
                        (int(8 + pulse * 8), 2, (220, 80, 20)),
                        (int(16 + pulse * 6), 2, (220, 120, 20)),
                        (int(24 + pulse * 4), 1, (180, 100, 20)),
                    ]:
                        pygame.draw.circle(
                            surf, ring_col, (sx9, sy9), r_sc + ring_r_off, ring_w
                        )
                    # Bold crosshair lines
                    ch_len = r_sc + 18
                    for dx_c, dy_c in [
                        (ch_len, 0),
                        (-ch_len, 0),
                        (0, ch_len),
                        (0, -ch_len),
                    ]:
                        pygame.draw.line(
                            surf, (220, 80, 20), (sx9, sy9), (sx9 + dx_c, sy9 + dy_c), 3
                        )
                    # Central dot
                    pygame.draw.circle(
                        surf, (255, 255, 200), (sx9, sy9), max(4, int(6 * z))
                    )
                    pygame.draw.circle(
                        surf, (180, 60, 10), (sx9, sy9), max(4, int(6 * z)), 1
                    )
                    self._tick_particles(sx9, sy9)

                elif is_reachable:
                    # Gold highlight on reachable hexes
                    hs = pygame.Surface((r_sc * 4, r_sc * 4), pygame.SRCALPHA)
                    local_pts = [
                        (p[0] - sx9 + r_sc * 2, p[1] - sy9 + r_sc * 2) for p in pts_sc
                    ]
                    a_val = 120 if is_hover else 60
                    c_val = (220, 180, 40, a_val) if is_hover else (180, 150, 30, a_val)
                    pygame.draw.polygon(hs, c_val, local_pts)
                    surf.blit(hs, (sx9 - r_sc * 2, sy9 - r_sc * 2))
                    border_col = (240, 200, 60) if is_hover else (160, 128, 40)
                    pygame.draw.polygon(
                        surf,
                        border_col,
                        pts_sc,
                        max(2, int(3 * z)) if is_hover else max(1, int(2 * z)),
                    )

                    # Hover tooltip
                    if is_hover:
                        terr = hex_terrain(col, row)
                        tdata = assets.TERRAIN_DATA[terr]
                        content = assets.HEX_CONTENTS.get(hkey)
                        parts = []
                        if tdata["food"]:
                            parts.append(f"food {tdata['food']:+d}")
                        if tdata["health"]:
                            parts.append(f"hp {tdata['health']:+d}")
                        if tdata["morale"]:
                            parts.append(f"mor {tdata['morale']:+d}")
                        parts.append(f"{tdata['days']}d")
                        tip_lines = [tdata["label"], "  ".join(parts)]
                        if content and content["type"] != "waypoint":
                            tip_lines.append(f"↳ {content.get('name', '?')[:28]}")
                        try:
                            ft = pygame.font.SysFont("Georgia", max(9, int(10 * z)))
                            tw = max(ft.size(l)[0] for l in tip_lines) + 16
                            th = len(tip_lines) * 15 + 10
                            tip_r = pygame.Rect(
                                sx9 - tw // 2, sy9 - r_sc - th - 6, tw, th
                            )
                            tip_r.x = max(R.x + 2, min(R.right - tw - 2, tip_r.x))
                            tip_r.y = max(R.y + 2, tip_r.y)
                            pygame.draw.rect(
                                surf, (200, 180, 120), tip_r, border_radius=3
                            )
                            pygame.draw.rect(
                                surf, (120, 90, 30), tip_r, 1, border_radius=3
                            )
                            for ti2, tl2 in enumerate(tip_lines):
                                col_t2 = (58, 40, 8) if ti2 == 0 else (100, 72, 32)
                                ts_t2 = ft.render(tl2, True, col_t2)
                                surf.blit(ts_t2, (tip_r.x + 7, tip_r.y + 5 + ti2 * 15))
                        except:
                            pass

                elif is_visited:
                    # Faint ink border on visited
                    pygame.draw.polygon(
                        surf, (100, 80, 40), pts_sc, max(1, int(1.5 * z))
                    )

                # Content markers on visited hexes (drawn dynamically in case used)
                if is_visited or is_cur:
                    content = assets.HEX_CONTENTS.get(hkey)
                    if content:
                        ctype = content["type"]
                        if ctype == "tribe":
                            pygame.draw.circle(
                                surf, (60, 140, 80), (sx9, sy9), max(4, int(7 * z))
                            )
                            pygame.draw.circle(
                                surf, (30, 90, 50), (sx9, sy9), max(4, int(7 * z)), 1
                            )
                        elif ctype == "resource":
                            already = any(
                                tuple(u) == (col, row) for u in s.used_resources
                            )
                            if not already:
                                pygame.draw.circle(
                                    surf, (200, 160, 30), (sx9, sy9), max(3, int(5 * z))
                                )
                        elif ctype == "rumour":
                            pygame.draw.circle(
                                surf, (160, 100, 160), (sx9, sy9), max(3, int(4 * z))
                            )

        # ── Waypoint markers — dynamic overlay (show revealed names etc.) ─────
        for i, wp in enumerate(assets.WAYPOINTS):
            wc, wr = assets.WP_HEX[i]
            sx9, sy9 = self.hex_screen_pos(wc, wr)
            if not R.collidepoint(sx9, sy9):
                continue
            sz9 = max(8, int(22 * z))
            is_cur_wp = i == s.current_wp
            is_vis_wp = i < s.current_wp or tuple(assets.WP_HEX[i]) in visited_set
            is_hov_wp = (wc, wr) == self.hover_hex
            wp_type = wp.get("type", "camp")
            is_dead = wp_type == "dead_end" and wp["revealed"]

            # Pulsing ring for current
            if is_cur_wp:
                pr2 = int(sz9 + 5 + pulse * 7)
                pygame.draw.circle(surf, (200, 60, 20), (sx9, sy9), pr2, 3)
            elif is_hov_wp and is_vis_wp:
                pygame.draw.circle(surf, (220, 180, 40), (sx9, sy9), sz9 + 4, 2)

            # Name label — revealed or generic
            show_lbl = is_hov_wp or is_cur_wp or is_vis_wp or z >= 0.4
            if show_lbl:
                disp = wp_display_name(i, s.visited_hexes)
                try:
                    fw = pygame.font.SysFont(
                        "Georgia", max(8, int(12 * z)), bold=is_cur_wp
                    )
                    lbl_col = (
                        (180, 40, 20)
                        if is_cur_wp
                        else ((120, 40, 40) if is_dead else (58, 40, 8))
                    )
                    box_w = fw.size(disp)[0] + 14
                    lbl_y = sy9 - sz9 - 20 if sy9 > R.y + 50 else sy9 + sz9 + 6
                    box_r = pygame.Rect(
                        sx9 - box_w // 2, lbl_y - 4, box_w, fw.get_height() + 8
                    )
                    pygame.draw.rect(surf, (230, 215, 170), box_r, border_radius=3)
                    border_c = (
                        (180, 40, 20)
                        if is_cur_wp
                        else ((100, 30, 30) if is_dead else (100, 75, 30))
                    )
                    pygame.draw.rect(surf, border_c, box_r, 1, border_radius=3)
                    ts_lbl = fw.render(disp, True, lbl_col)
                    surf.blit(
                        ts_lbl,
                        ts_lbl.get_rect(center=(sx9, lbl_y + fw.get_height() // 2 + 2)),
                    )
                except:
                    pass

        # ── Particles ─────────────────────────────────────────────────────────
        self._draw_particles(surf)

        # ── Compass rose (screen-space, bottom right) ─────────────────────────
        cr = 42
        crx = R.right - cr - 12
        cry = R.bottom - cr - 12
        pygame.draw.circle(surf, (220, 205, 160), (crx, cry), cr + 4)
        pygame.draw.circle(surf, (100, 78, 32), (crx, cry), cr + 4, 2)
        pygame.draw.circle(surf, (196, 178, 128), (crx, cry), cr)
        for pt9 in range(16):
            ang9 = math.radians(pt9 * 22.5)
            ln = (cr - 3) if pt9 % 4 == 0 else ((cr - 7) if pt9 % 2 == 0 else cr - 13)
            pygame.draw.line(
                surf,
                (58, 40, 8),
                (crx, cry),
                (crx + int(math.sin(ang9) * ln), cry - int(math.cos(ang9) * ln)),
                2 if pt9 % 4 == 0 else 1,
            )
        for lb9, ag9 in [("N", 0), ("E", 90), ("S", 180), ("W", 270)]:
            lxc = crx + int(math.sin(math.radians(ag9)) * (cr - 10))
            lyc = cry - int(math.cos(math.radians(ag9)) * (cr - 10))
            try:
                fc9 = pygame.font.SysFont("Georgia", 10, bold=True)
                surf.blit(
                    fc9.render(lb9, True, (200, 60, 20) if lb9 == "N" else (58, 40, 8)),
                    fc9.render(
                        lb9, True, (200, 60, 20) if lb9 == "N" else (58, 40, 8)
                    ).get_rect(center=(lxc, lyc)),
                )
            except:
                pass
        pygame.draw.circle(surf, (58, 40, 8), (crx, cry), 3)

        # ── Zoom badge ────────────────────────────────────────────────────────
        try:
            fz = pygame.font.SysFont("Georgia", 9)
            tz = fz.render(
                f"×{z:.2f}  pan({int(self.pan_x)},{int(self.pan_y)})",
                True,
                (154, 120, 72),
            )
            surf.blit(tz, (R.x + 4, R.bottom - 16))
        except:
            pass

        surf.set_clip(clip_save)
        pygame.draw.rect(surf, assets.UI_BORDER, R, 2)

    # ── handle ────────────────────────────────────────────────────────────────
    def handle(self, event, state, on_hex_click):
        R = self.MAP_RECT
        mpos = pygame.mouse.get_pos()
        z = self.zoom

        if event.type == pygame.MOUSEMOTION:
            self.hover_hex = None
            self.hover_wp = None
            if R.collidepoint(mpos):
                hc = self.screen_hex(*mpos)
                if hc and 0 <= hc[0] < assets.HEX_COLS and 0 <= hc[1] < assets.HEX_ROWS:
                    self.hover_hex = hc
                if self._drag_start:
                    dx = (mpos[0] - self._drag_start[0]) / z
                    dy = (mpos[1] - self._drag_start[1]) / z
                    self.pan_x = max(0, self._drag_pan[0] - dx)
                    self.pan_y = max(0, self._drag_pan[1] - dy)

        if event.type == pygame.MOUSEBUTTONDOWN and R.collidepoint(mpos):
            if event.button == 3:
                self._drag_start = mpos
                self._drag_pan = (self.pan_x, self.pan_y)
            elif event.button == 1:
                hc = self.screen_hex(*mpos)
                if hc:
                    on_hex_click(*hc)

        if event.type == pygame.MOUSEBUTTONUP and event.button == 3:
            self._drag_start = None

        if event.type == pygame.MOUSEWHEEL and R.collidepoint(mpos):
            # Zoom toward mouse cursor
            wx0, wy0 = self.screen_to_canvas(*mpos)
            factor = 1.2 if event.y > 0 else 1 / 1.2
            self.zoom = max(0.12, min(3.0, z * factor))
            # Re-anchor
            sx_off = mpos[0] - R.x
            sy_off = mpos[1] - R.y
            self.pan_x = wx0 - sx_off / self.zoom
            self.pan_y = wy0 - sy_off / self.zoom

    def zoom_in(self):
        self.zoom = min(3.0, self.zoom * 1.2)

    def zoom_out(self):
        self.zoom = max(0.12, self.zoom / 1.2)

    def zoom_reset(self):
        self.zoom = 0.22
        # Centre on starting hex
        sx, sy = self.hex_center(27, 12)
        R = self.MAP_RECT
        self.pan_x = max(0, sx - (R.w / self.zoom) / 2)
        self.pan_y = max(0, sy - (R.h / self.zoom) / 2)

    def invalidate(self):
        """Call after trail/visited changes to rebuild canvas."""
        self._canvas_dirty = True

    def centre_on_hex(self, col, row):
        """Pan map so hex (col,row) is centred in the viewport."""
        R = self.MAP_RECT
        cx, cy = self.hex_center(col, row)
        self.pan_x = max(0, cx - (R.w / self.zoom) / 2)
        self.pan_y = max(0, cy - (R.h / self.zoom) / 2)
