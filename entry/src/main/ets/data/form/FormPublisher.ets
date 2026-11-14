import { formBindingData, formProvider } from '@kit.FormKit';

import Logger from '../../common/utils/Logger';
import MultipleCommandsFormData from '../../domain/model/MultipleCommandsFormData';
import SingleCommandFormData from '../../domain/model/SingleCommandFormData';
import { CardPublisher } from '../../domain/repository/CardPublisher';

const LOG_TAG: string = '[FormPublisher]';

/**
 * 卡片数据写出的落点：`formProvider.updateForm` 只在这里调用，`FormBindingData` 的构造也只在这里
 * （`domain/` 禁 `@kit.FormKit`，见设计 §1.5 规则 1）。
 *
 * 两个入口按调用点的既有行为分开，不重试的口径不许被顺手统一（设计 §2.2）：
 * - `publish`：写一次，失败即返回 false。页面、VM、两个 FormAbility、两个编辑页走这条——
 *   它们在 1.7.1 都是直调 `formProvider.updateForm`、不重试。
 * - `publishWithRetry`：写一次，失败重试一次。两个运行 Ability 走这条——
 *   1.7.1 的 `updateFormWithRetry` 就是这个行为。
 * B2 期本类只有一个带重试的 `publish`；B3 按调用点拆分，两个运行 Ability 的 8 处改调 `publishWithRetry`。
 */
export class FormPublisher implements CardPublisher {
    private static instance: FormPublisher | null = null;

    private constructor() {
    }

    public static getInstance(): FormPublisher {
        if (!FormPublisher.instance) FormPublisher.instance = new FormPublisher();
        return FormPublisher.instance;
    }

    /**
     * 写入卡片数据，不重试（设计 §2.2）。`data` 为 `null` 表示写空卡。
     *
     * `null` 落成单指令卡的空形态：1.7.1 的 `createSingleCommandFormBindingData(formData ?? formID)`
     * 在绑定缺失时产出的正是 `new SingleCommandFormData(formID, false)`。
     * 多指令卡的空形态由调用方交 `new MultipleCommandsFormData(formID, false)` 表达——
     * 这张 `| null` 的形状认不出卡片类型，而空卡数据必须与卡片自己的模板同形，所以类型由调用方给。
     */
    async publish(formID: string, data: SingleCommandFormData | MultipleCommandsFormData | null): Promise<boolean> {
        const formInfo: formBindingData.FormBindingData = this.toFormBindingData(formID, data);
        return this.updateFormOnce(formID, formInfo, 'publish()');
    }

    /** 写入卡片数据，失败重试一次（两个运行 Ability 的既有行为，设计 §2.2） */
    async publishWithRetry(formID: string, data: SingleCommandFormData | MultipleCommandsFormData): Promise<boolean> {
        const formInfo: formBindingData.FormBindingData = this.toFormBindingData(formID, data);
        return this.updateFormWithRetry(formID, formInfo, 'publishWithRetry()');
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

    private toFormBindingData(formID: string,
        data: SingleCommandFormData | MultipleCommandsFormData | null): formBindingData.FormBindingData {
        if (data === null) return this.createSingleCommandFormBindingData(formID);
        return data instanceof SingleCommandFormData
            ? this.createSingleCommandFormBindingData(data)
            : this.createMultipleCommandFormBindingData(data);
    }

    // 写一次：成功 true；失败记日志并返回 false
    private async updateFormOnce(formID: string, formInfo: formBindingData.FormBindingData,
        caller: string): Promise<boolean> {
        try {
            await formProvider.updateForm(formID, formInfo);
            return true;
        } catch (err) {
            Logger.error(LOG_TAG, `${caller} 写入失败, ${formID}, ${err}`);
            return false;
        }
    }

    // 写一次，失败重试一次：两次都记日志
    private async updateFormWithRetry(formID: string, formInfo: formBindingData.FormBindingData,
        caller: string): Promise<boolean> {
        try {
            await formProvider.updateForm(formID, formInfo);
            return true;
        } catch (err) {
            Logger.error(LOG_TAG, `${caller} 首次写入失败，重试一次, ${formID}, ${err}`);
        }

        try {
            await formProvider.updateForm(formID, formInfo);
            return true;
        } catch (err) {
            Logger.error(LOG_TAG, `${caller} 重试仍失败, ${formID}, ${err}`);
            return false;
        }
    }
}
