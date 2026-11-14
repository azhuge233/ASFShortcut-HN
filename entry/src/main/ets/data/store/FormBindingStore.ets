import { preferences } from '@kit.ArkData';
import { deviceInfo, BusinessError } from '@kit.BasicServicesKit';

import Logger from '../../common/utils/Logger';
import CommandEntry from '../../domain/model/CommandEntry';
import MultipleCommandsFormData from '../../domain/model/MultipleCommandsFormData';
import SingleCommandFormData from '../../domain/model/SingleCommandFormData';
import { FormBindingRepository } from '../../domain/repository/FormBindingRepository';

const LOG_TAG: string = '[FormBindingStore]';

/**
 * `ASFS_Forms_Preferences` 的读写：一张卡片一条记录，键是 formID。
 * 键格式与内容格式一字不动（升级安装必须能读旧绑定）。
 *
 * 失败语义照 1.7.1，只有一处加严：`unbind` / `removeByShortcutID` 在真正写失败时抛错，
 * 因为「删除指令先解绑、解绑失败则删除失败」（设计 §2.11 第一条）需要一个能区分
 * 「没有绑定」与「解绑失败」的信号——旧实现两者都返回空数组。
 */
export class FormBindingStore implements FormBindingRepository {
    private static instance: FormBindingStore | null = null;

    private initPromise: Promise<void> | null = null;

    private dataPreferences: preferences.Preferences | null = null;

    private readonly PREFERENCES_NAME = 'ASFS_Forms_Preferences';

    private readonly isGSKVSupported = deviceInfo.sdkApiVersion >= 18 && preferences.isStorageTypeSupported(preferences.StorageType.GSKV);

    private constructor() {
    }

    public static getInstance(): FormBindingStore {
        if (!FormBindingStore.instance) FormBindingStore.instance = new FormBindingStore();
        return FormBindingStore.instance;
    }

    init(context: Context): void {
        if (this.initPromise) return;

        this.initPromise = new Promise((resolve) => {
            let options: preferences.Options = {
                name: this.PREFERENCES_NAME,
                storageType: this.isGSKVSupported ? preferences.StorageType.GSKV : preferences.StorageType.XML
            };

            preferences.getPreferences(context, options).then((preference) => {
                this.dataPreferences = preference;
                resolve();
            }).catch((err: BusinessError) => {
                Logger.error(LOG_TAG, `首选项初始化失败, ${err}`);
                this.initPromise = null; // 允许下次重试
                resolve(); // 即使失败也要 resolve，避免永久阻塞
            });
        });
    }

    async bindSingle(data: SingleCommandFormData): Promise<void> {
        await this.waitForReady();

        if (!this.dataPreferences) return;

        try {
            await this.dataPreferences.put(data.formID, JSON.stringify(data));
            if (!this.isGSKVSupported) await this.dataPreferences.flush();
        } catch (err) {
            Logger.error(LOG_TAG, `bindSingle() 绑定卡片失败, ${err}`);
        }
    }

    async bindMultiple(data: MultipleCommandsFormData): Promise<void> {
        await this.waitForReady();

        if (!this.dataPreferences) return;

        try {
            await this.dataPreferences.put(data.formID, JSON.stringify(data));
            if (!this.isGSKVSupported) await this.dataPreferences.flush();
        } catch (err) {
            Logger.error(LOG_TAG, `bindMultiple() 绑定卡片失败, ${err}`);
        }
    }

    async unbind(formID: string): Promise<void> {
        await this.waitForReady();

        if (!this.dataPreferences) throw new Error('首选项未初始化');

        try {
            const formDataStr = await this.dataPreferences.get(formID, '') as string;

            if (formDataStr !== '') {
                await this.dataPreferences.delete(formID);
                if (!this.isGSKVSupported) await this.dataPreferences.flush();
            } else Logger.warn(LOG_TAG, `${formID} 不存在`);
        } catch (err) {
            Logger.error(LOG_TAG, `unbind() 解除绑定失败, ${err}`);
            throw err as Error;
        }
    }

    async getSingle(formID: string): Promise<SingleCommandFormData | null> {
        await this.waitForReady();

        if (!this.dataPreferences) return null;

        try {
            const formDataStr = await this.dataPreferences.get(formID, '') as string;

            if (formDataStr !== '') return JSON.parse(formDataStr) as SingleCommandFormData;
            return null;
        } catch (err) {
            Logger.error(LOG_TAG, `getSingle() 获取绑定失败, ${err}`);
            return null;
        }
    }

    async getMultiple(formID: string): Promise<MultipleCommandsFormData | null> {
        await this.waitForReady();

        if (!this.dataPreferences) return null;

        try {
            const formDataStr = await this.dataPreferences.get(formID, '') as string;

            if (formDataStr !== '') return JSON.parse(formDataStr) as MultipleCommandsFormData;
            return null;
        } catch (err) {
            Logger.error(LOG_TAG, `getMultiple() 获取绑定失败, ${err}`);
            return null;
        }
    }

