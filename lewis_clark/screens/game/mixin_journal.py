"""Journal scroll panel content."""

from __future__ import annotations

from lewis_clark import assets


class JournalMixin:
    def _update_journal(self):
        TAG_COLS = {
            "OBJECTIVE": assets.GREEN2,
            "COMPLETE": assets.GREEN2,
            "FAILED": assets.RED2,
            "hunt": (78, 180, 64),
            "trade": assets.TEAL2,
            "camp": assets.BLUE2,
            "discover": assets.GOLD2,
        }
        lines = []
        for entry in reversed(self.state.journal[-24:]):
            if entry.startswith("["):
                end = entry.find("]")
                lines.append((entry[: end + 1], assets.F["mono_sm"], assets.GOLD))
                rest = entry[end + 1 :].strip()
                col = assets.PARCH_DARK
                for kw, c in TAG_COLS.items():
                    if kw.lower() in rest.lower():
                        col = c
                        break
                lines.append((rest, assets.F["mono"], col))
                lines.append(("", assets.F["tiny"], assets.DIM))
            else:
                lines.append((entry, assets.F["mono"], assets.PARCH_DARK))
        self.journal_panel.set_lines(lines)
