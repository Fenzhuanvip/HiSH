import { hilog } from '@kit.PerformanceAnalysisKit';
import { webview } from '@kit.ArkWeb';
import napi from 'libhish_main.so';
import stringToArrayBuffer from '../lib/stringToArrayBuffer';

const TAG = '[AiWorkbenchPage]';
const DOMAIN = 0x0001;

/** CodeArts 代码智能体入口 */
const CODEARTS_AI_URL = 'https://developer.huaweicloud.com/codeartsco.html';

/**
 * 码道 CodeArts —— 全屏 WebView 嵌入华为云 CodeArts 代码智能体
 * 通过 JavaScript Bridge 让 CodeArts AI 直接控制 HiSH 终端
 * WebView 内调用 hishTerminal.sendCommand('ls -la') 即可向终端发命令
 */
@Entry
@Component
export struct AiWorkbenchPage {
  webController: webview.WebviewController = new webview.WebviewController()

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
                {
                  "scheme": "https",
                  "host": "developer.huaweicloud.com",
                  "port": "",
                  "path": ""
                },
                {
                  "scheme": "https",
                  "host": "devcloud.cn-north-4.huaweicloud.com",
                  "port": "",
                  "path": ""
                }
              ]
            }
          }`
        })
        .onPageBegin((e) => {
          hilog.info(DOMAIN, TAG, 'Web loading: %{public}s', e.url)
        })
        .onPageEnd((e) => {
          hilog.info(DOMAIN, TAG, 'Web loaded: %{public}s', e.url)
        })
        .onErrorReceive((e) => {
          hilog.error(DOMAIN, TAG, 'Web error: %{public}s', JSON.stringify(e?.error))
        })
    }
    .width('100%')
    .height('100%')
  }

  /**
   * JavaScript Bridge: 发送命令到终端（自动加换行）
   * WebView 内调用: hishTerminal.sendCommand('ls -la')
   */
  sendCommand(cmd: string): void {
    hilog.info(DOMAIN, TAG, 'sendCommand: %{public}s', cmd)
    try {
      const buffer = stringToArrayBuffer(cmd + '\n', 'utf-8')
      napi.sendInput(buffer)
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'sendCommand failed: %{public}s', JSON.stringify(e))
    }
  }

  /**
   * JavaScript Bridge: 发送原始输入到终端（不加换行）
   * WebView 内调用: hishTerminal.sendInput('ls')
   */
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
