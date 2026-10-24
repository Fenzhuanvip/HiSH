# 云码道网页融合 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 HiSH 内嵌云码道网页，用与终端同屏的可收起抽屉接入（进入/收起不离开终端），视觉暗色一致，网页代码块可一键存到 `/mnt/share`。

**Architecture:** 以 `AppStorage` 作为"配置 + 抽屉开合"的单一真源；`CodeArtsWeb` 组件用 `Web`(ArkWeb) 承载网页，通过注入 JS + 定时轮询回传代码块；`codeartsBridge` 负责写入共享目录；`CodeArtsDrawer` 用 `Stack + animateTo` 实现同屏抽屉；`Index` 两种布局都叠加抽屉；`WebTerminal` 虚拟键栏提供入口。

**Tech Stack:** ArkTS / ArkUI、`@kit.ArkWeb`(Web/WebviewController)、`@ohos.file.fs`、`@ohos.data.preferences`、`@kit.BasicServicesKit`。

## Global Constraints

- 目标 SDK：HarmonyOS 6.1.1 / API 24（与本项目一致），不得使用 API 26+ 的 ArkUI 能力。
- 组件语法沿用本仓库：`@Component struct`、`@Builder`、`@StorageProp/@StorageLink`、`@Watch`。
- 新增面向用户的文案**直接用中文字符串**（不改资源文件，个人版可接受）。
- 不进 `main_pages.json` 注册（抽屉是同屏组件，不是独立页）；不新增 Ability。
- 每个任务结束提交一次 git commit（提交信息见各任务）。
- 本项目**无法在本环境编译**：每个任务的"验证"= 代码审查 + 交由用户在 DevEco Studio 编译；出现编译错误需回改。

## 文件结构

- 新增 `feature/hish_main/src/main/ets/components/codearts/CodeArtsTheme.ets` —— 暗色 token 常量
- 新增 `feature/hish_main/src/main/ets/lib/codeartsBridge.ets` —— 代码块写入共享目录
- 新增 `feature/hish_main/src/main/ets/components/codearts/CodeArtsWeb.ets` —— 云码道网页组件
- 新增 `feature/hish_main/src/main/ets/components/CodeArtsDrawer.ets` —— 同屏抽屉容器
- 修改 `feature/hish_main/src/main/ets/model/appOption.ets` —— 配置键
- 修改 `feature/hish_main/src/main/ets/entryability/EntryAbility.ets` —— 读取配置
- 修改 `feature/hish_main/src/main/ets/pages/Index.ets` —— 叠加抽屉
- 修改 `feature/hish_main/src/main/ets/components/WebTerminal.ets` —— 入口按钮
- 修改 `feature/hish_main/src/main/ets/components/SettingsContent.ets` —— 云码道分区
- 删除 `feature/hish_main/src/main/ets/components/ai/*`、`feature/hish_main/src/main/ets/pages/AiWorkbenchPage.ets`

---

### Task 1: 配置项（appOption + EntryAbility）

**Files:**
- Modify: `feature/hish_main/src/main/ets/model/appOption.ets`
- Modify: `feature/hish_main/src/main/ets/entryability/EntryAbility.ets:163-226`（`loadPreferences`）

**Interfaces:**
- Produces: `appOption.codeartsUrl`（string 键常量）、`appOption.codeartsDarkInject`（string 键常量）、`appOption.codeartsDrawerOpen`（string 键常量，运行时用）

- [ ] **Step 1: 在 `appOption` 类里新增键常量**

在 `appOption.ets` 的 `static isQgaConnected = 'isQgaConnected';`（第 65 行）之后追加：

```ts
  // 云码道网页
  static codeartsUrl = 'codeartsUrl';                 // 云码道网页地址
  static codeartsDarkInject = 'codeartsDarkInject';   // 是否注入暗色
  static codeartsDrawerOpen = 'codeartsDrawerOpen';   // 抽屉开合（运行时，不入 preference）
```

- [ ] **Step 2: 在 `EntryAbility.loadPreferences` 里读取配置**

在 `loadPreferences` 末尾、`rootFilesystems` 那段之后（第 225 行 `AppStorage.setOrCreate(appOption.rootFilesystems, rootFilesystems)` 之后）追加：

