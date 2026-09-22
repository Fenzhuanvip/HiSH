import { hilog } from '@kit.Per$kit.PerformanceAnalysisKit';
import { webview } from '@kit.ArkWeb';
import napi from 'libhish_main.so';
import stringToArrayBuffer from '../lib/stringToArrayBuffer';

const TAG = '[AiWorkbenchPage]';
const DOMAIN = 0x0001;
const CODEARTS_AI_URL = 'https://developer.huaweicloud.com/codeartsco.html';

const EXEC_SCRIPT = `(function() {
  try {
    var text = '';
    if (document.body && document.body.innerText) text = document.body.innerText;
    var lines = text.split('\\n');
    var inCmd = false;
    var cmds = [];
    var currentCmd = [];
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i].trim();
      if (line === '!hish:exec') { inCmd = true; currentCmd = []; }
      else if (line === '!hish:end') {
        if (inCmd && currentCmd.length > 0) cmds.push(currentCmd.join('\\n'));
        inCmd = false; currentCmd = [];
      } else if (inCmd) currentCmd.push(lines[i]);
    }
    for (var j = 0; j < cmds.length; j++) {
      var cmd = cmds[j].trim();
      if (cmd.length === 0) continue;
      var hash = cmd.substring(0, 200);
      if (!window.__hishExecuted) window.__hishExecuted = {};
      if (window.__hishExecuted[hash]) continue;
      window.__hishExecuted[hash] = true;
      try { hishTerminal.sendCommand(cmd); } catch(e) {}
    }
  } catch(e) {}
})()`;

@Entry
@Component
export struct AiWorkbenchPage {
  webController: webview.WebviewController = new webview.WebviewController()
  pollTimer: number = -1

  build() {
    Column() {
      Web({ src: CODEARTS_AI_URL, controller: this.webController })
        .width('100%').height('100%')
        .javaScriptAccess(true).domStorageAccess(true).imageAccess(true)
        .onlineImageAccess(true).fileAccess(true).mixedMode(MixedMode.All)
        .javaScriptProxy({
          object: this, name: 'hishTerminal',
          methodList: ['sendCommand', 'sendInput'],
          controller: this.webController, asyncMethodList: [],
          permission: `{"javascriptProxyPermission":{"urlPermissionList":[{"scheme":"https","host":"developer.huaweicloud.com","port":"","path":""},{"scheme":"https","host":"devcloud.cn-north-4.huaweicloud.com","port":"","path":""}]}}`
        })
        .onPageEnd(() => { this.startPollBridge() })
        .onErrorReceive((e) => { hilog.error(DOMAIN, TAG, 'Web error: %{public}s', JSON.stringify(e?.error)) })
    }.width('100%').height('100%')
  }

  aboutToDisappear(): void {
    if (this.pollTimer >= 0) { clearInterval(this.pollTimer); this.pollTimer = -1; }
  }

  private startPollBridge(): void {
    this.pollTimer = setInterval(() => {
      try { this.webController.runJavaScript(EXEC_SCRIPT) } catch (e) {}
    }, 2000)
  }

  sendCommand(cmd: string): void {
    hilog.info(DOMAIN, TAG, 'sendCommand: %{public}s', cmd)
    try {
      const lines = cmd.split('\n')
      for (let i = 0; i < lines.length; i++) {
        const line = lines[i].trim()
        if (line.length > 0) {
          const buffer = stringToArrayBuffer(line + '\n', 'utf-8')
          napi.sendInput(buffer)
        }
      }
    } catch (e) { hilog.error(DOMAIN, TAG, 'sendCommand failed: %{public}s', JSON.stringify(e)) }
  }

  sendInput(data: string): void {
    hilog.info(DOMAIN, TAG, 'sendInput: %{public}s', data)
    try { napi.sendInput(stringToArrayBuffer(data, 'utf-8')) } catch (e) {}
  }
}
