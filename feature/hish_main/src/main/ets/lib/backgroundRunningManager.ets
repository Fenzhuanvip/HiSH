import { abilityAccessCtrl, common, wantAgent } from '@kit.AbilityKit';
import { backgroundTaskManager } from "@kit.BackgroundTasksKit";
import { hilog } from "@kit.PerformanceAnalysisKit";
import { geoLocationManager } from '@kit.LocationKit';

const TAG = '[backgroundRunningManager]'

async function startContinuousTask(context: common.UIAbilityContext) {
  let wantAgentInfo: wantAgent.WantAgentInfo = {
    wants: [
      {
        bundleName: context.abilityInfo.bundleName,
        abilityName: context.abilityInfo.name
      }
    ],
    operationType: wantAgent.OperationType.START_ABILITY,
    requestCode: 0,
    wantAgentFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
  };
  const wantAgentObj = await wantAgent.getWantAgent(wantAgentInfo)
  await backgroundTaskManager.startBackgroundRunning(
    context, backgroundTaskManager.BackgroundMode.LOCATION, wantAgentObj)
}

async function stopContinuousTask(context: common.UIAbilityContext) {
  await backgroundTaskManager.stopBackgroundRunning(context)
}

export class backgroundRunningManager {
  public static async startBackground(context: common.UIAbilityContext): Promise<boolean> {
    try {
      const granted = await backgroundRunningManager.grantLocationPermission(context);
      if (granted) {
        // 使用低功耗定位策略，确保后台持续产生定位回调，避免系统判定任务空闲而回收
        geoLocationManager.on("locationChange", {
          interval: 30,
          locationScenario: geoLocationManager.PowerConsumptionScenario.LOW_POWER_CONSUMPTION
        }, () => {
        })
        await startContinuousTask(context)
        hilog.info(1, TAG, 'startBackground succeeded with LOW_POWER location scenario')
        return true
      }
      hilog.warn(1, TAG, 'startBackground skipped: location permission not granted')
      return false
    } catch (e) {
      hilog.error(1, TAG, `startBackground failed Cause:  ${JSON.stringify(e)}`);
      return false
    }
  }

  public static async grantLocationPermission(context: common.UIAbilityContext) {
    try {
      const atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
      // 同时请求粗略和精确定位权限，精确定位能产生更可靠的回调
      const result = await atManager.requestPermissionsFromUser(context,
        ['ohos.permission.APPROXIMATELY_LOCATION', 'ohos.permission.LOCATION']);
      const granted = result.authResults.every(r => r === 0)
      hilog.info(1, TAG, `grantLocationPermission result: ${JSON.stringify(result.authResults)}, granted: ${granted}`)
      return granted
    } catch (e) {
      hilog.error(1, TAG, `grantLocationPermission failed Cause:  ${JSON.stringify(e)}`);
      return false
    }
  }

  public static async stopBackground(context: common.UIAbilityContext): Promise<boolean> {
    try {
      geoLocationManager.off('locationChange')
      await stopContinuousTask(context)
      return true
    } catch (e) {
      hilog.error(1, TAG, `stopBackground failed Cause:  ${JSON.stringify(e)}`);
      return false
    }
  }
}