.PHONY: lint test

# Run from the repo root: make -f config/Makefile lint

lint:
	@if command -v shellcheck >/dev/null 2>&1; then \
		find . -name '*.sh' -not -path './.git/*' -exec shellcheck --shell=sh {} +; \
		shellcheck --shell=sh dots; \
	else \
		echo "shellcheck not found; skipping lint" >&2; \
		exit 1; \
	fi

test:
	@if command -v bats >/dev/null 2>&1; then \
		bats tests/; \
	else \
		echo "bats not installed; skipping unit tests" >&2; \
	fi
