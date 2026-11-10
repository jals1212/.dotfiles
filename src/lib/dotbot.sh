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

if ! command -v components_has >/dev/null 2>&1; then
    if [ -n "${REPO_ROOT:-}" ] && [ -f "${REPO_ROOT}/src/lib/components.sh" ]; then
        # shellcheck disable=SC1091
        . "${REPO_ROOT}/src/lib/components.sh"
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

    python3 - "${_dmd_root}" "${_dmd_home}" "${_dmd_configs_file}" <<'PY'
import glob
import os
import sys

repo_root = sys.argv[1]
home = sys.argv[2]
configs_file = sys.argv[3]
sys.path.insert(0, os.path.join(repo_root, "vendor/dotbot/lib/pyyaml/lib"))

import yaml

with open(configs_file, encoding="utf-8") as fh:
    configs = [line.rstrip("\n") for line in fh if line.strip()]

dirs = set()


def expand_destination(path):
    path = str(path).strip().strip("'\"")
    if not path or path.startswith("#"):
        return None
    if path == "~":
        return home
    if path.startswith("~/"):
        return os.path.join(home, path[2:])
    return None


def source_pattern(path):
    if path is None:
        return None
    path = str(path).strip().strip("'\"")
    if not path:
        return None
    path = os.path.expandvars(os.path.expanduser(path))
    if os.path.isabs(path):
        return path
    return os.path.join(repo_root, path)


def default_source_for(destination):
    base = os.path.basename(os.path.normpath(str(destination)))
    if base.startswith("."):
        base = base[1:]
    return base


def excluded_matches(patterns):
    excluded = set()
    for pattern in patterns or []:
        resolved = source_pattern(pattern)
        if not resolved:
            continue
        excluded.update(os.path.normpath(match) for match in glob.glob(resolved, recursive=True))
    return excluded


def link_destinations(destination, spec):
    expanded = expand_destination(destination)
    if not expanded:
        return []

    glob_enabled = False
    path = None
    excludes = []
    prefix = ""

    if isinstance(spec, str):
        path = spec
    elif isinstance(spec, dict):
        path = spec.get("path")
        glob_enabled = bool(spec.get("glob", False))
        excludes = spec.get("exclude") or []
        prefix = str(spec.get("prefix") or "")
    elif spec is None:
        path = default_source_for(destination)
    else:
        return []

    if not glob_enabled:
        return [os.path.normpath(expanded)]

    resolved_pattern = source_pattern(path)
    if not resolved_pattern:
        return []

    excluded = excluded_matches(excludes)
    destinations = []
    for match in sorted(glob.glob(resolved_pattern, recursive=True)):
        normalized_match = os.path.normpath(match)
        if normalized_match in excluded:
            continue
        basename = os.path.basename(normalized_match)
        if not basename:
            continue
        destinations.append(os.path.normpath(os.path.join(expanded, f"{prefix}{basename}")))
    return destinations


def add_create(path):
    expanded = expand_destination(path)
    if expanded:
        dirs.add(os.path.normpath(expanded))


for config in configs:
    if not os.path.isfile(config):
        continue
    with open(config, encoding="utf-8") as fh:
        data = yaml.safe_load(fh) or []
    if not isinstance(data, list):
        continue

    for item in data:
        if not isinstance(item, dict):
            continue
        create = item.get("create")
        if isinstance(create, list):
            for created in create:
                add_create(created)

        link = item.get("link")
        if isinstance(link, dict):
            for destination, spec in link.items():
                for expanded in link_destinations(destination, spec):
                    dirs.add(os.path.dirname(os.path.normpath(expanded)))

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

    python3 - "${_dml_root}" "${_dml_home}" "${_dml_configs_file}" <<'PY'
import glob
import os
import sys

repo_root = sys.argv[1]
home = sys.argv[2]
configs_file = sys.argv[3]
sys.path.insert(0, os.path.join(repo_root, "vendor/dotbot/lib/pyyaml/lib"))

import yaml

