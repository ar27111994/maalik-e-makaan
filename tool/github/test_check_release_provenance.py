"""Tests of check_release_provenance.py (make test-tools).

Most tests are mutants of the real release.yml: each changes its text in one place, which must
occur exactly once (so a mutant never turns silently into a no-op when release.yml changes), and
must give exactly the expected problems.
"""

from __future__ import annotations

import io
import re
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
RELEASE = ".github/workflows/release.yml"
RELEASE_TEXT = (ROOT / RELEASE).read_text(encoding="utf-8")
GIT = shutil.which("git")

# The attest step's `uses:` line as release.yml has it (the pin changes with Dependabot).
ATTEST_USES = re.search(
    r"^ {8}uses: actions/attest-build-provenance@[0-9a-f]{40} # v\S+\n", RELEASE_TEXT, re.M
)[0]
ATTEST = (
    "      - id: provenance\n" + ATTEST_USES + "        with:\n          subject-path: dist/*\n"
)
# The step each attest step follows, which tells the two jobs apart.
BEFORE = {
    "artefacts": '          rm -f "$RUNNER_TEMP/release.jks"\n',
    "ios": "          (cd dist && shasum -a 256 -- * > SHA256SUMS-ios)\n",
}
SUFFIX = {"artefacts": "", "ios": "-ios"}
VERIFY = (
    '            gh attestation verify "$file" --bundle "$PROVENANCE" --repo "$GITHUB_REPOSITORY" \\\n'
    '              --signer-workflow "$GITHUB_REPOSITORY/.github/workflows/release.yml" \\\n'
    "              --source-ref refs/heads/main\n"
)
UPLOAD = '        run: gh release upload "$TAG" dist/* --clobber --repo "$GITHUB_REPOSITORY"\n'
UPLOAD_ENV = "        env:\n          GH_TOKEN: ${{ github.token }}\n"
EXACT = "the upload step's run must be exactly `" + crp.UPLOAD_RUN + "`"
UPLOAD_LINE = crp.UPLOAD_RUN
GH_VERSION = "          gh --version\n"
# How a run the check cannot read as bash does is refused, by step.
UNREADABLE = {
    "provenance": "the provenance step's run cannot be read as bash reads it: ",
    "upload": "the upload step's run cannot be read as bash reads it: ",
}
COMMENT_BACKSLASH = (
    "is a comment that ends in a backslash; bash ends a comment at the end of its line and runs"
    " the next line, which reads as part of the comment: drop the backslash"
)
PAST_THE_LINE = "opens a quoted string that goes on past the line's end"
HERE_DOCUMENT = "has `<<`, a here-document or here-string, whose lines bash reads as text"
AS_A_WORD = "which bash reads as part of a word: only spaces and tabs separate its words"
EXACT_LINES = "the provenance step's run must be exactly these lines"


def upload_run(command: str) -> str:
    """The upload step's run line, with `command` in place of release.yml's."""
    return f"        run: {command}\n"


def provenance_step(job: str) -> str:
    """The provenance step of `job`, as release.yml has it, from its name to its `done`."""
    name = "      - name: Provenance file, checked against every file it covers\n"
    start = RELEASE_TEXT.index(BEFORE[job] + ATTEST + name) + len(BEFORE[job] + ATTEST)
    end = RELEASE_TEXT.index("          done\n", start) + len("          done\n")
    return RELEASE_TEXT[start:end]


def unreadable(job: str, step: str, reason: str) -> tuple[str, ...]:
    """The problem of a run in `job`'s `step` that the check cannot read as bash does."""
    return (f'job "{job}": {UNREADABLE[step]}{reason}',)


def both(*mutants: callable) -> callable:
    """A mutant that applies each of `mutants` in turn."""

    def mutate(text: str) -> str:
        for mutant in mutants:
            text = mutant(text)
        return text

    return mutate


def once(text: str, old: str, new: str) -> str:
    count = text.count(old)
    if count != 1:
        raise AssertionError(f"the mutant's text occurs {count} times in release.yml: {old!r}")
    return text.replace(old, new)


def in_job(job: str, old: str, new: str) -> callable:
    """A mutant that changes `old` within `job`'s attest step, provenance step and upload."""

    def mutate(text: str) -> str:
        start = text.index(BEFORE[job])
        end = text.index(UPLOAD, start) + len(UPLOAD)
        return text[:start] + once(text[start:end], old, new) + text[end:]

    return mutate


def later_step(job: str, run: str) -> callable:
    """A mutant that adds a step running `run` right after `job`'s upload step."""
    return in_job(job, UPLOAD, UPLOAD + f"      - run: {run}\n")


def in_job_header(job: str, old: str, new: str) -> callable:
    """A mutant that changes `old` in `job`'s keys before its steps (the jobs share the text)."""

    def mutate(text: str) -> str:
        start = text.index(f"\n  {job}:\n")
        end = text.index("    steps:\n", start)
        return text[:start] + once(text[start:end], old, new) + text[end:]

    return mutate


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

    def release(self, text: str) -> list[str]:
        return [str(p) for p in self.problems(self.write(RELEASE, text))]

    def assert_problems(self, found: list[str], *fragments: str | tuple[str, ...]) -> None:
        """One problem per fragment, in order; a tuple's parts must all be in its problem."""
        self.assertEqual(len(found), len(fragments), found)
        for problem, fragment in zip(found, fragments, strict=True):
            for part in fragment if isinstance(fragment, tuple) else (fragment,):
                self.assertIn(part, problem)


class RepositoryTest(Fixture):
    def test_the_repository_passes(self):
        files = crp.workflow_files(ROOT)
        self.assertIn(RELEASE, files)
        self.assertEqual([str(p) for p in crp.Checker(ROOT).problems(files)], [])

    def test_the_unchanged_release_yml_passes_in_a_fixture(self):
        self.assertEqual(self.release(RELEASE_TEXT), [])

    def test_release_yml_before_the_provenance_files_fails(self):
        # The workflow as it was in 1.3.0: attested, but with nothing attached.
        before = RELEASE_TEXT
        for job in ("artefacts", "ios"):
            before = once(before, provenance_step(job), "")
        found = self.release(before)
        self.assertEqual(len(found), 4, found)
        for job in ("artefacts", "ios"):
            self.assertTrue(any(f'job "{job}": two steps before the upload' in p for p in found))
            self.assertTrue(
                any(f'job "{job}": the step just before the upload must be' in p for p in found)
            )


