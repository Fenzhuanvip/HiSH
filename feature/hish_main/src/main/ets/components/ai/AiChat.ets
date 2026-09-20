import http from '@ohos.net.http';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { webview } from '@kit.ArkWeb';
import appOption from '../../model/appOption';
import { AtomGitRepo } from '../../lib/atomgit/types';

const TAG = '[AiChat]';
const DOMAIN = 0x0001;

/** CodeArts Web 控制台地址（华为云账号登录后可用 AI 代码智能体全部能力） */
const CODEARTS_WEB_URL = 'https://devcloud.cn-north-4.huaweicloud.com/home';
/** CodeArts 代码智能体入口 */
const CODEARTS_AI_URL = 'https://developer.huaweicloud.com/codeartsco.html';

interface ChatMessage {
  role: 'system' | 'user' | 'assistant'
  content: string
}

/** LLM API 响应体（OpenAI 兼容） */
interface LlmResponse {
  choices: { message: { content: string } }[]
}

type AiMode = 'codearts_web' | 'llm_api';

/**
 * AI 对话 Tab —— 双模式
 * 1. codearts_web（默认）：WebView 嵌入 CodeArts Web 控制台，用华为云账号登录，完整 AI 能力
 * 2. llm_api：调 OpenAI 兼容接口（需单独配置 LLM 端点+Key）
 */
@Component
export struct AiChat {
  @Prop repo: AtomGitRepo | null = null
  @StorageLink(appOption.llmApiBase) apiBase: string = ''
  @StorageLink(appOption.llmApiKey) apiKey: string = ''
  @StorageLink(appOption.llmModel) model: string = 'deepseek-chat'
  @State mode: AiMode = 'codearts_web'
  @State messages: ChatMessage[] = []
  @State input: string = ''
  @State sending: boolean = false
  @State webUrl: string = CODEARTS_AI_URL
  webController: webview.WebviewController = new webview.WebviewController()

