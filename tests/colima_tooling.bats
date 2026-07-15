#!/usr/bin/env bats
# Verifies the local Docker workflow managed by the dotfiles.

REPO_ROOT_REAL="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

@test "Brewfile manages Colima and the Docker CLI plugins without OrbStack" {
    brewfile="${REPO_ROOT_REAL}/config/Brewfile"

    grep -Fq 'brew "colima"' "${brewfile}"
    grep -Fq 'brew "docker"' "${brewfile}"
    grep -Fq 'brew "docker-buildx"' "${brewfile}"
    grep -Fq 'brew "docker-compose"' "${brewfile}"
    ! grep -Fiq "orbstack" "${brewfile}"
}

@test "dotbot exposes Homebrew Docker plugins without managing config.json" {
    install_config="${REPO_ROOT_REAL}/config/install.conf.yaml"

    grep -Fq '~/.docker/cli-plugins/docker-compose: content/home/.docker/cli-plugins/docker-compose' "${install_config}"
    grep -Fq '~/.docker/cli-plugins/docker-buildx: content/home/.docker/cli-plugins/docker-buildx' "${install_config}"
    ! grep -Eq '^[[:space:]]*~/.docker/config\.json:' "${install_config}"
}

@test "Docker plugin shims resolve the installed Homebrew binaries from PATH" {
    bin_dir="${BATS_TEST_TMPDIR}/bin"
    mkdir -p "${bin_dir}"

    for plugin in docker-compose docker-buildx; do
        cat >"${bin_dir}/${plugin}" <<'EOF'
#!/bin/sh
printf '%s:%s\n' "$(basename "$0")" "$*"
EOF
        chmod +x "${bin_dir}/${plugin}"

        run env PATH="${bin_dir}:${PATH}" "${REPO_ROOT_REAL}/content/home/.docker/cli-plugins/${plugin}" docker-cli-plugin-metadata
        [ "${status}" -eq 0 ]
        [ "${output}" = "${plugin}:docker-cli-plugin-metadata" ]
    done
}

@test "doctor verifies Docker plugin integration without requiring a running VM" {
    bin_dir="${BATS_TEST_TMPDIR}/bin"
    docker_calls="${BATS_TEST_TMPDIR}/docker-calls"
    colima_marker="${BATS_TEST_TMPDIR}/colima-executed"
    mkdir -p "${bin_dir}"

    cat >"${bin_dir}/colima" <<EOF
#!/bin/sh
touch "${colima_marker}"
exit 99
EOF
    cat >"${bin_dir}/docker" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >>"${docker_calls}"
case "\$*" in
    'compose version'|'buildx version') exit 0 ;;
    *) exit 99 ;;
esac
EOF
    chmod +x "${bin_dir}/colima" "${bin_dir}/docker"

    PATH="${bin_dir}:${PATH}"
    export PATH REPO_ROOT="${REPO_ROOT_REAL}"
    # shellcheck disable=SC1091
    . "${REPO_ROOT_REAL}/src/lib/log.sh"
    # shellcheck disable=SC1091
    . "${REPO_ROOT_REAL}/src/lib/doctor.sh"

    check_colima >/dev/null
    check_docker >/dev/null
    check_docker_buildx >/dev/null
    check_docker_compose >/dev/null
    [ ! -e "${colima_marker}" ]
    grep -Fxq 'buildx version' "${docker_calls}"
    grep -Fxq 'compose version' "${docker_calls}"
}

@test "doctor registers the Colima and Docker command checks" {
    doctor="${REPO_ROOT_REAL}/src/lib/doctor.sh"
    checks="$(sed -n 's/^DOCTOR_CHECKS="\(.*\)"$/\1/p' "${doctor}")"

    for check in check_colima check_docker check_docker_buildx check_docker_compose; do
        case " ${checks} " in
            *" ${check} "*) ;;
            *) return 1 ;;
        esac
    done
}
