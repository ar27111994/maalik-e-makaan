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

- the step, by that name and in that spelling, once, as the job's first step, and not as a
  `background:` step or inside a `parallel:` group, where the next step would not wait for it;
- a range that covers every port supabase/config.toml names (a key `port` or ending in `_port`)
  inside the kernel's default automatic range, since a port below it is never given out;
- no `if:` on the step, and `continue-on-error` only where the start it guards has it too and
  runs only when the step succeeded (the backup's restore check, whose last step then fails the
  run), so a failed reservation cannot pass in silence. Both are written as a plain `true`: an
  expression there is refused, because the check cannot tell what it comes to. That start's
  `if:` must be terms joined by `&&`, one of them exactly `steps.<its id>.outcome == 'success'`,
  where the id is the reservation's own. A condition the check cannot read so is refused: an
  `||` outside brackets, which lets the step run without the term, the term inside brackets or a
  function's arguments, and `${{ }}` with anything before or after it, even a space or the
  newline that ends a `|` or `>` block, which GitHub reads as text and so as true.

How GitHub reads these values is taken from its own readers, which agree: template-reader.ts in
actions/languageservices (workflow-parser) and TemplateReader.cs in actions/runner. Both refuse a
key written twice ("is already defined") and a key the schema does not know, such as a YAML
merge key `<<` ("Unexpected value"), so this check does not look for either; actionlint, in the
same `make lint`, names both. The step keys (`background`, `parallel`) are those of
workflow-v1.0.json in actions/languageservices.

A step starts the stack when its `run:` (backslash-continued lines joined, comment lines left
out) runs `supabase start` or `supabase db start`, with or without CLI options before `start`
(`supabase --workdir . start`) or a version after the name (`npx supabase@2 start`), or runs
`make test-uat` or tool/uat/run.sh, which starts the stack itself when it is not running. Steps
inside a `parallel:` group are read too.

What it does not see: a stack started by an action (a composite one included), a reusable
workflow, another script, or a command put together from an expression or a variable. Whoever
adds one of those reserves the ports by hand, and a reviewer reads it.

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

from check_workflow_calls import Problem, compose, get, is_true, items, kind_of, line_of, scalar

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
START = re.compile(rf"\bsupabase(?:@[\w.-]+)?{_OPTIONS}\s+(?:db{_OPTIONS}\s+)?start\b")
# tool/uat/run.sh runs `"${SUPABASE[@]}" start` when the stack is not running, and the Makefile's
# test-uat runs it (test_check_stack_ports.py keeps both true).
UAT_STARTS = re.compile(r"\bmake\b[^\n;&|#]*\stest-uat(?![\w-])|\btool/uat/run\.sh(?![\w.-])")
WHY = "docs/agents/conventions.md, Workflows and actions"
_SPACES = re.compile(r"[ \t\r\n]+")
# A step id as GitHub allows it; nothing in one can end the guard's term or start another.
ID = re.compile(r"[A-Za-z_][A-Za-z0-9_-]*")
# The spellings GitHub's readers take as a boolean; a tagged `!!bool yes` is not one of them.
BOOLEANS = ("true", "True", "TRUE", "false", "False", "FALSE")


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


def terms(condition: str) -> list[str] | None:
    """The `&&`-joined terms of an `if:`, spaces collapsed, or None when it is not only that.

    GitHub reads a value with no `${{` as one expression. In a value with one, the expression
    ends at the first `}}` outside a string, and any character before the `${{` or after that
    `}}` (a space, the newline that ends a `|` or `>` block) makes the whole a text, which is
    true whatever it says (actions/runner, TemplateReader.ParseScalar). So `${{ }}` is taken off
    only where the value starts and ends with it, and None is the answer for another `${{`, a
    brace outside a string, an `||` outside brackets (the step then runs without the other
    side), and a bracket or a string left open. A `&&` or `||` inside brackets or a string
    belongs to its term.
    """
    text = condition
    if "${{" in text:
        if not (text.startswith("${{") and text.endswith("}}")):
            return None
        text = text[3:-2]
        if "${{" in text:
            return None
    found: list[str] = []
    start = depth = 0
    quoted = False
    index = 0
    while index < len(text):
        char = text[index]
        if quoted:
            quoted = char != "'"  # '' inside a string closes it and opens it again
        elif char == "'":
            quoted = True
        elif char in "{}":
            return None
        elif char in "([":
            depth += 1
        elif char in ")]":
            depth -= 1
            if depth < 0:
                return None
        elif depth == 0 and text.startswith("||", index):
            return None
        elif depth == 0 and text.startswith("&&", index):
            found.append(text[start:index])
            index += 1
            start = index + 1
        index += 1
    if quoted or depth:
        return None
    found.append(text[start:])
    # Only the spaces YAML and a keyboard give: a term spelt with another kind is not the guard.
    return [_SPACES.sub(" ", term).strip(" ") for term in found]


def waits_for(condition: str, guard: str) -> bool:
    """Whether a step with this `if:` runs only when `guard` holds: `guard` is one of its
    `&&`-joined terms, so the whole is false when it is."""
    found = terms(condition)
    return found is not None and guard in found


