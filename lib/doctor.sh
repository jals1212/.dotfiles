#!/bin/sh
# lib/doctor.sh — doctor check primitives and concrete health checks
# POSIX sh. Source this file; do not execute directly.
# Callers must have set REPO_ROOT and sourced lib/log.sh.

# ---------------------------------------------------------------------------
# Primitives
# ---------------------------------------------------------------------------

# check_file <path> <label>
#   Pass when <path> is a regular file; fail otherwise.
#   Returns 0 on pass, 1 on fail.
check_file() {
    _cf_path="${1:?check_file: path required}"
    _cf_label="${2:?check_file: label required}"

    if [ -f "${_cf_path}" ]; then
        _log_line 82 '[PASS]' "${_cf_label}"
        return 0
    else
        _log_line 196 '[FAIL]' "${_cf_label}: file missing (${_cf_path})"
        return 1
    fi
}

# check_contains <path> <needle> <label>
#   Pass when <path> exists and contains the fixed string <needle>.
#   Returns 0 on pass, 1 on fail.
check_contains() {
    _cc_path="${1:?check_contains: path required}"
    _cc_needle="${2:?check_contains: needle required}"
    _cc_label="${3:?check_contains: label required}"

    if [ ! -f "${_cc_path}" ]; then
        _log_line 196 '[FAIL]' "${_cc_label}: file missing (${_cc_path})"
        return 1
    fi
    if grep -qF -- "${_cc_needle}" "${_cc_path}"; then
        _log_line 82 '[PASS]' "${_cc_label}"
        return 0
    else
        _log_line 196 '[FAIL]' "${_cc_label}: '${_cc_needle}' not found in ${_cc_path}"
        return 1
    fi
}

# check_json <path> <label>
#   Pass when <path> exists and is valid JSON (jq empty).
#   Returns 0 on pass, 1 on fail.
check_json() {
    _cj_path="${1:?check_json: path required}"
    _cj_label="${2:?check_json: label required}"

    if [ ! -f "${_cj_path}" ]; then
        _log_line 196 '[FAIL]' "${_cj_label}: file missing (${_cj_path})"
        return 1
    fi
    if jq empty "${_cj_path}" 2>/dev/null; then
        _log_line 82 '[PASS]' "${_cj_label}"
        return 0
    else
        _log_line 196 '[FAIL]' "${_cj_label}: invalid JSON (${_cj_path})"
        return 1
    fi
}

# check_command <name> <label>
#   Pass when <name> is found on PATH.
#   Returns 0 on pass, 1 on fail.
check_command() {
    _cmd_name="${1:?check_command: name required}"
    _cmd_label="${2:?check_command: label required}"

    if command -v "${_cmd_name}" >/dev/null 2>&1; then
        _log_line 82 '[PASS]' "${_cmd_label}"
        return 0
    else
        _log_line 196 '[FAIL]' "${_cmd_label}: command not found (${_cmd_name})"
        return 1
    fi
}

# ---------------------------------------------------------------------------
# Concrete checks — required commands (task 6.2, 6.3)
# ---------------------------------------------------------------------------

check_brew() {
    check_command brew "Homebrew installed"
}

check_zsh() {
    check_command zsh "zsh installed"
}

check_tmux() {
    check_command tmux "tmux installed"
}

check_nvim() {
    check_command nvim "nvim installed"
}

check_git() {
    check_command git "git installed"
}

check_jq() {
    check_command jq "jq installed"
}

check_gum() {
    check_command gum "gum installed"
}

# ---------------------------------------------------------------------------
# Concrete checks — manifest (task 6.2)
# ---------------------------------------------------------------------------

check_manifest_exists() {
    check_file "${REPO_ROOT}/manifest.json" "Manifest exists (post-apply)"
}

check_manifest_json() {
    check_json "${REPO_ROOT}/manifest.json" "Manifest is valid JSON"
}

