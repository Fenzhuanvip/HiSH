import { hilog } from '@kit.PerformanceAnalysisKit';
import { webview } from '@kit.ArkWeb';
import appOption from '../../model/appOption';
import { saveCodeBlock } from '../../lib/codeartsBridge';
import { setCodeArtsController } from '../../lib/codeartsBack';

const DOMAIN = 0x0001;
const TAG = '[CodeArtsWeb]';

/** 给每段代码块挂"存到共享目录"按钮，入队到 window.__hishQueue */
const INJECT_SCRIPT = `(function(){
  try {
    window.__hishQueue = window.__hishQueue || [];
    var pres = document.querySelectorAll('pre');
    for (var i = 0; i < pres.length; i++) {
      var pre = pres[i];
      if (pre.__hishTagged) continue;
      pre.__hishTagged = true;
      var codeEl = pre.querySelector('code');
      var lang = '';
      var cls = (codeEl && codeEl.className) || '';
      var m = cls.match(/language-([\\w-]+)/);
      if (m) lang = m[1];
      pre.style.position = 'relative';
      var btn = document.createElement('button');
      btn.textContent = '存到共享目录';
      btn.style.cssText = 'position:absolute;top:6px;right:6px;font-size:12px;padding:2px 8px;border-radius:6px;border:1px solid #A78BFA;background:#1A1B2E;color:#A78BFA;z-index:9999;cursor:pointer';
      (function(p, language){
        btn.onclick = function(){
          var t = p.innerText || '';
          window.__hishQueue.push({content:t, lang:language});
          btn.textContent = '已入队';
          setTimeout(function(){ btn.textContent = '存到共享目录'; }, 1500);
        };
      })(codeEl || pre, lang);
      pre.appendChild(btn);
    }
  } catch(e) {}
})()`;

/** 取出并清空队列 */
const DRAIN_SCRIPT = `(function(){ var q = window.__hishQueue || []; window.__hishQueue = []; return JSON.stringify(q); })()`;

interface CodeBlockItem {
  content: string
  lang: string
}

@Component
export struct CodeArtsWeb {
  @StorageProp(appOption.codeartsUrl) url: string = 'https://www.huaweicloud.com'
  @StorageProp(appOption.codeartsDarkInject) darkInject: boolean = true
  @StorageProp(appOption.sharedHost) sharedHost: string = ''
  @StorageProp(appOption.codeartsDrawerOpen) @Watch('onOpenChanged') drawerOpen: boolean = false
  controller: webview.WebviewController = new webview.WebviewController()
  @State loading: boolean = true
  @State errorMsg: string = ''
  timer: number = -1

  build() {
    // WebView 始终挂载（实例保留，重开不重载）；抽屉收起由 CodeArtsDrawer 的 Visibility.None 控制显隐。
    Stack() {
        Web({ src: this.url, controller: this.controller })
          .width('100%').height('100%')
          .javaScriptAccess(true)
          .domStorageAccess(true)
          .imageAccess(true)
          .onlineImageAccess(true)
          .fileAccess(false)
          .mixedMode(MixedMode.All)
          .onPageBegin(() => { this.loading = true })
          .onPageEnd(() => { this.loading = false; this.onLoaded() })
          .onErrorReceive((e) => {
            // 仅主文档加载失败才显示错误遮罩；子资源（图片/统计脚本等）失败不影响页面使用
            let isMain = true;
            try {
              if (e && e.request) {
                isMain = e.request.isMainFrame();
              }
            } catch (err) {
            }
            if (!isMain) {
              hilog.info(DOMAIN, TAG, 'subresource error ignored');
              return;
            }
            this.loading = false;
            this.errorMsg = '加载失败，请检查网络';
            hilog.error(DOMAIN, TAG, 'web main-frame error: %{public}s', JSON.stringify(e?.error));
          })

        if (this.loading) {
          Column() {
            LoadingProgress().width(60).height(60)
            Text('正在加载云码道...').fontSize(14).fontColor('#94A3B8').margin({ top: 10 })
          }.width('100%').height('100%').justifyContent(FlexAlign.Center)
        }

        if (this.errorMsg.length > 0) {
          Column() {
            Text(this.errorMsg).fontSize(14).fontColor('#F472B6')
            Button('重试').margin({ top: 12 }).onClick(() => {
              this.errorMsg = ''
              this.loading = true
              try { this.controller.refresh() } catch (e) { }
            })
          }.width('100%').height('100%').justifyContent(FlexAlign.Center)
        }
      }.width('100%').height('100%')
  }

  aboutToAppear(): void {
    // 把 controller 注册给 onBackPress 用，实现返回手势在网页内后退
    setCodeArtsController(this.controller)
  }

  aboutToDisappear(): void {
    this.stopPolling()
  }

  private onLoaded(): void {
    this.injectDark()
    this.injectCodeButtons()
    // 仅在抽屉打开时轮询；收起即停，避免 WebView 被移出屏幕后仍后台空转
    if (this.drawerOpen) {
      this.startPolling()
    }
  }

  /** 抽屉开合变化：打开恢复注入+轮询，收起停轮询并清错误态（Web 已卸载，重开重新加载） */
  onOpenChanged(): void {
    if (this.drawerOpen) {
      this.injectDark()
      this.injectCodeButtons()
      this.startPolling()
    } else {
      this.stopPolling()
      this.errorMsg = ''
    }
  }

  private startPolling(): void {
    if (this.timer >= 0) { return }
    this.timer = setInterval(() => {
      this.injectCodeButtons()
      this.drainQueue()
    }, 5000)
  }

  private stopPolling(): void {
    if (this.timer >= 0) {
      clearInterval(this.timer)
      this.timer = -1
    }
  }

  private injectDark(): void {
    if (!this.darkInject) { return }
    const css = `(function(){ if(document.getElementById('__hishDark'))return; var s=document.createElement('style'); s.id='__hishDark'; s.textContent='html,body{background:#0D0D14 !important;color:#E2E2E9 !important;}'; document.head && document.head.appendChild(s); })()`
    try { this.controller.runJavaScript(css) } catch (e) { }
  }

  private injectCodeButtons(): void {
    try { this.controller.runJavaScript(INJECT_SCRIPT) } catch (e) { }
  }

  private drainQueue(): void {
    try {
      this.controller.runJavaScript(DRAIN_SCRIPT).then((res: string) => {
        if (!res || res.length === 0 || res === '[]') { return }
        const items = JSON.parse(res) as CodeBlockItem[]
        items.forEach((it: CodeBlockItem) => {
          const ok = saveCodeBlock(this.sharedHost, it.content, it.lang)
          this.toast(ok ? '已保存到共享目录' : '共享目录不可用')
        })
      }).catch(() => { })
    } catch (e) { }
  }

  /**
   * 用本仓库既有方式弹 toast（参考 WebTerminal.saveShowVirtKey / EntryAbility），
   * 不使用计划里的 `import { promptAction } from '@kit.ArkUI'`（该写法在本项目编译期有风险）。
   */
  private toast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message, duration: 2000 })
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'showToast failed: %{public}s', JSON.stringify(e))
    }
  }
}