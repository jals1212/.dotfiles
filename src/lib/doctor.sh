#!/bin/sh
# lib/doctor.sh — non-mutating health checks for the dotbot model
# POSIX sh. Source this file; do not execute directly.
# Caller MUST have sourced lib/log.sh and exported REPO_ROOT.

if ! command -v path_manifest >/dev/null 2>&1; then
    if [ -n "${REPO_ROOT:-}" ] && [ -f "${REPO_ROOT}/src/lib/paths.sh" ]; then
        # shellcheck disable=SC1091
        . "${REPO_ROOT}/src/lib/paths.sh"
    fi
fi

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

# _doc_pass <label>
_doc_pass() { _log_line 76 '[PASS]' "${1}"; }
# _doc_fail <label> <reason>
_doc_fail() { _log_line 196 '[FAIL]' "${1}: ${2}"; }
# _doc_warn <label> <message>
_doc_warn() { _log_line 214 '[WARN]' "${1}: ${2}"; }
# _doc_skip <label> <reason>
_doc_skip() { _log_line 250 '[SKIP]' "${1}: ${2}"; }

_doc_managed_dirs() {
    if ! command -v dotbot_managed_dirs >/dev/null 2>&1; then
        if [ -n "${REPO_ROOT:-}" ] && [ -f "$(path_src_lib dotbot.sh)" ]; then
            # shellcheck disable=SC1091
            . "$(path_src_lib dotbot.sh)"
        fi
    fi

    if command -v dotbot_managed_dirs >/dev/null 2>&1; then
        dotbot_managed_dirs
        return $?
    fi

    _doc_fail "Dotbot-managed directories" "dotbot_managed_dirs unavailable"
    return 1
}

_doc_count_lines() {
    _dcl_pattern="${1:?_doc_count_lines: pattern required}"
    _dcl_file="${2:?_doc_count_lines: file required}"
    _dcl_count="$(grep -c "${_dcl_pattern}" "${_dcl_file}" 2>/dev/null || true)"
    printf '%s\n' "${_dcl_count:-0}" | awk 'NR == 1 { print ($0 ~ /^[0-9]+$/ ? $0 : 0); exit }'
}

# check_command <label> <cmd>
check_command() {
    if command -v "${2}" >/dev/null 2>&1; then
        _doc_pass "${1} present"
        return 0
    fi
    _doc_fail "${1} present" "command not found: ${2}"
    return 1
}

# check_docker_plugin <label> <subcommand>
#   Verifies CLI discovery only; `<subcommand> version` does not require a daemon.
check_docker_plugin() {
    if command -v docker >/dev/null 2>&1 && docker "${2}" version >/dev/null 2>&1; then
        _doc_pass "${1} present"
        return 0
    fi
    _doc_fail "${1} present" "Docker CLI plugin unavailable: docker ${2}"
    return 1
}

