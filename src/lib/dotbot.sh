#!/bin/sh
# lib/dotbot.sh — dotbot orchestration helpers
# POSIX sh. Source this file; do not execute directly.
# Requires: lib/log.sh sourced before this file.

# ---------------------------------------------------------------------------
# dotbot_managed_dirs
#   Print unique $HOME directories managed by the repository's Dotbot configs.
#   Source of truth:
#     - config/install.conf.yaml create: entries
#     - config/install.conf.yaml link: destination parents
#     - content/themes/*.yaml link: destination parents
#   Output is absolute, one directory per line. Uses python3 because dotbot
#   itself requires python3; parser intentionally handles only the Dotbot YAML
#   shapes used by this repo (top-level create/link directives).
# ---------------------------------------------------------------------------
dotbot_managed_dirs() {
    _dmd_root="${REPO_ROOT:?REPO_ROOT required}"
    _dmd_home="${HOME:?HOME required}"

    if ! command -v python3 >/dev/null 2>&1; then
        log_error "python3 not found; cannot derive Dotbot-managed directories"
        return 1
    fi

    python3 - "${_dmd_root}" "${_dmd_home}" <<'PY'
import glob
import os
import re
import sys

repo_root = sys.argv[1]
home = sys.argv[2]

configs = [os.path.join(repo_root, "config", "install.conf.yaml")]
configs.extend(sorted(glob.glob(os.path.join(repo_root, "content", "themes", "*.yaml"))))

dirs = set()


def expand_home(path):
    path = path.strip().strip("'\"")
    if not path or path.startswith("#"):
        return None
    if path == "~":
        return home
    if path.startswith("~/"):
        return os.path.join(home, path[2:])
    return None


def add_create(path):
    expanded = expand_home(path)
    if expanded:
        dirs.add(os.path.normpath(expanded))


def add_link_destination(path):
    expanded = expand_home(path)
    if expanded:
        dirs.add(os.path.dirname(os.path.normpath(expanded)))


top_directive = re.compile(r"^-\s+([A-Za-z0-9_-]+):")
list_item = re.compile(r"^\s+-\s+(.+?)\s*$")
link_key = re.compile(r"^    ([^:#][^:]*):(?:\s.*)?$")

for config in configs:
    if not os.path.isfile(config):
        continue

    mode = None
    with open(config, encoding="utf-8") as fh:
        for raw in fh:
            line = raw.rstrip("\n")
            stripped = line.strip()
            if not stripped or stripped.startswith("#"):
                continue

            m = top_directive.match(line)
            if m:
                mode = m.group(1)
                continue

            if mode == "create":
                m = list_item.match(line)
                if m:
                    add_create(m.group(1))
                continue

            if mode == "link":
                m = link_key.match(line)
                if m:
                    add_link_destination(m.group(1))
                continue

for directory in sorted(dirs):
    print(directory)
PY
}

# ---------------------------------------------------------------------------
# dotbot_managed_links
#   Print unique $HOME link destinations declared by the repository's Dotbot
#   configs. Source of truth:
#     - config/install.conf.yaml link: destinations
#     - content/themes/*.yaml link: destinations
#   Output is absolute, one path per line. This is intentionally destination-
#   based so destructive commands can operate on an allowlist instead of
#   recursively scanning $HOME.
# ---------------------------------------------------------------------------
dotbot_managed_links() {
    _dml_root="${REPO_ROOT:?REPO_ROOT required}"
    _dml_home="${HOME:?HOME required}"

    if ! command -v python3 >/dev/null 2>&1; then
        log_error "python3 not found; cannot derive Dotbot-managed links"
        return 1
    fi

    python3 - "${_dml_root}" "${_dml_home}" <<'PY'
import glob
import os
import re
import sys

repo_root = sys.argv[1]
home = sys.argv[2]

configs = [os.path.join(repo_root, "config", "install.conf.yaml")]
configs.extend(sorted(glob.glob(os.path.join(repo_root, "content", "themes", "*.yaml"))))

links = set()


def expand_home(path):
    path = path.strip().strip("'\"")
    if not path or path.startswith("#"):
        return None
    if path == "~":
        return home
    if path.startswith("~/"):
        return os.path.join(home, path[2:])
    return None


top_directive = re.compile(r"^-\s+([A-Za-z0-9_-]+):")
link_key = re.compile(r"^    ([^:#][^:]*):(?:\s.*)?$")

for config in configs:
    if not os.path.isfile(config):
        continue

    mode = None
    with open(config, encoding="utf-8") as fh:
        for raw in fh:
            line = raw.rstrip("\n")
            stripped = line.strip()
            if not stripped or stripped.startswith("#"):
                continue

            m = top_directive.match(line)
            if m:
                mode = m.group(1)
                continue

            if mode == "link":
                m = link_key.match(line)
                if m:
                    expanded = expand_home(m.group(1))
                    if expanded:
                        links.add(os.path.normpath(expanded))

for link in sorted(links):
    print(link)
PY
}

