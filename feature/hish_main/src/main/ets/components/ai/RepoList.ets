import { gitCodeApi, GitCodeRepo } from '../../lib/huaweicloud/GitCodeApi';
import { gitCodeClient } from '../../lib/huaweicloud/GitCodeClient';

/**
 * 仓库列表 Tab —— GitCode（atomgit）
 * 列出当前用户的所有仓库
 */
@Component
export struct RepoList {
  @State repos: GitCodeRepo[] = []
  @State loading: boolean = true
  @State errorMsg: string = ''
  onRepoSelected: (repo: GitCodeRepo) => void = () => {}

  aboutToAppear(): void {
    this.loadRepos()
  }

  private async loadRepos(): Promise<void> {
    this.loading = true
    this.errorMsg = ''
    const resp = await gitCodeApi.listRepos()
    this.loading = false
    if (resp.ok && resp.data) {
      this.repos = resp.data
    } else {
      this.errorMsg = resp.message || `加载失败 (${resp.statusCode})`
    }
  }

  build() {
    Column() {
      if (this.loading) {
        Column() {
          LoadingProgress().width(36).height(36).color('#3B82F6')
          Text('加载仓库...').fontSize(13).fontColor('#94A3B8').margin({ top: 12 })
        }.justifyContent(FlexAlign.Center).width('100%').layoutWeight(1)
      } else if (this.errorMsg.length > 0) {
        Column() {
          SymbolGlyph($r('sys.symbol.exclamationmark_circle'))
            .fontSize(36).fontColor(['#EF4444']).margin({ bottom: 12 })
          Text(this.errorMsg).fontSize(12).fontColor('#64748B').textAlign(TextAlign.Center)
            .margin({ left: 24, right: 24 })
          Button('重试').margin({ top: 16 }).type(ButtonType.Capsule)
            .backgroundColor('#3B82F6').fontColor('#FFFFFF')
            .onClick(() => this.loadRepos())
        }.justifyContent(FlexAlign.Center).width('100%').layoutWeight(1)
      } else if (this.repos.length === 0) {
        Column() {
          SymbolGlyph($r('sys.symbol.checkmark_circle'))
            .fontSize(36).fontColor(['#94A3B8']).margin({ bottom: 12 })
          Text('暂无仓库').fontSize(13).fontColor('#94A3B8')
        }.justifyContent(FlexAlign.Center).width('100%').layoutWeight(1)
      } else {
        List({ space: 10 }) {
          ForEach(this.repos, (repo: GitCodeRepo) => {
            ListItem() {
              this.buildRepoCard(repo)
            }
          }, (repo: GitCodeRepo) => repo.id.toString())
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
  buildRepoCard(repo: GitCodeRepo) {
    Row() {
      // 左侧色条
      Column()
        .width(4).height('100%')
        .backgroundColor(repo.private ? '#F59E0B' : '#3B82F6')
        .borderRadius({ topLeft: 2, bottomLeft: 2 })

      Column() {
        // 仓库名 + 私有标签
        Row() {
          Text(repo.name)
            .fontSize(15).fontColor('#1E293B').fontWeight(FontWeight.Medium)
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          if (repo.private) {
            Text('私有').fontSize(9).fontColor('#FFFFFF')
              .backgroundColor('#F59E0B').borderRadius(3)
              .padding({ left: 5, right: 5, top: 2, bottom: 2 })
              .margin({ left: 6 })
          }
        }.width('100%')

        // 描述
        if (repo.description && repo.description.length > 0) {
          Text(repo.description)
            .fontSize(11).fontColor('#64748B')
            .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: 4 }).width('100%')
        }

        // 底部统计
        Row() {
          if (repo.language && repo.language.length > 0) {
            Row() {
              Circle({ width: 6, height: 6 }).fill(this.langColor(repo.language))
              Text(repo.language).fontSize(10).fontColor('#64748B').margin({ left: 4 })
            }.margin({ right: 12 })
          }
          Text(`★ ${repo.stargazers_count}`).fontSize(10).fontColor('#94A3B8').margin({ right: 10 })
          Text(`⑂ ${repo.forks_count}`).fontSize(10).fontColor('#94A3B8').margin({ right: 10 })
          if (repo.open_issues_count > 0) {
            Text(`● ${repo.open_issues_count}`).fontSize(10).fontColor('#94A3B8')
          }
          Blank()
          Text(this.formatTime(repo.updated_at)).fontSize(10).fontColor('#94A3B8')
        }.width('100%').margin({ top: 8 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .padding({ left: 12, right: 12, top: 12, bottom: 12 })

      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(16).fontColor(['#CBD5E1'])
        .margin({ right: 12 })
    }
    .width('100%')
    .backgroundColor('#FFFFFF')
    .borderRadius(10)
    .shadow({ radius: 2, color: '#0F172A0A', offsetX: 0, offsetY: 1 })
    .onClick(() => this.onRepoSelected(repo))
  }

  private formatTime(iso: string): string {
    if (!iso || iso.length === 0) return ''
    return iso.substring(0, 10)
  }

  private langColor(lang: string): string {
    const colors: Record<string, string> = {
      'ArkTS': '#0080FF', 'TypeScript': '#3178C6', 'JavaScript': '#F1E05A',
      'Python': '#3572A5', 'Java': '#B07219', 'Go': '#00ADD8', 'Rust': '#DEA584',
      'C': '#555555', 'C++': '#F34B7D', 'HTML': '#E34C26', 'Vue': '#41B883',
    }
    return colors[lang] || '#94A3B8'
  }
}
