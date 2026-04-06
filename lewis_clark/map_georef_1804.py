"""Georeferencing for the baked Samuel Lewis ~1804 Louisiana plate crop.

The scan is not any standard projection: the engraved graticule is curved on the page,
so **no** closed-form lon/lat → (x, y) model (plate Carrée, Mercator, homography, …)
will line up with the drawing.

**Preferred:** ``assets/map_georef/lewis_1804_crop_control_points.json`` — many
(lon, lat) → (x, y) knots on *this* scan (from ``scripts/calibrate_lewis_1804_georef.py``,
which snaps seeds to dark grid ink). If ≥6 points are present, we use a quadratic
least-squares fit in (lon, lat) for ``lonlat_to_px``.

**Fallback** (no / too few control points): spherical Mercator + homography from the
crop corners — convenient but **not** faithful to the plate; only for bootstrapping.
"""

from __future__ import annotations

import json
import math
from pathlib import Path
from typing import Any

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OPTIONAL_CONTROL_POINTS = (
    ROOT / "assets" / "map_georef" / "lewis_1804_crop_control_points.json"
)


def _mercator_plane(lon_deg: float, lat_deg: float) -> tuple[float, float]:
    """Spherical Mercator: λ and ψ = ln(tan(π/4 + φ/2)) in radians-scale x, same as Web Mercator."""
    lam = math.radians(lon_deg)
    phi = math.radians(lat_deg)
    if phi >= math.pi / 2 - 1e-9:
        phi = math.pi / 2 - 1e-9
    if phi <= -math.pi / 2 + 1e-9:
        phi = -math.pi / 2 + 1e-9
    x = lam
    y = math.log(math.tan(math.pi / 4 + phi / 2))
    return x, y


def _homography_from_four_pairs(src: np.ndarray, dst: np.ndarray) -> np.ndarray:
    """Direct linear transform; src, dst shape (4, 2). Returns 3×3 H with h[2,2]=1."""
    A: list[list[float]] = []
    for i in range(4):
        x, y = float(src[i, 0]), float(src[i, 1])
        u, v = float(dst[i, 0]), float(dst[i, 1])
        A.append([-x, -y, -1.0, 0.0, 0.0, 0.0, u * x, u * y, u])
        A.append([0.0, 0.0, 0.0, -x, -y, -1.0, v * x, v * y, v])
    amat = np.array(A, dtype=np.float64)
    _, _, vt = np.linalg.svd(amat)
    h = vt[-1, :]
    h3 = h.reshape(3, 3)
    if abs(h3[2, 2]) < 1e-12:
        return np.eye(3, dtype=np.float64)
    return h3 / h3[2, 2]


def _apply_homography(h: np.ndarray, x: float, y: float) -> tuple[float, float]:
    v = np.array([x, y, 1.0], dtype=np.float64)
    w = h @ v
    if abs(w[2]) < 1e-12:
        return float(w[0]), float(w[1])
    return float(w[0] / w[2]), float(w[1] / w[2])


def _load_optional_control_points() -> list[tuple[float, float, float, float]]:
    if not OPTIONAL_CONTROL_POINTS.is_file():
        return []
    try:
        raw: Any = json.loads(OPTIONAL_CONTROL_POINTS.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return []
    pts: list[tuple[float, float, float, float]] = []
    for row in raw.get("control_points", []):
        try:
            lon = float(row["lon"])
            lat = float(row["lat"])
            px = float(row["x"])
            py = float(row["y"])
            pts.append((lon, lat, px, py))
        except (KeyError, TypeError, ValueError):
            continue
    return pts


def _fit_quadratic_lonlat_to_px(
    pts: list[tuple[float, float, float, float]],
) -> tuple[np.ndarray, np.ndarray]:
    """px ≈ M @ a, py ≈ M @ b with rows [1, L, φ, Lφ, L², φ²]."""
    m_rows: list[list[float]] = []
    bx: list[float] = []
    by: list[float] = []
    for lon, lat, px, py in pts:
        l, p = lon, lat
        m_rows.append([1.0, l, p, l * p, l * l, p * p])
        bx.append(px)
        by.append(py)
    mmat = np.array(m_rows, dtype=np.float64)
    bxv = np.array(bx, dtype=np.float64)
    byv = np.array(by, dtype=np.float64)
    ax, _, _, _ = np.linalg.lstsq(mmat, bxv, rcond=None)
    ay, _, _, _ = np.linalg.lstsq(mmat, byv, rcond=None)
    return ax, ay


def _apply_quadratic(
    ax: np.ndarray, ay: np.ndarray, lon: float, lat: float
) -> tuple[float, float]:
    l, p = lon, lat
    v = np.array([1.0, l, p, l * p, l * l, p * p], dtype=np.float64)
    return float(v @ ax), float(v @ ay)


class MapGeoRef1804:
    """Lon/lat in decimal degrees (west longitude negative). Pixel origin top-left."""

    __slots__ = ("_use_quad", "_ax", "_ay", "_h")

    def __init__(
        self,
        lon_w: float,
        lon_e: float,
        lat_n: float,
        lat_s: float,
        w_px: int,
        h_px: int,
    ) -> None:
        optional = _load_optional_control_points()
        if len(optional) >= 6:
            self._use_quad = True
            self._ax, self._ay = _fit_quadratic_lonlat_to_px(optional)
            self._h = np.eye(3)
            return

        self._use_quad = False
        nw = _mercator_plane(lon_w, lat_n)
        ne = _mercator_plane(lon_e, lat_n)
        sw = _mercator_plane(lon_w, lat_s)
        se = _mercator_plane(lon_e, lat_s)
        src = np.array([nw, ne, sw, se], dtype=np.float64)
        w1, h1 = max(1, w_px - 1), max(1, h_px - 1)
        dst = np.array([[0.0, 0.0], [w1, 0.0], [0.0, h1], [w1, h1]], dtype=np.float64)
        self._h = _homography_from_four_pairs(src, dst)
        self._ax = np.zeros(6)
        self._ay = np.zeros(6)

    def lonlat_to_px(self, lon_deg: float, lat_deg: float) -> tuple[float, float]:
        if self._use_quad:
            return _apply_quadratic(self._ax, self._ay, lon_deg, lat_deg)
        mx, my = _mercator_plane(lon_deg, lat_deg)
        return _apply_homography(self._h, mx, my)
