import Logger from '../../common/utils/Logger';
import CommonConstants from '../../common/constants/CommonConstants';
import { CommandDao } from '../../data/dao/CommandDao';
import { SettingsDao } from '../../data/dao/SettingsDao';
import TransferFiles from '../../data/file/TransferFiles';
import { FormBindingStore } from '../../data/store/FormBindingStore';
import CommandEntry from '../model/CommandEntry';
import { CommandEntryJsonObject, ExportJsonObject, SettingsJsonObject } from '../model/JsonObjects';
import MultipleCommandsFormData from '../model/MultipleCommandsFormData';
import SingleCommandFormData from '../model/SingleCommandFormData';
import { CommandRepository } from '../repository/CommandRepository';
import { FormBindingRepository } from '../repository/FormBindingRepository';
import { SettingsRepository } from '../repository/SettingsRepository';

const LOG_TAG: string = '[CommandService]';

/**
 * 备份导出与导入的结果（设计 §3.3 的调用链）：取消不是失败、失败分四类，
 * `reason` 保留可读细节。VM 把它转成自己的 `MoreActionResult`，界面按 `failure` 选文案。
 */
export class BackupResult {
    ok: boolean = false;
    cancelled: boolean = false;
    // 'none' | 'bindings' | 'reason' | 'error'
    failure: string = 'none';
    reason: string = '';

    static succeed(): BackupResult {
        const result = new BackupResult();
        result.ok = true;
        return result;
    }

    static cancel(): BackupResult {
        const result = new BackupResult();
        result.cancelled = true;
        return result;
    }

    static fail(failure: string, reason: string): BackupResult {
        const result = new BackupResult();
        result.failure = failure;
        result.reason = reason;
        return result;
    }
}

/**
 * 一次增删改的结果：成功与否、受影响的 `formID` 映射（按单卡 / 多卡分开，键沿用 `CommonConstants`）、
 * 可读原因，以及「失败在解绑」标记——界面据此区分「删除失败」与「删除失败：卡片绑定未能解除」。
 */
export class CommandMutationResult {
    ok: boolean = false;
    affected: Map<string, string[]> = new Map<string, string[]>();
    reason: string = '';
    unbindFailed: boolean = false;

    static succeed(affected: Map<string, string[]>): CommandMutationResult {
        const result = new CommandMutationResult();
        result.ok = true;
        result.affected = affected;
        return result;
    }

    static fail(reason: string, unbindFailed: boolean = false): CommandMutationResult {
        const result = new CommandMutationResult();
        result.ok = false;
        result.reason = reason;
        result.unbindFailed = unbindFailed;
        return result;
    }
}

/**
 * 领域规则落点（设计 §2.3）：
 * 删除先解绑、清空先解绑、改条目时判定是否解绑、受影响卡片集合的计算。
 * 数据存取在 `data/`，本类只编排顺序与判定——顺序就是规则本身。
 */
export class CommandService {
    private commands: CommandRepository;
    private bindings: FormBindingRepository;
    private settings: SettingsRepository;

    constructor(commands: CommandRepository = CommandDao.getInstance(),
                bindings: FormBindingRepository = FormBindingStore.getInstance(),
                settings: SettingsRepository = SettingsDao.getInstance()) {
        this.commands = commands;
        this.bindings = bindings;
        this.settings = settings;
    }

    /** 删除一条指令：先解绑含该 ID 的全部绑定，解绑失败则本次删除失败、库不变（X1） */
    async deleteEntry(id: number): Promise<CommandMutationResult> {
        // 先取受影响集合：解绑之后就拿不到「哪些卡片曾被这条指令绑着」了
        const affected = await this.collectAffectedByShortcut(id);

        try {
            await this.bindings.removeByShortcutID(id);
        } catch (err) {
            Logger.error(LOG_TAG, `deleteEntry() 解绑失败，删除中止, ${err}`);
            return CommandMutationResult.fail(`卡片绑定未能解除: ${err}`, true);
        }

        try {
            await this.commands.deleteByID(id);
        } catch (err) {
            Logger.error(LOG_TAG, `deleteEntry() 删除失败, ${err}`);
            return CommandMutationResult.fail(`删除指令失败: ${err}`);
        }

        Logger.debug(LOG_TAG, `deleteEntry() 已删除并解绑, ID: ${id}`);
        return CommandMutationResult.succeed(affected);
    }

    /** 更新一条指令：带自定义输入要求时解绑该条目的全部绑定，否则只把新昵称与新指令刷进绑定 */
    async updateEntry(entry: CommandEntry): Promise<CommandMutationResult> {
        try {
            await this.commands.update(entry);
        } catch (err) {
            Logger.error(LOG_TAG, `updateEntry() 更新失败, ${err}`);
            return CommandMutationResult.fail(`更新指令失败: ${err}`);
        }

        const affected = await this.collectAffectedByShortcut(entry.id);

        // 现有判据照搬：条目需要自定义输入即解绑全部卡片（不是「由不需要变为需要」）
        if (entry.idInputRequired === 1 || entry.accountInputRequired === 1) {
            try {
                await this.bindings.removeByShortcutID(entry.id);
            } catch (err) {
                Logger.error(LOG_TAG, `updateEntry() 解绑失败, ${err}`);
                return CommandMutationResult.fail(`卡片绑定未能解除: ${err}`, true);
            }
        } else {
            await this.bindings.updateByShortcut(entry);
        }

        return CommandMutationResult.succeed(affected);
    }

