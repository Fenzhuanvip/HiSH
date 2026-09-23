# HiSH 项目架构分析报告

## 1. 项目概述

### 1.1 项目简介

**HiSH** 是一个在 HarmonyOS 设备上运行 Linux Shell 的应用程序。该项目基于 [qemu-ohos](https://github.com/harmoninux/qemu) 开发，支持 2in1（PC）、平板和手机三种设备形态。

### 1.2 核心功能

- 完整的 arm64 Linux 内核支持
- 网络支持及端口转发功能
- Alpine Linux 根文件系统
- 虚拟按键（Tab/Ctrl/Esc/Shift/Fn/方向键）
- 共享文件夹功能（通过 virtio-9p 协议）
- JIT 加速（平板/2in1 设备支持，手机设备不支持）
- 镜像导入支持（Ubuntu 24.04 / Debian 12）
- VNC 远程桌面访问

### 1.3 目标用户

- 开发者：在 HarmonyOS 设备上进行 Linux 开发
- 系统管理员：远程管理 Linux 系统
- 技术爱好者：在移动设备上体验完整的 Linux 环境

### 1.4 技术栈

| 类别 | 技术 |
|------|------|
| 主要语言 | ArkTS (TypeScript 超集)、C++ |
| 框架 | HarmonyOS Stage 模型、ArkUI |
| 构建系统 | DevEco Studio、hvigor |
| 虚拟化 | QEMU (libqemu-system-aarch64.so) |
| 终端模拟 | xterm.js |
| 图形渲染 | OpenGL ES 3.0/2.0、libvncclient |
| 存储格式 | QCOW2 (QEMU Copy-On-Write v2/v3) |

---

## 2. 目录结构

```
workspace/
├── .codeartsdoer/          # CodeArts 配置与审查数据
├── HiSH/                   # 项目根目录
│   ├── .atomgit/           # AtomGit 工作流配置
│   ├── .github/            # GitHub 配置
│   ├── AppScope/           # 应用级资源与配置
│   ├── ci/                 # 持续集成配置
│   ├── deps/               # 原生依赖构建
│   │   ├── libglib/        # GLib 库
│   │   ├── libqemu/        # QEMU 构建配置
│   │   ├── pcre2/          # 正则表达式库
│   │   ├── pixman/         # 像素操作库
│   │   ├── zlib/           # 压缩库
│   │   ├── zstd/           # Zstandard 压缩库
│   │   └── Makefile        # 依赖构建编排
│   ├── docs/               # 文档资源
│   ├── feature/            # 功能模块
│   │   └── hish_main/      # 核心功能模块
│   │       ├── libs/       # 预编译原生库
│   │       └── src/
│   │           ├── main/
│   │           │   ├── cpp/        # C++ 原生代码
│   │           │   │   ├── include/  # 头文件
│   │           │   │   ├── libvncserver/  # VNC 库
│   │           │   │   ├── napi_init.cpp    # N-API QEMU 绑定
│   │           │   │   ├── napi_vnc.cpp     # N-API VNC 绑定
│   │           │   │   ├── vnc_client.cpp   # VNC 客户端封装
│   │           │   │   ├── vnc_renderer.cpp # OpenGL 渲染器
│   │           │   │   └── utils.cpp        # 工具函数
│   │           │   └── ets/        # ArkTS 代码
│   │           │       ├── components/    # UI 组件
│   │           │       ├── entryability/  # 入口能力
│   │           │       ├── lib/           # 工具库
│   │           │       ├── model/         # 数据模型
│   │           │       └── pages/         # 页面组件
│   ├── hvigor/             # hvigor 构建配置
│   ├── media/              # 媒体资源
│   └── product/            # 产品配置
│       ├── phone/          # 手机产品配置
│       └── tablet/         # 平板产品配置
└── ...
```

---

## 3. 核心组件架构

### 3.1 分层架构

```
┌─────────────────────────────────────────────────────────────┐
│                     UI 层 (ArkUI)                            │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │  WebTerminal │  │  VncPage    │  │  EmulatorManagement │  │
│  │  (终端界面)   │  │  (VNC界面)  │  │  (模拟器管理)       │  │
│  └─────────────┘  └─────────────┘  └─────────────────────┘  │
├─────────────────────────────────────────────────────────────┤
│                   业务逻辑层 (ArkTS)                         │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │ startVm     │  │ QemuAgent   │  │  QemuAgentManager   │  │
│  │ (VM启动)     │  │ (QMP通信)   │  │  (QMP管理器)        │  │
│  └─────────────┘  └─────────────┘  └─────────────────────┘  │
├─────────────────────────────────────────────────────────────┤
│                   N-API 桥接层 (C++)                         │
│  ┌─────────────────────┐  ┌─────────────────────────────┐   │
│  │ napi_init.cpp       │  │ napi_vnc.cpp                │   │
│  │ (QEMU N-API绑定)     │  │ (VNC N-API绑定)              │   │
│  └─────────────────────┘  └─────────────────────────────┘   │
├─────────────────────────────────────────────────────────────┤
│                   原生库层 (C/C++)                           │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │ libqemu-    │  │ libvncclient│  │  libqemu-img        │  │
│  │ system-aarch64.so │  │  (VNC客户端) │  │  (镜像操作)        │  │
│  └─────────────┘  └─────────────┘  └─────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### 3.2 核心模块说明

#### 3.2.1 EntryAbility（入口能力）

**文件位置**: `feature/hish_main/src/main/ets/entryability/EntryAbility.ets`

**职责**:
- 应用生命周期管理
- 用户偏好设置加载
- 内核与根文件系统提取
- 共享文件夹准备
- 默认模拟器启动
- 后台运行管理

**关键数据流**:
```
onCreate() → onWindowStageCreate() 
           → loadPreferences()      // 加载用户设置
           → extractKernelAndRootFilesystem()  // 提取资源
           → prepareForSharedFolder()  // 准备共享文件夹
           → startDefaultEmulator()  // 启动默认VM
```

#### 3.2.2 VM 启动模块

**文件位置**: `feature/hish_main/src/main/ets/lib/startVm.ets`

**职责**: 构建 QEMU 命令行参数并启动虚拟机

**QEMU 参数构建**:
```javascript
// 基础配置
-machine virt,acpi=on,gic-version=max,...
-cpu max,pauth-impdef=on,sve=off,pmu=off
-accel tcg,thread=multi,tb-size=2048

// 内存与CPU
-smp cpus=N,sockets=1,cores=N,threads=1
-object memory-backend-ram,id=mem0,size=NM
-m NM

// 网络 (用户模式网络 + 端口转发)
-device virtio-net-pci-non-transitional,...
-netdev user,id=eth0,hostfwd=tcp::HOST-:GUEST

// 共享文件夹 (virtio-9p)
-fsdev local,security_model=mapped-file,id=fsdev0,path=...
-device virtio-9p-pci,id=fs0,fsdev=fsdev0,mount_tag=hostshare

// 存储 (virtio-scsi + QCOW2)
-drive if=none,format=qcow2,file=...,id=hd0
-device virtio-scsi-pci-non-transitional
-device scsi-hd,drive=hd0

// VNC (可选)
-vnc :0,password=on
```

#### 3.2.3 N-API 原生桥接层

**文件位置**: `feature/hish_main/src/main/cpp/napi_init.cpp`

**核心功能**:

| 函数 | 描述 |
|------|------|
| `startVM()` | 启动 QEMU 虚拟机 |
| `checkPortUsed()` | 检查端口占用 |
| `sendInput()` | 发送输入到串口 |
| `onData()` | 数据回调注册 |
| `onShutdown()` | 关闭回调注册 |
| `getSnapshots()` | 获取 QCOW2 快照列表 |
| `createSnapshot()` | 创建快照 |

**QEMU 库加载策略**:
```cpp
// 根据设备类型选择 .so：
// phone → TCI (Tiny Code Interpreter) 版本
// tablet/2in1 → JIT 版本
if (supportJit) {
    libQemuHandle = dlopen("libqemu-system-aarch64.so", RTLD_LAZY);
} else {
    libQemuHandle = dlopen("libqemu-system-aarch64-tci.so", RTLD_LAZY);
    if (!libQemuHandle) {
        // 回退到 JIT 版本
        libQemuHandle = dlopen("libqemu-system-aarch64.so", RTLD_LAZY);
    }
}
```

#### 3.2.4 VNC 子系统

**架构设计**: 三线程模型

```
┌─────────────────────────────────────────────────────────────┐
│                    VNC 子系统架构                            │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐     │
│  │ Poll Thread │    │ Render Thread │    │  JS Thread  │     │
│  │ (VNC协议)   │    │ (OpenGL ES)  │    │  (UI)       │     │
│  └─────────────┘    └─────────────┘    └─────────────┘     │
│        │                  │                   │            │
│        │ WaitForMessage   │ markDirty()       │ TSFN       │
│        │ HandleRFBServer  │ ← 唤醒            │ 通知       │
│        │                  │                   │            │
│        ▼                  ▼                   ▼            │
│  ┌─────────────────────────────────────────────────────┐  │
│  │              共享资源 (线程安全保护)                  │  │
│  │  • socketMutex_: 保护 libvncclient socket I/O       │  │
│  │  • 帧缓冲区: 只读访问（Render Thread）               │  │
│  │  • 通知池: 预分配 VncNotifyData[4]                  │  │
│  └─────────────────────────────────────────────────────┘  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**关键文件**:
- `napi_vnc.cpp` - N-API 绑定与线程管理
- `vnc_client.cpp` - libvncclient 封装
- `vnc_renderer.cpp` - OpenGL ES 渲染器

**线程安全注意事项**:
> libvncclient socket I/O 是非线程安全的，poll 循环由 `socketMutex_` 保护。
> 重复发送 `SendFramebufferUpdateRequest` 会导致 QEMU 流不同步。

#### 3.2.5 WebTerminal 组件

**文件位置**: `feature/hish_main/src/main/ets/components/WebTerminal.ets`

**技术栈**: ArkUI + xterm.js

**功能**:
- 终端模拟（通过 xterm.js）
- 虚拟按键支持
- 上下文菜单（复制/粘贴/清屏）
- 字体与颜色配置
- 背景图片与模糊效果

**通信流程**:
```
用户输入 → sendInput() → stringToArrayBuffer() → napi.sendInput()
                                        ↓
VM输出 ← onData() ← napi.onData() ← 串口读取
        ↓
    flushData() (60FPS 合并缓冲) → webview.runJavaScript()
```

---

## 4. 数据模型

### 4.1 Emulator（模拟器配置）

```typescript
interface PortMapping {
  guest?: number    // 来宾端口
  host?: number     // 主机端口
}

interface RootFilesystem {
  id: string
  name: string
  path: string
}

interface Emulator {
  id: string
  name: string
  cpu: number              // CPU 核心数
  memory: number           // 内存大小 (MB)
  init: string             // init 进程路径
  portMapping: PortMapping[]  // 端口转发规则
  rootVda: string          // 根设备路径
  rootFilesystem: string   // 根文件系统路径
  sharedFolderReadonly: boolean  // 共享文件夹只读
}
```

### 4.2 应用配置 (appOption)

**存储键**: 使用 `@ohos.data.preferences` 持久化

| 键 | 描述 |
|------|------|
| `keepScreenOn` | 保持屏幕常亮 |
| `showVirtKey` | 显示虚拟按键 |
| `runningInBackground` | 后台运行 |
| `displayStatusBar` | 显示状态栏 |
| `terminalFontSize` | 终端字体大小 |
| `terminalFontFamily` | 终端字体族 |
| `terminalCursorShape` | 光标形状 |
| `terminalBackgroundColor` | 背景颜色 |
| `emulators` | 模拟器列表 |
| `defaultStartEmulator` | 默认启动模拟器 |

---

## 5. 入口点与数据流

### 5.1 外部输入入口

| 入口点 | 类型 | 描述 |
|--------|------|------|
| `EntryAbility.onCreate()` | 系统回调 | 应用创建 |
| `WebTerminal.sendInput()` | 用户输入 | 终端键盘输入 |
| `VncPage` 鼠标/键盘事件 | 用户输入 | VNC 远程输入 |
| `SharedFolderContent` | 文件操作 | 共享文件夹访问 |
| `startVm()` 端口转发 | 网络 | 外部网络访问 |

### 5.2 数据流图

```
┌─────────────────────────────────────────────────────────────┐
│                        外部输入                              │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐    │
│  │ 键盘输入  │  │ 鼠标输入  │  │ 文件选择  │  │ 网络请求  │    │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘    │
│       │             │             │             │           │
└───────┼─────────────┼─────────────┼─────────────┼───────────┘
        │             │             │             │
        ▼             ▼             ▼             ▼
┌─────────────────────────────────────────────────────────────┐
│                      ArkUI 层                                │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐    │
│  │WebTerminal│  │ VncPage  │  │文件选择器 │  │ xterm.js │    │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘    │
│       │             │             │             │           │
└───────┼─────────────┼─────────────┼─────────────┼───────────┘
        │             │             │             │
        ▼             ▼             ▼             ▼
┌─────────────────────────────────────────────────────────────┐
│                     业务逻辑层                               │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐    │
│  │sendInput │  │VNC事件   │  │文件I/O   │  │端口转发  │    │
│  │(QEMU串口) │  │(RFB协议) │  │(9P协议)  │  │(NAT)     │    │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘    │
│       │             │             │             │           │
└───────┼─────────────┼─────────────┼─────────────┼───────────┘
        │             │             │             │
        ▼             ▼             ▼             ▼
┌─────────────────────────────────────────────────────────────┐
│                     N-API 桥接层                             │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐    │
│  │napi_     │  │napi_vnc  │  │文件API   │  │socket    │    │
│  │init.cpp  │  │.cpp      │  │          │  │          │    │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘    │
│       │             │             │             │           │
└───────┼─────────────┼─────────────┼─────────────┼───────────┘
        │             │             │             │
        ▼             ▼             ▼             ▼
┌─────────────────────────────────────────────────────────────┐
│                     原生层                                   │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐    │
│  │libqemu-  │  │libvnccli │  │libqemu-  │  │QEMU NAT  │    │
│  │system    │  │ent       │  │img       │  │网络栈    │    │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘    │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │              QEMU 虚拟机                              │  │
│  │  • Linux Kernel (aarch64)                            │  │
│  │  • Alpine Rootfs (QCOW2)                             │  │
│  │  • virtio-9p 共享文件夹                               │  │
│  │  • virtio-net 网络                                   │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

---

## 6. 信任边界与安全考量

### 6.1 信任边界

```
┌─────────────────────────────────────────────────────────────┐
│                      外部不可信区域                          │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │ 用户输入     │  │ 网络流量     │  │ 外部文件 (QCOW2)     │  │
│  └──────┬──────┘  └──────┬──────┘  └──────────┬──────────┘  │
│         │                │                    │             │
└─────────┼────────────────┼────────────────────┼─────────────┘
          │                │                    │
          ▼                ▼                    ▼
┌─────────────────────────────────────────────────────────────┐
│                      验证与过滤层                            │
│  • 输入验证 (escape sequences)                              │
│  • 端口范围检查 (1-65535)                                   │
│  • QCOW2 头部验证 (magic, cluster_bits)                     │
│  • 快照名称长度限制 (MAX_SNAPSHOT_NAME_SIZE=4096)           │
└─────────────────────────────────────────────────────────────┘
          │                │                    │
          ▼                ▼                    ▼
┌─────────────────────────────────────────────────────────────┐
│                      内部可信区域                            │
│  • QEMU 进程 (沙箱隔离)                                     │
│  • 文件系统访问 (权限控制)                                  │
│  • 应用偏好设置 (加密存储)                                  │
└─────────────────────────────────────────────────────────────┘
```

### 6.2 安全机制

| 机制 | 实现位置 | 描述 |
|------|----------|------|
| QCOW2 验证 | `napi_init.cpp` | 检查 magic number、cluster_bits 范围 |
| 快照名称限制 | `napi_init.cpp` | 限制名称长度防止 OOM |
| 端口检查 | `startVm.ets` | 检查端口是否被占用 |
| 文件访问控制 | `EntryAbility.ets` | 使用 DocumentViewPicker |
| 输入转义 | `WebTerminal.ets` | 处理特殊控制字符 |

---

## 7. 技术依赖

### 7.1 原生依赖 (deps/)

| 依赖 | 版本 | 用途 |
|------|------|------|
| qemu | 自定义 | 虚拟化核心 |
| libvncclient | - | VNC 客户端 |
| zlib | - | 压缩库 |
| zstd | - | Zstandard 压缩 |
| pcre2 | - | 正则表达式 |
| libglib | - | 基础工具库 |
| pixman | - | 像素操作 |

### 7.2 HarmonyOS Kit 依赖

```json
{
  "dependencies": {
    "@ohos/commons-compress": "^2.0.6"
  },
  "devDependencies": {
    "@ohos/hypium": "1.0.21",
    "@ohos/hamock": "1.0.0"
  }
}
```

### 7.3 使用的系统能力

| Kit | 用途 |
|------|------|
| `@kit.CoreFileKit` | 文件操作 |
| `@kit.ArkUI` | UI 框架 |
| `@kit.AbilityKit` | 应用能力 |
| `@kit.PerformanceAnalysisKit` | 日志输出 |
| `@kit.BasicServicesKit` | 设备信息、剪贴板 |
| `@kit.ArkWeb` | Web 组件 |

---

## 8. 构建与部署

### 8.1 构建流程

```
┌─────────────────────────────────────────────────────────────┐
│                      构建流程                                │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  1. 准备阶段                                                 │
│     ├── git submodule update --init --recursive             │
│     ├── copy build-profile.template.json5 → build-profile.json5 │
│     └── 下载资源 (libs.zip, kernel, rootfs)                 │
│                                                             │
│  2. 原生构建 (可选)                                          │
│     └── cd deps && make [aarch64]                           │
│                                                             │
│  3. HAP 构建                                                 │
│     └── DevEco Studio Build → Build Hap(s)                  │
│                                                             │
│  4. 签名与部署                                               │
│     └── 自动签名 / 手动签名 → 安装到设备                      │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 8.2 产品配置

| 产品 | 路径 | 目标设备 |
|------|------|----------|
| tablet | `product/tablet` | 平板 |
| phone | `product/phone` | 手机 |
| hish_main | `feature/hish_main` | 核心功能模块 |

---

## 9. 总结

HiSH 是一个架构清晰的 HarmonyOS 应用，采用分层架构设计：

1. **UI 层**: 基于 ArkUI 的声明式 UI，支持多设备适配
2. **业务逻辑层**: ArkTS 实现的 VM 管理、QMP 通信、终端控制
3. **N-API 桥接层**: C++ 实现的高效原生绑定
4. **原生层**: QEMU 虚拟化、VNC 渲染、QCOW2 处理

**关键技术亮点**:
- 三线程 VNC 架构（Poll/Render/JS）
- QEMU 库动态加载与 JIT/TCI 策略
- QCOW2 格式直接解析（不依赖 qemu-img）
- 多设备自适应 UI（2in1/平板/手机）

**安全考量**:
- 输入验证与边界检查
- 文件格式严格校验
- 进程沙箱隔离
- 权限最小化原则