MUTANTS = {
    # Order and adjacency.
    "the artefacts attest step removed": (
        lambda t: once(t, BEFORE["artefacts"] + ATTEST, BEFORE["artefacts"]),
        ['job "artefacts": two steps before the upload must be the attest step'],
    ),
    "the attest and provenance steps swapped": (
        lambda t: once(
            t,
            BEFORE["artefacts"] + ATTEST + provenance_step("artefacts"),
            BEFORE["artefacts"] + provenance_step("artefacts") + ATTEST,
        ),
        [
            'job "artefacts": two steps before the upload must be the attest step',
            'job "artefacts": the step just before the upload must be the provenance step',
        ],
    ),
    "a step inserted between the attest and provenance steps": (
        in_job(
            "artefacts",
            "      - name: Provenance file",
            "      - run: touch dist/extra\n      - name: Provenance file",
        ),
        ['job "artefacts": two steps before the upload must be the attest step'],
    ),
    "a step inserted between the provenance step and the upload": (
        in_job(
            "ios",
            "          done\n",
            "          done\n      - run: touch dist/extra\n",
        ),
        [
            'job "ios": two steps before the upload must be the attest step',
            'job "ios": the step just before the upload must be the provenance step',
        ],
    ),
    # Coverage.
    "the iOS subject-path narrowed to dist/*.ipa": (
        in_job("ios", "subject-path: dist/*\n", "subject-path: dist/*.ipa\n"),
        ["job \"ios\": the attest step's subject-path is 'dist/*.ipa'"],
    ),
    "the upload narrowed to dist/*.apk": (
        in_job("artefacts", " dist/* --clobber", " dist/*.apk --clobber"),
        ['job "artefacts" uploads dist/*.apk; upload `dist/*`'],
    ),
    "a second path uploaded": (
        in_job("artefacts", " dist/* --clobber", " dist/* build/x --clobber dist/y"),
        ['job "artefacts" uploads dist/*, dist/y; upload `dist/*`'],
    ),
    "--clobber dropped": (
        in_job("ios", " --clobber", ""),
        ['job "ios" uploads without `--clobber`'],
    ),
    "a second upload step later in the job": (
        in_job(
            "artefacts",
            UPLOAD,
            UPLOAD + '      - run: date > dist/late && gh release upload "$TAG" dist/late\n',
        ),
        ['job "artefacts" runs `gh release upload` in 2 steps'],
    ),
    "the upload step writes into dist/ first": (
        in_job(
            "ios",
            UPLOAD,
            "        run: |\n          date > dist/late\n"
            '          gh release upload "$TAG" dist/* --clobber --repo "$GITHUB_REPOSITORY"\n',
        ),
        ['job "ios": the upload step must run `gh release upload` alone'],
    ),
    # The upload command, which must be exactly release.yml's.
    "a path outside dist/ uploaded beside dist/*": (
        in_job("artefacts", " dist/* --clobber", " dist/* build/x --clobber"),
        [
            f'job "artefacts": {EXACT}, so that it attaches the files of dist/ and nothing else,'
            " to this release, with nothing run before, after or around it; it runs"
            ' `gh release upload "$TAG" dist/* build/x --clobber --repo "$GITHUB_REPOSITORY"`'
        ],
    ),
    "a file written into dist/ on the upload line": (
        in_job(
            "ios",
            UPLOAD,
            upload_run(
                'date > dist/late && gh release upload "$TAG" dist/* --clobber'
                ' --repo "$GITHUB_REPOSITORY"'
            ),
        ),
        ['job "ios" uploads dist/late, dist/*; upload `dist/*`'],
    ),
    "a file written into dist/ from a subshell on the upload line": (
        in_job(
            "artefacts",
            UPLOAD,
            upload_run(
                '(cd dist; date > late) && gh release upload "$TAG" dist/* --clobber'
                ' --repo "$GITHUB_REPOSITORY"'
            ),
        ),
        [(f'job "artefacts": {EXACT}', "it runs `(cd dist; date > late) && gh release upload")],
    ),
    "another directory entered with ; before the upload": (
        in_job(
            "ios",
            UPLOAD,
            upload_run(
                'cd build; gh release upload "$TAG" dist/* --clobber --repo "$GITHUB_REPOSITORY"'
            ),
        ),
        [(f'job "ios": {EXACT}', "it runs `cd build; gh release upload")],
    ),
    "the upload piped into another command": (
        in_job(
            "artefacts",
            UPLOAD,
            upload_run(
                'gh release upload "$TAG" dist/* --clobber --repo "$GITHUB_REPOSITORY" | tee log'
            ),
        ),
        [(f'job "artefacts": {EXACT}', '"$GITHUB_REPOSITORY" | tee log`')],
    ),
    "a variable set for the upload command": (
        in_job("ios", "run: gh release upload", "run: GH_REPO=other/fork gh release upload"),
        [(f'job "ios": {EXACT}', "it runs `GH_REPO=other/fork gh release upload")],
    ),
    "an extra flag on the upload": (
        in_job(
            "artefacts",
            ' --repo "$GITHUB_REPOSITORY"\n',
            ' --repo "$GITHUB_REPOSITORY" -R other/fork\n',
        ),
        [(f'job "artefacts": {EXACT}', '"$GITHUB_REPOSITORY" -R other/fork`')],
    ),
    "the upload to another tag variable": (
        in_job("ios", 'upload "$TAG" dist/*', 'upload "$VERSION" dist/*'),
        [(f'job "ios": {EXACT}', 'it runs `gh release upload "$VERSION" dist/*')],
    ),
    "a second upload step with the command's words quoted": (
        in_job("ios", UPLOAD, UPLOAD + "      - run: gh 'release' upload \"$TAG\" build/x\n"),
        ['job "ios" runs `gh release upload` in 2 steps'],
    ),
    "a release created with the command's words quoted": (
        in_job("artefacts", UPLOAD, UPLOAD + "      - run: '\"gh\" release create v9 build/x'\n"),
        ["this step puts files on a release without the provenance check"],
    ),
    "the tag set in the upload step's env": (
        in_job("artefacts", UPLOAD_ENV + UPLOAD, UPLOAD_ENV + "          TAG: v0.0.1\n" + UPLOAD),
        ['job "artefacts": the upload step\'s env sets TAG; it may set only GH_TOKEN'],
    ),
    "the upload step's env from an expression": (
        in_job(
            "ios",
            UPLOAD_ENV + UPLOAD,
            "        env: ${{ fromJSON(vars.UPLOAD_ENV) }}\n" + UPLOAD,
        ),
        ['job "ios": the upload step\'s env must be a mapping that sets only GH_TOKEN'],
    ),
    "the upload written over several lines, with a comment (still passes)": (
        in_job(
            "artefacts",
            UPLOAD,
            "        run: |\n"
            "          # Every file in dist/, the provenance file included.\n"
            '          gh release upload "$TAG" dist/* \\\n'
            '            --clobber   --repo "$GITHUB_REPOSITORY"\n',
        ),
        [],
    ),
    # The provenance file.
    "the suffix changed to .json": (
        in_job("artefacts", "}}.intoto.jsonl", "}}.json"),
        ['job "artefacts": PROVENANCE is \'dist/maalik-e-makaan-${{'],
    ),
    "the suffix changed to .sigstore.json": (
        in_job("ios", "-ios.intoto.jsonl", "-ios.sigstore.json"),
        ["ending in .intoto.jsonl"],
    ),
    "the provenance file outside dist/": (
        in_job("ios", "PROVENANCE: dist/", "PROVENANCE: dist/provenance/"),
        ['job "ios": PROVENANCE is'],
    ),
    "the iOS provenance file named as the artefacts one": (
        in_job("ios", "-ios.intoto.jsonl", ".intoto.jsonl"),
        ['job "ios" names the provenance file dist/maalik-e-makaan-'],
    ),
    # GitHub ignores white space inside `${{ }}` and the case of context and property names, so
    # these are the artefacts job's file too (F2 on #81's second review).
    "the iOS provenance file named as the artefacts one, with other padding": (
        in_job(
            "ios",
            "${{ needs.release-please.outputs.tag }}-ios.intoto.jsonl",
            "${{needs.release-please.outputs.tag  }}.intoto.jsonl",
        ),
        [
            (
                'job "ios" names the provenance file'
                " dist/maalik-e-makaan-${{needs.release-please.outputs.tag  }}.intoto.jsonl, as"
                f" {RELEASE}:",
                " does (dist/maalik-e-makaan-${{ needs.release-please.outputs.tag }}"
                ".intoto.jsonl, the same file once GitHub reads its expressions); the two uploads"
                " would replace each other's file",
            )
        ],
    ),
    "the iOS provenance file named as the artefacts one, in other case": (
        in_job(
            "ios",
            "${{ needs.release-please.outputs.tag }}-ios.intoto.jsonl",
            "${{ needs.Release-Please.outputs.TAG }}.intoto.jsonl",
        ),
        [
            (
                'job "ios" names the provenance file'
                " dist/maalik-e-makaan-${{ needs.Release-Please.outputs.TAG }}.intoto.jsonl",
                "the same file once GitHub reads its expressions",
            )
        ],
    ),
    "BUNDLE reading attestation-id": (
        in_job("artefacts", "outputs.bundle-path", "outputs.attestation-id"),
        ['job "artefacts": BUNDLE must be ${{ steps.provenance.outputs.bundle-path }}'],
    ),
    "BUNDLE reading another step's output": (
        in_job("ios", "steps.provenance.outputs", "steps.other.outputs"),
        ['job "ios": BUNDLE must be'],
    ),
    "the attest step without an id": (
        in_job("ios", "      - id: provenance\n        uses:", "      - uses:"),
        ['job "ios": give the attest step an `id`'],
    ),
    "the copy removed": (
        in_job("artefacts", '          cp -- "$BUNDLE" "$PROVENANCE"\n', ""),
        ['job "artefacts": the provenance step must run `cp -- "$BUNDLE" "$PROVENANCE"`'],
    ),
    "the loop narrowed to the APKs": (
        in_job("artefacts", "for file in dist/*; do", "for file in dist/*.apk; do"),
        ['job "artefacts": the provenance step must check every file'],
    ),
    # The verification.
    "the verify command removed": (
        in_job("artefacts", VERIFY, ""),
        ['job "artefacts": the provenance step must run, on a line that is not a comment'],
    ),
    "the verify command turned into a comment": (
        in_job(
            "ios",
            VERIFY,
            "".join(line[:12] + "# " + line[12:] for line in VERIFY.splitlines(keepends=True)),
        ),
        # Its first two lines end in a backslash, which bash does not read as joining a comment
        # to the next line.
        [unreadable("ios", "provenance", "line 5 " + COMMENT_BACKSLASH)],
    ),
    "the verify command turned into a comment, without the backslashes": (
        in_job(
            "artefacts",
            VERIFY,
            "".join(
                line[:12] + "# " + line[12:].replace(" \\\n", "\n")
                for line in VERIFY.splitlines(keepends=True)
            ),
        ),
        ['job "artefacts": the provenance step must run, on a line that is not a comment'],
    ),
    "a failed verify swallowed with || true": (
        in_job(
            "artefacts", "--source-ref refs/heads/main\n", "--source-ref refs/heads/main || true\n"
        ),
        ['job "artefacts": the provenance step must fail when a check fails'],
    ),
    "a failed verify swallowed with || :": (
        in_job("ios", "--source-ref refs/heads/main\n", "--source-ref refs/heads/main || :\n"),
        ['job "ios": the provenance step must fail when a check fails'],
    ),
    "set +e in the provenance step": (
        in_job(
            "artefacts", "          gh --version\n", "          set +e\n          gh --version\n"
        ),
        ['job "artefacts": the provenance step must fail when a check fails'],
    ),
    "set +eo pipefail in the provenance step": (
        in_job(
            "ios",
            "          gh --version\n",
            "          set +eo pipefail\n          gh --version\n",
        ),
        ['job "ios": the provenance step must fail when a check fails'],
    ),
    "a failed verify turned into a success with !": (
        in_job(
            "artefacts", "            gh attestation verify", "            ! gh attestation verify"
        ),
        ['job "artefacts": the provenance step must fail when a check fails'],
    ),
    "exit 0 before the loop": (
        in_job(
            "artefacts",
            "          for file in dist/*; do\n",
            "          exit 0\n          for file in dist/*; do\n",
        ),
        [
            'job "artefacts": the provenance step\'s run must be exactly these lines, so that no file is skipped and no failure is lost; it runs `exit 0`'
        ],
    ),
    "break as the first line of the loop": (
        in_job("ios", '            [[ "$file"', '            break\n            [[ "$file"'),
        [
            'job "ios": the provenance step\'s run must be exactly these lines, so that no file is skipped and no failure is lost; it runs `break`'
        ],
    ),
    "the skip line skipping every file in dist/": (
        in_job("artefacts", '[[ "$file" == "$PROVENANCE" ]]', '[[ "$file" == dist/* ]]'),
        [
            'job "artefacts": the provenance step\'s run must be exactly these lines, so that no file is skipped and no failure is lost; it runs'
            ' `[[ "$file" == dist/* ]] && continue`'
        ],
    ),
    "the skip line skipping all but SHA256SUMS-ios": (
        in_job("ios", '[[ "$file" == "$PROVENANCE" ]]', '[[ "$file" != dist/SHA256SUMS-ios ]]'),
        ['job "ios": the provenance step\'s run must be exactly these lines'],
    ),
    "the skip line removed": (
        in_job("ios", '            [[ "$file" == "$PROVENANCE" ]] && continue\n', ""),
        [
            'job "ios": the provenance step\'s run must be exactly these lines, so that no file is skipped and no failure is lost; it lacks'
        ],
    ),
    "the provenance step's lines reordered": (
        in_job(
            "artefacts",
            '          gh --version\n          cp -- "$BUNDLE" "$PROVENANCE"\n',
            '          cp -- "$BUNDLE" "$PROVENANCE"\n          gh --version\n',
        ),
        ["its lines are out of order or repeated"],
    ),
    "the source ref taken from the run": (
        in_job("ios", "--source-ref refs/heads/main", '--source-ref "$GITHUB_REF"'),
        ['job "ios": the provenance step must run, on a line that is not a comment'],
    ),
    "a source ref that only starts like main": (
        in_job("ios", "--source-ref refs/heads/main", "--source-ref refs/heads/mainline"),
        ['job "ios": the provenance step must run, on a line that is not a comment'],
    ),
    "the signer workflow naming another file": (
        in_job("artefacts", 'workflows/release.yml"', 'workflows/deploy.yml"'),
        ['job "artefacts": the provenance step must run, on a line that is not a comment'],
    ),
    "the provenance file not passed to verify": (
        in_job("artefacts", '--bundle "$PROVENANCE"', '--bundle "$BUNDLE"'),
        ['job "artefacts": the provenance step must run, on a line that is not a comment'],
    ),
    # Reading a run as bash does (C1 on #81): a comment never goes on to the next line.
    "a comment that ends in a backslash, then set +e": (
        in_job("artefacts", GH_VERSION, "          # note \\\n          set +e\n" + GH_VERSION),
        [unreadable("artefacts", "provenance", "line 1 " + COMMENT_BACKSLASH)],
    ),
    "a comment that ends in a backslash, opening a quote over every check": (
        both(
            in_job("ios", GH_VERSION, GH_VERSION + "          # note \\\n          : '\n"),
            in_job("ios", "          done\n", "          done\n          # '\n"),
        ),
        [unreadable("ios", "provenance", "line 2 " + COMMENT_BACKSLASH)],
    ),
    "a comment after a command that ends in a backslash, then set +e": (
        in_job("ios", GH_VERSION, "          gh --version # for the log \\\n          set +e\n"),
        [unreadable("ios", "provenance", "line 1 " + COMMENT_BACKSLASH)],
    ),
    "a comment that ends in a backslash, then a file written in the upload step": (
        in_job(
            "ios",
            UPLOAD,
            "        run: |\n          # attach \\\n          date > dist/late\n"
            f"          {UPLOAD_LINE}\n",
        ),
        [unreadable("ios", "upload", "line 1 " + COMMENT_BACKSLASH)],
    ),
    "a comment that ends in two backslashes, then a file written in the upload step": (
        in_job(
            "artefacts",
            UPLOAD,
            "        run: |\n          # attach \\\\\n          date > dist/late\n"
            f"          {UPLOAD_LINE}\n",
        ),
        [unreadable("artefacts", "upload", "line 1 " + COMMENT_BACKSLASH)],
    ),
    "a second upload step behind a comment that ends in a backslash": (
        in_job(
            "artefacts",
            UPLOAD,
            UPLOAD
            + '      - run: |\n          # one more \\\n          gh release upload "$TAG" x\n',
        ),
        ['job "artefacts" runs `gh release upload` in 2 steps'],
    ),
    "a release created behind a comment that ends in a backslash": (
        in_job(
            "ios",
            UPLOAD,
            UPLOAD + "      - run: |\n          # one more \\\n          gh release create v9 x\n",
        ),
        ["this step puts files on a release without the provenance check"],
    ),
    # Words bash runs once it has read its $-quoting (finding 1 on #81's verification): the
    # check reads them as bash does, so a second upload or a create stays visible.
    "a second upload step with the command's word $'quoted'": (
        in_job(
            "artefacts",
            UPLOAD,
            UPLOAD + "      - run: |\n          date > late.txt\n"
            "          gh release $'upload' \"$TAG\" late.txt\n",
        ),
        ['job "artefacts" runs `gh release upload` in 2 steps'],
    ),
    'a second upload step with the command\'s word $"quoted"': (
        later_step("ios", 'gh release $"upload" "$TAG" late.txt'),
        ['job "ios" runs `gh release upload` in 2 steps'],
    ),
    "a second upload step with release $'quoted'": (
        later_step("artefacts", "gh $'release' upload \"$TAG\" late.txt"),
        ['job "artefacts" runs `gh release upload` in 2 steps'],
    ),
    "a second upload step with half the command's word $'quoted'": (
        later_step("ios", "gh release up$'load' \"$TAG\" late.txt"),
        ['job "ios" runs `gh release upload` in 2 steps'],
    ),
    "a second upload step with an ANSI-C escape in the command's word": (
        later_step("artefacts", "gh release $'\\x75pload' \"$TAG\" late.txt"),
        ['job "artefacts" runs `gh release upload` in 2 steps'],
    ),
    "a second upload step with the command's word as a parameter's default": (
        later_step("ios", 'gh release ${x:-upload} "$TAG" late.txt'),
        ['job "ios" runs `gh release upload` in 2 steps'],
    ),
    "a second upload step through eval": (
        later_step("artefacts", "eval \"gh release $'upload' late.txt\""),
        ['job "artefacts" runs `gh release upload` in 2 steps'],
    ),
    "a release created with the command's word $'quoted'": (
        later_step("ios", "gh release $'create' v9 x"),
        ["this step puts files on a release without the provenance check"],
    ),
    # A gh alias or extension can upload under another name (finding 2).
    "a gh alias for the upload in a later step": (
        in_job(
            "artefacts",
            UPLOAD,
            UPLOAD + "      - run: |\n          gh alias set attach 'release upload'\n"
            '          gh attach "$TAG" late.txt\n',
        ),
        [
            "this step puts files on a release without the provenance check, takes them off it,"
            " or defines a gh alias or extension that could",
            # The alias's text holds the upload's words, so the step counts as an upload too.
            'job "artefacts" runs `gh release upload` in 2 steps',
        ],
    ),
    "a gh alias with its words quoted in a later step": (
        later_step("ios", "command gh $'alias' set attach 'release view'"),
        ["this step puts files on a release without the provenance check"],
    ),
    "a gh extension installed in a later step": (
        later_step("artefacts", "gh extension install someone/gh-attach"),
        ["this step puts files on a release without the provenance check"],
    ),
    # A release file deleted after the upload (finding 4).
    "the provenance file deleted from the release": (
        later_step(
            "ios",
            'gh release delete-asset "$TAG" "maalik-e-makaan-$TAG-ios.intoto.jsonl" --yes',
        ),
        ["this step puts files on a release without the provenance check, takes them off it"],
    ),
    "the release deleted": (
        later_step("artefacts", 'gh release delete "$TAG" --yes'),
        ["this step puts files on a release without the provenance check"],
    ),
    "a release file deleted through the REST API": (
        later_step("ios", 'gh api -X DELETE "repos/$GITHUB_REPOSITORY/releases/assets/1"'),
        ["this step puts files on a release without the provenance check"],
    ),
    # Flags before the subcommand, which gh skips with their values (F1 on #81's second
    # review): `-R`/`--repo` is a flag of `gh release` itself.
    **{
        f"a second upload step in {job} with {how}": (
            later_step(job, f'gh release {flags} upload "$TAG" dist/late --clobber'),
            [f'job "{job}" runs `gh release upload` in 2 steps'],
        )
        for job in ("artefacts", "ios")
        for how, flags in (
            ("-R before the subcommand", '-R "$GITHUB_REPOSITORY"'),
            ("--repo= before the subcommand", '--repo="$GITHUB_REPOSITORY"'),
            ("a flag of its own before the subcommand", "--some-flag"),
        )
    },
    **{
        f"{what} in {job} with {flag.split()[0]} before the subcommand": (
            later_step(job, f"gh release {flag} {command}"),
            ["this step puts files on a release without the provenance check"],
        )
        for job in ("artefacts", "ios")
        for flag in ('-R "$GITHUB_REPOSITORY"', '--repo "$GITHUB_REPOSITORY"')
        for what, command in (
            ("a release created", "create v9 dist/late"),
            ("the release deleted", '"$TAG" --yes'.join(("delete ", ""))),
            ("the provenance file deleted", 'delete-asset "$TAG" x.intoto.jsonl --yes'),
        )
    },
    "a second upload step with -R before the subcommand, gh's name in a variable": (
        later_step("ios", 'command "$GH" release -R "$GITHUB_REPOSITORY" upload "$TAG" dist/late'),
        ['job "ios" runs `gh release upload` in 2 steps'],
    ),
    # Only gh knows which flags take a value, so a word after a flag counts as the subcommand
    # too: wider than gh, which runs `view` here, but an upload is never missed.
    "a step whose flag's value is the word upload": (
        later_step("artefacts", 'gh release -R upload view "$TAG"'),
        ['job "artefacts" runs `gh release upload` in 2 steps'],
    ),
    "a gh alias set with a flag before set, gh's name in a variable": (
        later_step("ios", "${GH:-gh} alias --clobber set up 'release view'"),
        ["this step puts files on a release without the provenance check"],
    ),
    "a gh extension installed with a flag before install, gh's name in a variable": (
        later_step("artefacts", 'command "$GH" extension --force install someone/gh-attach'),
        ["this step puts files on a release without the provenance check"],
    ),
    "a release viewed, with -R before the subcommand (still passes)": (
        later_step("ios", 'gh release -R "$GITHUB_REPOSITORY" view "$TAG" --json assets'),
        [],
    ),
    "a release edited and downloaded, with -R before the subcommand (still passes)": (
        later_step(
            "artefacts",
            'gh release -R "$GITHUB_REPOSITORY" edit "$TAG" --draft=false'
            ' && gh release --repo "$GITHUB_REPOSITORY" download "$TAG" -p "*.apk"',
        ),
        [],
    ),
    "a comment after a command (still passes)": (
        in_job("artefacts", GH_VERSION, "          gh --version  # for the log\n"),
        [],
    ),
    "a comment after the upload command (still passes)": (
        in_job("ios", UPLOAD, f"        run: |\n          {UPLOAD_LINE} # every file\n"),
        [],
    ),
    "a # inside a word, which is not a comment": (
        in_job("artefacts", GH_VERSION, "          gh --version#log\n"),
        [(f'job "artefacts": {EXACT_LINES}', "it runs `gh --version#log`")],
    ),
    "a # right after ;": (
        in_job("ios", GH_VERSION, "          gh --version;# log\n"),
        [unreadable("ios", "provenance", "line 1 has a `#` right after `;`, where bash starts")],
    ),
    "a backslash at a line's end inside single quotes": (
        in_job("artefacts", GH_VERSION, "          echo 'a \\\n          set +e'\n" + GH_VERSION),
        [unreadable("artefacts", "provenance", "line 1 " + PAST_THE_LINE)],
    ),
    "a backslash at a line's end inside double quotes": (
        in_job("ios", GH_VERSION, '          echo "a \\\n          set +e"\n' + GH_VERSION),
        [unreadable("ios", "provenance", "line 1 " + PAST_THE_LINE)],
    ),
    "a quoted string over two lines in the upload step": (
        in_job(
            "artefacts",
            UPLOAD,
            "        run: |\n          " + UPLOAD_LINE[:-1] + '\n          "\n',
        ),
        [unreadable("artefacts", "upload", "line 1 " + PAST_THE_LINE)],
    ),
    "a here-document in the provenance step": (
        in_job(
            "artefacts",
            GH_VERSION,
            "          cat <<'X'\n          set +e\n          X\n" + GH_VERSION,
        ),
        [unreadable("artefacts", "provenance", "line 1 " + HERE_DOCUMENT)],
    ),
    "a here-document in the upload step": (
        in_job(
            "ios",
            UPLOAD,
            f"        run: |\n          {UPLOAD_LINE} <<'X'\n          a\n          X\n",
        ),
        [unreadable("ios", "upload", "line 1 " + HERE_DOCUMENT)],
    ),
    "a second upload step inside a here-document": (
        in_job(
            "artefacts",
            UPLOAD,
            UPLOAD + "      - run: |\n          bash <<'X'\n"
            '          gh release upload "$TAG" x\n          X\n',
        ),
        ['job "artefacts" runs `gh release upload` in 2 steps'],
    ),
    "a line that ends in two backslashes, then a command, in the upload step": (
        in_job(
            "ios", UPLOAD, f"        run: |\n          {UPLOAD_LINE} \\\\\n          date > late\n"
        ),
        ['job "ios": the upload step must run `gh release upload` alone'],
    ),
    "a carriage return at the end of the upload command": (
        in_job(
            "artefacts",
            UPLOAD,
            '        run: "' + UPLOAD_LINE.replace('"', '\\"') + '\\r"\n',
        ),
        [
            unreadable(
                "artefacts", "upload", "line 1 has U+000D (a control character), " + AS_A_WORD
            )
        ],
    ),
    "CRLF line endings in the provenance step (still passes)": (
        lambda t: once(t, provenance_step("ios"), provenance_step("ios").replace("\n", "\r\n")),
        [],
    ),
    "a lone carriage return between two lines (still passes)": (
        in_job("artefacts", GH_VERSION, GH_VERSION[:-1] + "\r"),
        [],
    ),
    "tabs between the upload command's words (still passes)": (
        in_job(
            "ios",
            UPLOAD,
            '        run: |\n          gh release upload\t"$TAG" dist/*\t--clobber --repo'
            ' "$GITHUB_REPOSITORY"\n',
        ),
        [],
    ),
    "a no-break space in the upload command": (
        in_job("artefacts", "run: gh release upload", "run: gh\u00a0release upload"),
        [unreadable("artefacts", "upload", "line 1 has U+00A0 (no-break space), " + AS_A_WORD)],
    ),
    "a line of no-break spaces in the provenance step": (
        in_job("ios", GH_VERSION, GH_VERSION + "          \u00a0\u00a0\n"),
        [unreadable("ios", "provenance", "line 2 has U+00A0 (no-break space), " + AS_A_WORD)],
    ),
    "a line of a zero-width space in the provenance step": (
        in_job("artefacts", GH_VERSION, GH_VERSION + "          \u200b\n"),
        [
            unreadable(
                "artefacts", "provenance", "line 2 has U+200B (zero width space), " + AS_A_WORD
            )
        ],
    ),
    "the provenance step's run as a folded scalar": (
        in_job("ios", "        run: |\n", "        run: >\n"),
        [
            'job "ios": the provenance step must run `cp -- "$BUNDLE" "$PROVENANCE"`',
            'job "ios": the provenance step must check every file',
        ],
    ),
    "the upload as a folded scalar over two lines (still passes)": (
        in_job(
            "artefacts",
            UPLOAD,
            '        run: >\n          gh release upload "$TAG" dist/*\n'
            '          --clobber --repo "$GITHUB_REPOSITORY"\n',
        ),
        [],
    ),
    "the upload as a plain scalar over two lines (still passes)": (
        in_job(
            "ios",
            UPLOAD,
            '        run: gh release upload "$TAG" dist/*\n'
            '          --clobber --repo "$GITHUB_REPOSITORY"\n',
        ),
        [],
    ),
    "an expression in the upload command": (
        in_job(
            "artefacts", ' --repo "$GITHUB_REPOSITORY"\n', ' --repo "${{ github.repository }}"\n'
        ),
        [unreadable("artefacts", "upload", "line 1 has a `${{ }}` expression, which Actions")],
    ),
    "a command substitution in the upload command": (
        in_job("ios", 'upload "$TAG"', 'upload "$(cat tag)"'),
        [unreadable("ios", "upload", "line 1 has `$(` (a command substitution")],
    ),
    # The provenance file's name, which `dist/*` must meet in the loop and the upload (C2 on #81).
    "a hidden provenance file": (
        in_job("artefacts", "PROVENANCE: dist/", "PROVENANCE: dist/."),
        [
            (
                'job "artefacts": PROVENANCE is \'dist/.maalik-e-makaan-',
                "a hidden file: `dist/*`, in the check's loop and in the upload, leaves out a name"
                " that starts with a dot, so the release would go out without its provenance file",
            )
        ],
    ),
    "a provenance file named by an expression first": (
        in_job("ios", "PROVENANCE: dist/maalik-e-makaan-", "PROVENANCE: dist/"),
        [('job "ios": PROVENANCE is', "a name that starts with an expression, which could expand")],
    ),
    "a space in the provenance file's name": (
        in_job("artefacts", "dist/maalik-e-makaan-", "dist/maalik e-makaan-"),
        [('job "artefacts": PROVENANCE is', "a name with ` `; use only letters, digits")],
    ),
    "a glob character in the provenance file's name": (
        in_job("ios", "-ios.intoto.jsonl", "-ios*.intoto.jsonl"),
        [('job "ios": PROVENANCE is', "a name with `*`;")],
    ),
    "a # and a quote in the provenance file's name": (
        in_job("artefacts", "}}.intoto.jsonl", "}}#'x.intoto.jsonl"),
        [('job "artefacts": PROVENANCE is', "a name with `#` `'`;", "start of the file's label")],
    ),
    "a slash after an expression in the provenance file's name": (
        in_job("ios", "}}-ios.intoto.jsonl", "}}/ios.intoto.jsonl"),
        [('job "ios": PROVENANCE is', "name a file directly in dist/")],
    ),
    "a literal # in an expression in the provenance file's name": (
        in_job("artefacts", "dist/maalik-e-makaan-${{", "dist/m${{ '#' }}-${{"),
        [
            (
                'job "artefacts": PROVENANCE is',
                "a name with the expression `${{ '#' }}`, which is not a plain context property",
            )
        ],
    ),
    "a literal space in an expression in the provenance file's name": (
        in_job("ios", "dist/maalik-e-makaan-${{", "dist/m${{ ' x' }}-${{"),
        [('job "ios": PROVENANCE is', "the expression `${{ ' x' }}`, which is not a plain")],
    ),
    "a function in an expression in the provenance file's name": (
        in_job(
            "artefacts",
            "${{ needs.release-please.outputs.tag }}.intoto",
            "${{ format('{0} x', needs.release-please.outputs.tag) }}.intoto",
        ),
        [('job "artefacts": PROVENANCE is', "which is not a plain context property")],
    ),
    # Variables that change what bash or gh runs in the provenance and upload steps (finding 3).
    "an exported gh function in the provenance step's env": (
        in_job(
            "artefacts",
            ".intoto.jsonl\n        run: |\n",
            ".intoto.jsonl\n          'BASH_FUNC_gh%%': '() { echo fake; }'\n        run: |\n",
        ),
        [
            'job "artefacts": the provenance step\'s env sets BASH_FUNC_gh%%; it may set only'
            " BUNDLE and PROVENANCE"
        ],
    ),
    "BASH_ENV in the provenance step's env": (
        in_job(
            "ios",
            "-ios.intoto.jsonl\n",
            "-ios.intoto.jsonl\n          BASH_ENV: ./tool/env.sh\n",
        ),
        ['job "ios": the provenance step\'s env sets BASH_ENV; it may set only BUNDLE and'],
    ),
    "BASH_ENV in the job's env": (
        in_job_header("ios", "    env:\n", "    env:\n      BASH_ENV: ./tool/env.sh\n"),
        ['job "ios" uploads release files, but job "ios" sets BASH_ENV in its env; such a'],
    ),
    "an exported gh function in the job's env": (
        in_job_header(
            "artefacts", "    env:\n", "    env:\n      BASH_FUNC_gh%%: '() { echo fake; }'\n"
        ),
        ['job "artefacts" uploads release files, but job "artefacts" sets BASH_FUNC_gh%% in'],
    ),
    "PATH in the job's env": (
        in_job_header("ios", "    env:\n", "    env:\n      PATH: ./bin:/usr/bin:/bin\n"),
        ['job "ios" uploads release files, but job "ios" sets PATH in its env'],
    ),
    "the job's env from an expression": (
        in_job_header(
            "artefacts",
            "    env:\n      TAG: ${{ needs.release-please.outputs.tag }}\n"
            "      VERSION: ${{ needs.release-please.outputs.version }}\n",
            "    env: ${{ fromJSON(vars.RELEASE_ENV) }}\n",
        ),
        ['job "artefacts" uploads release files, but job "artefacts" sets its env from an'],
    ),
    "variables merged into the job's env": (
        in_job_header("ios", "    env:\n", "    env:\n      <<: {BASH_ENV: ./tool/env.sh}\n"),
        ['job "ios" uploads release files, but job "ios" merges variables into its env with'],
    ),
    "BASH_ENV in the workflow's env": (
        lambda t: once(t, '  JAVA_VERSION: "21"\n', '  JAVA_VERSION: "21"\n  BASH_ENV: ./x.sh\n'),
        [
            'job "artefacts" uploads release files, but the workflow sets BASH_ENV in its env',
            'job "ios" uploads release files, but the workflow sets BASH_ENV in its env',
        ],
    ),
    # Steps that may be skipped or may fail.
    "if: false on the attest step": (
        in_job(
            "artefacts", "      - id: provenance\n", "      - id: provenance\n        if: false\n"
        ),
        [
            'job "artefacts": the attest, provenance and upload steps run always and must succeed,'
            " so none may have `if:`"
        ],
    ),
    "if: on the provenance step": (
        in_job(
            "ios",
            "        env:\n          BUNDLE:",
            "        if: github.event_name == 'push'\n        env:\n          BUNDLE:",
        ),
        ["`if:`"],
    ),
    "if: on the upload step": (
        in_job(
            "ios", UPLOAD, UPLOAD.replace("        run:", "        if: success()\n        run:")
        ),
        ["`if:`"],
    ),
    "continue-on-error on the provenance step": (
        in_job(
            "artefacts",
            "        env:\n          BUNDLE:",
            "        continue-on-error: true\n        env:\n          BUNDLE:",
        ),
        ["none may have `continue-on-error:`"],
    ),
    "continue-on-error on the attest step": (
        in_job(
            "ios",
            "        with:\n          subject-path",
            "        continue-on-error: true\n        with:\n          subject-path",
        ),
        ["none may have `continue-on-error:`"],
    ),
    "continue-on-error on the upload step": (
        in_job(
            "artefacts",
            UPLOAD,
            UPLOAD.replace("        run:", "        continue-on-error: true\n        run:"),
        ),
        ["none may have `continue-on-error:`"],
    ),
    "continue-on-error on the job": (
        lambda t: once(
            t,
            "    runs-on: macos-26\n",
            "    runs-on: macos-26\n    continue-on-error: true\n",
        ),
        ['job "ios" uploads release files, so it may not set continue-on-error'],
    ),
    # The shell, which must keep -e so that every file's verify counts.
    "shell: bash {0} on the provenance step": (
        in_job(
            "artefacts",
            "        env:\n          BUNDLE:",
            "        shell: bash {0}\n        env:\n          BUNDLE:",
        ),
        [
            'job "artefacts": the attest, provenance and upload steps run in the default `bash`'
            " (-e, pipefail), so none may have `shell:` (this one is 'bash {0}')"
        ],
    ),
    "shell: on the upload step": (
        in_job("ios", UPLOAD, UPLOAD.replace("        run:", "        shell: sh\n        run:")),
        ["so none may have `shell:` (this one is 'sh')"],
    ),
    "the workflow's default shell bash {0}": (
        lambda t: once(
            t, "defaults:\n  run:\n    shell: bash\n", "defaults:\n  run:\n    shell: bash {0}\n"
        ),
        [
            'job "artefacts" uploads release files, but the workflow sets'
            " `defaults.run.shell: bash {0}`",
            'job "ios" uploads release files, but the workflow sets `defaults.run.shell: bash {0}`',
        ],
    ),
    "a job's default shell bash {0}": (
        lambda t: once(
            t,
            "    runs-on: macos-26\n",
            "    runs-on: macos-26\n    defaults:\n      run:\n        shell: bash {0}\n",
        ),
        ['job "ios" uploads release files, but job "ios" sets `defaults.run.shell: bash {0}`'],
    ),
    "a job's default shell bash over the workflow's bash {0}": (
        lambda t: once(
            once(
                t,
                "defaults:\n  run:\n    shell: bash\n",
                "defaults:\n  run:\n    shell: bash {0}\n",
            ),
            "    runs-on: macos-26\n",
            "    runs-on: macos-26\n    defaults:\n      run:\n        shell: bash\n",
        ),
        ['job "artefacts" uploads release files, but the workflow sets'],
    ),
    "no default shell anywhere": (
        lambda t: once(t, "defaults:\n  run:\n    shell: bash\n\n", ""),
        [],
    ),
    # The working directory, which must stay the workspace root the attest step names dist/ from.
    "working-directory on the attest step": (
        in_job(
            "artefacts",
            "        with:\n          subject-path",
            "        working-directory: app\n        with:\n          subject-path",
        ),
        [
            'job "artefacts": the attest, provenance and upload steps work on dist/ in the'
            " workspace root, the files the attestation covers, so none may have"
            " `working-directory:` (this one is 'app')"
        ],
    ),
    "working-directory on the provenance step": (
        in_job(
            "ios",
            "        env:\n          BUNDLE:",
            "        working-directory: app\n        env:\n          BUNDLE:",
        ),
        ['job "ios": the attest, provenance and upload steps work on dist/ in the workspace root'],
    ),
    "working-directory on the upload step": (
        in_job(
            "artefacts",
            UPLOAD,
            UPLOAD.replace("        run:", "        working-directory: build\n        run:"),
        ),
        ["so none may have `working-directory:` (this one is 'build')"],
    ),
    "a job's default working directory": (
        lambda t: once(
            t,
            "    runs-on: macos-26\n",
            "    runs-on: macos-26\n    defaults:\n      run:\n        working-directory: app\n",
        ),
        [
            'job "ios" uploads release files, but job "ios" sets'
            " `defaults.run.working-directory: app`; the provenance and upload steps must work on"
            " dist/ in the workspace root"
        ],
    ),
    "the workflow's default working directory": (
        lambda t: once(
            t,
            "defaults:\n  run:\n    shell: bash\n",
            "defaults:\n  run:\n    shell: bash\n    working-directory: app\n",
        ),
        [
            'job "artefacts" uploads release files, but the workflow sets'
            " `defaults.run.working-directory: app`",
            'job "ios" uploads release files, but the workflow sets'
            " `defaults.run.working-directory: app`",
        ],
    ),
    # Pins and permissions.
    "the attest action unpinned": (
        in_job("artefacts", ATTEST_USES, "        uses: actions/attest-build-provenance@v4\n"),
        ['job "artefacts": pin actions/attest-build-provenance by its full 40-character'],
    ),
    "id-token: write removed": (
        lambda t: _drop_permission(t, "artefacts", "id-token"),
        ['job "artefacts" uploads release files, so it must grant `id-token: write`'],
    ),
    "attestations: write removed": (
        lambda t: _drop_permission(t, "ios", "attestations"),
        ['job "ios" uploads release files, so it must grant `attestations: write`'],
    ),
}


