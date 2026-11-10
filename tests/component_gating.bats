#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
# tests/component_gating.bats
# The selected terminal components (DOTS_COMPONENTS in ~/.config/zsh/local.zsh)
# gate what ./dots links, themes and checks: the dotbot link predicates, the
# theme apply (tmux reload, Herdr fence/reload, Ghostty theme link) and the
# doctor checks. Every run uses a sandbox HOME and stub tools; nothing calls
# brew, curl or the network.

REPO_ROOT_REAL="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
ALL_COMPONENTS="tmux herdr-tui herdr-core herdr-app ghostty"
HELPER="content/home/.config/dots/component-selected.sh"

setup() {
    SANDBOX="$(cd "$(mktemp -d)" && pwd -P)"
    export HOME="${SANDBOX}/home"
    SHIMS="${SANDBOX}/shims"
    mkdir -p "${HOME}/.config/zsh" "${SHIMS}"
    export NO_COLOR=1
}

teardown() {
    rm -rf "${SANDBOX}"
}

# _record <ids...> — record a selection in the sandbox local.zsh.
_record() {
    printf 'export DOTS_COMPONENTS="${DOTS_COMPONENTS:-%s}"\n' "$*" > "${HOME}/.config/zsh/local.zsh"
}

_has() { case "${output}" in *"$1"*) return 0 ;; esac; echo "missing: $1 in: ${output}"; return 1; }
_lacks() { case "${output}" in *"$1"*) echo "unexpected: $1 in: ${output}"; return 1 ;; esac; return 0; }

# ── The predicate helper ─────────────────────────────────────────────────────

# _selected <ids...> — run the helper from the repo root, like dotbot.
_selected() {
    cd "${REPO_ROOT_REAL}"
    run env -i HOME="${HOME}" PATH="/usr/bin:/bin" sh "${HELPER}" "$@"
}

@test "the predicate helper fails while nothing is recorded and for none" {
    _selected tmux
    [ "${status}" -eq 1 ]
    [ "${output}" = "" ]
    _record none
    _selected tmux
    [ "${status}" -eq 1 ]
    _selected herdr-core
    [ "${status}" -eq 1 ]
}

@test "the predicate helper succeeds when any given id is selected" {
    _record tmux ghostty
    _selected tmux
    [ "${status}" -eq 0 ]
    _selected herdr-tui herdr-core herdr-app ghostty
    [ "${status}" -eq 0 ]
    _selected herdr-tui herdr-core herdr-app
    [ "${status}" -eq 1 ]
}

@test "the predicate helper counts the core as selected with the app (implied)" {
    _record herdr-app
    _selected herdr-core
    [ "${status}" -eq 0 ]
}

@test "the predicate helper needs at least one id" {
    _selected
    [ "${status}" -eq 2 ]
}

# ── dotbot link predicates ──────────────────────────────────────────────────

# _links — "<destination><TAB><if predicate>" for every link of
# install.conf.yaml (empty predicate when the link has none).
_links() {
    python3 - "${REPO_ROOT_REAL}" <<'PY'
import os, sys
root = sys.argv[1]
sys.path.insert(0, os.path.join(root, "vendor/dotbot/lib/pyyaml/lib"))
import yaml
with open(os.path.join(root, "config/install.conf.yaml"), encoding="utf-8") as fh:
    conf = yaml.safe_load(fh)
for directive in conf:
    for dest, spec in (directive.get("link") or {}).items():
        cond = spec.get("if", "") if isinstance(spec, dict) else ""
        print("%s\t%s" % (dest, cond))
PY
}

# _linked <dest> — succeed when the link to <dest> would be made now (its
# predicate, if any, exits 0 in the repo root with the sandbox HOME).
_linked() {
    _cond="$(_links | awk -F'\t' -v d="$1" '$1 == d { print $2; found = 1 } END { exit !found }')" || {
        echo "no link for $1"; return 2; }
    [ -z "${_cond}" ] && return 0
    (cd "${REPO_ROOT_REAL}" && env HOME="${HOME}" PATH="${PATH}" sh -c "${_cond}")
}

TMUX_LINKS="~/.config/tmux/tmux.conf ~/.config/tmux/theme.conf ~/.config/tmux/scripts/session-picker.sh ~/.config/tmux/scripts/pin-plugins.sh"
HERDR_LINKS="~/.config/herdr/config.toml"
GHOSTTY_LINKS="~/.config/ghostty/config ~/.config/ghostty/shaders"
OTHER_LINKS="~/.zshenv ~/.config/zsh/.zshrc ~/.config/starship.toml ~/.config/mise/config.toml ~/.config/bat/config"

