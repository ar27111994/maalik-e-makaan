#!/usr/bin/env python3
"""Check the repository's same-repository workflow and action references.

GitHub's self-repository syntax, `uses: $/.github/workflows/deploy.yml`, names a reusable
workflow or an action in this repository at the running commit. For a step-level action the
older `./` form instead names whatever is in the runner's workspace at that path, which a
previous step may have replaced; for a reusable workflow `./` also takes the caller's commit,
and `$/` is GitHub's recommended form and counts as pinned under a fully-pinned policy. zizmor's
self-repository audit flags every `./` reference, and this repository writes `$/`
(docs/agents/conventions.md).

actionlint 1.7.12 does not know `$/` and refuses it; .github/actionlint.yaml ignores exactly that
message, and actionlint then no longer checks such a call against the called workflow. This
check refuses `./` and does that part instead, for every job-level `uses: $/…` in
.github/workflows:

- the file exists, in .github/workflows, and declares `on.workflow_call`;
- every `with:` key is a declared input, and every required input without a default is passed;
- a literal value has the input's declared type (boolean, number or string); a value with an
  expression, `${{ … }}`, is accepted;
- every `secrets:` key is a declared secret, and every required secret is passed, unless the
  call says `secrets: inherit`;
- the reference has no `@ref`: with `$/` the called workflow comes from the caller's commit.

When a pinned actionlint accepts `$/`, test_check_workflow_calls.py's canary test fails: remove
the ignore and keep here only what actionlint still does not check.

    python3 tool/github/check_workflow_calls.py [repository root]
"""

from __future__ import annotations

import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path, PurePosixPath

import yaml

ROOT = Path(__file__).resolve().parents[2]
WORKFLOWS = ".github/workflows"
EXPRESSION = re.compile(r"\$\{\{.*?\}\}", re.S)


class _Loader(yaml.SafeLoader):
    """YAML 1.2's core schema, as GitHub reads workflows: `on`, `yes` and `no` are strings,
    only true and false (in any of three cases) are booleans, and there are no timestamps."""


_YAML_1_1_ONLY = {f"tag:yaml.org,2002:{name}" for name in ("bool", "int", "float", "timestamp")}
_Loader.yaml_implicit_resolvers = {
    first: [(tag, regex) for tag, regex in resolvers if tag not in _YAML_1_1_ONLY]
    for first, resolvers in yaml.SafeLoader.yaml_implicit_resolvers.items()
}
_Loader.add_implicit_resolver(
    "tag:yaml.org,2002:bool",
    re.compile(r"^(?:true|True|TRUE|false|False|FALSE)$"),
    list("tTfF"),
)
_Loader.add_implicit_resolver(
    "tag:yaml.org,2002:int",
    re.compile(r"^(?:[-+]?[0-9]+|0o[0-7]+|0x[0-9a-fA-F]+)$"),
    list("-+0123456789"),
)
_Loader.add_implicit_resolver(
    "tag:yaml.org,2002:float",
    re.compile(
        r"^(?:[-+]?(?:\.[0-9]+|[0-9]+(?:\.[0-9]*)?)(?:[eE][-+]?[0-9]+)?"
        r"|[-+]?\.(?:inf|Inf|INF)|\.(?:nan|NaN|NAN))$"
    ),
    list("-+.0123456789"),
)

_TYPE_OF_TAG = {
    "tag:yaml.org,2002:bool": "boolean",
    "tag:yaml.org,2002:int": "number",
    "tag:yaml.org,2002:float": "number",
    "tag:yaml.org,2002:str": "string",
    "tag:yaml.org,2002:null": "null",
}


@dataclass(frozen=True)
class Problem:
    path: str
    line: int
    message: str

    def __str__(self) -> str:
        return f"{self.path}:{self.line}: {self.message}"


def compose(text: str) -> yaml.Node | None:
    """The document's node tree, which keeps each value's line and resolved type."""
    return yaml.compose(text, Loader=_Loader)


def line_of(node: yaml.Node) -> int:
    return node.start_mark.line + 1


def get(node: yaml.Node | None, key: str) -> yaml.Node | None:
    """The value of `key` in a mapping node, or None (also when the node is not a mapping)."""
    if not isinstance(node, yaml.MappingNode):
        return None
    for key_node, value in node.value:
        if isinstance(key_node, yaml.ScalarNode) and key_node.value == key:
            return value
    return None


def items(node: yaml.Node | None) -> list[tuple[yaml.ScalarNode, yaml.Node]]:
    if not isinstance(node, yaml.MappingNode):
        return []
    return [(k, v) for k, v in node.value if isinstance(k, yaml.ScalarNode)]


