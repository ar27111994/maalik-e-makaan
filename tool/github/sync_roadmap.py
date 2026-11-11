#!/usr/bin/env python3
"""Creates and updates the roadmap's GitHub label, milestones and issues.

    GITHUB_TOKEN=... python3 tool/github/sync_roadmap.py --repository owner/name [--dry-run]

Reads .github/roadmap.toml. What is missing is created; a milestone's title,
description and due date are brought back in step with the file. Nothing is
closed, reopened or deleted, and an issue is never rewritten after it is
created: from then on it is managed on GitHub. Milestones and issues are
matched by the hidden roadmap id in their description or body (an issue only
when the project opened it, so an outsider who copies the id cannot stand in
for it), then a milestone by its title, ignoring case, unless another roadmap
id has that milestone. Milestones that trade titles are renamed in an order
GitHub accepts. The Roadmap workflow runs it when the file changes.
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


class SyncError(RuntimeError):
    """GitHub holds something that only a person can bring in step with the roadmap."""


def fold(title: str) -> str:
    """A milestone title as GitHub compares it: two titles that differ only in case are one."""
    return title.casefold()


def sync(roadmap: Roadmap, github: GitHub, *, dry_run: bool = False, log=print) -> dict[str, int]:
    """Brings GitHub in step with the roadmap. Returns counts of what was (or would be) done.

    Everything is read and planned before the first write: when a title the roadmap needs is held
    by a milestone that is not the roadmap's to rename (SyncError), nothing is changed.
    """
    counts = {"created": 0, "updated": 0, "unchanged": 0}

    def write(method: str, path: str, body: dict[str, Any]) -> Any:
        if dry_run:
            return {"number": -1}
        return github.request(method, path, body)

    label = roadmap.label
    wanted_label = {"color": label.color.lower(), "description": label.description}
    current = github.get_or_none(f"/labels/{label.name}")

    # Milestones, matched by their hidden id. One that has none takes the milestone with its
    # title (ignoring case, as GitHub does) only if no roadmap id has that milestone, in this run
    # or in its description; otherwise it is a new milestone.
    existing = github.paginate("/milestones", {"state": "all"})
    by_id = {
        find_marker(m.get("description")): m for m in existing if find_marker(m.get("description"))
    }
    by_title = {fold(str(m.get("title") or "")): m for m in existing}
    roadmap_ids = {m.id for m in roadmap.milestones}
    found: dict[str, dict[str, Any] | None] = {m.id: by_id.get(m.id) for m in roadmap.milestones}
    taken = {int(m["number"]) for m in found.values() if m is not None}
    for milestone in roadmap.milestones:
        candidate = by_title.get(fold(milestone.title))
        if (
            found[milestone.id] is None
            and candidate is not None
            and int(candidate["number"]) not in taken
            and find_marker(candidate.get("description")) not in roadmap_ids
        ):
            found[milestone.id] = candidate
            taken.add(int(candidate["number"]))

    def wanted(milestone: Milestone) -> dict[str, str]:
        return {
            "title": milestone.title,
            "description": milestone_description(milestone),
            "due_on": due_on(milestone.due),
        }

    numbers: dict[str, int] = {}
    pending: list[Milestone] = []
    for milestone in roadmap.milestones:
        match = found[milestone.id]
        if match is None:
            pending.append(milestone)
            continue
        numbers[milestone.id] = int(match["number"])
        if (
            match.get("title") == milestone.title
            and (match.get("description") or "") == wanted(milestone)["description"]
            and str(match.get("due_on") or "")[:10] == milestone.due
        ):
            counts["unchanged"] += 1
        else:
            pending.append(milestone)

    # GitHub refuses a milestone a title another milestone has, so a title is written only once
    # the milestone that has it now has moved to its own. A milestone on the roadmap always moves:
    # the file's titles are unique (roadmap_lib.load). One that is not on the roadmap never does.
    titles = {int(m["number"]): str(m.get("title") or "") for m in existing}
    holders = {fold(title): number for number, title in titles.items()}
    owners = {numbers[m.id]: m for m in pending if m.id in numbers}
    for milestone in pending:
        holder = holders.get(fold(milestone.title))
        if holder is not None and holder != numbers.get(milestone.id) and holder not in owners:
            raise SyncError(
                f"milestone {milestone.id}: GitHub's milestone #{holder} already has the title "
                f"{titles[holder]!r} and is not the roadmap's to rename; rename or delete it on "
                f"GitHub, or give {milestone.id} another title"
            )

    def waits_for(milestone: Milestone) -> Milestone | None:
        """The roadmap milestone that has this one's title now, while it has it."""
        holder = holders.get(fold(milestone.title))
        if holder is None or holder == numbers.get(milestone.id):
            return None
        return owners[holder]

    def retitle(number: int, title: str) -> None:
        if holders.get(fold(titles[number])) == number:
            del holders[fold(titles[number])]
        holders[fold(title)] = number
        titles[number] = title

    # The label first: an issue cannot carry a label that does not exist yet.
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

    targets = {fold(m.title) for m in roadmap.milestones}
    while pending:
        ready = next((m for m in pending if waits_for(m) is None), None)
        if ready is None:
            # Every milestone left waits for another's title, so their titles go round a ring
            # (two milestones swapping titles, say). Follow it from the first, and give one of
            # the ring a passing title that frees its own for the milestone that waits for it.
            seen: list[Milestone] = []
            ring = pending[0]
            while ring not in seen:
                seen.append(ring)
                ring = waits_for(ring) or ring
            number = numbers[ring.id]
            passing, count = f"{titles[number]} (renaming)", 1
            while fold(passing) in holders or fold(passing) in targets:
                count += 1
                passing = f"{titles[number]} (renaming {count})"
            write("PATCH", f"/milestones/{number}", {"title": passing})
            log(f"milestone {ring.id}: titled {passing!r} for now, to free {titles[number]!r}")
            retitle(number, passing)
            continue
        pending.remove(ready)
        if ready.id in numbers:
            write("PATCH", f"/milestones/{numbers[ready.id]}", wanted(ready))
            retitle(numbers[ready.id], ready.title)
            log(f"milestone {ready.id}: updated")
            counts["updated"] += 1
        else:
            created = write("POST", "/milestones", wanted(ready))
            numbers[ready.id] = int(created["number"])
            titles[numbers[ready.id]] = ready.title
            holders[fold(ready.title)] = numbers[ready.id]
            log(f"milestone {ready.id}: created")
            counts["created"] += 1

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
    try:
        counts = sync(roadmap, GitHub(args.repository, token), dry_run=args.dry_run)
    except SyncError as error:
        print(f"Roadmap: {error}", file=sys.stderr)
        return 1
    verb = "would be" if args.dry_run else "were"
    print(
        f"Roadmap: {counts['created']} {verb} created, {counts['updated']} {verb} updated, "
        f"{counts['unchanged']} already in step."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
