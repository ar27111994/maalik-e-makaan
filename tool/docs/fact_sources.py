"""Parsers of the sources the docs' facts come from (tool/docs/sync_facts.py).

Each parser reads the shape its file has today and raises SourceShapeError, naming the file,
the shape it expected and the function to update, when the file has another. Nothing here runs
the sources: commitlint.config.mjs is read as text, the workflows by lines (no YAML library),
so a file that changes shape fails loudly instead of being half-read.

Repo reads each source once and remembers a failure, so a broken source is reported once and
every fact or check that needs it is skipped.
"""

from __future__ import annotations

import json
import re
import shlex
import tomllib
from collections.abc import Callable, Sequence
from dataclasses import dataclass
from pathlib import Path, PurePosixPath
from typing import Any, TypeVar

T = TypeVar("T")

COMMITLINT = "commitlint.config.mjs"
RELEASE_PLEASE = "release-please-config.json"
MANIFEST = ".release-please-manifest.json"
MAKEFILE = "Makefile"
JOURNEYS = "app/uat/tests/journeys.spec.ts"
PGTAP_DIR = "supabase/tests/database"
PROJECT = ".planning/PROJECT.md"
WORKFLOWS_DIR = ".github/workflows"
CI = ".github/workflows/ci.yml"
DEPENDABOT = ".github/dependabot.yml"
NVMRC = ".nvmrc"
PUBSPEC = "pubspec.yaml"
APP_PUBSPEC = "app/pubspec.yaml"
PYPROJECT = "pyproject.toml"
FORMAL_INSTALL = "tool/formal/install.sh"
FORMAL_REQUIREMENTS = "tool/formal/requirements.txt"
LEAN_TOOLCHAIN = "formal/lean/lean-toolchain"
SUPABASE_CONFIG = "supabase/config.toml"
MM_VARIANTS = "packages/mm_ui/test/support/harness.dart"
TLA_DIR = "formal/tla"

# The pins ci.yml's env sets, which other workflows repeat (C11 holds the copies equal).
TOOLCHAIN_VARS = (
    "FLUTTER_VERSION",
    "DENO_VERSION",
    "SUPABASE_CLI_VERSION",
    "JAVA_VERSION",
    "PYTHON_VERSION",
)
# Pins a workflow sets for a tool ci.yml does not use; every workflow that sets one agrees.
OTHER_PIN_VARS = ("VERCEL_CLI_VERSION",)
# Inputs of setup actions, each of which reads its pin from env (C11).
TOOL_INPUTS = ("flutter-version", "deno-version", "java-version", "python-version")
COVERAGE_TARGETS = ("test-core", "test-ui", "test-app", "test-functions")
APP_PACKAGES = ("flutter_riverpod", "go_router", "supabase_flutter")
SEMVER = re.compile(r"\d+\.\d+\.\d+")
# A step of make test-web, and of the website job in ci.yml (C10 compares the two).
NPM_STEP = re.compile(r"npm test|npm run [A-Za-z0-9:_-]+")


class SourceShapeError(Exception):
    """A source no longer has the shape its parser reads."""

    def __init__(self, path: str, message: str) -> None:
        super().__init__(f"{path}: {message}")
        self.path = path
        self.message = message


def _line(text: str, offset: int) -> int:
    return text.count("\n", 0, offset) + 1


# ── commitlint.config.mjs ──────────────────────────────────────────────────────────────────


@dataclass(frozen=True)
class CommitConventions:
    types: tuple[str, ...]
    scopes: tuple[str, ...]
    header_max: int
    body_max: int
    subject_cases: tuple[str, ...]  # the cases a subject may not be in
    ignores: re.Pattern[str]
    ignores_line: int
    header_line: int


# The cases commitlint's subject-case rule knows (@commitlint/ensure, case.ts).
COMMIT_CASES = (
    "lower-case",
    "upper-case",
    "camel-case",
    "kebab-case",
    "pascal-case",
    "sentence-case",
    "snake-case",
    "start-case",
)


def _skip_string(text: str, i: int) -> int:
    quote = text[i]
    j = i + 1
    while j < len(text):
        if text[j] == "\\":
            j += 2
            continue
        if text[j] == quote:
            return j + 1
        if text[j] == "\n" and quote != "`":
            break
        j += 1
    raise SourceShapeError(COMMITLINT, f"a string opened on line {_line(text, i)} is not closed")


def _skip_comment(text: str, i: int) -> int | None:
    """End of the comment starting at `i`, or None when none starts there."""
    if text.startswith("//", i):
        end = text.find("\n", i)
        return len(text) if end < 0 else end
    if text.startswith("/*", i):
        end = text.find("*/", i + 2)
        if end < 0:
            raise SourceShapeError(COMMITLINT, f"a comment on line {_line(text, i)} is not closed")
        return end + 2
    return None


def _array_end(text: str, start: int) -> int:
    """Index just past the bracket matching text[start], skipping strings and comments."""
    depth = 0
    i = start
    while i < len(text):
        char = text[i]
        if char in "'\"`":
            i = _skip_string(text, i)
            continue
        end = _skip_comment(text, i)
        if end is not None:
            i = end
            continue
        if char in "[({":
            depth += 1
        elif char in "])}":
            depth -= 1
            if depth == 0:
                return i + 1
        i += 1
    raise SourceShapeError(COMMITLINT, f"the array on line {_line(text, start)} is not closed")


def _strip_comments(text: str) -> str:
    out = []
    i = 0
    while i < len(text):
        if text[i] in "'\"`":
            end = _skip_string(text, i)
            out.append(text[i:end])
            i = end
            continue
        end = _skip_comment(text, i)
        if end is not None:
            out.append(" ")
            i = end
            continue
        out.append(text[i])
        i += 1
    return "".join(out)


