#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
# tests/components_removal.bats
# Unchecking a component that was RECORDED as selected uninstalls it (brew
# uninstall / the official install dirs on Linux) and removes its repo-owned
# symlinks, after a confirmation (default No; --yes skips it; no TTY without
# --yes refuses with exit 2). Components never recorded are never touched.
# Every run uses a sandbox HOME and stub brew/curl/uname that log their calls;
# nothing reaches real brew, curl or the network.

REPO_ROOT_REAL="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

setup() {
    SANDBOX="$(cd "$(mktemp -d)" && pwd -P)"
    export HOME="${SANDBOX}/home"
    unset XDG_DATA_HOME
    export XDG_STATE_HOME="${HOME}/.local/state"
    mkdir -p "${HOME}/.config/zsh" "${HOME}/.local/bin" "${SANDBOX}/bin" "${SANDBOX}/elsewhere"
    export NO_COLOR=1
    LOCAL_ZSH="${HOME}/.config/zsh/local.zsh"
    CMD="${REPO_ROOT_REAL}/src/commands/components.sh"
    TOOL_LOG="${SANDBOX}/tools.log"
    export TOOL_LOG
    # brew: `list --formula|--cask <name>` succeeds for names in BREW_INSTALLED;
    # `uninstall ...` fails when BREW_FAIL=1. Every call is logged.
    cat > "${SANDBOX}/bin/brew" <<'STUB'
#!/bin/sh
printf 'brew %s\n' "$*" >> "${TOOL_LOG}"
case "$1" in
    list)
        for n in ${BREW_INSTALLED:-}; do [ "$n" = "$3" ] && exit 0; done
        exit 1 ;;
    uninstall) [ "${BREW_FAIL:-0}" = 1 ] && exit 1; exit 0 ;;
esac
exit 0
STUB
    printf '#!/bin/sh\nprintf "curl %%s\\n" "$*" >> "${TOOL_LOG}"\nexit 1\n' > "${SANDBOX}/bin/curl"
    # uname -s reports FAKE_UNAME (default Darwin); anything else passes through.
    cat > "${SANDBOX}/bin/uname" <<'STUB'
#!/bin/sh
if [ "$1" = "-s" ]; then printf '%s\n' "${FAKE_UNAME:-Darwin}"; exit 0; fi
exec /usr/bin/uname "$@"
STUB
    chmod +x "${SANDBOX}/bin/brew" "${SANDBOX}/bin/curl" "${SANDBOX}/bin/uname"
    export PATH="${SANDBOX}/bin:${PATH}"
}

teardown() {
    rm -rf "${SANDBOX}"
}

_has() { case "${output}" in *"$1"*) return 0 ;; esac; echo "missing: $1 in: ${output}"; return 1; }
_lacks() { case "${output}" in *"$1"*) echo "unexpected: $1 in: ${output}"; return 1 ;; esac; return 0; }

# _record <ids...> — record a selection in the sandbox local.zsh.
_record() {
    printf 'export DOTS_COMPONENTS="${DOTS_COMPONENTS:-%s}"\n' "$*" > "${LOCAL_ZSH}"
}

# _repo_link <dest relative to $HOME> <repo source relative to the repo root>
_repo_link() {
    mkdir -p "$(dirname "${HOME}/$1")"
    ln -s "${REPO_ROOT_REAL}/$2" "${HOME}/$1"
}

_tmux_links() {
    _repo_link .config/tmux/tmux.conf content/home/.config/tmux/tmux.conf
    _repo_link .config/tmux/theme.conf content/home/.config/tmux/theme.conf
    _repo_link .config/tmux/scripts/session-picker.sh content/home/.config/tmux/scripts/session-picker.sh
}

_ghostty_links() {
    _repo_link .config/ghostty/config content/home/.config/ghostty/config
    _repo_link .config/ghostty/shaders content/home/.config/ghostty/shaders
    _repo_link .config/ghostty/themes/dots content/assets/palettes/ghostty/kanagawa/dragon.conf
}

_brew_calls() { grep '^brew uninstall' "${TOOL_LOG}" 2>/dev/null || true; }

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

# ── Nothing recorded, nothing removed ────────────────────────────────────────

