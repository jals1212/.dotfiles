#!/bin/sh
# duti-apply.sh — register VSCodium as the default GUI app for code/text files.
# One script for both callers, so the conditions cannot drift: the dotbot shell
# step of config/install.conf.yaml (./dots update) and the targeted install of
# ./dots components. Run from anywhere; REPO_ROOT comes from this file's path.
#
# Applies ~/.config/duti/vscodium.duti with duti only on macOS, when vscodium is
# selected (./dots components), duti is on PATH and VSCodium.app is installed;
# otherwise it does nothing and exits 0. Exit 1 with a warning when duti itself
# failed (the dotbot step ignores it with `|| true`).
# The terminal $EDITOR/$VISUAL are not touched.

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

[ "$(uname -s)" = Darwin ] || exit 0
components_has vscodium || exit 0
command -v duti >/dev/null 2>&1 || exit 0
open -Ra VSCodium >/dev/null 2>&1 || exit 0

if duti "${HOME}/.config/duti/vscodium.duti"; then
    exit 0
fi
printf 'warning: duti could not apply %s\n' "${HOME}/.config/duti/vscodium.duti" >&2
exit 1