```ts
    const codeartsUrl = await appPref.get(appOption.codeartsUrl,
      'https://developer.huaweicloud.com/codeartsco.html') as string;
    AppStorage.setOrCreate(appOption.codeartsUrl, codeartsUrl);
    const codeartsDarkInject = await appPref.get(appOption.codeartsDarkInject, true) as boolean;
    AppStorage.setOrCreate(appOption.codeartsDarkInject, codeartsDarkInject);
    AppStorage.setOrCreate(appOption.codeartsDrawerOpen, false);
```

- [ ] **Step 3: 验证**

Run: 人工审查 `appOption.ets`、`EntryAbility.ets` 两处改动语法正确、键名一致。
Expected: 键常量与读取默认值一一对应；`codeartsco.html` 默认值正确。

- [ ] **Step 4: Commit**

```bash
git add feature/hish_main/src/main/ets/model/appOption.ets feature/hish_main/src/main/ets/entryability/EntryAbility.ets
git commit -m "feat(codearts): add codearts web config keys"
```

---

### Task 2: 暗色 token

**Files:**
- Create: `feature/hish_main/src/main/ets/components/codearts/CodeArtsTheme.ets`

**Interfaces:**
- Produces: `CodeArtsColor` 常量对象（供 Drawer/Web 使用）

- [ ] **Step 1: 创建文件**

```ts
/**
 * 云码道抽屉外壳的暗色视觉 token（与终端暗色主题一致）
 */
export class CodeArtsColor {
  static readonly bg: string = '#0D0D14';         // 抽屉背景
  static readonly card: string = '#1A1B2E';       // 卡片/顶栏
  static readonly primary: string = '#A78BFA';    // 主色（紫）
  static readonly accent: string = '#F472B6';     // 强调（粉）
  static readonly text: string = '#E2E2E9';       // 主文字
  static readonly textSub: string = '#94A3B8';    // 次文字
  static readonly divider: string = '#2A2B3D';    // 分割线
}
```

- [ ] **Step 2: 验证**

Run: 人工审查文件语法（ArkTS 静态类）。
Expected: 无语法错误。

- [ ] **Step 3: Commit**

```bash
git add feature/hish_main/src/main/ets/components/codearts/CodeArtsTheme.ets
git commit -m "feat(codearts): add dark theme tokens"
```

---

### Task 3: codeartsBridge（代码块 → 共享目录）

**Files:**
- Create: `feature/hish_main/src/main/ets/lib/codeartsBridge.ets`

**Interfaces:**
- Produces: `saveCodeBlock(sharedHost: string, content: string, lang: string): void`

- [ ] **Step 1: 创建文件**

```ts
import fs from '@ohos.file.fs';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0001;
const TAG = '[codeartsBridge]';

/** 语言 → 扩展名 */
function extOf(lang: string): string {
  const map: Record<string, string> = {
    'typescript': 'ts', 'ts': 'ts', 'javascript': 'js', 'js': 'js',
    'python': 'py', 'py': 'py', 'java': 'java', 'go': 'go', 'shell': 'sh',
    'bash': 'sh', 'sh': 'sh', 'json': 'json', 'yaml': 'yaml', 'yml': 'yaml',
    'html': 'html', 'css': 'css', 'c': 'c', 'cpp': 'cpp', 'tsx': 'tsx',
    'jsx': 'jsx', 'sql': 'sql', 'xml': 'xml', 'markdown': 'md', 'md': 'md'
  };
  const key = (lang || '').toLowerCase().trim();
  return map[key] || 'txt';
}

/**
 * 把云码道网页里的代码块写入共享目录（guest 端 /mnt/share）
 * @param sharedHost Host 侧共享目录绝对路径（AppStorage(appOption.sharedHost)）
 */
export function saveCodeBlock(sharedHost: string, content: string, lang: string): boolean {
  if (!sharedHost || sharedHost.length === 0) {
    hilog.warn(DOMAIN, TAG, 'sharedHost empty, skip');
    return false;
  }
  if (!content || content.length === 0) {
    return false;
  }
  try {
    const dir = sharedHost.endsWith('/') ? sharedHost : (sharedHost + '/');
    const ext = extOf(lang);
    const name = `code_${Date.now()}.${ext}`;
    const path = dir + name;
    const file = fs.openSync(path, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
    fs.writeSync(file.fd, content);
    fs.closeSync(file);
    hilog.info(DOMAIN, TAG, 'saved code block: %{public}s', path);
    return true;
  } catch (e) {
    hilog.error(DOMAIN, TAG, 'saveCodeBlock failed: %{public}s', JSON.stringify(e));
    return false;
  }
}
```