def scalar(node: yaml.Node | None) -> str | None:
    return node.value if isinstance(node, yaml.ScalarNode) else None


def kind_of(node: yaml.Node) -> str:
    """boolean, number, string, null, or the node's shape (mapping, sequence)."""
    if isinstance(node, yaml.MappingNode):
        return "mapping"
    if isinstance(node, yaml.SequenceNode):
        return "sequence"
    return _TYPE_OF_TAG.get(node.tag, node.tag)


def is_true(node: yaml.Node | None) -> bool:
    return node is not None and kind_of(node) == "boolean" and node.value.lower() == "true"


@dataclass(frozen=True)
class Called:
    """What a reusable workflow's `on.workflow_call` declares."""

    inputs: dict[str, yaml.Node]  # name -> its definition
    secrets: dict[str, yaml.Node]


def workflow_call(document: yaml.Node | None) -> Called | None:
    """The workflow's `on.workflow_call`, or None when it does not declare one."""
    on = get(document, "on")
    if isinstance(on, yaml.ScalarNode):
        return Called({}, {}) if on.value == "workflow_call" else None
    if isinstance(on, yaml.SequenceNode):
        names = [scalar(event) for event in on.value]
        return Called({}, {}) if "workflow_call" in names else None
    if not isinstance(on, yaml.MappingNode) or not any(
        k.value == "workflow_call" for k, _ in items(on)
    ):
        return None
    call = get(on, "workflow_call")
    return Called(
        {k.value: v for k, v in items(get(call, "inputs"))},
        {k.value: v for k, v in items(get(call, "secrets"))},
    )


def uses_nodes(
    path: str, document: yaml.Node | None
) -> list[tuple[str, yaml.ScalarNode, yaml.Node | None]]:
    """Every `uses:` in a workflow (jobs and their steps) or an action (its composite steps), as
    (where, the value's node, the job node for a job-level call)."""
    found: list[tuple[str, yaml.ScalarNode, yaml.Node | None]] = []

    def steps(node: yaml.Node | None) -> None:
        if isinstance(node, yaml.SequenceNode):
            for step in node.value:
                uses = get(step, "uses")
                if isinstance(uses, yaml.ScalarNode):
                    found.append(("step", uses, None))

    if PurePosixPath(path).name in ("action.yml", "action.yaml"):
        steps(get(get(document, "runs"), "steps"))
        return found
    for _, job in items(get(document, "jobs")):
        uses = get(job, "uses")
        if isinstance(uses, yaml.ScalarNode):
            found.append(("job", uses, job))
        steps(get(job, "steps"))
    return found


def check_value(name: str, value: yaml.Node, declared: str | None) -> str | None:
    """Why a `with:` value does not fit the input's declared type, or None when it does."""
    if declared not in ("boolean", "number", "string"):
        return None  # no type, or one GitHub refuses in the called workflow itself
    if (
        isinstance(value, yaml.ScalarNode)
        and kind_of(value) == "string"
        and EXPRESSION.search(value.value)
    ):
        return None
    found = kind_of(value)
    if found == declared:
        return None
    hint = ""
    if declared == "string" and found in ("boolean", "number"):
        hint = f"; quote it ('{value.value}')"
    elif declared in ("boolean", "number") and found == "string":
        hint = "; write it unquoted"
    return f"input {name!r} is a {declared}, but the value given is a {found}{hint}"


