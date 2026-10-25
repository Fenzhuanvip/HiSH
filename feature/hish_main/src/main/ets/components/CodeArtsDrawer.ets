import appOption from '../model/appOption';
import { CodeArtsWeb } from './codearts/CodeArtsWeb';
import { CodeArtsColor } from './codearts/CodeArtsTheme';
import { ImmersiveButtonModifier } from '../lib/immersiveButton';

/**
 * 云码道全屏覆盖层：打开时全屏 WebView（与终端全屏风格一致），关闭即回终端。
 * - 收起用 Visibility.None：不渲染、不参与触摸命中，绝不遮挡终端；
 * - 组件实例保留，WebView 不销毁，再次打开不重载网页；
 * - 入口为虚拟键栏云码道按钮（点击切换开合）；右上角悬浮小 X 也可关闭。
 */
@Component
export struct CodeArtsDrawer {
  @StorageLink(appOption.codeartsDrawerOpen) open: boolean = false
  immersiveButton: ImmersiveButtonModifier = new ImmersiveButtonModifier()

  build() {
    Stack({ alignContent: Alignment.TopEnd }) {
      CodeArtsWeb()
        .width('100%').height('100%')

      Button({ buttonStyle: ButtonStyleMode.TEXTUAL }) {
        SymbolGlyph($r('sys.symbol.xmark'))
          .fontSize(14)
          .fontColor([CodeArtsColor.textSub])
      }
      .width(28).height(28)
      .margin({ top: 8, right: 8 })
      .backgroundColor('#1A1B2EB3')
      .borderRadius(14)
      .attributeModifier(this.immersiveButton)
      .onClick(() => { this.open = false })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(CodeArtsColor.bg)
    .visibility(this.open ? Visibility.Visible : Visibility.None)
  }
}