def _rule(text: str, rule: str) -> tuple[str, int]:
    """The text inside the brackets of `'rule': [...]`, comments removed, and its line."""
    found = list(re.finditer(rf"(['\"]){re.escape(rule)}\1\s*:\s*\[", text))
    if len(found) != 1:
        where = "is missing" if not found else f"appears {len(found)} times"
        raise SourceShapeError(
            COMMITLINT, f"'{rule}' {where}; update parse_commitlint in tool/docs/fact_sources.py"
        )
    start = found[0].end() - 1
    end = _array_end(text, start)
    return _strip_comments(text[start + 1 : end - 1]), _line(text, found[0].start())


def _enum_rule(text: str, rule: str, condition: str = "always") -> tuple[str, ...]:
    inner, _ = _rule(text, rule)
    shape = (
        f"'{rule}' is not [2, '{condition}', [quoted names]] (the docs say what it allows);"
        " update parse_commitlint in tool/docs/fact_sources.py"
    )
    match = re.fullmatch(
        rf"\s*2\s*,\s*(['\"]){condition}\1\s*,\s*\[(?P<items>[^\[\]]*)\]\s*,?\s*", inner
    )
    if not match:
        raise SourceShapeError(COMMITLINT, shape)
    parts = [part.strip() for part in match["items"].split(",")]
    if parts and parts[-1] == "":
        parts.pop()
    names = []
    for part in parts:
        quoted = re.fullmatch(r"(['\"])(.*)\1", part)
        if not quoted:
            raise SourceShapeError(
                COMMITLINT,
                f"'{rule}' has the item {part or '(empty)'!r}, not a quoted name; a spread,"
                " variable or call cannot be read without running the file",
            )
        if not re.fullmatch(r"[a-z][a-z0-9-]*", quoted[2]):
            raise SourceShapeError(
                COMMITLINT,
                f"'{rule}' has {part}, which is not written as the other names are: lower-case"
                " letters, digits and hyphens, starting with a letter; rename it, or widen the"
                " pattern in _enum_rule in tool/docs/fact_sources.py if the docs can hold it",
            )
        names.append(quoted[2])
    if not names:
        raise SourceShapeError(COMMITLINT, f"'{rule}' lists no names")
    duplicates = sorted({name for name in names if names.count(name) > 1})
    if duplicates:
        raise SourceShapeError(COMMITLINT, f"'{rule}' lists {', '.join(duplicates)} twice")
    return tuple(names)


def _number_rule(text: str, rule: str) -> tuple[int, int]:
    """N in `'rule': [2, 'always', N]`, and the rule's line."""
    inner, line = _rule(text, rule)
    match = re.fullmatch(r"\s*2\s*,\s*(['\"])always\1\s*,\s*(\d+)\s*,?\s*", inner)
    if not match:
        raise SourceShapeError(
            COMMITLINT,
            f"'{rule}' is not [2, 'always', N] with N a whole number; update parse_commitlint in"
            " tool/docs/fact_sources.py",
        )
    return int(match[2]), line


def parse_commitlint(text: str) -> CommitConventions:
    """The types, scopes, length limits, subject cases and ignored messages of the config."""
    types = _enum_rule(text, "type-enum")
    scopes = _enum_rule(text, "scope-enum")
    header_max, header_line = _number_rule(text, "header-max-length")
    body_max, _ = _number_rule(text, "body-max-line-length")
    cases = _enum_rule(text, "subject-case", "never")
    unknown = [case for case in cases if case not in COMMIT_CASES]
    if unknown:
        raise SourceShapeError(
            COMMITLINT, f"'subject-case' names {unknown[0]}, which is not a case commitlint knows"
        )
    found = list(re.finditer(r"\bignores\s*:", text))
    shape = (
        "ignores is not exactly [(message) => /RE/.test(message)] with no flags; update"
        " parse_commitlint in tool/docs/fact_sources.py"
    )
    if len(found) != 1:
        raise SourceShapeError(COMMITLINT, shape)
    ignores = re.compile(
        r"ignores\s*:\s*\[\s*\(\s*message\s*\)\s*=>\s*"
        r"/(?P<re>(?:\\.|\[(?:\\.|[^\]\\\n])*\]|[^/\\\n\[])+)/(?P<flags>[a-z]*)"
        r"\.test\(\s*message\s*\)\s*,?\s*\]"
    ).match(text, found[0].start())
    if not ignores or ignores["flags"]:
        raise SourceShapeError(COMMITLINT, shape)
    try:
        pattern = re.compile(ignores["re"])
    except re.error as error:
        raise SourceShapeError(
            COMMITLINT, f"the ignores pattern does not compile: {error}"
        ) from None
    return CommitConventions(
        types=types,
        scopes=scopes,
        header_max=header_max,
        body_max=body_max,
        subject_cases=cases,
        ignores=pattern,
        ignores_line=_line(text, found[0].start()),
        header_line=header_line,
    )


# ── release-please ─────────────────────────────────────────────────────────────────────────


@dataclass(frozen=True)
class Section:
    type: str
    section: str
    hidden: bool


@dataclass(frozen=True)
class ReleasePlease:
    sections: tuple[Section, ...]
    title_pattern: str
    extra_files: tuple[dict[str, Any], ...]

    @property
    def visible(self) -> tuple[str, ...]:
        return tuple(s.type for s in self.sections if not s.hidden)

    @property
    def hidden(self) -> tuple[str, ...]:
        return tuple(s.type for s in self.sections if s.hidden)


