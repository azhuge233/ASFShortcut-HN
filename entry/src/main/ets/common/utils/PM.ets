import preferences from '@ohos.data.preferences';
import { deviceInfo } from '@kit.BasicServicesKit';

import Logger from './Logger';
import CommandEntry from '../../model/CommandEntry';
import SingleCommandFormData from '../../singlecommandwidget/model/SingleCommandFormData';
import MultipleCommandsFormData from '../../multiplecommandswidget/model/MultipleCommandsFormData';

export class PM {
    private LOG_TAG = '[PM]';

    private static instance: PM | null = null;

    private isInitialized: boolean = false; // 初始化标志
    private initPromise: Promise<void> | null = null;
    private resolveInit: (() => void) | null = null;

    private dataPreferences: preferences.Preferences | null = null;

    private readonly PREFERENCES_NAME = 'ASFS_Forms_Preferences';

    private readonly isGSKVSupported = deviceInfo.sdkApiVersion >= 18 && preferences.isStorageTypeSupported(preferences.StorageType.GSKV);

    private constructor() {}

    public static getInstance(): PM {
        if (!PM.instance) PM.instance = new PM();
        return PM.instance;
    }

    init(context: Context) {
        if(this.initPromise) return;

        this.initPromise = new Promise((resolve) => {
            this.resolveInit = resolve;

            let options: preferences.Options = {
                name: this.PREFERENCES_NAME,
                storageType: this.isGSKVSupported ? preferences.StorageType.GSKV : preferences.StorageType.XML
            }

            // 异步初始化
            preferences.getPreferences(context, options).then((preference) => {
                this.dataPreferences = preference;
                this.isInitialized = true;
                resolve(); // 解析Promise表示初始化完成
            }).catch((err: BusinessError) => {
                Logger.error(this.LOG_TAG, `首选项初始化失败, ${err}`);
                resolve(); // 即使失败也要resolve，避免永久阻塞
            });
        });
    }

    async bindSingle(formId: string, formData: SingleCommandFormData): Promise<boolean> {
        await this.waitForReady();

        if (!this.dataPreferences) return false;

        try {
            const formDataStr = JSON.stringify(formData);
            await this.dataPreferences.put(formId, formDataStr);
            if(!this.isGSKVSupported) await this.dataPreferences.flush();
            return true;
        } catch (err) {
            Logger.error(this.LOG_TAG, `bindSingle() 绑定卡片失败, ${err}`);
            return false;
        }
    }

    async unbind(formId: string): Promise<boolean> {
        await this.waitForReady();

        if (!this.dataPreferences) return false;

        try {
            const formDataStr = await this.dataPreferences.get(formId, '') as string;

            if (formDataStr !== '') {
                await this.dataPreferences.delete(formId);
                if(!this.isGSKVSupported) await this.dataPreferences.flush();
            } else Logger.warn(this.LOG_TAG, `${formId} 不存在`);

            return true;
        } catch (err) {
            Logger.error(this.LOG_TAG, `unbind() 解除绑定失败, ${err}`);
            return false;
        }
    }

    async getFormDataByIDSingle(formId: string): Promise<SingleCommandFormData | null> {
        await this.waitForReady();

        if (!this.dataPreferences) return null;

        try {
            const formDataStr = await this.dataPreferences.get(formId, '') as string;

            if(formDataStr !== '') {
                const formData: SingleCommandFormData = JSON.parse(formDataStr);
                return formData;
            } else return null;
        } catch (err) {
            Logger.error(this.LOG_TAG, `getFormDataByIDSingle() 获取绑定失败, ${err}`);
            return null;
        }
    }

    async getAllCardBindingsSingle(): Promise<Array<SingleCommandFormData>> {
        await this.waitForReady();

        if (!this.dataPreferences) return [];

        try {
            const formDataMap = (await this.dataPreferences.getAll() ?? {}) as Record<string, string>;
            let keys = Object.keys(formDataMap);
            keys = keys.filter(key => formDataMap[key].indexOf("commandList") === -1);

            return keys.map(key => JSON.parse(formDataMap[key]) as SingleCommandFormData);
        } catch (err) {
            Logger.error(this.LOG_TAG, `getAllCardBindingsSingle() 获取所有绑定失败, ${err}`);
            return [];
        }
    }

    async updateByShortcutSingle(commandEntry: CommandEntry): Promise<string[]> {
        await this.waitForReady();

        if (!this.dataPreferences) return [];

        try {
            const formDataArr = await this.getAllCardBindingsSingle();

            let updatedFormIDs: string[] = [];

            // 更新所有绑定该指令的卡片，统计受影响的 formID
            for(const formData of formDataArr) {
                if(formData.shortcutID === commandEntry.id) {
                    updatedFormIDs.push(formData.formID);

                    formData.nickname = commandEntry.nickname;
                    formData.command = commandEntry.command;

                    await this.bindSingle(formData.formID, formData);
                }
            }

            return updatedFormIDs;
        } catch (err) {
            Logger.error(this.LOG_TAG, `updateByShortcutSingle() 更新指令绑定失败, ${err}`);
            return [];
        }
    }

