# shellcheck shell=bash disable=SC2034
#
# The plan `pnpm exec ci-local` runs: the steps of .github/workflows/ci.yml
# (shellcheck, then bats, through the same two `make` targets), in a Linux
# container on this machine. What ci-local is and does:
# node_modules/@jals1212/ci-local/README.md. What a local run proves and when it
# stands in for GitHub's: README.md, "Development".
#
# `tests/ci_local_parity.bats` keeps the commands below equal to the workflow's
# and pins the project name. Edit them together.

# The repository is `jals1212/.dotfiles` and the directory `.dotfiles`, so the
# convention `<repo>-ci` would give `.dotfiles-ci`. ci-local refuses it: the name
# prefixes the runner container, the network and the volumes, and Docker names
# cannot start with a dot (ci-local also takes lowercase letters, digits, `_`
# and `-` only). The dot is dropped.
CI_PROJECT=dotfiles-ci
# The workflow's one job, `check`.
CI_JOBS=(check)

# The runner, extended with what the workflow apt-installs.
CI_RUNNER_DOCKERFILE=docker/ci-local/Dockerfile

# The runner mounts this checkout at its own path, so vendor/ is what
# `git submodule update --init --recursive` left here: the workflow checks it
# out with `submodules: recursive`, and the tests read vendor/dotbot/lib/pyyaml,
# a submodule of a submodule. Without them the suite fails far from the cause.
ci_preflight() {
  local path
  for path in vendor/dotbot/bin/dotbot vendor/dotbot/lib/pyyaml/lib \
    vendor/plugins/dotbot-brew vendor/plugins/dotbot-mise; do
    # A submodule that was not initialised is an empty directory.
    if [[ ! -e "$REPO/$path" ]] || { [[ -d "$REPO/$path" ]] && [[ -z "$(ls -A "$REPO/$path")" ]]; }; then
      echo "ci-local: $path is missing: run 'git submodule update --init --recursive' first" >&2
      exit 2
    fi
  done
}

ci_not_mirrored "Install bats and zsh (Linux)" \
  "the same packages are in the runner image, docker/ci-local/Dockerfile"
ci_not_mirrored "Install bats and shellcheck (macOS)" \
  "the runner is Linux; the macOS runner is GitHub's, by hand (workflow_dispatch)"

ci_plan() {
  ci_step host "Build the runner image" ci_build_runner
  ci_step host "Start the Linux runner" ci_start_runner

  # The workflow's timeout-minutes is 15 for the job.
  ci_step box "shellcheck" --timeout 600 'make -f config/Makefile lint'
  ci_step box "bats" --timeout 900 'make -f config/Makefile test'
}
