#!/usr/bin/env python3
"""Generate every platform's app icon from one source image.

    python3 tools/make_icons.py path/to/artwork.png

Writes the master, the Windows .ico, the Android launcher densities and the
small copy the game itself uses for its window icon. Re-run it whenever the
artwork changes; nothing downstream needs editing.
"""

import pathlib
import sys

from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent

MASTER = ROOT / "packaging" / "icon.png"
MASTER_SIZE = 1024

WINDOWS_ICO = ROOT / "packaging" / "icon.ico"
WINDOWS_SIZES = [16, 24, 32, 48, 64, 128, 256]

# The LOVE Android port declares android:icon="@drawable/love", so the launcher
# icon is these five density buckets rather than a mipmap set.
ANDROID_DIR = ROOT / "packaging" / "android"
ANDROID_DENSITIES = {
    "drawable-mdpi": 48,
    "drawable-hdpi": 72,
    "drawable-xhdpi": 96,
    "drawable-xxhdpi": 144,
    "drawable-xxxhdpi": 192,
}

# Shipped inside the .love and handed to love.window.setIcon at startup.
GAME_ICON = ROOT / "assets" / "icon.png"
GAME_ICON_SIZE = 256


def square(image: Image.Image) -> Image.Image:
    """Pad to a square so no resize distorts the artwork."""
    if image.width == image.height:
        return image
    side = max(image.width, image.height)
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    canvas.paste(image, ((side - image.width) // 2, (side - image.height) // 2))
    return canvas


def resized(image: Image.Image, size: int) -> Image.Image:
    return image.resize((size, size), Image.LANCZOS)


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__, file=sys.stderr)
        return 1

    source = pathlib.Path(sys.argv[1])
    if not source.is_file():
        print(f"no such file: {source}", file=sys.stderr)
        return 1

    art = square(Image.open(source).convert("RGBA"))
    print(f"source: {source} ({art.width}x{art.height})")

    written = []

    MASTER.parent.mkdir(parents=True, exist_ok=True)
    resized(art, MASTER_SIZE).save(MASTER, optimize=True)
    written.append(MASTER)

    master = Image.open(MASTER).convert("RGBA")

    master.save(WINDOWS_ICO, sizes=[(s, s) for s in WINDOWS_SIZES])
    written.append(WINDOWS_ICO)

    for folder, size in ANDROID_DENSITIES.items():
        target = ANDROID_DIR / folder / "love.png"
        target.parent.mkdir(parents=True, exist_ok=True)
        resized(master, size).save(target, optimize=True)
        written.append(target)

    GAME_ICON.parent.mkdir(parents=True, exist_ok=True)
    resized(master, GAME_ICON_SIZE).save(GAME_ICON, optimize=True)
    written.append(GAME_ICON)

    for path in written:
        print(f"  {path.relative_to(ROOT)}  {path.stat().st_size // 1024} KB")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