# ---------------------------------------------------------------------------
# dotbot_check_submodules
#   Ensure dotbot and plugin submodules are initialized (auto-bootstraps the
#   chicken-and-egg prereqs on a fresh machine via lib/bootstrap.sh), then
#   verifies the entry points are reachable. Returns 0 if all present, 1
#   with log_error if any are missing after the bootstrap attempt.
# ---------------------------------------------------------------------------
dotbot_check_submodules() {
    # Auto-bootstrap python3 + git + Linux build deps + submodules on first run.
    if [ -f "${REPO_ROOT}/src/lib/bootstrap.sh" ]; then
        # shellcheck source=src/lib/bootstrap.sh
        . "${REPO_ROOT}/src/lib/bootstrap.sh"
        bootstrap_ensure
    fi

    _dcs_ok=1

    if [ ! -x "${REPO_ROOT}/vendor/dotbot/bin/dotbot" ]; then
        log_error "dotbot submodule not initialized; run: git submodule update --init --recursive"
        _dcs_ok=0
    fi

    if [ ! -f "${REPO_ROOT}/vendor/plugins/dotbot-brew/brew.py" ]; then
        log_error "dotbot-brew plugin missing; run: git submodule update --init --recursive"
        _dcs_ok=0
    fi

    if [ ! -f "${REPO_ROOT}/vendor/plugins/dotbot-mise/mise.py" ]; then
        log_error "dotbot-mise plugin missing; run: git submodule update --init --recursive"
        _dcs_ok=0
    fi

    [ "${_dcs_ok}" -eq 1 ] || return 1
}

# ---------------------------------------------------------------------------
# dotbot_base_apply
#   Run the base dotbot config (install.conf.yaml) via the ./install wrapper.
#   Returns the wrapper's exit status.
# ---------------------------------------------------------------------------
dotbot_base_apply() {
    dotbot_check_submodules || return 1
    log_step "Running base dotbot config (install.conf.yaml)"
    "${REPO_ROOT}/src/install"
}

# ---------------------------------------------------------------------------
# dotbot_theme_apply <theme> <flavor>
#   Run the per-theme dotbot config for the given theme/flavor pair.
#   Returns the wrapper's exit status.
# ---------------------------------------------------------------------------
dotbot_theme_apply() {
    _dta_theme="${1:?dotbot_theme_apply: theme required}"
    _dta_flavor="${2:?dotbot_theme_apply: flavor required}"

    dotbot_check_submodules || return 1

    _dta_config="${REPO_ROOT}/content/themes/${_dta_theme}-${_dta_flavor}.yaml"
    if [ ! -f "${_dta_config}" ]; then
        log_error "Per-theme config not found: themes/${_dta_theme}-${_dta_flavor}.yaml"
        return 1
    fi

    log_step "Applying theme config: content/themes/${_dta_theme}-${_dta_flavor}.yaml"
    "${REPO_ROOT}/src/install" "${_dta_config}"
}
