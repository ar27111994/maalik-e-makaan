#!/usr/bin/env python3
"""Check that every workflow job that starts the local Supabase stack reserves its host ports.

Linux gives an outgoing connection a local port from net.ipv4.ip_local_port_range (32768 to
60999 by default), and while that socket lives, or lingers in TIME_WAIT, binding the wildcard
address to the same port fails with EADDRINUSE. The stack's host ports (supabase/config.toml)
lie in that range, and a job binds them straight after pulling the images over many
connections: run 43740334888 failed so, on 0.0.0.0:54322. net.ipv4.ip_local_reserved_ports keeps
listed ports from automatic assignment and leaves explicit binds alone, but it does not free a
port a socket already holds, so each job that starts the stack runs as its first step, before
anything connects out, in exactly this spelling:

    - name: Reserve the local stack's host ports
      run: |
        reserved="$(cat /proc/sys/net/ipv4/ip_local_reserved_ports)"
        echo "${reserved:+$reserved,}54320-54329" | sudo tee /proc/sys/net/ipv4/ip_local_reserved_ports

The write keeps any ports already reserved; tee fails the step when the kernel refuses it, where
`sysctl -w` would print "ignoring" and exit 0. This check requires, for every such job in
.github/workflows:

- the step, by that name and in that spelling, as the job's first step;
- a range that covers every port supabase/config.toml names (a key `port` or ending in `_port`)
  inside the kernel's default automatic range, since a port below it is never given out;
- no `if:` on the step, and `continue-on-error` only where the start it guards has it too and
  runs only when the step succeeded, `if: … steps.<its id>.outcome == 'success'` (the backup's
  restore check, whose last step then fails the run), so a failed reservation cannot pass in
  silence.

A step starts the stack when its `run:` (backslash-continued lines joined, comment lines left
out) runs `supabase start` or `supabase db start`, with or without CLI options before `start`
(`supabase --workdir . start`), or runs `make test-uat` or tool/uat/run.sh, which starts the
stack itself when it is not running.

    python3 tool/github/check_stack_ports.py [repository root]
"""

from __future__ import annotations

import re
import sys
import tomllib
from collections.abc import Iterator
from dataclasses import dataclass
from pathlib import Path

import yaml

sys.path.insert(0, str(Path(__file__).resolve().parent))

from check_workflow_calls import Problem, compose, get, is_true, items, line_of, scalar

ROOT = Path(__file__).resolve().parents[2]
WORKFLOWS = ".github/workflows"
CONFIG = "supabase/config.toml"
# The kernel's default net.ipv4.ip_local_port_range (Documentation/networking/ip-sysctl.rst).
AUTOMATIC = range(32768, 60999 + 1)
NAME = "Reserve the local stack's host ports"
SYSCTL = "/proc/sys/net/ipv4/ip_local_reserved_ports"
RUN = re.compile(
    r'reserved="\$\(cat ' + re.escape(SYSCTL) + r'\)"\n'
    r'echo "\$\{reserved:\+\$reserved,\}(\d+)-(\d+)" \| sudo tee ' + re.escape(SYSCTL) + r"\n?"
)
SPELLING = (
    f'reserved="$(cat {SYSCTL})" then '
    f'echo "${{reserved:+$reserved,}}<first>-<last>" | sudo tee {SYSCTL}'
)
# CLI options between `supabase` and `start`: `-x`, `--debug`, `--workdir=.`, `--workdir .`. A
# value is a word that is not an option, `db` or `start`; option and value each have one way to
# match, so a long line that does not start the stack fails at once.
_OPTIONS = r"(?:\s+-{1,2}\w[\w-]*(?:=\S*|\s+(?!-|(?:db|start)\b)\S+)?)*"
START = re.compile(rf"\bsupabase{_OPTIONS}\s+(?:db{_OPTIONS}\s+)?start\b")
# tool/uat/run.sh runs `"${SUPABASE[@]}" start` when the stack is not running, and the Makefile's
# test-uat runs it (test_check_stack_ports.py keeps both true).
UAT_STARTS = re.compile(r"\bmake\b[^\n;&|#]*\stest-uat(?![\w-])|\btool/uat/run\.sh(?![\w.-])")
WHY = "docs/agents/conventions.md, Workflows and actions"


@dataclass(frozen=True)
class Port:
    number: int
    where: str  # its table and key in supabase/config.toml


def config_ports(config: dict, table: str = "") -> Iterator[Port]:
    """Every integer under a key `port` or ending in `_port`, in any table."""
    for key, value in config.items():
        where = f"{table}.{key}" if table else key
        if isinstance(value, dict):
            yield from config_ports(value, where)
        elif (key == "port" or key.endswith("_port")) and type(value) is int:
            yield Port(value, where)


def starts_stack(run: str) -> bool:
    """Whether a `run:` script starts the stack, outside a comment line."""
    joined = re.sub(r"\\\n", " ", run)
    return any(
        START.search(line) or UAT_STARTS.search(line)
        for line in joined.splitlines()
        if not line.lstrip().startswith("#")
    )