def plain_boolean(node: yaml.Node | None) -> bool:
    """Whether a `continue-on-error` or `background` is absent or a boolean written out."""
    return node is None or (kind_of(node) == "boolean" and node.value in BOOLEANS)


@dataclass(frozen=True)
class Placed:
    step: yaml.Node
    index: int  # of the job's step it is, or is inside
    grouped: bool  # inside a `parallel:` group, whose steps run at once, in the background


def placed_steps(steps: list[yaml.Node], inside: int | None = None) -> Iterator[Placed]:
    """Every step of a job, those of `parallel:` groups included, in the order written."""
    for index, step in enumerate(steps):
        place = index if inside is None else inside
        group = get(step, "parallel")
        if isinstance(group, yaml.SequenceNode):
            yield from placed_steps(group.value, place)
        else:
            yield Placed(step, place, inside is not None)


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
        placed = list(placed_steps(steps.value if isinstance(steps, yaml.SequenceNode) else []))
        named = [at for at in placed if scalar(get(at.step, "name")) == NAME]
        found: list[Problem] = []
        for count, at in enumerate(named):
            found += self.check_reserve(path, at.step, scalar(get(at.step, "run")) or "")
            if at.grouped:
                found.append(
                    Problem(
                        path,
                        line_of(at.step),
                        f'"{NAME}" is inside a parallel: group, where it runs beside other'
                        " steps; make it a step of its own, the job's first",
                    )
                )
            elif count:
                found.append(
                    Problem(
                        path,
                        line_of(at.step),
                        f'job {job_name!r} has "{NAME}" {count + 1} times; keep the first'
                        f" (line {line_of(named[0].step)}) alone",
                    )
                )
        reserves = [at for at in named if not at.grouped]
        unguarded = False
        starts = False
        for at in placed:
            if at not in named and starts_stack(scalar(get(at.step, "run")) or ""):
                starts = True
                before = [r for r in reserves if r.index < at.index]
                if before:
                    found += self.check_start(path, at.step, before[0].step)
                    continue
                unguarded = True
                later = (
                    f" (the one at line {line_of(reserves[0].step)} comes after it)"
                    if reserves
                    else ""
                )
                found.append(
                    Problem(
                        path,
                        line_of(at.step),
                        f'job {job_name!r} starts the local stack with no "{NAME}" step before'
                        f" it{later}; make that step the job's first ({WHY})",
                    )
                )
                break  # one fix serves every later start
        # A reservation does not free a port a socket already holds, so it must come before
        # every step that connects out: the first. (A start with none before it is named above.)
        if starts and not unguarded and reserves[0].index != 0:
            found.append(
                Problem(
                    path,
                    line_of(reserves[0].step),
                    f'job {job_name!r}: "{NAME}" is step {reserves[0].index + 1};'
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
        if not plain_boolean(get(step, "continue-on-error")):
            found.append(
                Problem(
                    path,
                    line,
                    f'"{NAME}": write continue-on-error as a plain true, or leave it out; this'
                    " check cannot tell what an expression or a text comes to",
                )
            )
        if get(step, "background") is not None:
            found.append(
                Problem(
                    path,
                    line,
                    f'"{NAME}" has background:, so the next step would not wait for it;'
                    " remove it",
                )
            )
        return found

    def check_start(self, path: str, step: yaml.Node, reserve: yaml.Node) -> list[Problem]:
        """A reservation that may fail (continue-on-error) must stop the start it guards, which
        must itself be allowed to fail: the job then reports the failure its own way."""
        if not is_true(get(reserve, "continue-on-error")):
            return []
        line = line_of(step)
        may_fail = get(step, "continue-on-error")
        if not plain_boolean(may_fail):
            return [
                Problem(
                    path,
                    line,
                    "write this start's continue-on-error as a plain true; this check cannot"
                    " tell what an expression or a text comes to",
                )
            ]
        if not is_true(may_fail):
            return [
                Problem(
                    path,
                    line_of(reserve),
                    f'"{NAME}" has continue-on-error, but the start it guards (line {line})'
                    " does not, so a failed reservation would pass in silence; remove it",
                )
            ]
        # An id or an if: with a YAML tag (`!!null "..."`) is not the text it looks like.
        step_id = get(reserve, "id")
        named = step_id is not None and kind_of(step_id) == "string" and ID.fullmatch(step_id.value)
        guard = f"steps.{step_id.value if named else 'reserve'}.outcome == 'success'"
        condition = get(step, "if")
        if (
            not named
            or condition is None
            or kind_of(condition) != "string"
            or not waits_for(condition.value, guard)
        ):
            return [
                Problem(
                    path,
                    line,
                    f'this start can run when "{NAME}" failed (it has continue-on-error):'
                    f' give that step an id and make "{guard}", spelt so, one of the &&-joined'
                    " terms of this step's if:, with no || outside brackets and nothing before"
                    " or after a ${{ }} around it",
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
