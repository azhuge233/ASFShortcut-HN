import { formBindingData, formProvider } from '@kit.FormKit';

import Logger from '../../common/utils/Logger';
import MultipleCommandsFormData from '../../domain/model/MultipleCommandsFormData';
import SingleCommandFormData from '../../domain/model/SingleCommandFormData';

const LOG_TAG: string = '[FormPublisher]';

/**
 * 卡片数据写出的落点：`formProvider.updateForm` 与失败重试在这里，`FormBindingData` 的构造也只在这里
 * （`domain/` 禁 `@kit.FormKit`，见设计 §1.5 规则 1）。
 *
 * B2 的调用面：两个运行 Ability 走 `publish`（失败重试一次，与 1.7.1 的 `updateFormWithRetry` 一致）；
 * 两个 FormAbility、两个编辑页与 `CommandEntryListViewModel` 仍直调 `formProvider.updateForm`、不重试——
 * 给它们加重试是第七项行为变更，父代理已裁定 B2 不碰这条链。B3 改走 `publish` 时一并处理重试口径。
 */
export class FormPublisher {
    private static instance: FormPublisher | null = null;

    private constructor() {
    }

    public static getInstance(): FormPublisher {
        if (!FormPublisher.instance) FormPublisher.instance = new FormPublisher();
        return FormPublisher.instance;
    }

    /**
     * 写入卡片数据：失败重试一次，两次都记日志。
     * `data` 的类型决定空卡与卡片类型差异之外的一切——转换与写入都在本方法内完成。
     */
    async publish(formID: string, data: SingleCommandFormData | MultipleCommandsFormData): Promise<boolean> {
        const formInfo: formBindingData.FormBindingData = data instanceof SingleCommandFormData
            ? this.createSingleCommandFormBindingData(data)
            : this.createMultipleCommandFormBindingData(data);

        return this.updateForm(formID, formInfo);
    }

    // 根据 data 类型创建 FormBindingData；字符串按该类型的空卡处理
    createSingleCommandFormBindingData(data: string | SingleCommandFormData): formBindingData.FormBindingData {
        if (typeof (data) === "string") {
            return formBindingData.createFormBindingData(new SingleCommandFormData(data, false));
        }
        return formBindingData.createFormBindingData(data);
    }

    createMultipleCommandFormBindingData(data: string | MultipleCommandsFormData): formBindingData.FormBindingData {
        if (typeof (data) === "string") {
            return formBindingData.createFormBindingData(new MultipleCommandsFormData(data, false));
        }
        return formBindingData.createFormBindingData(data);
    }

    // 唯一的卡片写入入口：updateForm 失败重试一次，两次都记日志
    private async updateForm(formID: string, formInfo: formBindingData.FormBindingData): Promise<boolean> {
        try {
            await formProvider.updateForm(formID, formInfo);
            return true;
        } catch (err) {
            Logger.error(LOG_TAG, `publish() 首次写入失败，重试一次, ${formID}, ${err}`);
        }

        try {
            await formProvider.updateForm(formID, formInfo);
            return true;
        } catch (err) {
            Logger.error(LOG_TAG, `publish() 重试仍失败, ${formID}, ${err}`);
            return false;
        }
    }
}
