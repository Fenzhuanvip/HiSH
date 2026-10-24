# HiSH × 云码道网页融合设计（v4）

- 日期：2026-10-24
- 状态：待评审
- 目标仓库：Fenzhuanvip/HiSH（个人定制版）

## 0. 修订说明

- **v1**：误判"云码道"为 CodeArts DevOps 管理平台 → 作废。
- **v2**：修正为"云码道 = 能聊天的 CodeArts 代码智能体"，设计内嵌网页聊天。
- **v3**：曾计划"云码道网页 + DevOps 原生工作台并存"。
- **v4（本版）**：**实测确认** —— 云码道/CLI 能通过 KooCLI 调 CodeArts 全系列（仓库 ✅ 拉到真实数据、流水线 ✅、构建 ✅ 接口通、代码检查接口通但该账号该项目权限不足）。既然 AI/CLI 能调，**不再另做原生 DevOps 工作台**，最终**只做云码道网页融合**。

## 1. 目标

在 HiSH 里内嵌云码道网页聊天，并与 HiSH 完美融合：

1. 内嵌云码道网页，华为云账号登录后直接对话
2. 视觉与终端暗色一致，像原生的一部分
3. 与终端**同屏的可收起抽屉**，随时唤起、不打断终端
4. 网页里的**代码块一键保存到 `/mnt/share` 共享目录**
5. 地址可配置、登录态可保持

## 2. 现状盘点

| 现状 | 路径 | 问题 |
|---|---|---|
| 已内嵌云码道网页 | `components/ai/AiChat.ets`（`codeartsco.html`） | 浅色、粗糙、无入口 |
| 另一份网页页 | `pages/AiWorkbenchPage.ets` | 带 `hishTerminal` 桥，未被使用 |
| 正确 WebView 写法参考 | `GitHubPage.ets:19-46`、`AiChat.ets:48-65` | 有 `domStorageAccess` 等属性 |
| 命令注入桥 | `napi.sendInput(stringToArrayBuffer(cmd))` | `GitHubPage.ets:127` 同款 |

> 注：`codeartsco.html` 静态抓取返回的是"开发者联盟/活动"页模板（疑似 SPA），真实聊天内容需在 WebView 内登录后渲染——因此**地址做成可配置**。

## 3. 范围（5 项）

1. 云码道网页内嵌（正确 WebView 配置，规避闪退）
2. 暗色/主题融合
3. 同屏抽屉入口
4. 代码块保存到共享目录
5. 地址可配置 + 登录态保持

（不含：DevOps 原生工作台、AK/SK 配置——已由实测结论排除）

## 4. 总体架构

```
┌──────────────────────── HiSH App ────────────────────────┐
│  Index (PcIndex / PhoneOrTablet)                          │
│   └─ Stack                                                │
│       ├─ WebTerminal (终端, 保持不动)                      │
│       └─ CodeArtsDrawer (可收起同屏面板, 新增)              │
│            └─ CodeArtsWeb (WebView 加载云码道网页, 新增)    │
│                 │ 注入 JS 抓代码块 / javaScriptProxy 回传   │
│                 ▼                                          │
│            codeartsBridge ──写文件──► sharedHost(/mnt/share)│
│                                                           │
│  SettingsContent ──► 「云码道」分区: 地址 / 暗色开关 / 清缓存 │
└───────────────────────────────────────────────────────────┘
```

## 5. 详细设计

### 5.1 网页内嵌与防闪退

- `Web` 组件配置（对齐 `GitHubPage.ets` / `AiChat.ets`）：
  `javaScriptAccess(true)`、`domStorageAccess(true)`（保登录态）、`imageAccess(true)`、`onlineImageAccess(true)`、`fileAccess(false)`、`mixedMode(MixedMode.All)`、`darkMode(WebDarkMode.Off)`、`forceDarkAccess(false)`
- 三态：加载中 / 失败（`onErrorReceive`、`onHttpErrorReceive` 给错误码 + 重试）/ 正常
- `onControllerAttached` 里设置，避免早期调用崩溃
- 登录态：`domStorageAccess(true)` 保留 cookie/localStorage，登录在 WebView 内完成（华为云账号 / 扫码）

### 5.2 暗色/主题融合

- 抽屉外壳（顶栏、背景、按钮）用暗色 token：背景 `#0D0D14`、卡片 `#1A1B2E`、主色 `#A78BFA`/`#F472B6`
- 网页若不自带暗色：`runJavaScript` 注入 CSS 强制暗色（**带开关**，避免破坏布局）
- 圆角/阴影与 HiSH 其他面板一致

