#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
# tests/herdr_app_migration.bats
# On macOS the Herdr app comes from the herdr-app cask. When it is selected and
# an official install exists (~/Applications/Herdr.app), `./dots update` removes
# that install only after Homebrew installed the cask (the Brewfile run), after
# listing it and asking (default No; --yes moves it without asking; no TTY
# without --yes keeps it). The core and anything else stay. A running app is
# never removed; without the cask installed nothing is removed.
# Sandbox HOME; uname, pgrep and brew are stubs; nothing reaches the real machine.

REPO_ROOT_REAL="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

setup() {
    SANDBOX="$(cd "$(mktemp -d)" && pwd -P)"
    export HOME="${SANDBOX}/home"
    mkdir -p "${HOME}/.config/zsh" "${HOME}/.local/bin" "${SANDBOX}/bin"
    export NO_COLOR=1
    LOCAL_ZSH="${HOME}/.config/zsh/local.zsh"
    APP="${HOME}/Applications/Herdr.app"
    CORE="${HOME}/.local/share/herdr-core"
    cat > "${SANDBOX}/bin/uname" <<'STUB'
#!/bin/sh
if [ "$1" = "-s" ]; then printf '%s\n' "${FAKE_UNAME:-Darwin}"; exit 0; fi
exec /usr/bin/uname "$@"
STUB
    # pgrep succeeds only when FAKE_RUNNING=1.
    printf '#!/bin/sh\n[ "${FAKE_RUNNING:-0}" = 1 ]\n' > "${SANDBOX}/bin/pgrep"
    # brew: `list --cask herdr-app` succeeds unless FAKE_NO_CASK=1; calls are logged.
    BREW_LOG="${SANDBOX}/brew.log"
    export BREW_LOG
    printf '#!/bin/sh\nprintf "brew %%s\\n" "$*" >> "${BREW_LOG}"\n[ "$1" = list ] && [ "${FAKE_NO_CASK:-0}" = 1 ] && exit 1\nexit 0\n' > "${SANDBOX}/bin/brew"
    chmod +x "${SANDBOX}/bin/uname" "${SANDBOX}/bin/pgrep" "${SANDBOX}/bin/brew"
    export PATH="${SANDBOX}/bin:${PATH}"
}

teardown() {
    rm -rf "${SANDBOX}"
}

_record() {
    printf 'export DOTS_COMPONENTS="${DOTS_COMPONENTS:-%s}"\n' "$*" > "${LOCAL_ZSH}"
}

# _official_install — the official installer's macOS layout.
_official_install() {
    mkdir -p "${APP}/Contents/MacOS" "${CORE}/current/Contents/MacOS"
    printf 'app\n' > "${APP}/Contents/MacOS/Herdr"
    printf 'core\n' > "${CORE}/current/Contents/MacOS/herdr-core"
    ln -s "${APP}/Contents/MacOS/Herdr" "${HOME}/.local/bin/herdr-app"
    ln -s "${CORE}/current/Contents/MacOS/herdr-core" "${HOME}/.local/bin/herdr-core"
    ln -s "${CORE}/current/Contents/MacOS/herdr-core" "${HOME}/.local/bin/hc"
}

# _migrate <yes 0|1> [function] — run components_herdr_app_migrate (or the
# given function) with no TTY.
_migrate() {
    run --separate-stderr sh -c '
        REPO_ROOT="$1"; export REPO_ROOT
        . "$REPO_ROOT/src/lib/paths.sh"
        . "$REPO_ROOT/src/lib/log.sh"
        . "$REPO_ROOT/src/lib/detect.sh"
        . "$REPO_ROOT/src/lib/tui.sh"
        . "$REPO_ROOT/src/lib/theme.sh"
        . "$REPO_ROOT/src/lib/components.sh"
        "$3" "$2"' _ "${REPO_ROOT_REAL}" "$1" "${2:-components_herdr_app_migrate}" </dev/null
}

_core_intact() {
    [ -f "${CORE}/current/Contents/MacOS/herdr-core" ] &&
        [ -L "${HOME}/.local/bin/herdr-core" ] && [ -L "${HOME}/.local/bin/hc" ]
}

@test "--yes moves the official Herdr app out (app and its herdr-app link go, the core stays)" {
    _record herdr-app
    _official_install
    _migrate 1
    [ "${status}" -eq 0 ]
    [[ "${stderr}" == *"Herdr app moves to Homebrew"* ]] || return 1
    [[ "${stderr}" == *"    ${APP}"* ]] || return 1
    [[ "${stderr}" == *"    ${HOME}/.local/bin/herdr-app"* ]] || return 1
    [ ! -e "${APP}" ]
    [ ! -L "${HOME}/.local/bin/herdr-app" ]
    _core_intact
}

