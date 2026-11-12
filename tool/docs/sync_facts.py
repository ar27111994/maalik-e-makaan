#!/usr/bin/env python3
"""Keeps the facts the docs repeat in step with their sources.

    python3 tool/docs/sync_facts.py --write               # make docs: rewrite every generated fact
    python3 tool/docs/sync_facts.py --check               # make docs-check: exit 1 on any drift
    python3 tool/docs/sync_facts.py --check --paths F...  # pre-commit: only when F touches a fact
    python3 tool/docs/sync_facts.py --list                # each fact and check, its source, copies
    python3 tool/docs/sync_facts.py --list-files          # the files that hold generated facts

A generated fact sits between markers that name it (`<!-- docs:KEY … -->` and
`<!-- /docs:KEY -->`, or `# docs:KEY …` and `# /docs:KEY` in YAML), and --write rewrites the
text between them from the source (tool/docs/fact_registry.py lists the facts). --write is all
or nothing: with a broken marker or a source it cannot read, it writes no file. --check writes
nothing; it fails when a generated fact is stale, and when a copy the tool checks but does not
write (a version in prose, a workflow pin, a row of the CI table, a `make` reference) disagrees
with its source. `make docs` runs --write, Prettier on the files, then --check.

Exit status: 0 when everything is current, 1 on a stale fact, a disagreeing copy, a broken
marker or a source whose shape changed, 2 on a usage error.
"""

from __future__ import annotations

import argparse
import difflib
import subprocess
import sys
from collections.abc import Sequence
from dataclasses import dataclass, field
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import fact_markers
import fact_registry
from fact_markers import MarkerError, Rendered, Span
from fact_registry import CHECKS, FACTS, Problem
from fact_sources import Repo, SourceShapeError, glob_match

ROOT = Path(__file__).resolve().parents[2]
TOOL_FILES = "tool/docs/*"


@dataclass
class State:
    """What a run found: spans, broken markers, rendered facts and the files they change."""

    texts: dict[str, str] = field(default_factory=dict)
    spans: dict[str, list[Span]] = field(default_factory=dict)
    marker_errors: list[MarkerError] = field(default_factory=list)
    rendered: dict[str, Rendered] = field(default_factory=dict)
    source_errors: dict[tuple[str, str], list[str]] = field(default_factory=dict)
    new_texts: dict[str, str] = field(default_factory=dict)
    changed: dict[str, list[str]] = field(default_factory=dict)

    def not_checked(self, error: SourceShapeError, what: str) -> None:
        self.source_errors.setdefault((error.path, error.message), []).append(what)


def git_ls_files(root: Path) -> list[str]:
    out = subprocess.run(
        ["git", "ls-files", "-z"],  # noqa: S607 - git from PATH, as in every git hook
        capture_output=True,
        check=True,
        cwd=root,
    ).stdout
    return [path for path in out.decode("utf-8").split("\0") if path]


def marker_files(tracked: Sequence[str]) -> list[str]:
    return [p for p in tracked if p.endswith((".md", ".yml", ".yaml")) or p == "llms.txt"]


def list_files() -> list[str]:
    return sorted({path for fact in FACTS for path in fact.targets})


def relevant(paths: Sequence[str]) -> bool:
    """True when a path is a source, a copy, a target, a file a marker can be in, or this tool."""
    patterns = {TOOL_FILES}
    for fact in FACTS:
        patterns.update(fact.reads + fact.targets)
    for check in CHECKS:
        patterns.update(check.reads)
    cleaned = [p[2:] if p.startswith("./") else p for p in paths]
    return bool(marker_files(cleaned)) or any(
        glob_match(path, pattern) for path in cleaned for pattern in patterns
    )


def _render(repo: Repo, state: State) -> None:
    for fact in FACTS:
        try:
            body = fact.render(repo)
        except SourceShapeError as error:
            state.not_checked(error, f"{fact.ident} {fact.key}")
            continue
        bad = fact_registry.unholdable(fact.kind, body)
        if bad:
            state.not_checked(
                SourceShapeError(
                    "tool/docs/fact_registry.py",
                    f"{fact.key} rendered {', '.join(bad)}, which its markers cannot hold",
                ),
                f"{fact.ident} {fact.key}",
            )
            continue
        state.rendered[fact.key] = Rendered(fact.source, body)


def examine(root: Path, repo: Repo) -> State:
    """Scans every file for markers, renders every fact, and computes the files to rewrite."""
    state = State()
    kinds = fact_registry.kinds()
    found: dict[str, list[tuple[str, int]]] = {}
    for path in marker_files(repo.tracked):
        try:
            text = repo.text(path)
        except SourceShapeError:  # deleted but still tracked, or not UTF-8
            continue
        if "docs:" not in text:
            continue
        state.texts[path] = text
        spans, errors = fact_markers.scan(path, text, kinds)
        state.marker_errors += errors
        found[path] = fact_markers.markers_in(text, path)
        if spans and not errors:
            state.spans[path] = spans
    state.marker_errors += fact_markers.check_placement(found, fact_registry.targets())
    _render(repo, state)
    for path, spans in state.spans.items():
        new, changed = fact_markers.rewrite(state.texts[path], spans, state.rendered)
        if changed:
            state.new_texts[path] = new
            state.changed[path] = changed
    return state