@test "first recording removes nothing, even with the components installed" {
    _tmux_links
    BREW_INSTALLED="tmux gitmux herdr ghostty" run sh "${CMD}" ghostty
    [ "${status}" -eq 0 ]
    [ -z "$(_brew_calls)" ]
    [ -L "${HOME}/.config/tmux/tmux.conf" ]
    grep -Fqx 'export DOTS_COMPONENTS="${DOTS_COMPONENTS:-ghostty}"' "${LOCAL_ZSH}"
}

@test "recording none over a never-recorded selection removes nothing" {
    _tmux_links
    BREW_INSTALLED="tmux gitmux" run sh "${CMD}" none
    [ "${status}" -eq 0 ]
    [ -z "$(_brew_calls)" ]
    [ -L "${HOME}/.config/tmux/tmux.conf" ]
}

@test "components never recorded are never uninstalled when another one is unchecked" {
    _record tmux
    _tmux_links
    _ghostty_links
    BREW_INSTALLED="tmux gitmux ghostty herdr" run sh "${CMD}" --yes none
    [ "${status}" -eq 0 ]
    [ "$(_brew_calls)" = "brew uninstall tmux gitmux" ]
    [ -L "${HOME}/.config/ghostty/config" ]
}

@test "adding a component removes nothing and needs no --yes without a TTY" {
    _record tmux
    _tmux_links
    BREW_INSTALLED="tmux gitmux" run sh "${CMD}" tmux ghostty
    [ "${status}" -eq 0 ]
    [ -z "$(_brew_calls)" ]
    [ -L "${HOME}/.config/tmux/tmux.conf" ]
    grep -Fqx 'export DOTS_COMPONENTS="${DOTS_COMPONENTS:-tmux ghostty}"' "${LOCAL_ZSH}"
}

# ── tmux ─────────────────────────────────────────────────────────────────────

@test "unchecking tmux with --yes uninstalls tmux and gitmux and removes only repo symlinks" {
    _record tmux
    _tmux_links
    printf 'mine\n' > "${HOME}/.config/tmux/local.conf"
    printf 'x\n' > "${SANDBOX}/elsewhere/other.conf"
    mkdir -p "${HOME}/.config/tmux"
    ln -s "${SANDBOX}/elsewhere/other.conf" "${HOME}/.config/tmux/custom.conf"

    BREW_INSTALLED="tmux gitmux" run sh "${CMD}" --yes none
    [ "${status}" -eq 0 ]
    [ "$(_brew_calls)" = "brew uninstall tmux gitmux" ]
    [ ! -e "${HOME}/.config/tmux/tmux.conf" ] && [ ! -L "${HOME}/.config/tmux/tmux.conf" ]
    [ ! -L "${HOME}/.config/tmux/theme.conf" ]
    [ ! -L "${HOME}/.config/tmux/scripts/session-picker.sh" ]
    [ "$(cat "${HOME}/.config/tmux/local.conf")" = "mine" ]
    [ -L "${HOME}/.config/tmux/custom.conf" ]
    # the repo files the links pointed at are untouched
    [ -f "${REPO_ROOT_REAL}/content/home/.config/tmux/tmux.conf" ]
    grep -Fqx 'export DOTS_COMPONENTS="${DOTS_COMPONENTS:-none}"' "${LOCAL_ZSH}"
}

@test "a symlink at a declared path that points outside the repo survives" {
    _record tmux
    mkdir -p "${HOME}/.config/tmux"
    ln -s "${SANDBOX}/elsewhere/other.conf" "${HOME}/.config/tmux/tmux.conf"
    run sh "${CMD}" --yes none
    [ "${status}" -eq 0 ]
    [ -L "${HOME}/.config/tmux/tmux.conf" ]
    [ "$(readlink "${HOME}/.config/tmux/tmux.conf")" = "${SANDBOX}/elsewhere/other.conf" ]
}

@test "only the installed packages are uninstalled; missing ones are skipped without error" {
    _record tmux
    BREW_INSTALLED="tmux" run sh "${CMD}" --yes none
    [ "${status}" -eq 0 ]
    [ "$(_brew_calls)" = "brew uninstall tmux" ]

    _record tmux
    : > "${TOOL_LOG}"
    BREW_INSTALLED="" run sh "${CMD}" --yes none
    [ "${status}" -eq 0 ]
    [ -z "$(_brew_calls)" ]
    grep -Fqx 'export DOTS_COMPONENTS="${DOTS_COMPONENTS:-none}"' "${LOCAL_ZSH}"
}

