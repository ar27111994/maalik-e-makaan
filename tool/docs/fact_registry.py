"""The facts the docs repeat: the ones `make docs` writes, and the copies it only checks.

FACTS are generated: each sits between markers (tool/docs/fact_markers.py) in every file of its
`targets`, and `make docs` rewrites its body from its source. CHECKS compare copies that cannot
hold a marker (a code block, prose phrased differently each time, a workflow pin, a file
another tool owns) with their source, and name the place to fix by hand.

To repeat a fact in a new place, add the file to its `targets` and put an empty pair of markers
there; to add a fact or a check, add it below (and a parser to fact_sources.py for a new
source), with tests in test_fact_registry.py.
"""

from __future__ import annotations

import re
from collections.abc import Callable, Sequence
from dataclasses import dataclass
from pathlib import PurePosixPath

import fact_markers
from fact_sources import (
    APP_PUBSPEC,
    CI,
    COMMITLINT,
    COVERAGE_TARGETS,
    DEPENDABOT,
    FORMAL_INSTALL,
    FORMAL_REQUIREMENTS,
    JOURNEYS,
    LEAN_TOOLCHAIN,
    MAKEFILE,
    MANIFEST,
    NPM_STEP,
    NVMRC,
    PGTAP_DIR,
    PROJECT,
    PUBSPEC,
    PYPROJECT,
    RELEASE_PLEASE,
    Repo,
    SourceShapeError,
    glob_match,
)

README = "README.md"
AGENTS = "AGENTS.md"
COMMANDS = "docs/agents/commands.md"
CONVENTIONS = "docs/agents/conventions.md"
QUALITY_BAR = "docs/agents/quality-bar.md"
UAT = "docs/uat.md"
WEBSITE_README = "website/README.md"
PR_TITLE = ".github/workflows/pr-title.yml"
# Dated evidence: the record of a past run keeps the numbers it had (release-readiness.md).
DATED = ("docs/release-readiness.md",)
# Markdown the scans leave out: site copy, research notes, and the changelog release-please owns.
UNSCANNED = ("website/src/content/**", ".planning/research/**", "CHANGELOG.md")
# An X-check target whose X is not a generator.
NOT_GENERATORS = ("format",)

Tracked = Sequence[str]


@dataclass(frozen=True)
class Problem:
    """A copy that disagrees with its source: where to fix it, and how."""

    path: str
    line: int
    message: str

    def __str__(self) -> str:
        return f"{self.path}:{self.line}: {self.message}"


@dataclass(frozen=True)
class Fact:
    ident: str
    key: str
    kind: str  # "inline", "block" or "yaml"
    source: str  # the label written into the marker
    reads: tuple[str, ...]  # repository paths the renderer reads (for --paths and --list)
    targets: tuple[str, ...]  # files that must hold the marker; a marker elsewhere is M7
    render: Callable[[Repo], str]


@dataclass(frozen=True)
class Check:
    ident: str
    name: str
    reads: tuple[str, ...]  # sources and copies; globs allowed ("**/*.md")
    describe: str
    run: Callable[[Repo, Tracked], list[Problem]]


# ── Wording ────────────────────────────────────────────────────────────────────────────────

_WORDS = ("one", "two", "three", "four", "five", "six", "seven", "eight", "nine")


def prose_list(items: Sequence[str]) -> str:
    """ "a", "a and b", "a, b and c": no serial comma, as in the rest of the docs."""
    if not items:
        raise ValueError("an empty list has no wording")
    if len(items) == 1:
        return items[0]
    return ", ".join(items[:-1]) + " and " + items[-1]


def count_text(n: int) -> str:
    """Words for one to nine, figures from 10 (and for zero)."""
    return _WORDS[n - 1] if 1 <= n <= 9 else thousands(n)


def thousands(n: int) -> str:
    return f"{n:,}"


def code(text: str) -> str:
    return f"`{text}`"


def plural(n: int, word: str) -> str:
    return f"{thousands(n)} {word}{'' if n == 1 else 's'}"


# ── Generated facts ────────────────────────────────────────────────────────────────────────


def render_scopes(repo: Repo) -> str:
    return ", ".join(code(scope) for scope in repo.commitlint().scopes)


def render_types_and_scopes(repo: Repo) -> str:
    conventions = repo.commitlint()
    return "\n".join(
        ["types: |"]
        + [f"  {t}" for t in conventions.types]
        + ["scopes: |"]
        + [f"  {s}" for s in conventions.scopes]
    )


def render_changelog_visible(repo: Repo) -> str:
    return prose_list([code(t) for t in repo.release_please().visible])


def render_changelog_hidden(repo: Repo) -> str:
    return prose_list([code(t) for t in repo.release_please().hidden])


