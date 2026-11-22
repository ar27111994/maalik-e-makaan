#!/usr/bin/env python3
"""Check that only release.yml's publish jobs can put files on a release or sign their provenance.

Each release carries its files' build provenance as a `.intoto.jsonl` file, the name OpenSSF
Scorecard's Signed-Releases check counts (SECURITY.md, Checking a download). The builds that
make the files run Gradle's plugins, CocoaPods, the pub packages and Flutter, so release.yml
gives them a read-only token and no OIDC token: they hand their files over as a run artifact,
and a publish job of their own, on a fresh GitHub-hosted runner that runs none of those tools,
takes it by its id, keeps exactly the release's names, attests them, checks the provenance file
against each with the options SECURITY.md gives, and only then attaches them.

This check keeps that so. It reads the workflows' structure and values, never shell: the only
jobs that matter are those that can write to a release or sign as release.yml, permissions and
secrets decide which jobs those are, and each such job must be a fixed template. It reads no
build step, by design: what a build runs cannot reach the publish runner, its write token or its
OIDC token. For every tracked workflow in .github/workflows:

- R1. Permissions are declared: the workflow's top-level `permissions`, and a job's own where
  it sets one, is a mapping or `read-all` (not `write-all`, an expression or nothing).
- R2. Who may write or sign. A job's permissions are its own, or else the workflow's; a scope
  whose value is not `read` or `none` counts as a write. In release.yml, R5 and R6 hold the
  permissions of release-please and of the publish jobs exactly, and every other job writes
  nothing at all. In every other workflow, no job writes `contents` or `attestations`, and the
  file's name does not start with `release.`, nor with `release`, any one character and `yml`.
  `id-token: write` stays allowed there: an OIDC token of another workflow fails SECURITY.md's
  `--signer-workflow` with gh 2.102.0 or later, and older gh, which matches it as a prefix (and
  some versions with its dot as any character), would take only such a name for release.yml.
- R3. Secrets. In each value, from its first `${{` to its end, `secrets` (in any case) is
  followed directly by `.NAME` (no `secrets[…]`, `toJSON(secrets)` or bare `secrets`); NAME,
  read as GitHub reads a property (`-` included) and upper-cased, is in KNOWN_SECRETS; the text
  RELEASE_PLEASE_TOKEN, in any case, appears in no value but release-please's `with.token`; no
  mapping key holds `${{` (these rules read values, and no workflow needs an expression in a
  key); and a job passes `secrets` only as a mapping (never `inherit`).
- R4. release.yml runs only on push and workflow_dispatch (`workflow_call` would let another
  workflow sign as release.yml), its `defaults` is at most `run: {shell: bash}`, and its
  top-level `env` sets only FLUTTER_VERSION and JAVA_VERSION: the workflow's `defaults` and
  `env` reach every publish step.
- R5. release-please, which holds the write token, equals RELEASE_PLEASE_TEMPLATE, compared as
  R6 compares the publish jobs: its pinned action alone, with exactly today's inputs, runner,
  outputs and permissions (an input such as `github-api-url` or `proxy-server` would send the
  token elsewhere, and its `tag` output names the release the publish jobs overwrite).
- R6. Each publish job in PUBLISH_JOBS equals PUBLISH_TEMPLATE, filled in for its build: key for
  key and value for value, steps in order, runs as exact text. Only `name` and `timeout-minutes`
  of the job and of its steps are free, and each `uses` may name any 40-hex commit of the
  template's action (a Dependabot bump), never a tag or another owner. A commit that is not the
  action's own (an impostor commit, from a fork) passes here and in make lint's offline zizmor;
  security.yml's zizmor job, which runs the online audits, catches it.
- R7. Each publish job's build runs on its GitHub-hosted runner as PUBLISH_JOBS names it (the
  provenance records the runner of the job that attests, so this rule holds the builds' runners)
  and hands `dist/` over through one step with `id: upload` (actions/upload-artifact at a 40-hex
  commit, `with.path: dist/`) and the job output
  `artifact-id: ${{ steps.upload.outputs.artifact-id }}`. actionlint cannot see a typo in an
  output of a SHA-pinned action; the publish job would fail closed without this rule, as
  `|| 'missing'` makes an empty id no id.

A file is unreadable here when a mapping has a key twice or a key that is not text (the check
would see one of two values, and GitHub refuses the file), when an alias holds itself, or when
it has a line break that PyYAML, a YAML 1.1 reader, takes and a YAML 1.2 reader does not (NEL,
LS or PS: PyYAML could see a key that GitHub reads as part of a comment). Other ways PyYAML and
GitHub could read a workflow differently are refused elsewhere in make lint: actionlint refuses a
merge key (`<<`), a key in another case (`Permissions:`, `Contents:`) and a value of the wrong
shape (a scalar `env`), and tool/check_unicode.py refuses NEL as well.

The templates and release.yml change together, in one pull request that review reads; so does a
move from actions/attest-build-provenance to actions/attest. What this check does not cover (what
a build puts in its own files, the trust base, settings outside the files, PyYAML against
GitHub's parser) is in docs/operations.md, Release provenance.

    python3 tool/github/check_release_provenance.py [repository root]
"""

