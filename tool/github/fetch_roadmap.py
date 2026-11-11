#!/usr/bin/env python3
"""Writes the website's roadmap data (website/src/data/roadmap.json).

    python3 tool/github/fetch_roadmap.py --from-file            # from .github/roadmap.toml
    python3 tool/github/fetch_roadmap.py --from-github --repository owner/name

With --from-file it describes the plan in the roadmap file, every issue open:
the copy kept in the repository for offline builds and tests (`make roadmap`,
checked by `make roadmap-check`). With --from-github it reads the live
milestones and the issues labelled "roadmap", with their state, and takes the
Urdu titles from the file; the Deploy workflow runs it before building the
site. If GitHub cannot be reached it falls back to the file and says so,
unless --strict.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import sys
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).resolve().parent))

from roadmap_lib import (
    ROADMAP_FILE,
    ROOT,
    GitHub,
    Roadmap,
    find_marker,
    load,
    strip_marker,
)

OUTPUT = ROOT / "website" / "src" / "data" / "roadmap.json"
REPOSITORY = "ar27111994/maalik-e-makaan"


def from_file(roadmap: Roadmap, repository: str) -> dict[str, Any]:
    return {
        "source": "file",
        "repository": f"https://github.com/{repository}",
        "updated": None,
        "milestones": [
            {
                "id": m.id,
                "number": None,
                "title": m.title,
                "titleUr": m.title_ur,
                "description": m.description,
                "descriptionUr": m.description_ur,
                "due": m.due,
                "state": "open",
                "url": None,
                "issues": [
                    {
                        "id": i.id,
                        "number": None,
                        "title": i.title,
                        "titleUr": i.title_ur,
                        "state": "open",
                        "url": None,
                    }
                    for i in m.issues
                ],
            }
            for m in roadmap.milestones
        ],
    }


def from_github(roadmap: Roadmap, github: GitHub, today: dt.date) -> dict[str, Any]:
    label = roadmap.label.name
    milestones = github.paginate(
        "/milestones", {"state": "all", "sort": "due_on", "direction": "asc"}
    )
    issues = [
        i
        for i in github.paginate("/issues", {"state": "all", "labels": label})
        if "pull_request" not in i
    ]
    planned = {m.id: m for m in roadmap.milestones}
    planned_issues = {i.id: i for m in roadmap.milestones for i in m.issues}
    order = {issue_id: index for index, issue_id in enumerate(roadmap.issue_ids())}

    by_milestone: dict[int, list[dict[str, Any]]] = {}
    for issue in issues:
        milestone = issue.get("milestone")
        if not milestone:
            continue
        issue_id = find_marker(issue.get("body"))
        known = planned_issues.get(issue_id or "")
        by_milestone.setdefault(int(milestone["number"]), []).append(
            {
                "id": issue_id if known else None,
                "number": int(issue["number"]),
                "title": str(issue["title"]).strip(),
                # The Urdu title only while the English one is still the file's.
                "titleUr": (
                    known.title_ur if known and known.title == str(issue["title"]).strip() else None
                ),
                "state": "closed" if issue.get("state") == "closed" else "open",
                "url": issue.get("html_url"),
            }
        )

    out: list[dict[str, Any]] = []
    for milestone in milestones:
        number = int(milestone["number"])
        milestone_id = find_marker(milestone.get("description"))
        known = planned.get(milestone_id or "")
        items = by_milestone.get(number, [])
        if known is None and not items:
            continue  # a milestone that is not on the roadmap
        items.sort(key=lambda i: (order.get(i["id"] or "", len(order)), i["number"]))
        due = milestone.get("due_on")
        out.append(
            {
                "id": milestone_id if known else None,
                "number": number,
                "title": str(milestone["title"]).strip(),
                "titleUr": (
                    known.title_ur
                    if known and known.title == str(milestone["title"]).strip()
                    else None
                ),
                "description": strip_marker(milestone.get("description")),
                "descriptionUr": known.description_ur if known else None,
                "due": str(due)[:10] if due else None,
                "state": "closed" if milestone.get("state") == "closed" else "open",
                "url": milestone.get("html_url"),
                "issues": items,
            }
        )
    out.sort(key=lambda m: (m["due"] or "9999-12-31", m["number"]))
    return {
        "source": "github",
        "repository": f"https://github.com/{github.repository}",
        "updated": today.isoformat(),
        "milestones": out,
    }


def write(data: dict[str, Any], output: Path) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--from-file", action="store_true")
    source.add_argument("--from-github", action="store_true")
    parser.add_argument("--repository", default=os.environ.get("GITHUB_REPOSITORY") or REPOSITORY)
    parser.add_argument("--file", type=Path, default=ROADMAP_FILE)
    parser.add_argument("--output", type=Path, default=OUTPUT)
    parser.add_argument(
        "--strict", action="store_true", help="fail instead of falling back to the file"
    )
    args = parser.parse_args(argv)
    roadmap = load(args.file)
    if args.from_file:
        write(from_file(roadmap, args.repository), args.output)
        print(
            f"Roadmap from {args.file.name}: {len(roadmap.milestones)} milestones -> {args.output}"
        )
        return 0
    try:
        data = from_github(
            roadmap,
            GitHub(args.repository, os.environ.get("GITHUB_TOKEN")),
            dt.datetime.now(dt.UTC).date(),
        )
    except Exception as error:
        if args.strict:
            raise
        print(f"::warning::Roadmap: GitHub could not be read ({error}); using {args.file.name}")
        data = from_file(roadmap, args.repository)
    if data["source"] == "github" and not data["milestones"]:
        # Before the Roadmap workflow has run there is nothing on GitHub yet.
        print("::notice::Roadmap: no roadmap milestones on GitHub yet; using the file")
        data = from_file(roadmap, args.repository)
    write(data, args.output)
    print(f"Roadmap from {data['source']}: {len(data['milestones'])} milestones -> {args.output}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
