import { codeArtsApi, CodeArtsPipeline, CodeArtsPipelineRun, CodeArtsPipelineStep } from '../../lib/huaweicloud/CodeArtsApi';

/**
 * CI/CD 流水线 Tab —— 纯 CodeArts Pipeline
 * 功能：列出流水线 / 触发构建 / 查看运行记录 / 查看步骤日志
 */
@Component
export struct PipelineList {
  @State pipelines: CodeArtsPipeline[] = []
  @State loading: boolean = false
  @State errorMsg: string = ''
  // 选中的流水线 → 进入运行记录视图
  @State selectedPipeline: CodeArtsPipeline | null = null
  @State runs: CodeArtsPipelineRun[] = []
  @State runsLoading: boolean = false
  // 选中的运行记录 → 进入步骤日志视图
  @State selectedRun: CodeArtsPipelineRun | null = null
  @State steps: CodeArtsPipelineStep[] = []
  @State stepsLoading: boolean = false
  @State stepLog: string = ''
  @State viewingStepId: string = ''
  // 触发中状态
  @State triggering: boolean = false

  aboutToAppear(): void {
    this.loadPipelines()
  }

  // ==================== 流水线列表 ====================
  private async loadPipelines(): Promise<void> {
    this.loading = true
    this.errorMsg = ''
    const resp = await codeArtsApi.listPipelines()
    this.loading = false
    if (resp.ok && resp.data) {
      this.pipelines = resp.data
    } else {
      this.errorMsg = resp.message || `CodeArts 请求失败 (${resp.statusCode})`
    }
  }

  /** 触发流水线构建 */
  private async triggerPipeline(pipeline: CodeArtsPipeline): Promise<void> {
    this.triggering = true
    const resp = await codeArtsApi.startPipelineRun(pipeline.id, pipeline.branch)
    this.triggering = false
    if (resp.ok) {
      // 触发成功，进入运行记录视图
      this.selectedPipeline = pipeline
      await this.loadRuns(pipeline.id)
    } else {
      this.errorMsg = resp.message || `触发失败 (${resp.statusCode})`
    }
  }

  // ==================== 运行记录 ====================
  private async loadRuns(pipelineId: string): Promise<void> {
    this.runsLoading = true
    const resp = await codeArtsApi.listPipelineRuns(pipelineId)
    this.runsLoading = false
    if (resp.ok && resp.data) {
      this.runs = resp.data
    }
  }

  // ==================== 步骤日志 ====================
  private async loadSteps(pipelineId: string, runId: string): Promise<void> {
    this.stepsLoading = true
    const resp = await codeArtsApi.listPipelineSteps(pipelineId, runId)
    this.stepsLoading = false
    if (resp.ok && resp.data) {
      this.steps = resp.data
      // 自动加载第一个步骤的日志
      if (this.steps.length > 0) {
        await this.loadStepLog(pipelineId, runId, this.steps[0].id)
      }
    }
  }

  private async loadStepLog(pipelineId: string, runId: string, stepId: string): Promise<void> {
    this.viewingStepId = stepId
    const resp = await codeArtsApi.getPipelineStepLog(pipelineId, runId, stepId)
    if (resp.ok && resp.data) {
      this.stepLog = resp.data
    } else {
      this.stepLog = '(无日志)'
    }
  }

  build() {
    Column() {
      if (this.selectedRun && this.selectedPipeline) {
        // 第三层：步骤日志视图
        this.buildStepLogView()
      } else if (this.selectedPipeline) {
        // 第二层：运行记录视图
        this.buildRunsView()
      } else {
        // 第一层：流水线列表
        this.buildPipelineList()
      }
    }
    .width('100%')
    .height('100%')
  }

