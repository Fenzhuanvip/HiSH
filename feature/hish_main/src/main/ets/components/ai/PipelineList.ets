import { atomGitApi } from '../../lib/atomgit/AtomGitApi';
import { AtomGitRepo, AtomGitRun } from '../../lib/atomgit/types';
import { codeArtsApi, CodeArtsPipeline } from '../../lib/huaweicloud/CodeArtsApi';
import { iamClient } from '../../lib/huaweicloud/IamClient';
import { codeArtsClient } from '../../lib/huaweicloud/CodeArtsClient';

/** 统一流水线显示模型（双数据源归一化） */
interface PipelineDisplayItem {
  id: string
  title: string
  status: string      // success / failure / running / pending / canceled / unknown
  branch: string
  trigger: string
  buildNumber: number
  time: string
  source: string      // 'codearts' | 'atomgit'
}

type DataSource = 'codearts' | 'atomgit';

/**
 * CI/CD 流水线列表 Tab —— 双数据源
 * 优先用 CodeArts Pipeline API（项目级流水线），回退到 AtomGit Actions（仓库级）
 */
@Component
export struct PipelineList {
  @Prop repo: AtomGitRepo | null = null
  @State items: PipelineDisplayItem[] = []
  @State loading: boolean = false
  @State errorMsg: string = ''
  @State dataSource: DataSource = 'codearts'
  @State codeArtsAvailable: boolean = false

  aboutToAppear(): void {
    this.detectDataSource()
    this.load()
  }

  aboutToReuse(): void {
    this.detectDataSource()
    this.load()
  }

  private detectDataSource(): void {
    this.codeArtsAvailable = iamClient.isConfigured() && codeArtsClient.getProjectId().length > 0
    if (!this.codeArtsAvailable) {
      this.dataSource = 'atomgit'
    }
  }

  private async load(): Promise<void> {
    if (this.dataSource === 'codearts') {
      await this.loadFromCodeArts()
    } else {
      await this.loadFromAtomGit()
    }
  }

  // ==================== 数据源1：CodeArts Pipeline API ====================
  private async loadFromCodeArts(): Promise<void> {
    this.loading = true
    this.errorMsg = ''
    const resp = await codeArtsApi.listPipelines()
    this.loading = false
    if (resp.ok && resp.data) {
      this.items = resp.data.map((p: CodeArtsPipeline): PipelineDisplayItem => {
        return {
          id: p.id,
          title: p.name,
          status: p.latestRunStatus || p.status || 'unknown',
          branch: p.branch || '',
          trigger: '',
          buildNumber: 0,
          time: p.updatedAt || p.createdAt || '',
          source: 'codearts',
        }
      })
    } else {
      this.errorMsg = resp.message || `CodeArts 请求失败 (${resp.statusCode})`
      this.items = []
      // CodeArts 失败时自动回退到 atomgit（如果已选仓库）
      if (this.repo) {
        this.dataSource = 'atomgit'
        await this.loadFromAtomGit()
      }
    }
  }

  // ==================== 数据源2：AtomGit Actions ====================
  private async loadFromAtomGit(): Promise<void> {
    if (!this.repo) {
      this.errorMsg = '请先在「仓库」Tab 选择一个仓库'
      this.items = []
      return
    }
    const parts = this.repo.full_name.split('/')
    if (parts.length < 2) {
      this.errorMsg = '仓库名格式异常'
      return
    }
    this.loading = true
    this.errorMsg = ''
    const resp = await atomGitApi.listRuns(parts[0], parts[1], 1, 30)
    this.loading = false
    if (resp.ok && resp.data) {
      this.items = resp.data.map((run: AtomGitRun): PipelineDisplayItem => {
        return {
          id: String(run.id),
          title: run.display_title || run.name || `#${run.run_number}`,
          status: run.conclusion || run.status || 'unknown',
          branch: run.head_branch || '',
          trigger: run.event || '',
          buildNumber: run.run_number,
          time: run.created_at || '',
          source: 'atomgit',
        }
      })
    } else {
      this.errorMsg = resp.message || `加载失败 (${resp.statusCode})`
      this.items = []
    }
  }

