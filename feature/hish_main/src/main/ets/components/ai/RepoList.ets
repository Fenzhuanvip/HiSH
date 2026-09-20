import { codeArtsApi, CodeArtsRepository } from '../../lib/huaweicloud/CodeArtsApi';

/**
 * 仓库列表 Tab —— 纯 CodeArts CodeHub
 * 列出 CodeArts 项目下关联的代码仓库
 */
@Component
export struct RepoList {
  @State repos: CodeArtsRepository[] = []
  @State loading: boolean = false
  @State errorMsg: string = ''
  onRepoSelected: (repo: CodeArtsRepository) => void = () => {}

  aboutToAppear(): void {
    this.loadRepos()
  }

  private async loadRepos(): Promise<void> {
    this.loading = true
    this.errorMsg = ''
    const resp = await codeArtsApi.listRepositories()
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
          LoadingProgress().width(32).height(32)
          Text('加载仓库...').fontSize(12).fontColor($r('sys.color.font_secondary')).margin({ top: 8 })
        }.justifyContent(FlexAlign.Center).width('100%').layoutWeight(1)
      } else if (this.errorMsg.length > 0) {
        Column() {
          Text(this.errorMsg).fontSize(12).fontColor($r('sys.color.font_secondary')).textAlign(TextAlign.Center)
            .margin({ left: 16, right: 16 })
          Button('重试').margin({ top: 12 }).onClick(() => this.loadRepos())
        }.justifyContent(FlexAlign.Center).width('100%').layoutWeight(1)
      } else if (this.repos.length === 0) {
        Column() {
          Text('CodeArts 项目下暂无关联仓库').fontSize(12).fontColor($r('sys.color.font_secondary'))
        }.justifyContent(FlexAlign.Center).width('100%').layoutWeight(1)
      } else {
        List({ space: 8 }) {
          ForEach(this.repos, (repo: CodeArtsRepository) => {
            ListItem() {
              this.buildRepoItem(repo)
            }
          }, (repo: CodeArtsRepository) => repo.id)
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 12, right: 12, top: 8, bottom: 8 })
        .divider({ strokeWidth: 0.5, color: $r('sys.color.comp_background_divider'), startMargin: 0, endMargin: 0 })
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  buildRepoItem(repo: CodeArtsRepository) {
    Row() {
      Column() {
        Row() {
          Text(repo.name)
            .fontSize(14)
            .fontColor($r('sys.color.font_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          if (repo.visibility === 'private') {
            Text('私有')
              .fontSize(10)
              .fontColor($r('sys.color.font_on_primary'))
              .backgroundColor($r('sys.color.warning'))
              .borderRadius(4)
              .padding({ left: 4, right: 4, top: 1, bottom: 1 })
              .margin({ left: 6 })
          }
        }
        .width('100%')
        if (repo.description.length > 0) {
          Text(repo.description)
            .fontSize(11)
            .fontColor($r('sys.color.font_secondary'))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: 4 })
            .width('100%')
        }
        Row() {
          Text(`★ ${repo.starCount}`).fontSize(10).fontColor($r('sys.color.font_secondary')).margin({ right: 12 })
          Text(`⑂ ${repo.forkCount}`).fontSize(10).fontColor($r('sys.color.font_secondary'))
          Blank()
          Text(repo.defaultBranch).fontSize(10).fontColor($r('sys.color.font_secondary'))
        }
        .width('100%')
        .margin({ top: 6 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(16)
        .fontColor([$r('sys.color.font_secondary')])
    }
    .width('100%')
    .padding(10)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(8)
    .onClick(() => {
      this.onRepoSelected(repo)
    })
  }
}