def parse_release_please(text: str) -> ReleasePlease:
    """The changelog sections, release pull request title and root package's extra files."""

    def fail(message: str) -> SourceShapeError:
        return SourceShapeError(
            RELEASE_PLEASE, f"{message}; update parse_release_please in tool/docs/fact_sources.py"
        )

    try:
        config = json.loads(text)
    except json.JSONDecodeError as error:
        raise SourceShapeError(RELEASE_PLEASE, f"is not JSON: {error}") from None
    raw = config.get("changelog-sections") if isinstance(config, dict) else None
    if not isinstance(raw, list) or not raw:
        raise fail("changelog-sections is missing or not a list")
    sections = []
    for entry in raw:
        if (
            not isinstance(entry, dict)
            or not isinstance(entry.get("type"), str)
            or not isinstance(entry.get("section"), str)
            or not isinstance(entry.get("hidden", False), bool)
            or set(entry) - {"type", "section", "hidden"}
        ):
            raise fail(f"the changelog section {entry!r} is not {{type, section, hidden?}}")
        sections.append(Section(entry["type"], entry["section"], entry.get("hidden", False)))
    types = [s.type for s in sections]
    duplicates = sorted({t for t in types if types.count(t) > 1})
    if duplicates:
        raise SourceShapeError(
            RELEASE_PLEASE, f"changelog-sections lists the type {', '.join(duplicates)} twice"
        )
    title = config.get("pull-request-title-pattern")
    if not isinstance(title, str):
        raise fail("pull-request-title-pattern is missing")
    package = config.get("packages", {}).get(".")
    extra = package.get("extra-files", []) if isinstance(package, dict) else None
    if not isinstance(extra, list) or not all(isinstance(e, dict) for e in extra):
        raise fail('packages["."]["extra-files"] is not a list of objects')
    return ReleasePlease(tuple(sections), title, tuple(extra))


def parse_manifest(text: str) -> str:
    """The released version in .release-please-manifest.json."""
    try:
        manifest = json.loads(text)
    except json.JSONDecodeError as error:
        raise SourceShapeError(MANIFEST, f"is not JSON: {error}") from None
    if not isinstance(manifest, dict) or set(manifest) != {"."}:
        raise SourceShapeError(MANIFEST, 'must hold exactly the key "." (the root package)')
    version = manifest["."]
    if not isinstance(version, str) or not SEMVER.fullmatch(version):
        raise SourceShapeError(MANIFEST, f"{version!r} is not a version X.Y.Z")
    return version


# ── Makefile ───────────────────────────────────────────────────────────────────────────────


@dataclass(frozen=True)
class Target:
    name: str
    line: int
    prereqs: tuple[str, ...]
    help: str | None
    recipe: tuple[tuple[int, str], ...]  # (line, command), backslash continuations joined


@dataclass(frozen=True)
class Makefile:
    targets: dict[str, Target]
    phony: frozenset[str]


@dataclass(frozen=True)
class CoverageGate:
    target: str
    line: int
    lines: int
    branches: int | None
    functions: int | None


_TARGET = re.compile(r"^([A-Za-z0-9_.-]+):(?!=)(.*)$")


def parse_makefile(text: str) -> Makefile:
    """Targets (with prerequisites, help and recipe) and the .PHONY names."""
    lines = text.split("\n")
    targets: dict[str, Target] = {}
    phony: set[str] = set()
    i = 0
    while i < len(lines):
        line = lines[i]
        if line.startswith(".PHONY:"):
            phony.update(line.split(":", 1)[1].split())
            i += 1
            continue
        match = _TARGET.match(line)
        if not match or match[1].startswith("."):
            i += 1
            continue
        name = match[1]
        prereqs, _, help_text = match[2].partition("##")
        if name in targets:
            raise SourceShapeError(MAKEFILE, f"line {i + 1}: the target {name} is defined twice")
        recipe = []
        j = i + 1
        while j < len(lines) and lines[j].startswith("\t"):
            start = j
            command = lines[j][1:]
            while command.endswith("\\") and j + 1 < len(lines):
                j += 1
                command = command[:-1].rstrip() + " " + lines[j].strip()
            recipe.append((start + 1, command.strip()))
            j += 1
        targets[name] = Target(
            name=name,
            line=i + 1,
            prereqs=tuple(prereqs.split()),
            help=help_text.strip() or None,
            recipe=tuple(recipe),
        )
        i = j
    if not targets:
        raise SourceShapeError(MAKEFILE, "has no targets")
    return Makefile(targets, frozenset(phony))


def _target(makefile: Makefile, name: str) -> Target:
    if name not in makefile.targets:
        raise SourceShapeError(MAKEFILE, f"has no target {name}")
    return makefile.targets[name]


def coverage_gates(makefile: Makefile) -> dict[str, CoverageGate]:
    """The tool/coverage/check.py minimums of test-core, test-ui, test-app and test-functions."""
    gates = {}
    for name in COVERAGE_TARGETS:
        target = _target(makefile, name)
        calls = [(n, c) for n, c in target.recipe if "tool/coverage/check.py" in c]
        if len(calls) != 1:
            raise SourceShapeError(
                MAKEFILE,
                f"{name} calls tool/coverage/check.py {len(calls)} times, not once; update"
                " coverage_gates in tool/docs/fact_sources.py",
            )
        line, command = calls[0]
        try:
            words = shlex.split(command)
        except ValueError as error:
            raise SourceShapeError(MAKEFILE, f"line {line}: {error}") from None
        index = next(i for i, w in enumerate(words) if w.endswith("tool/coverage/check.py"))
        flags: dict[str, int] = {}
        args = words[index + 1 :]
        for position, word in enumerate(args):
            if word in ("--min", "--min-branches", "--min-functions"):
                value = args[position + 1] if position + 1 < len(args) else ""
                if not re.fullmatch(r"\d+", value):
                    raise SourceShapeError(
                        MAKEFILE, f"line {line}: {name}'s {word} is {value!r}, not a whole number"
                    )
                flags[word] = int(value)
        if "--min" not in flags:
            raise SourceShapeError(MAKEFILE, f"line {line}: {name} has no --min line-coverage gate")
        gates[name] = CoverageGate(
            name, line, flags["--min"], flags.get("--min-branches"), flags.get("--min-functions")
        )
    return gates


