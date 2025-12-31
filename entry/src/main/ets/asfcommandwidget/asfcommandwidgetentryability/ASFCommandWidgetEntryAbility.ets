import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { http } from '@kit.NetworkKit';
import { formProvider } from '@kit.FormKit';

import CommonUtils from '../../common/utils/CommonUtils';
import Logger from '../../common/utils/Logger';
import { ASF } from '../../common/utils/ASF';
import { DB } from '../../common/utils/DB';
import CommonConstants from '../../common/constants/CommonConstants';
import FormData from '../model/FormData';

export default class ASFCommandWidgetEntryAbility extends UIAbility {
    private LOG_TAG = "[ASFCommandWidgetEntryAbility]";

    private db = DB.getInstance();
    private asf = new ASF();

    private formID: string = '';
    private shortcutID: number = -1;
    private nickname: string = '';
    private command: string = '';

    // 如果UIAbility启动，在收到call事件后会触发onCreate生命周期回调
    async onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): Promise<void> {
        Logger.debug(this.LOG_TAG, `onCreate()`);

        // Logger.warn(this.LOG_TAG, JSON.stringify(want));

        await this.init();

        try {
            // 直接通过 want 获取 call 事件参数
            if (want.parameters && want.parameters.params) {
                const params: Record<string, Object> = JSON.parse(want.parameters.params as string);

                this.formID = params['formID'] as string;
                this.shortcutID = params['shortcutID'] as number;
                this.nickname = params['nickname'] as string;
                this.command = params['command'] as string;

                Logger.debug(this.LOG_TAG,
                    `onCreate() 从 call 事件获得参数: ${this.formID}, ${this.shortcutID}, ${this.nickname}, ${this.command}`);

                // 从数据库更新待执行的指令
                // 防止执行时卡片UI没有及时更新
                // 对比卡片指令与数据库指令，不一致时使用数据库指令
                await this.updateCommandFromDB();

                // 向卡片发送正在运行参数
                await this.sendFormRunning();

                const result = await this.runCommand();
                await this.showResult(result);
            } else Logger.warn(this.LOG_TAG, `onCreate() want 为空`);
        } catch (err) {
            Logger.error(this.LOG_TAG, `onCreate() 错误, ${err}`);
        } finally {
            CommonUtils.closeApplication(this.LOG_TAG, this.context);
        }
    }

    async onDestroy(): Promise<void> {
        Logger.debug(this.LOG_TAG, `onDestroy()`);
    }

    private async init() {
        this.db.initDB(this.context);

        const asfAddr = await this.db.getSetting(CommonConstants.DB_KEY_HostInfo_KEY_NAME_Address);
        const asfPwd = await this.db.getSetting(CommonConstants.DB_KEY_HostInfo_KEY_NAME_Password);

        this.asf.setAddress(asfAddr);
        this.asf.setASFPassword(asfPwd);
    }

    private getNewFormData(): FormData {
        const formData = new FormData(this.formID, true);

        formData.shortcutID = this.shortcutID;
        formData.nickname = this.nickname;
        formData.command = this.command;

        return formData;
    }

    private async sendFormRunning() {
        const formData = this.getNewFormData();
        formData.isRunning = true;

        const formInfo = CommonUtils.createFormBindingData(formData);
        try {
            await formProvider.updateForm(this.formID, formInfo);
        } catch (err) {
            Logger.error(this.LOG_TAG, `sendFormRunning() 失败, ${err}`);
        }
    }

    private async updateCommandFromDB(): Promise<void> {
        const commandEntry = await this.db.getCommandByID(this.shortcutID);
        if(commandEntry) {
            const dbCommand = commandEntry.command;
            if(dbCommand !== this.command) {
                Logger.warn(this.LOG_TAG, `DB 指令: ${commandEntry.command}, 卡片指令: ${this.command}, 不一致，使用 DB 指令`);
                this.command = commandEntry.command;
            }
        }
    }

    private async runCommand(): Promise<string> {
        Logger.debug(this.LOG_TAG, `runCommand() 执行指令: ${this.command}`);

        try {
            const response = await this.asf.send(this.command);

            return this.handleResponse(response);
        } catch (err) {
            Logger.error(this.LOG_TAG, `runCommand() 指令 ${this.command} 执行错误, ${err}`);
            return this.context.resourceManager.getStringSync($r("app.string.Form_Run_Failed_Message").id);
        }
    }

    private handleResponse(resp: http.HttpResponse | undefined): string {
        if (!resp) throw new Error(`空响应`);

        try {
            const result: Record<string, string> = JSON.parse(resp.result.toString());
            let toastMessage: string = '';

            if (resp.responseCode == 200) {
                Logger.debug(this.LOG_TAG, `${result["Result"]}`);
                toastMessage = result["Result"];
            } else {
                Logger.debug(this.LOG_TAG, `${result["Message"]}`);
                toastMessage = result["Message"];
            }

            return toastMessage;
        } catch (err) {
            Logger.error(this.LOG_TAG, `handleResponse() 错误`);
            throw err as Error;
        }
    }

    private async showResult(result: string): Promise<void> {
        try {
            const formData = this.getNewFormData();

            formData.runResult = result; // 显示执行结果
            formData.isRunning = false; // 取消卡片正在运行状态
            const formInfo = CommonUtils.createFormBindingData(formData);
            await formProvider.updateForm(this.formID, formInfo); // 更新

            // await formProvider.setFormNextRefreshTime(this.formID, 5);
            Logger.debug(this.LOG_TAG, `showResult() 已显示执行结果`);
        } catch (err) {
            Logger.error(this.LOG_TAG, `showResult() 错误, ${err as BusinessError}`);
        }
    }
}