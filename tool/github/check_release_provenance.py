#!/usr/bin/env python3
"""Check that every job that uploads files to a GitHub release attaches their provenance.

OpenSSF Scorecard's Signed-Releases check (v5.6.0) looks only at the names of the files on each
of the five newest releases: a name ending in `.intoto.jsonl` scores the release 10, a signature
(`.asc`, `.minisig`, `.sig`, `.sign`, `.sigstore`, `.sigstore.json`) 8, neither 0. The
attestations GitHub keeps for a workflow's builds count for nothing until a file is attached.
release.yml therefore attests `dist/*`, copies the attestation's Sigstore bundle into `dist/` as
a `.intoto.jsonl` file, checks it with `gh attestation verify --bundle` against every file it
covers, and only then uploads `dist/*` (docs/operations.md, Release provenance; SECURITY.md,
Checking a download). This check keeps that so, for every tracked workflow in
.github/workflows. In each job that runs `gh release upload`:

- there is exactly one such step, and its run is that one command, uploading `dist/*` (and no
  other path) with `--clobber`;
- the two steps just before it are, back to back, the attest step (`uses:
  actions/attest-build-provenance@<40-hex commit>`, with an `id` and `subject-path: dist/*`)
  and the provenance step, so no step can add an unattested file to `dist/` in between;
- the provenance step's `env.BUNDLE` is the attest step's `bundle-path` output, its
  `env.PROVENANCE` a file directly in `dist/` whose name ends in `.intoto.jsonl`, and its run
  copies the one to the other (`cp -- "$BUNDLE" "$PROVENANCE"`) and loops over `dist/*`, running
  `gh attestation verify "$file" --bundle "$PROVENANCE"` with `--signer-workflow` naming this
  workflow file and `--source-ref refs/heads/main`, the options SECURITY.md tells people to use.
  Once comments are dropped and continuation lines joined, the run is exactly the six lines
  release.yml has (`RUN_LINES`), so nothing in it can stop the loop early, skip a file, or
  swallow a failure (`||`, `!`, `set +e`, `exit 0`, `break`);
- none of the three steps has an `if:`, `continue-on-error` or `shell:`, the job has no
  `continue-on-error`, and the job's and the workflow's `defaults.run.shell`, where set, is
  `bash`: the runner runs that as `bash --noprofile --norc -e -o pipefail {0}`, and a step without
  a shell as `bash -e {0}`, so a failed verify ends the step; a custom shell such as `bash {0}`
  drops `-e`, and then only the last file's verify would count;
- the job grants `attestations: write` and `id-token: write`.

No two jobs may name the same provenance file (the two `--clobber` uploads would replace each
other's), no job may upload release files another way (`gh release create`, an upload to
uploads.github.com, or a release-upload action), and at least one job must upload, so that a
renamed upload command cannot pass this check by matching nothing.

Limits. It reads the workflow's structure and the text of these three steps' commands; it does
not run the shell. It checks the action as named here: a move to `actions/attest` (which the
wrapper's README recommends for new work) must update this check in the same change, keeping
build provenance (no predicate inputs). Scorecard's extension lists are as of v5.6.0; the docs
name that version.

    python3 tool/github/check_release_provenance.py [repository root]
"""

from __future__ import annotations

import re
import shlex
import sys
from pathlib import Path, PurePosixPath

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
ATTEST_ACTION = "actions/attest-build-provenance"
ATTEST = re.compile(rf"^{re.escape(ATTEST_ACTION)}@[0-9a-f]{{40}}$")
UPLOAD = re.compile(r"\bgh\s+release\s+upload\b")
SOURCE_REF = "refs/heads/main"
# Other ways of putting files on a release, refused so that the check cannot be sidestepped.
OTHER_UPLOAD = re.compile(r"\bgh\s+release\s+create\b|uploads\.github\.com")
UPLOAD_ACTIONS = (
    "softprops/action-gh-release",
    "ncipollo/release-action",
    "svenstaro/upload-release-action",
    "actions/upload-release-asset",
)
# `set +e`, `set +eo pipefail`, `set +xe`, `set +o errexit`, `set +o pipefail`, and a `!` that
# turns a failed command into a success.
SWALLOWS = re.compile(
    r"\|\||\bset\s+\+[a-z]*e|\bset\s+\+o\s+(?:errexit|pipefail)\b|(?:^|[;&|(]\s*)!\s"
)
# The provenance step's run, line by line once comments are dropped and continuation lines joined
# (with runs of white space read as one space); {workflow} is the workflow file's path.
RUN_LINES = (
    "gh --version",
    'cp -- "$BUNDLE" "$PROVENANCE"',
    "for file in dist/*; do",
    '[[ "$file" == "$PROVENANCE" ]] && continue',
    'gh attestation verify "$file" --bundle "$PROVENANCE" --repo "$GITHUB_REPOSITORY"'
    ' --signer-workflow "$GITHUB_REPOSITORY/{workflow}" --source-ref ' + SOURCE_REF,
    "done",
)
# The one shell a workflow or a job may set as its default for these steps.
SHELL = "bash"


