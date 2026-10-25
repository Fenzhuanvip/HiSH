import appOption from '../model/appOption';
import { CodeArtsWeb } from './codearts/CodeArtsWeb';
import { CodeArtsColor } from './codearts/CodeArtsTheme';
import { ImmersiveButtonModifier } from '../lib/immersiveButton';

/**
 * 云码道全屏覆盖层：打开时全屏 WebView（与终端全屏风格一致），关闭即回终端。
 * - 收起用 Visibility.None：不渲染、不参与触摸命中，绝不遮挡终端；
 * - 组件实例保留，WebView 不销毁，再次打开不重载网页；
 * - 入口为虚拟键栏云码道按钮（点击切换开合）；右上角悬浮小 X 长按可关闭（避免误触）。
 */
@Component
export struct CodeArtsDrawer {
  @StorageLink(appOption.codeartsDrawerOpen) open: boolean = false
  immersiveButton: ImmersiveButtonModifier = new ImmersiveButtonModifier()

  build() {
    Stack({ alignContent: Alignment.TopEnd }) {
      CodeArtsWeb()
        .width('100%').height('100%')

      // 关闭按钮：只保留一个 ×，不圆圈包裹；长按 500ms 才关闭，短按无反应，避免误触
      Button({ buttonStyle: ButtonStyleMode.TEXTUAL }) {
        SymbolGlyph($r('sys.symbol.xmark'))
          .fontSize(16)
          .fontColor([CodeArtsColor.textSub])
      }
      .width(20).height(20)
      .margin({ top: 10, right: 10 })
      .attributeModifier(this.immersiveButton)
      .gesture(
        LongPressGesture({ duration: 500 })
          .onAction(() => { this.open = false })
      )
    }
    .width('100%')
    .height('100%')
    .backgroundColor(CodeArtsColor.bg)
    .visibility(this.open ? Visibility.Visible : Visibility.None)
  }
}