  // ==================== 第一层：流水线列表 ====================
  @Builder
  buildPipelineList() {
    Column() {
      // 顶部标题栏
      Row() {
        Text('流水线列表').fontSize(14).fontColor($r('sys.color.font_primary')).layoutWeight(1)
        Text(`共 ${this.pipelines.length} 条`).fontSize(10).fontColor($r('sys.color.font_secondary'))
      }
      .width('100%').height(36).padding({ left: 12, right: 12 })
      .backgroundColor($r('sys.color.comp_background_tertiary'))

      if (this.loading) {
        Column() {
          LoadingProgress().width(32).height(32)
          Text('加载流水线...').fontSize(12).fontColor($r('sys.color.font_secondary')).margin({ top: 8 })
        }.justifyContent(FlexAlign.Center).width('100%').layoutWeight(1)
      } else if (this.errorMsg.length > 0) {
        Column() {
          Text(this.errorMsg).fontSize(12).fontColor($r('sys.color.font_secondary')).textAlign(TextAlign.Center)
            .margin({ left: 16, right: 16 })
          Button('重试').margin({ top: 12 }).onClick(() => this.loadPipelines())
        }.justifyContent(FlexAlign.Center).width('100%').layoutWeight(1)
      } else if (this.pipelines.length === 0) {
        Column() {
          Text('CodeArts 项目下暂无流水线').fontSize(12).fontColor($r('sys.color.font_secondary'))
        }.justifyContent(FlexAlign.Center).width('100%').layoutWeight(1)
      } else {
        List({ space: 8 }) {
          ForEach(this.pipelines, (p: CodeArtsPipeline) => {
            ListItem() {
              this.buildPipelineItem(p)
            }
          }, (p: CodeArtsPipeline) => p.id)
        }
        .width('100%').layoutWeight(1).padding({ left: 12, right: 12, top: 8, bottom: 8 })
      }
    }
    .width('100%').height('100%')
  }

  @Builder
  buildPipelineItem(p: CodeArtsPipeline) {
    Row() {
      this.buildStatusIcon(p.latestRunStatus || p.status)
      Column() {
        Text(p.name)
          .fontSize(13).fontColor($r('sys.color.font_primary'))
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
        Row() {
          if (p.branch.length > 0) {
            Text(p.branch).fontSize(10).fontColor($r('sys.color.interactive_active')).margin({ right: 8 })
          }
          Text(p.creator).fontSize(10).fontColor($r('sys.color.font_secondary')).margin({ right: 8 })
          Blank()
          Text(this.formatTime(p.updatedAt)).fontSize(10).fontColor($r('sys.color.font_secondary'))
        }.width('100%').margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start).layoutWeight(1).margin({ left: 10 })
      // 触发构建按钮
      Button({ type: ButtonType.Circle }) {
        if (this.triggering) {
          LoadingProgress().width(16).height(16).color($r('sys.color.font_on_primary'))
        } else {
          SymbolGlyph($r('sys.symbol.play_fill')).fontSize(16).fontColor([$r('sys.color.font_on_primary')])
        }
      }
      .width(32).height(32).margin({ left: 8 })
      .enabled(!this.triggering)
      .onClick(() => this.triggerPipeline(p))
    }
    .width('100%').padding(10)
    .backgroundColor($r('sys.color.comp_background_primary')).borderRadius(8)
    .onClick(() => {
      this.selectedPipeline = p
      this.loadRuns(p.id)
    })
  }

  // ==================== 第二层：运行记录 ====================
  @Builder
  buildRunsView() {
    Column() {
      // 返回栏
      Row() {
        Button({ type: ButtonType.Normal }) {
          SymbolGlyph($r('sys.symbol.chevron_left')).fontSize(16)
        }
        .width(32).height(32)
        .onClick(() => { this.selectedPipeline = null; this.runs = [] })
        Text(this.selectedPipeline!.name).fontSize(14).fontColor($r('sys.color.font_primary'))
          .layoutWeight(1).margin({ left: 4 })
        // 触发构建按钮
        Button('触发构建').fontSize(11)
          .enabled(!this.triggering)
          .onClick(() => this.triggerPipeline(this.selectedPipeline!))
      }
      .width('100%').height(40).padding({ left: 8, right: 12 })
      .backgroundColor($r('sys.color.comp_background_tertiary'))

      if (this.runsLoading) {
        Column() {
          LoadingProgress().width(32).height(32)
        }.justifyContent(FlexAlign.Center).width('100%').layoutWeight(1)
      } else if (this.runs.length === 0) {
        Column() {
          Text('暂无运行记录').fontSize(12).fontColor($r('sys.color.font_secondary'))
        }.justifyContent(FlexAlign.Center).width('100%').layoutWeight(1)
      } else {
        List({ space: 8 }) {
          ForEach(this.runs, (run: CodeArtsPipelineRun) => {
            ListItem() {
              this.buildRunItem(run)
            }
          }, (run: CodeArtsPipelineRun) => run.id)
        }
        .width('100%').layoutWeight(1).padding({ left: 12, right: 12, top: 8, bottom: 8 })
      }
    }
    .width('100%').height('100%')
  }

