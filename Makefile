.PHONY: lint test e2e clean

# All .sh files excluding tmp/ and openspec/ (generated/vendored dirs)
SH_FILES := $(shell find . -name '*.sh' \
	-not -path './tmp/*' \
	-not -path './openspec/*' \
	-not -path './.git/*')

# ---------------------------------------------------------------------------
# lint — shellcheck all POSIX sh files
# ---------------------------------------------------------------------------
lint:
	@if command -v shellcheck >/dev/null 2>&1; then \
		find . -name '*.sh' \
			-not -path './tmp/*' \
			-not -path './openspec/*' \
			-not -path './.git/*' \
			-exec shellcheck --shell=sh {} +; \
		shellcheck --shell=sh dots; \
	else \
		echo "shellcheck not found; skipping lint" >&2; \
		exit 1; \
	fi

# ---------------------------------------------------------------------------
# test — bats-core unit tests (optional; skipped when bats is absent)
# ---------------------------------------------------------------------------
test:
	@if command -v bats >/dev/null 2>&1; then \
		bats tests/; \
	else \
		echo "bats not installed; skipping unit tests" >&2; \
	fi

# ---------------------------------------------------------------------------
# e2e — Docker smoke tests (Debian, Fedora, Arch)
# Section 8 will add the actual e2e scripts; targets listed here for make tab.
# ---------------------------------------------------------------------------
e2e:
	@for d in debian fedora arch; do \
		sh installer/e2e/e2e_$$d.sh || exit 1; \
	done

# ---------------------------------------------------------------------------
# clean — remove generated / ephemeral artifacts
# ---------------------------------------------------------------------------
clean:
	rm -rf .backups/ *.bak .dots-selection.local.json