class Checker:
    def __init__(self, root: Path) -> None:
        self.root = root
        config = tomllib.loads((root / CONFIG).read_text(encoding="utf-8"))
        self.ports = [port for port in config_ports(config) if port.number in AUTOMATIC]

    def problems(self, files: list[str]) -> list[Problem]:
        found: list[Problem] = []
        for path in files:
            try:
                document = compose((self.root / path).read_text(encoding="utf-8"))
            except (OSError, UnicodeDecodeError, yaml.YAMLError) as error:
                found.append(Problem(path, 1, f"cannot read it ({error})"))
                continue
            for name, job in items(get(document, "jobs")):
                found += self.check_job(path, name.value, job)
        return found

    def check_job(self, path: str, job_name: str, job: yaml.Node) -> list[Problem]:
        steps = get(job, "steps")
        steps = steps.value if isinstance(steps, yaml.SequenceNode) else []
        reserves = [step for step in steps if scalar(get(step, "name")) == NAME]
        found: list[Problem] = []
        for step in reserves:
            found += self.check_reserve(path, step, scalar(get(step, "run")) or "")
        unguarded = False
        starts = False
        for index, step in enumerate(steps):
            if step not in reserves and starts_stack(scalar(get(step, "run")) or ""):
                starts = True
                before = [r for r in reserves if steps.index(r) < index]
                if before:
                    found += self.check_start(path, step, before[0])
                    continue
                unguarded = True
                later = (
                    f" (the one at line {line_of(reserves[0])} comes after it)" if reserves else ""
                )
                found.append(
                    Problem(
                        path,
                        line_of(step),
                        f'job {job_name!r} starts the local stack with no "{NAME}" step before'
                        f" it{later}; make that step the job's first ({WHY})",
                    )
                )
                break  # one fix serves every later start
        # A reservation does not free a port a socket already holds, so it must come before
        # every step that connects out: the first. (A start with none before it is named above.)
        if starts and not unguarded and steps.index(reserves[0]) != 0:
            found.append(
                Problem(
                    path,
                    line_of(reserves[0]),
                    f'job {job_name!r}: "{NAME}" is step {steps.index(reserves[0]) + 1};'
                    f" make it the job's first ({WHY})",
                )
            )
        return found

    def check_reserve(self, path: str, step: yaml.Node, run: str) -> list[Problem]:
        line = line_of(step)
        match = RUN.fullmatch(run)
        if match is None:
            return [Problem(path, line, f'"{NAME}" must run exactly: {SPELLING} ({WHY})')]
        found = []
        first, last = int(match[1]), int(match[2])
        if first > last:
            found.append(Problem(path, line, f"the reserved range {first}-{last} is empty"))
        for port in self.ports:
            if not first <= port.number <= last:
                found.append(
                    Problem(
                        path,
                        line,
                        f"the reserved range {first}-{last} leaves out {port.number}"
                        f" ({CONFIG}, {port.where}); widen it to cover every port there",
                    )
                )
        if get(step, "if") is not None:
            found.append(
                Problem(path, line, f'"{NAME}" has an if:, so it can be skipped; remove it')
            )
        return found

    def check_start(self, path: str, step: yaml.Node, reserve: yaml.Node) -> list[Problem]:
        """A reservation that may fail (continue-on-error) must stop the start it guards, which
        must itself be allowed to fail: the job then reports the failure its own way."""
        if not is_true(get(reserve, "continue-on-error")):
            return []
        line = line_of(step)
        if not is_true(get(step, "continue-on-error")):
            return [
                Problem(
                    path,
                    line_of(reserve),
                    f'"{NAME}" has continue-on-error, but the start it guards (line {line})'
                    " does not, so a failed reservation would pass in silence; remove it",
                )
            ]
        step_id = scalar(get(reserve, "id")) or "reserve"
        guard = f"steps.{step_id}.outcome == 'success'"
        if get(reserve, "id") is None or guard not in (scalar(get(step, "if")) or ""):
            return [
                Problem(
                    path,
                    line,
                    f'this start runs even when "{NAME}" failed (it has continue-on-error):'
                    f' give that step an id and add "{guard}" to this step\'s if:',
                )
            ]
        return []


def workflow_files(root: Path) -> list[str]:
    folder = root / WORKFLOWS
    return sorted(
        f"{WORKFLOWS}/{path.name}" for path in folder.glob("*") if path.suffix in (".yml", ".yaml")
    )


def main(argv: list[str]) -> int:
    root = Path(argv[0]) if argv else ROOT
    files = workflow_files(root)
    try:
        checker = Checker(root)
    except (OSError, UnicodeDecodeError, tomllib.TOMLDecodeError) as error:
        print(f"{CONFIG}:1: cannot read it ({error})", file=sys.stderr)
        return 1
    found = checker.problems(files)
    for problem in found:
        print(problem, file=sys.stderr)
    if not found:
        listed = ", ".join(sorted({str(port.number) for port in checker.ports}))
        print(
            f"Every job that starts the local stack reserves its host ports first ({listed};"
            f" {len(files)} workflow file(s))."
        )
    return 1 if found else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
