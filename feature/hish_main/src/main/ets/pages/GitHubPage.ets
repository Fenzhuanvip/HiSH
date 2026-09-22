import { hilog } from '@kit.PerformanceAnalysisKit';
import { webview } from '@kit.ArkWeb';

const TAG = '[GitHubPage]';
const DOMAIN = 0x0001;

/** GitHub Actions 构建页面 */
const GITHUB_ACTIONS_URL = 'https://github.com/Fenzhuanvip/HiSH/actions';

/**
 * GitHub —— 全屏 WebView 打开 GitHub Actions
 * 登录后可直接查看构建状态、下载 HAP artifact
 */
@Entry
@Component
export struct GitHubPage {
  webController: webview.WebviewController = new webview.WebviewController()

  build() {
    Column() {
      Web({ src: GITHUB_ACTIONS_URL, controller: this.webController })
        .width('100%')
        .height('100%')
        .javaScriptAccess(true)
        .domStorageAccess(true)
        .imageAccess(true)
        .onlineImageAccess(true)
        .fileAccess(true)
        .mixedMode(MixedMode.All)
        .onPageEnd((e) => {
          hilog.info(DOMAIN, TAG, 'GitHub loaded: %{public}s', e.url)
        })
        .onErrorReceive((e) => {
          hilog.error(DOMAIN, TAG, 'Web error: %{public}s', JSON.stringify(e?.error))
        })
    }
    .width('100%').height('100%')
  }
}