def _lines_only(repo: Repo, target: str) -> str:
    gate = repo.coverage_gates()[target]
    if gate.branches is not None or gate.functions is not None:
        raise SourceShapeError(
            MAKEFILE,
            f"{target} gates branches or functions as well as lines, but the docs say lines; reword"
            " them and update the renderer in tool/docs/fact_registry.py",
        )
    return f"{gate.lines}%"


def render_coverage_ui(repo: Repo) -> str:
    return _lines_only(repo, "test-ui")


def render_coverage_app(repo: Repo) -> str:
    return _lines_only(repo, "test-app")


def render_test_web_steps(repo: Repo) -> str:
    return prose_list([code(step) for step in repo.test_web_steps()])


def render_make_test_targets(repo: Repo) -> str:
    makefile = repo.makefile()
    if "test" not in makefile.targets or not makefile.targets["test"].prereqs:
        raise SourceShapeError(MAKEFILE, "the target test has no prerequisites")
    return code(" ".join(makefile.targets["test"].prereqs))


def render_uat_journeys(repo: Repo) -> str:
    return count_text(repo.journeys())


def render_pgtap_count(repo: Repo) -> str:
    pgtap = repo.pgtap()
    return f"{plural(pgtap.suites, 'suite')}, {plural(pgtap.tests, 'test')}"


def render_decision_range(repo: Repo) -> str:
    count = repo.decisions().decisions
    return "D-01" if count == 1 else f"D-01 to D-{count:02d}"


FACTS: tuple[Fact, ...] = (
    Fact(
        "G1",
        "commit-scopes",
        "inline",
        "commitlint.config.mjs scope-enum",
        (COMMITLINT,),
        (AGENTS, CONVENTIONS),
        render_scopes,
    ),
    Fact(
        "G2",
        "commit-types-and-scopes",
        "yaml",
        "commitlint.config.mjs",
        (COMMITLINT,),
        (PR_TITLE,),
        render_types_and_scopes,
    ),
    Fact(
        "G3",
        "changelog-visible",
        "inline",
        "release-please-config.json changelog-sections",
        (RELEASE_PLEASE,),
        (CONVENTIONS,),
        render_changelog_visible,
    ),
    Fact(
        "G4",
        "changelog-hidden",
        "inline",
        "release-please-config.json changelog-sections",
        (RELEASE_PLEASE,),
        (CONVENTIONS,),
        render_changelog_hidden,
    ),
    Fact(
        "G5",
        "coverage-ui",
        "inline",
        "Makefile test-ui",
        (MAKEFILE,),
        (README, COMMANDS, QUALITY_BAR),
        render_coverage_ui,
    ),
    Fact(
        "G6",
        "coverage-app",
        "inline",
        "Makefile test-app",
        (MAKEFILE,),
        (README, COMMANDS, QUALITY_BAR),
        render_coverage_app,
    ),
    Fact(
        "G7",
        "test-web-steps",
        "inline",
        "Makefile test-web",
        (MAKEFILE,),
        (COMMANDS, WEBSITE_README),
        render_test_web_steps,
    ),
    Fact(
        "G8",
        "make-test-targets",
        "inline",
        "Makefile test",
        (MAKEFILE,),
        (COMMANDS,),
        render_make_test_targets,
    ),
    Fact(
        "G9",
        "uat-journeys",
        "inline",
        JOURNEYS,
        (JOURNEYS,),
        (README, COMMANDS, UAT),
        render_uat_journeys,
    ),
    Fact(
        "G10",
        "pgtap-count",
        "inline",
        f"{PGTAP_DIR} select plan",
        (f"{PGTAP_DIR}/*.test.sql",),
        (README,),
        render_pgtap_count,
    ),
    Fact(
        "G11",
        "decision-range",
        "inline",
        f"{PROJECT} decisions",
        (PROJECT,),
        (CONVENTIONS,),
        render_decision_range,
    ),
)


# ── Markdown helpers for the checks ────────────────────────────────────────────────────────

_CODE_SPAN = re.compile(r"(?<!`)(`+)(?!`)(.+?)(?<!`)\1(?!`)")
_ASSIGNMENTS = re.compile(r"^(?:[A-Za-z_][A-Za-z0-9_]*=\S*\s+)+")
_TARGET_WORD = re.compile(r"[a-z][a-z0-9-]*")


def scanned_markdown(tracked: Tracked) -> list[str]:
    """The tracked Markdown the checks read: all but site copy, research and the changelog."""
    return [
        path
        for path in tracked
        if path.endswith(".md") and not any(glob_match(path, p) for p in UNSCANNED)
    ]


def strip_markers(text: str) -> str:
    """`text` with the markers taken out and the generated bodies kept."""
    return fact_markers.MD_CLOSE.sub("", fact_markers.MD_OPEN.sub("", text))


