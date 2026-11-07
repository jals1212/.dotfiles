#!/usr/bin/env bats
# Verifies the OrbStack-owned local Docker workflow managed by the dotfiles.

REPO_ROOT_REAL="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

@test "Brewfile installs OrbStack for the Docker toolchain" {
    grep -Fq 'cask "orbstack"' "${REPO_ROOT_REAL}/config/Brewfile"
}

@test "doctor discovers OrbStack and the Docker CLI plugins without a running engine" {
    bin_dir="${BATS_TEST_TMPDIR}/bin"
    docker_calls="${BATS_TEST_TMPDIR}/docker-calls"
    mkdir -p "${bin_dir}"

    cat >"${bin_dir}/orb" <<'EOF'
#!/bin/sh
exit 0
EOF
    # Engine-dependent calls fail; only plugin `version` (daemon-free) succeeds.
    cat >"${bin_dir}/docker" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >>"${docker_calls}"
case "\$*" in
    'compose version'|'buildx version') exit 0 ;;
    *) exit 99 ;;
esac
EOF
    # These checks only run on macOS (doctor skips them on Linux): pin the OS.
    printf '#!/bin/sh\necho Darwin\n' >"${bin_dir}/uname"
    chmod +x "${bin_dir}/orb" "${bin_dir}/docker" "${bin_dir}/uname"

    PATH="${bin_dir}:${PATH}"
    export PATH REPO_ROOT="${REPO_ROOT_REAL}"
    # shellcheck disable=SC1091
    . "${REPO_ROOT_REAL}/src/lib/log.sh"
    # shellcheck disable=SC1091
    . "${REPO_ROOT_REAL}/src/lib/doctor.sh"

    check_orbstack >/dev/null
    check_docker >/dev/null
    check_docker_buildx >/dev/null
    check_docker_compose >/dev/null
    grep -Fxq 'buildx version' "${docker_calls}"
    grep -Fxq 'compose version' "${docker_calls}"
}

@test "doctor registers the OrbStack and Docker command checks" {
    checks="$(sed -n 's/^DOCTOR_CHECKS="\(.*\)"$/\1/p' "${REPO_ROOT_REAL}/src/lib/doctor.sh")"

    for check in check_orbstack check_docker check_docker_buildx check_docker_compose; do
        case " ${checks} " in
            *" ${check} "*) ;;
            *) return 1 ;;
        esac
    done
}
