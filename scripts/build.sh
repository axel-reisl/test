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
  git clone --depth 1 https://github.com/ipxe/ipxe.git "${BUILD_DIR}" >/dev/null
fi

pushd "${BUILD_DIR}/src" >/dev/null
make clean
make bin/ipxe.iso EMBED="${BOOT_EMBED}"
make bin-x86_64-efi/ipxe.efi EMBED="${BOOT_EMBED}"
popd >/dev/null

BUILD_OUT="${BUILD_DIR}/output"
rm -rf "${BUILD_OUT}"
mkdir -p "${BUILD_OUT}/iso"
mkdir -p "${BUILD_OUT}/efi/EFI/BOOT"
cp "${BUILD_DIR}/src/bin-i386-pc/ipxe.lkrn" "${BUILD_OUT}/iso/ipxe.lkrn"
cp "${BUILD_DIR}/src/bin-x86_64-efi/ipxe.efi" "${BUILD_OUT}/efi/EFI/BOOT/BOOTx64.EFI"

EFI_IMG="${BUILD_OUT}/efi.img"
xorriso -as mkisofs -o "${EFI_IMG}" \
  -iso-level 3 -full-iso9660-filenames -volid IPXE_EFI -joliet -rock \
  "${BUILD_OUT}/efi"

xorriso -as mkisofs -o "${DIST_DIR}/ipxe-custom.iso" \
  -iso-level 3 -volid IPXE_CUSTOM \
  -eltorito-boot iso/ipxe.lkrn -no-emul-boot -boot-load-size 4 -boot-info-table \
  -eltorito-alt-boot -e "${EFI_IMG}" -no-emul-boot \
  -isohybrid-gpt-basdat -append_partition 2 0xef "${EFI_IMG}" \
  "${BUILD_OUT}/iso"

echo "Build complete: ${DIST_DIR}/ipxe-custom.iso"
if [[ -n "${SERVER_URL}" ]]; then
  echo "Embedded server URL: ${SERVER_URL}"
fi
