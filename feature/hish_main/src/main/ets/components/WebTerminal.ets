import util from '@ohos.util';
import { buffer } from '@kit.ArkTS';
import { hilog } from '@kit.PerformanceAnalysisKit';
import napi from 'libhish_main.so';
import { webview } from '@kit.ArkWeb';
import { pasteboard, deviceInfo } from '@kit.BasicServicesKit'
import appOption, { CursorShape, savePreference, UserFont, UserFontData } from '../model/appOption';
import { common } from '@kit.AbilityKit';
import { SymbolGlyphModifier } from '@kit.ArkUI';
import stringToArrayBuffer from '../lib/stringToArrayBuffer';
import fileToDataUrl from '../lib/fileToDataUrl';
import { ImmersiveButtonModifier, ImmersiveToggleModifier } from '../lib/immersiveButton';
import {
  applyVirtualKeyModifiers,
  FunctionKeySequences,
  getVirtualKeyMetrics,
  NormalKeySequences
} from '../lib/terminalVirtualKeys';

const DOMAIN = 0x0000;

const VKeyMetrics = getVirtualKeyMetrics(deviceInfo.deviceType)
const VKeyMargin = VKeyMetrics.margin;
const VKeyPadding = VKeyMetrics.padding;
const VKeyHeight = VKeyMetrics.height;
const VKeyWidth = VKeyMetrics.width;
const VKeyFontSize = VKeyMetrics.fontSize;
const VKeyRadius = VKeyMetrics.radius;

@Component
export default struct WebTerminal {
  @Require virtKeyEnabled: boolean = true
  @State ctrlPressed: boolean = false
  @State shiftPressed: boolean = false
  @State fnPressed: boolean = false
  @Watch('onFontSizeChanged') @StorageProp(appOption.terminalFontSize) fontSize: number | null = null
  @Watch('onFontFamilyChanged') @StorageProp(appOption.terminalFontFamily) fontFamily: string = 'Default'
  @Watch('onCursorShapeChanged') @StorageProp(appOption.terminalCursorShape) cursorShape: CursorShape | null = null
  @Watch('onCursorBlinkChanged') @StorageProp(appOption.terminalCursorBlink) cursorBlink: boolean | null = null
  @Watch('saveShowVirtKey') @StorageProp(appOption.showVirtKey) showVirtKey: boolean = true
  @StorageProp(appOption.vncEnabled) vncEnabled: boolean = false
  @Watch('onLigaturesChanged') @StorageProp(appOption.terminalLigatures) termLigatures: boolean = false
  @Watch('onItalicChanged') @StorageProp(appOption.terminalItalic) termItalic: boolean = true
  @Watch('onBgColorChanged') @StorageProp(appOption.terminalBackgroundColor) termBgColor: string = '#000000'
  @Watch('onBgImageChanged') @StorageProp(appOption.terminalBackgroundImage) termBgImage: string = ''
  @Watch('onBgBlurChanged') @StorageProp(appOption.terminalBackgroundBlur) termBgBlur: number = 0
  @Watch('onUserFontsChanged') @StorageProp(appOption.terminalUserFonts) termUserFonts: UserFont[] = []
  webviewController: WebviewController = new webview.WebviewController()
  utf8Decoder = util.TextDecoder.create('utf-8', { ignoreBOM: true })
  resizeTimeout?: number = undefined
  applicationMode: boolean = false
  @State keyFontColor: string = '#ffffff'
  @State showAIInput: boolean = false
  @State aiInputText: string = ''
  @State showGitHubWebView: boolean = false
  githubWebController: webview.WebviewController = new webview.WebviewController()
  immersiveButton: ImmersiveButtonModifier = new ImmersiveButtonModifier()
  immersiveToggle: ImmersiveToggleModifier = new ImmersiveToggleModifier()

