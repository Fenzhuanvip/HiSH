import { gitCodeClient } from '../../lib/huaweicloud/GitCodeClient';
import { gitCodeApi, GitCodeRepo, GitCodeUser } from '../../lib/huaweicloud/GitCodeApi';
import appOption from '../../model/appOption';
import { RepoList } from './RepoList';
import { PrList } from './PrList';
import { IssueList } from './IssueList';

/**
 * AI 工作台主容器 —— GitCode（atomgit）架构
 * 顶部用户信息 + Tab 导航（仓库/PR/Issue）
 * Token 未配置时显示引导
 */
@Component
export struct AiWorkbench {
  @StorageLink(appOption.gitcodeToken) gitcodeToken: string = ''
  @State currentTabIndex: number = 0
  @State selectedRepo: GitCodeRepo | null = null
  @State userInfo: GitCodeUser | null = null

  aboutToAppear(): void {
    this.initClient()
  }

  private async initClient(): Promise<void> {
    if (this.gitcodeToken.length > 0) {
      gitCodeClient.setToken(this.gitcodeToken)
      const resp = await gitCodeApi.getCurrentUser()
      if (resp.ok && resp.data) {
        this.userInfo = resp.data
      }
    }
  }

  build() {
    Column() {
      if (this.gitcodeToken.length === 0) {
        this.buildNoAuthGuide()
      } else {
        this.buildHeader()
        this.buildContent()
      }
    }
    .width('100%').height('100%')
    .backgroundColor('#F1F5F9')
  }

  @Builder
  buildNoAuthGuide() {
    Column() {
      SymbolGlyph($r('sys.symbol.lock'))
        .fontSize(56).fontColor(['#94A3B8']).margin({ bottom: 20 })
      Text('未配置 GitCode Token').fontSize(18).fontColor('#1E293B').fontWeight(FontWeight.Medium)
        .margin({ bottom: 8 })
      Text('请在设置页填入 atomgit.com 的\nPersonal Access Token 以启用 AI 工作台')
        .fontSize(13).fontColor('#64748B').textAlign(TextAlign.Center)
        .margin({ left: 32, right: 32 })
    }
    .width('100%').height('100%').justifyContent(FlexAlign.Center)
  }

  @Builder
  buildHeader() {
    Row() {
      // 用户头像
      if (this.userInfo && this.userInfo.avatar_url.length > 0) {
        Image(this.userInfo.avatar_url)
          .width(32).height(32).borderRadius(16)
          .margin({ right: 10 })
      }

      Column() {
        Text(this.userInfo?.name || this.userInfo?.login || 'GitCode 用户')
          .fontSize(14).fontColor('#1E293B').fontWeight(FontWeight.Medium)
          .maxLines(1)
        Text('atomgit.com')
          .fontSize(11).fontColor('#94A3B8').maxLines(1)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      // 选中仓库标签
      if (this.selectedRepo) {
        Text(this.selectedRepo.name)
          .fontSize(11).fontColor('#FFFFFF')
          .backgroundColor('#3B82F6').borderRadius(4)
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .margin({ right: 8 })
          .onClick(() => { this.selectedRepo = null; this.currentTabIndex = 0 })
      }
    }
    .width('100%').height(52)
    .padding({ left: 16, right: 16 })
    .backgroundColor('#FFFFFF')
    .shadow({ radius: 1, color: '#0F172A0F', offsetX: 0, offsetY: 1 })
  }

  @Builder
  buildContent() {
    if (this.currentTabIndex === 0) {
      // 仓库列表
      RepoList({ onRepoSelected: (repo: GitCodeRepo) => {
        this.selectedRepo = repo
        this.currentTabIndex = 1
      }})
    } else if (this.currentTabIndex >= 1 && this.selectedRepo) {
      // PR + Issue Tab
      this.buildRepoDetail()
    }
  }

  @Builder
  buildRepoDetail() {
    Column() {
      // 子 Tab 栏
      Row() {
        Text('Pull Request').fontSize(13).fontColor(this.currentTabIndex === 1 ? '#3B82F6' : '#64748B')
          .fontWeight(this.currentTabIndex === 1 ? FontWeight.Medium : FontWeight.Normal)
          .padding({ left: 16, right: 16, top: 10, bottom: 10 })
          .onClick(() => this.currentTabIndex = 1)
        Text('Issue').fontSize(13).fontColor(this.currentTabIndex === 2 ? '#3B82F6' : '#64748B')
          .fontWeight(this.currentTabIndex === 2 ? FontWeight.Medium : FontWeight.Normal)
          .padding({ left: 16, right: 16, top: 10, bottom: 10 })
          .onClick(() => this.currentTabIndex = 2)
        Blank()
        Text('返回仓库').fontSize(12).fontColor('#64748B')
          .padding({ right: 16 })
          .onClick(() => { this.selectedRepo = null; this.currentTabIndex = 0 })
      }
      .width('100%').height(40)
      .backgroundColor('#FFFFFF')
      .shadow({ radius: 1, color: '#0F172A0F', offsetX: 0, offsetY: 1 })

      // 内容区
      if (this.currentTabIndex === 1) {
        PrList({ repoOwner: this.selectedRepo!.owner.login, repoName: this.selectedRepo!.name })
      } else {
        IssueList({ repoOwner: this.selectedRepo!.owner.login, repoName: this.selectedRepo!.name })
      }
    }
    .width('100%').layoutWeight(1)
  }
}