- [ ] **Step 2: 验证**

Run: 人工审查 `fs.openSync/writeSync/closeSync` 用法与 `EntryAbility` 中 `fs` 用法一致。
Expected: API 名称与项目其他文件一致（`@ohos.file.fs`）。

- [ ] **Step 3: Commit**

```bash
git add feature/hish_main/src/main/ets/lib/codeartsBridge.ets
git commit -m "feat(codearts): bridge code blocks to shared folder"
```

---

### Task 4: CodeArtsWeb（网页组件）

**Files:**
- Create: `feature/hish_main/src/main/ets/components/codearts/CodeArtsWeb.ets`

**Interfaces:**
- Consumes: `saveCodeBlock`（Task 3）、`appOption.codeartsUrl/codeartsDarkInject/sharedHost`（Task 1）
- Produces: `@Component export struct CodeArtsWeb`（无入参，配置来自 AppStorage）

- [ ] **Step 1: 创建文件**

```ts
import { hilog } from '@kit.PerformanceAnalysisKit';
import { webview } from '@kit.ArkWeb';
import { promptAction } from '@kit.ArkUI';
import appOption from '../../model/appOption';
import { saveCodeBlock } from '../../lib/codeartsBridge';

const DOMAIN = 0x0001;
const TAG = '[CodeArtsWeb]';

/** 给每段代码块挂"存到共享目录"按钮，入队到 window.__hishQueue */
const INJECT_SCRIPT = `(function(){
  try {
    window.__hishQueue = window.__hishQueue || [];
    var pres = document.querySelectorAll('pre');
    for (var i = 0; i < pres.length; i++) {
      var pre = pres[i];
      if (pre.__hishTagged) continue;
      pre.__hishTagged = true;
      var codeEl = pre.querySelector('code');
      var lang = '';
      var cls = (codeEl && codeEl.className) || '';
      var m = cls.match(/language-([\\w-]+)/);
      if (m) lang = m[1];
      pre.style.position = 'relative';
      var btn = document.createElement('button');
      btn.textContent = '存到共享目录';
      btn.style.cssText = 'position:absolute;top:6px;right:6px;font-size:12px;padding:2px 8px;border-radius:6px;border:1px solid #A78BFA;background:#1A1B2E;color:#A78BFA;z-index:9999;cursor:pointer';
      (function(p, language){
        btn.onclick = function(){
          var t = p.innerText || '';
          window.__hishQueue.push({content:t, lang:language});
          btn.textContent = '已入队';
          setTimeout(function(){ btn.textContent = '存到共享目录'; }, 1500);
        };
      })(codeEl || pre, lang);
      pre.appendChild(btn);
    }
  } catch(e) {}
})()`;

/** 取出并清空队列 */
const DRAIN_SCRIPT = `(function(){ var q = window.__hishQueue || []; window.__hishQueue = []; return JSON.stringify(q); })()`;

interface CodeBlockItem {
  content: string
  lang: string
}

@Component
export struct CodeArtsWeb {
  @StorageProp(appOption.codeartsUrl) url: string = 'https://developer.huaweicloud.com/codeartsco.html'
  @StorageProp(appOption.codeartsDarkInject) darkInject: boolean = true
  @StorageProp(appOption.sharedHost) sharedHost: string = ''
  controller: webview.WebviewController = new webview.WebviewController()
  @State loading: boolean = true
  @State errorMsg: string = ''
  timer: number = -1

  build() {
    Stack() {
      Web({ src: this.url, controller: this.controller })
        .width('100%').height('100%')
        .javaScriptAccess(true)
        .domStorageAccess(true)
        .imageAccess(true)
        .onlineImageAccess(true)
        .fileAccess(false)
        .mixedMode(MixedMode.All)
        .onPageBegin(() => { this.loading = true })
        .onPageEnd(() => { this.loading = false; this.onLoaded() })
        .onErrorReceive((e) => {
          this.loading = false
          this.errorMsg = '加载失败，请检查网络'
          hilog.error(DOMAIN, TAG, 'web error: %{public}s', JSON.stringify(e?.error))
        })

      if (this.loading) {
        Column() {
          LoadingProgress().width(60).height(60)
          Text('正在加载云码道...').fontSize(14).fontColor('#94A3B8').margin({ top: 10 })
        }.width('100%').height('100%').justifyContent(FlexAlign.Center)
      }

      if (this.errorMsg.length > 0) {
        Column() {
          Text(this.errorMsg).fontSize(14).fontColor('#F472B6')
          Button('重试').margin({ top: 12 }).onClick(() => {
            this.errorMsg = ''
            this.loading = true
            try { this.controller.refresh() } catch (e) { }
          })
        }.width('100%').height('100%').justifyContent(FlexAlign.Center)
      }
    }.width('100%').height('100%')
  }

  aboutToDisappear(): void {
    if (this.timer >= 0) { clearInterval(this.timer); this.timer = -1 }
  }

  private onLoaded(): void {
    this.injectDark()
    this.injectCodeButtons()
    if (this.timer < 0) {
      this.timer = setInterval(() => { this.injectCodeButtons(); this.drainQueue() }, 3000)
    }
  }

  private injectDark(): void {
    if (!this.darkInject) { return }
    const css = `(function(){ if(document.getElementById('__hishDark'))return; var s=document.createElement('style'); s.id='__hishDark'; s.textContent='html,body{background:#0D0D14 !important;color:#E2E2E9 !important;}'; document.head && document.head.appendChild(s); })()`
    try { this.controller.runJavaScript(css) } catch (e) { }
  }

  private injectCodeButtons(): void {
    try { this.controller.runJavaScript(INJECT_SCRIPT) } catch (e) { }
  }

  private drainQueue(): void {
    try {
      this.controller.runJavaScript(DRAIN_SCRIPT).then((res: string) => {
        if (!res || res.length === 0 || res === '[]') { return }
        const items = JSON.parse(res) as CodeBlockItem[]
        items.forEach((it) => {
          const ok = saveCodeBlock(this.sharedHost, it.content, it.lang)
          promptAction.showToast({ message: ok ? '已保存到共享目录' : '共享目录不可用', duration: 2000 })
        })
      }).catch(() => { })
    } catch (e) { }
  }
}
```