def _drop_permission(text: str, job: str, scope: str) -> str:
    """release.yml without `scope: write` in `job`'s permissions (the two jobs share the text)."""
    start = text.index(f"\n  {job}:\n")
    end = text.index("    steps:\n", start)
    block = text[start:end]
    line = next(
        line for line in block.splitlines(keepends=True) if line.startswith(f"      {scope}:")
    )
    return text[:start] + once(block, line, "") + text[end:]


class MutantTest(Fixture):
    def test_each_mutant_gives_exactly_its_problems(self):
        for name, (mutate, fragments) in MUTANTS.items():
            with self.subTest(mutant=name):
                mutated = mutate(RELEASE_TEXT)
                self.assertNotEqual(mutated, RELEASE_TEXT)
                self.assert_problems(self.release(mutated), *fragments)

    def test_a_problem_names_the_file_and_line(self):
        mutated = MUTANTS["--clobber dropped"][0](RELEASE_TEXT)
        (problem,) = self.problems(self.write(RELEASE, mutated))
        upload_line = mutated.count("\n", 0, mutated.rindex(UPLOAD.replace(" --clobber", ""))) + 1
        self.assertEqual((problem.path, problem.line), (RELEASE, upload_line))
        self.assertEqual(str(problem), f"{RELEASE}:{upload_line}: {problem.message}")

    def test_a_mutant_whose_text_is_gone_fails_loudly(self):
        with self.assertRaisesRegex(AssertionError, "occurs 0 times"):
            once(RELEASE_TEXT, "no such text", "")
        with self.assertRaisesRegex(AssertionError, "occurs 2 times"):
            once(RELEASE_TEXT, ATTEST, "")


