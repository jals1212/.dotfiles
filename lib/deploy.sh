#!/bin/sh
# lib/deploy.sh — filesystem deploy functions for the dots deployer
# POSIX sh. Source this file; do not execute directly.
# Callers must have sourced lib/log.sh and lib/detect.sh before sourcing this.

# ---------------------------------------------------------------------------
# deploy_copy_home <repo_root>
#   Copies every file from <repo_root>/home/ into $HOME, preserving directory
#   structure and permissions.  Excludes .DS_Store files.
#   Uses a tar pipe for atomicity and portability (no rsync required).
# ---------------------------------------------------------------------------
deploy_copy_home() {
    _dch_root="${1:?deploy_copy_home: repo_root required}"
    _dch_src="${_dch_root}/home"

    log_step "Copying home payload to ${HOME}"
    mkdir -p "${HOME}"

    # tar pipe: exclude .DS_Store, preserve permissions, works on BSD+GNU.
    tar -C "${_dch_src}" \
        --exclude='.DS_Store' \
        --exclude='./.DS_Store' \
        -cf - . \
    | tar -C "${HOME}" -xf -

    log_info "Home payload deployed."
}

# ---------------------------------------------------------------------------
# deploy_apply_template <repo_root> <theme> <flavor>
#   Replaces template placeholders in the eight known template files that were
#   already deployed to $HOME/.config/ by deploy_copy_home.
#
#   Tokens substituted:
#     DOTS_THEME_FLAVOR  →  "<theme>/<flavor>"  (e.g. "kanagawa/dragon")
#     DOTS_THEME         →  "<theme>"
#     DOTS_FLAVOR        →  "<flavor>"
#
#   Uses portable sed -i.bak / rm pattern (BSD + GNU).
# ---------------------------------------------------------------------------
deploy_apply_template() {
    _dat_root="${1:?deploy_apply_template: repo_root required}"
    _dat_theme="${2:?deploy_apply_template: theme required}"
    _dat_flavor="${3:?deploy_apply_template: flavor required}"

    _dat_theme_flavor="${_dat_theme}/${_dat_flavor}"

    log_step "Applying template substitution (theme=${_dat_theme} flavor=${_dat_flavor})"

    # The eight template files (paths relative to $HOME/.config or $HOME)
    _dat_files="
${HOME}/.zshrc
${HOME}/.zprofile
${HOME}/.zshenv
${HOME}/.config/tmux/tmux.conf
${HOME}/.config/nvim/lua/plugins/colorschemes.lua
${HOME}/.config/nvim/lua/config/lazy.lua
${HOME}/.config/ghostty/config
${HOME}/.config/atuin/config.toml
"

    printf '%s\n' "${_dat_files}" | while IFS= read -r _dat_f; do
        # skip blank lines
        [ -z "${_dat_f}" ] && continue
        [ ! -f "${_dat_f}" ] && continue

        sed -i.bak \
            -e "s|DOTS_THEME_FLAVOR|${_dat_theme_flavor}|g" \
            -e "s|DOTS_THEME|${_dat_theme}|g" \
            -e "s|DOTS_FLAVOR|${_dat_flavor}|g" \
            "${_dat_f}" && rm -f "${_dat_f}.bak"

        log_info "Template applied: ${_dat_f}"
    done
}

# ---------------------------------------------------------------------------
# _deploy_titlecase <word>
#   Internal: emit word with first letter uppercased, rest unchanged.
#   Pure shell; no external tools.
# ---------------------------------------------------------------------------
_deploy_titlecase() {
    _dtc_word="${1}"
    # Extract first char and remainder via parameter expansion
    _dtc_first="$(printf '%s' "${_dtc_word}" | cut -c1 | tr '[:lower:]' '[:upper:]')"
    _dtc_rest="$(printf '%s' "${_dtc_word}" | cut -c2-)"
    printf '%s%s' "${_dtc_first}" "${_dtc_rest}"
}

