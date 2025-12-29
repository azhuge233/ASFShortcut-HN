import { formBindingData, FormExtensionAbility, formInfo, formProvider } from '@kit.FormKit';
import { Want } from '@kit.AbilityKit';

import Logger from '../common/utils/Logger';
import { DB } from '../common/utils/DB';
import { PM } from '../common/utils/PM';
import FormData from '../asfcommandwidget/model/FormData';
import CommonConstants from '../common/constants/CommonConstants';

export default class EntryFormAbility extends FormExtensionAbility {
    private LOG_TAG = '[EntryFormAbility]';

    private db: DB = DB.getInstance();
    private pm: PM = PM.getInstance();

    onAddForm(want: Want) {
        // Called to return a FormBindingData object.
        const formID = want?.parameters?.[formInfo.FormParam.IDENTITY_KEY] as string;

        Logger.debug(this.LOG_TAG, `onAddForm() formID: ${formID}`);

        return this.createFormBindingData(formID);
    }

    async onRemoveForm(formId: string) {
        // Called to notify the form provider that a specified form has been destroyed.
        Logger.debug(this.LOG_TAG, `onRemoveForm() formID: ${formId}`);

        await this.init();

        await this.unbindForm(formId);
    }

    async onUpdateForm(formId: string) {
        // Called to notify the form provider to update a specified form.
        Logger.debug(this.LOG_TAG, `${formId} onUpdateForm()`);

        this.init();

        try {
            const formData = await this.getFormDataByID(formId);

            if(formData) {
                Logger.debug(this.LOG_TAG, `onUpdateForm() 查询到 ID = ${formId} 的卡片 formData`);

                const formInfo = this.createFormBindingData(formData);
                await formProvider.updateForm(formId, formInfo);

                Logger.debug(this.LOG_TAG, `onUpdateForm() ID = ${formId} 的卡片已更新`);
            } else {
                Logger.warn(this.LOG_TAG, `onUpdateForm() ID = ${formId} 的卡片 formData 为空`);

                const formInfo = this.createFormBindingData(formId);
                await formProvider.updateForm(formId, formInfo);

                Logger.warn(this.LOG_TAG, `onUpdateForm() 已重置 ID = ${formId} 的卡片`);
            }
        } catch (err) {
            Logger.error(this.LOG_TAG, `${formId} onUpdateForm() 执行错误, ${err}`)
        }
    }

    async onFormEvent(formId: string, message: string) {
        // Called when a specified message event defined by the form provider is triggered.
        Logger.debug(this.LOG_TAG, `onFormEvent(), formID: ${formId}, message: ${message}`);

        // 卡片传参
        const messageObj: Record<string, Object> = JSON.parse(message);
        // action 参数
        const action = messageObj.formAction as string;

        await this.init();

        // 根据 action 执行：运行指令或更新卡片信息
        if(action === CommonConstants.FormMessage_Run) await this.handleRunAction(messageObj.data as string);
        else if(action === CommonConstants.FormMessage_Update) await this.handleUpdateAction(formId, messageObj.data as number);
        else Logger.warn(this.LOG_TAG, `onFormEvent() 未知指令: ${action}`);
    }

    onAcquireFormState(want: Want) {
        // Called to return a {@link FormState} object.
        const formID = want?.parameters?.[formInfo.FormParam.IDENTITY_KEY] as string;

        Logger.debug(this.LOG_TAG, `$onAcquireFormState() formID: ${formID}`);

        return formInfo.FormState.READY;
    }

    onCastToNormalForm(formId: string) {
        // Called when the form provider is notified that a temporary form is successfully
        // converted to a normal form.
        Logger.debug(this.LOG_TAG, `onCastToNormalForm() formID: ${formId}`);
    }

    private async init() {
        this.db.initDB(this.context);
        await this.pm.init(this.context);
    }

    private async unbindForm(formID: string) {
        const success = await this.pm.unbind(formID);
        if(success) Logger.debug(this.LOG_TAG, `unbindForm() 已删除卡片绑定: ${formID}`);
        else Logger.warn(this.LOG_TAG, `unbindForm() 删除卡片绑定失败: ${formID}`)
    }

    private createFormBindingData(data: string | FormData): formBindingData.FormBindingData {
        if(typeof(data) === "string") return this.createEmptyFormBindingData(data);
        else return formBindingData.createFormBindingData(data);
    }

    private createEmptyFormBindingData(formID: string): formBindingData.FormBindingData {
        const formData: FormData = new FormData(formID, false);

        return formBindingData.createFormBindingData(formData);
    }

    private async getFormDataByID(formID: string): Promise<FormData | null> {
        const formData = await this.pm.getFormDataByID(formID);

        Logger.debug(this.LOG_TAG, `getFormDataByID() ${formID} 查询结果: ${JSON.stringify(formData)}`);

        return formData;
    }

