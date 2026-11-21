#!/usr/bin/env python3
"""Validates the .lproj translations against English: every table must have exactly the
same keys as en.lproj, and every printf specifier in a key must appear in its value.

Run from the repo root:  python3 scripts/validate_l10n.py
"""
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RES = ROOT / "Resources"

SPEC = re.compile(r"%(?:\d+\$)?[-+ 0#]*(?:\d+|\*)?(?:\.(?:\d+|\*))?(?:hh|h|ll|l|q|z|t|L)?[@diouxXeEfgGaAcFsSp%]")


def load(path: Path) -> dict:
    out = subprocess.run(["plutil", "-convert", "json", "-o", "-", str(path)],
                         capture_output=True, text=True, check=True)
    return json.loads(out.stdout)


def specs(text: str) -> list:
    return sorted(SPEC.findall(text))


def main() -> int:
    en = load(RES / "en.lproj" / "Localizable.strings")
    failures = 0
    for directory in sorted(RES.glob("*.lproj")):
        if directory.name == "en.lproj":
            continue
        strings = directory / "Localizable.strings"
        if not strings.exists():
            print(f"FAIL {directory.name}: Localizable.strings missing")
            failures += 1
            continue
        try:
            table = load(strings)
        except subprocess.CalledProcessError as exc:
            print(f"FAIL {directory.name}: does not parse: {exc.stderr.strip()}")
            failures += 1
            continue
        problems = []
        missing = sorted(set(en) - set(table))
        extra = sorted(set(table) - set(en))
        if missing:
            problems.append(f"missing {len(missing)} keys, e.g. {missing[:3]}")
        if extra:
            problems.append(f"extra {len(extra)} keys, e.g. {extra[:3]}")
        mismatched = [(k, specs(k), specs(v)) for k, v in table.items()
                      if k in en and specs(k) != specs(v)]
        if mismatched:
            shown = "; ".join(f"{k!r}: key={a} value={b}" for k, a, b in mismatched[:4])
            problems.append(f"{len(mismatched)} format mismatches, e.g. {shown}")
        if problems:
            print(f"FAIL {directory.name}: " + "; ".join(problems))
            failures += 1
        else:
            print(f"OK   {directory.name}: {len(table)} keys")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