def test_web_steps(makefile: Makefile) -> tuple[str, ...]:
    """The npm steps of test-web, in order: `cd website && npm … && npm …` on one line."""
    target = _target(makefile, "test-web")
    shape = (
        "test-web is not one line `cd website && npm test && npm run SCRIPT …`; update"
        " test_web_steps in tool/docs/fact_sources.py"
    )
    if len(target.recipe) != 1:
        raise SourceShapeError(MAKEFILE, shape)
    steps = [step.strip() for step in target.recipe[0][1].split("&&")]
    if steps[0] != "cd website" or len(steps) < 2:
        raise SourceShapeError(MAKEFILE, shape)
    for step in steps[1:]:
        if not NPM_STEP.fullmatch(step):
            raise SourceShapeError(MAKEFILE, f"test-web has the step {step!r}; {shape}")
    return tuple(steps[1:])


def test_tools_dirs(makefile: Makefile) -> tuple[tuple[int, str], ...]:
    """(line, directory) of each `unittest discover -s DIR` line of test-tools."""
    target = _target(makefile, "test-tools")
    dirs = []
    for line, command in target.recipe:
        match = re.fullmatch(r"python3 -m unittest discover -s (\S+?)/? -p 'test_\*\.py'", command)
        if not match:
            raise SourceShapeError(
                MAKEFILE,
                f"line {line}: test-tools runs {command!r}, not python3 -m unittest discover -s DIR"
                " -p 'test_*.py'; update test_tools_dirs in tool/docs/fact_sources.py",
            )
        dirs.append((line, match[1]))
    if not dirs:
        raise SourceShapeError(MAKEFILE, "test-tools has no recipe")
    return tuple(dirs)


# ── Test suites ────────────────────────────────────────────────────────────────────────────


def parse_journeys(text: str) -> int:
    """The number of UAT journeys: test("J1 …") to test("Jn …"), with no gap or repeat."""
    numbers = [int(n) for n in re.findall(r"^\s*test\(\s*[\"'`]J(\d+)\b", text, re.M)]
    if not numbers:
        raise SourceShapeError(JOURNEYS, 'has no journey test("J1 …")')
    if sorted(numbers) != list(range(1, len(numbers) + 1)):
        raise SourceShapeError(
            JOURNEYS,
            f"the journeys are numbered {', '.join(map(str, numbers))}, not 1 to"
            f" {len(numbers)} without a gap or repeat",
        )
    return len(numbers)


@dataclass(frozen=True)
class PgTap:
    suites: int
    tests: int


def parse_pgtap(files: dict[str, str]) -> PgTap:
    """Suites and planned tests: each file has exactly one `select plan(N)`."""
    if not files:
        raise SourceShapeError(PGTAP_DIR, "has no *.test.sql suite")
    total = 0
    for path, text in sorted(files.items()):
        if re.search(r"\bno_plan\s*\(", text, re.I):
            raise SourceShapeError(path, "uses no_plan(); give it select plan(N)")
        plans = re.findall(r"\bselect\s+plan\(\s*(\d+)\s*\)", text, re.I)
        if len(plans) != 1:
            raise SourceShapeError(path, f"has {len(plans)} select plan(N), not one")
        total += int(plans[0])
    return PgTap(len(files), total)


# ── Golden variants and TLA+ models ────────────────────────────────────────────────────────


def parse_mm_variants(text: str) -> tuple[str, ...]:
    """The values of `enum MmVariant` in mm_ui's test harness, in order."""
    match = re.search(r"^enum MmVariant \{\n(?P<body>.*?);", text, re.M | re.S)
    if not match:
        raise SourceShapeError(
            MM_VARIANTS,
            "has no `enum MmVariant {` whose values end with `;` (Dart's enhanced enum)",
        )
    names = re.findall(r"^  ([a-z][A-Za-z0-9]*)\(", match["body"], re.M)
    if not names:
        raise SourceShapeError(MM_VARIANTS, "MmVariant has no value `  name(…)`")
    return tuple(names)


def tla_models(tracked: Sequence[str]) -> tuple[str, ...]:
    """The TLA+ models: each directory under formal/tla/ that holds a .tla file."""
    models = sorted(
        {PurePosixPath(path).parts[2] for path in tracked if glob_match(path, f"{TLA_DIR}/*/*.tla")}
    )
    if not models:
        raise SourceShapeError(TLA_DIR, "has no model (a directory with a .tla file)")
    return tuple(models)


# ── PostgreSQL ─────────────────────────────────────────────────────────────────────────────


def parse_supabase_major(text: str) -> int:
    """The PostgreSQL major version of the Supabase stack: `[db] major_version`."""
    try:
        config = tomllib.loads(text)
    except tomllib.TOMLDecodeError as error:
        raise SourceShapeError(SUPABASE_CONFIG, f"is not TOML: {error}") from None
    major = config.get("db", {}).get("major_version")
    if not isinstance(major, int) or isinstance(major, bool):
        raise SourceShapeError(SUPABASE_CONFIG, "has no whole-number [db] major_version")
    return major