UPLOADING_JOB = """\
name: Other
on: push
jobs:
  attach:
    runs-on: ubuntu-24.04
    permissions:
      contents: write
    steps:
      - run: echo build
      - run: mkdir dist && date > dist/file
      - run: gh release upload "$TAG" dist/* --clobber --repo "$GITHUB_REPOSITORY"
"""


class FixtureTest(Fixture):
    def test_a_new_job_in_another_workflow_that_uploads_without_attesting(self):
        self.write(RELEASE, RELEASE_TEXT)
        other = self.write(".github/workflows/other.yml", UPLOADING_JOB)
        found = [str(p) for p in self.problems(RELEASE, other)]
        self.assert_problems(
            found,
            '.github/workflows/other.yml:7: job "attach" uploads release files, so it must grant'
            " `attestations: write` and `id-token: write`",
            '.github/workflows/other.yml:9: job "attach": two steps before the upload',
            '.github/workflows/other.yml:10: job "attach": the step just before the upload',
        )

    def test_an_upload_with_a_single_step_before_it(self):
        text = UPLOADING_JOB.replace("      - run: echo build\n", "")
        text = text.replace("    permissions:\n      contents: write\n", "")
        found = [
            str(p) for p in self.problems(self.write(".github/workflows/x.yml", text), RELEASE)
        ]
        # release.yml is not written here, so it cannot be read.
        self.assert_problems(
            found,
            '.github/workflows/x.yml:4: job "attach" uploads release files, so it must grant',
            '.github/workflows/x.yml:8: job "attach" uploads to a release without the attest step',
            f"{RELEASE}:1: cannot read it",
        )

    def test_the_upload_step_s_keys_are_read_without_the_steps_before_it(self):
        # One step before the upload, so the attest and provenance steps are not read at all.
        text = UPLOADING_JOB.replace("      - run: echo build\n", "").replace(
            "      - run: gh release upload",
            "      - if: false\n        working-directory: build\n        run: gh release upload",
        )
        found = [str(p) for p in self.problems(self.write(".github/workflows/x.yml", text))]
        self.assert_problems(
            found,
            '.github/workflows/x.yml:7: job "attach" uploads release files, so it must grant',
            '.github/workflows/x.yml:10: job "attach": the attest, provenance and upload steps run'
            " always and must succeed, so none may have `if:`",
            '.github/workflows/x.yml:11: job "attach": the attest, provenance and upload steps work'
            " on dist/ in the workspace root",
            '.github/workflows/x.yml:10: job "attach" uploads to a release without the attest step',
        )

    def test_no_upload_anywhere(self):
        path = self.write(
            ".github/workflows/ci.yml", "on: push\njobs:\n  a:\n    steps:\n      - run: echo\n"
        )
        found = [str(p) for p in self.problems(path)]
        self.assert_problems(found, ".github/workflows:1: no job runs `gh release upload`")

    def test_an_unreadable_file(self):
        self.write(RELEASE, RELEASE_TEXT)
        bad = self.write(".github/workflows/bad.yml", "jobs: [\n")
        found = [str(p) for p in self.problems(RELEASE, bad)]
        self.assert_problems(found, ".github/workflows/bad.yml:1: cannot read it")

    def test_other_ways_of_uploading_are_refused(self):
        self.write(RELEASE, RELEASE_TEXT)
        steps = (
            "      - uses: softprops/action-gh-release@0123456789abcdef0123456789abcdef01234567\n",
            "      - run: gh release create v2 app.apk\n",
            '      - run: curl -X POST "https://uploads.github.com/repos/o/r/releases/1/assets"\n',
            # Text an action runs, in any of the step's values, not only in `run`.
            "      - uses: actions/github-script@0123456789abcdef0123456789abcdef01234567\n"
            "        with:\n"
            "          script: |\n"
            "            const r = context.repo;\n"
            "            await github.rest.repos.uploadReleaseAsset({...r, release_id: 1,"
            " name: 'x', data: 'y'});\n",
            "      - uses: actions/github-script@0123456789abcdef0123456789abcdef01234567\n"
            "        with:\n"
            "          script: await exec.exec('gh', ['release', 'upload', 'v2', 'app.apk'])\n",
            "      - uses: actions/github-script@0123456789abcdef0123456789abcdef01234567\n"
            "        with:\n"
            "          script: await exec.exec('gh release upload v2 app.apk')\n",
            "      - uses: some/python-action@0123456789abcdef0123456789abcdef01234567\n"
            "        with:\n"
            "          args: [release.upload_release_asset]\n",
            "      - uses: some/action@0123456789abcdef0123456789abcdef01234567\n"
            "        env:\n"
            "          URL: https://uploads.github.com/repos/o/r/releases/1/assets\n",
            # Taking files off a release, in a run and in an action's script.
            "      - run: gh release delete-asset v2 app.apk --yes\n",
            "      - run: command \"$GH\" release $'delete' v2 --yes\n",
            "      - run: curl -X DELETE https://api.github.com/repos/o/r/releases/assets/1\n",
            "      - uses: actions/github-script@0123456789abcdef0123456789abcdef01234567\n"
            "        with:\n"
            "          script: await github.rest.repos.deleteReleaseAsset(asset)\n",
            "      - uses: actions/github-script@0123456789abcdef0123456789abcdef01234567\n"
            "        with:\n"
            "          script: |\n"
            "            await github.request({method: 'DELETE',\n"
            "              url: '/repos/o/r/releases/assets/1'})\n",
            "      - uses: some/python-action@0123456789abcdef0123456789abcdef01234567\n"
            "        with:\n"
            "          script: release.get_assets()[0].delete_asset()\n",
            "      - uses: actions/github-script@0123456789abcdef0123456789abcdef01234567\n"
            "        with:\n"
            "          script: await exec.exec('gh', ['release', 'delete', 'v2', '--yes'])\n",
            # A gh alias or extension, which could upload under another name.
            "      - run: gh alias import aliases.yml\n",
            "      - run: ${GH:-gh} 'alias' set up 'release view'\n",
            "      - run: gh ext install someone/gh-attach\n",
            "      - run: gh extensions list\n",
            "      - uses: actions/github-script@0123456789abcdef0123456789abcdef01234567\n"
            "        with:\n"
            "          script: await exec.exec('gh', ['alias', 'set', 'up', 'release upload'])\n",
            # Flags gh skips before the subcommand, in an action's script and in an env value.
            "      - uses: actions/github-script@0123456789abcdef0123456789abcdef01234567\n"
            "        with:\n"
            "          script: await exec.exec('gh',"
            " ['release', '-R', repo, 'upload', 'v2', 'x'])\n",
            "      - uses: actions/github-script@0123456789abcdef0123456789abcdef01234567\n"
            "        with:\n"
            "          script: await exec.exec('gh --repo=o/r release"
            " --repo o/r delete-asset v2 x')\n",
            "      - uses: some/action@0123456789abcdef0123456789abcdef01234567\n"
            "        env:\n"
            '          COMMAND: gh release -R "o/r" create v2 x\n',
            "      - uses: some/action@0123456789abcdef0123456789abcdef01234567\n"
            "        env:\n"
            "          COMMAND: gh -R o/r extension install someone/gh-attach\n",
        )
        for step in steps:
            with self.subTest(step=step):
                path = self.write(
                    ".github/workflows/other.yml",
                    f"on: push\njobs:\n  a:\n    runs-on: ubuntu-24.04\n    steps:\n{step}",
                )
                found = [str(p) for p in self.problems(RELEASE, path)]
                self.assert_problems(
                    found, ".github/workflows/other.yml:6: this step puts files on a release"
                )

    def test_jobs_without_steps_and_unreadable_uploads(self):
        text = in_job("ios", UPLOAD, '        run: gh release upload "$TAG dist/* --clobber\n')(
            RELEASE_TEXT
        )
        found = self.release(text)
        self.assert_problems(
            found, unreadable("ios", "upload", "line 1 opens a quoted string that is never closed")
        )
        # A reusable workflow call (no steps) is not a job this check reads.
        call = "on: push\njobs:\n  a:\n    uses: $/.github/workflows/b.yml\n"
        self.write(RELEASE, RELEASE_TEXT)
        path = self.write(".github/workflows/call.yml", call)
        self.assertEqual(self.problems(RELEASE, path), [])


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
        self.write("tools/action.yml", UPLOADING_JOB)  # an action, not a workflow
        self.git("add", ".")
        code, out, err = self.run_main()
        self.assertEqual((code, err), (0, ""))
        self.assertIn("Release provenance checks passed (1 workflow file(s)).", out)
        # An untracked workflow is not read; a tracked one that uploads without attesting fails.
        self.write(".github/workflows/untracked.yml", UPLOADING_JOB)
        code, out, err = self.run_main()
        self.assertEqual((code, err), (0, ""))
        self.write(".github/workflows/tracked.yml", UPLOADING_JOB)
        self.git("add", ".github/workflows/tracked.yml")
        code, out, err = self.run_main()
        self.assertEqual((code, out), (1, ""))
        self.assertEqual(err.count("\n"), 3, err)
        self.assertNotIn("untracked.yml", err)


