import { BusinessError } from '@kit.BasicServicesKit';
import { PromptAction } from '@ohos.arkui.UIContext';
import { common } from '@kit.AbilityKit';
import { vibrator } from '@kit.SensorServiceKit';

import Logger from '../../common/utils/Logger';

const LOG_TAG: string = '[PageContext]';

/**
 * 页面上下文相关动作：提示、子页返回日志、振动、关闭应用。
 * 四个方法签名与行为与 1.7.1 一致；
 * 落 `ui/common/` 是因为它们只对页面侧有意义，`domain/` 与 `data/` 不该 import `@kit.ArkUI`。
 */
class PageContext {
    // 按照 API 版本显示 Toast 提醒
    public alert(message: string | Resource, promptAction: PromptAction) {
        promptAction.openToast({
            message: message
        }).catch((err: BusinessError) => {
            Logger.error(LOG_TAG, `toast 提示错误, ${err}`);
        });
    }

    // 从 NavDestination 由 pop() 返回时
    // 显示回调 popInfo
    public returnFromSubPage(popInfo: PopInfo): void {
        Logger.debug(LOG_TAG,
            `从 [${popInfo.info.name}] 页面返回, 携带参数: ${JSON.stringify(popInfo.result)}`);
    }

    // 设备振动
    public vibrate(effectId: string) {
        try {
            vibrator.isSupportEffect(effectId, (err: BusinessError, state: boolean) => {
                if (err) {
                    Logger.error(LOG_TAG, `查询振动效果失败, 代码: ${err.code}, 错误信息: ${err.message}`);
                    return;
                }

                Logger.info(LOG_TAG, `设置支持 ${effectId} 振动`);

                if (state) {
                    try {
                        // 触发马达振动
                        vibrator.startVibration({
                            type: 'preset',
                            effectId: effectId,
                            count: 1,
                            intensity: 100,
                        }, {
                            usage: 'unknown'
                        }, (error: BusinessError) => {
                            if (error) Logger.error(LOG_TAG, `振动触发失败, 代码: ${error.code}, 错误信息: ${error.message}`);
                            else Logger.info(LOG_TAG, '成功触发振动');
                        });
                    } catch (error) {
                        Logger.error(LOG_TAG, `振动发生未知错误, ${error}`);
                    }
                }
            });
        } catch (error) {
            Logger.error(LOG_TAG, `振动发生未知错误, ${error}`);
        }
    }

    // 关闭应用
    public closeApplication(from: string, context: common.UIAbilityContext) {
        Logger.info(from, `关闭应用`);
        context.terminateSelf().catch((err: BusinessError) => {
            Logger.error(from, `关闭应用失败, ${err}`);
        });
    }
}

export default new PageContext();
