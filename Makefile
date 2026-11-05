# Developer entry points. Every target is also what CI runs, so "it passes
# locally" means "it passes in CI". Run `make help` for the list.
SHELL := /usr/bin/env bash
.SHELLFLAGS := -euo pipefail -c
.DEFAULT_GOAL := help

FLUTTER ?= flutter
DART ?= dart
DENO ?= deno
PACKAGES := packages/mm_core packages/mm_ui app
# Pinned Python formatters and linters (tool/requirements-lint.txt) live in
# .venv after `make bootstrap`; CI installs the same pins on the runner.
VENV := $(CURDIR)/.venv
export PATH := $(VENV)/bin:$(PATH)
PYTHON_SOURCES := $(wildcard tool formal)
SHELL_SOURCES = $(shell git ls-files '*.sh')

.PHONY: help
help: ## Show this help
	@grep -E '^[a-zA-Z0-9_.-]+:.*?## ' $(MAKEFILE_LIST) | \
	  awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2}'

.PHONY: bootstrap
bootstrap: ## Install every toolchain dependency (pub, npm, deno cache, Python tools)
	python3 -m venv $(VENV)
	$(VENV)/bin/python -m pip install --quiet --require-hashes \
	  -r tool/requirements.txt -r tool/requirements-lint.txt
	$(FLUTTER) pub get
	npm ci
	cd website && npm ci
	cd supabase/functions && $(DENO) install

.PHONY: codegen
codegen: ## Regenerate the app's localisations from its ARB files
	cd app && $(FLUTTER) gen-l10n

.PHONY: format
format: ## Format Dart, TypeScript, Python, shell and docs
	$(DART) format $(PACKAGES)
	cd supabase/functions && $(DENO) fmt
	black --quiet $(PYTHON_SOURCES)
	ruff check --quiet --fix $(PYTHON_SOURCES)
	shfmt --write $(SHELL_SOURCES)
	npx --no-install prettier --write "**/*.{md,yml,yaml,json,jsonc}"

.PHONY: format-check
format-check: ## Verify formatting without writing
	$(DART) format --output=none --set-exit-if-changed $(PACKAGES)
	cd supabase/functions && $(DENO) fmt --check
	$(MAKE) --no-print-directory format-check-repo

.PHONY: format-check-repo
format-check-repo: ## Formatting of Python, shell and docs (no Flutter or Deno needed)
	black --check --quiet $(PYTHON_SOURCES)
	shfmt --diff $(SHELL_SOURCES)
	npx --no-install prettier --check "**/*.{md,yml,yaml,json,jsonc}"

.PHONY: lint
lint: ## Lint Python, shell, workflows, migrations, docs and plain text
	ruff check $(PYTHON_SOURCES)
	shellcheck $(SHELL_SOURCES)
	actionlint
	tool/db/lint_migrations.sh
	ec
	npx --no-install markdownlint-cli2 "**/*.md"
	python3 tool/check_unicode.py
	$(MAKE) --no-print-directory design-lint

.PHONY: design-lint
design-lint: ## UI code takes colours, type, spacing, radii and motion from tokens, and is RTL-safe
	python3 tool/design/lint_hardcoded.py

.PHONY: analyze
analyze: ## Static analysis for every package
	cd packages/mm_core && $(DART) analyze --fatal-infos
	cd packages/mm_ui && $(FLUTTER) analyze --fatal-infos
	cd app && $(FLUTTER) analyze --fatal-infos
	cd supabase/functions && $(DENO) lint && $(DENO) task check
	python3 tool/check_unicode.py

.PHONY: test-core
test-core: ## mm_core unit tests with the 100% line-coverage gate
	cd packages/mm_core && $(DART) test --coverage=coverage && \
	  $(DART) run coverage:format_coverage --lcov --in=coverage \
	    --out=coverage/lcov.info --report-on=lib --check-ignore
	python3 tool/coverage/check.py packages/mm_core/coverage/lcov.info --min 100