    /** 清空全部指令：先解绑全部绑定，解绑失败则不清表 */
    async clearAll(): Promise<CommandMutationResult> {
        const affected = await this.collectAllAffected();

        const cleared = await this.bindings.clearAll();
        if (!cleared) {
            Logger.warn(LOG_TAG, `clearAll() 解绑失败，未清空指令表`);
            return CommandMutationResult.fail('卡片绑定未能解除，指令未清空', true);
        }

        try {
            const replaced = await this.commands.replaceAll([]);
            if (!replaced) return CommandMutationResult.fail('清空指令表失败');
        } catch (err) {
            Logger.error(LOG_TAG, `clearAll() 清空指令表失败, ${err}`);
            return CommandMutationResult.fail(`清空指令表失败: ${err}`);
        }

        Logger.debug(LOG_TAG, `clearAll() 已清空绑定与指令表`);
        return CommandMutationResult.succeed(affected);
    }

    /** 受影响集合：单卡按 `shortcutID` 命中，多卡按列表里是否含该条目命中 */
    async collectAffectedByShortcut(shortcutID: number): Promise<Map<string, string[]>> {
        const singleIDs: string[] = [];
        const singleBindings: Array<[string, SingleCommandFormData]> = await this.bindings.listSingle();
        for (const pair of singleBindings) {
            if (pair[1].shortcutID === shortcutID) singleIDs.push(pair[0]);
        }

        const multipleIDs: string[] = [];
        const multipleBindings: Array<[string, MultipleCommandsFormData]> = await this.bindings.listMultiple();
        for (const pair of multipleBindings) {
            const contains: boolean = pair[1].commandList.some(item => item.id === shortcutID);
            if (contains) multipleIDs.push(pair[0]);
        }

        return this.toAffectedMap(singleIDs, multipleIDs);
    }

    /** 全部绑定：清空指令前要拿这份集合去重置卡片 */
    async collectAllAffected(): Promise<Map<string, string[]>> {
        const singleIDs: string[] = [];
        const singleBindings: Array<[string, SingleCommandFormData]> = await this.bindings.listSingle();
        for (const pair of singleBindings) singleIDs.push(pair[0]);

        const multipleIDs: string[] = [];
        const multipleBindings: Array<[string, MultipleCommandsFormData]> = await this.bindings.listMultiple();
        for (const pair of multipleBindings) multipleIDs.push(pair[0]);

        return this.toAffectedMap(singleIDs, multipleIDs);
    }

    /**
     * 导出：设置 + 指令组装成备份 JSON，交 `TransferFiles` 存盘（设计 §3.3 的调用链）。
     * 用户取消保存位置时 `cancelled = true`——取消不是失败，界面不提示失败。
     */
    async exportData(context: Object): Promise<BackupResult> {
        try {
            const settingsJson: SettingsJsonObject = new SettingsJsonObject(
                await this.settings.get(CommonConstants.DB_KEY_HOST_INFO_ADDRESS),
                await this.settings.get(CommonConstants.DB_KEY_HOST_INFO_PASSWORD)
            );

            const entries: Array<CommandEntry> = await this.commands.list();
            const entryJsonList: Array<CommandEntryJsonObject> = entries.map(
                (entry: CommandEntry) => new CommandEntryJsonObject(entry.nickname, entry.command, entry.orderIndex,
                    entry.accountInputRequired, entry.idInputRequired)
            );

            const jsonString: string = JSON.stringify(new ExportJsonObject(settingsJson, entryJsonList), null, 4);

            const saved: boolean = await TransferFiles.saveToFileFrom(jsonString, context);
            if (!saved) return BackupResult.cancel();

            Logger.debug(LOG_TAG, `exportData() 已导出 ${entryJsonList.length} 条指令`);
            return BackupResult.succeed();
        } catch (err) {
            Logger.error(LOG_TAG, `exportData() 导出失败, ${err}`);
            return BackupResult.fail('error', `${err}`);
        }
    }

    /**
     * 选备份文件。单独一步，是为了让「导入中的遮罩」仍从选完文件之后才升起（与 1.7.1 同一时机）。
     * 抛错由调用方按「导入失败」处置。
     */
    async pickBackupFile(context: Object): Promise<string[]> {
        return TransferFiles.pickFileFrom(context);
    }

    /**
     * 读备份文件并解析成导入用的 JSON 对象（设计 §3.3 的调用链前半）。
     * 读失败抛错，由调用方按「导入失败」处置——与 1.7.1 的 `throw new Error("读取文件失败")` 同口径。
     * 解析之后交 `CommandImportService`（经 `CommandEntryList.importData`）做字段校验与事务整体替换。
     */
    async readBackup(uris: string[]): Promise<ExportJsonObject> {
        const jsonString: string | undefined = await TransferFiles.readFile(uris[0]);
        if (jsonString === undefined) throw new Error('读取文件失败');

        return TransferFiles.parseData(jsonString);
    }

    private toAffectedMap(singleIDs: string[], multipleIDs: string[]): Map<string, string[]> {
        const affected: Map<string, string[]> = new Map<string, string[]>();
        affected.set(CommonConstants.FORM_RESULT_MAP_KEY_SINGLE, singleIDs);
        affected.set(CommonConstants.FORM_RESULT_MAP_KEY_MULTIPLE, multipleIDs);
        return affected;
    }
}
