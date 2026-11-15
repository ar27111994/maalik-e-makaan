#!/usr/bin/env python3
"""Check that every job that uploads files to a GitHub release attaches their provenance.

OpenSSF Scorecard's Signed-Releases check (v5.6.0) looks only at the names of the files on each
of the five newest releases: a name ending in `.intoto.jsonl` scores the release 10, a signature
(`.asc`, `.minisig`, `.sig`, `.sign`, `.sigstore`, `.sigstore.json`) 8, neither 0. The
attestations GitHub keeps for a workflow's builds count for nothing until a file is attached.
release.yml therefore attests `dist/*`, copies the attestation's Sigstore bundle into `dist/` as
a `.intoto.jsonl` file, checks it with `gh attestation verify --bundle` against every file it
covers (every build file in `dist/`, all but the provenance file itself), and only then uploads
`dist/*`, the provenance file included (docs/operations.md, Release provenance; SECURITY.md,
Checking a download). This check keeps that so, for every tracked workflow in
.github/workflows. It reads the runs of the provenance and upload steps as bash does
(`commands`: a backslash at a line's end joins the next line, a comment runs from a `#` that
starts a word to the end of its line and is dropped, and runs of spaces and tabs read as one
space), and refuses what it could read otherwise than bash: a comment that ends in a backslash
(bash never continues a comment, so the line after it runs), a `#` right after an operator, a
quoted string that goes on past its line, a here-document, a command substitution, parameter
expansion or $-quoted string, a `${{ }}` expression, and any character but a space, a tab and a
line feed that Python reads as white space, a line end or nothing (a carriage return, a no-break
or zero-width space). In each job that runs `gh release upload`:

- there is exactly one such step, and its run, read so, is exactly `UPLOAD_RUN`, the one command
  release.yml has: `dist/*` and no other path, with `--clobber`, to `"$TAG"` in
  `"$GITHUB_REPOSITORY"`, with nothing before, after or around it (no `cd`, `;`, `&&`, pipe or
  variable set for the command); its `env` sets only `GH_TOKEN`;
- the two steps just before it are, back to back, the attest step (`uses:
  actions/attest-build-provenance@<40-hex commit>`, with an `id` and `subject-path: dist/*`)
  and the provenance step, so no step can add an unattested file to `dist/` in between;
- the provenance step's `env` sets only `BUNDLE` and `PROVENANCE` (another variable, such as
  `BASH_FUNC_gh%%` or `BASH_ENV`, could make bash run a `gh` that passes every file), `BUNDLE`
  is the attest step's `bundle-path` output, `PROVENANCE` a file directly in `dist/` whose name
  ends in `.intoto.jsonl` and starts with a letter or a digit, with only letters, digits, `.`,
  `_`, `-` and plain context properties (`${{ needs.<job>.outputs.<name> }}`, no literal,
  function or operator) after it (`dist/*` leaves out a name that starts with a dot, or an
  expression that could become one, and gh and GitHub read other characters in their own way),
  and its run
  copies the one to the other (`cp -- "$BUNDLE" "$PROVENANCE"`) and loops over `dist/*`,
  skipping the provenance file (the bundle the others are checked against) and running
  `gh attestation verify "$file" --bundle "$PROVENANCE"` with `--signer-workflow` naming this
  workflow file and `--source-ref refs/heads/main`, the options SECURITY.md tells people to use.
  Read so, the run is exactly the six lines
  release.yml has (`RUN_LINES`), so nothing in it can stop the loop early, skip a file, or
  swallow a failure (`||`, `!`, `set +e`, `exit 0`, `break`);
- none of the three steps has an `if:`, `continue-on-error`, `shell:` or `working-directory:`,
  the job has no `continue-on-error`, neither the job nor the workflow sets
  `defaults.run.working-directory` (each would move `dist/` away from the files the attest step
  covers, which it names from the workspace root), and the job's and the workflow's
  `defaults.run.shell`, where set, is
  `bash`: the runner runs that as `bash --noprofile --norc -e -o pipefail {0}`, and a step without
  a shell as `bash -e {0}`, so a failed verify ends the step; a custom shell such as `bash {0}`
  drops `-e`, and then only the last file's verify would count;
- neither the job's nor the workflow's `env` sets a variable that changes what bash or gh
  runs (`SHELL_ENV`: `BASH_ENV`, `PATH`, `IFS`, `LD_PRELOAD` and others, and any
  `BASH_FUNC_*`), merges variables in with `<<`, or comes from an expression;
- the job grants `attestations: write` and `id-token: write`.

No two jobs may name the same provenance file, as GitHub reads the names (`provenance_key`: white
space inside `${{ }}` dropped and the expression case-folded), since the two `--clobber` uploads
would replace each other's; no job may upload release files another way (`gh release create`, an
upload to uploads.github.com or by the client libraries' `uploadReleaseAsset` and
`upload_release_asset`, or a release-upload action), take them off a release (`gh release delete` or
`delete-asset`, a `DELETE` on a release URL, the client libraries' `deleteRelease`,
`deleteReleaseAsset`, `delete_release` and `delete_asset`), or define a gh alias or extension (`gh
alias`, `gh extension`), which could upload under another name. It looks for these in every value of
every step, so also in an `actions/github-script` step's `with.script`, along with `gh release
upload` there; in a run, it looks once the run's quoting is read (`_words`: `gh release $'upload'`,
`gh release ${x:-upload}` and the words of a quoted `bash -c` or `eval` string count). Both readings
find the subcommand as gh does (`_verb_after`, `_gh_text`): flags, and a value after a flag, are
skipped first, so `gh release -R "$GITHUB_REPOSITORY" upload` and `gh release --repo=x delete`
count; since only gh knows which flags take a value, a word after a flag counts as the subcommand
too (`gh release -R upload view` counts as an upload, which is wider than gh). `gh release view`,
`list`, `download` and `edit` (which can retarget or rename a release, or make it a draft, but
attaches and deletes nothing) are left alone. At least one job must upload, so that a renamed upload
command cannot pass this check by matching nothing.

Limits. It reads the workflow's structure, the text of these three steps' commands and the text of
every step's values; it does not run the shell or any script, and it reads only the workflow files,
as PyYAML parses them: YAML folds a `run: >` and a plain scalar over several lines into one, and
reads a CR or a CRLF in the file as a line feed. GitHub's parser is not PyYAML; where the two
differ, this check sees PyYAML's value. Where it cannot read some other step's run as bash does, it
looks for an upload in every line of it, comments included. It cannot know a context property's
value, so one in the provenance file's name could still hold a `/`, a `#` or a space. An upload made
by a script or program a step runs (`./attach.sh`, `node attach.js`, a built binary), by an action
not named here, by a gh alias or extension already configured on the runner or read from a
configuration directory in the repository (`GH_CONFIG_DIR`), or through text built at run time
(`$(printf upload)`, a shell variable or function) is not seen; nor is a variable an earlier step
writes to `$GITHUB_ENV` (a `GH_REPO` or `TAG` that sends the upload elsewhere, a `BASH_ENV` or
`BASH_FUNC_*` for every later step). A reviewer reads those paths by hand (docs/operations.md,
Release provenance, What the check cannot see). It checks the action as named here: a move to
`actions/attest` (which the wrapper's README recommends for new work) must update this check in the
same change, keeping build provenance (no predicate inputs). Scorecard's extension lists are as of
v5.6.0; the docs name that version.

    python3 tool/github/check_release_provenance.py [repository root]
"""

