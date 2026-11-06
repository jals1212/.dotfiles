# The Linux runner `pnpm exec ci-local` runs the CI steps in (ci-local.config.sh):
# ci-local's base image (the Node of `.nvmrc` on Debian bookworm, the Docker
# client, sudo, corepack) plus what .github/workflows/ci.yml installs around the
# steps on its Ubuntu runner: bats, zsh, shellcheck and jq (apt), with git, make and
# python3 that the hosted image has and the suite uses (submodule paths, the
# Makefile, vendor/dotbot's pyyaml checks).
#
# Not an application image and never pushed. ci-local builds it when it is
# missing, and a change to this file or to the base gives it a new tag.
# `CI_LOCAL_BASE` has no default: ci-local passes it.
ARG CI_LOCAL_BASE
FROM ${CI_LOCAL_BASE}

# The base leaves the user root, so apt needs no sudo.
RUN apt-get update \
 && apt-get install -y --no-install-recommends bats zsh shellcheck jq git make python3 \
 && rm -rf /var/lib/apt/lists/*
