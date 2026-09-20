import { codeArtsApi, CodeArtsCheckTask, CodeArtsCheckIssue, CodeArtsSeverity } from '../../lib/huaweicloud/CodeArtsApi';

/**
 * 代码检视 Tab —— 纯 CodeArts CodeCheck
 * 功能：列出检查任务 / 触发检查 / 查看问题列表
 */
@Component
export struct PrList {
  @State tasks: CodeArtsCheckTask[] = []
  @State loading: boolean = false
  @State errorMsg: string = ''
  @State triggering: boolean = false
  @State triggerTaskId: string = ''
  // 选中的检查任务 → 进入问题列表视图
  @State selectedTask: CodeArtsCheckTask | null = null
  @State issues: CodeArtsCheckIssue[] = []
  @State issuesLoading: boolean = false

  aboutToAppear(): void {
    this.loadTasks()
  }

  // ==================== 检查任务列表 ====================
  private async loadTasks(): Promise<void> {
    this.loading = true
    this.errorMsg = ''
    const resp = await codeArtsApi.listCheckTasks()
    this.loading = false
    if (resp.ok && resp.data) {
      this.tasks = resp.data
    } else {
      this.errorMsg = resp.message || `CodeArts 检查请求失败 (${resp.statusCode})`
    }
  }

  /** 触发代码检查 */
  private async triggerCheck(task: CodeArtsCheckTask): Promise<void> {
    this.triggering = true
    this.triggerTaskId = task.id
    const resp = await codeArtsApi.startCheckTask(task.id)
    this.triggering = false
    this.triggerTaskId = ''
    if (resp.ok) {
      // 刷新列表
      await this.loadTasks()
    } else {
      this.errorMsg = resp.message || `触发失败 (${resp.statusCode})`
    }
  }

  // ==================== 问题列表 ====================
  private async loadIssues(taskId: string): Promise<void> {
    this.issuesLoading = true
    const resp = await codeArtsApi.listCheckIssues(taskId)
    this.issuesLoading = false
    if (resp.ok && resp.data) {
      this.issues = resp.data
    }
  }

  build() {
    Column() {
      if (this.selectedTask) {
        // 第二层：问题列表
        this.buildIssueView()
      } else {
        // 第一层：检查任务列表
        this.buildTaskList()
      }
    }
    .width('100%')
    .height('100%')
  }

  // ==================== 第一层：检查任务列表 ====================
  @Builder
  buildTaskList() {
    Column() {
      Row() {
        Text('代码检查任务').fontSize(14).fontColor($r('sys.color.font_primary')).layoutWeight(1)
        Text(`共 ${this.tasks.length} 个`).fontSize(10).fontColor($r('sys.color.font_secondary'))
      }
      .width('100%').height(36).padding({ left: 12, right: 12 })
      .backgroundColor($r('sys.color.comp_background_tertiary'))

      if (this.loading) {
        Column() {
          LoadingProgress().width(32).height(32)
          Text('加载检查任务...').fontSize(12).fontColor($r('sys.color.font_secondary')).margin({ top: 8 })
        }.justifyContent(FlexAlign.Center).width('100%').layoutWeight(1)
      } else if (this.errorMsg.length > 0) {
        Column() {
          Text(this.errorMsg).fontSize(12).fontColor($r('sys.color.font_secondary')).textAlign(TextAlign.Center)
            .margin({ left: 16, right: 16 })
          Button('重试').margin({ top: 12 }).onClick(() => this.loadTasks())
        }.justifyContent(FlexAlign.Center).width('100%').layoutWeight(1)
      } else if (this.tasks.length === 0) {
        Column() {
          Text('CodeArts 项目下暂无代码检查任务').fontSize(12).fontColor($r('sys.color.font_secondary'))
        }.justifyContent(FlexAlign.Center).width('100%').layoutWeight(1)
      } else {
        List({ space: 8 }) {
          ForEach(this.tasks, (task: CodeArtsCheckTask) => {
            ListItem() {
              this.buildTaskItem(task)
            }
          }, (task: CodeArtsCheckTask) => task.id)
        }
        .width('100%').layoutWeight(1).padding({ left: 12, right: 12, top: 8, bottom: 8 })
      }
    }
    .width('100%').height('100%')
  }

  @Builder
  buildTaskItem(task: CodeArtsCheckTask) {
    Row() {
      this.buildStatusIcon(task.status)
      Column() {
        Text(task.name)
          .fontSize(13).fontColor($r('sys.color.font_primary'))
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
        Row() {
          if (task.language.length > 0) {
            Text(task.language).fontSize(10).fontColor($r('sys.color.interactive_active')).margin({ right: 8 })
          }
          Text(`${task.ruleCount} 规则`).fontSize(10).fontColor($r('sys.color.font_secondary')).margin({ right: 8 })
          Text(`${task.issueCount} 问题`).fontSize(10).fontColor(
            task.issueCount > 0 ? $r('sys.color.error') : $r('sys.color.font_secondary')
          )
          Blank()
          if (task.severity) {
            this.buildSeverityBar(task.severity)
          }
        }.width('100%').margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start).layoutWeight(1).margin({ left: 10 })
      // 触发检查按钮
      Button({ type: ButtonType.Circle }) {
        if (this.triggering && this.triggerTaskId === task.id) {
          LoadingProgress().width(16).height(16).color($r('sys.color.font_on_primary'))
        } else {
          SymbolGlyph($r('sys.symbol.play_fill')).fontSize(16).fontColor([$r('sys.color.font_on_primary')])
        }
      }
      .width(32).height(32).margin({ left: 8 })
      .enabled(!this.triggering)
      .onClick(() => this.triggerCheck(task))
    }
    .width('100%').padding(10)
    .backgroundColor($r('sys.color.comp_background_primary')).borderRadius(8)
    .onClick(() => {
      this.selectedTask = task
      this.loadIssues(task.id)
    })
  }

