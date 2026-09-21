import { hilog } from '@kit.PerformanceAnalysisKit';
import { webview } from '@kit.ArkWeb';
import napi from 'libhish_main.so';
import stringToArrayBuffer from '../lib/stringToArrayBuffer';

const TAG = '[AiWorkbenchPage]';
const DOMAIN = 0x0001;

const CODEARTS_AI_URL = 'https://developer.huaweicloud.com/codeartsco.html';

/**
 * 在 WebView 里提取 !hish:exec 命令块的 JS 脚本
 * 返回 JSON 数组字符串，如 '["ls -la","echo hello"]'
 */
const EXTRACT_SCRIPT = `(function() {
  try {
    var text = '';
    // 尝试多种方式获取页面文本
    if (document.body && document.body.innerText) {
      text = document.body.innerText;
    }
    // 也检查所有 iframe
    try {
      var frames = document.querySelectorAll('iframe');
      for (var i = 0; i < frames.length; i++) {
        try { text += '\\n' + (frames[i].contentDocument?.body?.innerText || ''); } catch(e) {}
      }
    } catch(e) {}
    var regex = /!hish:\\s*exec\\s*([\\s\\S]*?)!hish:\\s*end/g;
    var cmds = [];
    var match;
    while ((match = regex.exec(text)) !== null) {
      cmds.push(match[1].trim());
    }
    return JSON.stringify(cmds);
  } catch(e) {
    return '[]';
  }
})()`;

/**
 * 码道 CodeArts —— 全屏 WebView + ArkTS 侧轮询桥接
 * 每 2 秒用 runJavaScript 扫描页面文本，发现 !hish:exec 命令块就执行
 */
@Entry
@Component
export struct AiWorkbenchPage {
  webController: webview.WebviewController = new webview.WebviewController()
  @State pollTimer: number = -1
  executedCmds: Set<string> = new Set()

  build() {
    Column() {
      Web({ src: CODEARTS_AI_URL, controller: this.webController })
        .width('100%')
        .height('100%')
        .javaScriptAccess(true)
        .domStorageAccess(true)
        .imageAccess(true)
        .onlineImageAccess(true)
        .fileAccess(true)
        .mixedMode(MixedMode.All)
        .javaScriptProxy({
          object: this,
          name: 'hishTerminal',
          methodList: ['sendCommand', 'sendInput'],
          controller: this.webController,
          asyncMethodList: [],
          permission: `{
            "javascriptProxyPermission": {
              "urlPermissionList": [
                { "scheme": "https", "host": "developer.huaweicloud.com", "port": "", "path": "" },
                { "scheme": "https", "host": "devcloud.cn-north-4.huaweicloud.com", "port": "", "path": "" }
              ]
            }
          }`
        })
        .onPageEnd(() => {
          hilog.info(DOMAIN, TAG, 'Web loaded, starting poll bridge')
          this.startPollBridge()
        })
        .onErrorReceive((e) => {
          hilog.error(DOMAIN, TAG, 'Web error: %{public}s', JSON.stringify(e?.error))
        })
    }
    .width('100%').height('100%')
  }

  aboutToDisappear(): void {
    if (this.pollTimer >= 0) {
      clearInterval(this.pollTimer)
      this.pollTimer = -1
    }
  }

  /**
   * 启动轮询桥接：每 2 秒扫描 WebView 页面文本，提取并执行命令块
   */
  private startPollBridge(): void {
    this.pollTimer = setInterval(() => {
      try {
        this.webController.runJavaScript(EXTRACT_SCRIPT).then((result: string) => {
          this.processExtractedCmds(result)
        }).catch(() => {})
      } catch (e) {
        // 忽略
      }
    }, 2000)
  }

  /**
   * 处理从 WebView 提取的命令数组
   */
  private processExtractedCmds(result: string): void {
    try {
      // runJavaScript 返回 JSON.stringify 的结果，需要解析
      let cmds: string[] = []
      if (result && result !== '""' && result !== '[]') {
        const parsed = JSON.parse(result)
        if (Array.isArray(parsed)) {
          cmds = parsed as string[]
        }
      }
      for (const cmd of cmds) {
        if (cmd.length === 0) continue
        const hash = cmd.substring(0, 200)
        if (this.executedCmds.has(hash)) continue
        this.executedCmds.add(hash)
        hilog.info(DOMAIN, TAG, 'Executing bridge cmd: %{public}s', cmd)
        const buffer = stringToArrayBuffer(cmd + '\\n', 'utf-8')
        napi.sendInput(buffer)
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'processCmds failed: %{public}s', JSON.stringify(e))
    }
  }

  sendCommand(cmd: string): void {
    hilog.info(DOMAIN, TAG, 'sendCommand: %{public}s', cmd)
    try {
      const buffer = stringToArrayBuffer(cmd + '\\n', 'utf-8')
      napi.sendInput(buffer)
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'sendCommand failed: %{public}s', JSON.stringify(e))
    }
  }

  sendInput(data: string): void {
    hilog.info(DOMAIN, TAG, 'sendInput: %{public}s', data)
    try {
      const buffer = stringToArrayBuffer(data, 'utf-8')
      napi.sendInput(buffer)
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'sendInput failed: %{public}s', JSON.stringify(e))
    }
  }
}
