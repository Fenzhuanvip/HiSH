import { hilog } from '@kit.PerformanceAnalysisKit';
import { webview } from '@kit.ArkWeb';

const TAG = '[AiChat]';
const DOMAIN = 0x0001;

/** CodeArts Web 控制台地址 */
const CODEARTS_WEB_URL = 'https://devcloud.cn-north-4.huaweicloud.com/home';
/** CodeArts 代码智能体入口 */
const CODEARTS_AI_URL = 'https://developer.huaweicloud.com/codeartsco.html';

/**
 * AI 对话 Tab —— CodeArts Web（WebView 嵌入）
 * 用华为云账号登录后可用 CodeArts 代码智能体全部 AI 能力
 * 包括：AI 代码生成 / 代码解释 / 缺陷修复 / 单测生成 等
 */
@Component
export struct AiChat {
  @State webUrl: string = CODEARTS_AI_URL
  webController: webview.WebviewController = new webview.WebviewController()

  build() {
    Column() {
      // 顶部地址栏：切换代码智能体 / DevOps 控制台
      Row() {
        Button('代码智能体')
          .fontSize(10)
          .margin({ right: 6 })
          .type(this.webUrl === CODEARTS_AI_URL ? ButtonType.Capsule : ButtonType.Normal)
          .onClick(() => { this.webUrl = CODEARTS_AI_URL; this.reloadWeb() })
        Button('DevOps 控制台')
          .fontSize(10)
          .type(this.webUrl === CODEARTS_WEB_URL ? ButtonType.Capsule : ButtonType.Normal)
          .onClick(() => { this.webUrl = CODEARTS_WEB_URL; this.reloadWeb() })
        Blank()
        Button({ type: ButtonType.Normal }) {
          SymbolGlyph($r('sys.symbol.arrow_clockwise')).fontSize(14)
        }
        .width(28).height(28)
        .onClick(() => { this.reloadWeb() })
      }
      .width('100%')
      .height(36)
      .padding({ left: 8, right: 8 })
      .backgroundColor($r('sys.color.comp_background_primary'))

      // WebView
      Web({ src: this.webUrl, controller: this.webController })
        .layoutWeight(1)
        .width('100%')
        .javaScriptAccess(true)
        .domStorageAccess(true)
        .imageAccess(true)
        .onlineImageAccess(true)
        .fileAccess(true)
        .mixedMode(MixedMode.All)
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

  private reloadWeb(): void {
    try {
      this.webController.loadUrl(this.webUrl)
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'reloadWeb: %{public}s', JSON.stringify(e))
    }
  }
}
