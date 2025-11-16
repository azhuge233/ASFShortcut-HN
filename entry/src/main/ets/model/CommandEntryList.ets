import CommandEntry from "./CommandEntry";
import Logger from '../common/utils/Logger';
import { DB } from "../common/utils/DB"

export default class CommandEntryList {
    commandEntries: Array<CommandEntry> = [];

    private LOG_TAG = "[Model/CommandEntryList]";

    private db = DB.getInstance();

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
            const result = await this.db.addCommandEntry(commandEntry);
            Logger.debug(this.LOG_TAG, `新命令添加成功，ID: ${result}`);
            return true;
        } catch (err) {
            Logger.error(this.LOG_TAG, `添加命令失败, ${err}`);
            return false;
        }
    }

    async updateCommandEntry(commandEntry: CommandEntry): Promise<boolean> {
        await this.db.waitForReady();

        try {
            const result = await this.db.updateCommandEntry(commandEntry);
            Logger.debug(this.LOG_TAG, `命令更新成功, ${result}`);
            return true;
        } catch (err) {
            Logger.error(this.LOG_TAG, `更新命令失败, ${err}`);
            return false;
        }
    }

    async deleteCommandEntry(commandEntry: CommandEntry): Promise<boolean> {
        await this.db.waitForReady();

        try {
            const result = await this.db.deleteCommandEntryByID(commandEntry);
            Logger.debug(this.LOG_TAG, `命令删除成功, ${result}`);
            return true;
        } catch (err) {
            Logger.error(this.LOG_TAG, `删除命令失败, ${err}`);
            return false;
        }
    }

    async clearCommandEntry(): Promise<boolean> {
        await this.db.waitForReady();

        try {
            await this.db.clearTableCommandEntries();
            Logger.debug(this.LOG_TAG, `指令列表清除成功`);
            return true;
        } catch (err) {
            Logger.error(this.LOG_TAG, `清除指令列表失败, ${err}`);
            return false;
        }
    }
}