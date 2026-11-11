#!/usr/bin/env python3
"""Creates and updates the roadmap's GitHub label, milestones and issues.

    GITHUB_TOKEN=... python3 tool/github/sync_roadmap.py --repository owner/name [--dry-run]

Reads .github/roadmap.toml. What is missing is created; a milestone's title,
description and due date are brought back in step with the file. Nothing is
closed, reopened or deleted, and an issue is never rewritten after it is
created: from then on it is managed on GitHub. Milestones and issues are
matched by the hidden roadmap id in their description or body (an issue only
when the project opened it, so an outsider who copies the id cannot stand in
for it), then a milestone by its title, unless another roadmap id has that
milestone. The Roadmap workflow runs it when the file changes.
"""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).resolve().parent))

from roadmap_lib import (
    ROADMAP_FILE,
    GitHub,
    Milestone,
    Roadmap,
    find_marker,
    load,
    marker,
    opened_by_project,
)


def milestone_description(milestone: Milestone) -> str:
    return f"{milestone.description}\n\n{marker(milestone.id)}"


def issue_body(body: str, issue_id: str) -> str:
    return f"{body.strip()}\n\n{marker(issue_id)}"


def due_on(date: str) -> str:
    """GitHub stores a due date as a timestamp; noon UTC keeps the day in every time zone."""
    return f"{date}T12:00:00Z"


def sync(roadmap: Roadmap, github: GitHub, *, dry_run: bool = False, log=print) -> dict[str, int]:
    """Brings GitHub in step with the roadmap. Returns counts of what was (or would be) done."""
    counts = {"created": 0, "updated": 0, "unchanged": 0}

    def write(method: str, path: str, body: dict[str, Any]) -> Any:
        if dry_run:
            return {"number": -1}
        return github.request(method, path, body)

    # The label every roadmap issue carries.
    label = roadmap.label
    wanted_label = {"color": label.color.lower(), "description": label.description}
    current = github.get_or_none(f"/labels/{label.name}")
    if current is None:
        write("POST", "/labels", {"name": label.name, **wanted_label})
        log(f"label {label.name}: created")
        counts["created"] += 1
    elif {
        "color": str(current.get("color", "")).lower(),
        "description": current.get("description") or "",
    } != wanted_label:
        write("PATCH", f"/labels/{label.name}", wanted_label)
        log(f"label {label.name}: updated")
        counts["updated"] += 1
    else:
        counts["unchanged"] += 1

    # Milestones, matched by their hidden id, then by title.
    existing = github.paginate("/milestones", {"state": "all"})
    by_id = {
        find_marker(m.get("description")): m for m in existing if find_marker(m.get("description"))
    }
    by_title = {m.get("title"): m for m in existing}
    roadmap_ids = {m.id for m in roadmap.milestones}
    matched = {m.id: by_id[m.id] for m in roadmap.milestones if m.id in by_id}
    taken = {int(m["number"]) for m in matched.values()}
    numbers: dict[str, int] = {}

    def bring_in_step(milestone: Milestone, found: dict[str, Any] | None) -> None:
        wanted = {
            "title": milestone.title,
            "description": milestone_description(milestone),
            "due_on": due_on(milestone.due),
        }
        if found is None:
            created = write("POST", "/milestones", wanted)
            numbers[milestone.id] = int(created["number"])
            log(f"milestone {milestone.id}: created")
            counts["created"] += 1
            return
        numbers[milestone.id] = int(found["number"])
        same = (
            found.get("title") == wanted["title"]
            and (found.get("description") or "") == wanted["description"]
            and str(found.get("due_on") or "")[:10] == milestone.due
        )
        if same:
            counts["unchanged"] += 1
        else:
            write("PATCH", f"/milestones/{found['number']}", wanted)
            log(f"milestone {milestone.id}: updated")
            counts["updated"] += 1

    # Those found by id first: a renamed milestone gives up its old title before another
    # milestone in the file takes that title (GitHub refuses two milestones with one title).
    for milestone in roadmap.milestones:
        if milestone.id in matched:
            bring_in_step(milestone, matched[milestone.id])
    # Then the rest, each taking the milestone with its title only if no roadmap id has that
    # milestone, in this run or in its description; otherwise a new milestone.
    for milestone in roadmap.milestones:
        if milestone.id in matched:
            continue
        found = by_title.get(milestone.title)
        if found is not None and (
            int(found["number"]) in taken or find_marker(found.get("description")) in roadmap_ids
        ):
            found = None
        if found is not None:
            taken.add(int(found["number"]))
        bring_in_step(milestone, found)

    # Issues, matched by their hidden id among every issue the project opened, open or closed,
    # with the label or without: an issue whose label was taken off is still the roadmap's, and
    # creating it again would duplicate it. An issue someone else opened with a roadmap id in it
    # is not the roadmap's (roadmap_lib.opened_by_project). Pull requests share the issues
    # endpoint; skip them.
    issues = github.paginate("/issues", {"state": "all"})
    known = {
        find_marker(i.get("body"))
        for i in issues
        if "pull_request" not in i and opened_by_project(i)
    }
    for milestone in roadmap.milestones:
        for issue in milestone.issues:
            if issue.id in known:
                counts["unchanged"] += 1
                continue
            write(
                "POST",
                "/issues",
                {
                    "title": issue.title,
                    "body": issue_body(issue.body, issue.id),
                    "labels": [label.name],
                    "milestone": numbers[milestone.id],
                },
            )
            log(f"issue {issue.id}: created in {milestone.id}")
            counts["created"] += 1
    return counts


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--repository", default=os.environ.get("GITHUB_REPOSITORY"))
    parser.add_argument("--file", type=Path, default=ROADMAP_FILE)
    parser.add_argument(
        "--dry-run", action="store_true", help="say what would change, change nothing"
    )
    args = parser.parse_args(argv)
    if not args.repository:
        parser.error("--repository (or GITHUB_REPOSITORY) is required")
    token = os.environ.get("GITHUB_TOKEN")
    if not token and not args.dry_run:
        parser.error("GITHUB_TOKEN is required unless --dry-run")
    roadmap = load(args.file)
    counts = sync(roadmap, GitHub(args.repository, token), dry_run=args.dry_run)
    verb = "would be" if args.dry_run else "were"
    print(
        f"Roadmap: {counts['created']} {verb} created, {counts['updated']} {verb} updated, "
        f"{counts['unchanged']} already in step."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