# Runs that commands() reads, with the commands it reads in them. BashTest checks that bash runs
# the same as it runs the commands read.
READ = (
    ("echo a \\\n  b\n", ["echo a   b"]),
    ("# c\necho a\n\n   # indented c\necho b\n", ["echo a", "echo b"]),
    ("echo a # c\necho b  #c\n", ["echo a", "echo b"]),
    ("echo a#b\n", ["echo a#b"]),
    ("echo a\\#b \\# # c\n", ["echo a\\#b \\#"]),
    ("echo 'a # b' \"c # d\" # e\n", ["echo 'a # b' \"c # d\""]),
    ("echo a \\\\\necho b\n", ["echo a \\\\", "echo b"]),
    ("echo a\\\n# b\n", ["echo a# b"]),
    ("echo a\tb\t# c\n", ["echo a\tb"]),
    ("echo 'a\\' \"b\\\"c\" 'd # e'\n", ["echo 'a\\' \"b\\\"c\" 'd # e'"]),
    ("echo a; echo b && echo c | cat\n", ["echo a; echo b && echo c | cat"]),
    ("echo a", ["echo a"]),
    ('echo "a$" "$\'b\'"\n', ['echo "a$" "$\'b\'"']),
)
# Runs that commands() refuses, with what it says.
REFUSED = (
    ("# c \\\necho a\n", "line 1 " + COMMENT_BACKSLASH),
    ("echo a\n# c \\\\\necho b\n", "line 2 " + COMMENT_BACKSLASH),
    ("echo a # c \\  \necho b\n", "line 1 " + COMMENT_BACKSLASH),
    ("echo a \\\n  # c \\\necho b\n", "line 2 " + COMMENT_BACKSLASH),
    ("echo a;#c\n", "line 1 has a `#` right after `;`"),
    ("echo a|#c\n", "line 1 has a `#` right after `|`"),
    ("echo a&&#c\n", "line 1 has a `#` right after `&`"),
    ("echo a >#c\n", "line 1 has a `#` right after `>`"),
    ("echo 'a\nb'\n", "line 1 " + PAST_THE_LINE),
    ("echo 'a \\\nb'\n", "line 1 " + PAST_THE_LINE),
    ('echo "a\nb"\n', "line 1 " + PAST_THE_LINE),
    ('echo a\necho "a \\\nb"\n', "line 2 " + PAST_THE_LINE),
    ("echo 'a", "line 1 opens a quoted string that is never closed"),
    ("cat <<X\na\nX\n", "line 1 " + HERE_DOCUMENT),
    ("cat <<<a\n", "line 1 " + HERE_DOCUMENT),
    ("echo $(date)\n", "line 1 has `$(` (a command substitution"),
    ('echo "$(date)"\n', "line 1 has `$(`"),
    ("echo `date`\n", "line 1 has `` ` ``"),
    ('echo "`date`"\n', "line 1 has `` ` ``"),
    ("echo ${HOME}\n", "line 1 has `${`"),
    ("echo $'a'\n", "line 1 has `$'`"),
    ('echo $"a"\n', 'line 1 has `$"`'),
    ("echo a\necho ${{ github.ref }}\n", "line 2 has a `${{ }}` expression"),
    ("echo 'a' \\", "line 1, the run's last, ends in a backslash"),
    ("echo a\r\necho b\n", "line 1 has U+000D (a control character), " + AS_A_WORD),
    ("echo a\u00a0b\n", "line 1 has U+00A0 (no-break space)"),
    ("echo a\n\u200b\n", "line 2 has U+200B (zero width space)"),
    ("echo a\x0bb\n", "line 1 has U+000B (a control character)"),
    ("echo a\u2028b\n", "line 1 has U+2028 (line separator)"),
    ("echo a\u3000b\n", "line 1 has U+3000 (ideographic space)"),
)