_GENERATED_SPAN = re.compile(
    rf"<!--[ \t]*docs:(?P<key>{fact_markers.KEY})(?:[ \t](?:(?!-->)[^\n])*)?-->(?s:.*?)"
    r"<!--[ \t]*/docs:(?P=key)[ \t]*-->"
)


def strip_generated(text: str) -> str:
    """`text` without its generated spans, wrapped ones included, which `make docs` keeps
    current, so a check of the copies made by hand does not report them a second time. Line
    breaks are kept, so line numbers still hold."""
    return _GENERATED_SPAN.sub(lambda match: "\n" * match[0].count("\n"), text)


def code_spans(line: str) -> list[str]:
    return [match[2].strip() for match in _CODE_SPAN.finditer(line)]


def make_targets_in(command: str) -> list[str]:
    """The targets of `make X Y …` at the start of `command` (after VAR=value assignments)."""
    command = _ASSIGNMENTS.sub("", command.strip())
    if not command.startswith("make "):
        return []
    names = []
    for word in command.split()[1:]:
        if not _TARGET_WORD.fullmatch(word):
            break
        names.append(word)
    return names


def make_references(text: str) -> list[tuple[int, list[str]]]:
    """(line, targets) of every `make …` in a code span, or starting a fenced line."""
    fenced = fact_markers.fenced_lines(text)
    found = []
    for number, line in enumerate(strip_markers(text).split("\n"), start=1):
        commands = [line] if number in fenced else code_spans(line)
        for command in commands:
            names = make_targets_in(command)
            if names:
                found.append((number, names))
    return found


def section(text: str, heading: str) -> tuple[int, list[str]]:
    """(line of the heading, the lines up to the next heading of the same or a higher level)."""
    lines = text.split("\n")
    level = len(heading) - len(heading.lstrip("#"))
    for index, line in enumerate(lines):
        if line.strip() == heading:
            body = []
            for following in lines[index + 1 :]:
                hashes = len(following) - len(following.lstrip("#"))
                if 0 < hashes <= level and following[hashes : hashes + 1] == " ":
                    break
                body.append(following)
            return index + 1, body
    return 0, []


def table_rows(text: str, heading: str) -> tuple[int, list[tuple[int, list[str], str]]]:
    """(heading line, [(line, cells, row text)]) of the first table under `heading`."""
    heading_line, body = section(text, heading)
    rows = []
    started = False
    for offset, line in enumerate(body, start=1):
        if line.lstrip().startswith("|"):
            started = True
            cells = [c.strip() for c in re.split(r"(?<!\\)\|", line.strip())[1:-1]]
            if all(re.fullmatch(r":?-+:?", c) for c in cells):
                continue
            rows.append((heading_line + offset, cells, line))
        elif started:
            break
    return heading_line, rows[1:]  # without the header row


def _line_containing(text: str, needle: str) -> int:
    index = text.find(needle)
    return 1 if index < 0 else fact_markers.line_of(text, index)


# ── Checks ─────────────────────────────────────────────────────────────────────────────────


def check_changelog_sections(repo: Repo, tracked: Tracked) -> list[Problem]:
    types = repo.commitlint().types
    release = repo.release_please()
    text = repo.text(RELEASE_PLEASE)
    problems = []
    section_types = [s.type for s in release.sections]
    for commit_type in types:
        if commit_type not in section_types:
            problems.append(
                Problem(
                    RELEASE_PLEASE,
                    _line_containing(text, '"changelog-sections"'),
                    f"has no changelog section for the commit type {commit_type}, which"
                    f" {COMMITLINT} allows; add one (and its heading in both languages in"
                    " website/src/i18n/ui.ts)",
                )
            )
    for entry in release.sections:
        if entry.type not in types:
            problems.append(
                Problem(
                    RELEASE_PLEASE,
                    _line_containing(text, f'"type": "{entry.type}"'),
                    f"has a changelog section for {entry.type}, a type {COMMITLINT}'s type-enum"
                    " refuses; remove the section or allow the type",
                )
            )
    return problems


def check_release_title_ignored(repo: Repo, tracked: Tracked) -> list[Problem]:
    conventions = repo.commitlint()
    title = (
        repo.release_please()
        .title_pattern.replace("${component}", "")
        .replace("${version}", "1.2.3")
    )
    if conventions.ignores.search(title):
        return []
    return [
        Problem(
            COMMITLINT,
            conventions.ignores_line,
            f"ignores does not match release-please's pull request title {title!r}"
            f" ({RELEASE_PLEASE}, pull-request-title-pattern), so commitlint would check the"
            " release commit, whose changelog lines run past the body limit",
        )
    ]


