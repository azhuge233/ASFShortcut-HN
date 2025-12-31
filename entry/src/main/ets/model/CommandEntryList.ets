import CommandEntry from "./CommandEntry";
import Logger from '../common/utils/Logger';
import { DB } from "../common/utils/DB"
import { PM } from "../common/utils/PM";

export default class CommandEntryList {
    commandEntries: Array<CommandEntry> = [];

    private LOG_TAG = "[Model/CommandEntryList]";

    private db = DB.getInstance();
    private pm = PM.getInstance();

    constructor(commandEntries: Array<CommandEntry>) {
        this.commandEntries = commandEntries;
    }

    async loadCommandEntries(): Promise<void> {
        await this.db.waitForReady();
        try {
            let result = await this.db.getCommandList();
            if(result === undefined) throw new Error("指令列表 undefined");
            else this.commandEntries = result;
        } catch (err) {
            Logger.error(this.LOG_TAG, `加载列表失败, ${err}`);
        }
    }

    async addCommandEntry(commandEntry: CommandEntry): Promise<boolean> {
        await this.db.waitForReady();

        try {
            let newOrderIndex = 0;
            if (this.commandEntries.length > 0) {
                const maxOrderIndex = Math.max(...this.commandEntries.map(entry => entry.orderIndex));
                newOrderIndex = maxOrderIndex + 1;
            }

            commandEntry.orderIndex = newOrderIndex;

            const result = await this.db.addCommandEntry(commandEntry);
            Logger.debug(this.LOG_TAG, `新命令添加成功，ID: ${result}`);
            return true;
        } catch (err) {
            Logger.error(this.LOG_TAG, `添加命令失败, ${err}`);
            return false;
        }
    }

    // 更新成功返回更新 entry 对应的所有 formID
    // 只有更新失败返回布尔值
    async updateCommandEntry(commandEntry: CommandEntry): Promise<boolean | string[]> {
        await this.db.waitForReady();

        try {
            const result = await this.db.updateCommandEntry(commandEntry);
            Logger.debug(this.LOG_TAG, `命令更新成功, ${result}`);

            let updatedFormIDs: string[] = [];

            // 如果条目更改为需要自定义输入，则取消绑定所有卡片
            if(commandEntry.idInputRequired === 1 || commandEntry.accountInputRequired === 1) {
                updatedFormIDs = await this.removeAllFormBelongsToEntryID(commandEntry.id);
            } else { // 否则更新卡片昵称和指令
                updatedFormIDs = await this.updateAllFormBelongsToEntry(commandEntry);
            }

            return updatedFormIDs;
        } catch (err) {
            Logger.error(this.LOG_TAG, `更新命令失败, ${err}`);
            return false;
        }
    }

    // 删除成功返回删除 entry 对应的所有 formID
    // 只有删除失败返回布尔值
    async deleteCommandEntry(commandEntry: CommandEntry): Promise<boolean | string[]> {
        await this.db.waitForReady();

        try {
            const result = await this.db.deleteCommandEntryByID(commandEntry);
            Logger.debug(this.LOG_TAG, `命令删除成功, ${result}`);

            // 删除所有对应 ID 的卡片
            const removedFormIDs = await this.removeAllFormBelongsToEntryID(commandEntry.id);

            return removedFormIDs;
        } catch (err) {
            Logger.error(this.LOG_TAG, `删除命令失败, ${err}`);
            return false;
        }
    }

    async clearCommandEntry(): Promise<boolean | string[]> {
        await this.db.waitForReady();

        try {
            await this.db.clearTableCommandEntries();
            Logger.debug(this.LOG_TAG, `指令列表清除成功`);

            // 获取全部卡片 formID，供 ViewModel 清空绑定
            const allBindings = await this.pm.getAllCardBindings();
            const allFormIDs = allBindings.map(binding => binding.formID);

            // 清空卡片绑定
            const success = await this.pm.clearAllBindings();
            if(success) {
                Logger.debug(this.LOG_TAG, `指令绑定已清空`);
                return allFormIDs; // 成功清除则返回所有 formID
            } else {
                Logger.warn(this.LOG_TAG, `指令绑定清空失败`);
                return false;
            }
        } catch (err) {
            Logger.error(this.LOG_TAG, `清除指令列表失败, ${err}`);
            return false;
        }
    }

    async updateEntriesOrder(reorderedEntries: Array<Array<number>>): Promise<boolean> {
        await this.db.waitForReady();

        try {
            await this.db.batchUpdateOrderIndices(reorderedEntries);
            Logger.debug(this.LOG_TAG, `顺序更新成功，共更新 ${reorderedEntries.length} 个命令。`);
            return true;
        } catch (err) {
            Logger.error(this.LOG_TAG, `更新命令顺序失败: ${err}`);
            return false;
        }
    }

    /*
     * 以下为桌面卡片(Form)相关
     * 仅更改持久化存储，不刷新卡片 UI
     * 卡片 UI 在 ViewModel 刷新
     */
    private async updateAllFormBelongsToEntry(commandEntry: CommandEntry): Promise<string[]> {
        const updatedFormIDs = await this.pm.updateByShortcut(commandEntry);
        Logger.debug(this.LOG_TAG, `已清除 ${updatedFormIDs.length} 个相关卡片`);
        return updatedFormIDs;
    }

    private async removeAllFormBelongsToEntryID(commandID: number): Promise<string[]> {
        const removedFormIDs = await this.pm.removeBindingsByShortcutId(commandID);
        Logger.debug(this.LOG_TAG, `已清除 ${removedFormIDs.length} 个相关卡片`);
        return removedFormIDs;
    }
}