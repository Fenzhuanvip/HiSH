import { atomGitApi } from '../../lib/atomgit/AtomGitApi';
import { AtomGitRepo, AtomGitPR } from '../../lib/atomgit/types';
import { codeArtsApi, CodeArtsCheckTask, CodeArtsSeverity } from '../../lib/huaweicloud/CodeArtsApi';
import { iamClient } from '../../lib/huaweicloud/IamClient';
import { codeArtsClient } from '../../lib/huaweicloud/CodeArtsClient';

type CheckView = 'codearts' | 'prs';

/**
 * 代码检视 Tab —— 双视图
 * 1. CodeArts 代码检查（CodeCheck 任务 + 问题统计）
 * 2. AtomGit PR 列表（代码审查）
 */
@Component
export struct PrList {
  @Prop repo: AtomGitRepo | null = null
  @State view: CheckView = 'codearts'
  @State codeArtsAvailable: boolean = false
  // CodeArts 检查
  @State checkTasks: CodeArtsCheckTask[] = []
  @State checkLoading: boolean = false
  @State checkError: string = ''
  // PR 列表
  @State prs: AtomGitPR[] = []
  @State prLoading: boolean = false
  @State prError: string = ''
  @State stateFilter: string = 'open'

  aboutToAppear(): void {
    this.detectView()
    this.load()
  }

  aboutToReuse(): void {
    this.detectView()
    this.load()
  }

  private detectView(): void {
    this.codeArtsAvailable = iamClient.isConfigured() && codeArtsClient.getProjectId().length > 0
    if (!this.codeArtsAvailable) {
      this.view = 'prs'
    }
  }

  private async load(): Promise<void> {
    if (this.view === 'codearts') {
      await this.loadCheckTasks()
    } else {
      await this.loadPRs()
    }
  }

  // ==================== CodeArts 代码检查 ====================
  private async loadCheckTasks(): Promise<void> {
    this.checkLoading = true
    this.checkError = ''
    const resp = await codeArtsApi.listCheckTasks()
    this.checkLoading = false
    if (resp.ok && resp.data) {
      this.checkTasks = resp.data
    } else {
      this.checkError = resp.message || `CodeArts 检查请求失败 (${resp.statusCode})`
      this.checkTasks = []
    }
  }

  // ==================== AtomGit PR ====================
  private async loadPRs(): Promise<void> {
    if (!this.repo) {
      this.prError = '请先在「仓库」Tab 选择一个仓库'
      return
    }
    const parts = this.repo.full_name.split('/')
    if (parts.length < 2) return
    this.prLoading = true
    this.prError = ''
    const resp = await atomGitApi.listPRs(parts[0], parts[1], this.stateFilter)
    this.prLoading = false
    if (resp.ok && resp.data) {
      this.prs = resp.data
    } else {
      this.prError = resp.message || `加载失败 (${resp.statusCode})`
    }
  }