# _expect <linked ids...> — assert exactly the links of these groups are made.
# Groups: tmux herdr ghostty.
_expect() {
    for _g in tmux herdr ghostty; do
        case "${_g}" in
            tmux) _l="${TMUX_LINKS}" ;;
            herdr) _l="${HERDR_LINKS}" ;;
            ghostty) _l="${GHOSTTY_LINKS}" ;;
        esac
        _want=0
        for _w in "$@"; do [ "${_w}" = "${_g}" ] && _want=1; done
        for _d in ${_l}; do
            if _linked "${_d}"; then _got=1; else _got=0; fi
            [ "${_got}" -eq "${_want}" ] || { echo "${_d}: linked=${_got} want=${_want}"; return 1; }
        done
    done
}

@test "no tmux, herdr or ghostty config is linked while nothing is recorded or for none" {
    _expect
    _record none
    _expect
}

@test "each component links only its own configs" {
    _record tmux
    _expect tmux
    _record ghostty
    _expect ghostty
    _record herdr-tui
    _expect herdr
    _record herdr-core
    _expect herdr
    _record herdr-app herdr-core
    _expect herdr
}

@test "the ghostty configs are linked on Linux too when ghostty is selected" {
    printf '#!/bin/sh\necho Linux\n' > "${SHIMS}/uname"; chmod +x "${SHIMS}/uname"
    _record ghostty
    PATH="${SHIMS}:${PATH}" _expect ghostty
}

@test "with every component, every link is made and unrelated links never depend on the selection" {
    _record ${ALL_COMPONENTS}
    _expect tmux herdr ghostty
    # Links outside the three components carry no component predicate.
    for _d in ${OTHER_LINKS}; do
        _cond="$(_links | awk -F'\t' -v d="${_d}" '$1 == d { print $2 }')"
        [[ "${_cond}" != *component-selected* ]] || return 1
    done
    rm -f "${HOME}/.config/zsh/local.zsh"
    for _d in ${OTHER_LINKS}; do _linked "${_d}"; done
}

# ── Theme apply ─────────────────────────────────────────────────────────────

# _theme_repo — a sandbox copy of the repo whose dotbot steps only log; tmux
# and herdr stubs log every call. HOME is the sandbox home.
_theme_repo() {
    REPO="${SANDBOX}/repo"
    mkdir -p "${REPO}"
    cp -R "${REPO_ROOT_REAL}/src" "${REPO_ROOT_REAL}/content" "${REPO}/"
    cp "${REPO_ROOT_REAL}/dots" "${REPO}/dots"
    rm -f "${REPO}/content/home/.config/nvim/lua/dots-theme.lua"
    CALLS="${SANDBOX}/calls.log"; export CALLS; : > "${CALLS}"
    printf '%s\n' \
        'dotbot_check_submodules() { return 0; }' \
        'dotbot_theme_apply() { echo dotbot-theme >> "${CALLS}"; return 0; }' \
        >> "${REPO}/src/lib/dotbot.sh"
    for tool in bat tmux herdr; do
        printf '#!/bin/sh\necho "%s $*" >> "${CALLS}"\nexit 0\n' "${tool}" > "${SHIMS}/${tool}"
        chmod +x "${SHIMS}/${tool}"
    done
    HERDR_CONF="${REPO}/content/home/.config/herdr/config.toml"
}

_theme() {
    run --separate-stderr env PATH="${SHIMS}:${PATH}" sh "${REPO}/src/commands/theme.sh" "$@"
}

@test "theme apply skips the tmux reload and the Herdr fence and reload when nothing is selected" {
    _theme_repo
    cp "${HERDR_CONF}" "${SANDBOX}/herdr.before"
    _theme catppuccin latte
    [ "${status}" -eq 0 ]
    cmp -s "${HERDR_CONF}" "${SANDBOX}/herdr.before"
    run grep -E '^(tmux|herdr) ' "${CALLS}"
    [ "${status}" -ne 0 ]
    # Everything else still happens.
    grep -Fxq 'dotbot-theme' "${CALLS}"
    grep -q '^bat cache --build' "${CALLS}"
    grep -Fq '"theme": "catppuccin"' "${REPO}/manifest.json"
    grep -Fq 'DOTS_THEME="${DOTS_THEME:-catppuccin_latte}"' "${HOME}/.config/zsh/local.zsh"
    grep -Fq 'palette = "catppuccin_latte"' "${REPO}/content/home/.config/starship.toml"
}

@test "theme apply with every component rewrites the Herdr fence and reloads tmux and Herdr" {
    _theme_repo
    _record ${ALL_COMPONENTS}
    _theme catppuccin latte
    [ "${status}" -eq 0 ]
    grep -Fq 'name = "catppuccin-latte"' "${HERDR_CONF}"
    grep -Fxq 'tmux info' "${CALLS}"
    grep -Fxq 'tmux set-environment -g DOTS_THEME catppuccin_latte' "${CALLS}"
    grep -q '^tmux source-file ' "${CALLS}"
    grep -Fxq 'herdr status server' "${CALLS}"
    grep -Fxq 'herdr server reload-config' "${CALLS}"
    grep -Fxq 'dotbot-theme' "${CALLS}"
}

