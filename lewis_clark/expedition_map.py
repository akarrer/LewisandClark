"""Vector expedition map layers (overview / region) — parchment + route, rivers, terrain blobs.

Uses equirectangular lon/lat → canvas pixels within each mode's bounding box (not tied to
the hex game canvas). Data: ``config/expedition_map.json``.
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

import pygame

from lewis_clark.textures import gen_parchment

_REPO = Path(__file__).resolve().parent.parent
_CONFIG_PATH = _REPO / "config" / "expedition_map.json"

_cache: dict[str, pygame.Surface] = {}
_data: dict[str, Any] | None = None


def _load_data() -> dict[str, Any]:
    global _data
    if _data is None:
        with open(_CONFIG_PATH, encoding="utf-8") as f:
            _data = json.load(f)
    return _data


def invalidate_cache() -> None:
    """Clear rendered surfaces (e.g. after editing JSON)."""
    global _cache
    _cache.clear()


def canvas_size(mode: str) -> tuple[int, int]:
    d = _load_data()
    key = "overview" if mode == "overview" else "region"
    m = d[key]
    return int(m["width"]), int(m["height"])


def lonlat_to_canvas(
    lon: float,
    lat: float,
    bbox: dict[str, float],
    w: int,
    h: int,
) -> tuple[float, float]:
    """West-negative longitude, north-positive latitude."""
    west, east = bbox["west"], bbox["east"]
    south, north = bbox["south"], bbox["north"]
    x = (lon - west) / (east - west) * (w - 1)
    y = (north - lat) / (north - south) * (h - 1)
    return x, y


def _polyline_to_pixels(
    coords: list[list[float]],
    bbox: dict[str, float],
    w: int,
    h: int,
) -> list[tuple[int, int]]:
    out: list[tuple[int, int]] = []
    for pair in coords:
        if len(pair) < 2:
            continue
        lon, lat = float(pair[0]), float(pair[1])
        x, y = lonlat_to_canvas(lon, lat, bbox, w, h)
        out.append((int(round(x)), int(round(y))))
    return out


def build_surface(mode: str) -> pygame.Surface:
    if mode in _cache:
        return _cache[mode]

    d = _load_data()
    key = "overview" if mode == "overview" else "region"
    spec = d[key]
    w, h = int(spec["width"]), int(spec["height"])
    bbox = spec["bbox"]
    layers = spec.get("layers", {})

    surf = pygame.Surface((w, h))
    seed = 41 if mode == "overview" else 43
    parchment = gen_parchment(w, h, seed=seed)
    surf.blit(parchment, (0, 0))

    # Light edge darkening (opaque ink)
    edge = pygame.Surface((w, h), pygame.SRCALPHA)
    for i in range(40):
        a = int((1.0 - i / 40.0) ** 2 * 35)
        if a < 2:
            break
        c = (40, 28, 14, a)
        pygame.draw.rect(edge, c, (i, i, w - 2 * i, h - 2 * i), 1)
    surf.blit(edge, (0, 0))

    # Terrain regions (region mode mainly)
    if layers.get("terrain"):
        for reg in d.get("terrain_regions", []):
            t = reg.get("type", "plains")
            col = {
                "forest": (90, 120, 70, 55),
                "plains": (200, 185, 130, 45),
                "mountain": (130, 110, 85, 60),
            }.get(t, (180, 170, 130, 40))
            pts = _polyline_to_pixels(reg.get("polygon", []), bbox, w, h)
            if len(pts) >= 3:
                over = pygame.Surface((w, h), pygame.SRCALPHA)
                pygame.draw.polygon(over, col, pts)
                surf.blit(over, (0, 0))

    # Rivers
    if layers.get("rivers"):
        for riv in d.get("rivers", []):
            pts = _polyline_to_pixels(riv.get("coordinates", []), bbox, w, h)
            if len(pts) >= 2:
                for i in range(len(pts) - 1):
                    pygame.draw.line(
                        surf,
                        (95, 130, 175),
                        pts[i],
                        pts[i + 1],
                        max(2, w // 280),
                    )
                    pygame.draw.line(
                        surf,
                        (150, 185, 215),
                        pts[i],
                        pts[i + 1],
                        max(1, w // 400),
                    )

    # Expedition route (highlight)
    if layers.get("route"):
        pts = _polyline_to_pixels(d.get("route_coordinates", []), bbox, w, h)
        if len(pts) >= 2:
            for i in range(len(pts) - 1):
                pygame.draw.line(
                    surf,
                    (40, 22, 8),
                    (pts[i][0] + 2, pts[i][1] + 2),
                    (pts[i + 1][0] + 2, pts[i + 1][1] + 2),
                    max(5, w // 160),
                )
                pygame.draw.line(
                    surf,
                    (210, 140, 40),
                    pts[i],
                    pts[i + 1],
                    max(3, w // 220),
                )
                pygame.draw.line(
                    surf,
                    (255, 210, 120),
                    pts[i],
                    pts[i + 1],
                    max(1, w // 350),
                )

    # Border
    pygame.draw.rect(surf, (75, 52, 22), (0, 0, w, h), 4)
    pygame.draw.rect(surf, (120, 90, 40), (6, 6, w - 12, h - 12), 2)

    title = (
        "Lewis & Clark — full trail"
        if mode == "overview"
        else "Corridor — rivers & terrain"
    )
    try:
        fdir = _REPO / "assets" / "fonts" / "EBGaramond.ttf"
        font = (
            pygame.font.Font(str(fdir), max(14, w // 55))
            if fdir.exists()
            else pygame.font.Font(None, 22)
        )
        tx = font.render(title, True, (48, 32, 12))
        surf.blit(tx, (14, 10))
    except Exception:
        pass

    _cache[mode] = surf
    return surf