- [ ] **Step 2: 验证**

Run: 人工审查。
Expected:
- `Web` 属性与 `GitHubPage.ets:22-26` 风格一致；
- `runJavaScript(...).then` 用法与 `GitHubPage.ets:117` 一致；
- `promptAction` 导入自 `@kit.ArkUI`（若项目用 `getUIContext().getPromptAction()` 则改为此方式，参考 `EntryAbility`）。

- [ ] **Step 3: Commit**

```bash
git add feature/hish_main/src/main/ets/components/codearts/CodeArtsWeb.ets
git commit -m "feat(codearts): embed codearts webview with code-block bridge"
```

---

### Task 5: CodeArtsDrawer（同屏抽屉容器）

**Files:**
- Create: `feature/hish_main/src/main/ets/components/CodeArtsDrawer.ets`

**Interfaces:**
- Consumes: `CodeArtsWeb`（Task 4）、`CodeArtsColor`（Task 2）、`appOption.codeartsDrawerOpen`（Task 1）
- Produces: `@Component export struct CodeArtsDrawer { width size }`

- [ ] **Step 1: 创建文件**

```ts
import appOption from '../model/appOption';
import { CodeArtsWeb } from './codearts/CodeArtsWeb';
import { CodeArtsColor } from './codearts/CodeArtsTheme';
import { ImmersiveButtonModifier } from '../lib/immersiveButton';

@Component
export struct CodeArtsDrawer {
  @StorageLink(appOption.codeartsDrawerOpen) open: boolean = false
  panelWidth: number = 380
  immersiveButton: ImmersiveButtonModifier = new ImmersiveButtonModifier()

  build() {
    Stack({ alignContent: Alignment.TopEnd }) {
      // 贴边把手：始终可见，点击开合
      Button({ buttonStyle: ButtonStyleMode.TEXTUAL }) {
        Text(this.open ? '▸' : '◂').fontSize(16).fontColor(CodeArtsColor.primary)
      }
      .width(24).height(72)
      .margin({ top: 120 })
      .backgroundColor(CodeArtsColor.card)
      .borderRadius({ topLeft: 12, bottomLeft: 12 })
      .attributeModifier(this.immersiveButton)
      .onClick(() => { animateTo({ duration: 220, curve: Curve.EaseInOut }, () => { this.open = !this.open }) })

      // 面板
      Column() {
        Row() {
          Text('云码道').fontSize(16).fontColor(CodeArtsColor.text).layoutWeight(1)
          Button({ buttonStyle: ButtonStyleMode.TEXTUAL }) {
            Text('收起').fontSize(13).fontColor(CodeArtsColor.textSub)
          }
          .attributeModifier(this.immersiveButton)
          .onClick(() => { animateTo({ duration: 220 }, () => { this.open = false }) })
        }
        .width('100%').height(44).padding({ left: 14, right: 8 })
        .backgroundColor(CodeArtsColor.card)

        CodeArtsWeb()
          .width('100%').layoutWeight(1)
      }
      .width(this.panelWidth)
      .height('100%')
      .backgroundColor(CodeArtsColor.bg)
      .shadow({ radius: 24, color: '#000000', offsetX: -6, offsetY: 0 })
      .translate({ x: this.open ? 0 : this.panelWidth })
    }
    .width('100%').height('100%')
    .hitTestBehavior(HitTestMode.Transparent)
  }
}
```

