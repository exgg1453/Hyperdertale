#!/usr/bin/env python3
"""Force every activity in the LOVE Android port to landscape.

Run from the root of a love-android checkout. Without this the APK follows the
phone's rotation and can end up in portrait, which a 320x240 landscape game
has nothing sensible to do with.
"""

import pathlib
import re
import sys

ORIENTATION = 'android:screenOrientation="sensorLandscape"'

existing = re.compile(r'android:screenOrientation="[^"]*"')


def patch(path: pathlib.Path) -> bool:
    text = path.read_text(encoding="utf-8")

    if existing.search(text):
        updated = existing.sub(ORIENTATION, text)
    else:
        # Every <activity> that has no orientation of its own gets one.
        updated = re.sub(r"<activity\b", "<activity " + ORIENTATION, text)

    if updated == text:
        return False

    path.write_text(updated, encoding="utf-8")
    return True


def main() -> int:
    root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "app/src")
    manifests = sorted(root.rglob("AndroidManifest.xml"))

    if not manifests:
        print(f"no AndroidManifest.xml found under {root}", file=sys.stderr)
        return 1

    for manifest in manifests:
        changed = patch(manifest)
        print(f"{'patched' if changed else 'unchanged'}: {manifest}")
        for line in manifest.read_text(encoding="utf-8").splitlines():
            if "screenOrientation" in line:
                print("   ", line.strip())

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