from __future__ import annotations

import re
import sys
from collections.abc import Iterator
from pathlib import Path, PurePosixPath
from typing import Any

import yaml

sys.path.insert(0, str(Path(__file__).resolve().parent))

from check_workflow_calls import (
    WORKFLOWS,
    Problem,
    compose,
    get,
    items,
    line_of,
    scalar,
    tracked_files,
)

ROOT = Path(__file__).resolve().parents[2]
RELEASE = f"{WORKFLOWS}/release.yml"
RELEASE_PLEASE = "release-please"

# Line breaks that PyYAML takes and a YAML 1.2 reader does not.
YAML_1_1_BREAKS = frozenset("\x85\u2028\u2029")

# R2. Permission values that write nothing; any other value counts as a write.
READ_ONLY = frozenset({"read", "none"})
# What no job outside release.yml may write: files on a release, or an attestation.
REFUSED_ELSEWHERE = frozenset({"attestations", "contents"})
# A workflow name that gh before 2.102.0 takes for release.yml under `--signer-workflow`: it
# matches `release.yml` as a prefix, and some versions read its dot as any character.
SIGNER_LOOKALIKE = re.compile(r"release(\.|.yml)")

# R3. Every secret a workflow may name. Add one only after asking whether it can write to the
# repository or sign; one that can is confined to a single place as RELEASE_PLEASE_TOKEN is.
WRITE_SECRET = "RELEASE_PLEASE_TOKEN"  # noqa: S105 - the secret's name, not its value
WRITE_SECRET_AT = f"jobs.{RELEASE_PLEASE}.steps[0].with.token"
KNOWN_SECRETS = frozenset(
    {
        "GITHUB_TOKEN",
        WRITE_SECRET,
        "ANDROID_KEYSTORE_BASE64",
        "ANDROID_KEYSTORE_PASSWORD",
        "ANDROID_KEY_ALIAS",
        "ANDROID_KEY_PASSWORD",
        "SUPABASE_ACCESS_TOKEN",
        "SUPABASE_DB_PASSWORD",
        "VERCEL_TOKEN",
    }
)
# The secrets context, with the name after it when it is named as `secrets.NAME`. Searched from
# a value's first `${{` to its end, without working out where an expression ends, so that
# `${{ '}}' && secrets[…] }}` is read too.
SECRET_WORD = re.compile(r"\bsecrets\b(?:\.([A-Za-z_][A-Za-z0-9_-]*))?", re.IGNORECASE)

# R4.
TRIGGERS = frozenset({"push", "workflow_dispatch"})
DEFAULTS = {"run": {"shell": "bash"}}
WORKFLOW_ENV = frozenset({"FLUTTER_VERSION", "JAVA_VERSION"})

# R5 and R6. A commit an action is pinned to.
PIN = re.compile(r"[0-9a-f]{40}")
# The keys of a job held to a template, and of each of its steps, that may hold any value.
FREE = frozenset({"name", "timeout-minutes"})
# release-please, without its free keys; a `uses` is its action's name and `@`, which any
# 40-hex commit may follow.
RELEASE_PLEASE_TEMPLATE = """\
runs-on: ubuntu-24.04
permissions:
  contents: write
  issues: write
  pull-requests: write
outputs:
  created: ${{ steps.release.outputs.release_created }}
  tag: ${{ steps.release.outputs.tag_name }}
  version: ${{ steps.release.outputs.version }}
steps:
  - id: release
    uses: googleapis/release-please-action@
    with:
      token: ${{ secrets.RELEASE_PLEASE_TOKEN || github.token }}
      config-file: release-please-config.json
      manifest-file: .release-please-manifest.json
"""

