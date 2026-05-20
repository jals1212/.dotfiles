#!/bin/sh
# installer/e2e/e2e_arch.sh — E2E smoke test on archlinux:latest.
# Usage: sh installer/e2e/e2e_arch.sh
# Requires: docker (runs a container; does NOT run inline).
# Assertions per task 8.5:
#   - brew --version exits 0
#   - ./dots doctor exits 0
#   - idempotency: second ./dots sync produces no manifest hash change
set -eu

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
IMAGE="archlinux:latest"

printf 'E2E smoke test: %s\n' "${IMAGE}"
printf 'Repo root:      %s\n' "${REPO_ROOT}"

docker run --rm \
  --platform linux/amd64 \
  -v "${REPO_ROOT}:/repo" \
  -w /repo \
  -e NONINTERACTIVE=1 \
  "${IMAGE}" \
  sh -c '
    set -eu
    # Disable pacman 7+ ALPM sandbox (needs user namespace caps not granted in
    # default Docker; throws "switching to sandbox user alpm failed").
    sed -i "s/^DownloadUser/#DownloadUser/" /etc/pacman.conf 2>/dev/null || true
    sed -i "s/^[[:space:]]*Sandbox.*/Sandbox = no/" /etc/pacman.conf 2>/dev/null || true
    pacman -Sy --noconfirm curl git sudo base-devel ca-certificates

    # First run: bootstrap installs Homebrew + Brewfile + applies defaults
    ./bootstrap.sh --yes

    # bootstrap.sh sources brew shellenv internally; re-source it here so the
    # subsequent docker shell commands inherit brew on PATH.
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

    # Assert: Homebrew installed and on PATH
    brew --version

    # Assert: doctor passes
    ./dots doctor

    # Idempotency: capture source_hash before second apply
    hash_before="$(jq -r .source_hash manifest.json 2>/dev/null || printf none)"

    # Second sync: must be no-op (hash unchanged, no errors)
    ./dots sync

    hash_after="$(jq -r .source_hash manifest.json 2>/dev/null || printf none)"

    if [ "${hash_before}" != "${hash_after}" ]; then
      printf "FAIL: source_hash changed on second apply (%s -> %s)\n" \
        "${hash_before}" "${hash_after}" >&2
      exit 1
    fi

    printf "OK: idempotency verified (hash=%s)\n" "${hash_after}"
  '

printf 'PASS: %s\n' "${IMAGE}"