            const board = pasteboard.getSystemPasteboard()
            const pasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text)
            board.setData(pasteData)
          }
        })
      PasteButton({ text: PasteDescription.PASTE, buttonType: ButtonType.Normal })
        .onClick(async (event: ClickEvent, result: PasteButtonOnClickResult) => {
          if (PasteButtonOnClickResult.SUCCESS === result) {
            let board = pasteboard.getSystemPasteboard();
            const data = await board.getData()
            const text = data.getPrimaryText()
            const array = util.TextEncoder.create().encodeInto(text)
            const base64 = new util.Base64Helper().encodeToStringSync(array)
            webController.runJavaScript(`exports.paste(atob('${base64}'))`)
          }
        })
        .fontColor(this.keyFontColor)
        .backgroundColor('#1AA78BFA')
        .padding({ left: 12, right: 12 })
        .width('100%')
      MenuItem({ content: $r('app.string.menu_clear_screen') })
        .width('100%')
        .onClick(() => {
          webController.runJavaScript('exports.clearScreen()')
        })
    }
    .width('160vp')
  }

  /**
   * @param appCode code used in application mode
   */
  @Builder
  buildVKey(name: string, value: string, appCode?: string) {
    Button(name, { buttonStyle: ButtonStyleMode.TEXTUAL })
      .height(VKeyHeight)
      .width(VKeyWidth)
      .borderRadius(VKeyRadius)
      .fontSize(VKeyFontSize)
      .fontColor(this.keyFontColor)
      .margin(VKeyMargin)
      .padding({ left: VKeyPadding, right: VKeyPadding })
      .backgroundColor('#1AA78BFA')
      .attributeModifier(this.immersiveButton)
      .onClick(() => {
        if (this.applicationMode && appCode) {
          this.sendInput(appCode);
        } else {
          this.sendInput(value)
        }
      })
  }

  @Builder
  toggleCtrlKey(name: string, action: () => void) {
    Toggle({ type: ToggleType.Button, isOn: this.ctrlPressed }) {
      Text(name).fontSize(VKeyFontSize).fontWeight(FontWeight.Medium)
    }
    .height(VKeyHeight)
    .width(VKeyWidth)
    .borderRadius(VKeyRadius)
    .margin(VKeyMargin)
    .selectedColor($r('sys.color.interactive_active'))
    .attributeModifier(this.immersiveToggle)
    .onClick(() => action())
  }

  @Builder
  toggleShiftKey(name: string, action: () => void) {
    Toggle({ type: ToggleType.Button, isOn: this.shiftPressed }) {
      Text(name).fontSize(VKeyFontSize).fontWeight(FontWeight.Medium)
    }
    .height(VKeyHeight)
    .width(VKeyWidth)
    .borderRadius(VKeyRadius)
    .margin(VKeyMargin)
    .selectedColor($r('sys.color.interactive_active'))
    .attributeModifier(this.immersiveToggle)
    .onClick(() => action())
  }

  @Builder
  toggleFnKey(name: string, action: () => void) {
    Toggle({ type: ToggleType.Button, isOn: this.fnPressed }) {
      Text(name).fontSize(VKeyFontSize).fontWeight(FontWeight.Medium)
    }
    .height(VKeyHeight)
    .width(VKeyWidth)
    .borderRadius(VKeyRadius)
    .margin(VKeyMargin)
    .selectedColor($r('sys.color.interactive_active'))
    .attributeModifier(this.immersiveToggle)
    .onClick(() => action())
  }

  @Builder
  settingsButton() {
    Button({ buttonStyle: ButtonStyleMode.TEXTUAL }) {
      Image($r('app.media.gearshape')).width(16).height(16).padding(0)
    }
    .height(VKeyHeight)
    .width(VKeyHeight)
    .borderRadius(VKeyRadius)
    .margin(VKeyMargin)
    .attributeModifier(this.immersiveButton)
    .bindMenu(this.settingsButtonOptions())
  }

  private settingsButtonOptions(): MenuElement[] {
    const vncOptions: MenuElement[] = this.vncEnabled ? [{
      value: $r('app.string.vnc_console_title'),
      action: () => {
        const vncEnabled = AppStorage.get<boolean>(appOption.vncEnabled)!!
        if (vncEnabled) {
          this.getUIContext().getRouter().pushUrl({
            url: 'pages/VncPage'
          });
        } else {
          this.getUIContext().getPromptAction().showToast({ message: $r('app.string.vnc_service_not_started') });
        }
      }
    }] : []
    const regularOptions: MenuElement[] = [{
      value: 'codearts',
      symbolIcon: new SymbolGlyphModifier($r('sys.symbol.gearshape')).fontSize($r('sys.float.Title_S')),
      action: () => this.getUIContext().getRouter().pushUrl({ url: 'pages/AiWorkbenchPage' })
    }, {
      value: 'GitHub',
      symbolIcon: new SymbolGlyphModifier($r('sys.symbol.folder')).fontSize($r('sys.float.Title_S')),
      action: () => {
        this.showGitHubWebView = true
      } catch (e) {
          hilog.error(DOMAIN, 'WebTerminal', 'GitHub pushUrl failed: %{public}s', JSON.stringify(e))
          this.getUIContext().getPromptAction().showToast({ message: 'Route failed: ' + JSON.stringify(e) })
        }
      }
    }, {
      value: $r('app.string.menu_emulator_management'),
      symbolIcon: new SymbolGlyphModifier($r('sys.symbol.more')).fontSize($r('sys.float.Title_S')),
      action: () => this.getUIContext().getRouter().pushUrl({ url: 'pages/EmulatorManagementPage' })
    }, {
      value: $r('app.string.menu_shared_folder'),
      symbolIcon: new SymbolGlyphModifier($r('sys.symbol.folder')).fontSize($r('sys.float.Title_S')),
      action: () => this.getUIContext().getRouter().pushUrl({ url: 'pages/SharedFolderPage' })
    }, {
      value: $r('app.string.menu_settings'),
      symbolIcon: new SymbolGlyphModifier($r('sys.symbol.gearshape')).fontSize($r('sys.float.Title_S')),
      action: () => this.getUIContext().getRouter().pushUrl({ url: 'pages/SettingsPage' })
    }]
    return [...vncOptions, ...regularOptions];
  }

  @Builder
  buildAIButton() {
    Button('AI', { buttonStyle: ButtonStyleMode.TEXTUAL })
      .height(VKeyHeight)
      .width(VKeyWidth)
      .borderRadius(VKeyRadius)
      .fontSize(VKeyFontSize)
      .fontColor('#A78BFA')
      .margin(VKeyMargin)
      .padding({ left: VKeyPadding, right: VKeyPadding })
      .backgroundColor('#33A78BFA')
      .onClick(() => {
        this.showAIInput = !this.showAIInput
        if (!this.showAIInput) {
          this.aiInputText = ''
        }
      })
  }

  @Builder
  hideVKeyButton() {
    Button('▼', { buttonStyle: ButtonStyleMode.TEXTUAL })
      .height(VKeyHeight)
      .width(VKeyHeight)
      .borderRadius(VKeyRadius)
      .margin(VKeyMargin)
      .padding({ left: VKeyPadding, right: VKeyPadding })
      .fontColor(this.keyFontColor)
      .attributeModifier(this.immersiveButton)
      .onClick(() => {
        this.showVirtKey = false
      })
  }

  build() {
    Stack() {
    Column() {
      Web({
        src: $rawfile('term/term.html'),
        controller: this.webviewController
      })
        .javaScriptProxy({
          object: this,
          name: 'native',
          methodList: ['sendInput', 'resize', 'load',
            'getFontSize', 'getFontFamily',
            'getCursorShape', 'getCursorBlink',
            'getLigatures', 'getItalic',
            'getBackgroundColor', 'getBackgroundImage', 'getBackgroundBlur',
            'getUserFonts',
            'setApplicationMode',
            'onAvailableFontsDetected'],
          controller: this.webviewController,
          asyncMethodList: [],
          permission: `{
          "javascriptProxyPermission": {
            "urlPermissionList": [
              {
                "scheme": "resource",
                "host": "rawfile",
                "port": "",
                "path": ""
              }
            ]
          }
        }`
        })
        .backgroundColor('#0D0D12')
        .layoutWeight(1)
        .bindContextMenu(this.contextMenu(this.webviewController), ResponseType.RightClick)
      if (this.showAIInput) {
        Row() {
          TextInput({ text: this.aiInputText, placeholder: '输入你想做的事，如：查看磁盘空间' })
            .layoutWeight(1)
            .height(36)
            .fontSize(14)
            .borderRadius(10)
            .backgroundColor('#F5F5FA')
            .onChange((value: string) => {
              this.aiInputText = value
            })
            .onSubmit(() => {
              this.executeAICommand()
            })
          Button('✓')
            .height(36)
            .width(36)
            .borderRadius(10)
            .fontSize(18)
            .fontColor('#FFFFFF')
            .backgroundColor('#F472B6')
            .margin({ left: 6 })
            .onClick(() => {
              this.executeAICommand()
            })
          Button('✗')
            .height(36)
            .width(36)
            .borderRadius(10)
            .fontSize(16)
            .fontColor('#9B9BA8')
            .backgroundColor('#252637')
            .margin({ left: 6 })
            .onClick(() => {
              this.showAIInput = false
              this.aiInputText = ''
            })
        }
        .width('100%')
        .padding({ left: 8, right: 8, top: 4, bottom: 4 })
        .backgroundColor('#1A1B2E')
      }
      if (this.virtKeyEnabled) {
        if (this.showVirtKey) {
          this.buildVirtualKeys()
        } else {
          this.buildShowVirtualKeysButton()
        }
      }
    }
    .height('100%')

      if (this.showGitHubWebView) {
        Column() {
          Row() {
            Button('\u2190 \u8FD4\u56DE', { buttonStyle: ButtonStyleMode.TEXTUAL })
              .fontSize(16)
              .fontColor('#A78BFA')
              .onClick(() => { this.showGitHubWebView = false })
            Text('GitHub Actions').fontSize(16).fontColor('#E0E0E0').margin({ left: 12 })
          }
          .width('100%').height(48).backgroundColor('#0D0D12').padding({ left: 12, right: 12 })

          Web({ src: 'https://github.com/Fenzhuanvip/HiSH/actions', controller: this.githubWebController })
            .width('100%').height('100%')
            .javaScriptAccess(true).domStorageAccess(true)
            .imageAccess(true).onlineImageAccess(true)
        }
        .width('100%').height('100%')
      }
    }
    .height('100%')
  }

  @Builder
  buildShowVirtualKeysButton() {
    Column() {
      Button('▲', { buttonStyle: ButtonStyleMode.TEXTUAL })
        .width(120)
        .height(16)
        .fontSize(16)
        .borderRadius(VKeyRadius)
        .fontColor('#444')
        .padding({ left: VKeyPadding, right: VKeyPadding })
        .attributeModifier(this.immersiveButton)
        .onClick(() => {
          this.showVirtKey = true
        })
    }
    .width('100%')
  }

  @Builder
  buildVirtualKeys() {
    Column() {
      if (this.fnPressed) {
        Row() {
          this.toggleFnKey('FN', () => this.toggleFn());
          this.buildVKey('F1', FunctionKeySequences.F1);
          this.buildVKey('F2', FunctionKeySequences.F2);
          this.buildVKey('F3', FunctionKeySequences.F3);

          Row().layoutWeight(1);

          this.buildVKey('F4', FunctionKeySequences.F4);
          this.buildVKey('F5', FunctionKeySequences.F5);
          this.buildVKey('F6', FunctionKeySequences.F6);
          this.settingsButton();
        }
        .margin({ left: 5, right: 5 })

        Row() {
          this.buildVKey('F7', FunctionKeySequences.F7);
          this.buildVKey('F8', FunctionKeySequences.F8);
          this.buildVKey('F9', FunctionKeySequences.F9);

          Row().layoutWeight(1);

          this.buildVKey('F10', FunctionKeySequences.F10);
          this.buildVKey('F11', FunctionKeySequences.F11);
          this.buildVKey('F12', FunctionKeySequences.F12);
          this.hideVKeyButton();
        }
        .margin({ left: 5, right: 5 })
      } else {
        Row() {
          this.buildVKey('ESC', NormalKeySequences.ESC);
          this.toggleFnKey('FN', () => this.toggleFn());
          this.buildVKey('/', '/', '/');

          Row().layoutWeight(1);

          this.buildVKey('PGUP', NormalKeySequences.PGUP);
          this.buildVKey('HOME', NormalKeySequences.HOME);
          this.buildVKey('↑', NormalKeySequences.UP, NormalKeySequences.UP_APP);
          this.buildVKey('END', NormalKeySequences.END);

          this.buildAIButton();
          this.settingsButton();
        }
        .margin({ left: 5, right: 5 })

        Row() {
          this.buildVKey('TAB', NormalKeySequences.TAB);
          this.toggleCtrlKey('CTRL', () => this.toggleCtrl());
          this.buildVKey('-', '-', '-');

          Row().layoutWeight(1);

          this.buildVKey('PGDN', NormalKeySequences.PGDN);
          this.buildVKey('←', NormalKeySequences.LEFT, NormalKeySequences.LEFT_APP);
          this.buildVKey('↓', NormalKeySequences.DOWN, NormalKeySequences.DOWN_APP);
          this.buildVKey('→', NormalKeySequences.RIGHT, NormalKeySequences.RIGHT_APP);
          this.hideVKeyButton();
        }
        .margin({ left: 5, right: 5 })
      }
    }
  }

  async saveShowVirtKey() {
    await savePreference(appOption.showVirtKey, this.showVirtKey, this.getUIContext())
    if (!this.showVirtKey) {
      this.getUIContext().getPromptAction().showToast({
        message: $r('app.string.hide_virtual_key_toast'),
        duration: 5000
      })
    }
  }

  private toggleCtrl(): void {
    this.ctrlPressed = !this.ctrlPressed;
  }

  private toggleShift(): void {
    this.shiftPressed = !this.shiftPressed;
  }

  private toggleFn(): void {
    this.fnPressed = !this.fnPressed;
  }
  //  ============== for javascript in ArkWeb ================

  sendInput(data: string): void {
    hilog.info(DOMAIN, 'WebTerminal', 'sendInput: len=%{public}d', data.length);

    const modifierResult = applyVirtualKeyModifiers(data, this.ctrlPressed, this.shiftPressed)
    data = modifierResult.data

    if (modifierResult.ctrlConverted) {
      hilog.info(DOMAIN, 'WebTerminal', 'sendInput with Ctrl: control char sent');
    }
    if (modifierResult.shouldResetCtrl) {
      this.toggleCtrl()
    }
    if (modifierResult.shiftConverted) {
      hilog.info(DOMAIN, 'WebTerminal', 'sendInput with Shift: len=%{public}d', data.length);
    }

    let buffer = stringToArrayBuffer(data, 'utf-8');
    napi.sendInput(buffer)

    // Ctrl: 一次性模式，发送后自动重置 | Shift: 状态保持，需要用户手动点击取消
  }

  async load(): Promise<void> {
    this.webviewController.runJavaScript('exports.setFocused(true)')
    napi.onData((d: ArrayBuffer): void => this.onData(d))
    napi.onShutdown((): void => {
      void this.onShutdown()
    })
    const vmStatus = AppStorage.get(appOption.currentEmulatorStatus) as string | undefined
    if (vmStatus === 'ABNORMAL') {
      const message = this.getUIContext().getHostContext()?.resourceManager.getStringByNameSync('pm_status_qmp_connect_failed')
        ?? 'Failed to connect to QMP (please restart app)'
      const text = util.TextEncoder.create('utf-8').encodeInto('\r\n' + message + '\r\n')
      const base64 = new util.Base64Helper().encodeToStringSync(text)
      this.webviewController.runJavaScript(`exports.writeBase64("${base64}", ${this.applicationMode})`)
    }
  }

  async resize(width: number, height: number): Promise<void> {
    hilog.info(DOMAIN, "WebTerminal", 'on resize: %{public}d, %{public}d', width, height)

    if (this.resizeTimeout !== undefined) {
      clearTimeout(this.resizeTimeout!!)
    }
    this.resizeTimeout = setTimeout(() => this.sendInput('\x1b' + `[8;${height};${width}t`), 100)
  }

  // 性能优化：输出缓冲区
  private pendingChunks: Uint8Array[] = [];
  private flushTimeoutID: number | undefined = undefined;
  private readonly FLUSH_INTERVAL = 16; // 60FPS (16.6ms)

  private onData(ab: ArrayBuffer) {
    try {
      // 将收到的数据块加入队列
      this.pendingChunks.push(new Uint8Array(ab));

      // 如果没有正在等待的 Flush 任务，则调度一个
      if (this.flushTimeoutID === undefined) {
        this.flushTimeoutID = setTimeout(() => {
          this.flushData();
        }, this.FLUSH_INTERVAL);
      }
    } catch (e) {
      hilog.error(DOMAIN, 'WebTerminal', 'onData failed: %{public}s', JSON.stringify(e));
    }
  }

  private flushData() {
    this.flushTimeoutID = undefined;

    if (this.pendingChunks.length === 0) return;

    try {
      // 1. 计算总长度
      let totalLength = 0;
      for (const chunk of this.pendingChunks) {
        totalLength += chunk.length;
      }

      // 2. 合并所有 Chunk
      const merged = new Uint8Array(totalLength);
      let offset = 0;
      for (const chunk of this.pendingChunks) {
        merged.set(chunk, offset);
        offset += chunk.length;
      }

      // 清空缓冲区
      this.pendingChunks = [];

      // 3. 检测清屏信号
      // 检查合并后的数据是否包含 \x1b[H\x1b[J 的字面量转义序列
      if (merged.length >= 12 &&
        merged[0] === 0x5C && merged[1] === 0x78 && merged[2] === 0x31 && merged[3] === 0x62 && // \x1b
        merged[4] === 0x5B && merged[5] === 0x48 && // [H
        merged[6] === 0x5C && merged[7] === 0x78 && merged[8] === 0x31 && merged[9] === 0x62 && // \x1b
        merged[10] === 0x5B && merged[11] === 0x4A // [J
      ) {
        const clearCmd = '\\x1b[3J';
        const encoder = util.TextEncoder.create('utf-8');
        const clearBytes = encoder.encodeInto(clearCmd);
        const clearBase64 = new util.Base64Helper().encodeToStringSync(clearBytes);
        this.webviewController.runJavaScript(`exports.writeBase64("${clearBase64}", ${this.applicationMode})`);
      }

      // 4. 发送合并后的数据
      const base64Helper = new util.Base64Helper();
      const base64 = base64Helper.encodeToStringSync(merged);
      this.webviewController.runJavaScript(`exports.writeBase64("${base64}", ${this.applicationMode})`);

    } catch (e) {
      hilog.error(DOMAIN, 'WebTerminal', 'flushData failed: %{public}s', JSON.stringify(e));
      // 出错时也要清空缓冲区，避免积压
      this.pendingChunks = [];
    }
  }

  private async onShutdown() {
    hilog.info(DOMAIN, 'WebTerminal', 'qemu system exited');
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    await context?.terminateSelf()
  }

  getFontSize(): number | null {
    return this.fontSize
  }

  getFontFamily(): string {
    return this.fontFamily
  }

  getCursorShape(): string | null {
    return this.cursorShape
  }

  getCursorBlink(): boolean | null {
    return this.cursorBlink
  }

  getDeviceType(): string {
    return deviceInfo.deviceType;
  }

  onFontSizeChanged() {
    this.webviewController.runJavaScript(`exports.setFontSize(${this.fontSize})`)
  }

  onFontFamilyChanged() {
    // Read directly from AppStorage to ensure we get the updated value
    const family = AppStorage.get<string>(appOption.terminalFontFamily) ?? 'Default';
    hilog.info(DOMAIN, 'WebTerminal', 'onFontFamilyChanged: %{public}s', family);
    // Use JSON.stringify to safely escape any special characters in font name
    this.webviewController.runJavaScript(`exports.setFontFamily(${JSON.stringify(family)})`)
      .catch((err: Error) => {
        hilog.error(DOMAIN, 'WebTerminal', 'setFontFamily failed: %{public}s', JSON.stringify(err));
      })
  }

  onCursorShapeChanged() {
    this.webviewController.runJavaScript(`exports.setCursorShape('${this.cursorShape}')`)
  }

  onCursorBlinkChanged() {
    this.webviewController.runJavaScript(`exports.setCursorBlink(${this.cursorBlink})`)
  }

  getLigatures(): boolean {
    return this.termLigatures
  }

  getItalic(): boolean {
    return this.termItalic
  }

  getBackgroundColor(): string {
    return this.termBgColor
  }

  getBackgroundBlur(): number {
    return this.termBgBlur
  }

  getBackgroundImage(): string {
    return this.backgroundImageDataUrl()
  }

  getUserFonts(): string {
    const fonts = AppStorage.get<UserFont[]>(appOption.terminalUserFonts) ?? []
    const list: UserFontData[] = []
    for (const f of fonts) {
      const data: UserFontData = { name: f.name, dataUrl: fileToDataUrl(f.file) }
      if (data.dataUrl.length > 0) {
        list.push(data)
      }
    }
    return JSON.stringify(list)
  }

  private backgroundImageDataUrl(): string {
    const fileName = AppStorage.get<string>(appOption.terminalBackgroundImage) ?? ''
    if (fileName.length === 0) {
      return ''
    }
    const filesDir = AppStorage.get<string>(appOption.appFilesDir) ?? ''
    return fileToDataUrl(`${filesDir}/terminal_bg/${fileName}`)
  }

  private computeKeyFontColor(): string {
    return '#E0E0E0'
  }
    return '#ffffff'
  }

  onBgColorChanged() {
    this.webviewController.runJavaScript(`exports.setBackgroundColor(${JSON.stringify(this.termBgColor)})`)
    this.keyFontColor = this.computeKeyFontColor()
  }

  onBgImageChanged() {
    this.webviewController.runJavaScript(`exports.setBackgroundImage(${JSON.stringify(this.backgroundImageDataUrl())})`)
  }

  onBgBlurChanged() {
    this.webviewController.runJavaScript(`exports.setBackgroundBlur(${this.termBgBlur})`)
  }

  onUserFontsChanged() {
    const json = this.getUserFonts()
    this.webviewController.runJavaScript(`exports.registerUserFonts(${JSON.stringify(json)})`)
  }

  onLigaturesChanged() {
    this.webviewController.runJavaScript(`exports.setLigatures(${this.termLigatures})`)
  }

  onItalicChanged() {
    this.webviewController.runJavaScript(`exports.setItalic(${this.termItalic})`)
  }

  setApplicationMode(mode: boolean) {
    this.applicationMode = mode
    hilog.info(DOMAIN, 'WebTerminal', 'set applicationMode to %{public}s', this.applicationMode);
  }

  // Called from WebView when monospace font detection completes.
  // Receives a JSON array of available monospace font names.
  onAvailableFontsDetected(json: string): void {
    try {
      const fonts: string[] = JSON.parse(json);
      hilog.info(DOMAIN, 'WebTerminal', 'Available monospace fonts: %{public}s', fonts.join(', '));
      AppStorage.setOrCreate(appOption.availableFontFamilies, fonts);
    } catch (e) {
      hilog.error(DOMAIN, 'WebTerminal', 'Failed to parse available fonts: %{public}s', JSON.stringify(e));
    }
  }

  private matchAICommand(input: string): string {
    const lower = input.toLowerCase().trim()
    if (lower.length === 0) return ''
    const rules: Array<[string, string]> = [
      ['磁盘', 'df -h'], ['disk', 'df -h'], ['存储', 'df -h'],
      ['内存', 'free -h'], ['memory', 'free -h'], ['ram', 'free -h'],
      ['进程', 'ps aux'], ['process', 'ps aux'], ['任务', 'top -n 1'],
      ['网络', 'ip addr'], ['network', 'ip addr'],
      ['端口', 'ss -tlnp'], ['port', 'ss -tlnp'],
      ['系统信息', 'uname -a'], ['system', 'uname -a'], ['内核', 'uname -r'],
      ['用户', 'whoami'], ['user', 'whoami'], ['登录', 'who'],
      ['目录', 'pwd'], ['路径', 'pwd'], ['path', 'pwd'],
      ['日期', 'date'], ['时间', 'date'], ['date', 'date'], ['time', 'date'],
      ['日历', 'cal'], ['calendar', 'cal'],
      ['cpu', 'lscpu'], ['处理器', 'lscpu'],
      ['列出文件', 'ls -la'], ['文件列表', 'ls -la'], ['list', 'ls -la'],
      ['查看文件', 'ls -la'], ['ls', 'ls -la'],
      ['更新系统', 'apt update && apt upgrade -y'], ['update', 'apt update'],
      ['安装', 'apt install -y'], ['install', 'apt install -y'],
      ['搜索包', 'apt search'], ['search', 'apt search'],
      ['下载', 'wget'], ['download', 'wget'],
      ['ping', 'ping -c 4 google.com'], ['连通', 'ping -c 4 8.8.8.8'],
      ['公网ip', 'curl -s ifconfig.me'], ['公网', 'curl -s ifconfig.me'],
      ['清理屏幕', 'clear'], ['清屏', 'clear'], ['clear', 'clear'],
      ['帮助', 'help'], ['help', 'help'],
      ['git状态', 'git status'], ['git status', 'git status'],
      ['git日志', 'git log --oneline -10'], ['git log', 'git log --oneline -10'],
      ['git分支', 'git branch -a'], ['git branch', 'git branch -a'],
      ['重启', 'sudo reboot'], ['关机', 'sudo poweroff'],
      ['退出', 'exit'], ['exit', 'exit'],
      ['环境变量', 'env'], ['env', 'env'],
      ['磁盘占用', 'du -sh *'], ['空间', 'du -sh *'],
      ['查看历史', 'history'], ['history', 'history'],
      ['杀死', 'killall'], ['kill', 'killall'],
    ]
    for (let i = 0; i < rules.length; i++) {
      if (lower.includes(rules[i][0])) {
        return rules[i][1]
      }
    }
    return ''
  }

  private executeAICommand() {
    const cmd = this.matchAICommand(this.aiInputText)
    if (cmd.length > 0) {
      this.sendInput(cmd + '\n')
      this.showAIInput = false
      this.aiInputText = ''
      this.getUIContext().getPromptAction().showToast({
        message: 'AI: ' + cmd,
        duration: 2000
      })
    } else {
      this.getUIContext().getPromptAction().showToast({
        message: '无法识别，试试：查看磁盘、查看内存、列出文件、查看进程、查看网络、git状态...',
        duration: 5000
      })
    }
  }

  aboutToAppear() {
  } else {
          AppStorage.setOrCreate(appOption.terminalBackgroundColor, '#FDF7FA')
        }
        hilog.info(DOMAIN, 'WebTerminal', 'System color mode: %{public}s', listener.matches ? 'dark' : 'light')
      }
      listener.on('change', applySystemColor)
      applySystemColor()
    } catch (e) {
      hilog.error(DOMAIN, 'WebTerminal', 'mediaquery init failed: %{public}s', JSON.stringify(e))
    }
  }

  aboutToDisappear() {
    try {
      if (this.colorModeListener) {
        this.colorModeListener.off('change')
        this.colorModeListener = undefined
      }
    } catch (e) {
      hilog.error(DOMAIN, 'WebTerminal', 'mediaquery cleanup failed: %{public}s', JSON.stringify(e))
    }
  }
}
