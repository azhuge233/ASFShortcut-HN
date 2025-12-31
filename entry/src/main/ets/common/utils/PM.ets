import preferences from '@ohos.data.preferences';
import { deviceInfo } from '@kit.BasicServicesKit';

import Logger from './Logger';
import FormData from '../../asfcommandwidget/model/FormData';
import CommandEntry from '../../model/CommandEntry';

export class PM {
    private LOG_TAG = '[PM]';

    private static instance: PM | null = null;
    private dataPreferences: preferences.Preferences | null = null;

    private readonly PREFERENCES_NAME = 'ASFS_Forms_Preferences';

    private readonly isGSKVSupported = deviceInfo.sdkApiVersion >= 18 && preferences.isStorageTypeSupported(preferences.StorageType.GSKV);

    private constructor() {}

    public static getInstance(): PM {
        if (!PM.instance) PM.instance = new PM();
        return PM.instance;
    }

    async init(context: Context): Promise<void> {
        try {
            let options: preferences.Options = {
                name: this.PREFERENCES_NAME,
                storageType: this.isGSKVSupported ? preferences.StorageType.GSKV : preferences.StorageType.XML
            }

            this.dataPreferences = await preferences.getPreferences(context, options);
        } catch (err) {
            Logger.error(this.LOG_TAG, `初始化失败, ${err}`);
        }
    }

    async bind(formId: string, formData: FormData): Promise<boolean> {
        if (!this.dataPreferences) return false;

        try {
            const formDataStr = JSON.stringify(formData);
            await this.dataPreferences.put(formId, formDataStr);
            if(!this.isGSKVSupported) await this.dataPreferences.flush();
            return true;
        } catch (err) {
            Logger.error(this.LOG_TAG, `绑定卡片失败, ${err}`);
            return false;
        }
    }

    async unbind(formId: string): Promise<boolean> {
        if (!this.dataPreferences) return false;

        try {
            const formDataStr = await this.dataPreferences.get(formId, '') as string;

            if (formDataStr !== '') {
                await this.dataPreferences.delete(formId);
                if(!this.isGSKVSupported) await this.dataPreferences.flush();
            } else Logger.warn(this.LOG_TAG, `${formId} 不存在`);

            return true;
        } catch (err) {
            Logger.error(this.LOG_TAG, `解除绑定失败, ${err}`);
            return false;
        }
    }

    async getFormDataByID(formId: string): Promise<FormData | null> {
        if (!this.dataPreferences) return null;

        try {
            const formDataStr = await this.dataPreferences.get(formId, '') as string;

            if(formDataStr !== '') {
                const formData: FormData = JSON.parse(formDataStr);
                return formData;
            } else return null;
        } catch (err) {
            Logger.error(this.LOG_TAG, `获取绑定失败, ${err}`);
            return null;
        }
    }

    async getAllCardBindings(): Promise<Array<FormData>> {
        if (!this.dataPreferences) return [];

        try {
            const formDataMap = (await this.dataPreferences.getAll() ?? {}) as Record<string, string>;
            const keys = Object.keys(formDataMap);

            return keys.map(key => JSON.parse(formDataMap[key]) as FormData);
        } catch (err) {
            Logger.error(this.LOG_TAG, `获取所有绑定失败, ${err}`);
            return [];
        }
    }

    async updateByShortcut(commandEntry: CommandEntry): Promise<string[]> {
        if (!this.dataPreferences) return [];

        try {
            const formDataArr = await this.getAllCardBindings();

            let updatedFormIDs: string[] = [];

            // 更新所有绑定该指令的卡片，统计受影响的 formID
            formDataArr.forEach(async formData => {
                if(formData.shortcutID === commandEntry.id) {
                    updatedFormIDs.push(formData.formID);

                    formData.nickname = commandEntry.nickname;
                    formData.command = commandEntry.command;

                    await this.bind(formData.formID, formData);
                }
            });

            return updatedFormIDs;
        } catch (err) {
            Logger.error(this.LOG_TAG, `更新指令绑定失败, ${err}`);
            return [];
        }
    }

    async removeBindingsByShortcutId(shortcutID: number): Promise<string[]> {
        if (!this.dataPreferences) return [];

        try {
            const formDataArr = await this.getAllCardBindings();

            let removedFormIDs: string[] = [];

            // 删除所有绑定该指令的卡片，统计受影响的 formID
            formDataArr.forEach(async formData => {
                if(formData.shortcutID === shortcutID) {
                    removedFormIDs.push(formData.formID);
                    await this.unbind(formData.formID);
                }
            });

            return removedFormIDs;
        } catch (err) {
            Logger.error(this.LOG_TAG, `删除指令绑定失败, ${err}`);
            return [];
        }
    }

    async clearAllBindings(): Promise<boolean> {
        if (!this.dataPreferences) return false;

        try {
            await this.dataPreferences.clear();
            if(!this.isGSKVSupported) await this.dataPreferences.flush();
            return true;
        } catch (err) {
            Logger.error(this.LOG_TAG, `清空绑定失败, ${err}`);
            return false;
        }
    }
}