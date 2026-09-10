#!/usr/bin/env python3
"""Point a love-android checkout at this game.

Run from the root of a love-android clone. Everything the port exposes for
branding lives in gradle.properties - the app name, the application id and the
screen orientation are read from there and fed into the manifest as
placeholders, so editing the manifest directly is both unnecessary and easy to
get wrong.
"""

import pathlib
import sys

NAME = "Hyperdertale"
APPLICATION_ID = "com.hyperdertale"
ORIENTATION = "sensorLandscape"


def configure(path: pathlib.Path) -> str:
    lines = path.read_text(encoding="utf-8").splitlines()
    out = []
    seen = set()

    for line in lines:
        stripped = line.strip()

        # The port accepts either app.name or app.name_byte_array, never both,
        # so the byte array form has to go before app.name can be set.
        if stripped.startswith("app.name_byte_array="):
            out.append("#" + line)
            continue

        for key, value in (
            ("app.name", NAME),
            ("app.application_id", APPLICATION_ID),
            ("app.orientation", ORIENTATION),
        ):
            if stripped.startswith(key + "="):
                out.append(f"{key}={value}")
                seen.add(key)
                break
        else:
            out.append(line)

    for key, value in (
        ("app.name", NAME),
        ("app.application_id", APPLICATION_ID),
        ("app.orientation", ORIENTATION),
    ):
        if key not in seen:
            out.append(f"{key}={value}")

    text = "\n".join(out) + "\n"
    path.write_text(text, encoding="utf-8")
    return text


def main() -> int:
    root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ".")
    properties = root / "gradle.properties"

    if not properties.is_file():
        print(f"gradle.properties not found in {root}", file=sys.stderr)
        return 1

    text = configure(properties)

    print(f"configured {properties}:")
    for line in text.splitlines():
        if line.startswith("app."):
            print("   ", line)

    # A missing value here means a silently unbranded APK, so fail loudly.
    for expected in (
        f"app.name={NAME}",
        f"app.application_id={APPLICATION_ID}",
        f"app.orientation={ORIENTATION}",
    ):
        if expected not in text.splitlines():
            print(f"expected line missing: {expected}", file=sys.stderr)
            return 1

    if any(
        line.strip().startswith("app.name_byte_array=") for line in text.splitlines()
    ):
        print("app.name_byte_array is still active; it conflicts with app.name",
              file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