# ── Confirmation ─────────────────────────────────────────────────────────────

@test "the confirmation lists exactly the packages and symlinks, and y removes them" {
    _require_script || skip "PTY script syntax unavailable"
    _record tmux
    _tmux_links
    BREW_INSTALLED="tmux gitmux" run _tty_components 'y' tmux ghostty
    # tmux stays: nothing to remove, no prompt
    [ "${status}" -eq 0 ]
    [ -z "$(_brew_calls)" ]

    BREW_INSTALLED="tmux gitmux" run _tty_components 'y' none
    [ "${status}" -eq 0 ]
    _has "brew uninstall tmux gitmux"
    _has "${HOME}/.config/tmux/tmux.conf"
    _has "${HOME}/.config/tmux/theme.conf"
    _has "[y/N]"
    [ "$(_brew_calls)" = "brew uninstall tmux gitmux" ]
    [ ! -L "${HOME}/.config/tmux/tmux.conf" ]
}

@test "declining (n, enter, q) removes nothing, records nothing and exits non-zero" {
    _require_script || skip "PTY script syntax unavailable"
    _record tmux
    _tmux_links
    cp "${LOCAL_ZSH}" "${SANDBOX}/local.before"

    for keys in 'n' '\n' 'q'; do
        BREW_INSTALLED="tmux gitmux" run _tty_components "${keys}" none
        [ "${status}" -ne 0 ]
        [ -z "$(_brew_calls)" ]
        [ -L "${HOME}/.config/tmux/tmux.conf" ]
        cmp -s "${LOCAL_ZSH}" "${SANDBOX}/local.before"
    done
}

@test "the interactive picker leads to the same confirmation" {
    _require_script || skip "PTY script syntax unavailable"
    _record tmux
    _tmux_links
    # space unchecks tmux, enter confirms the picker, y confirms the removal
    BREW_INSTALLED="tmux gitmux" run _tty_components ' \ny'
    [ "${status}" -eq 0 ]
    [ "$(_brew_calls)" = "brew uninstall tmux gitmux" ]
    grep -Fqx 'export DOTS_COMPONENTS="${DOTS_COMPONENTS:-none}"' "${LOCAL_ZSH}"

    _record tmux
    _tmux_links
    : > "${TOOL_LOG}"
    BREW_INSTALLED="tmux gitmux" run _tty_components ' \nn'
    [ "${status}" -ne 0 ]
    [ -z "$(_brew_calls)" ]
    grep -Fqx 'export DOTS_COMPONENTS="${DOTS_COMPONENTS:-tmux}"' "${LOCAL_ZSH}"
}

@test "without a TTY and without --yes a removing change exits 2 and changes nothing" {
    _record tmux
    _tmux_links
    cp "${LOCAL_ZSH}" "${SANDBOX}/local.before"
    BREW_INSTALLED="tmux gitmux" run sh "${CMD}" none
    [ "${status}" -eq 2 ]
    _has "--yes"
    _has "brew uninstall tmux gitmux"
    [ -z "$(_brew_calls)" ]
    [ -L "${HOME}/.config/tmux/tmux.conf" ]
    cmp -s "${LOCAL_ZSH}" "${SANDBOX}/local.before"
}

@test "unknown id still exits 1 with nothing removed or recorded" {
    _record tmux
    _tmux_links
    cp "${LOCAL_ZSH}" "${SANDBOX}/local.before"
    BREW_INSTALLED="tmux gitmux" run sh "${CMD}" --yes vim
    [ "${status}" -eq 1 ]
    _has "Unknown component 'vim'"
    [ -z "$(_brew_calls)" ]
    [ -L "${HOME}/.config/tmux/tmux.conf" ]
    cmp -s "${LOCAL_ZSH}" "${SANDBOX}/local.before"
}

# ── Herdr ────────────────────────────────────────────────────────────────────

