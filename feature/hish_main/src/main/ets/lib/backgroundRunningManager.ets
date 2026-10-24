import { common, wantAgent } from '@kit.AbilityKit';
import { backgroundTaskManager } from "@kit.BackgroundTasksKit";
import { hilog } from "@kit.PerformanceAnalysisKit";

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
    context, backgroundTaskManager.BackgroundMode.TASK_KEEPING, wantAgentObj)
}

async function stopContinuousTask(context: common.UIAbilityContext) {
  await backgroundTaskManager.stopBackgroundRunning(context)
}

export class backgroundRunningManager {
  public static async startBackground(context: common.UIAbilityContext): Promise<boolean> {
    try {
      await startContinuousTask(context)
      return true
    } catch (e) {
      hilog.info(1, TAG, `startBackground failed: ${JSON.stringify(e)}`)
      return false
    }
  }

  public static async stopBackground(context: common.UIAbilityContext): Promise<boolean> {
    try {
      await stopContinuousTask(context)
      return true
    } catch (e) {
      hilog.info(1, TAG, `stopBackground failed: ${JSON.stringify(e)}`)
      return false
    }
  }
}