    private async handleUpdateAction(formID: string, shortcutID: number) {
        const commandEntry = await this.db.getCommandByID(shortcutID);

        if(commandEntry && commandEntry.accountInputRequired === 0 && commandEntry.idInputRequired === 0) {
            Logger.debug(this.LOG_TAG, `handleUpdateAction() 查询到指令 ID = ${shortcutID} 的 DB 条目`);

            const formData = new FormData(formID, true);
            formData.shortcutID = commandEntry.id;
            formData.nickname = commandEntry.nickname;
            formData.command = commandEntry.command;

            Logger.debug(this.LOG_TAG, `handleUpdateAction() 已更新 ID = ${formID} 的卡片`);
        } else {
            if(!commandEntry) Logger.warn(this.LOG_TAG, `handleUpdateAction() 指令 ID = ${shortcutID} 的条目为空`);
            else Logger.warn(this.LOG_TAG, `handleUpdateAction() 指令 ID = ${shortcutID} 的条目已更改为包含自定义输入`);

            const success = await this.pm.unbind(formID);

            if(success) Logger.warn(this.LOG_TAG, `handleUpdateAction() 已重置 ID = ${formID} 的卡片`)
            else Logger.warn(this.LOG_TAG, `handleUpdateAction()`)
        }

        this.onUpdateForm(formID);
    }

    private async handleRunAction(command: string) {
        Logger.debug(this.LOG_TAG, `handleRunAction() 准备执行指令: ${command}`);

        Logger.debug(this.LOG_TAG, `handleRunAction() ${command} 执行完毕`);
    }

    // /**
    //  * 打开指令选择页面
    //  */
    // private openCommandSelectionPage(formId: string): void {
    //     const want: Want = {
    //         bundleName: this.context.applicationInfo.name,
    //         abilityName: 'CommandSelectionAbility',
    //         parameters: {
    //             formId: formId
    //         }
    //     };
    //
    //     this.context.startAbility(want).then(() => {
    //         Logger.info(this.LOG_TAG, '成功跳转到指令选择页面');
    //     }).catch((err: Error) => {
    //         Logger.error(this.LOG_TAG, `跳转失败: ${err.message}`);
    //     });
    // }
    //
    // /**
    //  * 执行指令
    //  */
    // private async executeCommand(formId: string): Promise<void> {
    //     try {
    //         // 获取卡片绑定的指令ID
    //         const commandId = await this.preferencesManager.getCardCommandId(formId);
    //         if (!commandId) {
    //             this.showToast('卡片未绑定指令');
    //             return;
    //         }
    //
    //         // 从数据库获取指令详情
    //         const command = await this.getCommandById(commandId);
    //         if (!command) {
    //             this.showToast('指令不存在');
    //             await this.preferencesManager.unbindCard(formId);
    //             // 更新卡片状态
    //             this.updateCardState(formId, 'unbound');
    //             return;
    //         }
    //
    //         // 获取ASF设置
    //         const address = await this.db.getSetting('ASF_ADDRESS');
    //         const password = await this.db.getSetting('ASF_PASSWORD');
    //
    //         if (!address || !password) {
    //             this.showToast('请先在App中设置ASF服务器');
    //             return;
    //         }
    //
    //         // 发送指令到ASF
    //         this.showToast('执行中...');
    //         const result = await this.sendToASF(address, password, command.command);
    //
    //         // 显示结果（截断过长的字符串）
    //         const truncatedResult = result.length > 100 ? result.substring(0, 100) + '...' : result;
    //         this.showToast(truncatedResult);
    //
    //     } catch (err) {
    //         Logger.error(this.LOG_TAG, `执行指令失败: ${(err as Error).message}`);
    //         this.showToast('执行失败');
    //     }
    // }
    //
    // /**
    //  * 根据ID获取指令
    //  */
    // private async getCommandById(commandId: number): Promise<CommandEntry | null> {
    //     try {
    //         await this.db.waitForReady();
    //         const commandList = new CommandEntryList([]);
    //         await commandList.loadCommandEntries();
    //
    //         const command = commandList.commandEntries.find(entry => entry.id === commandId);
    //         return command || null;
    //     } catch (err) {
    //         Logger.error(this.LOG_TAG, `获取指令失败: ${(err as Error).message}`);
    //         return null;
    //     }
    // }
    //
    // /**
    //  * 发送指令到ASF服务器
    //  */
    // private async sendToASF(address: string, password: string, command: string): Promise<string> {
    //     return new Promise((resolve, reject) => {
    //         const httpRequest = http.createHttp();
    //         const url = `${address}/Api/Command`;
    //
    //         httpRequest.request(
    //             url,
    //             {
    //                 method: http.RequestMethod.POST,
    //                 header: {
    //                     'Content-Type': 'application/json',
    //                     'Authentication': password
    //                 },
    //                 extraData: JSON.stringify({
    //                     Command: command
    //                 })
    //             },
    //             (err, data) => {
    //                 if (err) {
    //                     reject(new Error(`HTTP请求失败: ${err.message}`));
    //                     return;
    //                 }
    //
    //                 if (data.responseCode === 200) {
    //                     try {
    //                         const result = JSON.parse(data.result as string);
    //                         resolve(result.Result || '执行成功');
    //                     } catch {
    //                         resolve('执行成功');
    //                     }
    //                 } else {
    //                     reject(new Error(`ASF返回错误: ${data.responseCode}`));
    //                 }
    //
    //                 httpRequest.destroy();
    //             }
    //         );
    //     });
    // }
    //
    // /**
    //  * 显示Toast
    //  */
    // private showToast(message: string): void {
    //     prompt.showToast({
    //         message: message,
    //         duration: 3000,
    //         bottom: 200
    //     });
    // }
    //
    // /**
    //  * 更新卡片状态
    //  */
    // private updateCardState(formId: string, status: string): void {
    //     const formProvider = formBindingData.FormBindingData;
    //     // 这里需要调用FormManager更新卡片，简化实现
    //     Logger.info(this.LOG_TAG, `需要更新卡片状态: ${formId}, status: ${status}`);
    // }
}