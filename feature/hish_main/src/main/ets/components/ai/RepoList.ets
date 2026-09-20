import { atomGitApi } from '../../lib/atomgit/AtomGitApi';
import { AtomGitRepo } from '../../lib/atomgit/types';

/**
 * 仓库列表 Tab
 */
@Component
export struct RepoList {
  @State repos: AtomGitRepo[] = []
  @State loading: boolean = false
  @State errorMsg: string = ''
  onRepoSelected: (repo: AtomGitRepo) => void = () => {}

  aboutToAppear(): void {
    this.loadRepos()
  }

  private async loadRepos(): Promise<void> {
    this.loading = true
    this.errorMsg = ''
    const resp = await atomGitApi.listRepos(1, 50)
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
          Button('重试').margin({ top: 12 }).onClick(() => this.loadRepos())
        }.justifyContent(FlexAlign.Center).width('100%').layoutWeight(1)
      } else {
        List({ space: 8 }) {
          ForEach(this.repos, (repo: AtomGitRepo) => {
            ListItem() {
              this.buildRepoItem(repo)
            }
          }, (repo: AtomGitRepo) => repo.full_name)
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
  buildRepoItem(repo: AtomGitRepo) {
    Row() {
      Column() {
        Row() {
          Text(repo.full_name)
            .fontSize(14)
            .fontColor($r('sys.color.font_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          if (repo.private) {
            Text('私有')
              .fontSize(10)
              .fontColor($r('sys.color.font_on_primary'))
              .backgroundColor($r('sys.color.warning'))
              .borderRadius(4)
              .padding({ left: 4, right: 4, top: 1, bottom: 1 })
              .margin({ left: 6 })
          }
          if (repo.fork) {
            Text('Fork')
              .fontSize(10)
              .fontColor($r('sys.color.font_secondary'))
              .border({ width: 0.5, color: $r('sys.color.font_secondary') })
              .borderRadius(4)
              .padding({ left: 4, right: 4, top: 1, bottom: 1 })
              .margin({ left: 6 })
          }
        }
        .width('100%')
        if (repo.description && repo.description.length > 0) {
          Text(repo.description)
            .fontSize(11)
            .fontColor($r('sys.color.font_secondary'))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: 4 })
            .width('100%')
        }
        Row() {
          if (repo.language && repo.language.length > 0) {
            Text(repo.language).fontSize(10).fontColor($r('sys.color.interactive_active')).margin({ right: 12 })
          }
          Text(`★ ${repo.stargazers_count}`).fontSize(10).fontColor($r('sys.color.font_secondary')).margin({ right: 12 })
          Text(`⑂ ${repo.forks_count}`).fontSize(10).fontColor($r('sys.color.font_secondary'))
          Blank()
          Text(repo.default_branch).fontSize(10).fontColor($r('sys.color.font_secondary'))
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