def _report_errors(state: State, out: list[str]) -> None:
    for error in sorted(state.marker_errors, key=lambda e: (e.path, e.line, e.rule, e.message)):
        out.append(str(error))
    for (path, message), what in sorted(state.source_errors.items()):
        out.append(f"source: {path}: {message}")
        out.append(f"  not checked: {', '.join(what)}")


def write(root: Path, state: State) -> int:
    if state.marker_errors or state.source_errors:
        out: list[str] = []
        _report_errors(state, out)
        out.append("make docs: wrote nothing; fix the problems above, then run it again.")
        print("\n".join(out), file=sys.stderr)
        return 1
    for path in sorted(state.new_texts):
        (root / path).write_bytes(state.new_texts[path].encode("utf-8"))
        keys = ", ".join(dict.fromkeys(state.changed[path]))
        print(f"make docs: rewrote {path} ({keys})")
    if not state.new_texts:
        print("make docs: every generated fact is current")
    return 0


def _plural(n: int, one: str, many: str) -> str:
    return f"{n} {one if n == 1 else many}"


def check(state: State, repo: Repo) -> int:
    problems: list[Problem] = []
    for item in CHECKS:
        try:
            problems += item.run(repo, repo.tracked)
        except SourceShapeError as error:
            state.not_checked(error, f"{item.ident} {item.name}")
    problems = sorted(set(problems), key=lambda p: (p.path, p.line, p.message))
    out: list[str] = []
    _report_errors(state, out)
    stale = sum(len(keys) for keys in state.changed.values())
    if stale:
        if out:
            out.append("")
        verb = "is" if stale == 1 else "are"
        out.append(
            f"docs-check: {_plural(stale, 'generated fact', 'generated facts')} {verb} stale:"
        )
        for path in sorted(state.new_texts):
            out.append("")
            out.append(
                "".join(
                    difflib.unified_diff(
                        state.texts[path].splitlines(keepends=True),
                        state.new_texts[path].splitlines(keepends=True),
                        fromfile=f"a/{path}",
                        tofile=f"b/{path} (after make docs)",
                    )
                ).rstrip("\n")
            )
    if problems:
        if out:
            out.append("")
        out.append(
            "docs-check: 1 copy disagrees with its source; fix it by hand:"
            if len(problems) == 1
            else f"docs-check: {len(problems)} copies disagree with their sources; fix them by hand:"
        )
        out += [f"  {problem}" for problem in problems]
    if not out:
        print(
            f"docs-check: {_plural(len(FACTS), 'generated fact', 'generated facts')} and"
            f" {_plural(len(CHECKS), 'check', 'checks')} agree with their sources"
        )
        return 0
    out.append("")
    if stale:
        then = ", then fix the copies listed above." if problems else "."
        out.append("Run `make docs` to rewrite the generated facts (it also runs Prettier)" + then)
    elif problems:
        out.append("Fix the copies listed above; `make docs` does not write them.")
    if state.marker_errors or state.source_errors:
        out.append(
            "Broken markers and sources are explained in docs/agents/conventions.md,"
            " Generated files."
        )
    print("\n".join(out), file=sys.stderr)
    return 1


def print_list() -> None:
    lines = ["Generated facts (make docs writes them between markers):"]
    for fact in FACTS:
        lines.append(f"  {fact.ident:<4}{fact.key:<26}{fact.kind:<8}from {fact.source}")
        lines.append(f"      in {', '.join(fact.targets)}")
    lines.append("")
    lines.append("Checked copies (make docs-check compares them; fix them by hand):")
    for item in CHECKS:
        lines.append(f"  {item.ident:<4}{item.name:<26}{item.describe}")
        lines.append(f"      reads {', '.join(item.reads)}")
    print("\n".join(lines))


def main(
    argv: Sequence[str] | None = None, *, root: Path = ROOT, tracked: Sequence[str] | None = None
) -> int:
    parser = argparse.ArgumentParser(
        prog="tool/docs/sync_facts.py",
        description="Keep the facts the docs repeat in step with their sources.",
    )
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--write", action="store_true", help="rewrite every generated fact")
    mode.add_argument("--check", action="store_true", help="fail on any stale or disagreeing fact")
    mode.add_argument("--list", action="store_true", help="list the facts and checks")
    mode.add_argument("--list-files", action="store_true", help="list the files with facts")
    parser.add_argument(
        "--paths", nargs="*", metavar="PATH", help="with --check: do nothing unless one is relevant"
    )
    try:
        args = parser.parse_args(argv)
    except SystemExit as exit_:
        return exit_.code if isinstance(exit_.code, int) else 2
    if args.paths is not None and not args.check:
        parser.print_usage(sys.stderr)
        print(f"{parser.prog}: error: --paths goes with --check", file=sys.stderr)
        return 2
    if args.list:
        print_list()
        return 0
    if args.list_files:
        print("\n".join(list_files()))
        return 0
    if args.paths is not None and not relevant(args.paths):
        return 0
    if tracked is None:
        try:
            tracked = git_ls_files(root)
        except (OSError, subprocess.CalledProcessError) as error:
            print(f"{parser.prog}: cannot list the tracked files: {error}", file=sys.stderr)
            return 1
    repo = Repo(root, tracked)
    state = examine(root, repo)
    if args.write:
        return write(root, state)
    return check(state, repo)


if __name__ == "__main__":
    sys.exit(main())