  build() {
    Column() {
      this.buildSourceSwitcher()
      if (this.loading) {
        Column() {
          LoadingProgress().width(32).height(32)
          Text('加载流水线...').fontSize(12).fontColor($r('sys.color.font_secondary')).margin({ top: 8 })
        }.justifyContent(FlexAlign.Center).width('100%').layoutWeight(1)
      } else if (this.errorMsg.length > 0) {
        Column() {
          Text(this.errorMsg).fontSize(12).fontColor($r('sys.color.font_secondary')).textAlign(TextAlign.Center)
            .margin({ left: 16, right: 16 })
          Button('重试').margin({ top: 12 }).onClick(() => this.load())
        }.justifyContent(FlexAlign.Center).width('100%').layoutWeight(1)
      } else if (this.items.length === 0) {
        Column() {
          Text(this.dataSource === 'codearts' ? 'CodeArts 项目下暂无流水线' : '该仓库暂无流水线运行记录')
            .fontSize(12).fontColor($r('sys.color.font_secondary'))
        }.justifyContent(FlexAlign.Center).width('100%').layoutWeight(1)
      } else {
        List({ space: 8 }) {
          ForEach(this.items, (item: PipelineDisplayItem) => {
            ListItem() {
              this.buildItem(item)
            }
          }, (item: PipelineDisplayItem) => item.id)
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 12, right: 12, top: 8, bottom: 8 })
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  buildSourceSwitcher() {
    Row() {
      Button('CodeArts')
        .fontSize(10)
        .type(this.dataSource === 'codearts' ? ButtonType.Capsule : ButtonType.Normal)
        .enabled(this.codeArtsAvailable)
        .margin({ right: 6 })
        .onClick(() => { this.dataSource = 'codearts'; this.load() })
      Button('AtomGit')
        .fontSize(10)
        .type(this.dataSource === 'atomgit' ? ButtonType.Capsule : ButtonType.Normal)
        .onClick(() => { this.dataSource = 'atomgit'; this.load() })
      Blank()
      Text(`共 ${this.items.length} 条`).fontSize(10).fontColor($r('sys.color.font_secondary'))
    }
    .width('100%')
    .height(32)
    .padding({ left: 12, right: 12 })
    .backgroundColor($r('sys.color.comp_background_tertiary'))
  }

  @Builder
  buildItem(item: PipelineDisplayItem) {
    Row() {
      this.buildStatusIcon(item.status)
      Column() {
        Text(item.title)
          .fontSize(13)
          .fontColor($r('sys.color.font_primary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Row() {
          if (item.buildNumber > 0) {
            Text(`#${item.buildNumber}`).fontSize(10).fontColor($r('sys.color.font_secondary')).margin({ right: 8 })
          }
          if (item.trigger.length > 0) {
            Text(item.trigger).fontSize(10).fontColor($r('sys.color.font_secondary')).margin({ right: 8 })
          }
          if (item.branch.length > 0) {
            Text(item.branch).fontSize(10).fontColor($r('sys.color.interactive_active')).margin({ right: 8 })
          }
          Blank()
          // 数据来源标识
          Text(item.source === 'codearts' ? 'CA' : 'AG')
            .fontSize(8).fontColor($r('sys.color.font_secondary'))
            .border({ width: 0.5, color: $r('sys.color.font_secondary') })
            .borderRadius(3)
            .padding({ left: 3, right: 3, top: 1, bottom: 1 })
            .margin({ right: 6 })
          Text(this.formatTime(item.time)).fontSize(10).fontColor($r('sys.color.font_secondary'))
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
  buildStatusIcon(status: string) {
    if (status === 'success') {
      SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
        .fontSize(18).fontColor([$r('sys.color.success')])
    } else if (status === 'failure' || status === 'canceled' || status === 'error') {
      SymbolGlyph($r('sys.symbol.xmark_circle_fill'))
        .fontSize(18).fontColor([$r('sys.color.error')])
    } else if (status === 'in_progress' || status === 'running' || status === 'pending' || status === 'queued') {
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