def parse_ci_postgres(text: str) -> int:
    """The PostgreSQL major version ci.yml installs for the suites (`postgresql-N`)."""
    majors = sorted({int(n) for n in re.findall(r"\bpostgresql-(\d+)\b", text)})
    if len(majors) != 1:
        found = ", ".join(f"postgresql-{n}" for n in majors) or "no postgresql-N package"
        raise SourceShapeError(
            CI, f"installs {found}; the docs name one local PostgreSQL, so install one major"
        )
    return majors[0]


# ── .planning/PROJECT.md ───────────────────────────────────────────────────────────────────


@dataclass(frozen=True)
class Decisions:
    decisions: int
    proposals: int


def parse_decisions(text: str) -> Decisions:
    """The decisions D-01… and proposals P-01…: `- D-NN:` bullets, numbered from 01 in a row."""
    counts = {}
    for letter in "DP":
        written = re.findall(rf"^- {letter}-(\d+):", text, re.M)
        short = [n for n in written if len(n) < 2]
        if short:
            raise SourceShapeError(
                PROJECT,
                f"{letter}-{short[0]} is not written with two digits ({letter}-0{short[0]})",
            )
        numbers = [int(n) for n in written]
        if numbers != list(range(1, len(numbers) + 1)):
            raise SourceShapeError(
                PROJECT,
                f"the {letter}- bullets are {', '.join(f'{n:02d}' for n in numbers)}, not 01 upwards"
                " without a gap or repeat",
            )
        counts[letter] = len(numbers)
    if not counts["D"]:
        raise SourceShapeError(PROJECT, "has no decision bullet `- D-01:`")
    return Decisions(counts["D"], counts["P"])


# ── Workflows ──────────────────────────────────────────────────────────────────────────────


@dataclass(frozen=True)
class Step:
    line: int
    name: str | None
    runs: tuple[tuple[int, str], ...]  # (line, command line); a folded `>` block is one line


@dataclass(frozen=True)
class Job:
    id: str
    line: int
    name: str | None
    needs: tuple[str, ...]
    steps: tuple[Step, ...]

    @property
    def runs(self) -> tuple[tuple[int, str], ...]:
        return tuple(run for step in self.steps for run in step.runs)


@dataclass(frozen=True)
class Pin:
    name: str
    value: str
    line: int


@dataclass(frozen=True)
class Workflow:
    path: str
    jobs: tuple[Job, ...]
    env: tuple[Pin, ...]  # TOOLCHAIN_VARS and OTHER_PIN_VARS, at any level
    inputs: tuple[Pin, ...]  # TOOL_INPUTS and setup-cli's version
    packages: tuple[Pin, ...]  # what follows `vercel@` (npx runs the CLI from npm)

    def job(self, job_id: str) -> Job:
        for job in self.jobs:
            if job.id == job_id:
                return job
        raise SourceShapeError(self.path, f"has no job {job_id}")


def _unquote(value: str) -> str:
    value = value.strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in "'\"":
        return value[1:-1]
    return value


def _indent(line: str) -> int:
    return len(line) - len(line.lstrip(" "))


def _block(lines: list[str], start: int, key_column: int) -> list[int]:
    """Indexes of the lines of a block that follows lines[start], indented past key_column."""
    out = []
    j = start + 1
    while j < len(lines) and (not lines[j].strip() or _indent(lines[j]) > key_column):
        out.append(j)
        j += 1
    while out and not lines[out[-1]].strip():
        out.pop()
    return out


def _needs(path: str, lines: list[str], index: int, value: str) -> tuple[str, ...]:
    if value.startswith("["):
        text = value
        j = index
        while "]" not in text:
            j += 1
            if j >= len(lines):
                raise SourceShapeError(path, f"line {index + 1}: needs: [ is not closed")
            text += " " + lines[j].strip()
        return tuple(_unquote(n) for n in text[1 : text.index("]")].split(",") if n.strip())
    if value:
        return (_unquote(value),)
    following = _block(lines, index, _indent(lines[index]))
    if not following:
        raise SourceShapeError(path, f"line {index + 1}: needs: has no value")
    first = lines[following[0]].strip()
    if first.startswith("["):
        return _needs(path, lines, following[0], first)
    if first.startswith("- "):
        return tuple(_unquote(lines[j].strip()[2:]) for j in following if lines[j].strip())
    raise SourceShapeError(
        path,
        f"line {index + 1}: needs: is neither a list nor [a, b]; update parse_workflow in"
        " tool/docs/fact_sources.py",
    )


def _run(lines: list[str], index: int, key_column: int, value: str) -> list[tuple[int, str]]:
    value = value.strip()
    if not re.fullmatch(r"[|>][+-]?", value):
        return [(index + 1, _unquote(value))]
    block = _block(lines, index, key_column)
    if value.startswith(">"):
        words = " ".join(lines[j].strip() for j in block if lines[j].strip())
        return [(block[0] + 1, words)] if block else []
    return [(j + 1, lines[j].strip()) for j in block if lines[j].strip()]


