#!/usr/bin/env python3
"""Extract one exact version entry from the public changelog."""

import argparse
from pathlib import Path
import re


def extract_release_notes(changelog: str, version: str) -> str:
    if not re.fullmatch(r"[0-9]{4}\.[0-9]{1,2}\.[0-9]+", version):
        raise ValueError("Expected YYYY.M.PATCH version")

    lines = changelog.splitlines()
    headings = []
    fence = None
    for index, line in enumerate(lines):
        marker = re.match(r"^ {0,3}(`{3,}|~{3,})(.*)$", line)
        if fence is not None:
            if (marker and marker[1][0] == fence[0]
                    and len(marker[1]) >= len(fence) and not marker[2].strip()):
                fence = None
            continue
        if marker:
            fence = marker[1]
            continue
        heading = re.fullmatch(r" {0,3}##[ \t]+(.+?)[ \t]*", line)
        if heading:
            headings.append((index, heading[1]))

    if fence is not None:
        raise ValueError("Changelog contains an unclosed code fence")
    matches = [i for i, (_, title) in enumerate(headings) if title == version]
    if len(matches) != 1:
        raise ValueError(f"Expected exactly one changelog heading for {version}; found {len(matches)}")
    entry = matches[0]
    start = headings[entry][0] + 1
    end = headings[entry + 1][0] if entry + 1 < len(headings) else len(lines)
    notes = "\n".join(lines[start:end]).strip()
    if not notes:
        raise ValueError(f"Changelog entry for {version} is empty")
    return notes + "\n"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("version")
    parser.add_argument("--changelog", type=Path, default=Path("CHANGELOG.md"))
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    try:
        notes = extract_release_notes(args.changelog.read_text(encoding="utf-8"), args.version)
        args.output.write_text(notes, encoding="utf-8")
    except (OSError, ValueError) as error:
        parser.exit(1, f"Release notes: {error}\n")


if __name__ == "__main__":
    main()
