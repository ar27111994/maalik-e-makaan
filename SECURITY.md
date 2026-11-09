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

## How the project defends itself

- Every table is behind row-level security, and every write goes through
  checked functions; pgTAP suites and concurrency tests run in CI.
- Secret keys never reach the app; the app refuses to start with one.
- Edge Functions authenticate every caller, rate-limit, validate input and
  compare tokens in constant time.
- CI runs CodeQL, secret scanning over the full history, OSV dependency
  scanning, dependency review, workflow auditing (zizmor) and OpenSSF
  Scorecard. Actions are pinned to commit hashes.
- Concurrency and money logic are formally checked (`formal/`), and the website's money
  calculators have property-based tests (fast-check).

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