with open(configs_file, encoding="utf-8") as fh:
    configs = [line.rstrip("\n") for line in fh if line.strip()]

links = set()


def expand_destination(path):
    path = str(path).strip().strip("'\"")
    if not path or path.startswith("#"):
        return None
    if path == "~":
        return home
    if path.startswith("~/"):
        return os.path.join(home, path[2:])
    return None


def source_pattern(path):
    if path is None:
        return None
    path = str(path).strip().strip("'\"")
    if not path:
        return None
    path = os.path.expandvars(os.path.expanduser(path))
    if os.path.isabs(path):
        return path
    return os.path.join(repo_root, path)


def default_source_for(destination):
    base = os.path.basename(os.path.normpath(str(destination)))
    if base.startswith("."):
        base = base[1:]
    return base


def excluded_matches(patterns):
    excluded = set()
    for pattern in patterns or []:
        resolved = source_pattern(pattern)
        if not resolved:
            continue
        excluded.update(os.path.normpath(match) for match in glob.glob(resolved, recursive=True))
    return excluded


def link_destinations(destination, spec):
    expanded = expand_destination(destination)
    if not expanded:
        return []

    glob_enabled = False
    path = None
    excludes = []
    prefix = ""

    if isinstance(spec, str):
        path = spec
    elif isinstance(spec, dict):
        path = spec.get("path")
        glob_enabled = bool(spec.get("glob", False))
        excludes = spec.get("exclude") or []
        prefix = str(spec.get("prefix") or "")
    elif spec is None:
        path = default_source_for(destination)
    else:
        return []

    if not glob_enabled:
        return [os.path.normpath(expanded)]

    resolved_pattern = source_pattern(path)
    if not resolved_pattern:
        return []

    excluded = excluded_matches(excludes)
    destinations = []
    for match in sorted(glob.glob(resolved_pattern, recursive=True)):
        normalized_match = os.path.normpath(match)
        if normalized_match in excluded:
            continue
        basename = os.path.basename(normalized_match)
        if not basename:
            continue
        destinations.append(os.path.normpath(os.path.join(expanded, f"{prefix}{basename}")))
    return destinations


for config in configs:
    if not os.path.isfile(config):
        continue
    with open(config, encoding="utf-8") as fh:
        data = yaml.safe_load(fh) or []
    if not isinstance(data, list):
        continue

    for item in data:
        if not isinstance(item, dict):
            continue
        link = item.get("link")
        if not isinstance(link, dict):
            continue
        for destination, spec in link.items():
            for expanded in link_destinations(destination, spec):
                links.add(os.path.normpath(expanded))

for link in sorted(links):
    print(link)
PY
    _dml_status=$?
    rm -f "${_dml_configs_file}"
    return "${_dml_status}"
}

# ---------------------------------------------------------------------------
# dotbot_links_config <config.yaml> <destination prefix>...
#   Print a Dotbot config holding the `defaults` of <config> and only its link:
#   entries whose destination (as written, e.g. ~/.config/tmux/tmux.conf)
#   starts with one of the prefixes, each with its own path/if/glob options.
#   Prints nothing when no entry matches. Used to make exactly the links of a
#   few components without running the rest of the config.
# ---------------------------------------------------------------------------
dotbot_links_config() {
    _dlc_root="${REPO_ROOT:?REPO_ROOT required}"
    _dlc_config="${1:?dotbot_links_config: config required}"
    shift

    if ! command -v python3 >/dev/null 2>&1; then
        log_error "python3 not found; cannot derive the Dotbot links"
        return 1
    fi

    python3 - "${_dlc_root}" "${_dlc_config}" "$@" <<'PY'
import os
import sys

repo_root = sys.argv[1]
config = sys.argv[2]
prefixes = tuple(sys.argv[3:])
sys.path.insert(0, os.path.join(repo_root, "vendor/dotbot/lib/pyyaml/lib"))

import yaml

with open(config, encoding="utf-8") as fh:
    data = yaml.safe_load(fh) or []

out = []
links = {}
for item in data if isinstance(data, list) else []:
    if not isinstance(item, dict):
        continue
    if isinstance(item.get("defaults"), dict) and not any("defaults" in o for o in out):
        out.append({"defaults": item["defaults"]})
    link = item.get("link")
    if isinstance(link, dict):
        for destination, spec in link.items():
            if str(destination).strip().startswith(prefixes):
                links[destination] = spec

if links:
    out.append({"link": links})
    sys.stdout.write(yaml.safe_dump(out, default_flow_style=False, sort_keys=False))
PY
}

