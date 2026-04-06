"""Journal scroll panel content."""

from __future__ import annotations

from lewis_clark import assets
from lewis_clark.drawing import lighten


class JournalMixin:
    def _update_journal(self):
        # Readable on dark parchment: light “base” foreground, distinct accents
        # (solarized-like separation of base / accent / comment, parchment palette).
        BASE = assets.CREAM
        TAG_COLS = {
            "OBJECTIVE": lighten(assets.GREEN2, 1.12),
            "COMPLETE": lighten(assets.GREEN2, 1.12),
            "FAILED": lighten(assets.RED2, 1.08),
            "hunt": (88, 196, 72),
            "trade": lighten(assets.TEAL2, 1.1),
            "camp": lighten(assets.BLUE2, 1.12),
            "discover": lighten(assets.GOLD2, 1.06),
        }
        lines = []
        for entry in reversed(self.state.journal[-24:]):
            if entry.startswith("["):
                end = entry.find("]")
                lines.append((entry[: end + 1], assets.F["mono_sm"], assets.GOLD2))
                rest = entry[end + 1 :].strip()
                col = BASE
                for kw, c in TAG_COLS.items():
                    if kw.lower() in rest.lower():
                        col = c
                        break
                lines.append((rest, assets.F["mono"], col))
                lines.append(("", assets.F["tiny"], assets.PARCH_EDGE))
            else:
                lines.append((entry, assets.F["mono"], BASE))
        self.journal_panel.set_lines(lines)
