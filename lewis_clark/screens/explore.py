"""On-the-ground 3/4 isometric exploration scene.

The player walks a tiled world in real time; the strategic hex map (GameScreen)
is opened with M. Art is placeholder-procedural for now — the sprite-smith agent
replaces the character and tiles with baked isometric PNGs, dropped in through
``_tile_surface`` / ``_draw_player`` without touching the controller or camera.
"""

from __future__ import annotations

import random

import pygame

from lewis_clark import assets, iso
from lewis_clark.drawing import darken, draw_text, lighten

# Tile ids
GRASS, DIRT, WATER, SAND, ROCK = range(5)
_WALKABLE = {GRASS, DIRT, SAND}

_TILE_TOP = {
    GRASS: (74, 108, 52),
    DIRT: (120, 92, 54),
    WATER: (44, 86, 120),
    SAND: (196, 174, 118),
    ROCK: (110, 104, 96),
}


class ExploreScreen:
    """Real-time isometric field. Shares GameState with the map screen."""

    MOVE_SPEED = 0.075  # tiles per frame at base scale
    W, H = 48, 48  # world size in tiles

    def __init__(self, state, on_open_map, on_quit):
        self.state = state
        self.on_open_map = on_open_map
        self.on_quit = on_quit
        self.frame = 0
        self._rng = random.Random(1804)
        self._build_world()
        # Player starts near the centre on a walkable tile.
        self.px, self.py = self._find_spawn()
        self.facing = "S"
        self._moving = False
        self.cam_x = 0.0
        self.cam_y = 0.0
        self._snap_camera()

    # ---------------------------------------------------------------- world

    def _build_world(self):
        rng = self._rng
        self.tiles = [[GRASS] * self.W for _ in range(self.H)]
        # A meandering river of water down the map.
        river_x = self.W // 2
        for y in range(self.H):
            river_x += rng.choice((-1, 0, 0, 1))
            river_x = max(3, min(self.W - 4, river_x))
            for dx in (-1, 0, 1):
                self.tiles[y][river_x + dx] = WATER
            # sandy banks
            for dx in (-2, 2):
                if 0 <= river_x + dx < self.W and self.tiles[y][river_x + dx] != WATER:
                    self.tiles[y][river_x + dx] = SAND
        # Scatter dirt patches and rocky outcrops.
        for _ in range(60):
            x, y = rng.randrange(self.W), rng.randrange(self.H)
            if self.tiles[y][x] == GRASS:
                self.tiles[y][x] = rng.choice((DIRT, DIRT, ROCK))
        # Props (trees) sitting on walkable grass — depth-sorted with the player.
        self.props = []
        for _ in range(90):
            x, y = rng.randrange(self.W), rng.randrange(self.H)
            if self.tiles[y][x] == GRASS:
                self.props.append((x + 0.5, y + 0.5, "tree"))

    def _find_spawn(self) -> tuple[float, float]:
        cx, cy = self.W // 2, self.H // 2
        for r in range(self.W):
            for dy in range(-r, r + 1):
                for dx in range(-r, r + 1):
                    x, y = cx + dx, cy + dy
                    if 0 <= x < self.W and 0 <= y < self.H and self.tiles[y][x] in _WALKABLE:
                        return x + 0.5, y + 0.5
        return cx + 0.5, cy + 0.5

    def _walkable(self, wx: float, wy: float) -> bool:
        if wx < 0 or wy < 0:
            return False
        tx, ty = int(wx), int(wy)
        if not (0 <= tx < self.W and 0 <= ty < self.H):
            return False
        return self.tiles[ty][tx] in _WALKABLE

    # --------------------------------------------------------------- camera

    def _center(self) -> tuple[int, int]:
        return assets.SW // 2, int(assets.SH * 0.52)

    def _snap_camera(self):
        sx, sy = iso.world_to_screen(self.px, self.py)
        self.cam_x, self.cam_y = -sx, -sy

    # ---------------------------------------------------------------- input

    def handle(self, event, *_):
        if event.type == pygame.KEYDOWN:
            if event.key in (pygame.K_m, pygame.K_TAB):
                self.on_open_map()
            elif event.key == pygame.K_ESCAPE:
                self.on_quit()

    def update(self):
        self.frame += 1
        keys = pygame.key.get_pressed()
        us = getattr(assets, "UI_SCALE", 1.0)
        speed = self.MOVE_SPEED * max(0.8, us)
        # Screen-relative movement mapped onto the iso world axes.
        dx = dy = 0.0
        if keys[pygame.K_w] or keys[pygame.K_UP]:
            dx -= 1; dy -= 1
        if keys[pygame.K_s] or keys[pygame.K_DOWN]:
            dx += 1; dy += 1
        if keys[pygame.K_a] or keys[pygame.K_LEFT]:
            dx -= 1; dy += 1
        if keys[pygame.K_d] or keys[pygame.K_RIGHT]:
            dx += 1; dy -= 1
        self._moving = dx or dy
        if self._moving:
            mag = (dx * dx + dy * dy) ** 0.5
            dx, dy = dx / mag * speed, dy / mag * speed
            self.facing = self._facing_for(dx, dy)
            # Axis-separated collision so we can slide along water/edges.
            if self._walkable(self.px + dx, self.py):
                self.px += dx
            if self._walkable(self.px, self.py + dy):
                self.py += dy
        # Smooth camera follow.
        sx, sy = iso.world_to_screen(self.px, self.py)
        tx, ty = -sx, -sy
        self.cam_x += (tx - self.cam_x) * 0.15
        self.cam_y += (ty - self.cam_y) * 0.15

    @staticmethod
    def _facing_for(dx: float, dy: float) -> str:
        # Screen-space direction from iso velocity (ssx right+, ssy down+).
        import math
        ssx = dx - dy
        ssy = dx + dy
        ang = math.degrees(math.atan2(ssy, ssx)) % 360
        dirs = ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]
        return dirs[int(ang / 45 + 0.5) % 8]

    # ----------------------------------------------------------------- draw

    def draw(self, surf):
        cx, cy = self._center()
        ox = cx + self.cam_x
        oy = cy + self.cam_y
        # Sky/ground backdrop.
        surf.fill((38, 46, 40))

        # Visible tile window (cull off-screen tiles).
        drawables = []  # (depth, kind, payload)
        for ty in range(self.H):
            for tx in range(self.W):
                sx, sy = iso.world_to_screen(tx + 0.5, ty + 0.5)
                px, py = sx + ox, sy + oy
                if px < -iso.TILE_W or px > assets.SW + iso.TILE_W:
                    continue
                if py < -iso.TILE_H or py > assets.SH + iso.TILE_H:
                    continue
                self._draw_tile(surf, px, py, self.tiles[ty][tx])
        # Props + player as depth-sorted sprites.
        for (wx, wy, kind) in self.props:
            drawables.append((iso.depth(wx, wy), kind, (wx, wy)))
        drawables.append((iso.depth(self.px, self.py), "player", None))
        drawables.sort(key=lambda d: d[0])
        for _d, kind, payload in drawables:
            if kind == "player":
                self._draw_player(surf, self.px + 0 * ox, self.py, ox, oy)
            elif kind == "tree":
                wx, wy = payload
                sx, sy = iso.world_to_screen(wx, wy)
                self._draw_tree(surf, sx + ox, sy + oy)

        self._draw_hud(surf)

    def _draw_tile(self, surf, cx, cy, tid):
        top = _TILE_TOP[tid]
        hw, hh = iso.TILE_W / 2, iso.TILE_H / 2
        pts = [(cx, cy - hh), (cx + hw, cy), (cx, cy + hh), (cx - hw, cy)]
        pygame.draw.polygon(surf, top, pts)
        pygame.draw.polygon(surf, darken(top, 0.72), pts, 1)
        if tid == WATER and (self.frame // 20 + int(cx + cy)) % 7 == 0:
            pygame.draw.line(surf, lighten(top, 1.4), (cx - 6, cy), (cx + 6, cy), 1)

    def _draw_tree(self, surf, cx, cy):
        # feet at (cx, cy)
        pygame.draw.ellipse(surf, (24, 30, 22), (cx - 10, cy - 4, 20, 8))
        pygame.draw.rect(surf, (86, 60, 34), (cx - 3, cy - 22, 6, 20))
        pygame.draw.circle(surf, (46, 84, 44), (int(cx), int(cy - 30)), 15)
        pygame.draw.circle(surf, (60, 104, 56), (int(cx - 5), int(cy - 34)), 8)
        pygame.draw.circle(surf, darken((46, 84, 44), 0.7), (int(cx), int(cy - 30)), 15, 1)

    def _draw_player(self, surf, px, py, ox, oy):
        sx, sy = iso.world_to_screen(px, py)
        cx, cy = sx + ox, sy + oy
        # Shadow.
        sh = pygame.Surface((28, 12), pygame.SRCALPHA)
        pygame.draw.ellipse(sh, (0, 0, 0, 90), (0, 0, 28, 12))
        surf.blit(sh, (cx - 14, cy - 4))
        # Body (coat) + head; a small nub shows facing.
        coat = (60, 74, 110)
        pygame.draw.rect(surf, coat, (cx - 7, cy - 26, 14, 24), border_radius=3)
        pygame.draw.rect(surf, darken(coat, 0.6), (cx - 7, cy - 26, 14, 24), 1, border_radius=3)
        pygame.draw.circle(surf, (224, 194, 150), (int(cx), int(cy - 30)), 6)
        pygame.draw.circle(surf, (60, 42, 26), (int(cx), int(cy - 34)), 6)  # hat
        pygame.draw.rect(surf, (60, 42, 26), (cx - 7, cy - 35, 14, 3))
        nub = {
            "N": (0, -1), "S": (0, 1), "E": (1, 0), "W": (-1, 0),
            "NE": (1, -1), "NW": (-1, -1), "SE": (1, 1), "SW": (-1, 1),
        }.get(self.facing, (0, 1))
        pygame.draw.circle(
            surf, (250, 230, 180),
            (int(cx + nub[0] * 8), int(cy - 16 + nub[1] * 4)), 2,
        )

    def _draw_hud(self, surf):
        s = self.state
        # Top-left location/date ribbon.
        pad = 10
        txt = f"{s.season}  ·  {s.date_str}"
        draw_text(surf, txt, assets.F["subhead"], assets.CREAM, (pad + 4, pad + 2))
        # Bottom control hint.
        hint = "WASD / Arrows — walk      M — map      Esc — menu"
        hs = assets.F["small"].render(hint, True, assets.PARCH_LT)
        bg = pygame.Surface((hs.get_width() + 20, hs.get_height() + 10), pygame.SRCALPHA)
        bg.fill((0, 0, 0, 110))
        surf.blit(bg, (assets.SW // 2 - bg.get_width() // 2, assets.SH - bg.get_height() - 12))
        surf.blit(hs, (assets.SW // 2 - hs.get_width() // 2, assets.SH - hs.get_height() - 17))

    def on_resize(self):
        self._snap_camera()
