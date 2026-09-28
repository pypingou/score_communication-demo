# SCORE communication across AutoSD root and QM partitions

This tutorial builds an AutoSD image with the SCORE `mw::com` (LoLa) middleware and demonstrates one service with three participants:

- **Provider/server:** runs in the QM partition.
- **Client 1:** runs in the QM partition.
- **Client 2:** runs in the root partition.

Both clients subscribe to the provider's `Hello World` event. The application source and Bazel targets come from SCORE's existing [chapter 1 tutorial](https://github.com/eclipse-score/communication/tree/main/score/mw/com/doc/tutorial/chapter_1).

The image is assembled directly from Bazel-built executables and configuration files; the demo binaries and Bazel are not packaged as RPMs. Bazel is a build-time executable in a container and is not installed in the image.

## Partition and IPC layout

AutoSD runs QM applications inside its `qm` system container. The AIB manifest installs the provider and one client into the QM filesystem, and installs the other client into the root filesystem. It enables a systemd unit for each process.

On Linux, SCORE's LoLa shared-memory objects are backed by POSIX shared memory and its message-passing/service-discovery artifacts also use filesystem paths. For this demonstration, the QM container is configured to share the host `/dev/shm` and `/tmp` mounts. This lets the QM provider, QM client, and root client see the same SCORE IPC objects and endpoints.

> **Security warning:** The manifest sets SELinux to permissive to keep this introductory IPC example focused. It also shares `/tmp` and `/dev/shm` with the QM container and enables root SSH with a demo password. These are bring-up settings only. Do not use the image for deployment; production use needs a reviewed SELinux policy, restricted mounts/permissions, and production credentials. The [SIG shared-memory QM/root demo](https://gitlab.com/CentOS/automotive/sig-docs/-/tree/main/demos/shared_memory_qm_root) documents the more restrictive policy approach.

## Prerequisites

- Linux x86_64 with Podman.
- `aib` and `air` installed and configured. See the [AutoSD image-building guide](https://centos.gitlab.io/automotive/sig-docs/docs/building/building_an_os_image/).
- A SCORE communication source checkout. The adjacent checkout used during development is `../score_communication`; otherwise clone it:

  ```bash
  git clone https://github.com/eclipse-score/communication.git ../score_communication
  ```

## 1. Build the SCORE applications with Bazel in a container

From the root of this repository, run:

```bash
./build.sh
```

If the source checkout is elsewhere, set `SCORE_COMMUNICATION_DIR`:

```bash
SCORE_COMMUNICATION_DIR=/path/to/communication ./build.sh
```

The container is based on CentOS Stream 10 and uses the Bazel version pinned by the SCORE checkout. The build explicitly selects `@score_bazel_platforms//:x86_64-linux-autosd10`, while SCORE's `.bazelrc` supplies its configured GCC 15 toolchain. This marks the target as AutoSD 10 (rather than relying on Bazel's generic host Linux platform) and builds these upstream targets. The platform adds AutoSD runtime constraints; it does not itself provide a separate sysroot, so this build relies on the CentOS Stream 10 container userland for its Linux ABI.

```text
//score/mw/com/doc/tutorial/chapter_1:provider-tar
//score/mw/com/doc/tutorial/chapter_1:consumer-tar
```

The build script extracts their executables and logging configuration under `artifacts/`. The three per-process `mw_com_config.json` files in `configs/` assign distinct application IDs while sharing the same service deployment.

## 2. Build the AutoSD image with AIB

After `./build.sh` succeeds, run:

```bash
./build-image.sh
```

This calls `aib build` with [`image.aib.yml`](image.aib.yml), producing both a bootc image (`localhost/score-communication-demo:latest` in local Podman storage) and `score-communication-demo.qcow2` for QEMU. The script first runs `aib build-builder --if-needed` to ensure the matching disk-image builder exists. This uses the bootc workflow intended for production and OTA updates; the QCOW2 is also generated for local testing. Set `OUTPUT_IMAGE` to choose another disk-image path, `BOOTC_IMAGE` to change the container image name, or `AIB_DISTRO` to change the matching AutoSD distribution:

```bash
OUTPUT_IMAGE=/tmp/score-demo.qcow2 ./build-image.sh
```

Review `image.aib.yml` to see how the image is composed:

- Root partition: one `consumer_app` installation and its service unit.
- QM partition: the `provider_app`, the other `consumer_app`, their units, and configurations.
- QM container drop-in: bind-mounts the root `/tmp` and `/dev/shm` into QM so SCORE's message-passing endpoints and shared-memory objects are visible from both partitions.
- Private executables are installed under `/usr/libexec/score-communication-demo/`; the demo's fixed, architecture-independent configs and logging files remain under `/usr/share/score-communication-demo/`. The per-app working directories preserve SCORE's default `./etc/mw_com_config.json` lookup.

The manifest enables SSH for the demo and sets the root password to `password`. Both settings are for a local test VM only.

## 3. Run the image and observe all three participants

Start the image:

```bash
air --nographics --ssh-port 2222 score-communication-demo.qcow2
```

In another terminal, connect to the VM (the QEMU target forwards SSH on port 2222):

```bash
ssh root@localhost -p 2222 \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -o PubkeyAuthentication=no \
  -o PreferredAuthentications=password
```

Log in with `password`. Follow the root-partition client in one shell:

```bash
journalctl -fu score-demo-root-client.service
```

Follow the QM provider and QM client from the root shell in another terminal:

```bash
podman exec -it qm journalctl -fu score-demo-provider.service
podman exec -it qm journalctl -fu score-demo-qm-client.service
```

Each consumer should log received `Hello World` samples. The provider logs its sent samples. The QM and root consumer configurations have distinct `applicationID` values (`4002` and `4003`), and the provider uses `4001`.

Check service state if output is missing:

```bash
systemctl status score-demo-root-client.service
podman ps --filter name=qm
podman exec -it qm systemctl status score-demo-provider.service score-demo-qm-client.service
```

## Repository layout

- `Containerfile` — CentOS Stream 10 Bazel build environment.
- `build.sh`, `scripts/build-in-container.sh` — containerized Bazel build and extraction.
- `configs/` — separate SCORE deployment configs for provider, QM client, and root client.
- `image.aib.yml` — image content, partition placement, service units, and shared mount configuration.
- `build-image.sh` — AIB image build wrapper.
- `artifacts/` — generated Bazel output; ignored by Git and regenerated by `build.sh`.

## Troubleshooting

- **Source checkout not found:** clone it or set `SCORE_COMMUNICATION_DIR`.
- **Bazel/toolchain errors:** check `.bazelversion`, `.bazelrc`, and `MODULE.bazel` in the source checkout. The container controls the host build environment; the upstream repository selects the Bazel toolchain.
- **AIB cannot find an artifact:** run `./build.sh` before `./build-image.sh`.
- **No QM logs:** check `podman ps --filter name=qm`, then check `podman exec -it qm systemctl status score-demo-provider.service score-demo-qm-client.service`.
- **No root-client logs:** check `systemctl status score-demo-root-client.service` and ensure the `qm.container.d` drop-in mounts `/tmp` and `/dev/shm` into the QM container.