# R6 and R7. Each publish job: its build job, the GitHub-hosted runner that build runs on, the
# files it moves into dist/ (the release's names for that build, as shell words over lines
# joined by a backslash), and its provenance file's suffix.
PUBLISH_JOBS = {
    "publish-artefacts": (
        "artefacts",
        "ubuntu-24.04",
        'build/SHA256SUMS "build/maalik-e-makaan-$TAG.aab" \\\n'
        '  "build/maalik-e-makaan-$TAG"-{arm64-v8a,armeabi-v7a,x86_64}.apk \\\n'
        '  "build/maalik-e-makaan-$TAG"-{web,debug-symbols}.zip',
        "",
    ),
    "publish-ios": (
        "ios",
        "macos-26",
        'build/SHA256SUMS-ios "build/maalik-e-makaan-$TAG-ios-unsigned.ipa"',
        "-ios",
    ),
}
# A publish job, without its free keys. <build>, <files> and <suffix> are filled in from
# PUBLISH_JOBS; a `uses` is its action's name and `@`, which any 40-hex commit may follow.
PUBLISH_TEMPLATE = """\
needs: [release-please, <build>]
if: needs.release-please.outputs.created == 'true'
runs-on: ubuntu-24.04
environment: release
permissions:
  attestations: write
  contents: write
  id-token: write
env:
  TAG: ${{ needs.release-please.outputs.tag }}
steps:
  - uses: actions/download-artifact@
    with:
      artifact-ids: ${{ needs.<build>.outputs.artifact-id || 'missing' }}
      path: build
      digest-mismatch: error
  - run: |
      mkdir dist
      mv -- <files> dist/
      rmdir build
  - id: provenance
    uses: actions/attest-build-provenance@
    with:
      subject-path: dist/*
  - env:
      BUNDLE: ${{ steps.provenance.outputs.bundle-path }}
      PROVENANCE: dist/maalik-e-makaan-${{ needs.release-please.outputs.tag }}<suffix>.intoto.jsonl
    run: |
      gh --version
      cp -- "$BUNDLE" "$PROVENANCE"
      for file in dist/*; do
        [[ "$file" == "$PROVENANCE" ]] && continue
        gh attestation verify "$file" --bundle "$PROVENANCE" --repo "$GITHUB_REPOSITORY" \\
          --signer-workflow "$GITHUB_REPOSITORY/.github/workflows/release.yml" \\
          --source-ref refs/heads/main --deny-self-hosted-runners
      done
  - env:
      GH_TOKEN: ${{ github.token }}
    run: gh release upload "$TAG" dist/* --clobber --repo "$GITHUB_REPOSITORY"
"""

# R7.
UPLOAD_ACTION = "actions/upload-artifact@"
HANDOFF = {"artifact-id": "${{ steps.upload.outputs.artifact-id }}"}


class UnreadableError(ValueError):
    """A mapping in the file has a key twice, or a key that is not text."""

    def __init__(self, node: yaml.Node, message: str) -> None:
        super().__init__(message)
        self.node = node


def plain(node: yaml.Node | None) -> Any:
    """The node as text, lists and dicts. GitHub merges nothing, so `<<` stays an ordinary key."""
    if isinstance(node, yaml.SequenceNode):
        return [plain(item) for item in node.value]
    if isinstance(node, yaml.MappingNode):
        found: dict[str, Any] = {}
        for key, value in node.value:
            name = scalar(key)
            if name is None:
                raise UnreadableError(key, "a key that is not text")
            if name in found:
                raise UnreadableError(key, f"the key {name!r} twice in one mapping")
            found[name] = plain(value)
        return found
    return scalar(node)


def template(job: str) -> Any:
    """PUBLISH_TEMPLATE filled in for `job`."""
    build, _, files, suffix = PUBLISH_JOBS[job]
    text = (
        PUBLISH_TEMPLATE.replace("<build>", build)
        .replace("<files>", files.replace("\n", "\n      "))
        .replace("<suffix>", suffix)
    )
    return plain(compose(text))


def pinned(value: str | None, prefix: str) -> bool:
    """Whether `value` is `prefix` (an action's name and `@`) and a 40-hex commit."""
    return (
        value is not None
        and value.startswith(prefix)
        and PIN.fullmatch(value[len(prefix) :]) is not None
    )


