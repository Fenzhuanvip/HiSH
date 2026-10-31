import { notificationManager } from '@kit.NotificationKit'
import { hilog } from '@kit.PerformanceAnalysisKit'

const TAG = '[LiveViewManager]'
const LIVE_VIEW_ID = 9527

/**
 * 实况窗管理器：在锁屏/熄屏显示 VM 运行状态
 * 基于 HarmonyOS NEXT 通知系统的实况窗能力 (NOTIFICATION_CONTENT_LIVE_VIEW)
 */
export class LiveViewManager {
  private static active = false

  /** VM 启动时创建实况窗 */
  static async create(): Promise<void> {
    try {
      const request: notificationManager.NotificationRequest = {
        id: LIVE_VIEW_ID,
        content: {
          notificationContentType: notificationManager.NotificationContentType.NOTIFICATION_CONTENT_LIVE_VIEW,
          liveViewContent: {
            title: 'HiSH',
            text: 'VM 运行中',
            additionalText: '正在启动...',
          }
        }
      }
      await notificationManager.publish(request)
      LiveViewManager.active = true
      hilog.info(1, TAG, 'Live view created')
    } catch (e) {
      hilog.error(1, TAG, `create failed: ${JSON.stringify(e)}`)
    }
  }

  /** 定期更新实况窗内容（CPU/内存） */
  static async update(cpuUsage: number, memUsage: number, memTotalKB: number): Promise<void> {
    if (!LiveViewManager.active) return
    try {
      const memTotalMB = Math.round(memTotalKB / 1024)
      const memUsedMB = Math.round(memTotalKB * memUsage / 100 / 1024)
      const request: notificationManager.NotificationRequest = {
        id: LIVE_VIEW_ID,
        content: {
          notificationContentType: notificationManager.NotificationContentType.NOTIFICATION_CONTENT_LIVE_VIEW,
          liveViewContent: {
            title: 'HiSH',
            text: `CPU ${cpuUsage}%  内存 ${memUsage}%`,
            additionalText: `VM 运行中 · ${memUsedMB}MB/${memTotalMB}MB`,
          }
        }
      }
      await notificationManager.publish(request)
    } catch (e) {
      hilog.error(1, TAG, `update failed: ${JSON.stringify(e)}`)
    }
  }

  /** VM 停止或应用销毁时移除实况窗 */
  static async remove(): Promise<void> {
    if (!LiveViewManager.active) return
    try {
      await notificationManager.cancel(LIVE_VIEW_ID)
      LiveViewManager.active = false
      hilog.info(1, TAG, 'Live view removed')
    } catch (e) {
      hilog.error(1, TAG, `remove failed: ${JSON.stringify(e)}`)
    }
  }

  static isActive(): boolean {
    return LiveViewManager.active
  }
}
