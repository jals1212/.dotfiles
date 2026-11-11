#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
# tests/components_install.bats
# After `./dots components` records a selection that ADDS components it offers
# to install only those (S9): their own brew entries, the Herdr installers, the
# Herdr app migration and exactly their config links — never the full update
# (no brew bundle, no mise, nothing of unrelated tools). On a TTY it asks
# `Install the new components now? [Y/n]`; --yes installs without asking; no
# TTY without --yes (or declining) installs nothing and says to run
# ./dots update. A failed step warns, the rest continues, the exit is non-zero
# and the selection stays recorded.
#
# Safety: sandbox HOME; brew, curl, mise, uname and pgrep are logging stubs
# first on a restricted PATH (the host's ~/.local/bin is not on it); nothing
# reaches the real brew, network, home or the running Herdr app.

REPO_ROOT_REAL="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

setup() {
    SANDBOX="$(cd "$(mktemp -d)" && pwd -P)"
    export HOME="${SANDBOX}/home"
    unset XDG_DATA_HOME
    export XDG_STATE_HOME="${HOME}/.local/state"
    mkdir -p "${HOME}/.config/zsh" "${HOME}/.local/bin" "${SANDBOX}/bin"
    export NO_COLOR=1
    LOCAL_ZSH="${HOME}/.config/zsh/local.zsh"
    CMD="${REPO_ROOT_REAL}/src/commands/components.sh"
    TOOL_LOG="${SANDBOX}/tools.log"
    export TOOL_LOG
    : > "${TOOL_LOG}"
    # brew: `list --formula|--cask <name>` succeeds for names in BREW_INSTALLED;
    # `install` fails for any name in BREW_FAIL_INSTALL. Every call is logged.
    cat > "${SANDBOX}/bin/brew" <<'STUB'
#!/bin/sh
printf 'brew %s\n' "$*" >> "${TOOL_LOG}"
case "$1" in
    list)
        for n in ${BREW_INSTALLED:-}; do [ "$n" = "$3" ] && exit 0; done
        exit 1 ;;
    install)
        for last in "$@"; do :; done
        for n in ${BREW_FAIL_INSTALL:-}; do [ "$n" = "${last}" ] && exit 1; done
        exit 0 ;;
esac
exit 0
STUB
    # curl logs, fails when CURL_FAIL is set, else prints a one-line installer.
    cat > "${SANDBOX}/bin/curl" <<'STUB'
#!/bin/sh
printf 'curl %s\n' "$*" >> "${TOOL_LOG}"
[ -n "${CURL_FAIL:-}" ] && exit 22
for last in "$@"; do :; done
echo "echo ran ${last##*releases.herdr.dev/}"
STUB
    printf '#!/bin/sh\nprintf "mise %%s\\n" "$*" >> "${TOOL_LOG}"\n' > "${SANDBOX}/bin/mise"
    cat > "${SANDBOX}/bin/uname" <<'STUB'