def differences(
    expected: Any, actual: yaml.Node, where: str, free: bool
) -> list[tuple[yaml.Node, str]]:
    """Where `actual` differs from the template's `expected`; `free` is true only for a job's or
    a step's own keys, of which `name` and `timeout-minutes` may hold anything."""
    if isinstance(expected, dict):
        if not isinstance(actual, yaml.MappingNode):
            return [(actual, f"{where or 'the job'}: a mapping, as the template has")]
        given = {key.value: (key, value) for key, value in items(actual)}
        found: list[tuple[yaml.Node, str]] = []
        for key, value in expected.items():
            path = f"{where}.{key}" if where else key
            if key not in given:
                found.append((actual, f"{path}: missing; the template has {value!r}"))
            elif key == "uses":
                node = given[key][1]
                if not pinned(scalar(node), value):
                    found.append((node, f"{path}: {value}<40-hex commit>, found {plain(node)!r}"))
            elif key == "steps":
                found += steps(value, given[key][1], path)
            else:
                found += differences(value, given[key][1], path, free=False)
        for key, (node, _) in given.items():
            if key not in expected and not (free and key in FREE):
                path = f"{where}.{key}" if where else key
                found.append((node, f"{path}: not in the template"))
        return found
    if isinstance(expected, list):
        if not isinstance(actual, yaml.SequenceNode) or len(actual.value) != len(expected):
            return [(actual, f"{where}: {expected!r}, found {plain(actual)!r}")]
        return [
            found
            for i, (one, other) in enumerate(zip(expected, actual.value, strict=True))
            for found in differences(one, other, f"{where}[{i}]", free=False)
        ]
    if scalar(actual) == expected:
        return []
    return [(actual, f"{where}: {expected!r}, found {plain(actual)!r}")]


def steps(expected: list[Any], actual: yaml.Node, where: str) -> list[tuple[yaml.Node, str]]:
    """A job's steps against its template's, in order."""
    if not isinstance(actual, yaml.SequenceNode) or len(actual.value) != len(expected):
        count = len(actual.value) if isinstance(actual, yaml.SequenceNode) else "no list"
        return [(actual, f"{where}: {len(expected)} in the template, found {count}")]
    return [
        found
        for i, (one, other) in enumerate(zip(expected, actual.value, strict=True))
        for found in differences(one, other, f"{where}[{i}]", free=True)
    ]


def writes(permissions: yaml.Node | None) -> dict[str, str] | None:
    """The scopes a declared `permissions` value writes, with their values; None when it is
    neither a mapping nor `read-all`."""
    if isinstance(permissions, yaml.MappingNode):
        return {
            key.value: str(plain(value))
            for key, value in items(permissions)
            if scalar(value) not in READ_ONLY
        }
    if scalar(permissions) == "read-all":
        return {}
    return None


def scalars(node: yaml.Node | None, where: str = "") -> Iterator[tuple[str, yaml.ScalarNode, bool]]:
    """Every scalar in the document with its path, and whether it is a mapping's key."""
    if isinstance(node, yaml.SequenceNode):
        for i, item in enumerate(node.value):
            yield from scalars(item, f"{where}[{i}]")
    elif isinstance(node, yaml.MappingNode):
        for key, value in items(node):
            path = f"{where}.{key.value}" if where else key.value
            yield path, key, True
            yield from scalars(value, path)
    elif isinstance(node, yaml.ScalarNode):
        yield where, node, False


def held(rule: str, job: str, expected: Any, node: yaml.Node, constant: str) -> list[Problem]:
    """R5 and R6: where `node`, release.yml's job `job`, differs from its template."""
    return [
        Problem(
            RELEASE,
            line_of(at),
            f'{rule}: job "{job}" differs from the template at {message}; change {constant} in'
            " tool/github/check_release_provenance.py and the job together",
        )
        for at, message in differences(expected, node, "", free=True)
    ]