  // ==================== 第二层：问题列表 ====================
  @Builder
  buildIssueView() {
    Column() {
      // 返回栏
      Row() {
        Button({ type: ButtonType.Normal }) {
          SymbolGlyph($r('sys.symbol.chevron_left')).fontSize(16)
        }
        .width(32).height(32)
        .onClick(() => { this.selectedTask = null; this.issues = [] })
        Text(this.selectedTask!.name).fontSize(14).fontColor($r('sys.color.font_primary'))
          .layoutWeight(1).margin({ left: 4 })
        Text(`${this.issues.length} 问题`).fontSize(10).fontColor($r('sys.color.font_secondary'))
      }
      .width('100%').height(40).padding({ left: 8, right: 12 })
      .backgroundColor($r('sys.color.comp_background_tertiary'))

      if (this.issuesLoading) {
        Column() {
          LoadingProgress().width(32).height(32)
        }.justifyContent(FlexAlign.Center).width('100%').layoutWeight(1)
      } else if (this.issues.length === 0) {
        Column() {
          SymbolGlyph($r('sys.symbol.checkmark_seal_fill')).fontSize(40)
            .fontColor([$r('sys.color.success')]).margin({ bottom: 8 })
          Text('无问题').fontSize(13).fontColor($r('sys.color.font_secondary'))
        }.justifyContent(FlexAlign.Center).width('100%').layoutWeight(1)
      } else {
        List({ space: 6 }) {
          ForEach(this.issues, (issue: CodeArtsCheckIssue) => {
            ListItem() {
              this.buildIssueItem(issue)
            }
          }, (issue: CodeArtsCheckIssue) => issue.id)
        }
        .width('100%').layoutWeight(1).padding({ left: 12, right: 12, top: 8, bottom: 8 })
      }
    }
    .width('100%').height('100%')
  }

  @Builder
  buildIssueItem(issue: CodeArtsCheckIssue) {
    Row() {
      this.buildSeverityIcon(issue.severity)
      Column() {
        Text(issue.message)
          .fontSize(12).fontColor($r('sys.color.font_primary'))
          .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
        Row() {
          Text(issue.filePath).fontSize(10).fontColor($r('sys.color.interactive_active'))
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          Text(`:${issue.line}`).fontSize(10).fontColor($r('sys.color.font_secondary')).margin({ left: 4 })
          Text(`  [${issue.rule}]`).fontSize(9).fontColor($r('sys.color.font_secondary')).margin({ left: 8 })
        }.width('100%').margin({ top: 4 })
        if (issue.suggestion.length > 0) {
          Text(`建议: ${issue.suggestion}`)
            .fontSize(10).fontColor($r('sys.color.font_secondary'))
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%').margin({ top: 2 })
        }
      }
      .alignItems(HorizontalAlign.Start).layoutWeight(1).margin({ left: 8 })
    }
    .width('100%').padding(8)
    .backgroundColor($r('sys.color.comp_background_primary')).borderRadius(6)
  }

  // ==================== 通用 ====================
  @Builder
  buildStatusIcon(status: string) {
    if (status === 'finished' || status === 'success' || status === 'completed' || status === 'FINISHED') {
      SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
        .fontSize(18).fontColor([$r('sys.color.success')])
    } else if (status === 'running' || status === 'in_progress' || status === 'RUNNING') {
      LoadingProgress().width(18).height(18)
    } else if (status === 'failed' || status === 'error' || status === 'FAILED') {
      SymbolGlyph($r('sys.symbol.xmark_circle_fill'))
        .fontSize(18).fontColor([$r('sys.color.error')])
    } else {
      SymbolGlyph($r('sys.symbol.circle'))
        .fontSize(18).fontColor([$r('sys.color.font_secondary')])
    }
  }

  @Builder
  buildSeverityIcon(severity: string) {
    if (severity === 'fatal' || severity === 'blocker') {
      SymbolGlyph($r('sys.symbol.exclamationmark_octagon_fill'))
        .fontSize(16).fontColor([$r('sys.color.error')])
    } else if (severity === 'major' || severity === 'critical') {
      SymbolGlyph($r('sys.symbol.exclamationmark_triangle_fill'))
        .fontSize(16).fontColor([$r('sys.color.warning')])
    } else if (severity === 'minor') {
      SymbolGlyph($r('sys.symbol.info_circle_fill'))
        .fontSize(16).fontColor([$r('sys.color.interactive_active')])
    } else {
      SymbolGlyph($r('sys.symbol.lightbulb_fill'))
        .fontSize(16).fontColor([$r('sys.color.font_secondary')])
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
}