def parse_workflow(path: str, text: str) -> Workflow:
    """Jobs (name, needs, steps and their run lines) and the toolchain pins of a workflow."""
    lines = text.split("\n")
    names = "|".join(TOOLCHAIN_VARS + OTHER_PIN_VARS)
    env = [
        Pin(m[1], m[2], _line(text, m.start()))
        for m in re.finditer(rf"^ *({names}): *\"?([^\"\s#]+)\"? *(?:#.*)?$", text, re.M)
    ]
    inputs = [
        Pin(m[1], _unquote(m[2]), _line(text, m.start()))
        for m in re.finditer(rf"^ *({'|'.join(TOOL_INPUTS)}): *(.+?) *$", text, re.M)
    ]
    packages = tuple(
        Pin("vercel", m[1], _line(text, m.start()))
        for m in re.finditer(r"\bvercel@(\$\{\{[^}]*\}\}|[^\s\"']+)", text)
    )
    for index, line in enumerate(lines):
        uses = re.match(r"^( *)(- )?uses: supabase/setup-cli@", line)
        if not uses:
            continue
        key_column = len(uses[1]) + (2 if uses[2] else 0)
        j = index + 1
        while j < len(lines) and (not lines[j].strip() or _indent(lines[j]) >= key_column):
            version = re.match(r"^ *version: *(.+?) *$", lines[j])
            if version:
                inputs.append(Pin("setup-cli version", _unquote(version[1]), j + 1))
                break
            j += 1
    inputs.sort(key=lambda pin: pin.line)

    jobs: list[Job] = []
    if "jobs:" in lines:
        start = lines.index("jobs:")
        headers = []
        end = len(lines)
        for index in range(start + 1, len(lines)):
            line = lines[index]
            if line and not line.startswith((" ", "#")):
                end = index
                break
            match = re.match(r"^  ([A-Za-z_][A-Za-z0-9_-]*): *$", line)
            if match:
                headers.append((index, match[1]))
        for number, (index, job_id) in enumerate(headers):
            stop = headers[number + 1][0] if number + 1 < len(headers) else end
            jobs.append(_job(path, lines, index, stop, job_id))
    return Workflow(path, tuple(jobs), tuple(env), tuple(inputs), packages)


def _job(path: str, lines: list[str], start: int, stop: int, job_id: str) -> Job:
    name = None
    needs: tuple[str, ...] = ()
    steps: tuple[Step, ...] = ()
    index = start + 1
    while index < stop:
        line = lines[index]
        if name is None and (match := re.match(r"^    name: *(.+?) *$", line)):
            name = _unquote(match[1])
        elif match := re.match(r"^    needs:(.*)$", line):
            needs = _needs(path, lines, index, match[1].strip())
        elif re.match(r"^    steps: *$", line):
            body = [j for j in _block(lines, index, 4) if j < stop]
            steps = _steps(lines, body)
            index = body[-1] + 1 if body else index + 1
            continue
        index += 1
    return Job(job_id, start + 1, name, needs, steps)


def _steps(lines: list[str], body: list[int]) -> tuple[Step, ...]:
    """The steps of a `steps:` list: each `- ` item at the list's column, with its name and runs."""
    steps: list[Step] = []
    column: int | None = None
    current: dict[str, Any] | None = None
    for j in body:
        line = lines[j]
        item = re.match(r"^( *)- ", line)
        if item and (column is None or len(item[1]) == column):
            column = len(item[1])
            if current is not None:
                steps.append(Step(current["line"], current["name"], tuple(current["runs"])))
            current = {"line": j + 1, "name": None, "runs": []}
        if current is None or column is None:
            continue
        on_dash = line.startswith(" " * column + "- ")
        if not on_dash and (not line.strip() or _indent(line) != column + 2):
            continue
        key = line[column + 2 :]
        if match := re.match(r"^name: *(.+?) *$", key):
            current["name"] = _unquote(match[1])
        elif match := re.match(r"^run:(.*)$", key):
            current["runs"] += _run(lines, j, column + 2, match[1])
    if current is not None:
        steps.append(Step(current["line"], current["name"], tuple(current["runs"])))
    return tuple(steps)


# ── Dependabot ─────────────────────────────────────────────────────────────────────────────


@dataclass(frozen=True)
class DependabotUpdate:
    ecosystem: str
    prefix: str
    include_scope: bool
    line: int


def parse_dependabot(text: str) -> tuple[DependabotUpdate, ...]:
    """Each update's commit-message prefix, and whether it adds the scope."""
    starts = list(re.finditer(r"^ *- package-ecosystem: *(\S+)", text, re.M))
    if not starts:
        raise SourceShapeError(DEPENDABOT, "has no `- package-ecosystem:` entry")
    updates = []
    for number, start in enumerate(starts):
        end = starts[number + 1].start() if number + 1 < len(starts) else len(text)
        block = text[start.start() : end]
        prefix = re.search(r"^ *prefix: *(\w[\w-]*)", block, re.M)
        if not prefix:
            raise SourceShapeError(
                DEPENDABOT,
                f"the {start[1]} entry on line {_line(text, start.start())} has no prefix",
            )
        updates.append(
            DependabotUpdate(
                _unquote(start[1]),
                prefix[1],
                re.search(r"^ *include: *scope *$", block, re.M) is not None,
                _line(text, start.start() + prefix.start()),
            )
        )
    return tuple(updates)


# ── Toolchain versions ─────────────────────────────────────────────────────────────────────


def parse_nvmrc(text: str) -> str:
    if not re.fullmatch(r"\d+\.\d+\.\d+\n?", text):
        raise SourceShapeError(NVMRC, "is not one version X.Y.Z")
    return text.strip()


def parse_pubspec_sdk(path: str, text: str) -> str:
    """The Dart SDK floor of a pubspec: `environment:` then `  sdk: ^X.Y.Z`."""
    match = re.search(r"^environment:\n  sdk: *\^(\d+\.\d+\.\d+) *$", text, re.M)
    if not match:
        raise SourceShapeError(path, "has no `environment:` with `sdk: ^X.Y.Z` under it")
    return match[1]