class Checker:
    def __init__(self, root: Path) -> None:
        self.root = root
        self._documents: dict[str, yaml.Node | None] = {}

    def document(self, path: str) -> yaml.Node | None:
        if path not in self._documents:
            self._documents[path] = compose((self.root / path).read_text(encoding="utf-8"))
        return self._documents[path]

    def problems(self, files: list[str]) -> list[Problem]:
        found: list[Problem] = []
        for path in files:
            try:
                document = self.document(path)
            except (OSError, UnicodeDecodeError, yaml.YAMLError) as error:
                found.append(Problem(path, 1, f"cannot read it ({error})"))
                continue
            for where, uses, job in uses_nodes(path, document):
                found += self.check_uses(path, where, uses, job)
        return found

    def check_uses(
        self, path: str, where: str, uses: yaml.ScalarNode, job: yaml.Node | None
    ) -> list[Problem]:
        value = uses.value.strip()
        line = line_of(uses)
        thing = "reusable workflow" if where == "job" else "action"
        if value.startswith("./"):
            return [
                Problem(
                    path,
                    line,
                    f'the same-repository {thing} "{value}" is written with "./"; write'
                    f' "$/{value[2:]}", GitHub\'s self-repository syntax (docs/agents/conventions.md)',
                )
            ]
        if not value.startswith("$/"):
            return []
        if "@" in value:
            return [
                Problem(
                    path,
                    line,
                    f'"{value}" has an @ref; a "$/" reference takes none, since it always names'
                    f' the caller\'s own commit: write "{value.split("@", 1)[0]}"',
                )
            ]
        if where == "job":
            return self.check_call(path, line, value, job)
        return []

    def check_call(self, path: str, line: int, value: str, job: yaml.Node | None) -> list[Problem]:
        target = value[2:]
        parent = str(PurePosixPath(target).parent)
        if parent != WORKFLOWS or PurePosixPath(target).suffix not in (".yml", ".yaml"):
            return [
                Problem(
                    path,
                    line,
                    f'"{value}" is not a workflow file directly in {WORKFLOWS}/, where GitHub'
                    " looks for a reusable workflow",
                )
            ]
        if not (self.root / target).is_file():
            return [Problem(path, line, f'"{value}" names {target}, which does not exist')]
        try:
            called = workflow_call(self.document(target))
        except (OSError, UnicodeDecodeError, yaml.YAMLError) as error:
            return [Problem(path, line, f'"{value}": cannot read {target} ({error})')]
        if called is None:
            return [Problem(path, line, f'"{value}": {target} does not declare on.workflow_call')]
        return self.check_inputs(path, line, value, job, called) + self.check_secrets(
            path, line, value, job, called
        )

    def check_inputs(
        self, path: str, line: int, value: str, job: yaml.Node | None, called: Called
    ) -> list[Problem]:
        found = []
        given = items(get(job, "with"))
        names = {key.value for key, _ in given}
        declared_names = ", ".join(sorted(called.inputs)) or "none"
        for key, given_value in given:
            definition = called.inputs.get(key.value)
            if definition is None:
                found.append(
                    Problem(
                        path,
                        line_of(key),
                        f'input {key.value!r} is not declared by "{value}" (its inputs: {declared_names})',
                    )
                )
                continue
            wrong = check_value(key.value, given_value, scalar(get(definition, "type")))
            if wrong:
                found.append(Problem(path, line_of(given_value), f'"{value}": {wrong}'))
        for name, definition in sorted(called.inputs.items()):
            required = is_true(get(definition, "required"))
            if required and get(definition, "default") is None and name not in names:
                found.append(
                    Problem(
                        path, line, f'"{value}" requires the input {name!r}, which is not passed'
                    )
                )
        return found

    def check_secrets(
        self, path: str, line: int, value: str, job: yaml.Node | None, called: Called
    ) -> list[Problem]:
        secrets = get(job, "secrets")
        if scalar(secrets) == "inherit":
            return []
        if secrets is not None and not isinstance(secrets, yaml.MappingNode):
            return [
                Problem(
                    path,
                    line_of(secrets),
                    f'"{value}": secrets is neither a mapping nor "inherit"',
                )
            ]
        found = []
        given = items(secrets)
        names = {key.value for key, _ in given}
        declared_names = ", ".join(sorted(called.secrets)) or "none"
        for key, _ in given:
            if key.value not in called.secrets:
                found.append(
                    Problem(
                        path,
                        line_of(key),
                        f'secret {key.value!r} is not declared by "{value}" (its secrets: {declared_names})',
                    )
                )
        for name, definition in sorted(called.secrets.items()):
            if is_true(get(definition, "required")) and name not in names:
                found.append(
                    Problem(
                        path, line, f'"{value}" requires the secret {name!r}, which is not passed'
                    )
                )
        return found


def tracked_files(root: Path) -> list[str]:
    """The workflows, and every action.yml anywhere in the repository, that git tracks."""
    listed = subprocess.run(
        ["git", "ls-files", "-z"],  # noqa: S607 - git from PATH, as in every git hook
        cwd=root,
        check=True,
        capture_output=True,
    ).stdout.decode("utf-8")
    return sorted(
        path
        for path in listed.split("\0")
        if (str(PurePosixPath(path).parent) == WORKFLOWS and path.endswith((".yml", ".yaml")))
        or PurePosixPath(path).name in ("action.yml", "action.yaml")
    )


def main(argv: list[str]) -> int:
    root = Path(argv[0]) if argv else ROOT
    files = tracked_files(root)
    found = Checker(root).problems(files)
    for problem in found:
        print(problem, file=sys.stderr)
    if not found:
        print(f"Same-repository workflow and action references passed ({len(files)} file(s)).")
    return 1 if found else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