def check_header_length(repo: Repo, tracked: Tracked) -> list[Problem]:
    limit = repo.commitlint().header_max
    text = repo.text(PR_TITLE)
    problems = []
    found = list(re.finditer(r"^ *MAX_HEADER: *\"?(\d+)\"? *(?:#.*)?$", text, re.M))
    if len(found) != 1:
        problems.append(
            Problem(
                PR_TITLE,
                1,
                f"sets MAX_HEADER {len(found)} times; set it once, in the length step's env, to"
                f" commitlint's header-max-length ({limit})",
            )
        )
    for match in found:
        if int(match[1]) != limit:
            problems.append(
                Problem(
                    PR_TITLE,
                    text.count("\n", 0, match.start()) + 1,
                    f"MAX_HEADER is {match[1]}; commitlint's header-max-length is {limit}",
                )
            )
    for match in re.finditer(r"\b(\d+)-character", text):
        if int(match[1]) != limit:
            problems.append(
                Problem(
                    PR_TITLE,
                    text.count("\n", 0, match.start()) + 1,
                    f"says {match[0]}; commitlint's header-max-length is {limit}",
                )
            )
    return problems


def check_dependabot_commits(repo: Repo, tracked: Tracked) -> list[Problem]:
    conventions = repo.commitlint()
    problems = []
    reported: set[str] = set()
    for update in repo.dependabot():
        if update.prefix not in conventions.types:
            problems.append(
                Problem(
                    DEPENDABOT,
                    update.line,
                    f"the {update.ecosystem} updates commit as {update.prefix}, a type"
                    f" {COMMITLINT}'s type-enum refuses",
                )
            )
        if update.include_scope:
            for scope in ("deps", "deps-dev"):
                if scope not in conventions.scopes and scope not in reported:
                    reported.add(scope)
                    problems.append(
                        Problem(
                            DEPENDABOT,
                            update.line,
                            f"include: scope makes Dependabot use the scope {scope}, which"
                            f" {COMMITLINT}'s scope-enum refuses",
                        )
                    )
    return problems


def check_make_targets(repo: Repo, tracked: Tracked) -> list[Problem]:
    makefile = repo.makefile()
    problems = []
    commands_text = repo.text(COMMANDS)
    fenced = fact_markers.fenced_lines(commands_text)
    in_spans = {
        name
        for number, line in enumerate(strip_markers(commands_text).split("\n"), start=1)
        if number not in fenced
        for span in code_spans(line)
        for name in make_targets_in(span)
    }
    for name, target in makefile.targets.items():
        if name not in in_spans:
            problems.append(
                Problem(
                    COMMANDS,
                    1,
                    f"does not name `make {name}` (Makefile line {target.line}); add it to the"
                    " table for its area",
                )
            )
        if name not in makefile.phony:
            problems.append(
                Problem(
                    MAKEFILE,
                    target.line,
                    f"{name} is not .PHONY; add `.PHONY: {name}` above it, or a file or directory"
                    f" named {name} would stop make from running it",
                )
            )
    for path in scanned_markdown(tracked):
        if not repo.exists(path):
            continue
        for number, names in make_references(repo.text(path)):
            for name in names:
                if name not in makefile.targets:
                    problems.append(
                        Problem(path, number, f"names make {name}, which is not a Makefile target")
                    )
    return problems


def check_test_tools_discovery(repo: Repo, tracked: Tracked) -> list[Problem]:
    listed = repo.test_tools_dirs()
    target_line = repo.makefile().targets["test-tools"].line
    with_tests = {
        str(PurePosixPath(path).parent) for path in tracked if glob_match(path, "tool/**/test_*.py")
    }
    problems = []
    seen: set[str] = set()
    for line, directory in listed:
        if directory in seen:
            problems.append(Problem(MAKEFILE, line, f"test-tools discovers {directory} twice"))
        seen.add(directory)
        if directory not in with_tests:
            problems.append(
                Problem(
                    MAKEFILE,
                    line,
                    f"test-tools discovers {directory}, which has no tracked test_*.py file;"
                    " remove the line",
                )
            )
    for directory in sorted(with_tests - seen):
        problems.append(
            Problem(
                MAKEFILE,
                target_line,
                f"test-tools does not run the tests in {directory} (unittest discover does not"
                f" look in subdirectories); add: python3 -m unittest discover -s {directory}"
                " -p 'test_*.py'",
            )
        )
    return problems


_COVERAGE_CLAIM = re.compile(r"(?<![\d.])(\d+)% (?:line|lines|of lines|coverage)\b")


