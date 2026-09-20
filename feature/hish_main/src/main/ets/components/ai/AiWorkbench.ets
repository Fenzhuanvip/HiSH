import { iamClient, IamAuthResult } from '../../lib/huaweicloud/IamClient';
import { codeArtsClient } from '../../lib/huaweicloud/CodeArtsClient';
import { CodeArtsRepository } from '../../lib/huaweicloud/CodeArtsApi';
import appOption from '../../model/appOption';
import RepoList from './RepoList';
import PipelineList from './PipelineList';
import PrList from './PrList';
import AiChat from './AiChat';

/**
 * AI 工作台主容器 —— 纯 CodeArts 架构
 * 顶部用户信息 + Tab 导航（仓库/流水线/代码检视/AI对话）
 * AK/SK 未配置时显示引导
 */
@Component
export struct AiWorkbench {
  @StorageLink(appOption.hwAk) hwAk: string = ''
  @StorageLink(appOption.hwSk) hwSk: string = ''
  @StorageLink(appOption.hwRegion) hwRegion: string = 'cn-north-4'
  @StorageLink(appOption.codeartsProjectId) codeartsProjectId: string = ''
  @State authResult: IamAuthResult | null = null
  @State loading: boolean = false
  @State errorMsg: string = ''
  @State currentTabIndex: number = 0
  @State selectedRepo: CodeArtsRepository | null = null

  aboutToAppear(): void {
    this.initClient()
  }

  private initClient(): void {
    if (this.hwAk.length > 0 && this.hwSk.length > 0) {
      iamClient.setCredentials(this.hwAk, this.hwSk, this.hwRegion)
      codeArtsClient.setRegion(this.hwRegion)
      codeArtsClient.setProjectId(this.codeartsProjectId)
      this.checkAuth()
    }
  }

  private async checkAuth(): Promise<void> {
    this.loading = true
    this.errorMsg = ''
    const auth = await iamClient.getToken()
    this.loading = false
    if (auth) {
      this.authResult = auth
    } else {
      this.errorMsg = 'IAM 认证失败，请检查 AK/SK'
    }
  }

  build() {
    Column() {
      if (this.hwAk.length === 0 || this.hwSk.length === 0) {
        this.buildNoAuthGuide()
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
  buildNoAuthGuide() {
    Column() {
      SymbolGlyph($r('sys.symbol.lock'))
        .fontSize(48)
        .fontColor([$r('sys.color.font_secondary')])
        .margin({ bottom: 16 })
      Text('未配置华为云 AK/SK')
        .fontSize(18)
        .fontColor($r('sys.color.font_primary'))
        .margin({ bottom: 8 })
      Text('请在设置页填入华为云 Access Key 和 Secret Key\n以启用 CodeArts AI 工作台')
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
      } else if (this.authResult) {
        // CodeArts 认证成功
        SymbolGlyph($r('sys.symbol.checkmark_shield_fill'))
          .fontSize(28)
          .fontColor([$r('sys.color.success')])
          .margin({ right: 10 })
        Column() {
          Text(this.authResult.domainName)
            .fontSize(14)
            .fontColor($r('sys.color.font_primary'))
            .maxLines(1)
          Text(`CodeArts · ${this.hwRegion}`)
            .fontSize(11)
            .fontColor($r('sys.color.font_secondary'))
            .maxLines(1)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        // 项目 ID 状态
        if (this.codeartsProjectId.length > 0) {
          Text('项目已配置')
            .fontSize(10)
            .fontColor($r('sys.color.font_on_primary'))
            .backgroundColor($r('sys.color.success'))
            .borderRadius(4)
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
        } else {
          Text('未配置项目ID')
            .fontSize(10)
            .fontColor($r('sys.color.font_on_primary'))
            .backgroundColor($r('sys.color.warning'))
            .borderRadius(4)
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
        }
      } else {
        Text(this.errorMsg || '认证中...')
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
          Column() {
            Text(this.selectedRepo.name)
              .fontSize(13)
              .fontColor($r('sys.color.font_secondary'))
              .padding(8)
            RepoList({
              onRepoSelected: (repo: CodeArtsRepository) => {
                this.selectedRepo = repo
              }
            })
          }
        } else {
          RepoList({
            onRepoSelected: (repo: CodeArtsRepository) => {
              this.selectedRepo = repo
            }
          })
        }
      }
      .tabBar('仓库')

      TabContent() {
        PipelineList()
      }
      .tabBar('流水线')

      TabContent() {
        PrList()
      }
      .tabBar('代码检视')

      TabContent() {
        AiChat()
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
