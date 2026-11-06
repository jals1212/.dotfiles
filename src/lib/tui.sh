#!/bin/sh
# lib/tui.sh — shared TUI presentation helpers
# POSIX sh. Source this file; do not execute directly.
# Requires: lib/log.sh, lib/header.sh, jq, gum.

# shellcheck source=src/lib/log.sh
# shellcheck source=src/lib/header.sh

if ! command -v path_manifest >/dev/null 2>&1; then
    if [ -n "${REPO_ROOT:-}" ] && [ -f "${REPO_ROOT}/src/lib/paths.sh" ]; then
        # shellcheck disable=SC1091
        . "${REPO_ROOT}/src/lib/paths.sh"
    fi
fi

if ! command -v render_header >/dev/null 2>&1; then
    if [ -n "${REPO_ROOT:-}" ] && [ -f "$(path_src_lib header.sh)" ]; then
        # shellcheck disable=SC1091
        . "$(path_src_lib header.sh)"
    fi
fi

_tui_manifest_path() {
    path_manifest
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

# ---------------------------------------------------------------------------
# Main menu rows, in display order: maintain, appearance, danger, meta.
# Each row is "<value>|<description>"; the label shown is the value padded to
# a column followed by the description. No commas: gum splits --selected on
# commas, so a comma in a label breaks pre-selection.
# ---------------------------------------------------------------------------
_TUI_MENU_ROWS='update|Apply dotfiles and the active theme
upgrade|Bump vendored deps plus brew and mise
clean|Remove dead symlinks and stale backups
doctor|Health checks that change nothing
theme|Switch theme or flavor
prompt|Switch prompt engine: starship or p10k
uninstall|⚠ Remove managed symlinks and manifest
help|Show usage
quit|Exit'

# _tui_menu_label <value> — the label shown for a menu value (empty if unknown).
_tui_menu_label() {
    printf '%s\n' "${_TUI_MENU_ROWS}" | while IFS='|' read -r _tml_value _tml_desc; do
        if [ "${_tml_value}" = "${1:-}" ]; then
            printf '%-10s %s\n' "${_tml_value}" "${_tml_desc}"
        fi
    done
}

# _tui_git_summary — "✓ clean", "N changed", "N unpushed" or both; empty when
# REPO_ROOT is not a git work tree. Local only: never fetches.
_tui_git_summary() {
    _tgs_root="${REPO_ROOT:-.}"
    git -C "${_tgs_root}" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0
    _tgs_changed="$(git -C "${_tgs_root}" status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
    _tgs_ahead="$(git -C "${_tgs_root}" rev-list --count '@{u}..HEAD' 2>/dev/null || printf '0')"
    if [ "${_tgs_changed}" -eq 0 ] && [ "${_tgs_ahead}" -eq 0 ]; then
        printf '✓ clean'
        return 0
    fi
    _tgs_out=""
    [ "${_tgs_changed}" -gt 0 ] && _tgs_out="${_tgs_changed} changed"
    if [ "${_tgs_ahead}" -gt 0 ]; then
        [ -n "${_tgs_out}" ] && _tgs_out="${_tgs_out}, "
        _tgs_out="${_tgs_out}${_tgs_ahead} unpushed"
    fi
    printf '%s' "${_tgs_out}"
}

# render_menu_status — one-line menu header:
#   jals1212 DOTS · <theme[/flavor]> · <prompt> · <git summary>
# Prompt and git parts are omitted when unknown. Brand in the theme accent and
# the rest dimmed when stdout is a 256-color tty; plain text otherwise.
render_menu_status() {
    _rms_theme="$(_tui_active_theme)"
    _rms_prompt=""
    _rms_manifest="$(_tui_manifest_path)"
    if [ -f "${_rms_manifest}" ] && command -v jq >/dev/null 2>&1; then
        _rms_prompt="$(jq -r '.prompt // empty' "${_rms_manifest}" 2>/dev/null || printf '')"
    fi
    _rms_rest="${_rms_theme}"
    [ -n "${_rms_prompt}" ] && _rms_rest="${_rms_rest} · ${_rms_prompt}"
    _rms_git="$(_tui_git_summary)"
    [ -n "${_rms_git}" ] && _rms_rest="${_rms_rest} · ${_rms_git}"

    _rms_colors=0
    [ -t 1 ] && _rms_colors="$(tput colors 2>/dev/null || printf '8')"
    if [ "${_rms_colors}" -ge 256 ] 2>/dev/null; then
        printf '\033[1;38;5;%sm%s\033[0m \033[2m· %s\033[0m\n' \
            "$(_header_color_code "${_rms_theme}")" "jals1212 DOTS" "${_rms_rest}"
    else
        printf 'jals1212 DOTS · %s\n' "${_rms_rest}"
    fi
}

# render_action_menu [last] — gum picker over _TUI_MENU_ROWS; prints the chosen
# value. [last] (a value) is pre-selected; gum matches --selected by label.
render_action_menu() {
    _ram_accent="$(_header_color_code "$(_tui_active_theme)")"
    _ram_label="$(_tui_menu_label "${1:-}")"
    set -- --label-delimiter="|" --header="" \
        --cursor.foreground="${_ram_accent}" \
        --selected.foreground="${_ram_accent}" \
        --header.foreground="${_ram_accent}"
    [ -n "${_ram_label}" ] && set -- "$@" --selected="${_ram_label}"
    _ram_items="$(printf '%s\n' "${_TUI_MENU_ROWS}" | while IFS='|' read -r _ram_v _ram_d; do
        printf '%-10s %s|%s\n' "${_ram_v}" "${_ram_d}" "${_ram_v}"
    done)"
    _ram_old_ifs="${IFS}"
    IFS='
'
    # shellcheck disable=SC2086
    set -- "$@" ${_ram_items}
    IFS="${_ram_old_ifs}"
    gum choose "$@"
}
