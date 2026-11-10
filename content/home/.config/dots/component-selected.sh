#!/bin/sh
# component-selected.sh <id>... — exit 0 when any of the terminal components is
# selected (DOTS_COMPONENTS in ~/.config/zsh/local.zsh), 1 when none is, 2 on
# bad usage. dotbot runs it from the repo root as the `if:` predicate of the
# tmux, Herdr and Ghostty links and of the Herdr installer steps. A selection
# that was never recorded, or `none`, selects nothing. The ids and the
# herdr-app → herdr-core rule come from src/lib/components.sh.

[ "$#" -gt 0 ] || {
    printf 'usage: component-selected.sh <id>...\n' >&2
    exit 2
}

REPO_ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
export REPO_ROOT

# shellcheck source=src/lib/paths.sh
. "${REPO_ROOT}/src/lib/paths.sh"
# shellcheck source=src/lib/log.sh
. "${REPO_ROOT}/src/lib/log.sh"
# shellcheck source=src/lib/theme.sh
. "${REPO_ROOT}/src/lib/theme.sh"
# shellcheck source=src/lib/components.sh
. "${REPO_ROOT}/src/lib/components.sh"

components_has_any "$@"