- [ ] **Step 2: 验证**

Run: 人工审查。
Expected: `animateTo`/`translate`/`hitTestBehavior` 用法为标准 ArkUI API；`ImmersiveButtonModifier` 从 `../lib/immersiveButton` 导入。

- [ ] **Step 3: Commit**

```bash
git add feature/hish_main/src/main/ets/components/CodeArtsDrawer.ets
git commit -m "feat(codearts): add same-screen collapsible drawer"
```

---

### Task 6: Index 叠加抽屉

**Files:**
- Modify: `feature/hish_main/src/main/ets/pages/Index.ets:16-180`（PcIndex）、`:320-332`（PhoneOrTablet）

**Interfaces:**
- Consumes: `CodeArtsDrawer`（Task 5）

- [ ] **Step 1: 导入组件**

在 `Index.ets` 顶部 import 区（第 14 行附近）追加：

```ts
import { CodeArtsDrawer } from '../components/CodeArtsDrawer';
```

- [ ] **Step 2: 用 Stack 包裹 PcIndex 的根 Column 并叠加抽屉**

把 `PcIndex.build()` 的根 `Column(){...}`（第 68-177 行）改为：

```ts
    Stack() {
      Column() {
        /* ……原有 Column 内容保持不变…… */
      }
      .width('100%').height('100%')

      CodeArtsDrawer()
        .width('100%').height('100%')
    }
    .width('100%').height('100%')
```

- [ ] **Step 3: 同样处理 PhoneOrTablet**

把 `PhoneOrTablet.build()`（第 323-330 行）改为：

```ts
  build() {
    Stack() {
      Column() {
        WebTerminal({ virtKeyEnabled: true })
          .layoutWeight(1)
      }
      .width('100%').height('100%')

      CodeArtsDrawer()
        .width('100%').height('100%')
    }
    .width('100%').height('100%')
  }
```

- [ ] **Step 4: 验证**

Run: 人工审查。
Expected: 两处 build() 的括号配平；`CodeArtsDrawer` 在最上层（后声明）。

- [ ] **Step 5: Commit**

```bash
git add feature/hish_main/src/main/ets/pages/Index.ets
git commit -m "feat(codearts): overlay drawer on terminal layouts"
```

---

### Task 7: WebTerminal 入口按钮

**Files:**
- Modify: `feature/hish_main/src/main/ets/components/WebTerminal.ets`（`buildVirtualKeys` 内、`settingsButton()` 附近）

**Interfaces:**
- Consumes: `appOption.codeartsDrawerOpen`（Task 1）

- [ ] **Step 1: 新增入口 Builder**

在 `settingsButton()`（第 161-172 行）之后追加：