# Lines with the words bash runs in them, once their $-quoting is read. BashTest checks them.
WORDS = (
    ("gh release $'upload' x", ["gh", "release", "upload", "x"]),
    ('gh release $"upload" x', ["gh", "release", "upload", "x"]),
    ("gh release up$'load'", ["gh", "release", "upload"]),
    ("gh release $'\\x75pload'", ["gh", "release", "upload"]),
    ("gh release $'\\u0075pload'", ["gh", "release", "upload"]),
    ("gh release $'\\U00000075pload'", ["gh", "release", "upload"]),
    ("gh release $'\\165pload'", ["gh", "release", "upload"]),
    ("gh $'it\\'s' $'a\\\\b' $'\\\"'", ["gh", "it's", "a\\b", '"']),
    ("gh $'\\q' $'\\x' $'\\u' $'\\c' $'\\?'", ["gh", "\\q", "\\x", "\\u", "\\c", "?"]),
    ("gh $'\\cA\\e\\E\\a\\b\\f\\v'", ["gh", "\x01\x1b\x1b\x07\x08\x0c\x0b"]),
    ("gh 'release' \"upload\" re\\lease", ["gh", "release", "upload", "release"]),
)


class WordsTest(unittest.TestCase):
    def test_words_bash_runs(self):
        for line, expected in WORDS:
            with self.subTest(line=line):
                self.assertEqual(crp._words(line), expected)

    def test_a_word_with_white_space_is_read_again(self):
        self.assertEqual(crp._words("gh $'a\\tb'"), ["gh", "a", "b"])
        self.assertEqual(crp._words("gh $'\\n'"), ["gh"])
        self.assertEqual(
            crp._words("bash -c 'gh release $\"upload\" x'"),
            ["bash", "-c", "gh", "release", "upload", "x"],
        )
        # Two levels down, a word is left as it is.
        self.assertEqual(crp._words("a 'b \"c d\"'", depth=1), ["a", "b", "c d"])

    def test_a_line_shlex_cannot_read_is_split_at_its_white_space(self):
        self.assertEqual(crp._words("gh release 'upload x"), ["gh", "release", "'upload", "x"])

    def test_refused_lines(self):
        for line in (
            "gh release delete-asset v1 x",
            "gh alias list",
            "gh release ${x:-create} v1",
            "${x:-gh} alias set up 'release upload'",
            "gh ex$'t' install o/gh-x",
            "curl -X DELETE https://api.github.com/repos/o/r/releases/1",
            # Flags, and their values, before the subcommand (F1 on #81's second review).
            'gh release -R "$GITHUB_REPOSITORY" create v1',
            'gh release --repo "$GITHUB_REPOSITORY" delete v1 --yes',
            "gh release --repo=o/r delete-asset v1 x",
            '"$GH" release -R o/r --yes delete v1',
            "${x:-gh} alias --clobber set up 'release view'",
            '"$GH" ext --force install o/gh-x',
            '"$GH" extension --force install o/gh-x',
            # A flag's value that is itself a verb counts too (wider than gh, which runs view).
            "command gh release -R create view v1",
        ):
            with self.subTest(line=line):
                self.assertTrue(crp.refused_line(line))
        for line in (
            'gh release view --repo "$GITHUB_REPOSITORY" --json tagName',
            'gh api "repos/$GITHUB_REPOSITORY/releases/tags/$tag" --jq .assets',
            "gh attestation verify x --bundle y",
            "echo next steps",
            # Another subcommand first ends the search: `view`, `list`, `edit` and `download`
            # attach and delete nothing, whatever words come after them.
            "${x:-gh} release view create",
            '"$GH" release -R o/r view --json create',
            '"$GH" release --repo o/r list --limit 1 --exclude-drafts delete',
            '"$GH" release -R o/r edit v1 --draft=false --tag create',
            '"$GH" release download v1 -R o/r -p delete',
        ):
            with self.subTest(line=line):
                self.assertFalse(crp.refused_line(line))

    def test_the_subcommand_is_found_past_flags_as_gh_finds_it(self):
        upload = ("upload",)
        for words, expected in (
            (["upload"], True),
            (["-R", "o/r", "upload"], True),
            (["--repo=o/r", "upload"], True),
            (["--some-flag", "upload"], True),
            (["-R", "o/r", "--yes", "upload"], True),
            (["-R", "upload", "view"], True),
            (["view", "upload"], False),
            (["-R", "o/r", "view", "upload"], False),
            # Every flag may take a value, even one written with `=` (which gh reads as
            # holding its value): wider than gh, never narrower.
            (["--repo=o/r", "view", "upload"], True),
            (["-R"], False),
            ([], False),
        ):
            with self.subTest(words=words):
                self.assertEqual(crp._verb_after(words, upload), expected)
        self.assertTrue(
            crp._says('gh release -R "$GITHUB_REPOSITORY" upload "$TAG" x', crp.UPLOAD, "upload")
        )
        self.assertFalse(crp._says("gh release view -R o/r upload", crp.UPLOAD, "upload"))

    def test_the_text_patterns_skip_flags_as_gh_does(self):
        for pattern, text in (
            (crp.UPLOAD, 'gh release -R "$GITHUB_REPOSITORY" upload "$TAG" x'),
            (crp.UPLOAD, "gh --repo=o/r release --some-flag upload v1 x"),
            (crp.GH_RELEASE_TEXT, "exec.exec('gh', ['release', '-R', repo, 'upload', 'v1'])"),
            (crp.GH_RELEASE_TEXT, "exec.exec('gh', ['release', '--repo', 'o/r', 'delete'])"),
            (crp.GH_RELEASE_TEXT, "gh release -R 'o r' create v1"),
            (crp.GH_RELEASE_TEXT, "gh release -R upload view"),
            (crp.OTHER_UPLOAD, "gh release --repo o/r delete-asset v1 x"),
            (crp.GH_COMMANDS_TEXT, "gh -R o/r extension install o/gh-x"),
            (crp.GH_COMMANDS_TEXT, "exec.exec('gh', ['--repo', 'o/r', 'alias', 'set'])"),
        ):
            with self.subTest(text=text):
                self.assertIsNotNone(pattern.search(text))
        for pattern, text in (
            (crp.GH_RELEASE_TEXT, "gh release view upload"),
            (crp.GH_RELEASE_TEXT, "gh release -R o/r view upload"),
            (crp.GH_RELEASE_TEXT, "gh release download v1 -p delete"),
            (crp.GH_RELEASE_TEXT, "gh release edit v1 --tag create"),
            (
                crp.GH_RELEASE_TEXT,
                "uses: googleapis/release-please-action, gh release-please -x upload",
            ),
            (crp.OTHER_UPLOAD, "gh release list --limit 1"),
        ):
            with self.subTest(text=text):
                self.assertIsNone(pattern.search(text))

    def test_a_long_line_of_flags_is_read_quickly(self):
        # Each flag may or may not take a value; the patterns must not try every combination.
        text = "gh release " + "-a b " * 5000 + "view"
        for pattern in (crp.UPLOAD, crp.GH_RELEASE_TEXT, crp.OTHER_UPLOAD):
            self.assertIsNone(pattern.search(text))
        self.assertFalse(crp.refused_line(text))


