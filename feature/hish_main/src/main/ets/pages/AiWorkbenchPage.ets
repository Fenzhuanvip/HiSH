import { hilog } from '@kit.PerformanceAnalysisKit';
import { webview } from '@kit.ArkWeb';
import napi from 'libhish_main.so';
import stringToArrayBuffer from '../lib/stringToArrayBuffer';

const TAG = '[AiWorkbenchPage]';
const DOMAIN = 0x0001;

const CODEARTS_AI_URL = 'https://developer.huaweicloud.com/codeartsco.html';

/**
 * 自动点击"在线体验"按钮，跳过产品落地页
 */
const AUTO_ENTER_SCRIPT = `(function() {
  try {
    var btns = document.querySelectorAll('a, button, span, div');
    for (var i = 0; i < btns.length; i++) {
      var el = btns[i];
      var text = (el.innerText || el.textContent || '').trim();
      if (text === '在线体验' || text === '立即体验' || text === '开始使用' || text === '进入控制台') {
        console.log('[HiSH] auto-clicking:', text);
        el.click();
        return true;
      }
    }
  } catch(e) { console.error('[HiSH] auto-enter failed:', e); }
  return false;
})()`;

/**
 * 提取并执行 !hish:exec 命令块
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
      } catch(e) {}
    }
  } catch(e) {}
})()`;

/**
 * 码道 CodeArts —— 全屏 WebView
 * 自动跳过落地页 + 轮询桥接终端控制
 */
@Entry
@Component
export struct AiWorkbenchPage {
  webController: webview.WebviewController = new webview.WebviewController()
  pollTimer: number = -1
  @State hasEnteredAI: boolean = false

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
        .onPageEnd((e) => {
          hilog.info(DOMAIN, TAG, 'Web loaded: %{public}s', e.url)
          // 尝试自动点击"在线体验"跳过落地页
          if (!this.hasEnteredAI) {
            try {
              this.webController.runJavaScript(AUTO_ENTER_SCRIPT).then((result: string) => {
                if (result === 'true') {
                  this.hasEnteredAI = true
                  hilog.info(DOMAIN, TAG, 'Auto-entered AI experience')
                }
              }).catch(() => {})
            } catch (e) {}
          }
          // 启动轮询桥接
          if (this.pollTimer < 0) {
            this.startPollBridge()
          }
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
      } catch (e) {}
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
