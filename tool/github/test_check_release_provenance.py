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
import textwrap
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


def provenance_step(job: str) -> str:
    """The provenance step of `job`, as release.yml has it, from its name to its `done`."""
    name = "      - name: Provenance file, checked against every file it covers\n"
    start = RELEASE_TEXT.index(BEFORE[job] + ATTEST + name) + len(BEFORE[job] + ATTEST)
    end = RELEASE_TEXT.index("          done\n", start) + len("          done\n")
    return RELEASE_TEXT[start:end]


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

    def assert_problems(self, found: list[str], *fragments: str) -> None:
        self.assertEqual(len(found), len(fragments), found)
        for problem, fragment in zip(found, fragments, strict=True):
            self.assertIn(fragment, problem)


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
        ['job "ios": the provenance step must run, on a line that is not a comment'],
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
      - run: gh release upload v1 dist/* --clobber
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
            found, 'job "ios": cannot read the upload command (No closing quotation)'
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


class CommandsTest(unittest.TestCase):
    def test_commands_join_continuations_and_drop_comments(self):
        run = textwrap.dedent("""\
            # a comment
            gh attestation verify a \\
              --bundle b

              # indented comment
            done
            """)
        self.assertEqual(crp.commands(run), ["gh attestation verify a    --bundle b", "done"])


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
