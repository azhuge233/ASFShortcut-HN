import { BusinessError } from '@kit.BasicServicesKit';
import { PromptAction, UIContext } from '@ohos.arkui.UIContext';
import { common } from '@kit.AbilityKit';
import { vibrator } from '@kit.SensorServiceKit';

import Logger from '../../common/utils/Logger';

const LOG_TAG: string = '[PageContext]';

/**
 * 页面上下文相关动作：提示、子页返回日志、振动、关闭应用、读窗口参数。
 * 方法签名与行为与 1.7.1 一致（`readWindowParam` 是 B4 的一次性参数通道读取，见设计 §2.6）；
 * 落 `ui/common/` 是因为它们只对页面侧有意义，`domain/` 与 `data/` 不该 import `@kit.ArkUI`。
 */
class PageContext {
    // 按照 API 版本显示 Toast 提醒
    // `duration` 可选：不传就交给平台的默认时长（27 处调用点因此一行不动，C9 / D7）
    public alert(message: string | Resource, promptAction: PromptAction, duration?: number) {
        promptAction.openToast({
            message: message,
            duration: duration
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

    // 打开外部链接（「关于」页的开源地址）：与 `closeApplication` 同形，页面把宿主上下文交进来。
    // 失败（无浏览器 / 权限拒绝）不在这里吞掉：Promise 如实抛回调用页，由页面提示且不退出。
    public async openLink(link: string, context: common.UIAbilityContext): Promise<void> {
        await context.openLink(link);
    }

    // 读本窗口的参数：`loadContent` 第二参交付的 `LocalStorage`（设计 §2.6）
    // 通道只读不写：页面不写回参数，也不靠删键造“一次性”（那是写入）
    public readWindowParam(uiContext: UIContext, key: string): string {
        const storage: LocalStorage | undefined = uiContext.getSharedLocalStorage();

        if (!storage || !storage.has(key)) return '';

        const value: string | undefined = storage.get<string>(key);
        if (!value) return '';

        return value;
    }
}

export default new PageContext();