    async listSingle(): Promise<Array<[string, SingleCommandFormData]>> {
        await this.waitForReady();

        if (!this.dataPreferences) return [];

        try {
            const formDataMap = (await this.dataPreferences.getAll() ?? {}) as Record<string, string>;
            const keys = Object.keys(formDataMap);
            const result: Array<[string, SingleCommandFormData]> = [];

            for (const key of keys) {
                try {
                    const parsed = JSON.parse(formDataMap[key]) as Record<string, Object>;
                    if (!Array.isArray(parsed['commandList'])) {
                        result.push([key, JSON.parse(formDataMap[key]) as SingleCommandFormData]);
                    }
                } catch (err) {
                    Logger.warn(LOG_TAG, `跳过无法解析的卡片绑定: ${key}, ${err}`);
                }
            }

            return result;
        } catch (err) {
            Logger.error(LOG_TAG, `listSingle() 获取所有绑定失败, ${err}`);
            return [];
        }
    }

    async listMultiple(): Promise<Array<[string, MultipleCommandsFormData]>> {
        await this.waitForReady();

        if (!this.dataPreferences) return [];

        try {
            const formDataMap = (await this.dataPreferences.getAll() ?? {}) as Record<string, string>;
            const keys = Object.keys(formDataMap);
            const result: Array<[string, MultipleCommandsFormData]> = [];

            for (const key of keys) {
                try {
                    const parsed = JSON.parse(formDataMap[key]) as Record<string, Object>;
                    if (Array.isArray(parsed['commandList'])) {
                        result.push([key, JSON.parse(formDataMap[key]) as MultipleCommandsFormData]);
                    }
                } catch (err) {
                    Logger.warn(LOG_TAG, `跳过无法解析的卡片绑定: ${key}, ${err}`);
                }
            }

            return result;
        } catch (err) {
            Logger.error(LOG_TAG, `listMultiple() 获取所有绑定失败, ${err}`);
            return [];
        }
    }

    async updateByShortcut(entry: CommandEntry): Promise<string[]> {
        await this.waitForReady();

        if (!this.dataPreferences) return [];

        const updatedFormIDs: string[] = [];

        // 单指令卡片：整条绑定指向该条目
        const singleBindings = await this.listSingle();
        for (const pair of singleBindings) {
            const formData = pair[1];
            if (formData.shortcutID === entry.id) {
                updatedFormIDs.push(formData.formID);

                formData.nickname = entry.nickname;
                formData.command = entry.command;

                await this.bindSingle(formData);
            }
        }

        // 多指令卡片：命中列表里的某一项
        const multipleBindings = await this.listMultiple();
        for (const pair of multipleBindings) {
            const formData = pair[1];
            let needsUpdate: boolean = false;

            formData.commandList.forEach(shortcut => {
                if (shortcut.id === entry.id) {
                    needsUpdate = true;

                    shortcut.nickname = entry.nickname;
                    shortcut.command = entry.command;
                }
            });

            if (needsUpdate) {
                updatedFormIDs.push(formData.formID);
                await this.bindMultiple(formData);
            }
        }

        return updatedFormIDs;
    }

    async removeByShortcutID(shortcutID: number): Promise<string[]> {
        await this.waitForReady();

        if (!this.dataPreferences) throw new Error('首选项未初始化');

        const removedFormIDs: string[] = [];

        // 单指令卡片：整条绑定指向该条目，直接解除
        const singleBindings = await this.listSingle();
        for (const pair of singleBindings) {
            const formData = pair[1];
            if (formData.shortcutID === shortcutID) {
                removedFormIDs.push(formData.formID);
                await this.unbind(formData.formID);
            }
        }

        // 多指令卡片：从列表里摘掉该条目；列表空了就解除整张卡片
        const multipleBindings = await this.listMultiple();
        for (const pair of multipleBindings) {
            const formData = pair[1];
            const originalLength = formData.commandList.length;
            formData.commandList = formData.commandList.filter(shortcut => shortcut.id !== shortcutID);

            if (formData.commandList.length !== originalLength) {
                removedFormIDs.push(formData.formID);

                if (formData.commandList.length === 0) await this.unbind(formData.formID);
                else await this.bindMultiple(formData);
            }
        }

        return removedFormIDs;
    }

    async clearAll(): Promise<boolean> {
        await this.waitForReady();

        if (!this.dataPreferences) return false;

        try {
            await this.dataPreferences.clear();
            if (!this.isGSKVSupported) await this.dataPreferences.flush();
            return true;
        } catch (err) {
            Logger.error(LOG_TAG, `清空绑定失败, ${err}`);
            return false;
        }
    }

    private async waitForReady(): Promise<void> {
        if (!this.initPromise) throw new Error("首选项未初始化. 先调用 init()");
        await this.initPromise;
    }
}
