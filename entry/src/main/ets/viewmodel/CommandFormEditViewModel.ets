import Logger from '../common/utils/Logger';
import CommandEntry from '../domain/model/CommandEntry';
import MultipleCommandsFormData from '../domain/model/MultipleCommandsFormData';
import SingleCommandFormData from '../domain/model/SingleCommandFormData';
import WidgetCommand from '../domain/model/WidgetCommand';
import { CardPublisher } from '../domain/repository/CardPublisher';
import { CommandRepository } from '../domain/repository/CommandRepository';
import { FormBindingRepository } from '../domain/repository/FormBindingRepository';
import { SettingsRepository } from '../domain/repository/SettingsRepository';
import {
    cardPublisher,
    commandRepository,
    formBindingRepository,
    settingsRepository
} from '../domain/service/DependencyWiring';
import { CommandEntryViewModel } from './CommandEntryViewModel';

/** 页面隐藏的处置：`'defer'` 留在窗口（保存中），`'close'` 可关 */
export type PageHideDecision = 'close' | 'defer';

/**
 * 两个卡片编辑页共用的 VM（设计 §2.4.2；视图仍两份，见 §7.3 的编辑页一行）。
 *
 * 页面只剩列表与勾选的呈现：保存时组装领域数据模型 → `FormBindingRepository` 落绑定 →
 * `CardPublisher.publish` 刷卡片。`FormPublisher` 与 `formProvider` 都不再出现在页面里。
 *
 * 保存守卫（设计 §2.7）：`closePending` 是本 VM 的状态——保存中页面隐藏时记下，保存成功后由 VM
 * 调页面注入的关闭动作关窗；保存失败则清掉它、写 `saveError`，窗口留着可重试。
 */
@ObservedV2
export default class CommandFormEditViewModel {
    private LOG_TAG = '[CommandFormEditViewModel]';

    // 可绑定条目：不带自定义输入要求（带要求的条目无法在卡片上执行）
    @Trace bindableEntries: Array<CommandEntryViewModel> = [];
    // 首屏加载态
    @Trace isLoading: boolean = true;
    // 设置是否完整（决定 `SetupNotice`）
    @Trace isSettingsComplete: boolean = true;
    // 保存进行中，禁用确认按钮
    @Trace isUpdating: boolean = false;
    // 选中集合：多指令卡可多选，单指令卡由页面只允许一个
    @Trace selectedIDs: Array<number> = [];
    // 全量里是否有条目：空态判定沿用 1.7.1 的「一条都没有」口径，不是「可绑定的为 0」
    @Trace hasAnyEntry: boolean = false;
    // 最近一次保存失败的原因（`''` 表示本次没有失败）；页面据此提示一次，输入与勾选保持可重试
    @Trace saveError: string = '';

    private formID: string = '';

    // 保存中页面隐藏：记下来，保存成功后由 VM 关窗（设计 §2.7）
    private closePending: boolean = false;
    // 页面在 `aboutToAppear` 注入的关闭动作
    private closeHandler: (() => void) | null = null;

    private commands: CommandRepository;
    private bindings: FormBindingRepository;
    private publisher: CardPublisher;
    private settings: SettingsRepository;

    constructor(commands: CommandRepository = commandRepository(),
                bindings: FormBindingRepository = formBindingRepository(),
                publisher: CardPublisher = cardPublisher(),
                settings: SettingsRepository = settingsRepository()) {
        this.commands = commands;
        this.bindings = bindings;
        this.publisher = publisher;
        this.settings = settings;
    }

    /** 记 formID、查设置完整性、加载可绑定条目 */
    async init(formID: string): Promise<void> {
        this.formID = formID;
        this.isLoading = true;

        try {
            this.isSettingsComplete = await this.settings.areComplete();

            const entries: Array<CommandEntry> = await this.commands.list();
            this.hasAnyEntry = entries.length > 0;

            this.bindableEntries = entries
                .filter((entry: CommandEntry) => entry.accountInputRequired === 0 && entry.idInputRequired === 0)
                .map((entry: CommandEntry) => {
                    const viewModel = new CommandEntryViewModel();
                    viewModel.updateCommand(entry);
                    return viewModel;
                });

            Logger.debug(this.LOG_TAG, `init() 可绑定条目 ${this.bindableEntries.length} 条`);
        } catch (err) {
            // 读失败按「一条都没有」的空态呈现，错误细节留在日志（本步不在 X3 的授权变更内）
            Logger.error(this.LOG_TAG, `init() 加载失败, ${err}`);
            this.bindableEntries = [];
            this.hasAnyEntry = false;
        } finally {
            this.isLoading = false;
        }
    }

    /** 加入或移出选中集合 */
    toggleSelection(id: number): void {
        if (this.selectedIDs.includes(id)) {
            this.selectedIDs = this.selectedIDs.filter((item: number) => item !== id);
        } else {
            this.selectedIDs = [...this.selectedIDs, id];
        }
    }

    /** 行高亮与勾选状态 */
    isSelected(id: number): boolean {
        return this.selectedIDs.includes(id);
    }

