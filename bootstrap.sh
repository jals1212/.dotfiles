#!/bin/sh
# bootstrap.sh — backward-compat alias for `./dots update --yes "$@"`.
# Prefer `./dots` directly; ./dots auto-bootstraps on first run via
# lib/bootstrap.sh (called from lib/dotbot.sh:dotbot_check_submodules).
# This shim is kept for muscle memory and external automation that already
# points at ./bootstrap.sh.

set -eu

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
exec "${REPO_ROOT}/dots" update --yes "$@"
