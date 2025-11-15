import { deviceInfo, BusinessError } from '@kit.BasicServicesKit';
import { promptAction } from '@kit.ArkUI';
import { PromptAction } from '@ohos.arkui.UIContext';

import Logger from './Logger';


class CommonUtils {
    private LOG_TAG = "[CommonUtils]";

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
}

export default new CommonUtils();