@test "theme apply reloads only tmux when only tmux is selected" {
    _theme_repo
    _record tmux
    cp "${HERDR_CONF}" "${SANDBOX}/herdr.before"
    _theme catppuccin latte
    [ "${status}" -eq 0 ]
    grep -Fxq 'tmux info' "${CALLS}"
    cmp -s "${HERDR_CONF}" "${SANDBOX}/herdr.before"
    run grep -E '^herdr ' "${CALLS}"
    [ "${status}" -ne 0 ]
}

@test "theme apply handles Herdr when only the Herdr core is selected, and not tmux" {
    _theme_repo
    _record herdr-core
    _theme catppuccin latte
    [ "${status}" -eq 0 ]
    grep -Fq 'name = "catppuccin-latte"' "${HERDR_CONF}"
    grep -Fxq 'herdr server reload-config' "${CALLS}"
    run grep -E '^tmux ' "${CALLS}"
    [ "${status}" -ne 0 ]
}

# dotbot_theme_apply: a stub wrapper records the per-theme config it is given.
_dotbot_repo() {
    REPO="${SANDBOX}/repo"
    mkdir -p "${REPO}"
    cp -R "${REPO_ROOT_REAL}/src" "${REPO_ROOT_REAL}/content" "${REPO}/"
    rm -f "${REPO}/src/install"
    printf '#!/bin/sh\ncp "$1" "%s/given.yaml"\n' "${SANDBOX}" > "${REPO}/src/install"
    chmod +x "${REPO}/src/install"
    printf '%s\n' 'dotbot_check_submodules() { return 0; }' >> "${REPO}/src/lib/dotbot.sh"
}

_dotbot_theme() {
    run env REPO_ROOT="${REPO}" PATH="${PATH}" sh -c "
        . '${REPO}/src/lib/paths.sh'; . '${REPO}/src/lib/log.sh'
        . '${REPO}/src/lib/theme.sh'; dotbot_theme_apply kanagawa wave"
}

@test "the per-theme link run leaves out the Ghostty theme link unless Ghostty is selected" {
    _dotbot_repo
    cfg="${REPO}/content/themes/kanagawa-wave.yaml"
    _dotbot_theme
    [ "${status}" -eq 0 ]
    run grep -F '.config/ghostty/themes/dots' "${SANDBOX}/given.yaml"
    [ "${status}" -ne 0 ]
    grep -Fq '.config/bat/themes/dots.tmTheme' "${SANDBOX}/given.yaml"
    grep -Fq '.config/bottom/bottom.toml' "${SANDBOX}/given.yaml"

    _record tmux herdr-tui
    _dotbot_theme
    run grep -F '.config/ghostty/themes/dots' "${SANDBOX}/given.yaml"
    [ "${status}" -ne 0 ]

    _record ghostty
    _dotbot_theme
    [ "${status}" -eq 0 ]
    cmp -s "${cfg}" "${SANDBOX}/given.yaml"
}

# ── Doctor ──────────────────────────────────────────────────────────────────

_sysbin() {
    _sb="${SANDBOX}/sysbin"
    [ -d "${_sb}" ] && return 0
    mkdir -p "${_sb}"
    for _f in /usr/bin/* /bin/*; do
        _n="${_f##*/}"
        # The component commands stay out, so the checks see them as missing
        # even on hosts that have them in /usr/bin (Ubuntu CI runners ship tmux).
        case "${_n}" in tmux | gitmux | herdr | ghostty) continue ;; esac
        [ -e "${_sb}/${_n}" ] || ln -s "${_f}" "${_sb}/${_n}"
    done
}

_doctor() {
    _sysbin
    run env -i HOME="${HOME}" PATH="${SHIMS}:${SANDBOX}/sysbin" NO_COLOR=1 REPO_ROOT="${REPO_ROOT_REAL}" \
        sh -c ". '${REPO_ROOT_REAL}/src/lib/log.sh'; . '${REPO_ROOT_REAL}/src/lib/doctor.sh'; $1"
}

TMUX_CHECKS='check_tmux check_tmux_link check_tmux_theme_link check_tmux_prefix check_tmux_theme'
HERDR_CHECKS='check_herdr check_herdr_link check_herdr_theme_fence'
GHOSTTY_CHECKS='check_ghostty_link check_ghostty_theme_link check_ghostty_theme_marker'

