"""Procedural texture generation for antique cartography look.

All textures are generated once at startup and cached on the assets module.
"""

from __future__ import annotations

import random

import pygame

from lewis_clark import assets


def _hash_int(n: int) -> int:
    n = ((n >> 13) ^ n) & 0x7FFFFFFF
    return (n * (n * n * 15731 + 789221) + 1376312589) & 0x7FFFFFFF


def _noise_val(ix: int, iy: int, seed: int) -> float:
    return _hash_int(ix * 57 + iy * 131 + seed * 1013) / 2147483647.0


def gen_parchment(w: int, h: int, seed: int = 42) -> pygame.Surface:
    """Generate a warm parchment texture using low-res noise scaled up."""
    lo_w, lo_h = max(1, w // 8), max(1, h // 8)
    lo = pygame.Surface((lo_w, lo_h))
    rng = random.Random(seed)

    base_r, base_g, base_b = 225, 208, 165
    for y in range(lo_h):
        for x in range(lo_w):
            n = _noise_val(x, y, seed)
            n2 = _noise_val(x * 3, y * 3, seed + 100)
            variation = int((n - 0.5) * 50 + (n2 - 0.5) * 20)
            r = max(0, min(255, base_r + variation))
            g = max(0, min(255, base_g + variation - 5))
            b = max(0, min(255, base_b + variation - 12))
            lo.set_at((x, y), (r, g, b))

    surf = pygame.transform.smoothscale(lo, (w, h))

    grain = pygame.Surface((w, h), pygame.SRCALPHA)
    for _ in range(w * h // 80):
        gx = rng.randint(0, w - 1)
        gy = rng.randint(0, h - 1)
        gv = rng.randint(-12, 12)
        ga = rng.randint(15, 40)
        grain.set_at((gx, gy), (128 + gv, 128 + gv, 128 + gv, ga))
    surf.blit(grain, (0, 0))

    for _ in range(max(1, w * h // 80000)):
        cx = rng.randint(w // 6, w * 5 // 6)
        cy = rng.randint(h // 6, h * 5 // 6)
        ring_r = rng.randint(16, 38)
        ring_s = pygame.Surface((ring_r * 3, ring_r * 3), pygame.SRCALPHA)
        rcx, rcy = ring_r * 3 // 2, ring_r * 3 // 2
        for dr in range(-2, 3):
            alpha = max(0, 14 - abs(dr) * 4)
            pygame.draw.circle(
                ring_s, (140, 100, 50, alpha), (rcx, rcy), ring_r + dr, 2
            )
        surf.blit(ring_s, (cx - rcx, cy - rcy))

    for _ in range(w * h // 15000):
        sx = rng.randint(0, w - 1)
        sy = rng.randint(0, h - 1)
        sr = rng.randint(1, 2)
        pygame.draw.circle(surf, (190, 170, 130), (sx, sy), sr)

    return surf


def gen_parchment_tile(size: int = 256, seed: int = 42) -> pygame.Surface:
    """Small tileable parchment texture for UI panels."""
    return gen_parchment(size, size, seed)


def gen_vignette(w: int, h: int) -> pygame.Surface:
    """Radial vignette: transparent center fading to dark burnt edges."""
    surf = pygame.Surface((w, h), pygame.SRCALPHA)
    cx, cy = w / 2.0, h / 2.0

    num_rings = 60
    for i in range(num_rings):
        t = i / num_rings
        radius_x = int(cx * (1.6 - t * 1.2))
        radius_y = int(cy * (1.6 - t * 1.2))
        alpha = int(t * t * t * 5)
        if alpha < 1:
            continue
        ring = pygame.Surface((w, h), pygame.SRCALPHA)
        pygame.draw.ellipse(
            ring,
            (8, 4, 0, alpha),
            (
                int(cx - radius_x),
                int(cy - radius_y),
                radius_x * 2,
                radius_y * 2,
            ),
        )
        surf.blit(ring, (0, 0))

    # Top/bottom edge darkening only. Do not draw full-height vertical lines at x=i and x=w-1-i:
    # those stacks meet the ellipse layer at x=edge_w and x=w-edge_w and read as a sharp vertical
    # seam (~2/3 into the right UI column on typical layouts). Ellipse rings already darken corners.
    edge_w = min(w, h) // 6
    for i in range(edge_w):
        t = 1.0 - i / edge_w
        alpha = int(t * t * 180)
        if alpha < 1:
            continue
        pygame.draw.line(surf, (8, 4, 0, alpha), (0, i), (w, i))
        pygame.draw.line(surf, (8, 4, 0, alpha), (0, h - 1 - i), (w, h - 1 - i))

    return surf


def gen_fog_sprite(size: int = 64) -> pygame.Surface:
    """Soft circular fog/mist sprite with alpha falloff."""
    surf = pygame.Surface((size, size), pygame.SRCALPHA)
    cx = cy = size // 2
    max_r = size // 2
    for r in range(max_r, 0, -2):
        t = r / max_r
        alpha = int((1.0 - t * t) * 50)
        pygame.draw.circle(surf, (220, 210, 180, alpha), (cx, cy), r)
    return surf


def gen_fog_sprites(count: int = 5) -> list:
    """Generate several fog sprites at different sizes."""
    return [gen_fog_sprite(48 + i * 20) for i in range(count)]


def gen_ink_stain(w: int, h: int, seed: int = 77) -> pygame.Surface:
    """Semi-random ink splatter decorative overlay."""
    surf = pygame.Surface((w, h), pygame.SRCALPHA)
    rng = random.Random(seed)

    for _ in range(3):
        cx = rng.randint(w // 6, w * 5 // 6)
        cy = rng.randint(h // 6, h * 5 // 6)
        for _ in range(30):
            dx = rng.gauss(0, 10)
            dy = rng.gauss(0, 10)
            r = rng.randint(1, 3)
            alpha = rng.randint(8, 22)
            pygame.draw.circle(
                surf, (30, 18, 6, alpha), (int(cx + dx), int(cy + dy)), r
            )

    return surf


def generate_all() -> None:
    """Generate all textures and cache them on the assets module."""
    assets.TEX_PARCHMENT = gen_parchment_tile(256, seed=42)
    assets.TEX_VIGNETTE = gen_vignette(assets.SW, assets.SH)
    assets.TEX_FOG_SPRITES = gen_fog_sprites(5)
    assets.TEX_INK_STAIN = gen_ink_stain(200, 200, seed=77)
    assets.TEX_MAP_PARCHMENT = None