# check_symlink_into_repo <label> <path>
#   Pass: <path> exists, is a symlink, target resolves under $REPO_ROOT.
check_symlink_into_repo() {
    _cs_label="${1}"
    _cs_path="${2}"
    if [ ! -e "${_cs_path}" ] && [ ! -L "${_cs_path}" ]; then
        _doc_fail "${_cs_label}" "missing: ${_cs_path}"
        return 1
    fi
    if [ ! -L "${_cs_path}" ]; then
        _doc_fail "${_cs_label}" "not a symlink: ${_cs_path} (run ./dots update to repair)"
        return 1
    fi
    _cs_target="$(readlink -f "${_cs_path}" 2>/dev/null || true)"
    case "${_cs_target}" in
        "${REPO_ROOT}"/*) _doc_pass "${_cs_label}"; return 0 ;;
        *) _doc_fail "${_cs_label}" "target outside repo: ${_cs_target}"; return 1 ;;
    esac
}

# check_contains <label> <path> <needle>
check_contains() {
    _cc_label="${1}"; _cc_path="${2}"; _cc_needle="${3}"
    if [ ! -r "${_cc_path}" ]; then
        _doc_fail "${_cc_label}" "unreadable: ${_cc_path}"
        return 1
    fi
    if grep -qF -- "${_cc_needle}" "${_cc_path}"; then
        _doc_pass "${_cc_label}"
        return 0
    fi
    _doc_fail "${_cc_label}" "missing marker '${_cc_needle}' in ${_cc_path}"
    return 1
}

# ---------------------------------------------------------------------------
# Command availability
# ---------------------------------------------------------------------------
check_brew()    { check_command "Homebrew" brew; }
check_zsh()     { check_command "zsh" zsh; }
check_tmux()    { check_command "tmux" tmux; }
check_herdr()   { check_command "herdr" herdr; }
check_orbstack() { check_command "OrbStack CLI" orb; }
check_docker()  { check_command "Docker CLI" docker; }
check_docker_buildx() { check_docker_plugin "Docker Buildx" buildx; }
check_docker_compose() { check_docker_plugin "Docker Compose" compose; }
check_nvim()    { check_command "neovim" nvim; }
check_git()     { check_command "git" git; }
check_jq()      { check_command "jq" jq; }
check_gum()     { check_command "gum" gum; }
check_python3() { check_command "python3" python3; }

# ---------------------------------------------------------------------------
# Submodule presence
# ---------------------------------------------------------------------------
check_dotbot_submodule() {
    if [ -x "$(path_dotbot_bin)" ]; then
        _doc_pass "dotbot submodule"
        return 0
    fi
    _doc_fail "dotbot submodule" "missing dotbot/bin/dotbot (run: git submodule update --init --recursive)"
    return 1
}
check_dotbot_brew_plugin() {
    if [ -f "$(path_dotbot_brew_plugin)" ]; then
        _doc_pass "dotbot-brew plugin"
        return 0
    fi
    _doc_fail "dotbot-brew plugin" "missing plugins/dotbot-brew/brew.py"
    return 1
}
check_dotbot_mise_plugin() {
    if [ -f "$(path_dotbot_mise_plugin)" ]; then
        _doc_pass "dotbot-mise plugin"
        return 0
    fi
    _doc_fail "dotbot-mise plugin" "missing plugins/dotbot-mise/mise.py"
    return 1
}

# ---------------------------------------------------------------------------
# Required deployed paths (symlinks into repo)
# ---------------------------------------------------------------------------
check_zshrc_link()    { check_symlink_into_repo "ZDOTDIR .zshrc symlink"    "$(path_home_zshrc)"; }
check_zprofile_link() { check_symlink_into_repo "ZDOTDIR .zprofile symlink" "$(path_home_zprofile)"; }
check_zshenv_link()   { check_symlink_into_repo "home .zshenv symlink"      "$(path_home_zshenv)"; }
check_zdotdir_zshenv_link() { check_symlink_into_repo "ZDOTDIR .zshenv symlink" "$(path_home_zdotdir_zshenv)"; }
check_zsh_zinit_link(){ check_symlink_into_repo "zsh zinit"          "$(path_home_zsh_zinit)"; }
check_zsh_tools_link(){ check_symlink_into_repo "zsh tools"          "$(path_home_zsh_tools)"; }
check_zsh_prompt_link(){ check_symlink_into_repo "zsh prompt"        "$(path_home_zsh_prompt)"; }
check_zsh_plugins_link(){ check_symlink_into_repo "zsh plugins"      "$(path_home_zsh_plugins)"; }
check_nvim_link()     { check_symlink_into_repo "nvim init.lua"     "$(path_home_nvim_init)"; }
check_tmux_link()     { check_symlink_into_repo "tmux config"       "$(path_home_tmux_config)"; }
check_tmux_theme_link() { check_symlink_into_repo "tmux theme"       "$(path_home_tmux_theme)"; }
check_ghostty_link()  { check_symlink_into_repo "ghostty config"    "$(path_home_ghostty_config)"; }
check_herdr_link()    { check_symlink_into_repo "herdr config"      "$(path_home_herdr_config)"; }
check_mise_link()     { check_symlink_into_repo "mise config"       "$(path_home_mise_config)"; }
check_starship_link() { check_symlink_into_repo "starship config"   "$(path_home_starship_config)"; }
check_bat_config_link() { check_symlink_into_repo "bat config"       "$(path_home_bat_config)"; }
check_fzf_config_link() { check_symlink_into_repo "fzf config"       "$(path_home_fzf_config)"; }
check_eza_config_link() { check_symlink_into_repo "eza config"       "$(path_home_eza_config)"; }

# ---------------------------------------------------------------------------
# Theme symlinks (managed by per-theme dotbot config)
# ---------------------------------------------------------------------------
check_bat_theme_link()     { check_symlink_into_repo "bat theme"        "$(path_home_bat_theme)"; }
check_fzf_theme_link()     { check_symlink_into_repo "fzf theme"        "$(path_home_fzf_theme)"; }
check_eza_theme_link()     { check_symlink_into_repo "eza theme"        "$(path_home_eza_theme)"; }
check_lazygit_theme_link() { check_symlink_into_repo "lazygit theme"    "$(path_home_lazygit_theme)"; }
check_bottom_theme_link()  { check_symlink_into_repo "bottom theme"     "$(path_home_bottom_theme)"; }
check_ghostty_theme_link() { check_symlink_into_repo "ghostty theme"    "$(path_home_ghostty_theme)"; }

# ---------------------------------------------------------------------------
# Theme symlinks agreement
# ---------------------------------------------------------------------------
check_theme_symlinks_agree() {
    _ctsa_label="theme symlinks agreement"
    _ctsa_expected=""
    _ctsa_disagreed=""
    for _ctsa_link in \
        "$(path_home_fzf_theme)" \
        "$(path_home_eza_theme)" \
        "$(path_home_bottom_theme)" \
        "$(path_home_lazygit_theme)"
    do
        [ -L "${_ctsa_link}" ] || continue
        _ctsa_t="$(readlink -f "${_ctsa_link}" 2>/dev/null || true)"
        _ctsa_key="$(printf '%s' "${_ctsa_t}" | sed -n 's|.*content/assets/palettes/[^/]*/\([^/]*\)/\([^.]*\)\..*|\1/\2|p')"
        [ -n "${_ctsa_key}" ] || continue
        if [ -z "${_ctsa_expected}" ]; then
            _ctsa_expected="${_ctsa_key}"
        elif [ "${_ctsa_key}" != "${_ctsa_expected}" ]; then
            _ctsa_disagreed="${_ctsa_disagreed} ${_ctsa_link}=${_ctsa_key}"
        fi
    done
    if [ -z "${_ctsa_expected}" ]; then
        _doc_skip "${_ctsa_label}" "no theme symlinks resolved"
        return 0
    fi
    if [ -n "${_ctsa_disagreed}" ]; then
        _doc_fail "${_ctsa_label}" "expected=${_ctsa_expected} but disagree:${_ctsa_disagreed}"
        return 1
    fi
    _doc_pass "${_ctsa_label} (${_ctsa_expected})"
    return 0
}