@test "herdr-tui unchecked uninstalls the herdr formula and keeps the config while core remains" {
    _record herdr-tui herdr-core
    _repo_link .config/herdr/config.toml content/home/.config/herdr/config.toml
    BREW_INSTALLED="herdr" run sh "${CMD}" --yes herdr-core
    [ "${status}" -eq 0 ]
    [ "$(_brew_calls)" = "brew uninstall herdr" ]
    [ -L "${HOME}/.config/herdr/config.toml" ]
}

@test "the herdr config link goes only when no herdr component remains" {
    _record herdr-tui
    _repo_link .config/herdr/config.toml content/home/.config/herdr/config.toml
    BREW_INSTALLED="herdr" run sh "${CMD}" none
    [ "${status}" -eq 2 ]
    _has "brew uninstall herdr"
    _has "${HOME}/.config/herdr/config.toml"
    [ -L "${HOME}/.config/herdr/config.toml" ]
    BREW_INSTALLED="herdr" run sh "${CMD}" --yes none
    [ "${status}" -eq 0 ]
    [ ! -L "${HOME}/.config/herdr/config.toml" ]
}

@test "herdr-app unchecked while herdr-core is kept removes the app (macOS cask) and keeps the core" {
    _record herdr-app
    printf 'core\n' > "${HOME}/.local/bin/herdr-core"
    ln -s "${HOME}/.local/bin/herdr-core" "${HOME}/.local/bin/hc"
    _repo_link .config/herdr/config.toml content/home/.config/herdr/config.toml
    BREW_INSTALLED="herdr-app" run sh "${CMD}" --yes herdr-core
    [ "${status}" -eq 0 ]
    [ "$(_brew_calls)" = "brew uninstall --cask herdr-app" ]
    [ -f "${HOME}/.local/bin/herdr-core" ]
    [ -L "${HOME}/.local/bin/hc" ]
    [ -L "${HOME}/.config/herdr/config.toml" ]
    grep -Fqx 'export DOTS_COMPONENTS="${DOTS_COMPONENTS:-herdr-core}"' "${LOCAL_ZSH}"
}

@test "herdr-app on Linux: the official install dir, launcher and desktop files go; the core stays" {
    _record herdr-app
    export FAKE_UNAME=Linux
    mkdir -p "${HOME}/.local/share/herdr-app/bin" "${HOME}/.local/share/applications" \
        "${HOME}/.local/share/icons/hicolor/256x256/apps"
    printf 'app\n' > "${HOME}/.local/share/herdr-app/bin/herdr"
    ln -s "${HOME}/.local/share/herdr-app/bin/herdr" "${HOME}/.local/bin/herdr-app"
    printf '[Desktop Entry]\n' > "${HOME}/.local/share/applications/herdr-app.desktop"
    printf 'png\n' > "${HOME}/.local/share/icons/hicolor/256x256/apps/herdr-app.png"
    printf 'other\n' > "${HOME}/.local/share/applications/other.desktop"
    printf 'core\n' > "${HOME}/.local/bin/herdr-core"
    ln -s herdr-core "${HOME}/.local/bin/hc"

    run sh "${CMD}" --yes herdr-core
    [ "${status}" -eq 0 ]
    [ ! -e "${HOME}/.local/share/herdr-app" ]
    [ ! -L "${HOME}/.local/bin/herdr-app" ]
    [ ! -e "${HOME}/.local/share/applications/herdr-app.desktop" ]
    [ ! -e "${HOME}/.local/share/icons/hicolor/256x256/apps/herdr-app.png" ]
    [ -f "${HOME}/.local/share/applications/other.desktop" ]
    [ -f "${HOME}/.local/bin/herdr-core" ]
    [ -L "${HOME}/.local/bin/hc" ]
    [ -z "$(_brew_calls)" ]
}

@test "herdr-app Linux removal honors XDG_DATA_HOME" {
    _record herdr-app
    export FAKE_UNAME=Linux XDG_DATA_HOME="${SANDBOX}/xdg"
    mkdir -p "${SANDBOX}/xdg/herdr-app" "${HOME}/.local/share/herdr-app"
    run sh "${CMD}" --yes herdr-core
    [ "${status}" -eq 0 ]
    [ ! -e "${SANDBOX}/xdg/herdr-app" ]
    [ -d "${HOME}/.local/share/herdr-app" ]
}

