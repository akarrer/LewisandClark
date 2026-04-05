#!/usr/bin/env python3
"""Regenerate committed PNGs under assets/images/ (8-bit style)."""

from __future__ import annotations

import os

os.environ.setdefault("SDL_VIDEODRIVER", "dummy")

import pygame  # noqa: E402

pygame.init()

from lewis_clark.pixel_assets_bake import bake_all_to_disk  # noqa: E402


def main() -> None:
    bake_all_to_disk()
    print("Wrote assets under assets/images/ and assets/images/animals/")


if __name__ == "__main__":
    main()
