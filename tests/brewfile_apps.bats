#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
# tests/brewfile_apps.bats
# The terminal components (tmux + gitmux, Herdr TUI/core/app, Ghostty) are
# installed only when selected: the Brewfile reads DOTS_COMPONENTS from
# ~/.config/zsh/local.zsh, and the Herdr core/app installers run as dotbot
# shell steps. Nothing here reaches the network: curl and uname are stubs, and
# every run uses a sandbox HOME.

REPO_ROOT_REAL="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
BREWFILE="${REPO_ROOT_REAL}/config/Brewfile"
ALL_COMPONENTS="tmux herdr-tui herdr-core herdr-app ghostty"

setup() {
    SANDBOX="$(mktemp -d)"
    export HOME="${SANDBOX}/home"
    mkdir -p "${HOME}/.config/zsh" "${SANDBOX}/bin"
    export NO_COLOR=1
}

teardown() {
    rm -rf "${SANDBOX}"
}

# _record <ids...> — record a component selection in the sandbox local.zsh.
_record() {
    printf 'export DOTS_COMPONENTS="${DOTS_COMPONENTS:-%s}"\n' "$*" > "${HOME}/.config/zsh/local.zsh"
}

# --- Brewfile ---------------------------------------------------------------

@test "the Brewfile declares no terminal component unconditionally" {
    run grep -Eq '^(brew "(tmux|gitmux|herdr)"|cask "(herdr-app|ghostty)")( #.*)?$' "${BREWFILE}"
    [ "${status}" -ne 0 ]
}

@test "the Brewfile gates each terminal component on its DOTS_COMPONENTS id" {
    grep -Fq 'DOTS_COMPONENTS' "${BREWFILE}"
    grep -Eq '^brew "herdr" if dots_components\.include\?\("herdr-tui"\)' "${BREWFILE}"
    grep -Eq '^cask "herdr-app" if OS\.mac\? && dots_components\.include\?\("herdr-app"\)' "${BREWFILE}"
    grep -Eq '^cask "ghostty" if OS\.mac\? && dots_components\.include\?\("ghostty"\)' "${BREWFILE}"
    # tmux and gitmux come together, under the tmux id.
    grep -Eq '^if dots_components\.include\?\("tmux"\)' "${BREWFILE}"
}

# _bundle <formula|cask> — what the Brewfile declares for the sandbox HOME, as a
# sorted list of the terminal-component entries (brew bundle list only parses
# the file; nothing is installed or fetched).
_bundle() {
    env HOME="${HOME}" HOMEBREW_NO_AUTO_UPDATE=1 \
        brew bundle list "--$1" --file="${BREWFILE}" |
        grep -E '^(tmux|gitmux|herdr|herdr-app|ghostty)$' | sort | tr '\n' ' '
}

_needs_brew() {
    [ "$(/usr/bin/uname -s)" = "Darwin" ] && command -v brew >/dev/null 2>&1 || skip "needs macOS Homebrew"
}

@test "Brewfile declares no terminal component when nothing is recorded" {
    _needs_brew
    [ "$(_bundle formula)" = "" ]
    [ "$(_bundle cask)" = "" ]
}

@test "Brewfile declares no terminal component when the selection is none" {
    _needs_brew
    _record none
    [ "$(_bundle formula)" = "" ]
    [ "$(_bundle cask)" = "" ]
}

@test "Brewfile declares exactly the packages of each selected component" {
    _needs_brew
    _record tmux
    [ "$(_bundle formula)" = "gitmux tmux " ]
    [ "$(_bundle cask)" = "" ]

    _record herdr-tui
    [ "$(_bundle formula)" = "herdr " ]
    [ "$(_bundle cask)" = "" ]

    _record herdr-core
    [ "$(_bundle formula)" = "" ]
    [ "$(_bundle cask)" = "" ]

    _record herdr-app herdr-core
    [ "$(_bundle formula)" = "" ]
    [ "$(_bundle cask)" = "herdr-app " ]

    _record ghostty
    [ "$(_bundle formula)" = "" ]
    [ "$(_bundle cask)" = "ghostty " ]
}

@test "Brewfile with every component declares what it declared before the picker" {
    _needs_brew
    _record ${ALL_COMPONENTS}
    [ "$(_bundle formula)" = "gitmux herdr tmux " ]
    [ "$(_bundle cask)" = "ghostty herdr-app " ]
}

@test "the font cask stays declared whatever the components are" {
    _needs_brew
    run env HOME="${HOME}" HOMEBREW_NO_AUTO_UPDATE=1 brew bundle list --cask --file="${BREWFILE}"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"font-jetbrains-mono-nerd-font"* ]] || return 1
    _record ghostty
    run env HOME="${HOME}" HOMEBREW_NO_AUTO_UPDATE=1 brew bundle list --cask --file="${BREWFILE}"
    [[ "${output}" == *"font-jetbrains-mono-nerd-font"* ]] || return 1
}

# --- Herdr installer steps (dotbot shell directives) ------------------------

# _step <description-prefix> — the shell command of the install.conf.yaml step.
_step() {
    awk -v want="$1" '
        index($0, "description: " want) { f = 1; next }
        f && /^    quiet:/ { exit }
        f && /^    command: \|/ { next }
        f { sub(/^      /, ""); print }' "${REPO_ROOT_REAL}/config/install.conf.yaml"
}

