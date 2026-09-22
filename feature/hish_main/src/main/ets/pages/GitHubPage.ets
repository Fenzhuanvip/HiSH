import { hilog } from '@kit.PerformanceAnalysisKit';
import { webview } from '@kit.ArkWeb';
import napi from 'libhish_main.so';
import stringToArrayBuffer from '../lib/stringToArrayBuffer';

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
        .javaScriptProxy({
          object: this, name: 'hishTerminal',
          methodList: ['sendCommand', 'sendInput'],
          controller: this.webController, asyncMethodList: [],
          permission: `{"javascriptProxyPermission":{"urlPermissionList":[{"scheme":"https","host":"github.com","port":"","path":""}]}}`
        })
        .onPageBegin(() => {
          this.loading = true
        })
        .onPageEnd((e) => {
          this.loading = false
          hilog.info(DOMAIN, TAG, 'GitHub loaded: %{public}s', e.url)
          this.injectFloatingButton()
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
        .backgroundColor('#FDF7FA')
        .justifyContent(FlexAlign.Center)
      }

      if (this.errorMsg.length > 0) {
        Column() {
          Text(this.errorMsg).fontSize(16).fontColor('#EC4899')
          Button('重试').margin({ top: 15 }).onClick(() => {
            this.errorMsg = ''
            this.loading = true
            this.webController.refresh()
          })
        }
        .width('100%').height('100%')
        .backgroundColor('#FDF7FA')
        .justifyContent(FlexAlign.Center)
      }
    }
    .width('100%').height('100%')
  }

  private injectFloatingButton(): void {
    const script = `(function(){
      if(window.__hishBtn) return;
      var b=document.createElement('div');
      b.style.cssText='position:fixed;right:16px;bottom:80px;width:52px;height:52px;border-radius:26px;background:linear-gradient(135deg,#F472B6,#A78BFA);color:#fff;display:flex;align-items:center;justify-content:center;font-size:22px;cursor:pointer;z-index:99999;box-shadow:0 4px 16px rgba(244,114,182,0.5)';
      b.textContent='\\u26A1';
      b.onclick=function(){
        var m=document.getElementById('__hishM');
        if(m){m.remove();return;}
        m=document.createElement('div');
        m.id='__hishM';
        m.style.cssText='position:fixed;right:16px;bottom:144px;background:#1A1B2E;border-radius:14px;padding:6px;z-index:99999;box-shadow:0 8px 32px rgba(0,0,0,0.4);min-width:180px';
        var t=document.createElement('div');
        t.style.cssText='padding:10px 14px;color:#F472B6;font-size:13px;font-weight:600;border-bottom:1px solid rgba(244,114,182,0.2);margin-bottom:4px';
        t.textContent='\\u7EC8\\u7AEF\\u64CD\\u4F5C';
        m.appendChild(t);
        var cmds=[
          {l:'\\u67E5\\u770B\\u78C1\\u76D8',c:'df -h'},
          {l:'\\u67E5\\u770B\\u5185\\u5B58',c:'free -h'},
          {l:'\\u5217\\u51FA\\u6587\\u4EF6',c:'ls -la'},
          {l:'\\u67E5\\u770B\\u8FDB\\u7A0B',c:'ps aux'},
          {l:'\\u67E5\\u770B\\u7F51\\u7EDC',c:'ip addr'},
          {l:'\\u6E05\\u5C4F',c:'clear'}
        ];
        cmds.forEach(function(item){
          var r=document.createElement('div');
          r.style.cssText='padding:10px 14px;color:#E2E2E9;cursor:pointer;border-radius:8px;font-size:13px';
          r.textContent=item.l;
          r.onmouseenter=function(){r.style.background='rgba(244,114,182,0.15)';r.style.color='#F472B6';};
          r.onmouseleave=function(){r.style.background='transparent';r.style.color='#E2E2E9';};
          r.onclick=function(){
            try{hishTerminal.sendCommand(item.c)}catch(e){}
            m.remove();
          };
          m.appendChild(r);
        });
        document.body.appendChild(m);
      };
      document.body.appendChild(b);
      window.__hishBtn=b;
    })()`
    try {
      this.webController.runJavaScript(script)
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'Inject failed: %{public}s', JSON.stringify(e))
    }
  }

  sendCommand(cmd: string): void {
    hilog.info(DOMAIN, TAG, 'sendCommand: %{public}s', cmd)
    try {
      const buffer = stringToArrayBuffer(cmd + '\n', 'utf-8')
      napi.sendInput(buffer)
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'sendCommand failed: %{public}s', JSON.stringify(e))
    }
  }

  sendInput(data: string): void {
    hilog.info(DOMAIN, TAG, 'sendInput: %{public}s', data)
    try { napi.sendInput(stringToArrayBuffer(data, 'utf-8')) } catch (e) {}
  }
}
