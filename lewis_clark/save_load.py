"""Save / load expedition JSON via tkinter file dialogs."""

from __future__ import annotations

import json
import logging
from typing import Any, Optional

logger = logging.getLogger(__name__)


def save_expedition_json(data: dict) -> bool:
    """Prompt for path and write JSON. Returns True if saved."""
    try:
        import tkinter as tk
        from tkinter import filedialog
    except ImportError:
        logger.warning("tkinter not available; cannot show save dialog")
        return False
    try:
        root = tk.Tk()
        root.withdraw()
        path = filedialog.asksaveasfilename(
            defaultextension=".json",
            filetypes=[("Lewis & Clark Save", "*.json")],
            initialfile="expedition_save.json",
            title="Save Expedition",
        )
        root.destroy()
        if path:
            with open(path, "w", encoding="utf-8") as f:
                json.dump(data, f, indent=2)
            return True
    except OSError as e:
        logger.warning("Save failed (I/O): %s", e)
    except tk.TclError as e:
        logger.warning("Save dialog failed (tkinter): %s", e)
    except Exception:
        logger.exception("Unexpected error during save")
    return False


def load_expedition_json() -> Optional[dict[str, Any]]:
    """Prompt for file and return loaded dict, or None."""
    try:
        import tkinter as tk
        from tkinter import filedialog
    except ImportError:
        logger.warning("tkinter not available; cannot show load dialog")
        return None
    try:
        root = tk.Tk()
        root.withdraw()
        path = filedialog.askopenfilename(
            filetypes=[("Lewis & Clark Save", "*.json")],
            title="Load Expedition",
        )
        root.destroy()
        if path:
            with open(path, encoding="utf-8") as f:
                return json.load(f)
    except OSError as e:
        logger.warning("Load failed (I/O): %s", e)
    except json.JSONDecodeError as e:
        logger.warning("Load failed (invalid JSON): %s", e)
    except tk.TclError as e:
        logger.warning("Load dialog failed (tkinter): %s", e)
    except Exception:
        logger.exception("Unexpected error during load")
    return None
