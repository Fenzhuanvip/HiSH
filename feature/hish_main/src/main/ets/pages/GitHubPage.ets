import { hilog } from '@kit.PerformanceAnalysisKit';
import { webview } from '@kit.ArkWeb';

const TAG = '[GitHubPage]';
const DOMAIN = 0x0001;
const GITHUB_ACTIONS_URL = 'https://github.com/Fenzhuanvip/HiSH/actions';

@Entry
@Component
export struct GitHubPage {
  webController: webview.WebviewController = new webview.WebviewController()
  @State loading: boolean = true
  @State errorMsg: string = ''

  build() {
    Stack() {
      Web({ src: GITHUB_ACTIONS_URL, controller: this.webController })
        .width('100%')
        .height('100%')
        .javaScriptAccess(true)
        .domStorageAccess(true)
        .imageAccess(true)
        .onlineImageAccess(true)
        .fileAccess(true)
        .mixedMode(MixedMode.All)
        .onPageBegin(() => {
          this.loading = true
        })
        .onPageEnd((e) => {
          this.loading = false
          hilog.info(DOMAIN, TAG, 'GitHub loaded: %{public}s', e.url)
        })
        .onErrorReceive((e) => {
          this.loading = false
          this.errorMsg = '加载失败，请检查网络'
          hilog.error(DOMAIN, TAG, 'Web error: %{public}s', JSON.stringify(e?.error))
        })

      if (this.loading) {
        Column() {
          LoadingProgress().width(60).height(60)
          Text('正在加载 GitHub...').fontSize(16).fontColor('#666666').margin({ top: 10 })
        }
        .width('100%').height('100%')
        .backgroundColor('#ffffff')
        .justifyContent(FlexAlign.Center)
      }

      if (this.errorMsg.length > 0) {
        Column() {
          Text(this.errorMsg).fontSize(16).fontColor('#ff0000')
          Button('重试').margin({ top: 15 }).onClick(() => {
            this.errorMsg = ''
            this.loading = true
            this.webController.refresh()
          })
        }
        .width('100%').height('100%')
        .backgroundColor('#ffffff')
        .justifyContent(FlexAlign.Center)
      }
    }
    .width('100%').height('100%')
  }
}