  build() {
    Column() {
      this.buildViewSwitcher()
      if (this.view === 'codearts') {
        this.buildCheckView()
      } else {
        this.buildPrView()
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  buildViewSwitcher() {
    Row() {
      Button('CodeArts 检查')
        .fontSize(10)
        .type(this.view === 'codearts' ? ButtonType.Capsule : ButtonType.Normal)
        .enabled(this.codeArtsAvailable)
        .margin({ right: 6 })
        .onClick(() => { this.view = 'codearts'; this.load() })
      Button('PR 审查')
        .fontSize(10)
        .type(this.view === 'prs' ? ButtonType.Capsule : ButtonType.Normal)
        .onClick(() => { this.view = 'prs'; this.load() })
    }
    .width('100%')
    .height(32)
    .padding({ left: 12, right: 12 })
    .backgroundColor($r('sys.color.comp_background_tertiary'))
  }

  // ==================== CodeArts 检查视图 ====================
  @Builder
  buildCheckView() {
    if (this.checkLoading) {
      Column() {
        LoadingProgress().width(32).height(32)
        Text('加载代码检查...').fontSize(12).fontColor($r('sys.color.font_secondary')).margin({ top: 8 })
      }.justifyContent(FlexAlign.Center).width('100%').layoutWeight(1)
    } else if (this.checkError.length > 0) {
      Column() {
        Text(this.checkError).fontSize(12).fontColor($r('sys.color.font_secondary')).textAlign(TextAlign.Center)
          .margin({ left: 16, right: 16 })
        Button('重试').margin({ top: 12 }).onClick(() => this.loadCheckTasks())
      }.justifyContent(FlexAlign.Center).width('100%').layoutWeight(1)
    } else if (this.checkTasks.length === 0) {
      Column() {
        Text('CodeArts 项目下暂无代码检查任务').fontSize(12).fontColor($r('sys.color.font_secondary'))
      }.justifyContent(FlexAlign.Center).width('100%').layoutWeight(1)
    } else {
      List({ space: 8 }) {
        ForEach(this.checkTasks, (task: CodeArtsCheckTask) => {
          ListItem() {
            this.buildCheckItem(task)
          }
        }, (task: CodeArtsCheckTask) => task.id)
      }
      .width('100%')
      .layoutWeight(1)
      .padding({ left: 12, right: 12, top: 8, bottom: 8 })
    }
  }

  @Builder
  buildCheckItem(task: CodeArtsCheckTask) {
    Row() {
      this.buildCheckStatusIcon(task.status)
      Column() {
        Text(task.name)
          .fontSize(13)
          .fontColor($r('sys.color.font_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Row() {
          if (task.language.length > 0) {
            Text(task.language).fontSize(10).fontColor($r('sys.color.interactive_active')).margin({ right: 8 })
          }
          Text(`${task.ruleCount} 规则`).fontSize(10).fontColor($r('sys.color.font_secondary')).margin({ right: 8 })
          Text(`${task.issueCount} 问题`).fontSize(10).fontColor(
            task.issueCount > 0 ? $r('sys.color.error') : $r('sys.color.font_secondary')
          )
          Blank()
          // 严重等级分布
          if (task.severity) {
            this.buildSeverityBar(task.severity)
          }
        }
        .width('100%')
        .margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .margin({ left: 10 })
    }
    .width('100%')
    .padding(10)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(8)
  }

  @Builder
  buildCheckStatusIcon(status: string) {
    if (status === 'finished' || status === 'success' || status === 'completed') {
      SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
        .fontSize(18).fontColor([$r('sys.color.success')])
    } else if (status === 'running' || status === 'in_progress' || status === 'pending') {
      LoadingProgress().width(18).height(18)
    } else if (status === 'failed' || status === 'error') {
      SymbolGlyph($r('sys.symbol.xmark_circle_fill'))
        .fontSize(18).fontColor([$r('sys.color.error')])
    } else {
      SymbolGlyph($r('sys.symbol.circle'))
        .fontSize(18).fontColor([$r('sys.color.font_secondary')])
    }
  }

  @Builder
  buildSeverityBar(severity: CodeArtsSeverity) {
    Row() {
      if (severity.fatal > 0) {
        Text(`致命 ${severity.fatal}`).fontSize(8).fontColor($r('sys.color.font_on_primary'))
          .backgroundColor($r('sys.color.error')).borderRadius(3)
          .padding({ left: 3, right: 3, top: 1, bottom: 1 }).margin({ right: 3 })
      }
      if (severity.major > 0) {
        Text(`严重 ${severity.major}`).fontSize(8).fontColor($r('sys.color.font_on_primary'))
          .backgroundColor($r('sys.color.warning')).borderRadius(3)
          .padding({ left: 3, right: 3, top: 1, bottom: 1 }).margin({ right: 3 })
      }
      if (severity.minor > 0) {
        Text(`次要 ${severity.minor}`).fontSize(8).fontColor($r('sys.color.font_secondary'))
          .border({ width: 0.5, color: $r('sys.color.font_secondary') }).borderRadius(3)
          .padding({ left: 3, right: 3, top: 1, bottom: 1 }).margin({ right: 3 })
      }
    }
  }

  // ==================== PR 视图 ====================
  @Builder
  buildPrView() {
    Column() {
      if (this.repo) {
        this.buildFilterBar()
      }
      if (!this.repo) {
        Column() {
          Text('请先在「仓库」Tab 选择一个仓库').fontSize(12).fontColor($r('sys.color.font_secondary'))
        }.justifyContent(FlexAlign.Center).width('100%').layoutWeight(1)
      } else if (this.prLoading) {
        Column() {
          LoadingProgress().width(32).height(32)
          Text('加载 PR...').fontSize(12).fontColor($r('sys.color.font_secondary')).margin({ top: 8 })
        }.justifyContent(FlexAlign.Center).width('100%').layoutWeight(1)
      } else if (this.prError.length > 0) {
        Column() {
          Text(this.prError).fontSize(12).fontColor($r('sys.color.font_secondary')).textAlign(TextAlign.Center)
          Button('重试').margin({ top: 12 }).onClick(() => this.loadPRs())
        }.justifyContent(FlexAlign.Center).width('100%').layoutWeight(1)
      } else if (this.prs.length === 0) {
        Column() {
          Text(`无${this.stateFilter === 'open' ? '开启' : '关闭'}的 PR`).fontSize(12).fontColor($r('sys.color.font_secondary'))
        }.justifyContent(FlexAlign.Center).width('100%').layoutWeight(1)
      } else {
        List({ space: 8 }) {
          ForEach(this.prs, (pr: AtomGitPR) => {
            ListItem() {
              this.buildPrItem(pr)
            }
          }, (pr: AtomGitPR) => String(pr.number))
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 12, right: 12, top: 8, bottom: 8 })
      }
    }
    .width('100%')
    .layoutWeight(1)
  }

  @Builder
  buildFilterBar() {
    Row() {
      Button('开启')
        .fontSize(11)
        .type(this.stateFilter === 'open' ? ButtonType.Capsule : ButtonType.Normal)
        .margin({ right: 6 })
        .onClick(() => { this.stateFilter = 'open'; this.loadPRs() })
      Button('关闭')
        .fontSize(11)
        .type(this.stateFilter === 'closed' ? ButtonType.Capsule : ButtonType.Normal)
        .onClick(() => { this.stateFilter = 'closed'; this.loadPRs() })
      Blank()
      Text(`共 ${this.prs.length} 个`).fontSize(10).fontColor($r('sys.color.font_secondary'))
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 6, bottom: 6 })
  }

  @Builder
  buildPrItem(pr: AtomGitPR) {
    Row() {
      if (pr.merged) {
        SymbolGlyph($r('sys.symbol.checkmark_seal_fill')).fontSize(16).fontColor([$r('sys.color.interactive_active')])
      } else if (pr.state === 'open') {
        SymbolGlyph($r('sys.symbol.plus_circle')).fontSize(16).fontColor([$r('sys.color.success')])
      } else {
        SymbolGlyph($r('sys.symbol.minus_circle')).fontSize(16).fontColor([$r('sys.color.font_secondary')])
      }
      Column() {
        Text(`#${pr.number}  ${pr.title}`)
          .fontSize(13)
          .fontColor($r('sys.color.font_primary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .margin({ left: 8 })
        Row() {
          Text(`${pr.head.ref} → ${pr.base.ref}`)
            .fontSize(10)
            .fontColor($r('sys.color.font_secondary'))
            .margin({ left: 8, right: 8 })
          if (pr.changed_files) {
            Text(`±${pr.changed_files}`).fontSize(10).fontColor($r('sys.color.font_secondary')).margin({ right: 8 })
          }
          if (pr.additions !== undefined && pr.deletions !== undefined) {
            Text(`+${pr.additions} -${pr.deletions}`).fontSize(10)
              .fontColor($r('sys.color.font_secondary'))
          }
          Blank()
          if (pr.draft) {
            Text('草稿').fontSize(10).fontColor($r('sys.color.font_secondary')).margin({ left: 4 })
          }
        }
        .width('100%')
        .margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding(10)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(8)
  }
}