from __future__ import annotations

import re
import shlex
import sys
import unicodedata
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
# How gh (cobra) finds a subcommand in text that is not read as words (an action's script, an
# env value, or a run as plain text): it skips flags, and the value after a flag, before it takes
# the next word as the subcommand (`gh release -R o/r upload`, `gh --repo=o/r release upload`).
# Each flag may take a value or not, so both readings are tried: a word after a flag is the
# subcommand when it is one, and its value otherwise. GAP is what lies between two words: the
# closing quote of one, spaces, tabs, line ends, commas or `[(`, and the opening quote of the
# next (`'release', '-R', 'x', 'upload'`). A flag needs a gap before it, so `release-please`
# holds no flag.
_GAP = r"""['"]?[\s,\[(]*['"]?"""
_GAP_BEFORE = r"""['"]?[\s,\[(]+['"]?"""
_FLAG = r"""-[^\s,'"\])]*"""
_VALUE = r"""(?:'[^'\n]*'|"[^"\n]*"|[^\s,'"\[\]()-][^\s,'"\])]*)"""
_FLAGS = rf"(?:{_GAP_BEFORE}{_FLAG}(?:{_GAP_BEFORE}{_VALUE})?)*"


def _gh_text(*commands: str) -> re.Pattern[str]:
    """`gh`, then each of `commands` in turn (each a regex of the words gh may read there), with
    the flags gh skips before each, read as text."""
    return re.compile(r"\bgh\b" + "".join(rf"{_FLAGS}{_GAP}(?:{c})\b" for c in commands))