class Checker:
    def __init__(self, root: Path) -> None:
        self.root = root

    def problems(self, files: list[str]) -> list[Problem]:
        found: list[Problem] = []
        for path in files:
            try:
                text = (self.root / path).read_text(encoding="utf-8")
                document = compose(text)
                plain(document)
            except (OSError, UnicodeDecodeError, yaml.YAMLError, RecursionError) as error:
                found.append(Problem(path, 1, f"cannot read it ({error})"))
                continue
            except UnreadableError as error:
                found.append(
                    Problem(
                        path,
                        line_of(error.node),
                        f"cannot read it: {error}; GitHub refuses such a file, and this check"
                        " would see only one of the values",
                    )
                )
                continue
            at = min((text.index(c) for c in YAML_1_1_BREAKS if c in text), default=-1)
            if at >= 0:
                found.append(
                    Problem(
                        path,
                        text.count("\n", 0, at) + 1,
                        f"cannot read it: U+{ord(text[at]):04X} is a line break to PyYAML, not to"
                        " a YAML 1.2 reader, so the two could see different keys",
                    )
                )
                continue
            found += self.permissions(path, document)
            found += self.secrets(path, document)
            if path == RELEASE:
                found += self.release(path, document)
        if RELEASE not in files:
            found.append(
                Problem(
                    RELEASE, 1, "R6: release.yml is missing, so no job attaches a release's files"
                )
            )
        return found

    def permissions(self, path: str, document: yaml.Node | None) -> list[Problem]:
        """R1 and R2."""
        found: list[Problem] = []
        if path != RELEASE and SIGNER_LOOKALIKE.match(PurePosixPath(path).name):
            found.append(
                Problem(
                    path,
                    1,
                    "R2: no workflow but release.yml may have a name that starts with `release.`"
                    " (or `release`, any one character and `yml`): gh before 2.102.0 takes it"
                    " for release.yml under --signer-workflow",
                )
            )
        top = get(document, "permissions")
        top_writes = writes(top)
        if top_writes is None:
            found.append(
                Problem(
                    path,
                    line_of(top) if top is not None else 1,
                    "R1: set the workflow's top-level `permissions` as a mapping of scopes or"
                    " `read-all`; without it, or with `write-all`, every job may write",
                )
            )
            top_writes = {}
        for name, job in items(get(document, "jobs")):
            own = get(job, "permissions")
            granted = top_writes if own is None else writes(own)
            if granted is None:
                found.append(
                    Problem(
                        path,
                        line_of(own),
                        f'R1: job "{name.value}": set `permissions` as a mapping of scopes or'
                        " `read-all`",
                    )
                )
                continue
            if path != RELEASE:
                refused = {s: v for s, v in granted.items() if s in REFUSED_ELSEWHERE}
                why = (
                    "outside release.yml no job may write contents or attestations (files on a"
                    " release, or provenance)"
                )
            elif name.value == RELEASE_PLEASE or name.value in PUBLISH_JOBS:
                refused, why = {}, ""  # R5 and R6 hold these jobs' permissions exactly
            else:
                refused = granted
                why = (
                    "in release.yml only release-please and the publish jobs write; a build"
                    " hands its files to its publish job"
                )
            for scope, value in sorted(refused.items()):
                found.append(
                    Problem(
                        path,
                        line_of(own if own is not None else name),
                        f'R2: job "{name.value}" holds `{scope}: {value}`: {why}',
                    )
                )
        return found

    def secrets(self, path: str, document: yaml.Node | None) -> list[Problem]:
        """R3."""
        found: list[Problem] = []
        for name, job in items(get(document, "jobs")):
            passed = get(job, "secrets")
            if passed is not None and not isinstance(passed, yaml.MappingNode):
                found.append(
                    Problem(
                        path,
                        line_of(passed),
                        f'R3: job "{name.value}" passes `secrets: {plain(passed)}`; pass each'
                        " secret the called workflow needs by name",
                    )
                )
        for where, node, key in scalars(document):
            text = node.value
            if key:
                if "${{" in text:
                    found.append(
                        Problem(
                            path,
                            line_of(node),
                            f"R3: the key {where} holds an expression: this check reads secrets"
                            " in values only, and no workflow needs an expression in a key",
                        )
                    )
                continue
            if WRITE_SECRET.lower() in text.lower() and (path, where) != (RELEASE, WRITE_SECRET_AT):
                found.append(
                    Problem(
                        path,
                        line_of(node),
                        f"R3: {WRITE_SECRET} at {where}: it can write to the repository, so only"
                        f" release.yml's {WRITE_SECRET_AT} may name it",
                    )
                )
            start = text.find("${{")
            if start < 0:
                continue
            for match in SECRET_WORD.finditer(text, start):
                secret = match.group(1)
                if secret is None:
                    found.append(
                        Problem(
                            path,
                            line_of(node),
                            f"R3: `secrets` at {where} is not followed by `.NAME`: name each"
                            " secret as secrets.NAME (and, in a value with an expression,"
                            " write the word secrets nowhere else, or move the expression into"
                            " `env`)",
                        )
                    )
                elif secret.upper() not in KNOWN_SECRETS:
                    found.append(
                        Problem(
                            path,
                            line_of(node),
                            f"R3: secrets.{secret} at {where} is not in KNOWN_SECRETS; add it"
                            " there only once it is known not to write to the repository or"
                            " sign",
                        )
                    )
        return found

    def release(self, path: str, document: yaml.Node | None) -> list[Problem]:
        """R4 to R7, for release.yml."""
        found: list[Problem] = []
        on = get(document, "on")
        if isinstance(on, yaml.ScalarNode):
            triggers = [on.value]
        elif isinstance(on, yaml.SequenceNode):
            triggers = [scalar(item) for item in on.value]
        else:
            triggers = [key.value for key, _ in items(on)]
        for trigger in triggers:
            if trigger not in TRIGGERS:
                found.append(
                    Problem(
                        path,
                        line_of(on),
                        f"R4: release.yml runs on {trigger!r}; only push and workflow_dispatch"
                        " (another workflow calling it would sign as release.yml)",
                    )
                )
        defaults = get(document, "defaults")
        if defaults is not None and plain(defaults) != DEFAULTS:
            found.append(
                Problem(
                    path,
                    line_of(defaults),
                    "R4: release.yml's `defaults` may be `run: {shell: bash}` and nothing else,"
                    " since it reaches every publish step",
                )
            )
        env = get(document, "env")
        if env is not None:
            names = (
                [key.value for key, _ in items(env)]
                if isinstance(env, yaml.MappingNode)
                else [str(plain(env))]
            )
            for name in names:
                if name not in WORKFLOW_ENV:
                    found.append(
                        Problem(
                            path,
                            line_of(env),
                            f"R4: release.yml's top-level `env` sets {name!r}; only"
                            f" {', '.join(sorted(WORKFLOW_ENV))}, since it reaches every"
                            " publish step",
                        )
                    )
        jobs = {key.value: value for key, value in items(get(document, "jobs"))}
        node = jobs.get(RELEASE_PLEASE)
        if node is None:
            found.append(Problem(path, 1, f'R5: release.yml has no job "{RELEASE_PLEASE}"'))
        else:
            expected = plain(compose(RELEASE_PLEASE_TEMPLATE))
            found += held("R5", RELEASE_PLEASE, expected, node, "RELEASE_PLEASE_TEMPLATE")
        for job, (build, runner, _, _) in PUBLISH_JOBS.items():
            node = jobs.get(job)
            if node is None:
                found.append(Problem(path, 1, f'R6: release.yml has no job "{job}"'))
                continue
            found += held("R6", job, template(job), node, "PUBLISH_TEMPLATE")
            found += self.handoff(path, build, runner, jobs.get(build))
        return found

    def handoff(self, path: str, build: str, runner: str, job: yaml.Node | None) -> list[Problem]:
        """R7."""
        if job is None:
            return [
                Problem(path, 1, f'R7: release.yml has no job "{build}", which a publish job needs')
            ]
        why: list[str] = []
        if scalar(get(job, "runs-on")) != runner:
            why.append(f"it does not run on {runner}, its GitHub-hosted runner")
        if plain(get(job, "outputs")) != HANDOFF:
            why.append(
                "its outputs are not exactly `artifact-id: ${{ steps.upload.outputs.artifact-id }}`"
            )
        run = get(job, "steps")
        upload = [
            step
            for step in (run.value if isinstance(run, yaml.SequenceNode) else [])
            if scalar(get(step, "id")) == "upload"
        ]
        if len(upload) != 1:
            why.append(f"{len(upload)} steps with `id: upload`, not one")
        else:
            if not pinned(scalar(get(upload[0], "uses")), UPLOAD_ACTION):
                why.append(f"its upload step does not use {UPLOAD_ACTION}<40-hex commit>")
            if scalar(get(get(upload[0], "with"), "path")) != "dist/":
                why.append("its upload step's `with.path` is not `dist/`")
        if not why:
            return []
        return [
            Problem(
                path,
                line_of(job),
                f'R7: job "{build}" must run on its GitHub-hosted runner and hand dist/ to its'
                " publish job through one step with `id: upload` and its `artifact-id` output;"
                f" {'; '.join(why)}",
            )
        ]


def workflow_files(root: Path) -> list[str]:
    return [path for path in tracked_files(root) if str(PurePosixPath(path).parent) == WORKFLOWS]


def main(argv: list[str]) -> int:
    root = Path(argv[0]) if argv else ROOT
    files = workflow_files(root)
    found = Checker(root).problems(files)
    for problem in found:
        print(problem, file=sys.stderr)
    if not found:
        print(f"Release provenance checks passed ({len(files)} workflow file(s)).")
    return 1 if found else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
