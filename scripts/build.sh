#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${REPO_ROOT}/build/ipxe"
DIST_DIR="${REPO_ROOT}/dist"
BOOT_SRC="${REPO_ROOT}/scripts/boot.ipxe"
SERVER_URL="${1:-}" 

usage() {
  cat <<'EOF'
Usage: ./scripts/build.sh [SERVER_URL]

Build a custom iPXE ISO embedding scripts/boot.ipxe.
If SERVER_URL is provided, it will override the value in boot.ipxe for this build only.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

mkdir -p "${BUILD_DIR}"
mkdir -p "${DIST_DIR}"

if [[ -n "${SERVER_URL}" ]]; then
  TEMP_BOOT="${BUILD_DIR}/boot.ipxe"
  sed -E "s|^set SERVER .*|set SERVER ${SERVER_URL}|" "${BOOT_SRC}" > "${TEMP_BOOT}"
  BOOT_EMBED="${TEMP_BOOT}"
else
  BOOT_EMBED="${BOOT_SRC}"
fi

if [[ ! -d "${BUILD_DIR}/src" ]]; then
  echo "Cloning iPXE repository into ${BUILD_DIR}..."
  git clone https://github.com/ipxe/ipxe.git "${BUILD_DIR}" >/dev/null
fi

pushd "${BUILD_DIR}/src" >/dev/null
make clean
make bin/ipxe.iso EMBED="${BOOT_EMBED}" >/dev/null
popd >/dev/null

cp "${BUILD_DIR}/src/bin/ipxe.iso" "${DIST_DIR}/ipxe-custom.iso"

echo "Build complete: ${DIST_DIR}/ipxe-custom.iso"
if [[ -n "${SERVER_URL}" ]]; then
  echo "Embedded server URL: ${SERVER_URL}"
fi
