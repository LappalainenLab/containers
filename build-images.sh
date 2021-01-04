#!/bin/bash

#   Check changed image files
#   Set global options to cause the script to fail upon failure of any one step
set -eo pipefail

[[ -z ${VENDOR} ]] && VENDOR="$(basename $0)"
REGISTRY="$(echo ghcr.io/$(dirname ${GITHUB_REPOSITORY}) | tr '[:upper:]' '[:lower:]')"

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
    local name="$(basename ${builddir} | tr '[:upper:]' '[:lower:]')"
    cd ${builddir}
    (
        set -x
        docker build -t "${name}" . \
            --label "org.opencontainers.image.created=$(timestamp)" \
            --label "org.opencontainers.image.source=${repo}" \
            --label "org.opencontainers.image.revision=${revision}" \
            --label "org.opencontainers.image.vendor=${vendor}" \
            --label "org.opencontainers.image.documentation=${repo}"
    ) >&2
    cd ${root}
    echo "${name}"
}

#   Status messages
echo "Building images from commit pushed by ${GITHUB_ACTOR}" >&2
echo "Images provided by ${VENDOR}" >&2
echo "Images built from ${GITHUB_REPOSITORY}" >&2
echo "Images hosted at ${REGISTRY}" >&2

#   Fetch the current master commit
LL_HASH=$(set -x; git log -n 1 --format="%H" HEAD^1)
(set -x; echo $(git diff --name-only ${GITHUB_SHA} ${LL_HASH})) >&2

#   Set up holding arrays for changed image files that need to be rebuilt
declare -a DOCKERFILES=()

#   Find all changed image files
for DIFF in $(set -x; git diff --name-only ${GITHUB_SHA} ${LL_HASH}); do
    case $(basename ${DIFF}) in
        Dockerfile)
            echo "Adding ${DIFF} to check queue" >&2
            DOCKERFILES+=(${DIFF})
            ;;
        *)
            continue
            ;;
    esac
done

#   Build Docker images
if [[ ${#DOCKERFILES[@]} -gt 0 ]]; then
    [[ -z ${DOCKER_TOKEN} ]] && (echo "No authentication token for Docker provided" >&2; exit 1)
    echo ${DOCKER_TOKEN} | docker login $(echo ${REGISTRY} | cut -f 1 -d '/') -u ${GITHUB_ACTOR} --password-stdin
    for IMAGE in ${DOCKERFILES[@]}; do
        echo "Working on $(basename $(dirname ${IMAGE}))" >&2
        NAME=$(build_docker "${IMAGE}" "https://github.com/${GITHUB_REPOSITORY}" "${GITHUB_SHA}" "${VENDOR}")
        (set -x; docker tag "${NAME}" "${REGISTRY}/${NAME}:latest")
        (set -x; docker push "${REGISTRY}/${NAME}:latest")
        VERSION=$(docker_version ${IMAGE})
        if [[ ! -z ${VERSION} ]]; then
            (set -x; docker tag ${NAME} "${REGISTRY}/${NAME}:${VERSION}")
            (set -x; docker push "${REGISTRY}/${NAME}:${VERSION}")
        fi
    done
fi
