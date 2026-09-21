#!/bin/bash
set -e

# ============================================================
# HiSH HAP 构建脚本
# 用法: ./ci/build-hap.sh [--build-qemu] [--target tablet|phone|all]
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

# 默认参数
BUILD_QEMU=false
TARGET=all
BUILD_MODE=release

# 解析参数
while [[ $# -gt 0 ]]; do
  case $1 in
    --build-qemu)
      BUILD_QEMU=true
      shift
      ;;
    --target)
      TARGET="$2"
      shift 2
      ;;
    --mode)
      BUILD_MODE="$2"
      shift 2
      ;;
    --help)
      echo "用法: ./ci/build-hap.sh [--build-qemu] [--target tablet|phone|all] [--mode debug|release]"
      exit 0
      ;;
    *)
      echo "未知参数: $1"
      exit 1
      ;;
  esac
done

echo "========================================"
echo "HiSH HAP 构建"
echo "  目标: $TARGET"
echo "  模式: $BUILD_MODE"
echo "  从源码构建 QEMU: $BUILD_QEMU"
echo "========================================"

# ===== 1. 检查环境 =====
echo "[1/8] 检查构建环境..."

if [ -z "$TOOL_HOME" ]; then
  echo "  ⚠ TOOL_HOME 未设置"
  echo "  请从 https://developer.huawei.com/consumer/cn/download/ 下载 Command Line Tools"
  echo "  解压后设置: export TOOL_HOME=/path/to/command-line-tools"
  if [ "$BUILD_QEMU" = "true" ]; then
    exit 1
  fi
  echo "  （使用预编译库，可跳过）"
else
  echo "  ✓ TOOL_HOME=$TOOL_HOME"
fi

# ===== 2. 拉取子模块 =====
echo "[2/8] 拉取子模块..."
git submodule update --init --recursive
echo "  ✓ 子模块就绪"

# ===== 3. 获取 QEMU 库 =====
VM_DIR="feature/hish_main/src/main/resources/rawfile/vm"
LIBS_DIR="feature/hish_main/libs"

if [ "$BUILD_QEMU" = "true" ]; then
  echo "[3/8] 从源码构建 QEMU (arm64-v8a)..."
  cd deps
  make aarch64 -j$(nproc)
  cd ..
  echo "  ✓ QEMU 构建完成"
else
  echo "[3/8] 下载预编译 QEMU 库..."
  if [ ! -d "$LIBS_DIR/arm64-v8a" ] || [ -z "$(ls -A $LIBS_DIR/arm64-v8a 2>/dev/null)" ]; then
    wget -q --show-progress \
      https://github.com/harmoninux/qemu/releases/download/hish-20260110/libs.zip \
      -O /tmp/libs.zip
    unzip -q -o /tmp/libs.zip -d "$LIBS_DIR/"
    rm -f /tmp/libs.zip
    echo "  ✓ QEMU 库下载完成"
  else
    echo "  ✓ QEMU 库已存在，跳过"
  fi
  ls "$LIBS_DIR/arm64-v8a/" | head -5
fi

# ===== 4. 下载内核 =====
echo "[4/8] 下载 Linux 内核..."
mkdir -p "$VM_DIR"
if [ ! -f "$VM_DIR/kernel_aarch64" ]; then
  wget -q --show-progress \
    https://github.com/harmoninux/linux-config/releases/download/kernel-20260228/kernel_aarch64 \
    -O "$VM_DIR/kernel_aarch64"
  echo "  ✓ 内核下载完成"
else
  echo "  ✓ 内核已存在，跳过"
fi
ls -lh "$VM_DIR/kernel_aarch64"

# ===== 5. 下载根文件系统 =====
echo "[5/8] 下载根文件系统..."
if [ ! -f "$VM_DIR/rootfs_aarch64.qcow2" ]; then
  wget -q --show-progress \
    https://github.com/harmoninux/linux-config/releases/download/rootfs-20260117/rootfs_aarch64.qcow2 \
    -O "$VM_DIR/rootfs_aarch64.qcow2"
  echo "  ✓ rootfs 下载完成"
else
  echo "  ✓ rootfs 已存在，跳过"
fi
ls -lh "$VM_DIR/rootfs_aarch64.qcow2"

# ===== 6. 配置 build-profile =====
echo "[6/8] 配置 build-profile.json5..."
if [ ! -f "build-profile.json5" ]; then
  cp build-profile.template.json5 build-profile.json5
  echo "  ✓ 从模板创建 build-profile.json5"
else
  echo "  ✓ build-profile.json5 已存在"
fi

# ===== 7. 安装依赖 =====
echo "[7/8] 安装项目依赖..."
if command -v ohpm &> /dev/null; then
  ohpm install
  echo "  ✓ ohpm 依赖安装完成"
else
  echo "  ⚠ ohpm 未找到，跳过"
fi

# ===== 8. 构建 HAP =====
echo "[8/8] 构建 HAP ($BUILD_MODE)..."

# 尝试用 hvigorw 构建
if [ -f "hvigorw.js" ]; then
  node hvigorw.js assembleHap --mode "$BUILD_MODE" --no-daemon
elif [ -f "hvigorw" ]; then
  chmod +x hvigorw
  ./hvigorw assembleHap --mode "$BUILD_MODE" --no-daemon
else
  echo "  ⚠ 未找到 hvigorw，尝试用 devecocli..."
  if command -v devecocli &> /dev/null; then
    devecocli build --mode "$BUILD_MODE"
  else
    echo "  ✗ 未找到构建工具（hvigorw / devecocli）"
    echo "  请安装 HarmonyOS Command Line Tools 并设置 TOOL_HOME"
    exit 1
  fi
fi

# ===== 收集产物 =====
echo ""
echo "========================================"
echo "构建完成！HAP 产物："
find . -name "*.hap" -exec ls -lh {} \;
echo "========================================"

# 复制到 artifacts 目录
mkdir -p artifacts
find . -name "*.hap" -exec cp {} artifacts/ \;
echo "产物已复制到 artifacts/"
