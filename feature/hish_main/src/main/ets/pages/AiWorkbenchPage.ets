import { hilog } from '@kit.PerformanceAnalysisKit';
import { webview } from '@kit.ArkWeb';
import napi from 'libhish_main.so';
import stringToArrayBuffer from '../lib/stringToArrayBuffer';

const TAG = '[AiWorkbenchPage]';
const DOMAIN = 0x0001;

const CODEARTS_AI_URL = 'https://developer.huaweicloud.com/codeartsco.html';

/**
 * 在 WebView 里直接提取并执行 !hish:exec 命令块
 * 通过 hishTerminal.sendCommand() 调用 ArkTS 侧的终端控制
 * 用 window.__hishExecuted 去重，避免重复执行
 */
const EXEC_SCRIPT = `(function() {
  try {
    var text = '';
    if (document.body && document.body.innerText) {
      text = document.body.innerText;
    }
    var regex = /!hish:\\s*exec\\s*([\\s\\S]*?)!hish:\\s*end/g;
    var match;
    while ((match = regex.exec(text)) !== null) {
      var cmd = match[1].trim();
      if (cmd.length === 0) continue;
      var hash = cmd.substring(0, 200);
      if (!window.__hishExecuted) window.__hishExecuted = {};
      if (window.__hishExecuted[hash]) continue;
      window.__hishExecuted[hash] = true;
      try {
        hishTerminal.sendCommand(cmd);
      } catch(e) {
        console.error('[HiSH Bridge] sendCommand failed:', e);
      }
    }
  } catch(e) {}
})()`;

/**
 * 码道 CodeArts —— 全屏 WebView + ArkTS 侧轮询
 * 每 2 秒用 runJavaScript 在 WebView 里执行提取脚本
 * 脚本直接调用 hishTerminal.sendCommand() 控制终端
 */
@Entry
@Component
export struct AiWorkbenchPage {
  webController: webview.WebviewController = new webview.WebviewController()
  pollTimer: number = -1

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

  private startPollBridge(): void {
    this.pollTimer = setInterval(() => {
      try {
        this.webController.runJavaScript(EXEC_SCRIPT)
      } catch (e) {
        // 页面可能还在加载，忽略
      }
    }, 2000)
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
