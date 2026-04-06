"""Season-driven weather particle system for the map overlay."""

from __future__ import annotations

import math
import random

import pygame


class _Particle:
    __slots__ = ("x", "y", "vx", "vy", "life", "size", "col", "rot")

    def __init__(self, x, y, vx, vy, life, size, col, rot=0.0):
        self.x = x
        self.y = y
        self.vx = vx
        self.vy = vy
        self.life = life
        self.size = size
        self.col = col
        self.rot = rot


class WeatherSystem:
    """Draws seasonal weather particles over the map area."""

    MAX_PARTICLES = 260

    def __init__(self):
        self._particles: list[_Particle] = []
        self._season = ""
        self._rng = random.Random(0)
        self._frame = 0

    def update(self, season: str, map_rect: pygame.Rect) -> None:
        self._frame += 1
        if season != self._season:
            self._season = season
            self._particles.clear()

        R = map_rect
        deficit = self.MAX_PARTICLES - len(self._particles)
        spawn = min(deficit, 7)

        for _ in range(spawn):
            p = self._spawn(season, R)
            if p:
                self._particles.append(p)

        alive = []
        for p in self._particles:
            p.x += p.vx
            p.y += p.vy
            p.life -= 1
            p.rot += 0.03
            if p.life > 0 and R.collidepoint(int(p.x), int(p.y)):
                alive.append(p)
        self._particles = alive

    def _spawn(self, season: str, R: pygame.Rect) -> _Particle | None:
        rng = self._rng

        if season == "Spring":
            x = rng.randint(R.x, R.right)
            y = R.y - rng.randint(0, 10)
            return _Particle(
                x,
                y,
                rng.uniform(-0.3, 0.3) + 1.2,
                rng.uniform(2.5, 4.5),
                rng.randint(120, 250),
                rng.randint(2, 4),
                (160, 180, 210),
            )

        if season == "Summer":
            x = rng.randint(R.x, R.right)
            y = rng.randint(R.y, R.bottom)
            return _Particle(
                x,
                y,
                rng.uniform(-0.3, 0.3),
                rng.uniform(-0.4, 0.4),
                rng.randint(80, 200),
                rng.randint(2, 5),
                rng.choice(
                    [
                        (230, 215, 160),
                        (220, 200, 140),
                        (200, 190, 130),
                    ]
                ),
            )

        if season == "Autumn":
            x = rng.randint(R.x, R.right)
            y = R.y - rng.randint(0, 10)
            return _Particle(
                x,
                y,
                rng.uniform(0.5, 1.5),
                rng.uniform(0.8, 2.0),
                rng.randint(150, 350),
                rng.randint(3, 7),
                rng.choice(
                    [
                        (180, 90, 20),
                        (200, 120, 30),
                        (160, 70, 15),
                        (190, 140, 40),
                        (170, 80, 25),
                    ]
                ),
                rot=rng.uniform(0, math.pi * 2),
            )

        if season == "Winter":
            x = rng.randint(R.x, R.right)
            y = R.y - rng.randint(0, 10)
            return _Particle(
                x,
                y,
                rng.uniform(-0.5, 0.5),
                rng.uniform(0.5, 1.8),
                rng.randint(200, 400),
                rng.randint(2, 6),
                (235, 235, 240),
            )

        return None

    def draw(self, surf: pygame.Surface, map_rect: pygame.Rect) -> None:
        clip_save = surf.get_clip()
        surf.set_clip(map_rect)

        season = self._season
        for p in self._particles:
            ix, iy = int(p.x), int(p.y)
            alpha = min(255, int(p.life * 3.6))

            if season == "Spring":
                streak_len = 8
                ex = ix + int(p.vx * 2)
                ey = iy + streak_len
                pygame.draw.line(
                    surf,
                    (*p.col[:2], min(255, p.col[2] + 20)),
                    (ix, iy),
                    (ex, ey),
                    p.size,
                )

            elif season == "Summer":
                if alpha > 80:
                    ps = pygame.Surface(
                        (p.size * 2, p.size * 2),
                        pygame.SRCALPHA,
                    )
                    pygame.draw.circle(
                        ps,
                        (*p.col, min(alpha, 130)),
                        (p.size, p.size),
                        p.size,
                    )
                    surf.blit(ps, (ix - p.size, iy - p.size))

            elif season == "Autumn":
                sz = p.size
                c = math.cos(p.rot)
                s_val = math.sin(p.rot)
                pts = [
                    (ix + int(c * sz), iy + int(s_val * sz)),
                    (ix + int(-s_val * sz * 0.5), iy + int(c * sz * 0.5)),
                    (ix - int(c * sz), iy - int(s_val * sz)),
                    (ix - int(-s_val * sz * 0.5), iy - int(c * sz * 0.5)),
                ]
                leaf_s = pygame.Surface(
                    (sz * 4 + 2, sz * 4 + 2),
                    pygame.SRCALPHA,
                )
                local = [(x - ix + sz * 2 + 1, y - iy + sz * 2 + 1) for x, y in pts]
                pygame.draw.polygon(
                    leaf_s,
                    (*p.col, min(alpha, 220)),
                    local,
                )
                pygame.draw.polygon(
                    leaf_s,
                    (
                        max(0, p.col[0] - 30),
                        max(0, p.col[1] - 20),
                        p.col[2],
                        min(alpha, 170),
                    ),
                    local,
                    1,
                )
                surf.blit(leaf_s, (ix - sz * 2 - 1, iy - sz * 2 - 1))

            elif season == "Winter":
                ps = pygame.Surface(
                    (p.size * 2 + 2, p.size * 2 + 2),
                    pygame.SRCALPHA,
                )
                pygame.draw.circle(
                    ps,
                    (*p.col, min(alpha, 210)),
                    (p.size + 1, p.size + 1),
                    p.size,
                )
                surf.blit(ps, (ix - p.size - 1, iy - p.size - 1))

        if season == "Spring" and self._frame % 400 < 3 and self._rng.random() < 0.3:
            flash = pygame.Surface(
                (map_rect.w, map_rect.h),
                pygame.SRCALPHA,
            )
            flash.fill((255, 255, 240, 15))
            surf.blit(flash, map_rect.topleft)

        surf.set_clip(clip_save)
