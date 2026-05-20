#!/bin/sh
# lib/backup.sh — pre-deploy backup and restore utilities
# POSIX sh. Source this file; do not execute directly.
# Callers must have sourced lib/log.sh.

# _backup_managed_paths
#   Lists all managed destination paths (under $HOME) that deploy owns.
#   Outputs one path per line.  Used by both backup_create and restore_from.
_backup_managed_paths() {
    printf '%s\n' \
        "${HOME}/.zshenv" \
        "${HOME}/.config/zsh" \
        "${HOME}/.config/nvim" \
        "${HOME}/.config/tmux" \
        "${HOME}/.config/ghostty" \
        "${HOME}/.config/atuin" \
        "${HOME}/.config/oh-my-posh" \
        "${HOME}/.config/aerospace" \
        "${HOME}/.config/bottom" \
        "${HOME}/.config/lazygit" \
        "${HOME}/.config/bat" \
        "${HOME}/.config/eza" \
        "${HOME}/.config/fzf"
}

# backup_create <repo_root>
#   Copies every managed path that exists in $HOME into
#   <repo_root>/.backups/YYYY-MM-DDTHH-MM-SSZ/.
#   Echoes the backup directory path to stdout.
#   If no managed files exist, prints nothing and returns 0.
backup_create() {
    _bc_root="${1:?backup_create: repo_root required}"

    _bc_stamp="$(date -u '+%Y-%m-%dT%H-%M-%SZ')"
    _bc_dir="${_bc_root}/.backups/${_bc_stamp}"

    _bc_any=0

    _backup_managed_paths | while IFS= read -r _bc_src; do
        if [ -e "${_bc_src}" ]; then
            _bc_any=1
            # Derive relative path under $HOME to replicate structure
            _bc_rel="${_bc_src#"${HOME}"/}"
            _bc_dest_dir="${_bc_dir}/$(dirname "${_bc_rel}")"
            mkdir -p "${_bc_dest_dir}"
            cp -R "${_bc_src}" "${_bc_dest_dir}/"
            log_step "Backed up ${_bc_src} → ${_bc_dest_dir}/"
        fi
    done

    # Determine if any files were actually backed up by checking if dir exists
    if [ -d "${_bc_dir}" ]; then
        log_ok "Backup → ${_bc_dir}"
        printf '%s\n' "${_bc_dir}"
    fi

    return 0
}

# backup_latest <repo_root>
#   Echoes the full path of the most-recent backup directory, or empty string
#   when no backups exist.
backup_latest() {
    _bl_root="${1:?backup_latest: repo_root required}"
    _bl_backups="${_bl_root}/.backups"

    if [ ! -d "${_bl_backups}" ]; then
        return 0
    fi

    _bl_latest="$(find "${_bl_backups}" -mindepth 1 -maxdepth 1 -type d -print 2>/dev/null \
        | sort -r | head -1 | xargs -I BL_PATH basename BL_PATH 2>/dev/null)"

    if [ -n "${_bl_latest}" ]; then
        printf '%s\n' "${_bl_backups}/${_bl_latest}"
    fi
}

# backup_list <repo_root>
#   Lists backup directories newest first, one absolute path per line.
backup_list() {
    _bls_root="${1:?backup_list: repo_root required}"
    _bls_backups="${_bls_root}/.backups"

    if [ ! -d "${_bls_backups}" ]; then
        return 0
    fi

    find "${_bls_backups}" -mindepth 1 -maxdepth 1 -type d -print 2>/dev/null | sort -r
}

# restore_from <repo_root> <backup_dir>
#   Copies contents of <backup_dir> back to $HOME, preserving structure.
#   Exits 1 if <backup_dir> does not exist.
restore_from() {
    _rf_root="${1:?restore_from: repo_root required}"
    _rf_backup="${2:?restore_from: backup_dir required}"

    if [ ! -d "${_rf_backup}" ]; then
        log_error "Backup directory not found: ${_rf_backup}"
        return 1
    fi

    log_step "Restoring from ${_rf_backup} → ${HOME}"

    # Walk every file in the backup and restore it
    find "${_rf_backup}" -type f | while IFS= read -r _rf_src; do
        _rf_rel="${_rf_src#"${_rf_backup}"/}"
        _rf_dest="${HOME}/${_rf_rel}"
        _rf_dest_dir="$(dirname "${_rf_dest}")"
        mkdir -p "${_rf_dest_dir}"
        cp -R "${_rf_src}" "${_rf_dest}"
        log_step "Restored ${_rf_dest}"
    done

    # Restore directory structures (symlinks, etc. not handled — plain files only)
    find "${_rf_backup}" -mindepth 1 -maxdepth 1 -type d | while IFS= read -r _rf_dir; do
        _rf_name="$(basename "${_rf_dir}")"
        cp -R "${_rf_dir}" "${HOME}/${_rf_name}"
        log_step "Restored directory ${HOME}/${_rf_name}"
    done

    log_info "Restore complete from ${_rf_backup}"
}
