import { deviceInfo, BusinessError } from '@kit.BasicServicesKit';
import { promptAction } from '@kit.ArkUI';
import { PromptAction } from '@ohos.arkui.UIContext';

import Logger from './Logger';


class CommonUtils {
    private LOG_TAG = "[CommonUtils]";

    // 按照 API 版本显示 Toast 提醒
    public alert(message: string | Resource, newerPromptAction: PromptAction) {
        if(deviceInfo.sdkApiVersion <= 17) {
            try {
                promptAction.showToast({
                    message: message
                });
            } catch (err) {
                Logger.error(this.LOG_TAG, `<alert API <= 17> 错误, ${err}`);
            }
        } else {
            newerPromptAction.openToast({
                message: message
            }).catch((err: BusinessError) => {
                Logger.error(this.LOG_TAG, `<alert API > 17> 错误, ${err}`);
            });
        }
    }

    // 从 NavDestination 由 pop() 返回时
    // 显示回调 popInfo
    public returnFromSubPage(popInfo: PopInfo): void {
        Logger.debug(this.LOG_TAG,
            `从 [${popInfo.info.name}] 页面返回, 携带参数: ${JSON.stringify(popInfo.result)}`);
    }
}

export default new CommonUtils();