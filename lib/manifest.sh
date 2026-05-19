#!/bin/sh
# lib/manifest.sh — manifest read/write and source-hash utilities
# POSIX sh. Source this file; do not execute directly.
# Callers must have sourced lib/detect.sh and lib/log.sh.

# _mf_sha256 <path>
#   Internal helper: emit bare hex SHA-256 of a file.
_mf_sha256() {
    if command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "${1}" | cut -d' ' -f1
    elif command -v sha256sum >/dev/null 2>&1; then
        sha256sum "${1}" | cut -d' ' -f1
    else
        printf '_mf_sha256: no sha256 tool found\n' >&2
        return 1
    fi
}

# source_hash <repo_root>
#   Outputs the SHA-256 hex digest (64 chars) representing the deploy payload.
#   Covers every regular file under:
#     <repo_root>/home/.config/
#     <repo_root>/assets/themes/
#   Strategy: hash each file individually; collect "<hash>  <path>" lines
#   sorted by path; hash that listing → stable across platform + traversal order.
source_hash() {
    _sh_root="${1:?source_hash: repo_root required}"

    _sh_home_cfg="${_sh_root}/home/.config"
    _sh_themes="${_sh_root}/assets/themes"

    # Collect per-file hashes into a temp file so we can sort them
    _sh_tmp="$(mktemp)"

    find "${_sh_home_cfg}" "${_sh_themes}" -type f 2>/dev/null \
    | sort \
    | while IFS= read -r _sh_f; do
        _sh_h="$(_mf_sha256 "${_sh_f}")" || continue
        printf '%s  %s\n' "${_sh_h}" "${_sh_f}"
    done > "${_sh_tmp}"

    # Hash the sorted listing
    _sh_result="$(_mf_sha256 "${_sh_tmp}")"
    rm -f "${_sh_tmp}"
    printf '%s\n' "${_sh_result}"
}

# manifest_write <path> <theme> <flavor> <accent> <tools_csv> <source_hash>
#   Writes manifest.json atomically with stable key order.
#   Version is always "2.0.0".
manifest_write() {
    _mw_path="${1:?manifest_write: path required}"
    _mw_theme="${2:?manifest_write: theme required}"
    _mw_flavor="${3:?manifest_write: flavor required}"
    _mw_accent="${4:?manifest_write: accent required}"
    _mw_tools_csv="${5:?manifest_write: tools_csv required}"
    _mw_source_hash="${6:?manifest_write: source_hash required}"

    _mw_applied_at="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    _mw_tmp="${_mw_path}.tmp.$$"

    # Build tools JSON array from CSV
    _mw_tools_json="$(printf '%s' "${_mw_tools_csv}" \
        | tr ',' '\n' \
        | jq -Rn '[inputs | select(length>0)]')"

    jq -n \
        --arg version     "2.0.0" \
        --arg theme       "${_mw_theme}" \
        --arg flavor      "${_mw_flavor}" \
        --arg accent      "${_mw_accent}" \
        --argjson tools   "${_mw_tools_json}" \
        --arg source_hash "${_mw_source_hash}" \
        --arg applied_at  "${_mw_applied_at}" \
        '{
            version:     $version,
            theme:       $theme,
            flavor:      $flavor,
            accent:      $accent,
            tools:       $tools,
            source_hash: $source_hash,
            applied_at:  $applied_at
        }' > "${_mw_tmp}" && mv "${_mw_tmp}" "${_mw_path}"

    log_info "Manifest written: ${_mw_path}"
}

# manifest_read_field <path> <field>
#   Reads a single top-level field from manifest.json.
#   Returns empty string when the file is absent or the field is missing.
manifest_read_field() {
    _mrf_path="${1:?manifest_read_field: path required}"
    _mrf_field="${2:?manifest_read_field: field required}"

    if [ ! -f "${_mrf_path}" ]; then
        return 0
    fi
    jq -r ".${_mrf_field} // empty" "${_mrf_path}"
}