  build() {
    Column() {
      this.buildModeSwitcher()
      if (this.mode === 'codearts_web') {
        this.buildCodeArtsWeb()
      } else {
        this.buildLlmChat()
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  buildModeSwitcher() {
    Row() {
      Button('CodeArts Web')
        .fontSize(11)
        .type(this.mode === 'codearts_web' ? ButtonType.Capsule : ButtonType.Normal)
        .layoutWeight(1)
        .onClick(() => { this.mode = 'codearts_web' })
      Button('LLM API')
        .fontSize(11)
        .type(this.mode === 'llm_api' ? ButtonType.Capsule : ButtonType.Normal)
        .layoutWeight(1)
        .onClick(() => { this.mode = 'llm_api' })
    }
    .width('100%')
    .height(32)
    .padding({ left: 8, right: 8 })
    .backgroundColor($r('sys.color.comp_background_tertiary'))
  }

  // ==================== 模式1：CodeArts Web（WebView 嵌入） ====================
  @Builder
  buildCodeArtsWeb() {
    Column() {
      // 顶部地址栏：可切换控制台/代码智能体
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

  // ==================== 模式2：LLM API（OpenAI 兼容） ====================
  @Builder
  buildLlmChat() {
    if (this.apiBase.length === 0 || this.apiKey.length === 0) {
      Column() {
        SymbolGlyph($r('sys.symbol.sparkles')).fontSize(40).fontColor([$r('sys.color.font_secondary')])
        Text('未配置 LLM API').fontSize(15).fontColor($r('sys.color.font_primary')).margin({ top: 12 })
        Text('请在设置页填入 LLM API 端点和 Key\n或切到「CodeArts Web」用华为云账号登录')
          .fontSize(11).fontColor($r('sys.color.font_secondary')).textAlign(TextAlign.Center)
          .margin({ top: 8, left: 24, right: 24 })
      }
      .justifyContent(FlexAlign.Center)
      .width('100%')
      .layoutWeight(1)
    } else {
      Column() {
        this.buildMessageList()
        this.buildInputBar()
      }
      .width('100%')
      .layoutWeight(1)
    }
  }

  @Builder
  buildMessageList() {
    List() {
      ForEach(this.messages, (msg: ChatMessage, index: number) => {
        ListItem() {
          this.buildMessageBubble(msg)
        }
      }, (msg: ChatMessage, index: number) => String(index))
    }
    .width('100%')
    .layoutWeight(1)
    .padding({ left: 12, right: 12, top: 8, bottom: 8 })
  }

  @Builder
  buildMessageBubble(msg: ChatMessage) {
    Row() {
      if (msg.role === 'user') {
        Blank()
        Text(msg.content)
          .fontSize(13)
          .fontColor($r('sys.color.font_on_primary'))
          .backgroundColor($r('sys.color.interactive_active'))
          .borderRadius({ topLeft: 12, topRight: 12, bottomLeft: 12, bottomRight: 2 })
          .padding(10)
          .constraintSize({ maxWidth: '75%' })
      } else {
        Text(msg.content)
          .fontSize(13)
          .fontColor($r('sys.color.font_primary'))
          .backgroundColor($r('sys.color.comp_background_tertiary'))
          .borderRadius({ topLeft: 12, topRight: 12, bottomLeft: 2, bottomRight: 12 })
          .padding(10)
          .constraintSize({ maxWidth: '75%' })
        Blank()
      }
    }
    .width('100%')
    .margin({ bottom: 8 })
  }

  @Builder
  buildInputBar() {
    Row() {
      TextArea({ text: this.input, placeholder: this.repo ? `针对 ${this.repo.full_name} 提问...` : '输入问题...' })
        .fontSize(13)
        .layoutWeight(1)
        .maxLines(4)
        .borderRadius(8)
        .backgroundColor($r('sys.color.comp_background_tertiary'))
        .onChange((val: string) => {
          this.input = val
        })
      Button({ type: ButtonType.Circle }) {
        if (this.sending) {
          LoadingProgress().width(18).height(18).color($r('sys.color.font_on_primary'))
        } else {
          SymbolGlyph($r('sys.symbol.arrow_up')).fontSize(18).fontColor([$r('sys.color.font_on_primary')])
        }
      }
      .width(36)
      .height(36)
      .margin({ left: 8 })
      .enabled(this.input.trim().length > 0 && !this.sending)
      .onClick(() => this.send())
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 8, bottom: 8 })
    .backgroundColor($r('sys.color.comp_background_primary'))
  }

  private async send(): Promise<void> {
    const userText = this.input.trim()
    if (userText.length === 0 || this.sending) return

    this.input = ''
    this.sending = true

    const sysPrompt = this.repo
      ? `你是一个 AI 编程助手，当前正在协助用户处理仓库 ${this.repo.full_name}（${this.repo.language}）。`
      : '你是一个 AI 编程助手。'

    const reqMessages: ChatMessage[] = [
      { role: 'system', content: sysPrompt },
      ...this.messages,
      { role: 'user', content: userText }
    ]
    this.messages = [...this.messages, { role: 'user', content: userText }]

    try {
      const reply = await this.callLLM(reqMessages)
      this.messages = [...this.messages, { role: 'assistant', content: reply }]
    } catch (e) {
      this.messages = [...this.messages, { role: 'assistant', content: `[请求失败] ${JSON.stringify(e)}` }]
    } finally {
      this.sending = false
    }
  }

  private async callLLM(msgs: ChatMessage[]): Promise<string> {
    const url = this.apiBase.replace(/\/$/, '') + '/chat/completions'
    const httpRequest = http.createHttp()
    try {
      const resp = await httpRequest.request(url, {
        method: http.RequestMethod.POST,
        header: {
          'Authorization': `Bearer ${this.apiKey}`,
          'Content-Type': 'application/json',
        },
        extraData: JSON.stringify({
          model: this.model,
          messages: msgs,
          stream: false,
        }),
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 15000,
        readTimeout: 60000,
      })

      if (resp.responseCode >= 200 && resp.responseCode < 300) {
        const raw = typeof resp.result === 'string' ? resp.result : String(resp.result)
        const json = JSON.parse(raw) as LlmResponse
        return json.choices?.[0]?.message?.content || '(空回复)'
      }
      throw new Error(`HTTP ${resp.responseCode}: ${String(resp.result)}`)
    } finally {
      httpRequest.destroy()
    }
  }
}
