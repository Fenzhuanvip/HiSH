import { hilog } from '@kit.PerformanceAnalysisKit';
import { webview } from '@kit.ArkWeb';
import napi from 'libhish_main.so';
import stringToArrayBuffer from '../lib/stringToArrayBuffer';

const TAG = '[AiWorkbenchPage]';
const DOMAIN = 0x0001;

/** CodeArts 代码智能体入口 */
const CODEARTS_AI_URL = 'https://developer.huaweicloud.com/codeartsco.html';

/**
 * 注入到 WebView 的自动执行桥接脚本
 * 监听 DOM 变化，当检测到 AI 回复中的 !hish:exec ... !hish:end 命令块时
 * 自动提取并调用 hishTerminal.sendCommand() 执行
 */
const BRIDGE_INJECT_SCRIPT = `
(function() {
  if (window.__hishBridgeInjected) return;
  window.__hishBridgeInjected = true;

  // 命令块格式: !hish:exec  ...  !hish:end
  var CMD_START = '!hish:exec';
  var CMD_END = '!hish:end';
  var executedHashes = {};

  function extractAndExec(text) {
    if (!text || text.indexOf(CMD_START) < 0) return;
    var regex = new RegExp(CMD_START + '\\s*([\\s\\S]*?)' + CMD_END, 'g');
    var match;
    while ((match = regex.exec(text)) !== null) {
      var cmd = match[1].trim();
      var hash = cmd.substring(0, 50);
      if (executedHashes[hash]) continue;
      executedHashes[hash] = true;
      console.log('[HiSH Bridge] executing:', cmd);
      try {
        hishTerminal.sendCommand(cmd);
      } catch(e) {
        console.error('[HiSH Bridge] exec failed:', e);
      }
    }
  }

  // 监听整个文档的文本变化
  var observer = new MutationObserver(function(mutations) {
    for (var i = 0; i < mutations.length; i++) {
      var m = mutations[i];
      if (m.addedNodes.length > 0) {
        for (var j = 0; j < m.addedNodes.length; j++) {
          var node = m.addedNodes[j];
          if (node.nodeType === 3) {
            extractAndExec(node.textContent);
          } else if (node.innerText) {
            extractAndExec(node.innerText);
          }
        }
      }
      if (m.type === 'characterData' && m.target.textContent) {
        extractAndExec(m.target.textContent);
      }
    }
  });

  function startObserver() {
    observer.observe(document.body, {
      childList: true,
      subtree: true,
      characterData: true
    });
    console.log('[HiSH Bridge] DOM observer started');
  }

  if (document.body) {
    startObserver();
  } else {
    document.addEventListener('DOMContentLoaded', startObserver);
  }

  // 也监听 console 消息（备用通道）
  var origLog = console.log;
  console.log = function() {
    var args = Array.prototype.slice.call(arguments);
    var msg = args.join(' ');
    if (msg.indexOf(CMD_START) >= 0) {
      extractAndExec(msg);
    }
    origLog.apply(console, args);
  };

  console.log('[HiSH Bridge] Auto-exec bridge injected');
})();
`;

/**
 * 码道 CodeArts —— 全屏 WebView 嵌入华为云 CodeArts 代码智能体
 * 通过 JavaScript Bridge 让 CodeArts AI 直接控制 HiSH 终端
 *
 * 用法：AI 在回复中写：
 *   !hish:exec
 *   ls -la /tmp
 *   !hish:end
 * 桥接脚本会自动提取并执行命令
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
          // 注入自动执行桥接脚本
          this.injectBridge()
        })
        .onErrorReceive((e) => {
          hilog.error(DOMAIN, TAG, 'Web error: %{public}s', JSON.stringify(e?.error))
        })
    }
    .width('100%')
    .height('100%')
  }

  private injectBridge(): void {
    try {
      this.webController.runJavaScript(BRIDGE_INJECT_SCRIPT)
      hilog.info(DOMAIN, TAG, 'Bridge script injected')
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'injectBridge failed: %{public}s', JSON.stringify(e))
    }
  }

  /**
   * JavaScript Bridge: 发送命令到终端（自动加换行）
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
