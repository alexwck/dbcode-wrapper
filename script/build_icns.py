#!/usr/bin/env python3

"""Pack a standard macOS iconset into an ICNS file."""

from __future__ import annotations

import struct
import sys
from pathlib import Path


PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"
ICON_ENTRIES = (
    (b"icp4", "icon_16x16.png", 16),
    (b"ic11", "icon_16x16@2x.png", 32),
    (b"icp5", "icon_32x32.png", 32),
    (b"ic12", "icon_32x32@2x.png", 64),
    (b"ic07", "icon_128x128.png", 128),
    (b"ic13", "icon_128x128@2x.png", 256),
    (b"ic08", "icon_256x256.png", 256),
    (b"ic14", "icon_256x256@2x.png", 512),
    (b"ic09", "icon_512x512.png", 512),
    (b"ic10", "icon_512x512@2x.png", 1024),
)


def read_icon(iconset: Path, filename: str, expected_size: int) -> bytes:
    source = iconset / filename
    data = source.read_bytes()
    if len(data) < 24 or data[:8] != PNG_SIGNATURE:
        raise ValueError(f"{source} is not a PNG file")

    width, height = struct.unpack(">II", data[16:24])
    if (width, height) != (expected_size, expected_size):
        raise ValueError(
            f"{source} is {width}x{height}; expected {expected_size}x{expected_size}"
        )
    return data


def pack_iconset(iconset: Path, output: Path) -> None:
    chunks = []
    for chunk_type, filename, expected_size in ICON_ENTRIES:
        data = read_icon(iconset, filename, expected_size)
        chunks.append(chunk_type + struct.pack(">I", len(data) + 8) + data)

    payload = b"".join(chunks)
    temporary_output = output.with_name(f"{output.name}.tmp")
    temporary_output.write_bytes(
        b"icns" + struct.pack(">I", len(payload) + 8) + payload
    )
    temporary_output.replace(output)


def main() -> int:
    if len(sys.argv) != 3:
        print("Usage: build_icns.py ICONSET_DIR OUTPUT.icns", file=sys.stderr)
        return 2

    try:
        pack_iconset(Path(sys.argv[1]), Path(sys.argv[2]))
    except (OSError, ValueError) as error:
        print(f"Could not build ICNS: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
