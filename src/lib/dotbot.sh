#!/bin/sh
# lib/dotbot.sh — dotbot orchestration helpers
# POSIX sh. Source this file; do not execute directly.
# Requires: lib/log.sh sourced before this file.

if ! command -v path_manifest >/dev/null 2>&1; then
    if [ -n "${REPO_ROOT:-}" ] && [ -f "${REPO_ROOT}/src/lib/paths.sh" ]; then
        # shellcheck disable=SC1091
        . "${REPO_ROOT}/src/lib/paths.sh"
    fi
fi

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
    _dmd_configs_file="$(mktemp)"

    if ! command -v python3 >/dev/null 2>&1; then
        log_error "python3 not found; cannot derive Dotbot-managed directories"
        rm -f "${_dmd_configs_file}"
        return 1
    fi

    path_dotbot_config_files > "${_dmd_configs_file}"

    python3 - "${_dmd_home}" "${_dmd_configs_file}" <<'PY'
import os
import re
import sys

home = sys.argv[1]
configs_file = sys.argv[2]
with open(configs_file, encoding="utf-8") as fh:
    configs = [line.rstrip("\n") for line in fh if line.strip()]

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
    _dmd_status=$?
    rm -f "${_dmd_configs_file}"
    return "${_dmd_status}"
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
    _dml_configs_file="$(mktemp)"

    if ! command -v python3 >/dev/null 2>&1; then
        log_error "python3 not found; cannot derive Dotbot-managed links"
        rm -f "${_dml_configs_file}"
        return 1
    fi

    path_dotbot_config_files > "${_dml_configs_file}"

    python3 - "${_dml_home}" "${_dml_configs_file}" <<'PY'
import os
import re
import sys

home = sys.argv[1]
configs_file = sys.argv[2]
with open(configs_file, encoding="utf-8") as fh:
    configs = [line.rstrip("\n") for line in fh if line.strip()]

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
    _dml_status=$?
    rm -f "${_dml_configs_file}"
    return "${_dml_status}"
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
    if [ -f "$(path_src_lib bootstrap.sh)" ]; then
        # shellcheck source=src/lib/bootstrap.sh
        . "$(path_src_lib bootstrap.sh)"
        bootstrap_ensure
    fi

    _dcs_ok=1

    if [ ! -x "$(path_dotbot_bin)" ]; then
        log_error "dotbot submodule not initialized; run: git submodule update --init --recursive"
        _dcs_ok=0
    fi

    if [ ! -f "$(path_dotbot_brew_plugin)" ]; then
        log_error "dotbot-brew plugin missing; run: git submodule update --init --recursive"
        _dcs_ok=0
    fi

    if [ ! -f "$(path_dotbot_mise_plugin)" ]; then
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
    "$(path_install_wrapper)"
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

    _dta_config="$(path_theme_config "${_dta_theme}" "${_dta_flavor}")"
    if [ ! -f "${_dta_config}" ]; then
        log_error "Per-theme config not found: themes/${_dta_theme}-${_dta_flavor}.yaml"
        return 1
    fi

    log_step "Applying theme config: content/themes/${_dta_theme}-${_dta_flavor}.yaml"
    "$(path_install_wrapper)" "${_dta_config}"
}