@test "without a TTY and without --yes the official app is kept, with a warning" {
    _record herdr-app
    _official_install
    _migrate 0
    [ "${status}" -eq 0 ]
    [[ "${stderr}" == *"No TTY to confirm: kept the official Herdr app (pass --yes to move it)"* ]] || return 1
    [ -f "${APP}/Contents/MacOS/Herdr" ]
    [ -L "${HOME}/.local/bin/herdr-app" ]
    _core_intact
}

@test "a running Herdr app is never removed, even with --yes" {
    _record herdr-app
    _official_install
    FAKE_RUNNING=1 _migrate 1
    [ "${status}" -eq 0 ]
    [[ "${stderr}" == *"Herdr app is running from ${APP}: quit it and run ./dots update again"* ]] || return 1
    [ -f "${APP}/Contents/MacOS/Herdr" ]
    [ -L "${HOME}/.local/bin/herdr-app" ]
}

@test "nothing happens on Linux, when herdr-app is not selected, or with no official install" {
    _official_install
    for sel in "" "none" "herdr-core herdr-tui"; do
        [ -z "${sel}" ] && rm -f "${LOCAL_ZSH}" || _record ${sel}
        _migrate 1
        [ "${status}" -eq 0 ]
        [ -z "${stderr}" ]
        [ -d "${APP}" ]
    done
    _record herdr-app
    FAKE_UNAME=Linux _migrate 1
    [ "${status}" -eq 0 ]
    [ -z "${stderr}" ]
    [ -d "${APP}" ]
    rm -rf "${APP}" "${HOME}/.local/bin/herdr-app"
    _migrate 1
    [ "${status}" -eq 0 ]
    [ -z "${stderr}" ]
}

@test "a herdr-app link that does not point into the official app is left alone" {
    _record herdr-app
    _official_install
    rm -f "${HOME}/.local/bin/herdr-app"
    ln -s /opt/homebrew/bin/herdr-app "${HOME}/.local/bin/herdr-app"
    _migrate 1
    [ "${status}" -eq 0 ]
    [ ! -e "${APP}" ]
    [ "$(readlink "${HOME}/.local/bin/herdr-app")" = /opt/homebrew/bin/herdr-app ]
}

@test "update moves the official Herdr app only after the base dotbot run (Homebrew)" {
    upd="${REPO_ROOT_REAL}/src/commands/update.sh"
    mig="$(grep -n 'components_herdr_app_migrate_installed "${_yes}"' "${upd}" | cut -d: -f1)"
    base="$(grep -n '^dotbot_base_apply' "${upd}" | cut -d: -f1)"
    [ -n "${mig}" ] && [ -n "${base}" ] && [ "${mig}" -gt "${base}" ]
    run grep -c 'components_herdr_app_migrate ' "${upd}"
    [ "${output}" = 0 ]
}

@test "after the Brewfile: without the herdr-app cask installed the official app is kept, with a warning" {
    _record herdr-app
    _official_install
    FAKE_NO_CASK=1 _migrate 1 components_herdr_app_migrate_installed
    [ "${status}" -eq 0 ]
    [[ "${stderr}" == *"Homebrew has not installed herdr-app; kept the official Herdr app"* ]] || return 1
    [ -f "${APP}/Contents/MacOS/Herdr" ]
    [ -L "${HOME}/.local/bin/herdr-app" ]
    grep -Fqx "brew list --cask herdr-app" "${BREW_LOG}"
}

@test "after the Brewfile: with the herdr-app cask installed the official app is moved out" {
    _record herdr-app
    _official_install
    _migrate 1 components_herdr_app_migrate_installed
    [ "${status}" -eq 0 ]
    [ ! -e "${APP}" ]
    [ ! -L "${HOME}/.local/bin/herdr-app" ]
    _core_intact
}

@test "after the Brewfile: nothing asks brew on Linux, unselected, or with no official install" {
    _official_install
    _record herdr-core
    _migrate 1 components_herdr_app_migrate_installed
    [ "${status}" -eq 0 ]
    _record herdr-app
    FAKE_UNAME=Linux _migrate 1 components_herdr_app_migrate_installed
    [ "${status}" -eq 0 ]
    rm -rf "${APP}" "${HOME}/.local/bin/herdr-app"
    _migrate 1 components_herdr_app_migrate_installed
    [ "${status}" -eq 0 ]
    [ -z "${stderr}" ]
    [ ! -e "${BREW_LOG}" ]
}
