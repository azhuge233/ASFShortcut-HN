import Logger from '../../common/utils/Logger';
import { CommandDao } from '../../data/dao/CommandDao';
import { CommandRepository } from '../repository/CommandRepository';
import { CommandImportResult, CommandImportService } from '../service/CommandImportService';
import { CommandMutationResult, CommandService } from '../service/CommandService';
import CommandEntry from './CommandEntry';
import { ExportJsonObject } from './JsonObjects';

/**
 * 指令列表聚合根（设计 §2.3）：持有内存中的列表与 `orderIndex = max + 1` 的规则，
 * 增删改后把受影响的 `formID` 映射交回上层。
 *
 * 涉及业务判定的顺序（删除先解绑、清空先解绑、改条目是否解绑）在 `CommandService`；
 * 导入校验与事务整体替换在 `CommandImportService`。数据存取一律经仓库接口，不直连数据库与首选项。
 */
export default class CommandEntryList {
    commandEntries: Array<CommandEntry> = [];

    private LOG_TAG = '[Model/CommandEntryList]';

    private commands: CommandRepository;
    private service: CommandService;
    private importService: CommandImportService;

    constructor(commandEntries: Array<CommandEntry>,
                commands: CommandRepository = CommandDao.getInstance(),
                service: CommandService = new CommandService(),
                importService: CommandImportService = new CommandImportService()) {
        this.commandEntries = commandEntries;
        this.commands = commands;
        this.service = service;
        this.importService = importService;
    }

    /**
     * 读列表。失败时返回 false 且不动内存列表——把失败显示成空列表是假话（设计 §2.11 第三条）。
     */
    async loadCommandEntries(): Promise<boolean> {
        try {
            const result = await this.commands.list();
            if (result === undefined) throw new Error("指令列表 undefined");

            this.commandEntries = result;
            return true;
        } catch (err) {
            Logger.error(this.LOG_TAG, `加载列表失败, ${err}`);
            return false;
        }
    }

    async addCommandEntry(commandEntry: CommandEntry): Promise<boolean> {
        try {
            let newOrderIndex = 0;
            if (this.commandEntries.length > 0) {
                const maxOrderIndex = Math.max(...this.commandEntries.map(entry => entry.orderIndex));
                newOrderIndex = maxOrderIndex + 1;
            }

            commandEntry.orderIndex = newOrderIndex;

            const result = await this.commands.insert(commandEntry);
            Logger.debug(this.LOG_TAG, `新命令添加成功，ID: ${result}`);
            return true;
        } catch (err) {
            Logger.error(this.LOG_TAG, `添加命令失败, ${err}`);
            return false;
        }
    }

    async updateCommandEntry(commandEntry: CommandEntry): Promise<CommandMutationResult> {
        const result = await this.service.updateEntry(commandEntry);

        if (result.ok) Logger.debug(this.LOG_TAG, `命令更新成功`);
        else Logger.error(this.LOG_TAG, `更新命令失败, ${result.reason}`);

        return result;
    }

    async deleteCommandEntry(commandEntry: CommandEntry): Promise<CommandMutationResult> {
        const result = await this.service.deleteEntry(commandEntry.id);

        if (result.ok) Logger.debug(this.LOG_TAG, `命令删除成功`);
        else Logger.error(this.LOG_TAG, `删除命令失败, ${result.reason}`);

        return result;
    }

    async clearCommandEntry(): Promise<CommandMutationResult> {
        const result = await this.service.clearAll();

        if (result.ok) Logger.debug(this.LOG_TAG, `指令列表清除成功`);
        else Logger.error(this.LOG_TAG, `清除指令列表失败, ${result.reason}`);

        return result;
    }

    async importData(json: ExportJsonObject): Promise<CommandImportResult> {
        return this.importService.importData(json);
    }

    async updateEntriesOrder(entries: Array<CommandEntry>): Promise<boolean> {
        try {
            const success = await this.commands.batchUpdateOrderIndices(entries);
            if (success) {
                Logger.debug(this.LOG_TAG, `顺序更新成功，共更新 ${entries.length} 个命令。`);
            } else {
                Logger.warn(this.LOG_TAG, `顺序更新失败，共 ${entries.length} 个命令。`);
            }
            return success;
        } catch (err) {
            Logger.error(this.LOG_TAG, `更新命令顺序失败: ${err}`);
            return false;
        }
    }
}