def commands(run: str) -> list[str]:
    """The run's logical lines: continuation lines joined, comment lines and blanks dropped."""
    joined = re.sub(r"\\\n", " ", run)
    return [
        line.strip()
        for line in joined.split("\n")
        if line.strip() and not line.strip().startswith("#")
    ]


def run_of(step: yaml.Node) -> str | None:
    return scalar(get(step, "run"))


def uses_of(step: yaml.Node) -> str:
    return (scalar(get(step, "uses")) or "").strip()


def is_upload(step: yaml.Node) -> bool:
    run = run_of(step)
    return run is not None and any(UPLOAD.search(line) for line in commands(run))


class Checker:
    def __init__(self, root: Path) -> None:
        self.root = root

    def problems(self, files: list[str]) -> list[Problem]:
        found: list[Problem] = []
        provenance_names: dict[str, tuple[str, int]] = {}
        uploading_jobs = 0
        for path in files:
            try:
                document = compose((self.root / path).read_text(encoding="utf-8"))
            except (OSError, UnicodeDecodeError, yaml.YAMLError) as error:
                found.append(Problem(path, 1, f"cannot read it ({error})"))
                continue
            for job_name, job in items(get(document, "jobs")):
                steps = get(job, "steps")
                if not isinstance(steps, yaml.SequenceNode):
                    continue
                found += self.other_uploads(path, steps.value)
                uploads = [i for i, step in enumerate(steps.value) if is_upload(step)]
                if not uploads:
                    continue
                uploading_jobs += 1
                job_problems, name = self.check_job(path, job_name, job, steps.value, uploads)
                job_problems += self.check_shell(path, job_name.value, document, job)
                found += job_problems
                if name is not None:
                    text, line = name
                    if text in provenance_names:
                        other_path, other_line = provenance_names[text]
                        found.append(
                            Problem(
                                path,
                                line,
                                f'job "{job_name.value}" names the provenance file {text}, as'
                                f" {other_path}:{other_line} does; the two uploads would replace"
                                " each other's file: give each job its own name",
                            )
                        )
                    else:
                        provenance_names[text] = (path, line)
        if uploading_jobs == 0:
            found.append(
                Problem(
                    WORKFLOWS,
                    1,
                    "no job runs `gh release upload`: release.yml attaches the release's files"
                    " that way, so this check has matched nothing (was the command changed?)",
                )
            )
        return found

    def other_uploads(self, path: str, steps: list[yaml.Node]) -> list[Problem]:
        found = []
        for step in steps:
            uses = uses_of(step).split("@", 1)[0]
            run = run_of(step)
            if uses in UPLOAD_ACTIONS or (
                run is not None and any(OTHER_UPLOAD.search(line) for line in commands(run))
            ):
                found.append(
                    Problem(
                        path,
                        line_of(step),
                        "this step puts files on a release without the provenance check: attach"
                        " them with one `gh release upload` step after the attest and provenance"
                        " steps (tool/github/check_release_provenance.py)",
                    )
                )
        return found

    def check_job(
        self,
        path: str,
        job_name: yaml.ScalarNode,
        job: yaml.Node,
        steps: list[yaml.Node],
        uploads: list[int],
    ) -> tuple[list[Problem], tuple[str, int] | None]:
        name = job_name.value
        found: list[Problem] = []
        if len(uploads) > 1:
            lines = ", ".join(str(line_of(steps[i])) for i in uploads)
            return [
                Problem(
                    path,
                    line_of(steps[uploads[1]]),
                    f'job "{name}" runs `gh release upload` in {len(uploads)} steps (lines'
                    f" {lines}); attach the files in one step, right after the provenance step",
                )
            ], None
        found += self.check_permissions(path, name, job, job_name)
        if get(job, "continue-on-error") is not None:
            found.append(
                Problem(
                    path,
                    line_of(get(job, "continue-on-error")),
                    f'job "{name}" uploads release files, so it may not set continue-on-error',
                )
            )
        index = uploads[0]
        upload = steps[index]
        found += self.check_upload(path, name, upload)
        if index < 2:
            found.append(
                Problem(
                    path,
                    line_of(upload),
                    f'job "{name}" uploads to a release without the attest step and the'
                    " provenance step just before the upload",
                )
            )
            return found, None
        attest, provenance = steps[index - 2], steps[index - 1]
        attest_problems, attest_id = self.check_attest(path, name, attest)
        found += attest_problems
        provenance_problems, provenance_name = self.check_provenance(
            path, name, provenance, attest_id
        )
        found += provenance_problems
        for step in (attest, provenance, upload):
            for key in ("if", "continue-on-error"):
                value = get(step, key)
                if value is not None:
                    found.append(
                        Problem(
                            path,
                            line_of(value),
                            f'job "{name}": the attest, provenance and upload steps run'
                            f" always and must succeed, so none may have `{key}:`",
                        )
                    )
            shell = get(step, "shell")
            if shell is not None:
                found.append(
                    Problem(
                        path,
                        line_of(shell),
                        f'job "{name}": the attest, provenance and upload steps run in the'
                        f" default `{SHELL}` (-e, pipefail), so none may have `shell:`"
                        f" (this one is {scalar(shell)!r})",
                    )
                )
        return found, provenance_name

    def check_shell(
        self, path: str, name: str, document: yaml.Node, job: yaml.Node
    ) -> list[Problem]:
        """The default shell the job's steps run in: the job's `defaults.run.shell`, or else the
        workflow's (the job's overrides the workflow's)."""
        for owner, node in ((f'job "{name}"', job), ("the workflow", document)):
            shell = get(get(get(node, "defaults"), "run"), "shell")
            if shell is None:
                continue
            if scalar(shell) == SHELL:
                return []
            return [
                Problem(
                    path,
                    line_of(shell),
                    f'job "{name}" uploads release files, but {owner} sets'
                    f" `defaults.run.shell: {scalar(shell)}`; set `{SHELL}` (the runner adds"
                    " -e and pipefail) or nothing, so a failed verify ends the provenance step",
                )
            ]
        return []

    def check_permissions(
        self, path: str, name: str, job: yaml.Node, job_name: yaml.ScalarNode
    ) -> list[Problem]:
        permissions = get(job, "permissions")
        missing = [
            scope
            for scope in ("attestations", "id-token")
            if scalar(get(permissions, scope)) != "write"
        ]
        if not missing:
            return []
        node = permissions if permissions is not None else job_name
        return [
            Problem(
                path,
                line_of(node),
                f'job "{name}" uploads release files, so it must grant '
                + " and ".join(f"`{scope}: write`" for scope in missing)
                + " to attest them",
            )
        ]

    def check_upload(self, path: str, name: str, upload: yaml.Node) -> list[Problem]:
        run = run_of(upload) or ""
        lines = commands(run)
        where = line_of(get(upload, "run"))
        if len(lines) != 1:
            return [
                Problem(
                    path,
                    where,
                    f'job "{name}": the upload step must run `gh release upload` alone, so that'
                    " nothing it runs can add a file to dist/ after the provenance check",
                )
            ]
        try:
            words = shlex.split(lines[0])
        except ValueError as error:
            return [Problem(path, where, f'job "{name}": cannot read the upload command ({error})')]
        paths = [word for word in words if word.startswith("dist/") or word == "dist"]
        found = []
        if paths != ["dist/*"]:
            found.append(
                Problem(
                    path,
                    where,
                    f'job "{name}" uploads {", ".join(paths) or "no dist/ path"}; upload `dist/*`,'
                    " every file the attestation and the provenance file cover",
                )
            )
        if "--clobber" not in words:
            found.append(
                Problem(
                    path,
                    where,
                    f'job "{name}" uploads without `--clobber`, so a re-run would keep the'
                    " first attempt's files beside a provenance file that does not match them",
                )
            )
        return found

    def check_attest(
        self, path: str, name: str, attest: yaml.Node
    ) -> tuple[list[Problem], str | None]:
        uses = uses_of(attest)
        if not uses.startswith(f"{ATTEST_ACTION}@"):
            return [
                Problem(
                    path,
                    line_of(attest),
                    f'job "{name}": two steps before the upload must be the attest step (uses:'
                    f" {ATTEST_ACTION}@<commit>), then the provenance step, back to back",
                )
            ], None
        found = []
        if not ATTEST.match(uses):
            found.append(
                Problem(
                    path,
                    line_of(get(attest, "uses")),
                    f'job "{name}": pin {ATTEST_ACTION} by its full 40-character commit SHA',
                )
            )
        subject = get(get(attest, "with"), "subject-path")
        if scalar(subject) != "dist/*":
            found.append(
                Problem(
                    path,
                    line_of(subject if subject is not None else attest),
                    f'job "{name}": the attest step\'s subject-path is'
                    f" {scalar(subject)!r}; attest `dist/*`, every file the job uploads",
                )
            )
        attest_id = scalar(get(attest, "id"))
        if not attest_id:
            found.append(
                Problem(
                    path,
                    line_of(attest),
                    f'job "{name}": give the attest step an `id`, so the provenance step can'
                    " read its bundle-path output",
                )
            )
        return found, attest_id

    def check_provenance(
        self, path: str, name: str, step: yaml.Node, attest_id: str | None
    ) -> tuple[list[Problem], tuple[str, int] | None]:
        env = get(step, "env")
        bundle, provenance = get(env, "BUNDLE"), get(env, "PROVENANCE")
        if bundle is None or provenance is None or run_of(step) is None:
            return [
                Problem(
                    path,
                    line_of(step),
                    f'job "{name}": the step just before the upload must be the provenance step'
                    " (env BUNDLE and PROVENANCE, and a run that copies and verifies the file)",
                )
            ], None
        found = []
        if attest_id is not None and not re.fullmatch(
            rf"\$\{{\{{\s*steps\.{re.escape(attest_id)}\.outputs\.bundle-path\s*\}}\}}",
            scalar(bundle) or "",
        ):
            found.append(
                Problem(
                    path,
                    line_of(bundle),
                    f'job "{name}": BUNDLE must be ${{{{ steps.{attest_id}.outputs.bundle-path }}}},'
                    " the attestation the step before made",
                )
            )
        text = scalar(provenance) or ""
        directly_in_dist = text.startswith("dist/") and "/" not in text[len("dist/") :]
        if not directly_in_dist or not text.endswith(".intoto.jsonl"):
            found.append(
                Problem(
                    path,
                    line_of(provenance),
                    f'job "{name}": PROVENANCE is {text!r}; name a file directly in dist/ ending'
                    " in .intoto.jsonl, the name Scorecard counts and gh reads as JSON Lines",
                )
            )
        found += self.check_provenance_run(path, name, step)
        return found, (text, line_of(provenance))

    def check_provenance_run(self, path: str, name: str, step: yaml.Node) -> list[Problem]:
        run = run_of(step) or ""
        where = line_of(get(step, "run"))
        lines = commands(run)
        workflow = PurePosixPath(path).as_posix()
        found = []
        if any(SWALLOWS.search(line) for line in lines):
            found.append(
                Problem(
                    path,
                    where,
                    f'job "{name}": the provenance step must fail when a check fails; remove'
                    " `||`, `!` and `set +e`",
                )
            )
        if 'cp -- "$BUNDLE" "$PROVENANCE"' not in lines:
            found.append(
                Problem(
                    path,
                    where,
                    f'job "{name}": the provenance step must run `cp -- "$BUNDLE" "$PROVENANCE"`',
                )
            )
        if "for file in dist/*; do" not in lines:
            found.append(
                Problem(
                    path,
                    where,
                    f'job "{name}": the provenance step must check every file, in a loop'
                    " `for file in dist/*; do`",
                )
            )
        verify = [line for line in lines if re.search(r"\bgh\s+attestation\s+verify\b", line)]
        required = (
            'gh attestation verify "$file"',
            '--bundle "$PROVENANCE"',
            f'--signer-workflow "$GITHUB_REPOSITORY/{workflow}"',
            f"--source-ref {SOURCE_REF}",
        )
        if not any(all(_has(line, part) for part in required) for line in verify):
            found.append(
                Problem(
                    path,
                    where,
                    f'job "{name}": the provenance step must run, on a line that is not a'
                    " comment, " + " ".join(f"`{part}`" for part in required) + " (SECURITY.md"
                    " tells people to check a download with the same options)",
                )
            )
        expected = [line.format(workflow=workflow) for line in RUN_LINES]
        actual = [re.sub(r"\s+", " ", line) for line in lines]
        if not found and actual != expected:
            extra = next((line for line in actual if line not in expected), None)
            missing = next((line for line in expected if line not in actual), None)
            what = (
                f"it runs `{extra}`"
                if extra is not None
                else (
                    f"it lacks `{missing}`"
                    if missing is not None
                    else "its lines are out of order or repeated"
                )
            )
            found.append(
                Problem(
                    path,
                    where,
                    f'job "{name}": the provenance step\'s run must be exactly these lines, so that'
                    " no file is skipped and no failure is lost; "
                    + what
                    + ": "
                    + " / ".join(f"`{line}`" for line in expected),
                )
            )
        return found


def _has(line: str, part: str) -> bool:
    """Whether `part` is in `line` as whole words (so `refs/heads/main` is not `…/mainx`)."""
    return re.search(rf"(?<!\S){re.escape(part)}(?!\S)", line) is not None


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
