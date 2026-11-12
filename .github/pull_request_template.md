## What and why

<!-- What changes, and the problem it solves. Link the issue (Fixes #123). -->

## How it was checked

<!-- Commands you ran (make format-check analyze lint, make test, make test-db, …) and what you looked at by hand. -->

## Checklist

- [ ] The title follows Conventional Commits with a scope from `commitlint.config.mjs` (`feat(app): …`, `fix(db): …`); it becomes the squash commit.
- [ ] `make format-check analyze lint` and the tests for the touched areas pass; coverage gates still pass.
- [ ] Tests cover the change, including edge cases and failure paths.
- [ ] Database changes come as a new migration with pgTAP tests, keep the lock order (account, portfolio, lease, other rows), and add concurrency scenarios where rows are shared.
- [ ] Money stays whole paisa in integers; rent maths shared with SQL updates `contracts/` (`make contracts`).
- [ ] User-facing text is in both English and Urdu, and screens work right to left, at 200% text and with a screen reader.
- [ ] Changed goldens were re-recorded on Linux (`make goldens`) and every changed image was reviewed; they are listed below.
- [ ] No secrets, personal data or real tenant details in code, tests, logs or screenshots.
- [ ] A new, removed or upgraded direct dependency, font or icon set is recorded in `THIRD_PARTY_NOTICES.md`.
- [ ] Documentation (README, `docs/`, `AGENTS.md`, `DESIGN.md`, `formal/`) matches the change, and `make docs-check` passes (`make docs` rewrites the generated facts).