UPLOAD = _gh_text("release", "upload")
# The upload step's run, once read as RUN_LINES are: dist/* alone, to this release of this
# repository, replacing a file of the same name.
UPLOAD_RUN = 'gh release upload "$TAG" dist/* --clobber --repo "$GITHUB_REPOSITORY"'
# The only variable the upload step's own env may set: a step-level TAG or GH_REPO would send
# the files elsewhere.
UPLOAD_ENV = ("GH_TOKEN",)
# The only variables the provenance step's own env may set: any other could change what bash or
# gh does there (`BASH_FUNC_gh%%` defines a `gh` function that passes every file, `BASH_ENV` a
# file bash reads first).
PROVENANCE_ENV = ("BUNDLE", "PROVENANCE")
# Variables the job's and the workflow's env may not set, since they reach the provenance and
# upload steps: each can make bash or gh run something other than the commands this check reads.
SHELL_ENV = (
    "BASH_ENV",
    "ENV",
    "SHELLOPTS",
    "BASHOPTS",
    "GLOBIGNORE",
    "PATH",
    "IFS",
    "CDPATH",
    "LD_PRELOAD",
    "LD_LIBRARY_PATH",
    "DYLD_INSERT_LIBRARIES",
    "DYLD_LIBRARY_PATH",
)
# An exported bash function, which bash defines from the environment before the run starts.
SHELL_FUNCTION_ENV = "BASH_FUNC_"
# A YAML merge key, whose variables PyYAML's node tree does not spell out.
MERGE_KEY = "<<"
# Keys none of the attest, provenance and upload steps may have.
STEP_KEYS = ("if", "continue-on-error", "shell", "working-directory")
SOURCE_REF = "refs/heads/main"
# Other ways of putting files on a release or taking them off it, refused so that the check
# cannot be sidestepped: looked for in every value of every step (a `run`, an action's
# `with.script`, an `env`). `gh release create`, `delete` and `delete-asset`; the REST upload by
# its URL and by the names Octokit (`uploadReleaseAsset`) and PyGithub (`upload_release_asset`)
# give it; the deletes by Octokit's and PyGithub's names; and a `DELETE` on a release URL.
OTHER_UPLOAD = re.compile(
    _gh_text("release", "create|delete").pattern + r"|uploads\.github\.com|\buploadReleaseAsset\b"
    r"|\bupload_release_asset\b|\bdeleteRelease(?:Asset)?\b|\bdelete_(?:release|asset)\b"
    r"|(?s:\bDELETE\b.*\breleases/|\breleases/.*\bDELETE\b)"
)
# `gh release upload`, `create` or `delete` outside a `run`, where it is not read as a command:
# in an action's script, also as separate quoted words
# (`exec.exec('gh', ['release', '-R', repo, 'upload'])`).
GH_RELEASE_TEXT = _gh_text("release", "upload|create|delete")
# `gh alias` and `gh extension` (or `ext`, `extensions`): an alias (`gh alias set attach 'release
# upload'`) or an installed extension can run an upload under another name. Refused in every
# value of every step, as text and as separate quoted words.
GH_COMMANDS_TEXT = _gh_text("alias|ext|extensions?")
# Pairs of words that a run may not hold once its quoting is read (`_words`): a word holding the
# first text, then, as gh finds its subcommand (`_verb_after`), one holding one of the second.
# They need no `gh` before them, so that `"$GH" release create` and `${x:-gh} alias set` count too.
REFUSED_PAIRS = (
    ("release", ("create", "delete")),
    ("alias", ("set", "import")),
    ("ext", ("install",)),
)
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
# A `${{ }}` expression in a workflow value, which Actions replaces before the step runs.
EXPRESSION = re.compile(r"\$\{\{.*?\}\}")
# The only expression the provenance file's name may hold: a context property, such as
# `${{ needs.release-please.outputs.tag }}`, with no literal, function, index or operator.
CONTEXT_PROPERTY = re.compile(
    r"\$\{\{\s*(?:needs|steps|github|env|vars|inputs|matrix)(?:\.[A-Za-z_][A-Za-z0-9_-]*)+\s*\}\}"
)
# The one shell a workflow or a job may set as its default for these steps.
SHELL = "bash"


