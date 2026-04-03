"""Entrypoint: init pygame, load JSON config into assets, run App."""

from __future__ import annotations

import os
import sys

import pygame

from lewis_clark import assets
from lewis_clark.config import load_all

# Populate assets before importing App (screens/ui use assets.* in defaults/class attrs).
load_all(assets)

from lewis_clark.app import App
from lewis_clark.fonts import load_fonts
from lewis_clark.hex_grid import _build_hex_contents


def main() -> None:
    os.environ.setdefault(
        "SDL_VIDEODRIVER", "windib" if sys.platform == "win32" else "x11"
    )

    pygame.init()
    pygame.font.init()
    load_fonts(assets)

    assets.screen = pygame.display.set_mode((assets.SW, assets.SH))
    pygame.display.set_caption("Lewis & Clark — Corps of Discovery  1804")
    assets.clock = pygame.time.Clock()

    _build_hex_contents()

    App().run()


if __name__ == "__main__":
    main()