# _run_checks <checks> — run each check and print "<name> rc=<n>".
_run_checks() {
    _doctor "for c in $1; do \$c; echo \"\$c rc=\$?\"; done"
}

@test "doctor skips every tmux, Herdr and Ghostty check, passing, when nothing is selected" {
    printf '#!/bin/sh\necho Darwin\n' > "${SHIMS}/uname"; chmod +x "${SHIMS}/uname"
    _run_checks "${TMUX_CHECKS} ${HERDR_CHECKS} ${GHOSTTY_CHECKS}"
    [ "${status}" -eq 0 ]
    _has "[SKIP] tmux present: not selected"
    _has "[SKIP] tmux config: not selected"
    _has "[SKIP] tmux theme: not selected"
    _has "[SKIP] tmux prefix C-a: not selected"
    _has "[SKIP] tmux theme from DOTS_THEME + default: not selected"
    _has "[SKIP] herdr present: not selected"
    _has "[SKIP] herdr config: not selected"
    _has "[SKIP] herdr theme fence: not selected"
    _has "[SKIP] ghostty config: not selected"
    _has "[SKIP] ghostty theme: not selected"
    _has "[SKIP] ghostty theme = dots: not selected"
    _lacks "[FAIL]"
    _lacks "[PASS]"
    [ "$(printf '%s\n' "${output}" | grep -c ' rc=0$')" -eq 11 ]
}

@test "doctor skips them the same way for the none selection" {
    _record none
    _run_checks "${TMUX_CHECKS} ${HERDR_CHECKS} ${GHOSTTY_CHECKS}"
    _lacks "[FAIL]"
    [ "$(printf '%s\n' "${output}" | grep -c '^\[SKIP\] .*: not selected')" -eq 11 ]
}

@test "doctor checks only the selected components and skips the others" {
    printf '#!/bin/sh\necho Darwin\n' > "${SHIMS}/uname"; chmod +x "${SHIMS}/uname"
    _record tmux
    _run_checks "${TMUX_CHECKS} ${HERDR_CHECKS} ${GHOSTTY_CHECKS}"
    _has "[FAIL] tmux present: command not found: tmux"
    _has "[FAIL] tmux config: missing: ${HOME}/.config/tmux/tmux.conf"
    _has "[SKIP] herdr present: not selected"
    _has "[SKIP] herdr config: not selected"
    _has "[SKIP] ghostty config: not selected"
    _lacks "[FAIL] herdr"
    _lacks "[FAIL] ghostty"

    _record ghostty
    _run_checks "${TMUX_CHECKS} ${HERDR_CHECKS} ${GHOSTTY_CHECKS}"
    _has "[SKIP] tmux config: not selected"
    _has "[FAIL] ghostty config: missing: ${HOME}/.config/ghostty/config"
    _has "[FAIL] ghostty theme = dots: unreadable: ${HOME}/.config/ghostty/config"
    _lacks "[FAIL] tmux"
}

@test "doctor treats any Herdr component as selecting the Herdr config checks; the herdr command is the TUI's" {
    _record herdr-core
    _run_checks "${HERDR_CHECKS}"
    _has "[SKIP] herdr present: not selected"
    _has "[FAIL] herdr config: missing: ${HOME}/.config/herdr/config.toml"
    _has "[FAIL] herdr theme fence: unreadable: ${HOME}/.config/herdr/config.toml"

    _record herdr-tui
    _run_checks "${HERDR_CHECKS}"
    _has "[FAIL] herdr present: command not found: herdr"
}

@test "doctor with every component runs every check as before (macOS and Linux skips unchanged)" {
    _record ${ALL_COMPONENTS}
    printf '#!/bin/sh\necho Darwin\n' > "${SHIMS}/uname"; chmod +x "${SHIMS}/uname"
    _run_checks "${TMUX_CHECKS} ${HERDR_CHECKS} ${GHOSTTY_CHECKS}"
    _lacks "[SKIP]"
    _lacks "not selected"
    [ "$(printf '%s\n' "${output}" | grep -c ' rc=1$')" -eq 11 ]

    printf '#!/bin/sh\necho Linux\n' > "${SHIMS}/uname"
    _run_checks "${GHOSTTY_CHECKS}"
    _has "[SKIP] ghostty config: macOS only"
    _has "[SKIP] ghostty theme: macOS only"
    _has "[SKIP] ghostty theme = dots: macOS only"
    _lacks "not selected"
}

@test "doctor still reports a passing tmux check when tmux is selected and installed" {
    _record tmux
    printf '#!/bin/sh\nexit 0\n' > "${SHIMS}/tmux"; chmod +x "${SHIMS}/tmux"
    _run_checks "check_tmux"
    _has "[PASS] tmux present"
    _has "check_tmux rc=0"
}