    /** 选中非空且不在保存中 */
    canConfirm(): boolean {
        return this.selectedIDs.length > 0 && !this.isUpdating;
    }

    /** 页面在 `aboutToAppear` 注入关闭动作：保存中隐藏后保存成功时由 VM 关窗（设计 §2.7） */
    setCloseHandler(handler: () => void): void {
        this.closeHandler = handler;
    }

    /**
     * 页面隐藏：保存中 → 记 `closePending` 并推迟关闭；否则可关。
     * 返回值由页面消费：`'close'` 就调 `PageContext.closeApplication`。
     */
    notifyPageHide(): PageHideDecision {
        if (this.isUpdating) {
            this.closePending = true;
            Logger.debug(this.LOG_TAG, 'notifyPageHide() 保存中，推迟关闭');
            return 'defer';
        }

        return 'close';
    }

    /** 取走保存失败原因（一次性）：非空时页面提示一次，看不见的那次由 `onPageShow` 补提 */
    consumeSaveError(): string {
        const message: string = this.saveError;

        if (message !== '') this.saveError = '';

        return message;
    }

    // 收尾：不在保存中；失败清 closePending（留窗口可重试），成功且隐藏过则关窗
    private completeSave(saved: boolean): void {
        this.isUpdating = false;

        if (!saved) {
            this.closePending = false;
            return;
        }

        if (!this.closePending) return;

        this.closePending = false;

        if (this.closeHandler) this.closeHandler();
    }

    /** 单指令卡：组装 `SingleCommandFormData` → 落绑定 → 刷卡片；全部成功才返回 true（页面据此关窗） */
    async confirmSingle(): Promise<boolean> {
        // 保存期间 `onPageShow` 可能重跑 `init`，本次保存按开始时的 formID 落盘
        const formID: string = this.formID;

        // 卡片标识缺失属前置条件不满足：写给页面一个可见原因，不能静默返回
        if (formID === '') {
            this.saveError = '卡片标识缺失';
            return false;
        }

        if (!this.canConfirm()) return false;

        const selected: CommandEntryViewModel | undefined = this.bindableEntries.find(
            (item: CommandEntryViewModel) => item.id === this.selectedIDs[0]
        );
        if (!selected) {
            Logger.error(this.LOG_TAG, 'confirmSingle() 未找到选中的条目');
            return false;
        }

        this.isUpdating = true;
        this.saveError = '';
        let saved: boolean = false;

        try {
            const formData: SingleCommandFormData = new SingleCommandFormData(formID, true);
            formData.shortcutID = selected.id;
            formData.nickname = selected.nickname;
            formData.command = selected.command;

            await this.bindings.bindSingle(formData);

            const written: boolean = await this.publisher.publish(formID, formData);
            if (!written) {
                Logger.error(this.LOG_TAG, `confirmSingle() 卡片写入失败, formID: ${formID}`);
                this.saveError = '卡片写入失败';
                return false;
            }

            Logger.debug(this.LOG_TAG, `卡片更新成功: formID: ${formID}, commandId: ${selected.id}`);
            saved = true;

            return true;
        } catch (err) {
            Logger.error(this.LOG_TAG, `confirmSingle() 更新卡片失败, ${err}`);
            this.saveError = `更新卡片失败: ${err}`;

            return false;
        } finally {
            this.completeSave(saved);
        }
    }

    /** 多指令卡：`commandList` 按选中顺序组装，其余同单卡 */
    async confirmMultiple(): Promise<boolean> {
        // 同 `confirmSingle`：按开始时的 formID 落盘
        const formID: string = this.formID;

        if (formID === '') {
            this.saveError = '卡片标识缺失';
            return false;
        }

        if (!this.canConfirm()) return false;

        const selectedItems: Array<CommandEntryViewModel> = [];
        for (const id of this.selectedIDs) {
            for (const item of this.bindableEntries) {
                if (item.id === id) {
                    selectedItems.push(item);
                    break;
                }
            }
        }

        if (selectedItems.length === 0) {
            Logger.error(this.LOG_TAG, 'confirmMultiple() 未找到选中的条目');
            return false;
        }

        this.isUpdating = true;
        this.saveError = '';
        let saved: boolean = false;

        try {
            const formData: MultipleCommandsFormData = new MultipleCommandsFormData(formID, true);
            formData.commandList = selectedItems.map(
                (item: CommandEntryViewModel) => new WidgetCommand(item.id, item.nickname, item.command)
            );

            await this.bindings.bindMultiple(formData);

            const written: boolean = await this.publisher.publish(formID, formData);
            if (!written) {
                Logger.error(this.LOG_TAG, `confirmMultiple() 卡片写入失败, formID: ${formID}`);
                this.saveError = '卡片写入失败';
                return false;
            }

            Logger.debug(this.LOG_TAG,
                `卡片更新成功: formID: ${formID}, commandIDs: ${this.selectedIDs.join(', ')}`);
            saved = true;

            return true;
        } catch (err) {
            Logger.error(this.LOG_TAG, `confirmMultiple() 更新卡片失败, ${err}`);
            this.saveError = `更新卡片失败: ${err}`;

            return false;
        } finally {
            this.completeSave(saved);
        }
    }
}