def parse_workspace(text: str) -> tuple[str, ...]:
    """The members of the root pubspec's `workspace:` list."""
    match = re.search(r"^workspace:\n((?:  - \S+\n?)+)", text, re.M)
    if not match:
        raise SourceShapeError(PUBSPEC, "has no `workspace:` list of members")
    return tuple(line.strip()[2:] for line in match[1].splitlines() if line.strip())


def parse_python_floor(text: str) -> str:
    """The Python floor black and ruff target in pyproject.toml, as X.Y."""
    try:
        config = tomllib.loads(text)
    except tomllib.TOMLDecodeError as error:
        raise SourceShapeError(PYPROJECT, f"is not TOML: {error}") from None
    tool = config.get("tool", {})
    black = tool.get("black", {}).get("target-version")
    ruff = tool.get("ruff", {}).get("target-version")
    if not (isinstance(black, list) and len(black) == 1 and isinstance(ruff, str)):
        raise SourceShapeError(
            PYPROJECT, 'needs black target-version ["pyXY"] and ruff target-version "pyXY"'
        )
    if black[0] != ruff:
        raise SourceShapeError(
            PYPROJECT, f"black targets {black[0]} but ruff {ruff}; they must agree"
        )
    match = re.fullmatch(r"py(\d)(\d+)", ruff)
    if not match:
        raise SourceShapeError(PYPROJECT, f"target-version {ruff!r} is not pyXY")
    return f"{match[1]}.{match[2]}"


def parse_app_majors(text: str) -> dict[str, int]:
    """The major versions of flutter_riverpod, go_router and supabase_flutter in app/pubspec."""
    majors = {}
    for package in APP_PACKAGES:
        match = re.search(rf"^  {package}: *\^(\d+)\.\d+\.\d+ *$", text, re.M)
        if not match:
            raise SourceShapeError(APP_PUBSPEC, f"has no `{package}: ^X.Y.Z` dependency")
        majors[package] = int(match[1])
    return majors


@dataclass(frozen=True)
class FormalPins:
    tla: str
    tlc: str
    lean: str
    lean434: str
    bend: str
    z3: str
    lean_toolchain: str
    sha256: dict[str, str]


def parse_formal_pins(install: str, requirements: str, toolchain: str) -> FormalPins:
    """The tool versions tool/formal/install.sh, requirements.txt and lean-toolchain pin."""
    values: dict[str, str] = {}
    for match in re.finditer(r"^(TLA|LEAN|LEAN434|BEND)_(VERSION|SHA256)=(\S+)", install, re.M):
        values[f"{match[1]}_{match[2]}"] = match[3]
    missing = [
        f"{tool}_{kind}"
        for tool in ("TLA", "LEAN", "LEAN434", "BEND")
        for kind in ("VERSION", "SHA256")
        if f"{tool}_{kind}" not in values
    ]
    if missing:
        raise SourceShapeError(FORMAL_INSTALL, f"does not set {', '.join(missing)}")
    tlc = re.search(r"^TLA_VERSION=\S+ *# TLC2 Version (\d+\.\d+)\b", install, re.M)
    if not tlc:
        raise SourceShapeError(
            FORMAL_INSTALL, "the TLA_VERSION line has no `# TLC2 Version X.Y` comment"
        )
    z3 = re.search(r"^z3-solver==(\S+)", requirements, re.M)
    if not z3:
        raise SourceShapeError(FORMAL_REQUIREMENTS, "does not pin z3-solver==X")
    lean = re.fullmatch(r"leanprover/lean4:v(\S+)\n?", toolchain)
    if not lean:
        raise SourceShapeError(LEAN_TOOLCHAIN, "is not leanprover/lean4:vX.Y.Z")
    return FormalPins(
        tla=values["TLA_VERSION"],
        tlc=tlc[1],
        lean=values["LEAN_VERSION"],
        lean434=values["LEAN434_VERSION"],
        bend=values["BEND_VERSION"],
        z3=z3[1],
        lean_toolchain=lean[1],
        sha256={tool: values[f"{tool}_SHA256"] for tool in ("TLA", "LEAN", "LEAN434", "BEND")},
    )


# ── The repository ─────────────────────────────────────────────────────────────────────────


def glob_match(path: str, pattern: str) -> bool:
    """`**/` matches any directories (or none), `*` and `?` stay within one path segment."""
    regex = ""
    i = 0
    while i < len(pattern):
        if pattern.startswith("**/", i):
            regex += "(?:.*/)?"
            i += 3
        elif pattern.startswith("**", i):
            regex += ".*"
            i += 2
        elif pattern[i] == "*":
            regex += "[^/]*"
            i += 1
        elif pattern[i] == "?":
            regex += "[^/]"
            i += 1
        else:
            regex += re.escape(pattern[i])
            i += 1
    return re.fullmatch(regex, path) is not None


