import { Index as MainPage, appOption, codeArtsGoBack } from 'hish_main';

@Entry
@Component
struct Index {
  onBackPress(): boolean {
    const open = AppStorage.get<boolean>(appOption.codeartsDrawerOpen) ?? false
    if (!open) {
      return false
    }
    // 码道抽屉开着：先在网页历史里后退；没历史就关抽屉，不退出 app 回桌面
    if (codeArtsGoBack()) {
      return true
    }
    AppStorage.setOrCreate(appOption.codeartsDrawerOpen, false)
    return true
  }

  build() {
    Column() {
      MainPage()
    }.width('100%').height('100%')
  }
}
