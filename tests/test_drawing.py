"""Pure drawing helpers (no pygame display, no config)."""

from __future__ import annotations

import pytest

pytest.importorskip("pygame")

from lewis_clark.drawing import blend, darken, hex2rgb, lighten


def test_hex2rgb():
    assert hex2rgb("#ff00aa") == (255, 0, 170)
    assert hex2rgb("000000") == (0, 0, 0)


def test_blend_midpoint():
    c1 = (100, 100, 100)
    c2 = (200, 200, 200)
    assert blend(c1, c2, 0.5) == (150, 150, 150)


def test_darken_lighten_monotonic():
    c = (100, 100, 100)
    assert darken(c, 0.5)[0] < c[0]
    assert lighten(c, 1.5)[0] > c[0]