def check_coverage(repo: Repo, tracked: Tracked) -> list[Problem]:
    gates = repo.coverage_gates()
    problems = []
    core = gates["test-core"]
    if core.lines != 100:
        problems.append(
            Problem(
                MAKEFILE,
                core.line,
                f"test-core's gate is {core.lines}% of lines; the docs state 100% for mm_core"
                " without markers (100 is the ceiling), so change them with it",
            )
        )
    functions = gates["test-functions"]
    if (functions.lines, functions.branches, functions.functions) != (100, 100, 100):
        problems.append(
            Problem(
                MAKEFILE,
                functions.line,
                "test-functions' gate is not 100% of lines, branches and functions; the docs state"
                " 100% without markers (100 is the ceiling), so change them with it",
            )
        )
    for path in scanned_markdown(tracked):
        if path in DATED or not repo.exists(path):
            continue
        for number, line in enumerate(strip_generated(repo.text(path)).split("\n"), start=1):
            clean = strip_markers(line)
            named = [
                word
                for match in re.finditer(r"\bmake((?: +[a-z][a-z0-9-]*)+)", clean)
                for word in match[1].split()
                if word in COVERAGE_TARGETS
            ]
            if not named:
                continue
            allowed = {
                value
                for name in named
                for value in (gates[name].lines, gates[name].branches, gates[name].functions)
                if value is not None
            }
            for claim in _COVERAGE_CLAIM.finditer(clean):
                if int(claim[1]) not in allowed:
                    gate = " or ".join(f"{v}" for v in sorted(allowed))
                    problems.append(
                        Problem(
                            path,
                            number,
                            f"says {claim[1]}% for make {' and make '.join(dict.fromkeys(named))};"
                            f" the Makefile gate is {gate}",
                        )
                    )
    return problems


def _job_display(name: str) -> str:
    return re.sub(r"\$\{\{\s*matrix\.(\w+)\s*\}\}", r"<\1>", name)


def _literal_make_targets(runs: Sequence[tuple[int, str]]) -> list[tuple[int, str]]:
    found = []
    for line, command in runs:
        if command.lstrip().startswith("#"):
            continue
        for match in re.finditer(r"(?:^|[\s;&|(])make((?: +[a-z][a-z0-9-]*)+)", command):
            found += [(line, word) for word in match[1].split()]
    return found


def check_ci_jobs(repo: Repo, tracked: Tracked) -> list[Problem]:
    workflow = repo.workflow(CI)
    text = repo.text(COMMANDS)
    heading_line, rows = table_rows(text, "## CI jobs")
    problems = []
    if not heading_line:
        return [Problem(COMMANDS, 1, "has no `## CI jobs` section")]
    passed = [job for job in workflow.jobs if job.name == "CI passed"]
    if len(passed) != 1:
        problems.append(
            Problem(CI, 1, "needs exactly one job named `CI passed`, the required check")
        )
    others = [job for job in workflow.jobs if job not in passed]
    if passed:
        needs = set(passed[0].needs)
        ids = {job.id for job in others}
        for job_id in sorted(ids - needs):
            problems.append(
                Problem(
                    CI,
                    passed[0].line,
                    f"`CI passed` does not need {job_id}, so the required check would pass"
                    " without it; add it to needs",
                )
            )
        for job_id in sorted(needs - ids):
            problems.append(
                Problem(CI, passed[0].line, f"`CI passed` needs {job_id}, which is not a job")
            )
    _, body = section(text, "## CI jobs")
    if not any("`CI passed`" in line for line in body):
        problems.append(
            Problem(COMMANDS, heading_line, "the CI jobs section does not name `CI passed`")
        )
    jobs = {_job_display(job.name or job.id): job for job in others}
    by_name = {cells[0].replace("`", "").strip(): (line, row) for line, cells, row in rows if cells}
    for name, job in jobs.items():
        if name not in by_name:
            problems.append(
                Problem(
                    COMMANDS,
                    heading_line,
                    f'the CI jobs table has no row for "{name}" (the job {job.id} in {CI});'
                    " add one, named exactly as the job",
                )
            )
            continue
        line, row = by_name[name]
        words = set(re.findall(r"[A-Za-z0-9][A-Za-z0-9_.:-]*", strip_markers(row)))
        for run_line, target in _literal_make_targets(job.runs):
            if target not in words:
                problems.append(
                    Problem(
                        COMMANDS,
                        line,
                        f'the row for "{name}" does not name {target}, which the job runs'
                        f" ({CI} line {run_line})",
                    )
                )
    for name, (line, _) in by_name.items():
        if name not in jobs:
            problems.append(
                Problem(
                    COMMANDS,
                    line,
                    f'the CI jobs table names "{name}", but no job in {CI} has that name;'
                    " use the job's name exactly",
                )
            )
    return problems


def check_workflows_listed(repo: Repo, tracked: Tracked) -> list[Problem]:
    text = repo.text(COMMANDS)
    heading_line, _ = section(text, "## CI jobs")
    spans = {span for line in text.split("\n") for span in code_spans(line)}
    return [
        Problem(
            COMMANDS,
            heading_line or 1,
            f"does not name the workflow {path}; add `{PurePosixPath(path).name}` to the CI jobs"
            " section",
        )
        for path in repo.workflow_paths()
        if PurePosixPath(path).name not in spans and path not in spans
    ]


