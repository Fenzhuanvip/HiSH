import { gitCodeApi, GitCodePull, GitCodeLabel } from '../../lib/huaweicloud/GitCodeApi';

/**
 * PR 列表 Tab —— GitCode（atomgit）Pull Requests
 * 显示选中仓库的 Pull Request 列表
 */
@Component
export struct PrList {
  @State pulls: GitCodePull[] = []
  @State loading: boolean = true
  @State errorMsg: string = ''
  @Prop repoOwner: string
  @Prop repoName: string

  aboutToAppear(): void {
    this.loadPulls()
  }

  private async loadPulls(): Promise<void> {
    if (this.repoOwner.length === 0 || this.repoName.length === 0) {
      this.loading = false
      return
    }
    this.loading = true
    this.errorMsg = ''
    const resp = await gitCodeApi.listPulls(this.repoOwner, this.repoName, 'all')
    this.loading = false
    if (resp.ok && resp.data) {
      this.pulls = resp.data
    } else {
      this.errorMsg = resp.message || `加载失败 (${resp.statusCode})`
    }
  }

  build() {
    Column() {
      if (this.loading) {
        Column() {
          LoadingProgress().width(36).height(36).color('#3B82F6')
          Text('加载 PR...').fontSize(13).fontColor('#94A3B8').margin({ top: 12 })
        }.justifyContent(FlexAlign.Center).width('100%').layoutWeight(1)
      } else if (this.errorMsg.length > 0) {
        Column() {
          SymbolGlyph($r('sys.symbol.exclamationmark_circle'))
            .fontSize(36).fontColor(['#EF4444']).margin({ bottom: 12 })
          Text(this.errorMsg).fontSize(12).fontColor('#64748B').textAlign(TextAlign.Center)
            .margin({ left: 24, right: 24 })
          Button('重试').margin({ top: 16 }).type(ButtonType.Capsule)
            .backgroundColor('#3B82F6').fontColor('#FFFFFF')
            .onClick(() => this.loadPulls())
        }.justifyContent(FlexAlign.Center).width('100%').layoutWeight(1)
      } else if (this.pulls.length === 0) {
        Column() {
          SymbolGlyph($r('sys.symbol.checkmark_circle'))
            .fontSize(36).fontColor(['#94A3B8']).margin({ bottom: 12 })
          Text('暂无 Pull Request').fontSize(13).fontColor('#94A3B8')
        }.justifyContent(FlexAlign.Center).width('100%').layoutWeight(1)
      } else {
        List({ space: 10 }) {
          ForEach(this.pulls, (pr: GitCodePull) => {
            ListItem() {
              this.buildPrCard(pr)
            }
          }, (pr: GitCodePull) => pr.id.toString())
        }
        .width('100%').layoutWeight(1)
        .padding({ left: 14, right: 14, top: 12, bottom: 12 })
        .scrollBar(BarState.Off)
      }
    }
    .width('100%').height('100%')
    .backgroundColor('#F1F5F9')
  }

  @Builder
  buildPrCard(pr: GitCodePull) {
    Row() {
      // 状态色条
      Column()
        .width(4).height('100%')
        .backgroundColor(this.prColor(pr))
        .borderRadius({ topLeft: 2, bottomLeft: 2 })

      Column() {
        // PR 编号 + 标题
        Row() {
          Text(`#${pr.number}`)
            .fontSize(11).fontColor('#3B82F6').fontWeight(FontWeight.Medium)
            .margin({ right: 6 })
          Text(pr.title)
            .fontSize(14).fontColor('#1E293B').fontWeight(FontWeight.Medium)
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
        }.width('100%')

        // 状态标签 + 分支
        Row() {
          Text(this.prStateText(pr))
            .fontSize(9).fontColor('#FFFFFF')
            .backgroundColor(this.prColor(pr))
            .borderRadius(3)
            .padding({ left: 5, right: 5, top: 2, bottom: 2 })
            .margin({ right: 8 })
          Text(`${pr.head.ref} → ${pr.base.ref}`)
            .fontSize(10).fontColor('#64748B')
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          Blank()
          Text(this.formatTime(pr.updated_at)).fontSize(10).fontColor('#94A3B8')
        }.width('100%').margin({ top: 6 })

        // 标签
        if (pr.labels && pr.labels.length > 0) {
          Row() {
            ForEach(pr.labels.slice(0, 3), (label: GitCodeLabel) => {
              Text(label.name).fontSize(9).fontColor('#FFFFFF')
                .backgroundColor(`#${label.color}`)
                .borderRadius(3)
                .padding({ left: 4, right: 4, top: 1, bottom: 1 })
                .margin({ right: 4 })
            })
          }.width('100%').margin({ top: 6 })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .padding({ left: 12, right: 12, top: 12, bottom: 12 })
    }
    .width('100%')
    .backgroundColor('#FFFFFF')
    .borderRadius(10)
    .shadow({ radius: 2, color: '#0F172A0A', offsetX: 0, offsetY: 1 })
  }

  private prStateText(pr: GitCodePull): string {
    if (pr.merged) return '已合并'
    if (pr.state === 'closed') return '已关闭'
    return '开启'
  }

  private prColor(pr: GitCodePull): string {
    if (pr.merged) return '#8B5CF6'
    if (pr.state === 'closed') return '#EF4444'
    return '#22C55E'
  }

  private formatTime(iso: string): string {
    if (!iso || iso.length === 0) return ''
    return iso.substring(0, 10)
  }
}
