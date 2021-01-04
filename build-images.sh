#!/bin/bash

#   Check changed image files
#   Set global options to cause the script to fail upon failure of any one step
set -eo pipefail

[[ -z ${VENDOR} ]] && VENDOR="$(basename $0)"
REGISTRY="ghcr.io/$(dirname ${GITHUB_REPOSITORY})"

#   Helper functions
function timestamp() {
    echo $(date --utc +"%Y-%m-%dT%H:%M:%S.%2NZ")
}

export -f timestamp

function docker_version() {
    local image="${1}"
    echo $(docker inspect --format '{{index .ContainerConfig.Labels "org.opencontainers.image.version"}}' ${image})
}

export -f docker_version

function build_docker() {
    local dockerfile="${1}"
    local repo="${2}"
    local revision="${3}"
    local vendor="${4}"
    local root="$(pwd)"
    local builddir="$(dirname ${dockerfile})"
    local name="$(basename ${builddir})"
    cd -v ${builddir}
    (
        set -x
        docker build -t "${name}" . \
            --label "org.opencontainers.image.created=$(timestamp)" \
            --label "org.opencontainers.image.source=${repo}" \
            --label "org.opencontainers.image.revision=${revision}" \
            --label "org.opencontainers.image.vendor=${vendor}" \
            --label "org.opencontainers.image.documentation=${repo}"
    )
    echo "${name}"
}

#   Get the hashes between this current commit and any previous ones
declare -a HASHES=($(set -x; git log -n 2 --format="%H"))

[[ ${#HASHES[@]} -lt 2 ]] && (echo "Not enough hashes"; exit 0)

#   Set up holding arrays for changed image files that need to be rebuilt
declare -a DOCKERFILES=()

#   Find all changed image files
for diff in $(set -x; git diff --name-only ${HASHES[0]} ${HASHES[1]}); do
    case $(basename ${diff}) in
        Dockerfile)
            DOCKERFILES+=(${diff})
            ;;
        *)
            continue
            ;;
    esac
done

if [[ ${#DOCKERFILES[@]} -gt 0 ]]; then
    [[ -z ${DOCKER_TOKEN} ]] && (echo "No authentication token for Docker provided" >&2; exit 1)
    echo ${DOCKER_TOKEN} | docker login $(echo ${REGISTRY} | cut -f 1 -d '/') -u ${GITHUB_ACTOR} --password-stdin
    for IMAGE in ${DOCKERFILES[@]}; do
        echo "Working on $(basename $(dirname ${IMAGE}))" >&2
        NAME=$(build_docker "${IMAGE}" "${GITHUB_REPO}" "${HASHES[0]}" "${VENDOR}")
        (set -x; docker tag "${NAME}" "${REGISTRY}/${NAME}:latest")
        (set -x; docker push "${REGISTRY}/${NAME}:latest")
        VERSION=$(docker_version ${IMAGE})
        if [[ ! -z ${VERSION} ]]; then
            (set -x; docker tag ${NAME} "${REGISTRY}/${NAME}:${VERSION}")
            (set -x; docker push "${REGISTRY}/${NAME}:${VERSION}")
        fi
    done
fi
