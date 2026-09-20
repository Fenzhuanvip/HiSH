import { atomGitClient } from '../../lib/atomgit/AtomGitClient';
import { atomGitApi } from '../../lib/atomgit/AtomGitApi';
import { AtomGitUser, AtomGitRepo } from '../../lib/atomgit/types';
import { iamClient } from '../../lib/huaweicloud/IamClient';
import { codeArtsClient } from '../../lib/huaweicloud/CodeArtsClient';
import appOption from '../../model/appOption';
import RepoList from './RepoList';
import PipelineList from './PipelineList';
import PrList from './PrList';
import AiChat from './AiChat';

/**
 * AI 工作台主容器
 * 顶部用户信息 + Tab 导航（仓库/流水线/代码检视/AI对话）
 * Token 未配置时显示引导
 */
@Component
export struct AiWorkbench {
  @StorageLink(appOption.atomgitToken) token: string = ''
  @StorageLink(appOption.hwAk) hwAk: string = ''
  @StorageLink(appOption.hwSk) hwSk: string = ''
  @StorageLink(appOption.hwRegion) hwRegion: string = 'cn-north-4'
  @StorageLink(appOption.codeartsProjectId) codeartsProjectId: string = ''
  @State user: AtomGitUser | null = null
  @State loading: boolean = false
  @State errorMsg: string = ''
  @State currentTabIndex: number = 0
  @State selectedRepo: AtomGitRepo | null = null
  @State codeArtsAuthed: boolean = false

  aboutToAppear(): void {
    this.initClient()
  }

  private initClient(): void {
    // 初始化 AtomGit 客户端
    if (this.token.length > 0) {
      atomGitClient.setToken(this.token)
      this.loadUser()
    }
    // 初始化华为云 CodeArts 客户端
    if (this.hwAk.length > 0 && this.hwSk.length > 0) {
      iamClient.setCredentials(this.hwAk, this.hwSk, this.hwRegion)
      codeArtsClient.setRegion(this.hwRegion)
      codeArtsClient.setProjectId(this.codeartsProjectId)
      this.checkCodeArtsAuth()
    }
  }

  private async checkCodeArtsAuth(): Promise<void> {
    const auth = await iamClient.getToken()
    this.codeArtsAuthed = auth !== null
  }

  private async loadUser(): Promise<void> {
    this.loading = true
    this.errorMsg = ''
    const resp = await atomGitApi.getCurrentUser()
    this.loading = false
    if (resp.ok && resp.data) {
      this.user = resp.data
    } else {
      this.errorMsg = resp.message || `获取用户失败 (${resp.statusCode})`
    }
  }

  build() {
    Column() {
      if (this.token.length === 0) {
        this.buildNoTokenGuide()
      } else {
        this.buildHeader()
        this.buildTabs()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_primary'))
  }

  @Builder
  buildNoTokenGuide() {
    Column() {
      SymbolGlyph($r('sys.symbol.lock'))
        .fontSize(48)
        .fontColor([$r('sys.color.font_secondary')])
        .margin({ bottom: 16 })
      Text('未配置 AtomGit Token')
        .fontSize(18)
        .fontColor($r('sys.color.font_primary'))
        .margin({ bottom: 8 })
      Text('请在设置页填入 CodeArts 授权的 AtomGit Access Token，以启用 AI 工作台')
        .fontSize(13)
        .fontColor($r('sys.color.font_secondary'))
        .textAlign(TextAlign.Center)
        .margin({ left: 32, right: 32 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  buildHeader() {
    Row() {
      if (this.loading) {
        LoadingProgress().width(28).height(28)
      } else if (this.user) {
        Image(this.user.avatar_url)
          .width(32)
          .height(32)
          .borderRadius(16)
          .margin({ right: 10 })
        Column() {
          Text(this.user.name || this.user.login)
            .fontSize(14)
            .fontColor($r('sys.color.font_primary'))
            .maxLines(1)
          Text('@' + this.user.login)
            .fontSize(11)
            .fontColor($r('sys.color.font_secondary'))
            .maxLines(1)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        // CodeArts 认证状态标识
        if (this.codeArtsAuthed) {
          Text('CodeArts ✓')
            .fontSize(10)
            .fontColor($r('sys.color.font_on_primary'))
            .backgroundColor($r('sys.color.success'))
            .borderRadius(4)
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
        } else if (this.hwAk.length > 0) {
          Text('CodeArts ✗')
            .fontSize(10)
            .fontColor($r('sys.color.font_on_primary'))
            .backgroundColor($r('sys.color.error'))
            .borderRadius(4)
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
        }
      } else {
        Text(this.errorMsg || '未登录')
          .fontSize(12)
          .fontColor($r('sys.color.font_secondary'))
          .layoutWeight(1)
      }
    }
    .width('100%')
    .height(48)
    .padding({ left: 16, right: 16 })
    .backgroundColor($r('sys.color.comp_background_tertiary'))
  }

  @Builder
  buildTabs() {
    Tabs({ index: this.currentTabIndex }) {
      TabContent() {
        if (this.selectedRepo) {
          // 选中仓库后，其他 Tab 基于该仓库
          Column() {
            Text(this.selectedRepo.full_name)
              .fontSize(13)
              .fontColor($r('sys.color.font_secondary'))
              .padding(8)
            RepoList({
              onRepoSelected: (repo: AtomGitRepo) => {
                this.selectedRepo = repo
              }
            })
          }
        } else {
          RepoList({
            onRepoSelected: (repo: AtomGitRepo) => {
              this.selectedRepo = repo
            }
          })
        }
      }
      .tabBar('仓库')

      TabContent() {
        PipelineList({ repo: this.selectedRepo })
      }
      .tabBar('流水线')

      TabContent() {
        PrList({ repo: this.selectedRepo })
      }
      .tabBar('代码检视')

      TabContent() {
        AiChat({ repo: this.selectedRepo })
      }
      .tabBar('AI 对话')
    }
    .barMode(BarMode.Scrollable)
    .layoutWeight(1)
    .onChange((index: number) => {
      this.currentTabIndex = index
    })
  }
}
