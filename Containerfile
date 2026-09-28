# SPDX-License-Identifier: MIT
FROM quay.io/centos/centos:stream10

ARG BAZEL_VERSION=8.7.0

# Use the Bazel executable directly (rather than packaging the build tool as an RPM).
# The version matches score_communication/.bazelversion.
RUN dnf install -y \
        ca-certificates \
        cpio \
        curl \
        gcc \
        gcc-c++ \
        git \
        java-21-openjdk-devel \
        libstdc++ \
        libstdc++-devel \
        make \
        tar \
        wget \
    && dnf clean all \
    && curl -fsSL \
        "https://github.com/bazelbuild/bazel/releases/download/${BAZEL_VERSION}/bazel-${BAZEL_VERSION}-linux-x86_64" \
        -o /usr/local/bin/bazel \
    && chmod 0755 /usr/local/bin/bazel \
    && bazel --version

ENV HOME=/root
WORKDIR /score_communication