# Unquoted characters that end a word, besides spaces and tabs: after one, a `#` starts a comment.
OPERATORS = ";&|()<>"
# Inside double quotes or unquoted: what this check does not read the way bash does, because
# what it encloses can nest quotes, span lines or hold comments of its own.
UNREAD = ("$(", "${", "`")
UNREAD_UNQUOTED = (*UNREAD, "$'", '$"')


class UnclearRunError(ValueError):
    """Text in a run that this check could read otherwise than bash does, so it refuses it."""


def _unclear_character(run: str) -> str | None:
    """A character bash reads as part of a word that Python reads as white space, a line end or
    nothing at all (a carriage return, a no-break space, a zero-width space)."""
    for number, line in enumerate(run.split("\n"), start=1):
        for char in line:
            if char in " \t":
                continue
            if char.isspace() or unicodedata.category(char) in ("Cc", "Cf", "Zs", "Zl", "Zp"):
                name = unicodedata.name(char, "a control character").lower()
                return (
                    f"line {number} has U+{ord(char):04X} ({name}), which bash reads as part of a"
                    " word: only spaces and tabs separate its words, and only a line feed ends"
                    " its lines"
                )
    return None


def commands(run: str) -> list[str]:
    """The run's commands, one per logical line, as bash reads them: a backslash at the end of
    a line joins the next one to it, a comment (a `#` that starts a word, to the end of its line)
    is dropped, and so is a blank line. Raises `UnclearRunError` for text where bash's reading
    and a simpler one could differ, none of which the release steps need: a comment that ends in
    a backslash (bash never continues a comment), a `#` right after an operator, a quoted string
    that goes on past its line, a here-document, a command substitution, a parameter expansion
    or a $-quoted string, a `${{ }}` expression, and a character bash reads as part of a word
    that Python reads as white space, a line end or nothing (anything but a space, a tab or a
    line feed that is white space, a control or a format character)."""
    if (problem := _unclear_character(run)) is not None:
        raise UnclearRunError(problem)
    if "${{" in run:
        number = run[: run.index("${{")].count("\n") + 1
        raise UnclearRunError(
            f"line {number} has a `${{{{ }}}}` expression, which Actions replaces with its value"
            " (any text, a line break or a `#` included) before bash reads the run"
        )
    lines: list[str] = []
    line: list[str] = []
    quote = ""
    # What came before: "start" of a line, a "blank", an "operator", or a "word" character.
    before = "start"
    number = 1
    i = 0
    while i < len(run):
        char = run[i]
        rest = run[i : i + 2]
        if char == "\n" and quote:
            raise UnclearRunError(
                f"line {number} opens a quoted string that goes on past the line's end"
            )
        if quote == "'":
            line.append(char)
            quote = "" if char == "'" else quote
            i += 1
            continue
        if any(rest.startswith(text) for text in (UNREAD if quote else UNREAD_UNQUOTED)):
            text = next(t for t in UNREAD_UNQUOTED if rest.startswith(t))
            shown = "`` ` ``" if text == "`" else f"`{text}`"
            raise UnclearRunError(
                f"line {number} has {shown} (a command substitution, a parameter expansion or a"
                " $-quoted string), which this check does not read"
            )
        if char == "\\":
            following = run[i + 1 : i + 2]
            if following == "\n" and quote:
                raise UnclearRunError(
                    f"line {number} opens a quoted string that goes on past the line's end"
                )
            if following == "\n":
                number += 1
                i += 2
                continue
            if not following:
                raise UnclearRunError(f"line {number}, the run's last, ends in a backslash")
            line.append(rest)
            before = "word"
            i += 2
            continue
        if quote == '"':
            line.append(char)
            quote = "" if char == '"' else quote
            i += 1
            continue
        if char == "\n":
            lines.append("".join(line).strip(" \t"))
            line, before, number = [], "start", number + 1
        elif char == "#" and before != "word":
            if before == "operator":
                raise UnclearRunError(
                    f"line {number} has a `#` right after `{line[-1]}`, where bash starts a"
                    " comment: put a space before the `#`, or quote it"
                )
            end = run.find("\n", i)
            end = len(run) if end < 0 else end
            if run[i:end].rstrip(" \t").endswith("\\"):
                raise UnclearRunError(
                    f"line {number} is a comment that ends in a backslash; bash ends a comment at"
                    " the end of its line and runs the next line, which reads as part of the"
                    " comment: drop the backslash"
                )
            i = end
            continue
        elif rest == "<<":
            raise UnclearRunError(
                f"line {number} has `<<`, a here-document or here-string, whose lines bash reads"
                " as text, not as commands"
            )
        else:
            line.append(char)
            if char in "'\"":
                quote, before = char, "word"
            elif char in " \t":
                before = "blank"
            elif char in OPERATORS:
                before = "operator"
            else:
                before = "word"
        i += 1
    if quote:
        raise UnclearRunError(f"line {number} opens a quoted string that is never closed")
    lines.append("".join(line).strip(" \t"))
    return [text for text in lines if text]


