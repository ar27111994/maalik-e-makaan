## What and why

<!-- What changes, and the problem it solves. Link the issue (Fixes #123). -->

## How it was checked

<!-- Commands you ran (make test, make test-db, …) and what you looked at by hand. -->

## Checklist

- [ ] The title follows Conventional Commits (`feat(app): …`, `fix(db): …`); it becomes the squash commit.
- [ ] Tests cover the change, including edge cases and failure paths; coverage gates still pass.
- [ ] Database changes come as a new migration with pgTAP tests, and concurrency scenarios where rows are shared.
- [ ] User-facing text is in both English and Urdu, and screens work right to left, at 200% text and with a screen reader.
- [ ] No secrets, personal data or real tenant details in code, tests, logs or screenshots.
- [ ] Documentation (README, docs/, DESIGN.md, formal/) matches the change.