.PHONY: test-ui
test-ui: ## mm_ui widget, golden and accessibility tests with coverage gate
	cd packages/mm_ui && $(FLUTTER) test --coverage
	python3 tool/coverage/check.py packages/mm_ui/coverage/lcov.info --min 95

.PHONY: test-app
test-app: ## App unit/widget/golden tests with coverage gate
	cd app && $(FLUTTER) test --coverage
	python3 tool/coverage/check.py app/coverage/lcov.info --min 90

.PHONY: goldens
goldens: ## Re-record golden images (review the diff before committing!)
	cd packages/mm_ui && $(FLUTTER) test --update-goldens --tags golden
	cd app && $(FLUTTER) test --update-goldens --tags golden

.PHONY: test-integration
test-integration: ## Flutter integration tests on the Linux desktop target (needs xvfb)
	cd app && xvfb-run -a $(FLUTTER) test integration_test -d linux

.PHONY: test-db
test-db: ## Migrations + pgTAP suite on a local Postgres (see tool/db/test.sh)
	tool/db/test.sh

.PHONY: test-db-concurrency
test-db-concurrency: ## Parallel payments, retries and billing races keep the ledger invariants
	tool/db/concurrency_test.sh

.PHONY: test-db-stress
test-db-stress: ## Report latency budgets, index usage and pgbench throughput (STRESS_SECONDS=10)
	tool/db/stress_test.sh

.PHONY: contracts
contracts: ## Regenerate the rent-maths contract vectors shared by Dart and SQL
	python3 tool/contracts/generate.py

.PHONY: contracts-check
contracts-check: ## Fail when the committed contract vectors are stale
	python3 tool/contracts/generate.py --check

.PHONY: test-functions
test-functions: ## Edge Function tests with the 100% coverage gate
	cd supabase/functions && $(DENO) task test
	python3 tool/coverage/check.py supabase/functions/coverage/lcov.info \
	  --min 100 --min-branches 100 --min-functions 100

.PHONY: test-functions-e2e
test-functions-e2e: ## Edge Functions against a running local stack (supabase start)
	set -a && eval "$$(supabase status -o env \
	    --override-name api.url=SUPABASE_URL \
	    --override-name auth.publishable_key=SUPABASE_PUBLISHABLE_KEY \
	    --override-name auth.secret_key=SUPABASE_SECRET_KEY)" && set +a && \
	  cd supabase/functions && $(DENO) task test:e2e

.PHONY: test-web
test-web: ## Website build, e2e, accessibility and SEO checks
	cd website && npm run check && npm run build && npm run test:e2e

.PHONY: test-tools
test-tools: ## Unit tests of the repository tooling (coverage gate, text guard, tokens)
	python3 -m unittest discover -s tool -p 'test_*.py'
	python3 -m unittest discover -s tool/coverage -p 'test_*.py'
	python3 -m unittest discover -s tool/design -p 'test_*.py'

.PHONY: tokens
tokens: ## Rebuild the design-token outputs (Dart, CSS, DESIGN.md frontmatter)
	python3 tool/design/build_tokens.py

.PHONY: tokens-check
tokens-check: ## Fail when the design tokens are invalid or their outputs are stale
	python3 tool/design/build_tokens.py --check

.PHONY: icons
icons: ## Rebuild the MmIcons font subset and constants (needs npm ci)
	python3 tool/design/build_icons.py

.PHONY: icons-check
icons-check: ## Fail when the icon font or MmIcons are out of date with design/icons/icons.json
	python3 tool/design/build_icons.py --check

.PHONY: test
test: test-tools test-core test-ui test-app test-db test-functions ## Run every fast test suite

.PHONY: build-web-app
build-web-app: ## Release build of the Flutter web app
	cd app && $(FLUTTER) build web --release --no-web-resources-cdn \
	  --dart-define-from-file=config/production.json

.PHONY: build-apk
build-apk: ## Release Android APKs split per ABI
	cd app && $(FLUTTER) build apk --release --split-per-abi \
	  --dart-define-from-file=config/production.json

.PHONY: clean
clean: ## Remove build outputs and caches
	cd app && $(FLUTTER) clean
	rm -rf packages/*/coverage app/coverage website/dist website/.astro