def command_lines(run: str) -> list[str]:
    """What to look for an upload in: `commands(run)`, or, where the check cannot read the run as
    bash does, every line of it, comments included, as written and with continuations joined,
    so that nothing bash could run is missed."""
    try:
        return commands(run)
    except UnclearRunError:
        return run.splitlines() + re.sub(r"\\\n", "", run).splitlines()


def strings(node: yaml.Node | None) -> list[tuple[yaml.ScalarNode, str]]:
    """Every scalar value under `node` (mapping keys left out), with its text."""
    if isinstance(node, yaml.ScalarNode):
        return [(node, node.value)]
    if isinstance(node, yaml.SequenceNode):
        return [found for item in node.value for found in strings(item)]
    if isinstance(node, yaml.MappingNode):
        return [found for _, value in node.value for found in strings(value)]
    return []


def run_of(step: yaml.Node) -> str | None:
    return scalar(get(step, "run"))


def uses_of(step: yaml.Node) -> str:
    return (scalar(get(step, "uses")) or "").strip()


# bash's escapes in a $'...' string (ANSI-C quoting), as bash 5 decodes them.
ANSI_C_ESCAPE = re.compile(
    r"\\(x[0-9A-Fa-f]{1,2}|u[0-9A-Fa-f]{1,4}|U[0-9A-Fa-f]{1,8}|[0-7]{1,3}|c.|.)", re.S
)
ANSI_C_LETTERS = {
    "a": "\a",
    "b": "\b",
    "e": "\x1b",
    "E": "\x1b",
    "f": "\f",
    "n": "\n",
    "r": "\r",
    "t": "\t",
    "v": "\v",
    "\\": "\\",
    "'": "'",
    '"': '"',
    "?": "?",
}


def _ansi_c(match: re.Match[str]) -> str:
    """One escape of a $'...' string, decoded as bash decodes it."""
    escape = match[1]
    if escape[0] in "xuU" and len(escape) > 1:
        return chr(min(int(escape[1:], 16), 0x10FFFF))
    if escape[0] in "01234567":
        return chr(int(escape, 8) & 0xFF)
    if escape[0] == "c" and len(escape) == 2:
        return chr(ord(escape[1]) & 0x1F)
    return ANSI_C_LETTERS.get(escape, "\\" + escape)


def _plain_quotes(line: str) -> str:
    """`line` with each $'...' string turned into a single-quoted one holding what bash decodes
    it to, and each `$"` into `"`, so that `shlex` reads the words bash runs. It does not tell
    whether the string is itself inside double quotes, where bash keeps it as written: reading
    more words than bash does only makes the search for a command wider."""

    def single(match: re.Match[str]) -> str:
        return "'" + ANSI_C_ESCAPE.sub(_ansi_c, match[1]).replace("'", "'\\''") + "'"

    return re.sub(r"""\$'((?:[^'\\]|\\.)*)'""", single, line, flags=re.S).replace('$"', '"')


def _words(line: str, depth: int = 2) -> list[str]:
    """The words of `line` once its shell quoting is read ($'...' and $"..." included), and the
    words of any word that holds white space, read again (`bash -c 'gh release upload'`,
    `alias up='gh release upload'`, `eval "gh release $'upload'"`), to `depth` levels. A line
    `shlex` cannot read is split at its white space."""
    text = _plain_quotes(line)
    try:
        words = shlex.split(text)
    except ValueError:
        words = text.split()
    found: list[str] = []
    for word in words:
        if depth and re.search(r"\s", word):
            found += _words(word, depth - 1)
        else:
            found.append(word)
    return found