# ---------------------------------------------------------------------------
# Content markers
# ---------------------------------------------------------------------------
check_tmux_prefix() {
    check_contains "tmux prefix C-a" "$(path_home_tmux_config)" 'set -g prefix C-a'
}
check_ghostty_theme_marker() {
    check_contains "ghostty theme = dots" "$(path_home_ghostty_config)" 'theme = dots'
}
check_bat_config_theme() {
    check_contains 'bat config theme' "$(path_home_bat_config)" '--theme=dots'
}
check_fzf_shell_integration() {
    check_contains 'fzf shell integration' "$(path_home_fzf_config)" 'fzf --zsh'
}
check_eza_theme_source() {
    check_contains 'eza theme source' "$(path_home_eza_config)" '/eza/theme.sh'
}
check_starship_init() {
    check_contains 'starship zsh init' "$(path_home_zsh_prompt)" 'starship init zsh'
}

# ---------------------------------------------------------------------------
# Tmux theme (driven by DOTS_THEME)
# ---------------------------------------------------------------------------
check_tmux_theme() {
    _ctf_label="tmux theme from DOTS_THEME + default"
    _ctf_conf="$(path_home_tmux_theme)"
    if [ ! -r "${_ctf_conf}" ]; then
        _doc_fail "${_ctf_label}" "unreadable: ${_ctf_conf}"
        return 1
    fi
    if ! grep -Fq 'set -g @themux_theme "${DOTS_THEME}"' "${_ctf_conf}"; then
        _doc_fail "${_ctf_label}" "theme.conf does not set @themux_theme from DOTS_THEME"
        return 1
    fi
    if ! grep -q "^set -g @themux_theme '" "${_ctf_conf}"; then
        _doc_fail "${_ctf_label}" "no default @themux_theme fallback line in theme.conf"
        return 1
    fi
    _doc_pass "${_ctf_label}"
    return 0
}