# _stubs <uname> — stub uname and curl. curl logs its arguments, prints a
# one-line installer, and fails when CURL_FAIL is set.
_stubs() {
    printf '#!/bin/sh\nprintf "%s\\n"\n' "$1" > "${SANDBOX}/bin/uname"
    cat > "${SANDBOX}/bin/curl" <<EOF
#!/bin/sh
echo "curl \$*" >> "${SANDBOX}/calls"
[ -n "\${CURL_FAIL:-}" ] && exit 22
for last in "\$@"; do :; done
echo "echo ran \${last##*releases.herdr.dev/}"
EOF
    chmod +x "${SANDBOX}/bin/uname" "${SANDBOX}/bin/curl"
}

# _run_step <description-prefix> — run a step from the repo root, like dotbot,
# with the stubs first on PATH and a sandbox HOME.
_run_step() {
    _step "$1" > "${SANDBOX}/step.sh"
    [ -s "${SANDBOX}/step.sh" ]
    cd "${REPO_ROOT_REAL}"
    run --separate-stderr env HOME="${HOME}" XDG_DATA_HOME= \
        PATH="${SANDBOX}/bin:/usr/bin:/bin" sh "${SANDBOX}/step.sh"
}

APP_STEP="Install Herdr desktop app"
CORE_STEP="Install Herdr core"

_calls() { cat "${SANDBOX}/calls" 2>/dev/null || true; }

@test "on Linux, selecting the Herdr app runs the official app installer" {
    _stubs Linux
    _record herdr-app herdr-core
    _run_step "${APP_STEP}"
    [ "${status}" -eq 0 ]
    [ "$(_calls)" = "curl -fsSL https://releases.herdr.dev/app/install.sh" ]
    [ "${output}" = "ran app/install.sh" ]
}

@test "on Linux an installed Herdr app is not reinstalled" {
    _stubs Linux
    _record herdr-app herdr-core
    mkdir -p "${HOME}/.local/share/herdr-app"
    _run_step "${APP_STEP}"
    [ "${status}" -eq 0 ]
    [ "$(_calls)" = "" ]
}

@test "on Linux the app installer does not run unless the app is selected" {
    _stubs Linux
    for sel in "" "none" "tmux herdr-tui ghostty" "herdr-core"; do
        [ -z "${sel}" ] || _record ${sel}
        _run_step "${APP_STEP}"
        [ "${status}" -eq 0 ]
        [ "$(_calls)" = "" ]
    done
}

@test "on macOS the app step does nothing (the cask installs the app)" {
    _stubs Darwin
    _record herdr-app herdr-core
    _run_step "${APP_STEP}"
    [ "${status}" -eq 0 ]
    [ "$(_calls)" = "" ]
}

@test "a failing app installer only warns" {
    _stubs Linux
    _record herdr-app herdr-core
    CURL_FAIL=1 _run_step "${APP_STEP}"
    [ "${status}" -eq 0 ]
    [[ "${stderr}" == *"warning: the Herdr app installer failed"* ]] || return 1
}

@test "selecting Herdr core runs the official core installer on Linux and macOS" {
    for os in Linux Darwin; do
        rm -f "${SANDBOX}/calls"
        _stubs "${os}"
        _record herdr-core
        _run_step "${CORE_STEP}"
        [ "${status}" -eq 0 ]
        [ "$(_calls)" = "curl -fsSL https://releases.herdr.dev/core/install.sh" ]
        [ "${output}" = "ran core/install.sh" ]
    done
}

@test "the core installer is skipped when the app is selected (it brings the core)" {
    for os in Linux Darwin; do
        _stubs "${os}"
        _record herdr-app herdr-core
        _run_step "${CORE_STEP}"
        [ "${status}" -eq 0 ]
        [ "$(_calls)" = "" ]
    done
}

@test "the core installer is skipped when the core is not selected" {
    _stubs Linux
    for sel in "" "none" "tmux herdr-tui ghostty"; do
        [ -z "${sel}" ] || _record ${sel}
        _run_step "${CORE_STEP}"
        [ "${status}" -eq 0 ]
        [ "$(_calls)" = "" ]
    done
}

@test "the core installer is skipped when herdr-core is already on PATH or in ~/.local/bin" {
    _stubs Linux
    _record herdr-core
    printf '#!/bin/sh\nexit 0\n' > "${SANDBOX}/bin/herdr-core"
    chmod +x "${SANDBOX}/bin/herdr-core"
    _run_step "${CORE_STEP}"
    [ "${status}" -eq 0 ]
    [ "$(_calls)" = "" ]

    rm -f "${SANDBOX}/bin/herdr-core"
    mkdir -p "${HOME}/.local/bin"
    printf '#!/bin/sh\nexit 0\n' > "${HOME}/.local/bin/herdr-core"
    chmod +x "${HOME}/.local/bin/herdr-core"
    _run_step "${CORE_STEP}"
    [ "${status}" -eq 0 ]
    [ "$(_calls)" = "" ]
}

@test "a failing core installer only warns" {
    _stubs Linux
    _record herdr-core
    CURL_FAIL=1 _run_step "${CORE_STEP}"
    [ "${status}" -eq 0 ]
    [[ "${stderr}" == *"warning: the Herdr core installer failed"* ]] || return 1
}