@test "herdr-core unchecked removes its official bin files; hc and herdr-core only when files or symlinks" {
    _record herdr-core
    printf 'core\n' > "${HOME}/.local/bin/herdr-core"
    ln -s herdr-core "${HOME}/.local/bin/hc"
    printf 'keep\n' > "${HOME}/.local/bin/other-tool"
    run sh "${CMD}" --yes none
    [ "${status}" -eq 0 ]
    [ ! -e "${HOME}/.local/bin/herdr-core" ]
    [ ! -L "${HOME}/.local/bin/hc" ]
    [ -f "${HOME}/.local/bin/other-tool" ]
}

@test "herdr-core: a directory at the official path is warned about and left alone" {
    _record herdr-core
    mkdir -p "${HOME}/.local/bin/herdr-core/inner"
    printf 'core\n' > "${HOME}/.local/bin/hc"
    run sh "${CMD}" --yes none
    [ -d "${HOME}/.local/bin/herdr-core/inner" ]
    [ ! -e "${HOME}/.local/bin/hc" ]
    _has "WARN"
    _has "${HOME}/.local/bin/herdr-core"
    grep -Fqx 'export DOTS_COMPONENTS="${DOTS_COMPONENTS:-none}"' "${LOCAL_ZSH}"
}

@test "herdr-core implied by a kept herdr-app is never removed" {
    _record herdr-app
    printf 'core\n' > "${HOME}/.local/bin/herdr-core"
    run sh "${CMD}" --yes herdr-app
    [ "${status}" -eq 0 ]
    [ -f "${HOME}/.local/bin/herdr-core" ]
    [ -z "$(_brew_calls)" ]
}

# ── Ghostty ──────────────────────────────────────────────────────────────────

@test "ghostty unchecked on macOS uninstalls the cask and removes its repo links, not font.conf" {
    _record ghostty
    _ghostty_links
    printf 'font-family = X\n' > "${HOME}/.config/ghostty/font.conf"
    printf 'mine\n' > "${HOME}/.config/ghostty/notes.txt"
    BREW_INSTALLED="ghostty" run sh "${CMD}" --yes none
    [ "${status}" -eq 0 ]
    [ "$(_brew_calls)" = "brew uninstall --cask ghostty" ]
    [ ! -L "${HOME}/.config/ghostty/config" ]
    [ ! -L "${HOME}/.config/ghostty/shaders" ]
    [ ! -L "${HOME}/.config/ghostty/themes/dots" ]
    [ -f "${HOME}/.config/ghostty/font.conf" ]
    [ -f "${HOME}/.config/ghostty/notes.txt" ]
    [ -f "${REPO_ROOT_REAL}/content/home/.config/ghostty/config" ]
}

@test "ghostty unchecked on Linux removes the links and calls no brew" {
    _record ghostty
    export FAKE_UNAME=Linux
    _ghostty_links
    run sh "${CMD}" --yes none
    [ "${status}" -eq 0 ]
    [ ! -f "${TOOL_LOG}" ] || ! grep -q '^brew uninstall' "${TOOL_LOG}"
    [ ! -L "${HOME}/.config/ghostty/config" ]
}

# ── Failures ─────────────────────────────────────────────────────────────────

@test "a failing brew uninstall warns, continues, exits non-zero and still records the selection" {
    _record tmux ghostty
    _tmux_links
    _ghostty_links
    BREW_FAIL=1 BREW_INSTALLED="tmux gitmux ghostty" run sh "${CMD}" --yes none
    [ "${status}" -ne 0 ]
    _has "WARN"
    # both uninstalls were attempted and the links went regardless
    [ "$(_brew_calls | wc -l | tr -d ' ')" -eq 2 ]
    [ ! -L "${HOME}/.config/tmux/tmux.conf" ]
    [ ! -L "${HOME}/.config/ghostty/config" ]
    grep -Fqx 'export DOTS_COMPONENTS="${DOTS_COMPONENTS:-none}"' "${LOCAL_ZSH}"
}

@test "removal never reaches curl and --help documents --yes" {
    _record tmux
    BREW_INSTALLED="tmux gitmux" run sh "${CMD}" --yes none
    [ ! -f "${TOOL_LOG}" ] || ! grep -q '^curl' "${TOOL_LOG}"

    run sh "${CMD}" --help
    [ "${status}" -eq 0 ]
    _has "--yes"
    _has "uninstall"
}