def check_website_sequence(repo: Repo, tracked: Tracked) -> list[Problem]:
    job = repo.workflow(CI).job("website")
    steps = [command for _, command in job.runs if NPM_STEP.fullmatch(command)]
    expected = list(repo.test_web_steps())
    if steps == expected:
        return []
    return [
        Problem(
            CI,
            job.line,
            f"the website job runs {', '.join(steps) or 'no npm step'}; make test-web runs"
            f" {', '.join(expected)}; keep the same steps in the same order",
        )
    ]


_INPUT_VARS = {
    "flutter-version": "FLUTTER_VERSION",
    "deno-version": "DENO_VERSION",
    "setup-cli version": "SUPABASE_CLI_VERSION",
}


def check_toolchain_pins(repo: Repo, tracked: Tracked) -> list[Problem]:
    versions = repo.ci_versions()
    problems = []
    for path in repo.workflow_paths():
        workflow = repo.workflow(path)
        defined = {pin.name for pin in workflow.env}
        for pin in workflow.env:
            if pin.value != versions[pin.name]:
                problems.append(
                    Problem(
                        path,
                        pin.line,
                        f"{pin.name} is {pin.value}; {CI} has {versions[pin.name]}; make them equal",
                    )
                )
        for pin in workflow.inputs:
            variable = _INPUT_VARS[pin.name]
            match = re.fullmatch(r"\$\{\{\s*env\.(\w+)\s*\}\}", pin.value)
            if not match or match[1] != variable:
                problems.append(
                    Problem(
                        path,
                        pin.line,
                        f"{pin.name} is {pin.value}; read ${{{{ env.{variable} }}}} and set"
                        f" {variable} in the workflow's env, equal to {CI}'s",
                    )
                )
            elif variable not in defined:
                problems.append(
                    Problem(
                        path,
                        pin.line,
                        f"{pin.name} reads env.{variable}, which this workflow does not set; set"
                        f" it in env, equal to {CI}'s",
                    )
                )
    root = repo.dart_sdk()
    for path, sdk in repo.member_sdks().items():
        if sdk != root:
            problems.append(
                Problem(
                    path,
                    _line_containing(repo.text(path), "sdk: ^"),
                    f"sdk is ^{sdk}; the workspace's {PUBSPEC} has ^{root}; make them equal",
                )
            )
    pins = repo.formal_pins()
    if pins.lean_toolchain != pins.lean:
        problems.append(
            Problem(
                LEAN_TOOLCHAIN,
                1,
                f"names Lean {pins.lean_toolchain}; {FORMAL_INSTALL} pins LEAN_VERSION={pins.lean}",
            )
        )
    return problems


def _is_prefix(found: str, version: str) -> bool:
    found_parts = found.split(".")
    return version.split(".")[: len(found_parts)] == found_parts


