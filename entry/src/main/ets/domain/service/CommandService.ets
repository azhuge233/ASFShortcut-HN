import Logger from '../../common/utils/Logger';
import CommonConstants from '../../common/constants/CommonConstants';
import { CommandDao } from '../../data/dao/CommandDao';
import { FormBindingStore } from '../../data/store/FormBindingStore';
import CommandEntry from '../model/CommandEntry';
import MultipleCommandsFormData from '../model/MultipleCommandsFormData';
import SingleCommandFormData from '../model/SingleCommandFormData';
import { CommandRepository } from '../repository/CommandRepository';
import { FormBindingRepository } from '../repository/FormBindingRepository';

const LOG_TAG: string = '[CommandService]';

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

    constructor(commands: CommandRepository = CommandDao.getInstance(),
                bindings: FormBindingRepository = FormBindingStore.getInstance()) {
        this.commands = commands;
        this.bindings = bindings;
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

    private toAffectedMap(singleIDs: string[], multipleIDs: string[]): Map<string, string[]> {
        const affected: Map<string, string[]> = new Map<string, string[]>();
        affected.set(CommonConstants.FORM_RESULT_MAP_KEY_SINGLE, singleIDs);
        affected.set(CommonConstants.FORM_RESULT_MAP_KEY_MULTIPLE, multipleIDs);
        return affected;
    }
}
