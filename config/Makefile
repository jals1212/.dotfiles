.PHONY: lint test

# Run from the repo root: make -f config/Makefile lint test
# CI (.github/workflows/ci.yml) runs these same two targets.

# Own shell only: vendor/ is third-party submodules, top-level dot-directories are tool
# state, and the palette fragments are sourced snippets with no shebang (so
# shellcheck cannot tell their dialect). src/install and dots have no .sh
# extension and are listed explicitly.
lint:
	@if ! command -v shellcheck >/dev/null 2>&1; then \
		echo "shellcheck not installed: install it to run lint (macOS: brew install shellcheck, Debian/Ubuntu: apt-get install shellcheck)" >&2; \
		exit 1; \
	fi
	@find . \( -path ./vendor -o -path ./content/assets/palettes -o -path './.?*' \) -prune -o \
		-type f -name '*.sh' -exec shellcheck --severity=warning dots src/install {} +

test:
	@if ! command -v bats >/dev/null 2>&1; then \
		echo "bats not installed: install it to run tests (macOS: brew install bats-core, Debian/Ubuntu: apt-get install bats)" >&2; \
		exit 1; \
	fi
	@bats tests/
