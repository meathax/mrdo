#!/usr/bin/env python3
"""Frame-barrier coordinator for the native RTL and MAME participants."""

from __future__ import annotations

import argparse
import json
import os
import struct
import time
from pathlib import Path


WIDTH = 240
HEIGHT = 192
BYTES = WIDTH * HEIGHT * 3


def atomic_text(path: Path, text: str) -> None:
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(text, encoding="ascii")
    for _ in range(100):
        try:
            os.replace(tmp, path)
            return
        except PermissionError:
            time.sleep(0.005)
    # Readers keep the tiny release token open briefly on Windows. A direct
    # replacement is safe after the bounded retry because there is only one
    # coordinator writer and the readers tolerate a transient short token.
    path.write_text(text, encoding="ascii")


def wait_for(path: Path, timeout: float) -> bool:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if path.exists():
            return True
        time.sleep(0.002)
    return False


def mame_rgb(raw: bytes, width: int, height: int) -> bytes:
    if len(raw) != width * height * 4:
        raise ValueError(f"MAME raw frame is {len(raw)} bytes, expected {width * height * 4}")
    # screen:pixels() returns the native u32 bitmap. On Windows/MAME's
    # little-endian host, ARGB32 is stored as B,G,R,A bytes.
    out = bytearray(width * height * 3)
    for src, dst in zip(range(0, len(raw), 4), range(0, len(out), 3)):
        out[dst:dst + 3] = raw[src + 2:src + 3] + raw[src + 1:src + 2] + raw[src:src + 1]
    return bytes(out)


def write_diff(path: Path, left: bytes, right: bytes) -> None:
    diff = bytearray(BYTES)
    for index, (a, b) in enumerate(zip(left, right)):
        diff[index] = abs(a - b)
    path.write_bytes(b"P6\n240 192\n255\n" + diff)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("session", type=Path)
    parser.add_argument("--frames", type=int, default=120)
    parser.add_argument("--timeout", type=float, default=30.0)
    parser.add_argument("--strict", action="store_true")
    args = parser.parse_args()

    session = args.session.resolve()
    rtl = session / "rtl"
    reference = session / "reference"
    inputs = session / "inputs"
    diff_dir = session / "diff"
    for directory in (rtl, reference, inputs, diff_dir):
        directory.mkdir(parents=True, exist_ok=True)
    atomic_text(session / "release.txt", "-1\n")

    rows: list[dict[str, int | str]] = []
    failures = 0
    for frame in range(args.frames):
        stem = f"frame_{frame:06d}"
        # The SDL participant publishes its actual input state before each
        # frame. If it is absent, MAME's own idle defaults are authoritative.
        rtl_ready = rtl / f"{stem}.ready"
        ref_ready = reference / f"{stem}.ready"
        if not wait_for(rtl_ready, args.timeout) or not wait_for(ref_ready, args.timeout):
            print(f"LOCKSTEP TIMEOUT frame={frame} rtl={rtl_ready.exists()} mame={ref_ready.exists()}")
            failures += 1
            atomic_text(session / "release.txt", f"{frame}\n")
            break
        try:
            left = (rtl / f"{stem}.rgb").read_bytes()
            meta = (reference / f"{stem}.meta").read_text(encoding="ascii")
            fields = dict(line.split("=", 1) for line in meta.splitlines() if "=" in line)
            width = int(fields.get("width", "0"))
            height = int(fields.get("height", "0"))
            right = mame_rgb((reference / f"{stem}.raw").read_bytes(), width, height)
            if width != WIDTH or height != HEIGHT:
                raise ValueError(f"MAME visible area is {width}x{height}, expected {WIDTH}x{HEIGHT}")
            if len(left) != BYTES or len(right) != BYTES:
                raise ValueError(f"frame size mismatch rtl={len(left)} mame={len(right)}")
        except (OSError, ValueError) as error:
            print(f"LOCKSTEP ERROR frame={frame}: {error}")
            failures += 1
            atomic_text(session / "release.txt", f"{frame}\n")
            break

        mismatch = sum(1 for a, b in zip(left, right) if a != b)
        max_error = max((abs(a - b) for a, b in zip(left, right)), default=0)
        mean_error = sum(abs(a - b) for a, b in zip(left, right)) / BYTES
        if mismatch:
            write_diff(diff_dir / f"{stem}.ppm", left, right)
        row = {
            "frame": frame,
            "rtl_checksum": sum(left) & 0xffffffff,
            "mame_checksum": sum(right) & 0xffffffff,
            "mismatch_bytes": mismatch,
            "max_error": max_error,
            "mean_error": round(mean_error, 4),
        }
        rows.append(row)
        print("FRAME " + json.dumps(row, sort_keys=True), flush=True)
        atomic_text(session / "release.txt", f"{frame}\n")

    atomic_text(session / "comparison.json", json.dumps({"frames": rows, "failures": failures}, indent=2) + "\n")
    if failures:
        return 2
    if args.strict and any(row["mismatch_bytes"] for row in rows):
        return 3
    print(f"LOCKSTEP PASS frames={len(rows)} strict={args.strict}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