# ---------------------------------------------------------------------------
# deploy_theme_assets <repo_root> <theme> <flavor>
#   Materializes eight theme-derived files from
#     <repo_root>/assets/themes/<tool>/<theme>/<source-file>
#   to their tool-specific destinations under $HOME/.config/.
#
#   Tool mapping:
#     oh-my-posh : assets/themes/oh-my-posh/<theme>/<flavor>.json
#                  → $HOME/.config/oh-my-posh/config.json
#     atuin      : kanagawa → assets/themes/atuin/kanagawa/<theme>-<flavor>.toml
#                  catppuccin → assets/themes/atuin/catppuccin/<flavor>.toml
#                  → $HOME/.config/atuin/themes/dots.toml
#                  (name = line patched to: name = "dots")
#     bottom     : assets/themes/bottom/<theme>/<flavor>.toml
#                  → $HOME/.config/bottom/bottom.toml
#     lazygit    : assets/themes/lazygit/<theme>/<flavor>.yml
#                  → $HOME/.config/lazygit/config.yml
#     bat        : assets/themes/bat/<theme>/<Titlecase-theme>-<flavor>.tmTheme
#                  → $HOME/.config/bat/themes/dots.tmTheme
#     eza        : assets/themes/eza/<theme>/<flavor>.txt
#                  → $HOME/.config/eza/themes/dots.sh
#     fzf        : assets/themes/fzf/<theme>/<flavor>.sh
#                  → $HOME/.config/fzf/themes/dots.sh
#     ghostty    : assets/themes/ghostty/<theme>/<flavor>.conf
#                  → $HOME/.config/ghostty/themes/dots
# ---------------------------------------------------------------------------
deploy_theme_assets() {
    _dta_root="${1:?deploy_theme_assets: repo_root required}"
    _dta_theme="${2:?deploy_theme_assets: theme required}"
    _dta_flavor="${3:?deploy_theme_assets: flavor required}"

    _dta_assets="${_dta_root}/assets/themes"

    log_step "Materializing theme assets (${_dta_theme}/${_dta_flavor})"

    # ── oh-my-posh ──────────────────────────────────────────────────────────
    _dta_src="${_dta_assets}/oh-my-posh/${_dta_theme}/${_dta_flavor}.json"
    _dta_dst="${HOME}/.config/oh-my-posh/config.json"
    if [ -f "${_dta_src}" ]; then
        mkdir -p "$(dirname "${_dta_dst}")"
        cp "${_dta_src}" "${_dta_dst}"
        log_info "oh-my-posh: ${_dta_dst}"
    else
        log_warn "oh-my-posh asset not found: ${_dta_src}"
    fi

    # ── atuin ───────────────────────────────────────────────────────────────
    # kanagawa uses compound filename: kanagawa-<flavor>.toml
    # catppuccin uses: <flavor>.toml
    if [ "${_dta_theme}" = "kanagawa" ]; then
        _dta_atuin_src="${_dta_assets}/atuin/${_dta_theme}/${_dta_theme}-${_dta_flavor}.toml"
    else
        _dta_atuin_src="${_dta_assets}/atuin/${_dta_theme}/${_dta_flavor}.toml"
    fi
    _dta_atuin_dst="${HOME}/.config/atuin/themes/dots.toml"
    if [ -f "${_dta_atuin_src}" ]; then
        mkdir -p "$(dirname "${_dta_atuin_dst}")"
        _dta_tmp="${_dta_atuin_dst}.tmp.$$"
        cp "${_dta_atuin_src}" "${_dta_tmp}"
        # Patch the name field to "dots" so atuin loads it as the "dots" theme
        sed -i.bak -e 's|^name = ".*"|name = "dots"|' "${_dta_tmp}" \
            && rm -f "${_dta_tmp}.bak"
        mv "${_dta_tmp}" "${_dta_atuin_dst}"
        log_info "atuin: ${_dta_atuin_dst}"
    else
        log_warn "atuin asset not found: ${_dta_atuin_src}"
    fi

    # ── bottom ───────────────────────────────────────────────────────────────
    _dta_src="${_dta_assets}/bottom/${_dta_theme}/${_dta_flavor}.toml"
    _dta_dst="${HOME}/.config/bottom/bottom.toml"
    if [ -f "${_dta_src}" ]; then
        mkdir -p "$(dirname "${_dta_dst}")"
        cp "${_dta_src}" "${_dta_dst}"
        log_info "bottom: ${_dta_dst}"
    else
        log_warn "bottom asset not found: ${_dta_src}"
    fi

    # ── lazygit ──────────────────────────────────────────────────────────────
    _dta_src="${_dta_assets}/lazygit/${_dta_theme}/${_dta_flavor}.yml"
    _dta_dst="${HOME}/.config/lazygit/config.yml"
    if [ -f "${_dta_src}" ]; then
        mkdir -p "$(dirname "${_dta_dst}")"
        cp "${_dta_src}" "${_dta_dst}"
        log_info "lazygit: ${_dta_dst}"
    else
        log_warn "lazygit asset not found: ${_dta_src}"
    fi

    # ── bat ──────────────────────────────────────────────────────────────────
    # Source files keep upstream-style naming (Kanagawa-dragon.tmTheme,
    # Catppuccin-mocha.tmTheme); destination is normalized to dots.tmTheme so
    # BAT_THEME=dots stays stable across flavor switches.
    _dta_theme_tc="$(_deploy_titlecase "${_dta_theme}")"
    _dta_flavor_tc="$(_deploy_titlecase "${_dta_flavor}")"
    _dta_bat_src_name="${_dta_theme_tc}-${_dta_flavor_tc}.tmTheme"
    _dta_src="${_dta_assets}/bat/${_dta_theme}/${_dta_bat_src_name}"
    _dta_bat_dst_dir="${HOME}/.config/bat/themes"
    _dta_dst="${_dta_bat_dst_dir}/dots.tmTheme"
    if [ -f "${_dta_src}" ]; then
        mkdir -p "${_dta_bat_dst_dir}"
        cp "${_dta_src}" "${_dta_dst}"
        log_info "bat: ${_dta_dst}"
    else
        log_warn "bat asset not found: ${_dta_src}"
    fi

    # ── eza ───────────────────────────────────────────────────────────────────
    _dta_src="${_dta_assets}/eza/${_dta_theme}/${_dta_flavor}.txt"
    _dta_dst="${HOME}/.config/eza/themes/dots.sh"
    if [ -f "${_dta_src}" ]; then
        mkdir -p "$(dirname "${_dta_dst}")"
        cp "${_dta_src}" "${_dta_dst}"
        log_info "eza: ${_dta_dst}"
    else
        log_warn "eza asset not found: ${_dta_src}"
    fi

    # ── fzf ───────────────────────────────────────────────────────────────────
    _dta_src="${_dta_assets}/fzf/${_dta_theme}/${_dta_flavor}.sh"
    _dta_dst="${HOME}/.config/fzf/themes/dots.sh"
    if [ -f "${_dta_src}" ]; then
        mkdir -p "$(dirname "${_dta_dst}")"
        cp "${_dta_src}" "${_dta_dst}"
        log_info "fzf: ${_dta_dst}"
    else
        log_warn "fzf asset not found: ${_dta_src}"
    fi

    # ── ghostty ──────────────────────────────────────────────────────────────
    _dta_src="${_dta_assets}/ghostty/${_dta_theme}/${_dta_flavor}.conf"
    _dta_dst="${HOME}/.config/ghostty/themes/dots"
    if [ -f "${_dta_src}" ]; then
        mkdir -p "$(dirname "${_dta_dst}")"
        cp "${_dta_src}" "${_dta_dst}"
        log_info "ghostty: ${_dta_dst}"
    else
        log_warn "ghostty asset not found: ${_dta_src}"
    fi

    log_info "Theme assets materialized."
}

