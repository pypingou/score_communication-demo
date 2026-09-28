#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="${SCORE_COMMUNICATION_DIR:-${PROJECT_DIR}/../score_communication}"
SOURCE_DIR="$(cd "$SOURCE_DIR" 2>/dev/null && pwd)" || {
    echo "ERROR: SCORE communication checkout not found: ${SCORE_COMMUNICATION_DIR:-${PROJECT_DIR}/../score_communication}" >&2
    echo "Set SCORE_COMMUNICATION_DIR to the checkout path." >&2
    exit 1
}

if [[ ! -f "${SOURCE_DIR}/.bazelversion" || ! -f "${SOURCE_DIR}/MODULE.bazel" ]]; then
    echo "ERROR: ${SOURCE_DIR} does not look like a SCORE communication Bazel checkout." >&2
    exit 1
fi

if ! command -v podman >/dev/null 2>&1; then
    echo "ERROR: podman is required to build the containerized Bazel environment." >&2
    exit 1
fi

BAZEL_VERSION="$(tr -d '[:space:]' < "${SOURCE_DIR}/.bazelversion")"
BUILDER_IMAGE="localhost/score-communication-builder:${BAZEL_VERSION}"
BAZEL_CACHE="${BAZEL_CACHE_DIR:-${XDG_CACHE_HOME:-${HOME}/.cache}/bazel-score-communication}"

mkdir -p "${PROJECT_DIR}/artifacts" "${BAZEL_CACHE}"

echo "Building the Bazel build environment (${BUILDER_IMAGE})..."
podman build \
    --build-arg "BAZEL_VERSION=${BAZEL_VERSION}" \
    --tag "${BUILDER_IMAGE}" \
    --file "${PROJECT_DIR}/Containerfile" \
    "${PROJECT_DIR}"

echo "Building SCORE communication examples from ${SOURCE_DIR}..."
podman run --rm \
    --volume "${SOURCE_DIR}:/score_communication:Z" \
    --volume "${PROJECT_DIR}:/demo:Z" \
    --volume "${BAZEL_CACHE}:/root/.cache/bazel:Z" \
    --workdir /score_communication \
    "${BUILDER_IMAGE}" \
    /demo/scripts/build-in-container.sh

echo "Build complete. Artifacts are in ${PROJECT_DIR}/artifacts/"