#!/bin/sh
if [ $# -eq 0 ] || [ "$1" = "-s" ]; then printf '%s\n' "${FAKE_UNAME:-Darwin}"; exit 0; fi
exec /usr/bin/uname "$@"
STUB
    # pgrep succeeds only when FAKE_RUNNING=1.
    printf '#!/bin/sh\nprintf "pgrep %%s\\n" "$*" >> "${TOOL_LOG}"\n[ "${FAKE_RUNNING:-0}" = 1 ]\n' > "${SANDBOX}/bin/pgrep"
    # duti logs; open -Ra VSCodium succeeds unless NO_VSCODIUM_APP=1; DUTI_FAIL=1 makes duti fail.
    printf '#!/bin/sh\nprintf "duti %%s\\n" "$*" >> "${TOOL_LOG}"\n[ "${DUTI_FAIL:-0}" != 1 ]\n' > "${SANDBOX}/bin/duti"
    printf '#!/bin/sh\nprintf "open %%s\\n" "$*" >> "${TOOL_LOG}"\n[ "${NO_VSCODIUM_APP:-0}" != 1 ]\n' > "${SANDBOX}/bin/open"
    chmod +x "${SANDBOX}"/bin/*
    # The Neovim theme link lives in the repo (gitignored): put it back after each test.
    NVIM_THEME_LINK="${REPO_ROOT_REAL}/content/home/.config/nvim/lua/dots-theme.lua"
    NVIM_LINK_SAVED=""
    [ ! -L "${NVIM_THEME_LINK}" ] || NVIM_LINK_SAVED="$(readlink "${NVIM_THEME_LINK}")"
    # Restricted PATH: stubs, python3's directory (Dotbot), system tools.
    PY_DIR="$(dirname "$(command -v python3)")"
    export PATH="${SANDBOX}/bin:${PY_DIR}:/usr/bin:/bin:/usr/sbin:/sbin"
}

teardown() {
    if [ -n "${NVIM_LINK_SAVED}" ]; then
        ln -sfn "${NVIM_LINK_SAVED}" "${NVIM_THEME_LINK}"
    elif [ -L "${NVIM_THEME_LINK}" ]; then
        rm -f "${NVIM_THEME_LINK}"
    fi
    rm -rf "${SANDBOX}"
}

_has() { case "${output}" in *"$1"*) return 0 ;; esac; echo "missing: $1 in: ${output}"; return 1; }
_lacks() { case "${output}" in *"$1"*) echo "unexpected: $1 in: ${output}"; return 1 ;; esac; return 0; }

_record() {
    printf 'export DOTS_COMPONENTS="${DOTS_COMPONENTS:-%s}"\n' "$*" > "${LOCAL_ZSH}"
}

_recorded_is() {
    grep -Fqx "export DOTS_COMPONENTS=\"\${DOTS_COMPONENTS:-$1}\"" "${LOCAL_ZSH}"
}

# _log — the stub call log, one call per line.
_log() { cat "${TOOL_LOG}"; }

# _points_into_repo <path relative to $HOME>
_points_into_repo() {
    [ -L "${HOME}/$1" ] || return 1
    case "$(readlink "${HOME}/$1")" in
        "${REPO_ROOT_REAL}"/*) return 0 ;;
    esac
    return 1
}

_require_script() {
    command -v script >/dev/null 2>&1 || return 1
    script -q /dev/null env true >/dev/null 2>&1
}

# _tty_components <keys> [args...] — run the command on a pty reading <keys>
# (printf format) from fd 3, like the pickers' tests.
_tty_components() {
    _keys="$1"; shift
    printf "${_keys}" > "${SANDBOX}/keys"
    script -q /dev/null sh -c 'exec 3<"$1"; shift; exec sh "$@"' _ "${SANDBOX}/keys" "${CMD}" "$@"
}

# _nothing_else — no full update ran: no bundle, no mise.
_nothing_else() {
    run grep -E '^(mise |brew bundle)' "${TOOL_LOG}"
    [ "${status}" -ne 0 ]
}

# _no_installs — nothing was installed (listing for the removal plan is fine).
_no_installs() {
    run grep -E '^(brew install|curl|mise|brew bundle)' "${TOOL_LOG}"
    [ "${status}" -ne 0 ]
}

# ── What gets installed ──────────────────────────────────────────────────────

@test "--yes with tmux installs tmux and gitmux with brew and links only the tmux config" {
    run sh "${CMD}" --yes tmux
    [ "${status}" -eq 0 ]
    [ "$(_log)" = "brew list --formula tmux
brew install tmux
brew list --formula gitmux
brew install gitmux" ]
    _points_into_repo .config/tmux/tmux.conf
    _points_into_repo .config/tmux/theme.conf
    _points_into_repo .config/tmux/scripts/session-picker.sh
    # nothing of the other components or of the rest of the update
    [ ! -e "${HOME}/.config/herdr" ] && [ ! -e "${HOME}/.config/ghostty" ]
    [ ! -e "${HOME}/.zshenv" ] && [ ! -e "${HOME}/.config/nvim" ] && [ ! -e "${HOME}/.config/starship.toml" ]
    _recorded_is tmux
    _nothing_else
}

@test "--yes with herdr-tui installs the herdr formula and links the Herdr config" {
    run sh "${CMD}" --yes herdr-tui
    [ "${status}" -eq 0 ]
    [ "$(_log)" = "brew list --formula herdr
brew install herdr" ]
    _points_into_repo .config/herdr/config.toml
    [ ! -e "${HOME}/.config/tmux" ]
}

@test "--yes with ghostty installs the cask and links the config, shaders and theme" {
    run sh "${CMD}" --yes ghostty
    [ "${status}" -eq 0 ]
    [ "$(_log)" = "brew list --cask ghostty
brew install --cask ghostty" ]
    _points_into_repo .config/ghostty/config
    _points_into_repo .config/ghostty/shaders
    _points_into_repo .config/ghostty/themes/dots
    # the font is not touched: dots font owns it
    [ ! -e "${HOME}/.config/ghostty/font.conf" ]
    [ ! -e "${HOME}/.config/tmux" ]
    _nothing_else
}

@test "--yes with herdr-core runs only the official core installer (skipped when the core exists)" {
    run sh "${CMD}" --yes herdr-core
    [ "${status}" -eq 0 ]
    [ "$(_log)" = "curl -fsSL --connect-timeout 10 --max-time 120 https://releases.herdr.dev/core/install.sh" ]
    _has "ran core/install.sh"
    _points_into_repo .config/herdr/config.toml
    # the Herdr app config belongs to herdr-app only
    [ ! -e "${HOME}/.config/herdr-app" ]

    : > "${TOOL_LOG}"
    _record none
    printf '#!/bin/sh\nexit 0\n' > "${HOME}/.local/bin/herdr-core"
    chmod +x "${HOME}/.local/bin/herdr-core"
    run sh "${CMD}" --yes herdr-core
    [ "${status}" -eq 0 ]
    [ "$(_log)" = "" ]
}

@test "on macOS herdr-app installs the cask, then migrates an official install; the core installer runs too" {
    mkdir -p "${HOME}/Applications/Herdr.app/Contents/MacOS"
    printf 'app\n' > "${HOME}/Applications/Herdr.app/Contents/MacOS/Herdr"
    ln -s "${HOME}/Applications/Herdr.app/Contents/MacOS/Herdr" "${HOME}/.local/bin/herdr-app"
    run sh "${CMD}" --yes herdr-app
    [ "${status}" -eq 0 ]
    [ "$(_log)" = "curl -fsSL --connect-timeout 10 --max-time 120 https://releases.herdr.dev/core/install.sh
brew list --cask herdr-app
brew install --cask herdr-app
pgrep -f ${HOME}/Applications/Herdr.app/Contents/MacOS/" ]
    [ ! -e "${HOME}/Applications/Herdr.app" ]
    [ ! -L "${HOME}/.local/bin/herdr-app" ]
    _points_into_repo .config/herdr/config.toml
    _points_into_repo .config/herdr-app/settings.json
    _points_into_repo .config/herdr-app/keys.json
    _points_into_repo .config/herdr-app/layouts/jals1212.json
    _points_into_repo .config/herdr-app/mods/jals1212
    _recorded_is "herdr-core herdr-app"
}

@test "a failing herdr-app cask install keeps the official Herdr app (no migration) and fails" {
    mkdir -p "${HOME}/Applications/Herdr.app/Contents/MacOS"
    printf 'app\n' > "${HOME}/Applications/Herdr.app/Contents/MacOS/Herdr"
    ln -s "${HOME}/Applications/Herdr.app/Contents/MacOS/Herdr" "${HOME}/.local/bin/herdr-app"
    BREW_FAIL_INSTALL="herdr-app" run sh "${CMD}" --yes herdr-app
    [ "${status}" -ne 0 ]
    _has "brew install --cask herdr-app failed"
    [ -f "${HOME}/Applications/Herdr.app/Contents/MacOS/Herdr" ]
    [ -L "${HOME}/.local/bin/herdr-app" ]
    run grep -q '^pgrep' "${TOOL_LOG}"
    [ "${status}" -ne 0 ]
}

@test "a running official Herdr app is kept by the migration; the cask is still installed" {
    mkdir -p "${HOME}/Applications/Herdr.app/Contents/MacOS"
    printf 'app\n' > "${HOME}/Applications/Herdr.app/Contents/MacOS/Herdr"
    FAKE_RUNNING=1 run sh "${CMD}" --yes herdr-app
    [ "${status}" -eq 0 ]
    _has "Herdr app is running"
    [ -f "${HOME}/Applications/Herdr.app/Contents/MacOS/Herdr" ]
    grep -Fqx "brew install --cask herdr-app" "${TOOL_LOG}"
}

@test "on Linux herdr-app runs the official app installer only (it brings the core) and no brew" {
    FAKE_UNAME=Linux run sh "${CMD}" --yes herdr-app
    [ "${status}" -eq 0 ]
    [ "$(_log)" = "curl -fsSL --connect-timeout 10 --max-time 120 https://releases.herdr.dev/app/install.sh" ]
    _has "ran app/install.sh"
    _points_into_repo .config/herdr/config.toml

    # an installed app is not reinstalled
    : > "${TOOL_LOG}"
    _record none
    mkdir -p "${HOME}/.local/share/herdr-app"
    FAKE_UNAME=Linux run sh "${CMD}" --yes herdr-app
    [ "$(_log)" = "" ]
}

@test "on Linux ghostty links its config and installs no package" {
    FAKE_UNAME=Linux run sh "${CMD}" --yes ghostty
    [ "${status}" -eq 0 ]
    [ "$(_log)" = "" ]
    _points_into_repo .config/ghostty/config
}

@test "installed packages are skipped" {
    BREW_INSTALLED="tmux ghostty" run sh "${CMD}" --yes tmux ghostty
    [ "${status}" -eq 0 ]
    [ "$(_log)" = "brew list --formula tmux
brew list --formula gitmux
brew install gitmux
brew list --cask ghostty" ]
}

@test "only the components added by this change are installed" {
    _record tmux
    run sh "${CMD}" --yes tmux ghostty
    [ "${status}" -eq 0 ]
    [ "$(_log)" = "brew list --cask ghostty
brew install --cask ghostty" ]
    [ ! -e "${HOME}/.config/tmux" ]

    # herdr-app already recorded implies herdr-core: adding core installs nothing
    : > "${TOOL_LOG}"
    _record herdr-app
    run sh "${CMD}" --yes herdr-app herdr-core
    [ "${status}" -eq 0 ]
    [ "$(_log)" = "" ]
}

# ── Editors: nvim, fresh, vscodium ───────────────────────────────────────────

# _active_nvim_palette — the Neovim palette of the repo's active theme.
_active_nvim_palette() {
    _t="$(sed -n 's/.*"theme"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "${REPO_ROOT_REAL}/manifest.json" | head -1)"
    _f="$(sed -n 's/.*"flavor"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "${REPO_ROOT_REAL}/manifest.json" | head -1)"
    printf '%s/content/assets/palettes/nvim/%s-%s.lua' "${REPO_ROOT_REAL}" "${_t:-kanagawa}" "${_f:-dragon}"
}

@test "--yes with nvim installs neovim and luarocks, links ~/.config/nvim and the theme link of the active theme" {
    run sh "${CMD}" --yes nvim
    [ "${status}" -eq 0 ]
    [ "$(_log)" = "brew list --formula neovim
brew install neovim
brew list --formula luarocks
brew install luarocks" ]
    _points_into_repo .config/nvim/init.lua
    _points_into_repo .config/nvim/lua
    [ -L "${NVIM_THEME_LINK}" ]
    [ "$(readlink "${NVIM_THEME_LINK}")" = "$(_active_nvim_palette)" ]
    [ ! -e "${HOME}/.config/tmux" ] && [ ! -e "${HOME}/.config/ghostty" ] && [ ! -e "${HOME}/.config/duti" ]
    _recorded_is nvim
    _nothing_else
}

@test "nvim installs the same on Linux (brew formulae and links)" {
    FAKE_UNAME=Linux run sh "${CMD}" --yes nvim
    [ "${status}" -eq 0 ]
    grep -Fqx "brew install neovim" "${TOOL_LOG}"
    _points_into_repo .config/nvim/init.lua
}

@test "--yes with fresh installs the fresh-editor formula and links nothing" {
    run sh "${CMD}" --yes fresh
    [ "${status}" -eq 0 ]
    [ "$(_log)" = "brew list --formula fresh-editor
brew install fresh-editor" ]
    [ ! -e "${HOME}/.config/nvim" ] && [ ! -e "${HOME}/.config/duti" ] && [ ! -e "${HOME}/Library" ]
    _recorded_is fresh
    _nothing_else
}

@test "--yes with vscodium on macOS installs the cask and duti, links duti and the Quick Action, applies duti" {
    run sh "${CMD}" --yes vscodium
    [ "${status}" -eq 0 ]
    [ "$(_log)" = "brew list --cask vscodium
brew install --cask vscodium
brew list --formula duti
brew install duti
open -Ra VSCodium
duti ${HOME}/.config/duti/vscodium.duti" ]
    _points_into_repo .config/duti/vscodium.duti
    _points_into_repo "Library/Services/Open in VSCodium.workflow"
    [ ! -e "${HOME}/.config/nvim" ]
    _recorded_is vscodium
    _nothing_else
}

@test "vscodium on Linux installs and links nothing" {
    FAKE_UNAME=Linux run sh "${CMD}" --yes vscodium
    [ "${status}" -eq 0 ]
    [ "$(_log)" = "" ]
    [ ! -e "${HOME}/.config/duti" ] && [ ! -e "${HOME}/Library" ]
    _recorded_is vscodium
}

@test "the duti step is skipped without duti or without VSCodium.app, and a failing duti warns and fails" {
    rm -f "${SANDBOX}/bin/duti"
    run sh "${CMD}" --yes vscodium
    [ "${status}" -eq 0 ]
    run grep -E '^(duti|open) ' "${TOOL_LOG}"
    [ "${status}" -ne 0 ]

    printf '#!/bin/sh\nprintf "duti %%s\\n" "$*" >> "${TOOL_LOG}"\n[ "${DUTI_FAIL:-0}" != 1 ]\n' > "${SANDBOX}/bin/duti"
    chmod +x "${SANDBOX}/bin/duti"
    : > "${TOOL_LOG}"
    _record none
    NO_VSCODIUM_APP=1 run sh "${CMD}" --yes vscodium
    [ "${status}" -eq 0 ]
    run grep -E '^duti ' "${TOOL_LOG}"
    [ "${status}" -ne 0 ]

    : > "${TOOL_LOG}"
    _record none
    DUTI_FAIL=1 run sh "${CMD}" --yes vscodium
    [ "${status}" -ne 0 ]
    _has "duti"
    _recorded_is vscodium
}

@test "the editors are independent: adding one installs only it" {
    _record nvim
    run sh "${CMD}" --yes nvim fresh vscodium
    [ "${status}" -eq 0 ]
    run grep -E 'neovim|luarocks' "${TOOL_LOG}"
    [ "${status}" -ne 0 ]
    grep -Fqx "brew install fresh-editor" "${TOOL_LOG}"
    grep -Fqx "brew install --cask vscodium" "${TOOL_LOG}"
    _recorded_is "nvim fresh vscodium"
}

@test "a recorded selection without editors installs no editor and the never-recorded case installs none" {
    run sh "${CMD}" --yes tmux
    [ "${status}" -eq 0 ]
    run grep -E 'neovim|luarocks|fresh-editor|vscodium|duti' "${TOOL_LOG}"
    [ "${status}" -ne 0 ]
    [ ! -e "${HOME}/.config/nvim" ] && [ ! -e "${HOME}/.config/duti" ]
}

@test "the duti step is one script shared by install.conf.yaml and the components install" {
    script="content/home/.config/dots/duti-apply.sh"
    [ -f "${REPO_ROOT_REAL}/${script}" ]
    grep -Fq "${script}" "${REPO_ROOT_REAL}/config/install.conf.yaml"
    grep -Fq "duti-apply.sh" "${REPO_ROOT_REAL}/src/lib/components.sh"
    run grep -v '^[[:space:]]*#' "${REPO_ROOT_REAL}/config/install.conf.yaml"
    [[ "${output}" != *"duti ~/.config/duti"* ]] || return 1
}

# ── Asking ───────────────────────────────────────────────────────────────────

@test "on a TTY it asks Install the new components now? [Y/n] and y installs only those" {
    _require_script || skip "PTY script syntax unavailable"
    run _tty_components 'y' tmux
    [ "${status}" -eq 0 ]
    _has "Install the new components now?"
    _has "[Y/n]"
    [ "$(_log)" = "brew list --formula tmux
brew install tmux
brew list --formula gitmux
brew install gitmux" ]
    _points_into_repo .config/tmux/tmux.conf
}

@test "enter takes the default (yes)" {
    _require_script || skip "PTY script syntax unavailable"
    run _tty_components '\n' herdr-tui
    [ "${status}" -eq 0 ]
    [ "$(_log)" = "brew list --formula herdr
brew install herdr" ]
}

@test "declining (n or q) installs nothing, keeps the selection and says to run ./dots update" {
    _require_script || skip "PTY script syntax unavailable"
    for keys in 'n' 'q'; do
        : > "${TOOL_LOG}"
        rm -f "${LOCAL_ZSH}"
        run _tty_components "${keys}" tmux
        [ "${status}" -eq 0 ]
        _has "./dots update"
        [ "$(_log)" = "" ]
        [ ! -e "${HOME}/.config/tmux" ]
        _recorded_is tmux
    done
}

@test "the interactive picker leads to the same question" {
    _require_script || skip "PTY script syntax unavailable"
    # space checks the first row (tmux), enter confirms the picker, y installs
    run _tty_components ' \ny'
    [ "${status}" -eq 0 ]
    _has "Install the new components now?"
    grep -Fqx "brew install tmux" "${TOOL_LOG}"
    _recorded_is tmux
}

@test "without a TTY and without --yes nothing is installed and the hint says ./dots update" {
    run sh "${CMD}" tmux ghostty
    [ "${status}" -eq 0 ]
    _has "./dots update"
    _lacks "Install the new components now?"
    [ "$(_log)" = "" ]
    [ ! -e "${HOME}/.config/tmux" ] && [ ! -e "${HOME}/.config/ghostty" ]
    _recorded_is "tmux ghostty"
}

@test "a selection that only removes or keeps components does not ask to install" {
    _require_script || skip "PTY script syntax unavailable"
    _record tmux ghostty
    # unchecking ghostty asks only the removal question
    BREW_INSTALLED="" run _tty_components 'y' tmux
    [ "${status}" -eq 0 ]
    _lacks "Install the new components now?"
    _lacks "./dots update"
    _no_installs

    _record tmux
    run sh "${CMD}" --yes tmux
    [ "${status}" -eq 0 ]
    _lacks "./dots update"
    _no_installs

    run sh "${CMD}" --yes none
    [ "${status}" -eq 0 ]
    _lacks "./dots update"
}

# ── Failures ─────────────────────────────────────────────────────────────────

@test "a failing install warns, the rest continues, the exit is non-zero and the selection stays recorded" {
    BREW_FAIL_INSTALL="gitmux" CURL_FAIL=1 run sh "${CMD}" --yes tmux herdr-core ghostty
    [ "${status}" -ne 0 ]
    _has "WARN"
    _has "brew install gitmux failed"
    # every step was attempted and the links were made regardless
    grep -Fqx "brew install tmux" "${TOOL_LOG}"
    grep -Fqx "brew install gitmux" "${TOOL_LOG}"
    grep -Fqx "brew install --cask ghostty" "${TOOL_LOG}"
    grep -Fq "curl -fsSL --connect-timeout 10 --max-time 120 https://releases.herdr.dev/core/install.sh" "${TOOL_LOG}"
    _points_into_repo .config/tmux/tmux.conf
    _points_into_repo .config/ghostty/config
    _recorded_is "tmux herdr-core ghostty"
}

@test "a missing brew warns and fails the install but still records and links" {
    # No brew anywhere on PATH (not even the host's next to python3).
    [ -x /usr/bin/python3 ] || skip "needs /usr/bin/python3"
    rm -f "${SANDBOX}/bin/brew"
    export PATH="${SANDBOX}/bin:/usr/bin:/bin:/usr/sbin:/sbin"
    run sh "${CMD}" --yes tmux
    [ "${status}" -ne 0 ]
    _has "brew not found"
    _points_into_repo .config/tmux/tmux.conf
    _recorded_is tmux
}

# ── Shared installer, help, docs ─────────────────────────────────────────────

@test "install.conf.yaml and the components install share one Herdr installer script" {
    script="content/home/.config/dots/herdr-install.sh"
    [ -f "${REPO_ROOT_REAL}/${script}" ]
    grep -Fq "${script} app" "${REPO_ROOT_REAL}/config/install.conf.yaml"
    grep -Fq "${script} core" "${REPO_ROOT_REAL}/config/install.conf.yaml"
    # the installer URLs live in the script only, not in install.conf.yaml commands
    run sh -c "grep -v '^[[:space:]]*#' '${REPO_ROOT_REAL}/config/install.conf.yaml' | grep -c 'releases.herdr.dev'"
    [ "${output}" = "0" ]
    grep -Fq "herdr-install.sh" "${REPO_ROOT_REAL}/src/lib/components.sh"
    run sh "${REPO_ROOT_REAL}/${script}" bogus
    [ "${status}" -eq 2 ]
}

@test "--help documents the install offer" {
    run sh "${CMD}" --help
    [ "${status}" -eq 0 ]
    _has "Install the new components now?"
    _has "./dots update"
    _has "--yes"
}
