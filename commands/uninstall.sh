#!/bin/sh
# commands/uninstall.sh — remove managed dotfiles payload and manifest
# POSIX sh. Invoked by the dots dispatcher or directly.

set -eu

# ---------------------------------------------------------------------------
# Help
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    # shellcheck disable=SC2016
    printf 'dots uninstall - remove managed configuration files from $HOME\n\n' >&2
    printf 'USAGE\n' >&2
    printf '  ./dots uninstall [--yes]\n\n' >&2
    printf 'FLAGS\n' >&2
    printf '  --yes    Skip confirmation prompt.\n\n' >&2
    # shellcheck disable=SC2016
    printf 'Removes managed config paths from $HOME and deletes manifest.json.\n' >&2
    printf "Does NOT restore a backup. Run './dots restore --latest' first.\n\n" >&2
    printf 'Managed paths: .zshenv, .config/zsh, nvim, tmux, ghostty, atuin,\n' >&2
    printf 'oh-my-posh, aerospace, bottom, lazygit, bat, eza, fzf\n' >&2
    exit 0
fi

# ---------------------------------------------------------------------------
# Compute REPO_ROOT
# ---------------------------------------------------------------------------
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export REPO_ROOT

# ---------------------------------------------------------------------------
# Source libs
# ---------------------------------------------------------------------------
# shellcheck source=lib/log.sh
. "${REPO_ROOT}/lib/log.sh"
# shellcheck source=lib/detect.sh
. "${REPO_ROOT}/lib/detect.sh"
# shellcheck source=lib/tui.sh
. "${REPO_ROOT}/lib/tui.sh"

tui_start_timer
render_subcommand_banner "$(tui_subtitle_for uninstall)"

# ---------------------------------------------------------------------------
# Parse flags
# ---------------------------------------------------------------------------
_yes=0
for _arg in "$@"; do
    case "${_arg}" in
        --yes|-y) _yes=1 ;;
    esac
done

if [ "${NONINTERACTIVE:-0}" = "1" ]; then
    _yes=1
fi

# ---------------------------------------------------------------------------
# Managed paths (mirrors lib/backup.sh _backup_managed_paths)
# ---------------------------------------------------------------------------
_managed_paths() {
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

# ---------------------------------------------------------------------------
# Confirmation (unless --yes / NONINTERACTIVE)
# ---------------------------------------------------------------------------
if [ "${_yes}" -eq 0 ]; then
    if has_command gum; then
        gum confirm "Remove all managed dotfiles from \$HOME and delete manifest.json?" || {
            log_warn "Uninstall cancelled."
            exit 1
        }
    else
        printf '[WARN] gum not found — falling back to read prompt.\n' >&2
        printf 'Remove all managed dotfiles and manifest.json? [y/N] ' >&2
        read -r _confirm
        case "${_confirm}" in
            [Yy]*) ;;
            *)
                log_warn "Uninstall cancelled."
                exit 1
                ;;
        esac
    fi
fi

# ---------------------------------------------------------------------------
# Remove managed paths
# ---------------------------------------------------------------------------
log_step "Removing managed config paths from \$HOME..."
_removed_count_file="$(mktemp)"
printf '0\n' > "${_removed_count_file}"
_managed_paths | while IFS= read -r _path; do
    if [ -e "${_path}" ] || [ -L "${_path}" ]; then
        rm -rf "${_path}"
        _removed_count="$(cat "${_removed_count_file}")"
        _removed_count=$((_removed_count + 1))
        printf '%s\n' "${_removed_count}" > "${_removed_count_file}"
        log_info "Removed: ${_path}"
    else
        log_info "Not present (skip): ${_path}"
    fi
done
_removed_count="$(cat "${_removed_count_file}")"
rm -f "${_removed_count_file}"

# ---------------------------------------------------------------------------
# Remove manifest.json
# ---------------------------------------------------------------------------
_manifest="${REPO_ROOT}/manifest.json"
_manifest_status="not present"
if [ -f "${_manifest}" ]; then
    rm -f "${_manifest}"
    _manifest_status="removed"
    log_info "Removed: ${_manifest}"
else
    log_info "manifest.json not present (skip)."
fi

log_success "Uninstall complete" \
    "removed_paths=${_removed_count}" \
    "manifest=${_manifest_status}" \
    "restore=./dots restore --latest"
