import { webview } from '@kit.ArkWeb';
import fs from '@ohos.file.fs';
import util from '@ohos.util';
import appOption from '../model/appOption';

/**
 * 小说写作组件 —— 世界书 + 角色卡 + AI 对话
 * WebView 加载 rawfile/novel/index.html，内置 localStorage 持久化
 * 支持同步到共享文件夹，终端智能体可读写 JSON 数据
 */
@Component
export struct NovelWriter {
  webController: webview.WebviewController = new webview.WebviewController()

  /**
   * 保存数据到共享文件夹 novel/data.json
   * 终端可通过 /mnt/share/novel/data.json 读写
   */
  saveToSharedFolder(jsonStr: string): string {
    try {
      const sharedHost = AppStorage.get(appOption.sharedHost) as string
      if (!sharedHost || sharedHost.length === 0) {
        return JSON.stringify({ ok: false, error: '共享文件夹未配置' })
      }
      const dir = sharedHost + 'novel'
      if (!fs.accessSync(dir)) {
        fs.mkdirSync(dir, true)
      }
      const filePath = dir + '/data.json'
      const file = fs.openSync(filePath, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC)
      fs.writeSync(file.fd, jsonStr)
      fs.closeSync(file)
      return JSON.stringify({ ok: true, path: '/mnt/share/novel/data.json' })
    } catch (e) {
      return JSON.stringify({ ok: false, error: String(e) })
    }
  }

  /**
   * 从共享文件夹加载 novel/data.json
   */
  loadFromSharedFolder(): string {
    try {
      const sharedHost = AppStorage.get(appOption.sharedHost) as string
      if (!sharedHost || sharedHost.length === 0) {
        return JSON.stringify({ ok: false, error: '共享文件夹未配置' })
      }
      const filePath = sharedHost + 'novel/data.json'
      if (!fs.accessSync(filePath)) {
        return JSON.stringify({ ok: false, error: '文件不存在' })
      }
      const file = fs.openSync(filePath, fs.OpenMode.READ_ONLY)
      const stat = fs.statSync(filePath)
      const buf = new ArrayBuffer(stat.size)
      fs.readSync(file.fd, buf)
      fs.closeSync(file)
      const decoder = util.TextDecoder.create('utf-8')
      const jsonStr = decoder.decodeWithStream(new Uint8Array(buf))
      return JSON.stringify({ ok: true, data: jsonStr })
    } catch (e) {
      return JSON.stringify({ ok: false, error: String(e) })
    }
  }

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
        methodList: ['saveToSharedFolder', 'loadFromSharedFolder'],
        controller: this.webController
      })
      .width('100%')
      .height('100%')
      .backgroundColor('#1a1b26')
  }
}
