import { hilog } from '@kit.PerformanceAnalysisKit'

const DOMAIN = 0x0000

/**
 * Button 沉浸光感修饰器（SDK 5.0.0(12) 空实现）。
 * uiMaterial 是 API 26+ 功能，低版本不适用。
 */
export class ImmersiveButtonModifier implements AttributeModifier<ButtonAttribute> {
  applyNormalAttribute(instance: ButtonAttribute): void {
    // SDK 5.0.0(12) 不支持 uiMaterial，空实现
  }
}

/**
 * Toggle(Button 型) 沉浸光感修饰器（SDK 5.0.0(12) 空实现）。
 */
export class ImmersiveToggleModifier implements AttributeModifier<ToggleAttribute> {
  applyNormalAttribute(instance: ToggleAttribute): void {
    // SDK 5.0.0(12) 不支持 uiMaterial，空实现
  }
}

/**
 * 主按钮（强调色）沉浸光感修饰器（SDK 5.0.0(12) 空实现）。
 */
export class ImmersivePrimaryButtonModifier implements AttributeModifier<ButtonAttribute> {
  applyNormalAttribute(instance: ButtonAttribute): void {
    // SDK 5.0.0(12) 不支持 uiMaterial，空实现
  }
}
