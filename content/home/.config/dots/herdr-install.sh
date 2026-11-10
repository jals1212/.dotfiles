#!/bin/sh
# herdr-install.sh app|core — run Herdr's official installer when it applies.
# One script for both callers, so the conditions cannot drift: the dotbot shell
# steps of config/install.conf.yaml (./dots update) and the targeted install of
# ./dots components. Run from anywhere; REPO_ROOT comes from this file's path.
#
#   app   Linux only (macOS gets the app from the herdr-app cask), when herdr-app
#         is selected and ${XDG_DATA_HOME:-~/.local/share}/herdr-app is absent.
#         The app installer brings the core.
#   core  macOS and Linux (Homebrew has no core package), when herdr-core is
#         selected; on Linux not when herdr-app is (its installer brings the
#         core); skipped when herdr-core is on PATH or in ~/.local/bin.
#
# The installers are unpinned. Exit 0 when it ran or did not apply; 1 with a
# warning when the installer failed (dotbot steps ignore it with `|| true`, so an
# offline run still finishes; ./dots components reports it); 2 on bad usage.

case "${1:-}" in
    app | core) ;;
    *)
        printf 'usage: herdr-install.sh app|core\n' >&2
        exit 2
        ;;
esac
_hi_kind="$1"

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

case "${_hi_kind}" in
    app)
        [ "$(uname -s)" = Linux ] || exit 0
        components_has herdr-app || exit 0
        [ ! -d "${XDG_DATA_HOME:-${HOME}/.local/share}/herdr-app" ] || exit 0
        ;;
    core)
        components_has herdr-core || exit 0
        if [ "$(uname -s)" = Linux ] && components_has herdr-app; then
            exit 0
        fi
        ! command -v herdr-core >/dev/null 2>&1 || exit 0
        [ ! -x "${HOME}/.local/bin/herdr-core" ] || exit 0
        ;;
esac

if _hi_script="$(curl -fsSL "https://releases.herdr.dev/${_hi_kind}/install.sh")" \
    && printf '%s\n' "${_hi_script}" | sh; then
    exit 0
fi
printf 'warning: the Herdr %s installer failed\n' "${_hi_kind}" >&2
exit 1