def _verb_after(words: list[str], verbs: tuple[str, ...]) -> bool:
    """Whether gh, given `words` after a command such as `release`, could run one of `verbs`.
    gh (cobra) skips flags, and the value after a flag, before it takes the next word as the
    subcommand, and which flags take a value it alone knows: so a flag (a word that starts with
    `-`) is skipped, the word after it is the subcommand if it holds a verb and is skipped as the
    flag's value if not, and the first other word is the subcommand, which ends the search
    (`gh release view upload` runs `view`). Reading a flag's value as the subcommand too makes
    the search wider than gh's (`gh release -R upload view` runs `view`, yet counts as an upload),
    never narrower."""
    after_flag = False
    for word in words:
        if any(verb in word for verb in verbs):
            return True
        if word.startswith("-"):
            after_flag = True
        elif after_flag:
            after_flag = False
        else:
            return False
    return False


def _holds_pair(line: str, first: str, seconds: tuple[str, ...]) -> bool:
    """Whether a word of `line` that holds `first` is followed, as gh finds its subcommand
    (`_verb_after`), by one that holds any of `seconds`, once its quoting is read:
    `gh 'release' upload`, `gh release $'\\x75pload'`, `gh release ${x:-upload}` and
    `gh release -R "$GITHUB_REPOSITORY" upload` all hold `release` and then `upload`."""
    words = _words(line)
    return any(
        first in word and _verb_after(words[i + 1 :], seconds) for i, word in enumerate(words)
    )


def _says(line: str, pattern: re.Pattern[str], verb: str) -> bool:
    """Whether `line` runs `gh release <verb>`: as plain text, or once its shell quoting is read
    (so `gh 'release' upload`, `"gh" release upload` and `gh release $'upload'` count too)."""
    return pattern.search(line) is not None or _holds_pair(line, "release", (verb,))


def is_upload(step: yaml.Node) -> bool:
    run = run_of(step)
    return run is not None and any(_says(line, UPLOAD, "upload") for line in command_lines(run))


def refused_line(line: str) -> bool:
    """Whether a line of some step's run puts files on a release another way, takes them off it,
    or defines a gh alias or extension (which could upload under another name)."""
    return (
        OTHER_UPLOAD.search(line) is not None
        or GH_COMMANDS_TEXT.search(line) is not None
        or any(_holds_pair(line, first, seconds) for first, seconds in REFUSED_PAIRS)
    )


def refused_text(text: str) -> bool:
    """The same, for a step's other values (an action's script, an `env` value), read as text."""
    return any(
        pattern.search(text) is not None
        for pattern in (OTHER_UPLOAD, GH_RELEASE_TEXT, GH_COMMANDS_TEXT)
    )