```ts
  @Builder
  codeartsButton() {
    Button({ buttonStyle: ButtonStyleMode.TEXTUAL }) {
      SymbolGlyph($r('sys.symbol.cloud'))
        .fontSize(16)
        .fontColor([this.keyFontColor])
    }
    .height(VKeyHeight)
    .width(VKeyHeight)
    .borderRadius(VKeyRadius)
    .margin(VKeyMargin)
    .attributeModifier(this.immersiveButton)
    .onClick(() => {
      AppStorage.setOrCreate(appOption.codeartsDrawerOpen, true)
    })
  }
```

- [ ] **Step 2: 在虚拟键栏第一行右侧调用它**

在 `buildVirtualKeys()` 中、`this.settingsButton()` 调用点前插入 `this.codeartsButton()`（保持与设置按钮同排）。

```ts
      this.codeartsButton()
      this.settingsButton()
```

> 说明：`sys.symbol.cloud` 若在本项目 SDK 不存在，换成 `sys.symbol.rectangle_stack` 或 `sys.symbol.globe`；编译期报 symbol 未定义时按提示替换。

- [ ] **Step 3: 验证**

Run: 人工审查 `buildVirtualKeys` 调用块，确认 `codeartsButton()` 已定义且被调用。
Expected: `@Builder` 名称一致；`appOption` 已在本文件 import（第 7 行已有）。

- [ ] **Step 4: Commit**

```bash
git add feature/hish_main/src/main/ets/components/WebTerminal.ets
git commit -m "feat(codearts): add drawer entry button to virtual keys"
```

---

### Task 8: SettingsContent 云码道分区

**Files:**
- Modify: `feature/hish_main/src/main/ets/components/SettingsContent.ets`（顶部状态 + `build()` 分区）

**Interfaces:**
- Consumes: `appOption.codeartsUrl`、`appOption.codeartsDarkInject`（Task 1）、`savePreference`（已有）

- [ ] **Step 1: 增加状态与保存方法**

在组件状态区（第 55 行 `@Watch('saveTermUserFonts') ...` 之后）追加：

```ts
  @Watch('saveCodeartsUrl') @StorageProp(appOption.codeartsUrl) codeartsUrl: string =
    'https://developer.huaweicloud.com/codeartsco.html'
  @Watch('saveCodeartsDarkInject') @StorageProp(appOption.codeartsDarkInject) codeartsDarkInject: boolean = true
```

并在其它 `saveXxx` 方法附近追加：

```ts
  async saveCodeartsUrl() {
    await savePreference(appOption.codeartsUrl, this.codeartsUrl, this.getUIContext())
  }

  async saveCodeartsDarkInject() {
    await savePreference(appOption.codeartsDarkInject, this.codeartsDarkInject, this.getUIContext())
  }
```

- [ ] **Step 2: 在 `build()` 里新增分区**

在 `build()` 的 `Scroll { Column { ... } }` 内、最后一段设置分区之后追加：

```ts
          BlockTitle({ content: '云码道' })
          Column() {
            SettingItem({
              title: '网页地址',
              subTitle: '云码道聊天页地址（可修改）',
              content: () => {
                TextInput({ text: this.codeartsUrl })
                  .width(180)
                  .fontSize(12)
                  .backgroundColor('#1A1B2E')
                  .fontColor('#E2E2E9')
                  .onChange((v: string) => { AppStorage.setOrCreate(appOption.codeartsUrl, v) })
              }
            })

            SettingItem({
              title: '网页暗色',
              subTitle: '强制网页使用暗色（部分页面可能不适用）',
              content: () => {
                Toggle({ type: ToggleType.Switch, isOn: this.codeartsDarkInject })
                  .onChange((v: boolean) => { AppStorage.setOrCreate(appOption.codeartsDarkInject, v) })
              }
            })
          }
          .attributeModifier(this.blockStyle)
```

- [ ] **Step 3: 验证**

Run: 人工审查。
Expected: `@StorageProp/@Watch` 对应方法名匹配（`saveCodeartsUrl`/`saveCodeartsDarkInject`）；`TextInput`/`Toggle` 语法正确；分区位于 `Column` 内、`Scroll` 可滚动范围中。