# ---------------------------------------------------------------------------
# dotbot_links_apply <config.yaml> <destination prefix>...
#   Make only the links of <config> under the prefixes (dotbot_links_config),
#   through the Dotbot wrapper, so relink/backup/if: behave exactly as in a
#   full run. Nothing else of the config runs. Returns the wrapper's status.
# ---------------------------------------------------------------------------
dotbot_links_apply() {
    _dla_tmp="$(mktemp)" || return 1
    if ! dotbot_links_config "$@" > "${_dla_tmp}"; then
        rm -f "${_dla_tmp}"
        return 1
    fi
    if [ ! -s "${_dla_tmp}" ]; then
        rm -f "${_dla_tmp}"
        return 0
    fi
    "$(path_install_wrapper)" "${_dla_tmp}"
    _dla_rc=$?
    rm -f "${_dla_tmp}"
    return "${_dla_rc}"
}

# ---------------------------------------------------------------------------
# dotbot_filter_repo_owned_links
#   Read symlink paths (one per line) on stdin; print only those whose link
#   target points inside REPO_ROOT. Relative targets are resolved against the
#   link's own directory; the physical (symlink-resolved) target is compared
#   with the physical REPO_ROOT, on path-component boundaries (so /repo-other is not inside /repo). A symlink pointing
#   anywhere else was not created by this repo and is never printed.
#   Fails (prints nothing) when python3 is missing, so callers delete nothing.
# ---------------------------------------------------------------------------
dotbot_filter_repo_owned_links() {
    _dfr_root="${REPO_ROOT:?REPO_ROOT required}"

    if ! command -v python3 >/dev/null 2>&1; then
        log_error "python3 not found; cannot decide which symlinks this repo owns"
        return 1
    fi

    # The script goes in via -c so stdin stays free for the link list.
    _dfr_py="$(cat <<'PY'
import os
import sys

root = sys.argv[1]
roots = {os.path.realpath(root)}
roots.discard(os.sep)


def inside(path):
    return any(path.startswith(r + os.sep) for r in roots)


for line in sys.stdin:
    link = line.rstrip("\n")
    if not link or not os.path.islink(link):
        continue
    try:
        target = os.readlink(link)
    except OSError:
        continue
    parent = os.path.realpath(os.path.dirname(os.path.abspath(link)))
    if not os.path.isabs(target):
        target = os.path.join(parent, target)
    # Physical resolution of the target (follows symlinks and .. components,
    # tolerates the missing tail), compared with the physical repo root.
    if inside(os.path.realpath(target)):
        print(link)
PY
)"
    python3 -c "${_dfr_py}" "${_dfr_root}"
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

    # The Ghostty theme link is made only when Ghostty is selected
    # (./dots components): run a copy of the config without that one link.
    # Fail open: without the components lib the config runs as it is.
    _dta_run="${_dta_config}"
    _dta_tmp=""
    if command -v components_has >/dev/null 2>&1 && command -v dots_local_get >/dev/null 2>&1 \
        && ! components_has ghostty; then
        _dta_tmp="$(mktemp)" || return 1
        grep -v '^[[:space:]]*~/\.config/ghostty/themes/dots:' "${_dta_config}" > "${_dta_tmp}" || true
        _dta_run="${_dta_tmp}"
    fi

    "$(path_install_wrapper)" "${_dta_run}"
    _dta_rc=$?
    [ -z "${_dta_tmp}" ] || rm -f "${_dta_tmp}"
    return "${_dta_rc}"
}