class Checker:
    def __init__(self, root: Path) -> None:
        self.root = root

    def problems(self, files: list[str]) -> list[Problem]:
        found: list[Problem] = []
        provenance_names: dict[str, tuple[str, str, int]] = {}
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
                job_problems += self.check_env(path, job_name.value, document, job)
                found += job_problems
                if name is not None:
                    text, line = name
                    key = provenance_key(text)
                    if key in provenance_names:
                        other_text, other_path, other_line = provenance_names[key]
                        same = (
                            ""
                            if other_text == text
                            else f" ({other_text}, the same file once GitHub reads its"
                            " expressions)"
                        )
                        found.append(
                            Problem(
                                path,
                                line,
                                f'job "{job_name.value}" names the provenance file {text}, as'
                                f" {other_path}:{other_line} does{same}; the two uploads would"
                                " replace each other's file: give each job its own name",
                            )
                        )
                    else:
                        provenance_names[key] = (text, path, line)
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
            run = get(step, "run")
            others = [text for node, text in strings(step) if node is not run]
            if (
                uses in UPLOAD_ACTIONS
                or any(refused_line(line) for line in command_lines(scalar(run) or ""))
                or any(refused_text(text) for text in others)
            ):
                found.append(
                    Problem(
                        path,
                        line_of(step),
                        "this step puts files on a release without the provenance check, takes"
                        " them off it, or defines a gh alias or extension that could: attach"
                        " release files with one `gh release upload` step after the attest and"
                        " provenance steps, and delete none (tool/github/check_release_provenance.py)",
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
        found += self.check_step_keys(path, name, upload)
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
        for step in (attest, provenance):
            found += self.check_step_keys(path, name, step)
        return found, provenance_name

    def check_step_keys(self, path: str, name: str, step: yaml.Node) -> list[Problem]:
        """The keys none of the attest, provenance and upload steps may have."""
        found = []
        for key in STEP_KEYS:
            value = get(step, key)
            if value is None:
                continue
            if key == "shell":
                why = (
                    f"run in the default `{SHELL}` (-e, pipefail), so none may have `shell:`"
                    f" (this one is {scalar(value)!r})"
                )
            elif key == "working-directory":
                why = (
                    "work on dist/ in the workspace root, the files the attestation covers, so"
                    f" none may have `working-directory:` (this one is {scalar(value)!r})"
                )
            else:
                why = f"run always and must succeed, so none may have `{key}:`"
            found.append(
                Problem(
                    path,
                    line_of(value),
                    f'job "{name}": the attest, provenance and upload steps {why}',
                )
            )
        return found

    def check_shell(
        self, path: str, name: str, document: yaml.Node, job: yaml.Node
    ) -> list[Problem]:
        """The defaults the job's run steps take: the job's `defaults.run`, or else the
        workflow's (the job's overrides the workflow's, key by key). The shell, where set, must
        be bash; the working directory may not be set at all."""
        found = []
        for owner, node in ((f'job "{name}"', job), ("the workflow", document)):
            directory = get(get(get(node, "defaults"), "run"), "working-directory")
            if directory is not None:
                found.append(
                    Problem(
                        path,
                        line_of(directory),
                        f'job "{name}" uploads release files, but {owner} sets'
                        f" `defaults.run.working-directory: {scalar(directory)}`; the provenance"
                        " and upload steps must work on dist/ in the workspace root, the files"
                        " the attest step covers",
                    )
                )
        for owner, node in ((f'job "{name}"', job), ("the workflow", document)):
            shell = get(get(get(node, "defaults"), "run"), "shell")
            if shell is None:
                continue
            if scalar(shell) != SHELL:
                found.append(
                    Problem(
                        path,
                        line_of(shell),
                        f'job "{name}" uploads release files, but {owner} sets'
                        f" `defaults.run.shell: {scalar(shell)}`; set `{SHELL}` (the runner"
                        " adds -e and pipefail) or nothing, so a failed verify ends the"
                        " provenance step",
                    )
                )
            break
        return found

    def check_env(self, path: str, name: str, document: yaml.Node, job: yaml.Node) -> list[Problem]:
        """The job's and the workflow's env, which every step of the job takes: a mapping, with
        none of the variables that change what bash or gh runs (`SHELL_ENV`, `BASH_FUNC_*`)."""
        found = []
        for owner, node in ((f'job "{name}"', job), ("the workflow", document)):
            env = get(node, "env")
            if env is not None and not isinstance(env, yaml.MappingNode):
                found.append(
                    Problem(
                        path,
                        line_of(env),
                        f'job "{name}" uploads release files, but {owner} sets its env from an'
                        " expression, which could set a variable that changes what the"
                        " provenance and upload steps run: write each variable out",
                    )
                )
            for key, _ in items(env):
                if (
                    key.value in SHELL_ENV
                    or key.value.startswith(SHELL_FUNCTION_ENV)
                    or key.value == MERGE_KEY
                ):
                    what = (
                        "merges variables into its env with `<<`, which this check does not read"
                        if key.value == MERGE_KEY
                        else f"sets {key.value} in its env"
                    )
                    found.append(
                        Problem(
                            path,
                            line_of(key),
                            f'job "{name}" uploads release files, but {owner} {what}; such a'
                            " variable could make bash or gh in the provenance and upload steps"
                            " run something other than their commands",
                        )
                    )
        return found

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
        where = line_of(get(upload, "run"))
        try:
            lines = commands(run)
        except UnclearRunError as unclear:
            return [_unreadable(path, where, name, "upload", unclear)]
        if len(lines) != 1:
            return [
                Problem(
                    path,
                    where,
                    f'job "{name}": the upload step must run `gh release upload` alone, so that'
                    " nothing it runs can add a file to dist/ after the provenance check",
                )
            ]
        # commands() has refused a quote left open and a trailing backslash, so this reads.
        words = shlex.split(lines[0])
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
        actual = re.sub(r"\s+", " ", lines[0])
        if not found and actual != UPLOAD_RUN:
            found.append(
                Problem(
                    path,
                    where,
                    f'job "{name}": the upload step\'s run must be exactly `{UPLOAD_RUN}`, so that'
                    " it attaches the files of dist/ and nothing else, to this release, with"
                    f" nothing run before, after or around it; it runs `{actual}`",
                )
            )
        env = get(upload, "env")
        if env is not None and not isinstance(env, yaml.MappingNode):
            found.append(
                Problem(
                    path,
                    line_of(env),
                    f'job "{name}": the upload step\'s env must be a mapping that sets only '
                    + ", ".join(UPLOAD_ENV),
                )
            )
        for key, _ in items(env):
            if key.value not in UPLOAD_ENV:
                found.append(
                    Problem(
                        path,
                        line_of(key),
                        f'job "{name}": the upload step\'s env sets {key.value}; it may set only '
                        + ", ".join(UPLOAD_ENV)
                        + " (the tag and the repository come from the job and the runner)",
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
        # env is a mapping here, since it sets BUNDLE and PROVENANCE.
        for key, _ in items(env):
            if key.value not in PROVENANCE_ENV:
                found.append(
                    Problem(
                        path,
                        line_of(key),
                        f'job "{name}": the provenance step\'s env sets {key.value}; it may set'
                        " only " + " and ".join(PROVENANCE_ENV) + ", since another variable"
                        " could change what bash or gh runs there (`BASH_FUNC_gh%%`, `BASH_ENV`)",
                    )
                )
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
        if (why := provenance_name_problem(text)) is not None:
            found.append(
                Problem(path, line_of(provenance), f'job "{name}": PROVENANCE is {text!r}; {why}')
            )
        found += self.check_provenance_run(path, name, step)
        return found, (text, line_of(provenance))

    def check_provenance_run(self, path: str, name: str, step: yaml.Node) -> list[Problem]:
        run = run_of(step) or ""
        where = line_of(get(step, "run"))
        try:
            lines = commands(run)
        except UnclearRunError as unclear:
            return [_unreadable(path, where, name, "provenance", unclear)]
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


def _unreadable(path: str, where: int, name: str, step: str, unclear: UnclearRunError) -> Problem:
    return Problem(
        path,
        where,
        f'job "{name}": the {step} step\'s run cannot be read as bash reads it: {unclear}',
    )


def provenance_key(text: str) -> str:
    """A provenance file's name as GitHub reads it, to tell whether two jobs name the same file:
    in each `${{ }}` expression, white space dropped and the text case-folded (GitHub ignores
    the white space inside the braces, and context and property names are not case-sensitive),
    the text outside left as written. An expression that is not a plain context property (a
    literal, whose white space and case count) is refused by `provenance_name_problem` on its
    own; reading it so here can only find more names alike, never fewer."""
    return EXPRESSION.sub(lambda match: re.sub(r"\s+", "", match[0]).casefold(), text)


def provenance_name_problem(text: str) -> str | None:
    """Why `text` is not a name the provenance step may give its file, or None if it is."""
    file = text[len("dist/") :]
    if not text.startswith("dist/") or "/" in file or not text.endswith(".intoto.jsonl"):
        return (
            "name a file directly in dist/ ending in .intoto.jsonl, the name Scorecard counts and"
            " gh reads as JSON Lines"
        )
    if file.startswith("."):
        return (
            "a hidden file: `dist/*`, in the check's loop and in the upload, leaves out a name"
            " that starts with a dot, so the release would go out without its provenance file;"
            " start the name with a letter or a digit"
        )
    if file.startswith("${{"):
        return (
            "a name that starts with an expression, which could expand to a dot or to nothing"
            " (`.intoto.jsonl`, a hidden file that `dist/*` leaves out): start the name with a"
            " letter or a digit"
        )
    for expression in EXPRESSION.findall(file):
        if not CONTEXT_PROPERTY.fullmatch(expression):
            return (
                f"a name with the expression `{expression}`, which is not a plain context"
                " property such as `${{ needs.<job>.outputs.<name> }}`: a literal, a function"
                " or an operator in it can put a `#`, a space or a dot first into the name, and"
                " the check would not see it"
            )
    others = sorted(set(re.sub(r"[A-Za-z0-9._-]", "", re.sub(EXPRESSION, "", file))))
    if others:
        return (
            "a name with " + " ".join(f"`{char}`" for char in others) + "; use only letters,"
            " digits, `.`, `_` and `-`, and `${{ }}` expressions after the first character: gh"
            " reads a `#` as the start of the file's label, and GitHub renames a file whose name"
            " has other characters, so the release would not carry the name SECURITY.md gives"
        )
    return None


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