    async removeBindingsByShortcutIdSingle(shortcutID: number): Promise<string[]> {
        await this.waitForReady();

        if (!this.dataPreferences) return [];

        try {
            const formDataArr = await this.getAllCardBindingsSingle();

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
            Logger.error(this.LOG_TAG, `removeBindingsByShortcutIdSingle() 删除指令绑定失败, ${err}`);
            return [];
        }
    }

    async bindMultiple(formId: string, formData: MultipleCommandsFormData): Promise<boolean> {
        await this.waitForReady();

        if (!this.dataPreferences) return false;

        try {
            const formDataStr = JSON.stringify(formData);
            await this.dataPreferences.put(formId, formDataStr);
            if(!this.isGSKVSupported) await this.dataPreferences.flush();
            return true;
        } catch (err) {
            Logger.error(this.LOG_TAG, `bindMultiple() 绑定卡片失败, ${err}`);
            return false;
        }
    }

    async getFormDataByIDMultiple(formId: string): Promise<MultipleCommandsFormData | null> {
        await this.waitForReady();

        if (!this.dataPreferences) return null;

        try {
            const formDataStr = await this.dataPreferences.get(formId, '') as string;

            if(formDataStr !== '') {
                const formData: MultipleCommandsFormData = JSON.parse(formDataStr);
                return formData;
            } else return null;
        } catch (err) {
            Logger.error(this.LOG_TAG, `getFormDataByIDMultiple() 获取绑定失败, ${err}`);
            return null;
        }
    }

    async getAllCardBindingsMultiple(): Promise<Array<MultipleCommandsFormData>> {
        await this.waitForReady();

        if (!this.dataPreferences) return [];

        try {
            const formDataMap = (await this.dataPreferences.getAll() ?? {}) as Record<string, string>;
            let keys = Object.keys(formDataMap);
            keys = keys.filter(key => formDataMap[key].indexOf("commandList") !== -1);

            return keys.map(key => JSON.parse(formDataMap[key]) as MultipleCommandsFormData);
        } catch (err) {
            Logger.error(this.LOG_TAG, `getAllCardBindingsMultiple() 获取所有绑定失败, ${err}`);
            return [];
        }
    }

    async updateByShortcutMultiple(commandEntry: CommandEntry): Promise<string[]> {
        await this.waitForReady();

        if (!this.dataPreferences) return [];

        try {
            const formDataArr = await this.getAllCardBindingsMultiple();

            let updatedFormIDs: string[] = [];

            // 更新所有绑定该指令的卡片，统计受影响的 formID
            for(const formData of formDataArr) {
                let needsUpdate: boolean = false;

                formData.commandList.forEach(shortcut => {
                    if(shortcut.id === commandEntry.id) {
                        needsUpdate = true;

                        shortcut.nickname = commandEntry.nickname;
                        shortcut.command = commandEntry.command;
                    }
                });

                if(needsUpdate) {
                    updatedFormIDs.push(formData.formID);
                    await this.bindMultiple(formData.formID, formData);
                }
            }

            return updatedFormIDs;
        } catch (err) {
            Logger.error(this.LOG_TAG, `updateByShortcutMultiple() 更新指令绑定失败, ${err}`);
            return [];
        }
    }

    async removeBindingsByShortcutIdMultiple(shortcutID: number): Promise<string[]> {
        await this.waitForReady();

        if (!this.dataPreferences) return [];

        try {
            const formDataArr = await this.getAllCardBindingsMultiple();

            let affectedFormIDs: string[] = [];

            // 删除所有绑定该指令的卡片，统计受影响的 formID
            for(const formData of formDataArr) {
                // 过滤掉要删除的指令
                const originalLength = formData.commandList.length;
                formData.commandList = formData.commandList.filter(
                    shortcut => shortcut.id !== shortcutID
                );

                // 如果指令列表有变化
                if (formData.commandList.length !== originalLength) {
                    affectedFormIDs.push(formData.formID);

                    // 如果指令列表为空，删除整个卡片
                    if (formData.commandList.length === 0) await this.unbind(formData.formID);
                    else await this.bindMultiple(formData.formID, formData); // 否则更新卡片
                }
            }

            return affectedFormIDs;
        } catch (err) {
            Logger.error(this.LOG_TAG, `removeBindingsByShortcutIdMultiple() 删除指令绑定失败, ${err}`);
            return [];
        }
    }

    async clearAllBindings(): Promise<boolean> {
        await this.waitForReady();

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

    private async waitForReady(): Promise<void> {
        if (!this.initPromise) throw new Error("首选项未初始化. 先调用 init()");
        await this.initPromise;
    }
}