# ---------------------------------------------------------------------------
# Slim manifest validation
# ---------------------------------------------------------------------------
check_manifest_exists() {
    if [ -f "$(path_manifest)" ]; then
        _doc_pass "manifest.json exists"
        return 0
    fi
    _doc_fail "manifest.json exists" "missing (run ./dots update)"
    return 1
}
check_manifest_slim_schema() {
    _cms_label="manifest slim schema"
    _cms_m="$(path_manifest)"
    [ -f "${_cms_m}" ] || { _doc_skip "${_cms_label}" "no manifest"; return 0; }
    if ! command -v jq >/dev/null 2>&1; then
        _doc_skip "${_cms_label}" "jq not installed"
        return 0
    fi
    if ! jq -e . "${_cms_m}" >/dev/null 2>&1; then
        _doc_fail "${_cms_label}" "invalid JSON"
        return 1
    fi
    _cms_keys="$(jq -r 'keys | join(",")' "${_cms_m}")"
    case "${_cms_keys}" in
        "applied_at,flavor,prompt,theme,version") ;;
        *)
            if printf '%s' "${_cms_keys}" | grep -q 'source_hash\|deployed_at'; then
                _doc_fail "${_cms_label}" "legacy keys present: ${_cms_keys}"
            else
                _doc_fail "${_cms_label}" "key set mismatch: got ${_cms_keys}; expected applied_at,flavor,prompt,theme,version"
            fi
            return 1
            ;;
    esac
    _cms_prompt="$(jq -r '.prompt' "${_cms_m}")"
    case "${_cms_prompt}" in
        starship|p10k) ;;
        *) _doc_fail "${_cms_label}" "prompt not whitelisted: ${_cms_prompt}"; return 1 ;;
    esac
    _cms_theme="$(jq -r '.theme' "${_cms_m}")"
    _cms_flavor="$(jq -r '.flavor' "${_cms_m}")"
    case "${_cms_theme}" in
        kanagawa|catppuccin) ;;
        *) _doc_fail "${_cms_label}" "theme not whitelisted: ${_cms_theme}"; return 1 ;;
    esac
    case "${_cms_theme}:${_cms_flavor}" in
        kanagawa:dragon|kanagawa:lotus|kanagawa:wave) ;;
        catppuccin:frappe|catppuccin:latte|catppuccin:macchiato|catppuccin:mocha) ;;
        *) _doc_fail "${_cms_label}" "flavor invalid for theme: ${_cms_theme}/${_cms_flavor}"; return 1 ;;
    esac
    _doc_pass "${_cms_label} (${_cms_theme}/${_cms_flavor})"
    return 0
}
check_starship_fence() {
    _csf_label="starship theme fence"
    _csf_conf="$(path_home_starship_config)"
    if [ ! -r "${_csf_conf}" ]; then
        _doc_fail "${_csf_label}" "unreadable: ${_csf_conf}"
        return 1
    fi
    _csf_open="$(_doc_count_lines '^# >>> dots:theme >>>$' "${_csf_conf}")"
    _csf_close="$(_doc_count_lines '^# <<< dots:theme <<<$' "${_csf_conf}")"
    if [ "${_csf_open}" = 1 ] && [ "${_csf_close}" = 1 ]; then
        if grep -q '^palette = ' "${_csf_conf}"; then
            _doc_pass "${_csf_label}"
            return 0
        fi
        _doc_fail "${_csf_label}" "fence present but no 'palette =' line between markers"
        return 1
    fi
    _doc_fail "${_csf_label}" "expected exactly one open + one close fence (got open=${_csf_open}, close=${_csf_close})"
    return 1
}
check_herdr_theme_fence() {
    _chtf_label="herdr theme fence"
    _chtf_conf="$(path_home_herdr_config)"
    if [ ! -r "${_chtf_conf}" ]; then
        _doc_fail "${_chtf_label}" "unreadable: ${_chtf_conf}"
        return 1
    fi
    _chtf_open="$(_doc_count_lines '^# >>> dots:theme >>>$' "${_chtf_conf}")"
    _chtf_close="$(_doc_count_lines '^# <<< dots:theme <<<$' "${_chtf_conf}")"
    if [ "${_chtf_open}" = 1 ] && [ "${_chtf_close}" = 1 ]; then
        if grep -q '^name = ' "${_chtf_conf}"; then
            _doc_pass "${_chtf_label}"
            return 0
        fi
        _doc_fail "${_chtf_label}" "fence present but no 'name =' line between markers"
        return 1
    fi
    _doc_fail "${_chtf_label}" "expected exactly one open + one close fence (got open=${_chtf_open}, close=${_chtf_close})"
    return 1
}
check_local_state() {
    _cls_label="machine-local zsh state"
    _cls_file="$(path_home_zsh_local)"
    if [ ! -f "${_cls_file}" ]; then
        _doc_pass "${_cls_label} (absent; defaults apply)"
        return 0
    fi
    if [ -L "${_cls_file}" ]; then
        _doc_fail "${_cls_label}" "must be a real file, found a symlink: ${_cls_file}"
        return 1
    fi
    _cls_prompt="$(sed -n 's/^export DOTS_PROMPT="\${DOTS_PROMPT:-\(.*\)}"$/\1/p' "${_cls_file}" | head -1)"
    case "${_cls_prompt:-starship}" in
        starship|p10k) ;;
        *) _doc_fail "${_cls_label}" "DOTS_PROMPT not whitelisted: ${_cls_prompt}"; return 1 ;;
    esac
    _doc_pass "${_cls_label}"
    return 0
}

