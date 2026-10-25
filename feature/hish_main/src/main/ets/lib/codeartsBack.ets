import { webview } from '@kit.ArkWeb';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0001;
const TAG = '[codeartsBack]';

// CodeArtsWeb 启动时把它的 WebviewController 注册到这里，
// 供 @Entry 页的 onBackPress 调用，实现"返回手势在网页内后退"。
let controller: webview.WebviewController | null = null;

export function setCodeArtsController(c: webview.WebviewController): void {
  controller = c;
}

// 返回 true = 已在网页历史中后退（消费返回键）；false = 无可后退历史。
export function codeArtsGoBack(): boolean {
  try {
    if (controller && controller.accessBackward()) {
      controller.backward();
      return true;
    }
  } catch (e) {
    hilog.error(DOMAIN, TAG, 'backward failed: %{public}s', JSON.stringify(e));
  }
  return false;
}
