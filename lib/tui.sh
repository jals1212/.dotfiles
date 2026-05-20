#!/bin/sh
# lib/tui.sh — shared TUI presentation helpers
# POSIX sh. Source this file; do not execute directly.
# Requires: lib/log.sh, lib/header.sh, jq, gum.

# shellcheck source=lib/log.sh
# shellcheck source=lib/header.sh

if ! command -v render_header >/dev/null 2>&1; then
    if [ -n "${REPO_ROOT:-}" ] && [ -f "${REPO_ROOT}/lib/header.sh" ]; then
        # shellcheck disable=SC1091
        . "${REPO_ROOT}/lib/header.sh"
    fi
fi

_tui_manifest_path() {
    printf '%s/manifest.json' "${REPO_ROOT:?REPO_ROOT required}"
}

_tui_active_theme() {
    _tat_manifest="$(_tui_manifest_path)"
    if [ -f "${_tat_manifest}" ] && command -v jq >/dev/null 2>&1; then
        _tat_theme="$(jq -r '.theme // empty' "${_tat_manifest}" 2>/dev/null || printf '')"
        _tat_flavor="$(jq -r '.flavor // empty' "${_tat_manifest}" 2>/dev/null || printf '')"
        if [ -n "${_tat_theme}" ]; then
            if [ -n "${_tat_flavor}" ]; then
                printf '%s/%s\n' "${_tat_theme}" "${_tat_flavor}"
            else
                printf '%s\n' "${_tat_theme}"
            fi
            return 0
        fi
    fi
    printf 'kanagawa\n'
}

tui_subtitle_for() {
    case "${1:-}" in
        init) printf 'Init' ;;
        update) printf 'Update' ;;
        sync) printf 'Sync' ;;
        backup) printf 'Backup' ;;
        doctor) printf 'Doctor' ;;
        restore) printf 'Restore' ;;
        uninstall) printf 'Uninstall' ;;
        *) printf '%s' "${1:-Dotfiles Manager}" ;;
    esac
}

render_command_banner() {
    _rcb_subtitle="${1:-}"
    _rcb_theme="$(_tui_active_theme)"
    render_header "${_rcb_theme}" "${_rcb_subtitle}"
}

render_subcommand_banner() {
    [ "${DOTS_MENU_DISPATCH:-0}" = "1" ] && return 0
    render_command_banner "${1:-}"
}

tui_start_timer() {
    TUI_START_EPOCH="$(date +%s)"
    export TUI_START_EPOCH
}

tui_elapsed_seconds() {
    _tes_now="$(date +%s)"
    _tes_start="${TUI_START_EPOCH:-${_tes_now}}"
    _tes_elapsed=$((_tes_now - _tes_start))
    [ "${_tes_elapsed}" -lt 0 ] 2>/dev/null && _tes_elapsed=0
    printf '%s' "${_tes_elapsed}"
}

log_success() {
    _ls_title="${1:?log_success: title required}"
    shift || true

    _ls_accent="$(_header_color_code "$(_tui_active_theme)")"
    _ls_elapsed="$(tui_elapsed_seconds)"
    _ls_text="${_ls_title} · ${_ls_elapsed}s"

    for _ls_line in "$@"; do
        _ls_text="${_ls_text}
${_ls_line}"
    done

    gum style \
        --border rounded \
        --border-foreground "${_ls_accent}" \
        --padding "1 2" \
        --bold \
        "${_ls_text}"
}

render_action_menu() {
    _ram_selected="${1:-}"
    _ram_sel_arg=""
    if [ -n "${_ram_selected}" ]; then
        _ram_sel_arg="--selected=${_ram_selected}"
    fi
    # shellcheck disable=SC2086
    gum choose \
        --header "Choose an action" \
        ${_ram_sel_arg} \
        update sync backup doctor restore uninstall help quit
}