- [ ] **Step 4: Commit**

```bash
git add feature/hish_main/src/main/ets/components/SettingsContent.ets
git commit -m "feat(codearts): add codearts section in settings"
```

---

### Task 9: 清理旧组件

**Files:**
- Delete: `feature/hish_main/src/main/ets/components/ai/AiChat.ets`、`AiWorkbench.ets`、`RepoList.ets`、`PrList.ets`、`IssueList.ets`、`PipelineList.ets`
- Delete: `feature/hish_main/src/main/ets/pages/AiWorkbenchPage.ets`
- Modify（如有残留引用）：`feature/hish_main/Index.ets`、各处 `product/*/src/main/ets/pages/AiWorkbenchPage.ets`

**Interfaces:**
- Consumes: 无

- [ ] **Step 1: 确认无外部引用**

Run:
```bash
grep -rn "components/ai/\|AiWorkbenchPage\|AiChat\|AiWorkbench\|RepoList\|PrList\|IssueList\|PipelineList" feature product --include=*.ets
```
Expected: 仅剩被删除文件自身与 `product/*/pages/AiWorkbenchPage.ets`（re-export）出现。

- [ ] **Step 2: 删除 ai 目录与 AiWorkbenchPage**

```bash
git rm -r feature/hish_main/src/main/ets/components/ai
git rm feature/hish_main/src/main/ets/pages/AiWorkbenchPage.ets
git rm product/phone/src/main/ets/pages/AiWorkbenchPage.ets product/tablet/src/main/ets/pages/AiWorkbenchPage.ets
```

- [ ] **Step 3: 移除 `main_pages.json` 中 AiWorkbenchPage 注册（若存在）**

Run:
```bash
grep -rn "AiWorkbenchPage" product/*/src/main/resources product/*/src/main/ets 2>/dev/null
```
如有匹配，从对应 `main_pages.json` 的 `src` 数组中删除该行。

- [ ] **Step 4: 验证**

Run: 再次执行 Step 1 的 grep。
Expected: 无任何引用残留。

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "chore(codearts): remove legacy ai components"
```

---

### Task 10: 交付前整体检查

**Files:** 全部改动

- [ ] **Step 1: 全量引用自检**

Run:
```bash
grep -rn "codeartsUrl\|codeartsDarkInject\|codeartsDrawerOpen\|CodeArtsDrawer\|CodeArtsWeb\|saveCodeBlock" feature --include=*.ets
```
Expected: 键名/类名/函数名在各文件间拼写一致。

- [ ] **Step 2: 交由用户编译**

Run（用户侧）：DevEco Studio 打开 → Build。
Expected: 编译通过、可安装；在真机验证：
1. 终端快捷键栏出现云码道入口按钮；
2. 点击 → 抽屉从右侧滑出，**无需退出终端即可看/用终端**，点把手/收起可滑回；
3. 云码道网页加载、可登录、可聊天，**不闪退**；
4. 网页代码块出现"存到共享目录"按钮，点击后 `/mnt/share` 出现 `code_*.txt`；
5. 设置页「云码道」分区可改地址、开关暗色。

- [ ] **Step 3: Commit（如修复编译问题后）**

```bash
git add -A && git commit -m "fix(codearts): compile fixes from DevEco"
```

---

## 自审记录（Self-Review）

- **Spec 覆盖**：v4 设计 5 项 → Task 1(配置)、Task 4(网页/防闪退)、Task 5+6+7(抽屉/入口)、Task 3+4(代码块存共享目录)、Task 1+8(地址可配置/登录态)；暗色 → Task 2 + Task 4 注入。清理 → Task 9。✅
- **占位符扫描**：无 TBD/TODO；每个代码步骤给出完整片段。`sys.symbol.cloud` 备选已注明。
- **类型/命名一致性**：`appOption.codeartsUrl/codeartsDarkInject/codeartsDrawerOpen`、`saveCodeBlock(sharedHost,content,lang)`、`CodeArtsWeb`、`CodeArtsDrawer`、`CodeArtsColor` 全文一致。✅
- **已知限制**：本环境无法编译；`promptAction` 导入方式需按项目实际（`@kit.ArkUI` 或 `getUIContext().getPromptAction()`）在 DevEco 编译时二选一。