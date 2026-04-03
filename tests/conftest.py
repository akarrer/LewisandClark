"""Shared fixtures: load JSON config into ``lewis_clark.assets``.

Config is loaded at import time so modules such as ``drawing`` (default args use
``assets.GOLD``) can be imported during test collection.
"""

from __future__ import annotations

from lewis_clark import assets
from lewis_clark.config import load_all

load_all(assets)
