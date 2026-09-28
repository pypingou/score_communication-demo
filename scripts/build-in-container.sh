#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
set -euo pipefail

DEMO_DIR=/demo
BAZEL_VERSION="$(tr -d '[:space:]' < .bazelversion)"
EXPECTED_BAZEL="bazel ${BAZEL_VERSION}"
ACTUAL_BAZEL="$(bazel --version)"

if [[ "${ACTUAL_BAZEL}" != "${EXPECTED_BAZEL}" ]]; then
    echo "ERROR: expected ${EXPECTED_BAZEL}, found ${ACTUAL_BAZEL}" >&2
    exit 1
fi

# These targets produce application bundles containing the executable and its
# mw::com configuration under opt/<application>/.
bazel build \
    --platforms=@score_bazel_platforms//:x86_64-linux-autosd10 \
    //score/mw/com/doc/tutorial/chapter_1:provider-tar \
    //score/mw/com/doc/tutorial/chapter_1:consumer-tar

ARTIFACT_DIR="${DEMO_DIR}/artifacts"
rm -rf "${ARTIFACT_DIR}"
mkdir -p "${ARTIFACT_DIR}"

tar -xf bazel-bin/score/mw/com/doc/tutorial/chapter_1/provider-tar.tar -C "${ARTIFACT_DIR}"
tar -xf bazel-bin/score/mw/com/doc/tutorial/chapter_1/consumer-tar.tar -C "${ARTIFACT_DIR}"

for app_and_binary in HelloWorldServer:provider_app HelloWorldClient:consumer_app; do
    app="${app_and_binary%%:*}"
    binary="${app_and_binary#*:}"
    for file in \
        "${ARTIFACT_DIR}/opt/${app}/bin/${binary}" \
        "${ARTIFACT_DIR}/opt/${app}/etc/mw_com_config.json" \
        "${ARTIFACT_DIR}/opt/${app}/etc/logging.json"; do
        if [[ ! -s "${file}" ]]; then
            echo "ERROR: expected Bazel package file is missing: ${file}" >&2
            exit 1
        fi
    done
done

echo "Extracted provider and consumer bundles to ${ARTIFACT_DIR}/opt/"
