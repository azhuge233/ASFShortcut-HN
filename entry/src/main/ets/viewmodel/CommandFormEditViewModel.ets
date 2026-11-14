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

/**
 * 两个卡片编辑页共用的 VM（设计 §2.4.2；视图仍两份，见 §7.3 的编辑页一行）。
 *
 * 页面只剩列表与勾选的呈现：保存时组装领域数据模型 → `FormBindingRepository` 落绑定 →
 * `CardPublisher.publish` 刷卡片。`FormPublisher` 与 `formProvider` 都不再出现在页面里。
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

    private formID: string = '';

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

    /** 单指令卡：组装 `SingleCommandFormData` → 落绑定 → 刷卡片；全部成功才返回 true（页面据此关窗） */
    async confirmSingle(): Promise<boolean> {
        if (!this.canConfirm() || this.formID === '') return false;

        const selected: CommandEntryViewModel | undefined = this.bindableEntries.find(
            (item: CommandEntryViewModel) => item.id === this.selectedIDs[0]
        );
        if (!selected) {
            Logger.error(this.LOG_TAG, 'confirmSingle() 未找到选中的条目');
            return false;
        }

        this.isUpdating = true;

        try {
            const formData: SingleCommandFormData = new SingleCommandFormData(this.formID, true);
            formData.shortcutID = selected.id;
            formData.nickname = selected.nickname;
            formData.command = selected.command;

            await this.bindings.bindSingle(formData);

            const written: boolean = await this.publisher.publish(this.formID, formData);
            if (!written) {
                Logger.error(this.LOG_TAG, `confirmSingle() 卡片写入失败, formID: ${this.formID}`);
                return false;
            }

            Logger.debug(this.LOG_TAG, `卡片更新成功: formID: ${this.formID}, commandId: ${selected.id}`);
            return true;
        } catch (err) {
            Logger.error(this.LOG_TAG, `confirmSingle() 更新卡片失败, ${err}`);
            return false;
        } finally {
            this.isUpdating = false;
        }
    }

    /** 多指令卡：`commandList` 按选中顺序组装，其余同单卡 */
    async confirmMultiple(): Promise<boolean> {
        if (!this.canConfirm() || this.formID === '') return false;

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

        try {
            const formData: MultipleCommandsFormData = new MultipleCommandsFormData(this.formID, true);
            formData.commandList = selectedItems.map(
                (item: CommandEntryViewModel) => new WidgetCommand(item.id, item.nickname, item.command)
            );

            await this.bindings.bindMultiple(formData);

            const written: boolean = await this.publisher.publish(this.formID, formData);
            if (!written) {
                Logger.error(this.LOG_TAG, `confirmMultiple() 卡片写入失败, formID: ${this.formID}`);
                return false;
            }

            Logger.debug(this.LOG_TAG,
                `卡片更新成功: formID: ${this.formID}, commandIDs: ${this.selectedIDs.join(', ')}`);
            return true;
        } catch (err) {
            Logger.error(this.LOG_TAG, `confirmMultiple() 更新卡片失败, ${err}`);
            return false;
        } finally {
            this.isUpdating = false;
        }
    }
}
