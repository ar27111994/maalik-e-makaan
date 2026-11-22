# Security policy

Maalik-e-Makaan holds landlords' and tenants' personal and financial details:
names, CNICs, phone numbers, rent, payments and documents. We take reports
seriously and fix confirmed issues before anything else.

## Reporting a vulnerability

Please report privately through
[GitHub security advisories](https://github.com/ar27111994/maalik-e-makaan/security/advisories/new).
Do not open a public issue, pull request or discussion.

Include what you found, how to reproduce it, and what an attacker could do with
it. Use your own test accounts and data only.

What to expect:

- an acknowledgement within 3 working days;
- an assessment, with severity, within 10 working days;
- a fix or a mitigation plan, and credit in the advisory if you would like it.

## Supported versions

Only the latest release, and `main`, receive security fixes.

## Scope

In scope:

- the Android, iOS and web app (`app/`, `packages/`);
- the database: row-level security, functions and storage policies
  (`supabase/migrations/`);
- the Edge Functions (`supabase/functions/`);
- the website and the CI/CD workflows (`.github/`).

Out of scope: denial of service by volume, social engineering, physical
attacks, and findings in third-party services (Supabase, Vercel, Resend) that
we cannot fix. Report those to the vendor.

## Safe harbour

We will not pursue action against research that respects this policy: it
avoids privacy violations, data destruction and service disruption, uses only
accounts you own, and gives us reasonable time to fix before disclosure.

## Checking a download

From v1.4.0 on, each release carries, beside its files, the build provenance that GitHub
recorded for them when the Release workflow built them:

- `maalik-e-makaan-vX.Y.Z.intoto.jsonl` covers the app bundle, the three APKs, the web zip, the
  debug symbols and `SHA256SUMS`;
- `maalik-e-makaan-vX.Y.Z-ios.intoto.jsonl` covers the unsigned iOS app and `SHA256SUMS-ios`.

Each file is a Sigstore bundle in JSON Lines form (one bundle per line). The bundle signs an
in-toto statement with SLSA provenance v1: it names each file by its SHA-256 and the workflow,
commit and git ref that built it. The signature uses a short-lived certificate issued to the
Release workflow, `.github/workflows/release.yml`, running on `main`, from Sigstore's
public-good instance (used because the repository is public), and the signing is recorded in
Sigstore's public transparency log. A job of its own, on a fresh GitHub-hosted runner that runs
none of the build's tools, attests the files the build handed over, checks each against the
provenance as below, and only then attaches them.

Check it with GitHub's command-line tool, `gh`, version 2.102.0 or later. `--source-ref` came
with 2.68.0, but until 2.102.0 `gh` compared the branch name without regard to case, so a build
from a branch named `Main` would pass as `main`. The `.intoto.jsonl` name is the one OpenSSF
Scorecard counts, but the file is
not output of slsa-github-generator, so `slsa-verifier` does not apply: its
`verify-github-attestation` command accepts only a few named builders, and this workflow is not
one of them.

**With the attached file, no GitHub account needed.** Download the provenance file with the file
you want to check, and run, with the release's version for `vX.Y.Z`:

```sh
gh attestation verify maalik-e-makaan-vX.Y.Z-arm64-v8a.apk \
  --bundle maalik-e-makaan-vX.Y.Z.intoto.jsonl \
  --repo ar27111994/maalik-e-makaan \
  --signer-workflow ar27111994/maalik-e-makaan/.github/workflows/release.yml \
  --source-ref refs/heads/main \
  --deny-self-hosted-runners
```

`--deny-self-hosted-runners` refuses provenance made on a self-hosted runner, as the signing
certificate records, and every release from v1.4.0 on passes it.

This shows that the file was built by this repository's Release workflow from `main`. It does
not show which release it was built for: a file from an older release, with that release's
provenance file, passes under any name. To check the release as well, add `--source-digest` and
the full id of the commit that the tag `vX.Y.Z` points to (on the release's page, the commit
link beside the tag opens it).

For the iPhone file or `SHA256SUMS-ios`, use `--bundle maalik-e-makaan-vX.Y.Z-ios.intoto.jsonl`.
With `--bundle`, `gh` needs no sign-in, but it still fetches Sigstore's trusted root over the
network. To check with no network at all, save that root first with
`gh attestation trusted-root > trusted_root.jsonl`, and add
`--custom-trusted-root trusted_root.jsonl`. As `gh` warns, with `--bundle` the `--repo` value is
compared only with the repository and owner names recorded in the certificate when it was made.

**Online, with a GitHub account.** Leave out `--bundle`, and `gh` fetches the provenance from
GitHub's attestation store, which also confirms that it belongs to the repository that has the
name today. This form needs `gh` signed in (`gh auth login`, with any GitHub account) or a token
in `GH_TOKEN`, even though the repository is public. It also works for v1.0.0 to v1.3.1, which
have no provenance file attached: their builds attested every file they attached except
`SHA256SUMS-ios`, so that one file cannot be checked this way.

**Without `gh`: the checksums.** These show that a file arrived whole and matches the release's
list of SHA-256 sums. They do not show who built it, since the list comes from the same place as
the file. To check one file, in the folder that holds it and `SHA256SUMS` (or `SHA256SUMS-ios`
for the iPhone file):

- Linux: `grep -- ' maalik-e-makaan-vX.Y.Z-arm64-v8a.apk$' SHA256SUMS | sha256sum -c`
- macOS: `grep -- ' maalik-e-makaan-vX.Y.Z-arm64-v8a.apk$' SHA256SUMS | shasum -a 256 -c`
- Windows (PowerShell): `(Get-FileHash maalik-e-makaan-vX.Y.Z-arm64-v8a.apk -Algorithm SHA256).Hash`,
  then compare it with the first word of the line in `SHA256SUMS` that ends with that file's
  name (Windows prints capital letters, the list small ones; they are the same sum).

The Linux and macOS commands print `OK` for a good file. Checking all of `SHA256SUMS` at once
reports every file in it that you did not download as missing, so check the files you have one
by one.

## How the project defends itself

- Every table is behind row-level security, and every write goes through
  checked functions; pgTAP suites and concurrency tests run in CI.
- Secret keys never reach the app; the app refuses to start with one.
- Edge Functions authenticate every caller, rate-limit, validate input and
  compare tokens in constant time.
- CI runs CodeQL, secret scanning over the full history, OSV dependency
  scanning, dependency review, workflow auditing (zizmor, which fails a pull
  request on any finding that has no inline ignore) and OpenSSF Scorecard.
  Actions are pinned to commit hashes.
- Concurrency and money logic are formally checked (`formal/`), and the website's money
  calculators have property-based tests (fast-check).
- Each release's files are built by jobs that hold only a read-only token and no OIDC token; a
  separate job for each build, on a fresh runner, takes the files by their artifact id, attests
  them, checks each against the provenance file and attaches them; a check in `make lint` holds
  those jobs to a fixed shape and keeps every other job from writing to a release or signing as
  the Release workflow (`docs/operations.md`, Release provenance). A change to the check itself
  is read in review.

Common classes of error, and what stops each one:

- **Broken access control:** row-level security on every table, tested role by role
  (`supabase/tests/database/03_rls_matrix.test.sql`); the app's role checks only shape the
  screens.
- **SQL injection:** the app reaches the database only through PostgREST and RPC calls with
  bound parameters, and every database function pins its `search_path`.
- **Cross-site scripting:** a strict Content-Security-Policy with no inline scripts on the web
  app and the website, and Trusted Types on the website.
- **Leaked secrets:** clients take only the publishable key, and gitleaks scans every commit.
- **Lost or double-counted money:** whole paisa in integers, idempotent payments, gapless
  receipts, and financial rows that are voided, never deleted.

Findings of medium severity or higher from CodeQL, zizmor or the dependency scanners are fixed
before other work, or dismissed with a written reason. A release that fixes a published
advisory names its GHSA and CVE identifiers in its release notes.
