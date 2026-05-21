#!/bin/sh
# lib/detect.sh — OS/arch detection and platform utilities
# POSIX sh. Source this file; do not execute directly.

# detect_os
#   Outputs one of: macos | linux | unknown
detect_os() {
    case "$(uname -s)" in
        Darwin) printf 'macos' ;;
        Linux)  printf 'linux' ;;
        *)      printf 'unknown' ;;
    esac
}

# detect_arch
#   Outputs one of: arm64 | x86_64 | unknown
detect_arch() {
    case "$(uname -m)" in
        arm64|aarch64) printf 'arm64'  ;;
        x86_64|amd64)  printf 'x86_64' ;;
        *)              printf 'unknown' ;;
    esac
}

# brew_prefix
#   Outputs the canonical Homebrew prefix for the current OS+arch.
#   Does not verify the prefix actually exists.
brew_prefix() {
    _bp_os="$(detect_os)"
    _bp_arch="$(detect_arch)"

    case "${_bp_os}" in
        macos)
            case "${_bp_arch}" in
                arm64)  printf '/opt/homebrew' ;;
                x86_64) printf '/usr/local' ;;
                *)      printf '/usr/local' ;;
            esac
            ;;
        linux)
            printf '/home/linuxbrew/.linuxbrew'
            ;;
        *)
            printf '/usr/local'
            ;;
    esac
}

# has_command <name>
#   Returns 0 if <name> is found on PATH, 1 otherwise.
has_command() {
    command -v "${1}" >/dev/null 2>&1
}

# sha256_file <path>
#   Outputs the bare lowercase hex SHA-256 digest of <path>.
#   Uses shasum on macOS, sha256sum on Linux.
sha256_file() {
    _sf_path="${1}"
    if has_command shasum; then
        shasum -a 256 "${_sf_path}" | cut -d' ' -f1
    elif has_command sha256sum; then
        sha256sum "${_sf_path}" | cut -d' ' -f1
    else
        printf 'sha256_file: no sha256 tool found\n' >&2
        return 1
    fi
}