class ProvenanceKeyTest(unittest.TestCase):
    def test_names_are_compared_as_github_reads_them(self):
        name = "dist/m-${{ needs.release-please.outputs.tag }}.intoto.jsonl"
        for same in (
            "dist/m-${{needs.release-please.outputs.tag}}.intoto.jsonl",
            "dist/m-${{\tneeds.release-please.outputs.tag  }}.intoto.jsonl",
            "dist/m-${{ Needs.Release-Please.Outputs.TAG }}.intoto.jsonl",
        ):
            with self.subTest(name=same):
                self.assertEqual(crp.provenance_key(same), crp.provenance_key(name))
        # The text outside the braces is kept as written.
        for other in (
            "dist/M-${{ needs.release-please.outputs.tag }}.intoto.jsonl",
            "dist/m-${{ needs.release-please.outputs.tag }}-ios.intoto.jsonl",
        ):
            with self.subTest(name=other):
                self.assertNotEqual(crp.provenance_key(other), crp.provenance_key(name))


class CommandsTest(unittest.TestCase):
    def test_runs_it_reads(self):
        for run, expected in READ:
            with self.subTest(run=run):
                self.assertEqual(crp.commands(run), expected)
                self.assertEqual(crp.command_lines(run), expected)

    def test_runs_it_refuses(self):
        for run, reason in REFUSED:
            with self.subTest(run=run):
                with self.assertRaises(crp.UnclearRunError) as raised:
                    crp.commands(run)
                self.assertTrue(str(raised.exception).startswith(reason), str(raised.exception))

    def test_a_refused_run_is_searched_line_by_line_for_an_upload(self):
        # Every line, comments included, as written and with continuations joined.
        run = "# c \\\ngh release \\\nupload x\n"
        self.assertEqual(
            crp.command_lines(run),
            ["# c \\", "gh release \\", "upload x", "# c gh release upload x"],
        )