def check_version_mentions(repo: Repo, tracked: Tracked) -> list[Problem]:
    versions = repo.ci_versions()
    sdk = repo.dart_sdk()
    node = repo.nvmrc()
    python = repo.python_floor()
    majors = repo.app_majors()
    pins = repo.formal_pins()
    number = r"(\d+(?:\.\d+){0,2})(?![\d%]|\.\d)"
    rules: list[tuple[re.Pattern[str], Callable[[str], bool], str]] = [
        (
            re.compile(r"\bFlutter (\d+\.\d+(?:\.\d+)?)(?![\d%]|\.\d)"),
            lambda v: _is_prefix(v, versions["FLUTTER_VERSION"]),
            f"{CI}'s FLUTTER_VERSION is {versions['FLUTTER_VERSION']}",
        ),
        (
            re.compile(rf"\bDart {number}"),
            lambda v: _is_prefix(v, sdk),
            f"the Dart SDK floor in {PUBSPEC} is {sdk}",
        ),
        (
            re.compile(rf"\bDeno {number}"),
            lambda v: _is_prefix(v, versions["DENO_VERSION"]),
            f"{CI}'s DENO_VERSION is {versions['DENO_VERSION']}",
        ),
        (
            re.compile(rf"\bNode(?:\.js)? {number}"),
            lambda v: _is_prefix(v, node),
            f"{NVMRC} has {node}",
        ),
        (
            re.compile(r"\bPython (\d+\.\d+)(?:\+| or later)"),
            lambda v: v == python,
            f"black and ruff in {PYPROJECT} target Python {python}",
        ),
    ]
    for package, label in (
        ("flutter_riverpod", "Riverpod"),
        ("go_router", "go_router"),
        ("supabase_flutter", "supabase_flutter"),
    ):
        rules.append(
            (
                re.compile(rf"\b{label} (\d+)(?:\.\d+)*(?![\d%])"),
                lambda v, major=majors[package]: int(v) == major,
                f"{APP_PUBSPEC} depends on {package} ^{majors[package]}",
            )
        )
    rules += [
        (
            re.compile(r"\bLean (\d+\.\d+\.\d+)\b"),
            lambda v: v in (pins.lean, pins.lean434),
            f"{FORMAL_INSTALL} pins Lean {pins.lean} and {pins.lean434}",
        ),
        (
            re.compile(r"\bBend (\d+\.\d+\.\d+)\b"),
            lambda v: v == pins.bend,
            f"{FORMAL_INSTALL} pins Bend {pins.bend}",
        ),
        (
            re.compile(r"\bTLC (\d+\.\d+)\b"),
            lambda v: v == pins.tlc,
            f"{FORMAL_INSTALL} pins TLC {pins.tlc}",
        ),
        (
            re.compile(r"\btlaplus v(\d+\.\d+\.\d+)\b"),
            lambda v: v == pins.tla,
            f"{FORMAL_INSTALL} pins tlaplus v{pins.tla}",
        ),
        (
            re.compile(r"\bz3-solver (\d+\.\d+\.\d+\.\d+)\b"),
            lambda v: v == pins.z3,
            f"{FORMAL_REQUIREMENTS} pins z3-solver {pins.z3}",
        ),
    ]
    problems = []
    for path in scanned_markdown(tracked):
        if path in DATED or path.startswith(".planning/") or not repo.exists(path):
            continue
        text = strip_generated(repo.text(path))
        for line_number, line in enumerate(text.split("\n"), start=1):
            for regex, agrees, source in rules:
                for match in regex.finditer(line):
                    if not agrees(match[1]):
                        problems.append(Problem(path, line_number, f"says {match[0]}; {source}"))
    return problems


def check_generated_files_table(repo: Repo, tracked: Tracked) -> list[Problem]:
    makefile = repo.makefile()
    checks = [
        name
        for name in makefile.targets
        if name.endswith("-check")
        and name[: -len("-check")] in makefile.targets
        and name[: -len("-check")] not in NOT_GENERATORS
    ]
    text = repo.text(CONVENTIONS)
    heading_line, rows = table_rows(text, "## Generated files")
    named = {
        target
        for _, _, row in rows
        for span in code_spans(strip_markers(row))
        for target in make_targets_in(span)
    }
    problems = [
        Problem(
            CONVENTIONS,
            heading_line or 1,
            f"the generated-files table has no row for `make {name[: -len('-check')]}`"
            f" ({name} checks its output); add one",
        )
        for name in checks
        if name[: -len("-check")] not in named
    ]
    hygiene = [
        step
        for job in repo.workflow(CI).jobs
        for step in job.steps
        if step.name == "Generated files are up to date"
    ]
    if len(hygiene) != 1:
        problems.append(
            Problem(CI, 1, 'needs exactly one step named "Generated files are up to date"')
        )
    else:
        step = hygiene[0]
        run = {target for _, target in _literal_make_targets(step.runs)}
        for name in checks:
            if name not in run:
                problems.append(
                    Problem(
                        CI,
                        step.line,
                        f'"Generated files are up to date" does not run make {name}; add it',
                    )
                )
    return problems


def check_release_in_readme(repo: Repo, tracked: Tracked) -> list[Problem]:
    version = repo.manifest()
    release = repo.release_please()
    text = repo.text(README)
    problems = []
    annotated = [
        (number, line)
        for number, line in enumerate(text.split("\n"), start=1)
        if "x-release-please-version" in line
    ]
    if len(annotated) != 1:
        problems.append(
            Problem(
                README,
                annotated[1][0] if len(annotated) > 1 else 1,
                f"has {len(annotated)} lines marked x-release-please-version; it needs exactly"
                " one, naming the latest release",
            )
        )
    else:
        number, line = annotated[0]
        versions = re.findall(r"\d+\.\d+\.\d+", line)
        if versions != [version]:
            problems.append(
                Problem(
                    README,
                    number,
                    f"the release line names {', '.join(versions) or 'no version'};"
                    f" {MANIFEST} has {version}, the only version that line may hold (release-please"
                    " rewrites every version on it)",
                )
            )
        elif f"v{version}" not in line:
            problems.append(
                Problem(README, number, f"the release line should name the release as v{version}")
            )
    entries = [entry for entry in release.extra_files if entry.get("path") == README]
    if not (len(entries) == 1 and entries[0].get("type") == "generic"):
        problems.append(
            Problem(
                RELEASE_PLEASE,
                _line_containing(repo.text(RELEASE_PLEASE), '"extra-files"'),
                'extra-files needs { "type": "generic", "path": "README.md" }, or release-please'
                " leaves README's release line behind",
            )
        )
    return problems


