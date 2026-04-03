"""Lewis & Clark Expedition — Pygame game package."""

from typing import TYPE_CHECKING, Any

if TYPE_CHECKING:
    from lewis_clark.app import App

__all__ = ["App"]


def __getattr__(name: str) -> Any:
    if name == "App":
        from lewis_clark.app import App

        return App
    raise AttributeError(f"module {__name__!r} has no attribute {name!r}")