class Repo:
    """The repository's files, each read and parsed at most once."""

    def __init__(self, root: Path, tracked: Sequence[str]) -> None:
        self.root = root
        self.tracked = tuple(tracked)
        self._texts: dict[str, str] = {}
        self._crlf: set[str] = set()
        self._parsed: dict[str, tuple[bool, Any]] = {}

    def exists(self, path: str) -> bool:
        return (self.root / path).is_file()

    def text(self, path: str) -> str:
        """The file with CRLF line breaks read as LF, so every parser and check sees one kind
        of line (and the line numbers stay those of the file)."""
        if path not in self._texts:
            try:
                raw = (self.root / path).read_bytes().decode("utf-8")
            except (FileNotFoundError, IsADirectoryError):
                raise SourceShapeError(path, "is missing") from None
            except UnicodeDecodeError:
                raise SourceShapeError(path, "is not UTF-8") from None
            if "\r\n" in raw and raw.count("\r\n") == raw.count("\n"):
                self._crlf.add(path)
            self._texts[path] = raw.replace("\r\n", "\n")
        return self._texts[path]

    def newline(self, path: str) -> str:
        """CRLF for a file read by text() whose every line break is CRLF, else LF (a file with
        both is written back with LF, as .gitattributes and .editorconfig want)."""
        return "\r\n" if path in self._crlf else "\n"

    def tracked_matching(self, pattern: str) -> list[str]:
        return [path for path in self.tracked if glob_match(path, pattern)]

    def _cached(self, name: str, load: Callable[[], T]) -> T:
        if name not in self._parsed:
            try:
                self._parsed[name] = (True, load())
            except SourceShapeError as error:
                self._parsed[name] = (False, error)
        ok, value = self._parsed[name]
        if not ok:
            raise value
        return value

    def commitlint(self) -> CommitConventions:
        return self._cached("commitlint", lambda: parse_commitlint(self.text(COMMITLINT)))

    def release_please(self) -> ReleasePlease:
        return self._cached(
            "release-please", lambda: parse_release_please(self.text(RELEASE_PLEASE))
        )

    def manifest(self) -> str:
        return self._cached("manifest", lambda: parse_manifest(self.text(MANIFEST)))

    def makefile(self) -> Makefile:
        return self._cached("makefile", lambda: parse_makefile(self.text(MAKEFILE)))

    def coverage_gates(self) -> dict[str, CoverageGate]:
        return self._cached("coverage", lambda: coverage_gates(self.makefile()))

    def test_web_steps(self) -> tuple[str, ...]:
        return self._cached("test-web", lambda: test_web_steps(self.makefile()))

    def test_tools_dirs(self) -> tuple[tuple[int, str], ...]:
        return self._cached("test-tools", lambda: test_tools_dirs(self.makefile()))

    def journeys(self) -> int:
        return self._cached("journeys", lambda: parse_journeys(self.text(JOURNEYS)))

    def pgtap(self) -> PgTap:
        def load() -> PgTap:
            files = [
                p
                for p in self.tracked
                if str(PurePosixPath(p).parent) == PGTAP_DIR and p.endswith(".test.sql")
            ]
            return parse_pgtap({p: self.text(p) for p in files})

        return self._cached("pgtap", load)

    def decisions(self) -> Decisions:
        return self._cached("decisions", lambda: parse_decisions(self.text(PROJECT)))

    def mm_variants(self) -> tuple[str, ...]:
        return self._cached("mm-variants", lambda: parse_mm_variants(self.text(MM_VARIANTS)))

    def tla_models(self) -> tuple[str, ...]:
        return self._cached("tla-models", lambda: tla_models(self.tracked))

    def supabase_major(self) -> int:
        return self._cached(
            "supabase-major", lambda: parse_supabase_major(self.text(SUPABASE_CONFIG))
        )

    def ci_postgres(self) -> int:
        return self._cached("ci-postgres", lambda: parse_ci_postgres(self.text(CI)))

    def workflow(self, path: str) -> Workflow:
        return self._cached(f"workflow:{path}", lambda: parse_workflow(path, self.text(path)))

    def workflow_paths(self) -> list[str]:
        return [
            p
            for p in self.tracked
            if str(PurePosixPath(p).parent) == WORKFLOWS_DIR and p.endswith(".yml")
        ]

    def dependabot(self) -> tuple[DependabotUpdate, ...]:
        return self._cached("dependabot", lambda: parse_dependabot(self.text(DEPENDABOT)))

    def ci_versions(self) -> dict[str, str]:
        """The TOOLCHAIN_VARS in ci.yml's env."""

        def load() -> dict[str, str]:
            found: dict[str, str] = {}
            for pin in self.workflow(CI).env:
                if pin.name not in TOOLCHAIN_VARS:
                    continue
                if found.setdefault(pin.name, pin.value) != pin.value:
                    raise SourceShapeError(CI, f"sets {pin.name} twice, to different values")
            missing = [name for name in TOOLCHAIN_VARS if name not in found]
            if missing:
                raise SourceShapeError(CI, f"does not set {', '.join(missing)} in env")
            return found

        return self._cached("ci-versions", load)

    def nvmrc(self) -> str:
        return self._cached("nvmrc", lambda: parse_nvmrc(self.text(NVMRC)))

    def dart_sdk(self) -> str:
        return self._cached("dart-sdk", lambda: parse_pubspec_sdk(PUBSPEC, self.text(PUBSPEC)))

    def member_sdks(self) -> dict[str, str]:
        def load() -> dict[str, str]:
            members = parse_workspace(self.text(PUBSPEC))
            return {
                f"{m}/pubspec.yaml": parse_pubspec_sdk(
                    f"{m}/pubspec.yaml", self.text(f"{m}/pubspec.yaml")
                )
                for m in members
            }

        return self._cached("member-sdks", load)

    def python_floor(self) -> str:
        return self._cached("python", lambda: parse_python_floor(self.text(PYPROJECT)))

    def app_majors(self) -> dict[str, int]:
        return self._cached("app-majors", lambda: parse_app_majors(self.text(APP_PUBSPEC)))

    def formal_pins(self) -> FormalPins:
        return self._cached(
            "formal",
            lambda: parse_formal_pins(
                self.text(FORMAL_INSTALL), self.text(FORMAL_REQUIREMENTS), self.text(LEAN_TOOLCHAIN)
            ),
        )