BASH = shutil.which("bash")


@unittest.skipIf(BASH is None, "bash is not on PATH")
class BashTest(unittest.TestCase):
    """bash, given a run commands() reads, runs what it runs given the commands read."""

    def bash(self, script: str) -> str:
        with tempfile.TemporaryDirectory() as folder:
            done = subprocess.run(  # noqa: S603
                [BASH, "--noprofile", "--norc", "-e"],
                input=script,
                capture_output=True,
                text=True,
                cwd=folder,
                check=False,
            )
        return f"{done.returncode}\n{done.stdout}{done.stderr}"

    def test_bash_runs_what_the_check_reads(self):
        for run, expected in READ:
            with self.subTest(run=run):
                self.assertEqual(self.bash(run), self.bash("\n".join(expected) + "\n"))

    def test_bash_runs_the_line_after_a_comment_that_ends_in_a_backslash(self):
        # Why such a comment is refused (C1 on #81): bash does not continue it.
        self.assertEqual(self.bash("# note \\\necho ran\n"), "0\nran\n")
        self.assertEqual(self.bash("echo a # note \\\necho ran\n"), "0\na\nran\n")

    def test_bash_runs_the_words_the_check_reads(self):
        # Why $-quoting is read before the search for an upload (finding 1 on #81's
        # verification): bash runs `gh release upload` for each of these.
        shown = 'gh() { for word in gh "$@"; do printf \'<%s>\' "$word"; done; echo; }\n'
        for line, expected in WORDS:
            with self.subTest(line=line):
                self.assertEqual(
                    self.bash(shown + line + "\n"),
                    "0\n" + "".join(f"<{word}>" for word in expected) + "\n",
                )


class DocsTest(unittest.TestCase):
    """SECURITY.md tells people to check a download with the files and options the workflow
    attaches and checks with."""

    def test_security_md_names_the_files_and_options_the_workflow_uses(self):
        security = (ROOT / "SECURITY.md").read_text(encoding="utf-8")
        names = re.findall(r"^ {10}PROVENANCE: (dist/.+)$", RELEASE_TEXT, re.M)
        self.assertEqual(len(names), 2, names)
        for name in names:
            shown = name.removeprefix("dist/").replace(
                "${{ needs.release-please.outputs.tag }}", "vX.Y.Z"
            )
            self.assertIn(f"`{shown}`", security)
        self.assertIn("--bundle maalik-e-makaan-vX.Y.Z.intoto.jsonl", security)
        self.assertIn("--bundle maalik-e-makaan-vX.Y.Z-ios.intoto.jsonl", security)
        self.assertIn(f"--source-ref {crp.SOURCE_REF}\n", security)
        self.assertRegex(security, r"--signer-workflow \S+/\S+/\.github/workflows/release\.yml")
        self.assertIn("## Checking a download", security)


if __name__ == "__main__":
    unittest.main()
