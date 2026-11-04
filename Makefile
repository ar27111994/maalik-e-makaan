# Developer entry points. Every target is also what CI runs, so "it passes
# locally" means "it passes in CI". Run `make help` for the list.
SHELL := /usr/bin/env bash
.SHELLFLAGS := -euo pipefail -c
.DEFAULT_GOAL := help

FLUTTER ?= flutter
DART ?= dart
DENO ?= deno
PACKAGES := packages/mm_core packages/mm_ui app

.PHONY: help
help: ## Show this help
	@grep -E '^[a-zA-Z0-9_.-]+:.*?## ' $(MAKEFILE_LIST) | \
	  awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2}'

.PHONY: bootstrap
bootstrap: ## Install every toolchain dependency (pub, npm, deno cache)
	$(FLUTTER) pub get
	npm ci
	cd website && npm ci
	cd supabase/functions && $(DENO) install

.PHONY: codegen
codegen: ## Regenerate freezed/json_serializable code and localisations
	cd packages/mm_core && $(DART) run build_runner build --delete-conflicting-outputs
	cd app && $(DART) run build_runner build --delete-conflicting-outputs
	cd app && $(FLUTTER) gen-l10n

.PHONY: format
format: ## Format Dart, TypeScript and docs
	$(DART) format $(PACKAGES)
	cd supabase/functions && $(DENO) fmt
	npx --no-install prettier --write "**/*.{md,yml,yaml,json,jsonc}"

.PHONY: format-check
format-check: ## Verify formatting without writing
	$(DART) format --output=none --set-exit-if-changed $(PACKAGES)
	cd supabase/functions && $(DENO) fmt --check
	npx --no-install prettier --check "**/*.{md,yml,yaml,json,jsonc}"

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