  @Builder
  buildRunItem(run: CodeArtsPipelineRun) {
    Row() {
      this.buildStatusIcon(run.status)
      Column() {
        Text(`#${run.buildNumber}  ${run.trigger}`)
          .fontSize(13).fontColor($r('sys.color.font_primary')).width('100%')
        Row() {
          Text(run.branch).fontSize(10).fontColor($r('sys.color.interactive_active')).margin({ right: 8 })
          Text(run.commitId.length > 8 ? run.commitId.substring(0, 8) : run.commitId)
            .fontSize(10).fontColor($r('sys.color.font_secondary')).margin({ right: 8 })
          Blank()
          Text(this.formatTime(run.startTime)).fontSize(10).fontColor($r('sys.color.font_secondary'))
        }.width('100%').margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start).layoutWeight(1).margin({ left: 10 })
      SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(14).fontColor([$r('sys.color.font_secondary')])
    }
    .width('100%').padding(10)
    .backgroundColor($r('sys.color.comp_background_primary')).borderRadius(8)
    .onClick(() => {
      this.selectedRun = run
      this.loadSteps(this.selectedPipeline!.id, run.id)
    })
  }

  // ==================== 第三层：步骤日志 ====================
  @Builder
  buildStepLogView() {
    Column() {
      // 返回栏
      Row() {
        Button({ type: ButtonType.Normal }) {
          SymbolGlyph($r('sys.symbol.chevron_left')).fontSize(16)
        }
        .width(32).height(32)
        .onClick(() => { this.selectedRun = null; this.steps = []; this.stepLog = '' })
        Text(`#${this.selectedRun!.buildNumber} 步骤`).fontSize(14).fontColor($r('sys.color.font_primary'))
          .layoutWeight(1).margin({ left: 4 })
      }
      .width('100%').height(40).padding({ left: 8, right: 12 })
      .backgroundColor($r('sys.color.comp_background_tertiary'))

      // 步骤列表（横向滚动）
      if (this.steps.length > 0) {
        Scroll() {
          Row({ space: 6 }) {
            ForEach(this.steps, (step: CodeArtsPipelineStep) => {
              Button(step.name)
                .fontSize(10)
                .type(this.viewingStepId === step.id ? ButtonType.Capsule : ButtonType.Normal)
                .margin({ right: 4 })
                .onClick(() => this.loadStepLog(this.selectedPipeline!.id, this.selectedRun!.id, step.id))
            }, (step: CodeArtsPipelineStep) => step.id)
          }
          .padding({ left: 8, right: 8 })
        }
        .scrollable(ScrollDirection.Horizontal)
        .width('100%').height(36)
        .backgroundColor($r('sys.color.comp_background_primary'))
      }

      // 日志内容
      if (this.stepsLoading) {
        Column() {
          LoadingProgress().width(32).height(32)
        }.justifyContent(FlexAlign.Center).width('100%').layoutWeight(1)
      } else {
        Scroll() {
          Text(this.stepLog.length > 0 ? this.stepLog : '(无日志)')
            .fontSize(11)
            .fontColor($r('sys.color.font_primary'))
            .fontFamily('monospace')
            .width('100%')
            .padding(8)
        }
        .scrollable(ScrollDirection.Vertical)
        .scrollBar(BarState.On)
        .width('100%').layoutWeight(1)
        .backgroundColor($r('sys.color.background_primary'))
      }
    }
    .width('100%').height('100%')
  }

  // ==================== 通用 ====================
  @Builder
  buildStatusIcon(status: string) {
    if (status === 'success' || status === 'SUCCEEDED' || status === 'completed') {
      SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
        .fontSize(18).fontColor([$r('sys.color.success')])
    } else if (status === 'failure' || status === 'FAILED' || status === 'error' || status === 'canceled') {
      SymbolGlyph($r('sys.symbol.xmark_circle_fill'))
        .fontSize(18).fontColor([$r('sys.color.error')])
    } else if (status === 'running' || status === 'RUNNING' || status === 'in_progress' || status === 'pending' || status === 'QUEUED') {
      LoadingProgress().width(18).height(18)
    } else {
      SymbolGlyph($r('sys.symbol.circle'))
        .fontSize(18).fontColor([$r('sys.color.font_secondary')])
    }
  }

  private formatTime(iso: string): string {
    if (!iso || iso.length === 0) return ''
    return iso.substring(5, 16).replace('T', ' ')
  }
}