# ---------------------------------------------------------------------------
# deploy_bat_cache
#   Runs `bat cache --build` to register theme files deployed under
#   $HOME/.config/bat/themes/ with bat's index.
#   Skips silently (with a warning) if bat is not installed.
# ---------------------------------------------------------------------------
deploy_bat_cache() {
    if ! has_command bat; then
        log_warn "bat not found — skipping bat cache build."
        return 0
    fi

    log_step "Building bat theme cache"
    bat cache --build >/dev/null 2>&1 || bat cache --build >&2
    log_info "bat cache built."
}

# ---------------------------------------------------------------------------
# apply_block <file> <block_id> <block_content>
#   Idempotently inserts or replaces a managed block in <file>.
#
#   Sentinel format:
#     # dots:<block_id> begin
#     <block_content>
#     # dots:<block_id> end
#
#   Behavior:
#   - If sentinels exist: replaces content between them with <block_content>.
#   - If sentinels absent: appends the full block (begin + content + end) to file.
#   - Always idempotent: running twice produces identical output.
# ---------------------------------------------------------------------------
apply_block() {
    _ab_file="${1:?apply_block: file required}"
    _ab_id="${2:?apply_block: block_id required}"
    _ab_content="${3:?apply_block: block_content required}"

    _ab_begin="# dots:${_ab_id} begin"
    _ab_end="# dots:${_ab_id} end"

    # Check whether sentinels exist
    if grep -qF "${_ab_begin}" "${_ab_file}" 2>/dev/null; then
        # Replace content between sentinels using awk
        _ab_tmp="${_ab_file}.tmp.$$"
        awk \
            -v begin="${_ab_begin}" \
            -v end="${_ab_end}" \
            -v content="${_ab_content}" \
            '
            $0 == begin { print; in_block=1; print content; next }
            $0 == end   { in_block=0 }
            !in_block   { print }
            ' "${_ab_file}" > "${_ab_tmp}" && mv "${_ab_tmp}" "${_ab_file}"
        log_info "Block updated: ${_ab_id} in ${_ab_file}"
    else
        # Append block to file
        printf '\n%s\n%s\n%s\n' \
            "${_ab_begin}" \
            "${_ab_content}" \
            "${_ab_end}" \
            >> "${_ab_file}"
        log_info "Block inserted: ${_ab_id} in ${_ab_file}"
    fi
}