### 5.3 同屏抽屉入口

- `Index.ets` 的 `PcIndex` / `PhoneOrTablet` 外层 `Stack` 叠加 `CodeArtsDrawer`
- `@State drawerOpen: boolean`；`animateTo` 平移进出；PC/平板约 380vp，手机半屏
- 贴边把手（点击/可拖动）随时唤起收起
- 打开时不抢终端输入焦点，终端保持可输入
- 入口：`WebTerminal.buildVirtualKeys()` 第一行右侧、紧邻 `settingsButton()`，`SymbolGlyph`（`sys.symbol.cloud`）→ 开合抽屉

### 5.4 代码块保存到共享目录

- 注入 JS：抓当前消息的代码块（`pre > code`，含语言标注）或选中文本
- 经 `javaScriptProxy`(`hishBridge`) 回传 `{content, lang}`
- 宿主用 `@ohos.file.fs` 写入 `AppStorage(appOption.sharedHost)`（guest 端 `/mnt/share`）
- 命名 `code_<时间戳>.<ext>`；成功/失败 toast

### 5.5 配置与登录态

- 新增 `appOption.codeartsUrl`（默认沿用 `codeartsco.html`）、`appOption.codeartsDarkInject`（默认 true）
- `EntryAbility.loadPreferences()` 读取进 `AppStorage`
- 设置页「云码道」分区：地址输入、暗色注入开关、打开网页/登录、清缓存（登出）

## 6. 文件清单

### 新增
- `components/codearts/CodeArtsTheme.ets`（抽屉外壳暗色 token）
- `components/codearts/CodeArtsWeb.ets`（云码道网页组件，替代 `AiChat`）
- `components/CodeArtsDrawer.ets`（同屏抽屉）
- `lib/codeartsBridge.ets`（代码块 → 共享目录）

### 修改
- `model/appOption.ets`（`codeartsUrl`、`codeartsDarkInject`）
- `entryability/EntryAbility.ets`（读取配置）
- `components/SettingsContent.ets`（「云码道」分区）
- `components/WebTerminal.ets`（入口按钮）
- `pages/Index.ets`（叠加抽屉）
- `feature/hish_main/Index.ets`（导出）

### 删除
- `components/ai/` 整目录：`AiChat.ets`、`AiWorkbench.ets`、`RepoList.ets`、`PrList.ets`、`IssueList.ets`、`PipelineList.ets`
- `pages/AiWorkbenchPage.ets`

## 7. 配置模型

| 键 | 存储 | 默认 | 说明 |
|---|---|---|---|
| `codeartsUrl` | preference | `https://developer.huaweicloud.com/codeartsco.html` | 云码道网页地址，可改 |
| `codeartsDarkInject` | preference | `true` | 是否注入暗色 |

## 8. 错误处理

- 网页加载失败 → 错误码 + 重试
- 写入共享目录失败 → toast「共享目录不可用」
- 暗色注入异常 → 自动关闭注入并提示
- 登录过期 → 设置里「清缓存」重新登录

## 9. 风险与验证

| 风险 | 影响 | 缓解 |
|---|---|---|
| WebView 加载云码道闪退/白屏 | 不可用 | 正确属性配置 + 真机验证 + 错误兜底 |
| 云码道地址不确定（现为活动页模板） | 加载错页 | 做成可配置，用户填真实聊天地址 |
| 第三方登录在 WebView 受限 | 无法登录 | 真机验证；必要时自定义 UA |
| 暗色注入被 CSP 限制/破坏布局 | 显示异常 | 提供开关，默认试探 |
| 无 SDK 无法本地编译 | 交付风险 | 需用户在 DevEco 编译验证并反馈 |

## 10. 实施顺序

1. `CodeArtsWeb` 网页组件（正确 WebView 配置 + 三态 + 可配置地址）
2. `codeartsBridge`（代码块 → 共享目录）
3. `CodeArtsDrawer` + `Index` 叠加 + `WebTerminal` 入口
4. 暗色融合（外壳 token + 可选注入）
5. 设置页「云码道」分区
6. 清理旧 `components/ai/` 与 `AiWorkbenchPage`

## 11. 验收标准

- 抽屉可从终端同屏唤起/收起，**不打断终端输入**
- 云码道网页能加载、登录、聊天，**不闪退**
- 网页里的代码块可一键保存到 `/mnt/share`
- 视觉与终端暗色一致
- 地址可在设置页修改
- 项目在 DevEco Studio 编译通过、可安装运行