# ---------------------------------------------------------------------------
# Concrete check — source hash drift (task 6.2)
# ---------------------------------------------------------------------------

# check_source_hash_match
#   Compares the current computed source_hash with the value stored in manifest.
#   Warns (non-fatal) on drift; fails only when manifest is present with a hash
#   that does not match.
check_source_hash_match() {
    _cshm_label="Source hash matches manifest"
    _cshm_manifest="${REPO_ROOT}/manifest.json"

    if [ ! -f "${_cshm_manifest}" ]; then
        _log_line 214 '[SKIP]' "${_cshm_label}: no manifest (run ./dots update first)"
        return 0
    fi

    # Source manifest.sh to get source_hash helper (detect.sh already sourced by caller)
    if [ -f "${REPO_ROOT}/lib/manifest.sh" ]; then
        # shellcheck source=lib/manifest.sh
        . "${REPO_ROOT}/lib/manifest.sh"
    fi

    _cshm_stored="$(manifest_read_field "${_cshm_manifest}" source_hash)"
    if [ -z "${_cshm_stored}" ]; then
        _log_line 214 '[SKIP]' "${_cshm_label}: no source_hash field in manifest"
        return 0
    fi

    _cshm_current="$(source_hash "${REPO_ROOT}")"
    if [ "${_cshm_current}" = "${_cshm_stored}" ]; then
        _log_line 82 '[PASS]' "${_cshm_label}"
        return 0
    else
        _log_line 214 '[WARN]' "${_cshm_label}: drift detected (stored=${_cshm_stored} current=${_cshm_current})"
        return 1
    fi
}

# ---------------------------------------------------------------------------
# Concrete checks — content markers (task 6.4)
# ---------------------------------------------------------------------------

check_tmux_prefix() {
    check_contains "${HOME}/.config/tmux/tmux.conf" \
        "set -g prefix C-a" \
        "tmux prefix is C-a"
}

check_ghostty_theme() {
    check_contains "${HOME}/.config/ghostty/config" \
        "theme = dots" \
        "ghostty theme = dots"
}

# check_bat_theme_block
#   Checks that both the begin and end sentinels for the BAT_THEME apply_block
#   are present in $HOME/.zshrc, and that the block contains the canonical
#   `export BAT_THEME="dots"` literal.
check_bat_theme_block() {
    _zshrc="${HOME}/.zshrc"
    _cbt_ok=0

    check_contains "${_zshrc}" \
        "# dots:bat-theme begin" \
        "BAT_THEME block begin sentinel in .zshrc" || _cbt_ok=1

    check_contains "${_zshrc}" \
        "# dots:bat-theme end" \
        "BAT_THEME block end sentinel in .zshrc" || _cbt_ok=1

    check_contains "${_zshrc}" \
        'export BAT_THEME="dots"' \
        'BAT_THEME="dots" literal in .zshrc' || _cbt_ok=1

    return "${_cbt_ok}"
}

check_bat_theme_dst() {
    check_file "${HOME}/.config/bat/themes/dots.tmTheme" \
        "bat dots.tmTheme deployed"
}

check_fzf_theme_dst() {
    check_file "${HOME}/.config/fzf/themes/dots.sh" \
        "fzf themes/dots.sh deployed"
}

check_eza_theme_dst() {
    check_file "${HOME}/.config/eza/themes/dots.sh" \
        "eza themes/dots.sh deployed"
}

# ---------------------------------------------------------------------------
# Registry — space-separated list consumed by commands/doctor.sh
# ---------------------------------------------------------------------------
# shellcheck disable=SC2034
DOCTOR_CHECKS="check_brew check_zsh check_tmux check_nvim check_git check_jq check_gum check_manifest_exists check_manifest_json check_source_hash_match check_tmux_prefix check_ghostty_theme check_bat_theme_block check_bat_theme_dst check_fzf_theme_dst check_eza_theme_dst"
export DOCTOR_CHECKS
