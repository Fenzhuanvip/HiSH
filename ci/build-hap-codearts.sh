#!/bin/bash
set -ex

echo "=== Step 1: Download large binaries from atomgit ==="
git clone --depth 1 "https://ff-518:fNCrAW6XzAx_P-19_RymJr7t@atomgit.com/ff-518/HiSH.git" /tmp/hish-bin || true
if [ -d /tmp/hish-bin ]; then
  for f in \
    feature/hish_main/libs/arm64-v8a/libqemu-system-aarch64.so \
    feature/hish_main/src/main/resources/rawfile/vm/kernel_aarch64 \
    feature/hish_main/src/main/resources/rawfile/vm/rootfs_aarch64.qcow2; do
    if [ -f "/tmp/hish-bin/${f}" ]; then
      mkdir -p "$(dirname "${f}")"
      cp "/tmp/hish-bin/${f}" "${f}"
      echo "OK: ${f}"
    fi
  done
  rm -rf /tmp/hish-bin
fi

echo "=== Step 1.5: Download Ubuntu 24.04 rootfs from OBS ==="
ROOTFS_DIR="feature/hish_main/src/main/resources/rawfile/vm"
UBUNTU_ZIP="/tmp/ubuntu-base-24.04.zip"
set +e
curl -L --retry 2 --max-time 120 -o "${UBUNTU_ZIP}" \
  "https://hish-hap-muapc3vt.obs.cn-north-4.myhuaweicloud.com/ubuntu-base-24.04.zip"
if [ -f "${UBUNTU_ZIP}" ] && [ -s "${UBUNTU_ZIP}" ]; then
  echo "Ubuntu zip downloaded: $(ls -lh ${UBUNTU_ZIP})"
  mkdir -p /tmp/ubuntu-extract
  unzip -o "${UBUNTU_ZIP}" -d /tmp/ubuntu-extract
  UBUNTU_QCOW2=$(find /tmp/ubuntu-extract -name "*.qcow2" | head -1)
  if [ -n "${UBUNTU_QCOW2}" ]; then
    echo "Found Ubuntu qcow2: ${UBUNTU_QCOW2} ($(ls -lh ${UBUNTU_QCOW2}))"
    cp "${UBUNTU_QCOW2}" "${ROOTFS_DIR}/rootfs_aarch64.qcow2"
    echo "Replaced rootfs with Ubuntu 24.04"
  else
    echo "WARNING: No qcow2 found in Ubuntu zip, keeping Alpine rootfs"
  fi
  rm -rf /tmp/ubuntu-extract "${UBUNTU_ZIP}"
else
  echo "WARNING: Ubuntu zip download failed, keeping Alpine rootfs"
fi
set -e

echo "=== Step 2: Configure registries ==="
ohpm config set strict_ssl false
ohpm config set registry https://ohpm.openharmony.cn/ohpm/
npm config set strict-ssl false
npm config set registry=https://repo.huaweicloud.com/repository/npm/
npm config set @ohos:registry=https://repo.harmonyos.com/npm/

echo "=== Step 3: Install dependencies at root ==="
ohpm install

echo "=== Step 4: Build HAP from root ==="
hvigorw clean --no-daemon
hvigorw assembleHap --mode module -p product=default -p debuggable=false --no-daemon

echo "=== Step 5: Results ==="
find . -name "*.hap" -exec ls -lh {} \;

echo "=== Step 6: Upload HAP to atomgit (build-artifacts branch) ==="
# 保存 HAP 的绝对路径（当前工作目录是项目根目录）
BUILD_WORKSPACE="$(pwd)"
PHONE_HAP_ABS="${BUILD_WORKSPACE}/product/phone/build/default/outputs/default/phone-default-unsigned.hap"
TABLET_HAP_ABS="${BUILD_WORKSPACE}/product/tablet/build/default/outputs/default/tablet-default-unsigned.hap"
echo "Phone HAP: ${PHONE_HAP_ABS}"
echo "Tablet HAP: ${TABLET_HAP_ABS}"
ls -lh "${PHONE_HAP_ABS}" "${TABLET_HAP_ABS}"

git config --global user.email "build@codearts.com"
git config --global user.name "CodeArts Build"
rm -rf /tmp/hish-upload
git clone "https://ff-518:fNCrAW6XzAx_P-19_RymJr7t@atomgit.com/ff-518/HiSH.git" /tmp/hish-upload
cd /tmp/hish-upload
git checkout --orphan build-artifacts 2>/dev/null || git checkout build-artifacts
git rm -rf . 2>/dev/null || true
mkdir -p artifacts

# 分割并上传 phone HAP
if [ -f "${PHONE_HAP_ABS}" ]; then
  split -b 20M "${PHONE_HAP_ABS}" artifacts/phone-hap-part-
  sha256sum "${PHONE_HAP_ABS}" | awk '{print $1}' > artifacts/phone-hap.sha256
  ls -lh "${PHONE_HAP_ABS}" > artifacts/phone-hap.info
  echo "Phone HAP split and checksum saved"
fi

# 分割并上传 tablet HAP
if [ -f "${TABLET_HAP_ABS}" ]; then
  split -b 20M "${TABLET_HAP_ABS}" artifacts/tablet-hap-part-
  sha256sum "${TABLET_HAP_ABS}" | awk '{print $1}' > artifacts/tablet-hap.sha256
  ls -lh "${TABLET_HAP_ABS}" > artifacts/tablet-hap.info
  echo "Tablet HAP split and checksum saved"
fi

ls -lh artifacts/
git add -f artifacts/
git commit -m "Upload HAP artifacts from CodeArts build" || { echo "Nothing to commit, aborting"; exit 1; }
git push origin build-artifacts --force
echo "=== HAP upload complete ==="
cd "${BUILD_WORKSPACE}"
rm -rf /tmp/hish-upload
