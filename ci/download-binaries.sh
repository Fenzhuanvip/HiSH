#!/bin/bash
# Download large binary files from atomgit (CodeHub API has size limit)
set -e

ATOMGIT_TOKEN="${ATOMGIT_TOKEN:-fNCrAW6XzAx_P-19_RymJr7t}"
ATOMGIT_REPO="https://atomgit.com/ff-518/HiSH.git"
TMP_DIR="/tmp/hish-binaries"

echo "=== Downloading large binaries from atomgit ==="
git clone --depth 1 "https://ff-518:${ATOMGIT_TOKEN}@atomgit.com/ff-518/HiSH.git" "${TMP_DIR}" 2>/dev/null || \
git clone --depth 1 "${ATOMGIT_REPO}" "${TMP_DIR}"

LARGE_FILES=(
  "feature/hish_main/libs/arm64-v8a/libqemu-system-aarch64.so"
  "feature/hish_main/src/main/resources/rawfile/vm/kernel_aarch64"
  "feature/hish_main/src/main/resources/rawfile/vm/rootfs_aarch64.qcow2"
)

for f in "${LARGE_FILES[@]}"; do
  if [ -f "${TMP_DIR}/${f}" ]; then
    mkdir -p "$(dirname "${f}")"
    cp "${TMP_DIR}/${f}" "${f}"
    echo "  OK: ${f} ($(du -h "${f}" | cut -f1))"
  else
    echo "  MISSING: ${f}"
  fi
done

rm -rf "${TMP_DIR}"
echo "=== Done ==="
