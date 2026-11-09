#!/usr/bin/env python3
"""Compare two schema fingerprints produced by tool/db/schema_fingerprint.sql.

Usage:
    psql -X -At -d db_a -f tool/db/schema_fingerprint.sql > a.json
    psql -X -At -d db_b -f tool/db/schema_fingerprint.sql > b.json
    tool/db/fingerprint_diff.py a.json b.json

Prints the objects that exist on only one side and the objects whose
definitions differ. Exits 0 when the schemas match, 1 on drift and 2 on
usage errors.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path


def load(path: str) -> dict[str, str]:
    data = json.loads(Path(path).read_text(encoding="utf-8"))
    if not isinstance(data, dict) or not all(
        isinstance(key, str) and isinstance(value, str) for key, value in data.items()
    ):
        raise ValueError(f"{path}: expected a JSON object of object name -> md5")
    return data


def diff(left: dict[str, str], right: dict[str, str]) -> tuple[list[str], list[str], list[str]]:
    only_left = sorted(left.keys() - right.keys())
    only_right = sorted(right.keys() - left.keys())
    changed = sorted(key for key in left.keys() & right.keys() if left[key] != right[key])
    return only_left, only_right, changed


def main(argv: list[str]) -> int:
    if len(argv) != 3:
        print(__doc__.strip(), file=sys.stderr)
        return 2
    try:
        left, right = load(argv[1]), load(argv[2])
    except (OSError, ValueError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 2

    only_left, only_right, changed = diff(left, right)
    for title, keys in (
        (f"only in {argv[1]}", only_left),
        (f"only in {argv[2]}", only_right),
        ("definition differs", changed),
    ):
        if keys:
            print(f"{title} ({len(keys)}):")
            for key in keys:
                print(f"  {key}")

    if only_left or only_right or changed:
        return 1
    print(f"schemas match ({len(left)} objects)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
