import { webview } from '@kit.ArkWeb';

/**
 * 小说写作组件 —— 世界书 + 角色卡 + AI 对话
 * WebView 加载 rawfile/novel/index.html，内置 localStorage 持久化
 */
@Component
export struct NovelWriter {
  webController: webview.WebviewController = new webview.WebviewController()

  build() {
    Web({
      src: $rawfile('novel/index.html'),
      controller: this.webController
    })
      .javaScriptProxy({
        permission: `{
          "javascriptProxyPermission": {
            "urlPermissionList": [
              {
                "scheme": "resource",
                "host": "rawfile",
                "port": "",
                "path": ""
              }
            ]
          }
        }`,
        object: this,
        name: 'native',
        methodList: [],
        controller: this.webController
      })
      .width('100%')
      .height('100%')
      .backgroundColor('#1a1b26')
  }
}