_MARKDOWN = "**/*.md"
_WORKFLOWS = ".github/workflows/*.yml"

CHECKS: tuple[Check, ...] = (
    Check(
        "C1",
        "changelog-sections",
        (RELEASE_PLEASE, COMMITLINT),
        "release-please's changelog sections are exactly commitlint's types",
        check_changelog_sections,
    ),
    Check(
        "C2",
        "release-title-ignored",
        (RELEASE_PLEASE, COMMITLINT),
        "commitlint ignores the release pull request's title",
        check_release_title_ignored,
    ),
    Check(
        "C3",
        "header-length",
        (COMMITLINT, PR_TITLE),
        "pr-title.yml's MAX_HEADER and every N-character in it equal commitlint's header limit",
        check_header_length,
    ),
    Check(
        "C4",
        "dependabot-commits",
        (DEPENDABOT, COMMITLINT),
        "Dependabot's commit prefixes are commitlint types, and deps and deps-dev are scopes",
        check_dependabot_commits,
    ),
    Check(
        "C5",
        "make-targets",
        (MAKEFILE, _MARKDOWN),
        "every target is in commands.md and .PHONY; every `make X` in the docs names a target",
        check_make_targets,
    ),
    Check(
        "C6",
        "test-tools-discovery",
        (MAKEFILE, "tool/**/test_*.py"),
        "test-tools discovers exactly the tool/ directories that have tests",
        check_test_tools_discovery,
    ),
    Check(
        "C7",
        "coverage",
        (MAKEFILE, _MARKDOWN),
        "the 100% floors hold, and a line naming make test-X states that target's gate",
        check_coverage,
    ),
    Check(
        "C8",
        "ci-jobs",
        (CI, COMMANDS),
        "commands.md's CI jobs table has a row per ci.yml job, named exactly, naming its make"
        " targets; `CI passed` needs every job",
        check_ci_jobs,
    ),
    Check(
        "C9",
        "workflows-listed",
        (_WORKFLOWS, COMMANDS),
        "commands.md names every workflow",
        check_workflows_listed,
    ),
    Check(
        "C10",
        "website-sequence",
        (CI, MAKEFILE),
        "ci.yml's website job runs make test-web's npm steps in order",
        check_website_sequence,
    ),
    Check(
        "C11",
        "toolchain-pins",
        (_WORKFLOWS, PUBSPEC, "**/pubspec.yaml", LEAN_TOOLCHAIN, FORMAL_INSTALL),
        "workflow pins equal ci.yml's and tool inputs read env; member pubspecs' sdk equals the"
        " root's; lean-toolchain equals LEAN_VERSION",
        check_toolchain_pins,
    ),
    Check(
        "C12",
        "version-mentions",
        (
            _MARKDOWN,
            CI,
            PUBSPEC,
            NVMRC,
            PYPROJECT,
            APP_PUBSPEC,
            FORMAL_INSTALL,
            FORMAL_REQUIREMENTS,
            LEAN_TOOLCHAIN,
        ),
        "Flutter, Dart, Deno, Node, Python, Riverpod, go_router, supabase_flutter, Lean, Bend,"
        " TLC, tlaplus and z3-solver versions in the docs match their pins",
        check_version_mentions,
    ),
    Check(
        "C13",
        "generated-files-table",
        (MAKEFILE, CONVENTIONS, CI),
        "conventions.md's generated-files table names make X for every X-check target, and"
        " ci.yml's 'Generated files are up to date' step runs every X-check",
        check_generated_files_table,
    ),
    Check(
        "C14",
        "release-in-readme",
        (README, MANIFEST, RELEASE_PLEASE),
        "README's release line (written by release-please) names the manifest's version",
        check_release_in_readme,
    ),
)


def unholdable(kind: str, body: str) -> list[str]:
    """What in a rendered body its markers cannot hold (empty when it is fine).

    Markdown bodies may not contain a table's `|` or a marker's `<!--` and `-->`, and inline ones
    no line break; YAML bodies may not contain a line that reads as a marker.
    """
    if kind == "yaml":
        return ["a marker line" for line in body.split("\n") if re.match(r"\s*# /?docs:", line)][:1]
    bad = [text for text in ("|", "<!--", "-->") if text in body]
    if kind == "inline" and "\n" in body:
        bad.append("a line break")
    return bad


def facts_by_key() -> dict[str, Fact]:
    return {fact.key: fact for fact in FACTS}


def kinds() -> dict[str, str]:
    return {fact.key: fact.kind for fact in FACTS}


def targets() -> dict[str, tuple[str, ...]]:
    return {fact.key: fact.targets for fact in FACTS}
