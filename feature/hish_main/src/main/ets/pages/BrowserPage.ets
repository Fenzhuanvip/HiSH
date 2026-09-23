import { webview } from '@kit.ArkWeb'

@Entry
@Component
export struct BrowserPage {
  @State url: string = ''
  @State inputUrl: string = ''
  @State canGoBack: boolean = false
  @State canGoForward: boolean = false
  @State loading: boolean = false
  controller: WebviewController = new webview.WebviewController()

  aboutToAppear() {
    const params = this.getUIContext().getRouter().getParams() as Record<string, string>
    if (params && params['url']) {
      this.url = this.normalizeUrl(params['url'])
      this.inputUrl = this.url
    }
  }

  normalizeUrl(u: string): string {
    if (!u.startsWith('http://') && !u.startsWith('https://')) {
      return 'https://' + u
    }
    return u
  }

  build() {
    Column() {
      // 地址栏
      Row() {
        Button('←')
          .enabled(this.canGoBack)
          .onClick(() => {
            this.controller.backward()
          })
        Button('→')
          .enabled(this.canGoForward)
          .onClick(() => {
            this.controller.forward()
          })
        Button('⟳')
          .onClick(() => {
            this.controller.refresh()
          })
        TextInput({ text: this.inputUrl, placeholder: '输入网址' })
          .layoutWeight(1)
          .onChange((v: string) => { this.inputUrl = v })
          .onSubmit(() => {
            this.url = this.normalizeUrl(this.inputUrl)
            this.inputUrl = this.url
            this.controller.loadUrl(this.url)
          })
        if (this.loading) {
          LoadingProgress().width(20).height(20)
        }
      }
      .width('100%')
      .height(48)
      .padding({ left: 8, right: 8 })

      // WebView
      Web({ src: this.url, controller: this.controller })
        .layoutWeight(1)
        .width('100%')
        .onPageBegin((e) => {
          this.loading = true
          this.inputUrl = e.url
        })
        .onPageEnd((e) => {
          this.loading = false
          this.inputUrl = e.url
          this.canGoBack = this.controller.accessBackward()
          this.canGoForward = this.controller.accessForward()
        })
        .onErrorReceive((e) => {
          this.loading = false
        })
    }
    .height('100%')
  }
}