# ---------------------------------------------------------------------------
# Stale dotbot-backup warning (non-fatal)
# ---------------------------------------------------------------------------
check_stale_backups() {
    _csb_label="stale dotbot-backup files"
    _csb_count="$(
        _doc_managed_dirs | while IFS= read -r _csb_dir; do
            [ -d "${_csb_dir}" ] || continue
            find "${_csb_dir}" -maxdepth 1 -type f -name '*.dotbot-backup.*' -mtime +29 2>/dev/null
        done | wc -l | tr -d ' '
    )"
    if [ "${_csb_count:-0}" -gt 0 ]; then
        _doc_warn "${_csb_label}" "${_csb_count} file(s) older than 30 days (run ./dots clean)"
    else
        _doc_pass "${_csb_label}"
    fi
    return 0
}

# ---------------------------------------------------------------------------
# Registry
# ---------------------------------------------------------------------------
DOCTOR_CHECKS="check_python3 check_brew check_zsh check_tmux check_herdr check_orbstack check_docker check_docker_buildx check_docker_compose check_nvim check_git check_jq check_gum check_dotbot_submodule check_dotbot_brew_plugin check_dotbot_mise_plugin check_zshrc_link check_zprofile_link check_zshenv_link check_zdotdir_zshenv_link check_zsh_zinit_link check_zsh_tools_link check_zsh_prompt_link check_zsh_plugins_link check_nvim_link check_tmux_link check_tmux_theme_link check_ghostty_link check_herdr_link check_mise_link check_starship_link check_bat_config_link check_fzf_config_link check_eza_config_link check_bat_theme_link check_fzf_shell_integration check_eza_theme_source check_starship_init check_tmux_theme check_starship_fence check_herdr_theme_fence check_local_state check_manifest_exists check_manifest_slim_schema check_stale_backups"
export DOCTOR_CHECKS
