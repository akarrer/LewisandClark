"""Download the third-party assets listed in assets/ASSETS.json into assets/third_party/.

Run from anywhere:  python godot/tools/fetch_assets.py
Files already present are skipped. Everything listed is CC0.
"""

from __future__ import annotations

import json
import subprocess
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MANIFEST = ROOT / "assets" / "ASSETS.json"
DEST = ROOT / "assets" / "third_party"


def main() -> int:
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    for pack in manifest["packs"]:
        print(f"== {pack['name']} ({pack['licence']}, {pack['creator']})")
        for f in pack["files"]:
            out = DEST / f["file"]
            if out.exists() and (not f.get("bytes") or out.stat().st_size == f["bytes"]):
                continue
            out.parent.mkdir(parents=True, exist_ok=True)
            # curl: the mirror rejects Python's default user agent.
            subprocess.run(["curl", "-sSfL", "-o", str(out), f["url"]], check=True)
            print(f"  {f['file']}  {out.stat().st_size / 1e6:.1f} MB")
            if f.get("unzip"):
                with zipfile.ZipFile(out) as z:
                    z.extractall(out.with_suffix(""))
    return 0


if __name__ == "__main__":
    sys.exit(main())
