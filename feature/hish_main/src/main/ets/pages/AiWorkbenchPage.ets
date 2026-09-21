import { ComposeTitleBar } from '@kit.ArkUI'
import { AiWorkbench } from '../components/ai/AiWorkbench'

@Entry
@Component
export struct AiWorkbenchPage {
  build() {
    Column() {
      ComposeTitleBar({
        title: 'AI 工作台'
      })
      AiWorkbench()
        .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
  }
}
