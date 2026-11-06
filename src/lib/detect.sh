#!/bin/sh
# lib/detect.sh — OS detection
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
