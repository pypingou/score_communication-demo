#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="${PROJECT_DIR}/image.aib.yml"
OUTPUT_IMAGE="${OUTPUT_IMAGE:-${PROJECT_DIR}/score-communication-demo.qcow2}"
BOOTC_IMAGE="${BOOTC_IMAGE:-localhost/score-communication-demo:latest}"
AIB_DISTRO="${AIB_DISTRO:-autosd10-sig}"

if ! command -v aib >/dev/null 2>&1; then
    echo "ERROR: aib is required. Install Automotive Image Builder first." >&2
    exit 1
fi

for artifact in \
    "${PROJECT_DIR}/artifacts/opt/HelloWorldServer/bin/provider_app" \
    "${PROJECT_DIR}/artifacts/opt/HelloWorldServer/etc/logging.json" \
    "${PROJECT_DIR}/artifacts/opt/HelloWorldClient/bin/consumer_app" \
    "${PROJECT_DIR}/artifacts/opt/HelloWorldClient/etc/logging.json" \
    "${PROJECT_DIR}/configs/provider.json" \
    "${PROJECT_DIR}/configs/qm-client.json" \
    "${PROJECT_DIR}/configs/root-client.json"; do
    if [[ ! -s "${artifact}" ]]; then
        echo "ERROR: missing build input ${artifact}" >&2
        echo "Run ./build.sh before building the AutoSD image." >&2
        exit 1
    fi
done

case "${OUTPUT_IMAGE}" in
    */*)
        OUTPUT_DIR="${OUTPUT_IMAGE%/*}"
        [[ -n "${OUTPUT_DIR}" ]] || OUTPUT_DIR="/"
        ;;
    *) OUTPUT_DIR="." ;;
esac
mkdir -p "${OUTPUT_DIR}"
echo "Preparing the ${AIB_DISTRO} disk-image builder (no-op if already present)..."
aib build-builder \
    --no-sudo \
    --if-needed \
    --distro "${AIB_DISTRO}" \
    "localhost/aib-build:${AIB_DISTRO}"

echo "Building bootc image ${BOOTC_IMAGE} and disk image ${OUTPUT_IMAGE}..."
aib build \
    --no-sudo \
    --target qemu \
    --distro "${AIB_DISTRO}" \
    "${MANIFEST}" \
    "${BOOTC_IMAGE}" \
    "${OUTPUT_IMAGE}"
echo "Bootc image ready: ${BOOTC_IMAGE}"
echo "Disk image ready: ${OUTPUT_IMAGE}"
