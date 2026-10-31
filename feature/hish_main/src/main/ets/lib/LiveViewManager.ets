import { notificationManager } from '@kit.NotificationKit'
import { hilog } from '@kit.PerformanceAnalysisKit'

const TAG = '[LiveViewManager]'
const LIVE_VIEW_ID = 9527

/**
 * 通知管理器：在锁屏/通知栏显示 VM 运行状态
 * 使用普通通知 (NOTIFICATION_CONTENT_BASIC_TEXT) 替代实况窗
 */
export class LiveViewManager {
  private static active = false

  /** VM 启动时创建通知 */
  static async create(): Promise<void> {
    try {
      const request: notificationManager.NotificationRequest = {
        id: LIVE_VIEW_ID,
        content: {
          notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
          normal: {
            title: 'HiSH',
            text: 'VM 运行中',
            additionalText: '正在启动...',
          }
        }
      }
      await notificationManager.publish(request)
      LiveViewManager.active = true
      hilog.info(1, TAG, 'Notification created')
    } catch (e) {
      hilog.error(1, TAG, `create failed: ${JSON.stringify(e)}`)
    }
  }

  /** 定期更新通知内容（CPU/内存） */
  static async update(cpuUsage: number, memUsage: number, memTotalKB: number): Promise<void> {
    if (!LiveViewManager.active) return
    try {
      const memTotalMB = Math.round(memTotalKB / 1024)
      const memUsedMB = Math.round(memTotalKB * memUsage / 100 / 1024)
      const request: notificationManager.NotificationRequest = {
        id: LIVE_VIEW_ID,
        content: {
          notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
          normal: {
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

  /** VM 停止或应用销毁时移除通知 */
  static async remove(): Promise<void> {
    if (!LiveViewManager.active) return
    try {
      await notificationManager.cancel(LIVE_VIEW_ID)
      LiveViewManager.active = false
      hilog.info(1, TAG, 'Notification removed')
    } catch (e) {
      hilog.error(1, TAG, `remove failed: ${JSON.stringify(e)}`)
    }
  }

  static isActive(): boolean {
    return LiveViewManager.active
  }
}
