import Logger from '../../common/utils/Logger';
import CommonConstants from '../../common/constants/CommonConstants';
import { CommandDao } from '../../data/dao/CommandDao';
import { SettingsDao } from '../../data/dao/SettingsDao';
import { Database, TransactionBoundary } from '../../data/Database';
import { FormBindingStore } from '../../data/store/FormBindingStore';
import CommandEntry from '../model/CommandEntry';
import { CommandEntryJsonObject, ExportJsonObject, SettingsJsonObject } from '../model/JsonObjects';
import { CommandRepository } from '../repository/CommandRepository';
import { FormBindingRepository } from '../repository/FormBindingRepository';
import { SettingsRepository } from '../repository/SettingsRepository';

const LOG_TAG: string = '[CommandImportService]';

/** 导入校验结果：不通过时 `reason` 点名缺失的键或第几条的哪个字段 */
export class ImportValidation {
    ok: boolean = false;
    reason: string = '';

    static pass(): ImportValidation {
        const result = new ImportValidation();
        result.ok = true;
        return result;
    }

    static reject(reason: string): ImportValidation {
        const result = new ImportValidation();
        result.ok = false;
        result.reason = reason;
        return result;
    }
}

/**
 * 导入结果。`bindingsCleared` 单独给出来，是为了让界面用资源文案
 * （「导入完成但卡片绑定未清理，请重新绑定」）而不是把领域原因直接抛给用户；
 * `reason` 保留可读细节，供日志与诊断。
 */
export class CommandImportResult {
    ok: boolean = false;
    reason: string = '';
    bindingsCleared: boolean = true;

    static succeed(): CommandImportResult {
        const result = new CommandImportResult();
        result.ok = true;
        return result;
    }

    static fail(reason: string, bindingsCleared: boolean = true): CommandImportResult {
        const result = new CommandImportResult();
        result.ok = false;
        result.reason = reason;
        result.bindingsCleared = bindingsCleared;
        return result;
    }
}

/**
 * 导入：字段级校验 + 事务整体替换（设计 §2.3、§2.11 第二条）。
 *
 * 事务边界由本类发起、在 `data/Database.ets` 实现：两张表的整表替换必须是同一次提交，
 * 否则「导入失败保留原数据」不成立。
 */
export class CommandImportService {
    private commands: CommandRepository;
    private settings: SettingsRepository;
    private bindings: FormBindingRepository;
    private transaction: TransactionBoundary;

    constructor(commands: CommandRepository = CommandDao.getInstance(),
                settings: SettingsRepository = SettingsDao.getInstance(),
                bindings: FormBindingRepository = FormBindingStore.getInstance(),
                transaction: TransactionBoundary = Database.getInstance()) {
        this.commands = commands;
        this.settings = settings;
        this.bindings = bindings;
        this.transaction = transaction;
    }

    /** 字段级校验：返回第一个失败原因与位置 */
    validate(json: ExportJsonObject): ImportValidation {
        if (json === null || json === undefined) return ImportValidation.reject('备份内容为空');

        const settings: SettingsJsonObject = json.Settings;
        if (settings === null || settings === undefined) return ImportValidation.reject('缺少顶层键 Settings');

        const entries: Array<CommandEntryJsonObject> = json.CommandEntryList;
        if (!Array.isArray(entries)) return ImportValidation.reject('顶层键 CommandEntryList 不是数组');

        for (let index = 0; index < entries.length; index++) {
            const item: CommandEntryJsonObject = entries[index];
            const position: string = `第 ${index + 1} 条`;

            if (item === null || item === undefined) {
                return ImportValidation.reject(`${position} 不是对象`);
            }

            if (typeof item.Command !== 'string' || item.Command.trim() === '') {
                return ImportValidation.reject(`${position} 的 Command 为空`);
            }

            if (typeof item.OrderIndex !== 'number' || Math.floor(item.OrderIndex) !== item.OrderIndex) {
                return ImportValidation.reject(`${position} 的 OrderIndex 不是整数`);
            }

            if (!this.isBooleanOrBit(item.AIR)) {
                return ImportValidation.reject(`${position} 的 AIR 不是布尔或 0/1`);
            }

            if (!this.isBooleanOrBit(item.IIR)) {
                return ImportValidation.reject(`${position} 的 IIR 不是布尔或 0/1`);
            }
        }

        return ImportValidation.pass();
    }

    /** 导入：校验 → 同一事务内整体替换两张表 → 清空卡片绑定；清空失败如实上报（X2） */
    async importData(json: ExportJsonObject): Promise<CommandImportResult> {
        const validation: ImportValidation = this.validate(json);
        if (!validation.ok) {
            Logger.warn(LOG_TAG, `importData() 校验未通过: ${validation.reason}`);
            return CommandImportResult.fail(validation.reason);
        }

        const entries: Array<CommandEntry> = this.toEntries(json.CommandEntryList);
        const settingsPairs: Array<[string, string]> = [
            [CommonConstants.DB_KEY_HOST_INFO_ADDRESS, json.Settings.Address],
            [CommonConstants.DB_KEY_HOST_INFO_PASSWORD, json.Settings.Password]
        ];

        let replaced: boolean = false;
        try {
            this.transaction.beginTransaction();
            try {
                const settingsOk: boolean = await this.settings.replaceAll(settingsPairs);
                const commandsOk: boolean = await this.commands.replaceAll(entries);
                replaced = settingsOk && commandsOk;
            } catch (err) {
                replaced = false;
                Logger.error(LOG_TAG, `importData() 写入失败, ${err}`);
            }

            if (!replaced) {
                this.transaction.rollBackTransaction();
                return CommandImportResult.fail('导入数据失败，原数据已保留');
            }

            this.transaction.commitTransaction();
        } catch (err) {
            Logger.error(LOG_TAG, `importData() 事务失败, ${err}`);

            // 失败必须回到原数据：回滚自身再失败时只记日志，业务结论仍是「导入失败」
            try {
                this.transaction.rollBackTransaction();
            } catch (rollbackErr) {
                Logger.error(LOG_TAG, `importData() 回滚失败, ${rollbackErr}`);
            }

            return CommandImportResult.fail(`导入数据失败: ${err}`);
        }

        const cleared: boolean = await this.bindings.clearAll();
        if (!cleared) {
            // 导入本身已成功、卡片绑定没清掉：不能按成功报，否则用户以为导入干净了
            Logger.warn(LOG_TAG, `importData() 导入成功，但卡片绑定清空失败`);
            return CommandImportResult.fail('导入完成但卡片绑定未清理', false);
        }

        return CommandImportResult.succeed();
    }

    private toEntries(items: Array<CommandEntryJsonObject>): Array<CommandEntry> {
        const entries: Array<CommandEntry> = [];

        for (let index = 0; index < items.length; index++) {
            const item: CommandEntryJsonObject = items[index];
            const orderIndex: number = item.OrderIndex == -1 ? index : item.OrderIndex;

            entries.push(new CommandEntry(0, item.Nickname, item.Command, orderIndex, this.toBit(item.AIR),
                this.toBit(item.IIR)));
        }

        return entries;
    }

    private toBit(value: number): number {
        if (typeof value === 'boolean') return (value as boolean) ? 1 : 0;
        return value;
    }

    private isBooleanOrBit(value: number): boolean {
        const type: string = typeof value;
        if (type === 'boolean') return true;
        return value === 0 || value === 1;
    }
}
