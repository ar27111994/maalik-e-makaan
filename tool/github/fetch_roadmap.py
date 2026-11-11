#!/usr/bin/env python3
"""Writes the website's roadmap data (website/src/data/roadmap.json).

    python3 tool/github/fetch_roadmap.py --from-file            # from .github/roadmap.toml
    python3 tool/github/fetch_roadmap.py --from-github --repository owner/name

With --from-file it describes the plan in the roadmap file, every issue open:
the copy kept in the repository for offline builds and tests (`make roadmap`,
checked by `make roadmap-check`), always naming the project's own repository.
With --from-github it reads the live milestones and the issues labelled
"roadmap", with their state (a labelled issue in no milestone is listed as not
yet scheduled), and takes the Urdu text from the file while the English it
translates is unchanged; the Deploy workflow runs it before building the site.
If GitHub cannot be reached it falls back to the file and says so, unless
--strict.

Two kinds of labelled issue stay off the site. One that someone outside the
project opened: its author can retitle it at any time, and the weekly refresh
would publish the new title unseen (roadmap_lib.opened_by_project). And one
closed as not planned or as a duplicate: it was dropped, not done, so it is
neither listed nor counted.
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
    opened_by_project,
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
        "unscheduled": [],
    }


def state(issue: dict[str, Any]) -> str | None:
    """An issue's state on the site: open, closed (done), or None when it was closed undone.

    GitHub gives a closed issue's reason as "completed", "not_planned" or "duplicate"; one closed
    before GitHub kept reasons has none, and GitHub shows it as completed.
    """
    if issue.get("state") != "closed":
        return "open"
    return "closed" if issue.get("state_reason") in ("completed", None) else None


def from_github(roadmap: Roadmap, github: GitHub, today: dt.date) -> dict[str, Any]:
    label = roadmap.label.name
    milestones = github.paginate(
        "/milestones", {"state": "all", "sort": "due_on", "direction": "asc"}
    )
    issues = [
        i
        for i in github.paginate("/issues", {"state": "all", "labels": label})
        if "pull_request" not in i and opened_by_project(i) and state(i) is not None
    ]
    planned = {m.id: m for m in roadmap.milestones}
    planned_issues = {i.id: i for m in roadmap.milestones for i in m.issues}
    order = {issue_id: index for index, issue_id in enumerate(roadmap.issue_ids())}

    def entry(issue: dict[str, Any]) -> dict[str, Any]:
        issue_id = find_marker(issue.get("body"))
        known = planned_issues.get(issue_id or "")
        title = str(issue["title"]).strip()
        return {
            "id": issue_id if known else None,
            "number": int(issue["number"]),
            "title": title,
            # The Urdu title only while the English one is still the file's.
            "titleUr": known.title_ur if known and known.title == title else None,
            "state": state(issue),
            "url": issue.get("html_url"),
        }

    by_milestone: dict[int, list[dict[str, Any]]] = {}
    # Labelled issues in no milestone yet: still on the roadmap, so still shown.
    unscheduled: list[dict[str, Any]] = []
    for issue in issues:
        milestone = issue.get("milestone")
        if milestone:
            by_milestone.setdefault(int(milestone["number"]), []).append(entry(issue))
        else:
            unscheduled.append(entry(issue))
    unscheduled.sort(key=lambda i: i["number"])

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
        title = str(milestone["title"]).strip()
        description = strip_marker(milestone.get("description"))
        out.append(
            {
                "id": milestone_id if known else None,
                "number": number,
                "title": title,
                # The Urdu text only while the English it translates is still the file's.
                "titleUr": known.title_ur if known and known.title == title else None,
                "description": description,
                "descriptionUr": (
                    known.description_ur
                    if known and known.description.strip() == description
                    else None
                ),
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
        "unscheduled": unscheduled,
    }


def write(data: dict[str, Any], output: Path) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--from-file", action="store_true")
    source.add_argument("--from-github", action="store_true")
    # The file's copy names this repository unless told otherwise, as `make roadmap-check`
    # expects; GITHUB_REPOSITORY (set in Codespaces and on forks) applies to --from-github only.
    parser.add_argument(
        "--repository",
        help=f"owner/name (default {REPOSITORY}; with --from-github, GITHUB_REPOSITORY first)",
    )
    parser.add_argument("--file", type=Path, default=ROADMAP_FILE)
    parser.add_argument("--output", type=Path, default=OUTPUT)
    parser.add_argument(
        "--strict", action="store_true", help="fail instead of falling back to the file"
    )
    args = parser.parse_args(argv)
    roadmap = load(args.file)
    if args.from_file:
        write(from_file(roadmap, args.repository or REPOSITORY), args.output)
        print(
            f"Roadmap from {args.file.name}: {len(roadmap.milestones)} milestones -> {args.output}"
        )
        return 0
    repository = args.repository or os.environ.get("GITHUB_REPOSITORY") or REPOSITORY
    try:
        data = from_github(
            roadmap,
            GitHub(repository, os.environ.get("GITHUB_TOKEN")),
            dt.datetime.now(dt.UTC).date(),
        )
    except Exception as error:
        if args.strict:
            raise
        print(f"::warning::Roadmap: GitHub could not be read ({error}); using {args.file.name}")
        data = from_file(roadmap, repository)
    if data["source"] == "github" and not data["milestones"]:
        # Before the Roadmap workflow has run there is nothing on GitHub yet.
        print("::notice::Roadmap: no roadmap milestones on GitHub yet; using the file")
        data = from_file(roadmap, repository)
    write(data, args.output)
    print(f"Roadmap from {data['source']}: {len(data['milestones'])} milestones -> {args.output}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
