import Logger from '../common/utils/Logger';
import CommonConstants from '../common/constants/CommonConstants';
import CommandEntry from '../domain/model/CommandEntry';
import CommandEntryList from '../domain/model/CommandEntryList';
import MultipleCommandsFormData from '../domain/model/MultipleCommandsFormData';
import SingleCommandFormData from '../domain/model/SingleCommandFormData';
import { CommandEntryJsonObject, ExportJsonObject } from '../domain/model/JsonObjects';
import { CommandSendResult, CommandSender } from '../domain/repository/CommandSender';
import { CardPublisher } from '../domain/repository/CardPublisher';
import { FormBindingRepository } from '../domain/repository/FormBindingRepository';
import { SettingsRepository } from '../domain/repository/SettingsRepository';
import { CommandImportResult } from '../domain/service/CommandImportService';
import { CommandMutationResult } from '../domain/service/CommandService';
import {
    cardPublisher,
    createCommandSender,
    formBindingRepository,
    settingsRepository
} from '../domain/service/DependencyWiring';
import { CommandEntryViewModel } from './CommandEntryViewModel';

/** 呈现意图类别（设计 §2.4.2）：`result` = 弹结果对话框，`notice` = 弹提示，`error` = 弹错误 */
export type CommandOutcomeKind = 'result' | 'notice' | 'error';

/**
 * 一次指令执行给界面的呈现意图（设计 §2.4.2）：VM 只说「弹什么、写什么」，
 * 对话框 / 提示 / `$r` 资源都由页面选。
 */
export class CommandOutcome {
    kind: CommandOutcomeKind = 'result';
    text: string = '';

    /** 响应码 200：弹结果对话框 */
    static result(text: string): CommandOutcome {
        const outcome = new CommandOutcome();
        outcome.kind = 'result';
        outcome.text = text;
        return outcome;
    }

    /** 其他响应码：弹提示，`text` 已含响应码 */
    static notice(text: string): CommandOutcome {
        const outcome = new CommandOutcome();
        outcome.kind = 'notice';
        outcome.text = text;
        return outcome;
    }

    /** 没拿到响应：弹错误 */
    static error(text: string): CommandOutcome {
        const outcome = new CommandOutcome();
        outcome.kind = 'error';
        outcome.text = text;
        return outcome;
    }
}

/**
 * 主列表一屏的 VM（设计 §2.4.2）。替掉 B1 的旧列表 VM：
 * 页面可见面扩到搜索与加载错误态（X3），数据与动作全部经本类，页面不再 import 数据层。
 *
 * 依赖全部走 `domain/` 的端口，默认实现由 `domain/service/DependencyWiring.ets` 装配——
 * 规则 4 只许 `viewmodel/` import `domain/` 与 `common/`（§1.5）。
 */
@ObservedV2
export default class CommandListViewModel {
    private LOG_TAG = '[CommandListViewModel]';

    // 当前显示的条目（过滤后的结果）
    @Trace entries: Array<CommandEntryViewModel> = [];
    // 搜索关键字；赋值即重算过滤（页面写 `setKeyword`）
    @Trace keyword: string = '';
    // 加载进行中
    @Trace isLoading: boolean = false;
    // 最近一次加载失败的可读原因；空串表示无错（X3：不把读失败显示成空列表）
    @Trace loadError: string = '';
    // 发指令 / 测试中，驱动遮罩
    @Trace isProcessing: boolean = false;
    // 正在运行的条目 ID
    @Trace runningIDs: Set<number> = new Set<number>();
    // 底部 tab 下标
    @Trace currentTab: number = 0;
    // ASF 设置不完整时的初始化覆盖层
    @Trace showSetup: boolean = false;

    // 测试页三个输入
    @Trace testAddress: string = '';
    @Trace testPassword: string = '';
    @Trace testCommand: string = '';

    // 拖拽落库失败回调：页面据此再刷一次列表并提示（§2.4.5）
    onMoveFailed: (() => void) | null = null;

    // 全量条目：过滤前的底稿，`entries` 是它按关键字过滤后的副本
    private allEntries: Array<CommandEntryViewModel> = [];

    private dataModel: CommandEntryList;
    private bindings: FormBindingRepository;
    private publisher: CardPublisher;
    private settings: SettingsRepository;
    private senderFactory: () => CommandSender;
    private sender: CommandSender | null = null;

    constructor(dataModel: CommandEntryList = new CommandEntryList([]),
                bindings: FormBindingRepository = formBindingRepository(),
                publisher: CardPublisher = cardPublisher(),
                settings: SettingsRepository = settingsRepository(),
                senderFactory: () => CommandSender = createCommandSender) {
        this.dataModel = dataModel;
        this.bindings = bindings;
        this.publisher = publisher;
        this.settings = settings;
        this.senderFactory = senderFactory;
    }

    /** 首屏：检查设置完整性 → 读地址密码并初始化发送器 → 读列表 */
    async init(): Promise<void> {
        try {
            this.showSetup = !(await this.settings.areComplete());
        } catch (err) {
            // 设置读不出来不能当成「设置不完整」（那是另一个业务状态）：按读取失败进错误态，由用户重试
            Logger.error(this.LOG_TAG, `init() 检查设置失败, ${err}`);
            this.loadError = '读取设置失败';
            return;
        }

        if (!this.showSetup) await this.loadSettings();

        await this.loadEntries();
    }

    /** 读库填全量、应用过滤；失败置 `loadError` 并保留上一次 `entries` */
    async loadEntries(): Promise<void> {
        this.isLoading = true;

        try {
            const loaded: boolean = await this.dataModel.loadCommandEntries();

            // 读失败时保留上一次的列表：把失败显示成「没有指令」是假话（X3）
            if (!loaded) {
                this.loadError = '读取指令列表失败';
                return;
            }

            this.loadError = '';
            this.allEntries = this.dataModel.commandEntries.map((entry: CommandEntry) => {
                const viewModel = new CommandEntryViewModel();
                viewModel.updateCommand(entry);
                return viewModel;
            });
            this.applyFilter();
        } catch (err) {
            // 仓库层抛错同样要走到错误态，不能把异常漏成空列表（U16 的「读抛错」口径）
            Logger.error(this.LOG_TAG, `loadEntries() 读库抛错, ${err}`);
            this.loadError = '读取指令列表失败';
        } finally {
            this.isLoading = false;
        }
    }

    /** 清错误态后重读；页面重试入口调它 */
    async retryLoad(): Promise<void> {
        this.loadError = '';
        await this.loadEntries();
    }

    /** 写关键字并重算过滤 */
    setKeyword(value: string): void {
        this.keyword = value;
        this.applyFilter();
    }

    /** 全量为空（「没有指令 / 点右上角新建」空态） */
    isEmpty(): boolean {
        return this.allEntries.length === 0;
    }

    /** 全量非空且过滤后为空（搜索空态） */
    isNoMatch(): boolean {
        return this.allEntries.length > 0 && this.entries.length === 0;
    }

    async addEntry(entry: CommandEntry): Promise<boolean> {
        const success = await this.dataModel.addCommandEntry(entry);
        if (success) await this.loadEntries();
        return success;
    }

    async updateEntry(entry: CommandEntry): Promise<CommandMutationResult> {
        const result = await this.dataModel.updateCommandEntry(entry);

        // 更新成功，`affected` 携带绑定了该条目的所有 formID
        if (result.ok) {
            await this.loadEntries();
            await this.updateForms(result.affected);
        }
        return result;
    }

    async deleteEntry(entry: CommandEntry): Promise<CommandMutationResult> {
        const result = await this.dataModel.deleteCommandEntry(entry);

        if (result.ok) {
            // 顺序不能换：先刷新列表与内存底稿，再重排下标，最后刷卡片
            await this.loadEntries();
            await this.updateEntriesOrder();
            await this.updateForms(result.affected);
        }
        return result;
    }

    async clearAllEntries(): Promise<CommandMutationResult> {
        const result = await this.dataModel.clearCommandEntry();

        if (result.ok) {
            await this.loadEntries();
            await this.updateForms(result.affected);
        }
        return result;
    }

    /** 导入：成功后重载，并用空绑定刷新全部卡片（§2.11 X2 的失败由领域层给出来） */
    async importData(json: ExportJsonObject): Promise<CommandImportResult> {
        const allSingleBindings: Array<[string, SingleCommandFormData]> = await this.bindings.listSingle();
        const allMultipleBindings: Array<[string, MultipleCommandsFormData]> = await this.bindings.listMultiple();

        const allFormIDMap: Map<string, string[]> = new Map<string, string[]>();
        allFormIDMap.set(CommonConstants.FORM_RESULT_MAP_KEY_SINGLE, allSingleBindings.map(pair => pair[0]));
        allFormIDMap.set(CommonConstants.FORM_RESULT_MAP_KEY_MULTIPLE, allMultipleBindings.map(pair => pair[0]));

        const result = await this.dataModel.importData(json);
        if (result.ok) {
            await this.loadEntries();
            await this.updateForms(allFormIDMap);
        }
        return result;
    }

    /** 导出取数据：当前已加载的全量（不受搜索过滤影响）；导出链本身由 `CommandService.exportData` 直接读库 */
    async toJsonObjectList(): Promise<Array<CommandEntryJsonObject>> {
        return this.allEntries.map((entry: CommandEntryViewModel) => entry.toCommandEntryJsonObject());
    }

    /**
     * 拖拽排序：同步返回（`List.onMove` 要求同步），落库在后台。
     * `from/to` 是**可见列表**的下标，而搜索过滤时可见列表 ≠ 全量底稿，所以先按 id 映回全量位置再重排——
     * 直接拿可见下标去 splice 全量，会拖 A 行改掉 B 行的顺序。
     * 落库失败时按 DB 顺序回滚并调 `onMoveFailed`，页面据此再刷一次（§2.4.5）。
     */
    move(from: number, to: number): boolean {
        const visible: Array<CommandEntryViewModel> = this.entries;
        if (from === to || from < 0 || to < 0 ||
            from >= visible.length || to >= visible.length) {
            return false;
        }

        const fromIndex: number = this.allEntries.findIndex(
            (entry: CommandEntryViewModel) => entry.id === visible[from].id);
        const toIndex: number = this.allEntries.findIndex(
            (entry: CommandEntryViewModel) => entry.id === visible[to].id);
        if (fromIndex < 0 || toIndex < 0) return false;

        const reordered: Array<CommandEntryViewModel> = [...this.allEntries];
        const moved: Array<CommandEntryViewModel> = reordered.splice(fromIndex, 1);
        reordered.splice(toIndex, 0, moved[0]);

        // 重新分配连续的 orderIndex，交仓库整批写入
        reordered.forEach((entry: CommandEntryViewModel, index: number) => {
            entry.orderIndex = index;
        });

        this.allEntries = reordered;
        this.applyFilter();

        const persisted: Array<CommandEntry> = reordered.map((entry: CommandEntryViewModel) => entry.toCommandEntry());
        this.persistOrder(persisted);

        return true;
    }

    /** 发指令：`nickname` 只在结果对话框的标题里用，呈现交给页面 */
    async execute(nickname: string, command: string): Promise<CommandOutcome> {
        try {
            const sender = await this.ensureSender();
            const result = await sender.send(command);
            Logger.debug(this.LOG_TAG, `execute() ${nickname} 响应码 ${result.statusCode}`);
            return this.toOutcome(result);
        } catch (err) {
            Logger.error(this.LOG_TAG, `execute() 错误, ${(err as Error).message}`);
            return CommandOutcome.error(`${(err as Error).message}`);
        }
    }

    /** 发测试指令：另建实例，不污染主实例的地址与密码 */
    async executeTest(address: string, password: string, command: string): Promise<CommandOutcome> {
        this.isProcessing = true;

        try {
            const sender: CommandSender = this.senderFactory();
            sender.setAddress(address);
            sender.setPassword(password);

            const result = await sender.sendTest(command);
            return this.toOutcome(result);
        } catch (err) {
            Logger.error(this.LOG_TAG, `executeTest() 错误, ${(err as Error).message}`);
            return CommandOutcome.error(`${(err as Error).message}`);
        } finally {
            this.isProcessing = false;
        }
    }

    /** 行回报运行状态：维护 `runningIDs`，驱动对应条目的启用 / 禁用 */
    setRunning(id: number, running: boolean): void {
        if (running) this.runningIDs.add(id);
        else this.runningIDs.delete(id);

        // 换一个新 Set：V2 对 Set 的增删也能观察到，这里保留 1.7.1 的替换写法，确保列表刷新
        this.runningIDs = new Set<number>(this.runningIDs);
        Logger.debug(this.LOG_TAG, `正在运行的指令：${Array.from(this.runningIDs).join(', ')}`);
    }

    setCurrentTab(index: number): void {
        this.currentTab = index;
    }

    // 私有方法

    /** 读地址与密码并初始化发送器（规则 1：VM 不 import 平台 kit，只调端口） */
    private async loadSettings(): Promise<void> {
        const address: string = await this.settings.get(CommonConstants.DB_KEY_HOST_INFO_ADDRESS);
        const password: string = await this.settings.get(CommonConstants.DB_KEY_HOST_INFO_PASSWORD);

        const sender: CommandSender = this.senderFactory();
        sender.setAddress(address);
        sender.setPassword(password);
        this.sender = sender;
    }

    /** 没有发送器时补一次初始化：`init()` 之外被调用也不会带着空地址发请求 */
    private async ensureSender(): Promise<CommandSender> {
        if (this.sender !== null) return this.sender;

        await this.loadSettings();
        return this.sender !== null ? this.sender : this.senderFactory();
    }

    /** 领域结果 → 呈现意图：200 弹结果、其他响应码带响应码提示、没拿到响应按错误 */
    private toOutcome(result: CommandSendResult): CommandOutcome {
        if (!result.ok) return CommandOutcome.error(result.error);

        if (result.statusCode === 200) return CommandOutcome.result(result.text);

        return CommandOutcome.notice(`${result.text} 响应码: ${result.statusCode}`);
    }

    /** 按关键字过滤：昵称与指令任一包含即命中，大小写不敏感，首尾空白忽略 */
    private applyFilter(): void {
        const keyword: string = this.keyword.trim().toLowerCase();

        if (keyword === '') {
            this.entries = this.allEntries;
            return;
        }

        this.entries = this.allEntries.filter((entry: CommandEntryViewModel) => {
            return entry.nickname.toLowerCase().includes(keyword) ||
                entry.command.toLowerCase().includes(keyword);
        });
    }

    /** 后台落库：成功即刷新；失败按 DB 顺序回滚并通知页面 */
    private persistOrder(entries: Array<CommandEntry>): void {
        this.dataModel.updateEntriesOrder(entries).then(async (success: boolean) => {
            if (success) {
                await this.loadEntries();
                return;
            }

            Logger.warn(this.LOG_TAG, `拖拽排序失败，按数据库顺序回滚`);
            await this.loadEntries();
            if (this.onMoveFailed) this.onMoveFailed();
        }).catch(async (err: Error) => {
            Logger.error(this.LOG_TAG, `拖拽排序异常: ${err}`);
            await this.loadEntries();
            if (this.onMoveFailed) this.onMoveFailed();
        });
    }

    // 删除条目后重算每个条目的位置并同步到数据库（1.7.1 的 updateEntriesOrder）
    private async updateEntriesOrder(): Promise<boolean> {
        const reorderedEntries: Array<CommandEntry> = this.allEntries.map(
            (entry: CommandEntryViewModel, index: number) => {
                entry.orderIndex = index;
                return entry.toCommandEntry();
            }
        );

        const success: boolean = await this.dataModel.updateEntriesOrder(reorderedEntries);
        if (success) await this.loadEntries();
        return success;
    }

    /** 刷新受影响卡片：绑定还在就写绑定内容，已解绑就写该类型的空卡（1.7.1 的 `?? formID` 口径） */
    private async updateForms(formIDMap: Map<string, string[]>): Promise<boolean> {
        const singleFormIDs: string[] = formIDMap.get(CommonConstants.FORM_RESULT_MAP_KEY_SINGLE) ?? [];
        const multipleFormIDs: string[] = formIDMap.get(CommonConstants.FORM_RESULT_MAP_KEY_MULTIPLE) ?? [];

        if (singleFormIDs.length === 0 && multipleFormIDs.length === 0) return true;

        let allSuccess = true;

        for (const formID of singleFormIDs) {
            try {
                const formData: SingleCommandFormData | null = await this.bindings.getSingle(formID);
                const written: boolean = await this.publisher.publish(formID,
                    formData ?? new SingleCommandFormData(formID, false));

                if (!written) allSuccess = false;
                Logger.debug(this.LOG_TAG, `已更新单指令卡片, formID = ${formID}`);
            } catch (err) {
                allSuccess = false;
                Logger.error(this.LOG_TAG, `更新单指令卡片失败, formID = ${formID}, ${err}`);
            }
        }

        for (const formID of multipleFormIDs) {
            try {
                const formData: MultipleCommandsFormData | null = await this.bindings.getMultiple(formID);
                const written: boolean = await this.publisher.publish(formID,
                    formData ?? new MultipleCommandsFormData(formID, false));

                if (!written) allSuccess = false;
                Logger.debug(this.LOG_TAG, `已更新多指令卡片, formID = ${formID}`);
            } catch (err) {
                allSuccess = false;
                Logger.error(this.LOG_TAG, `更新多指令卡片失败, formID = ${formID}, ${err}`);
            }
        }

        return allSuccess;
    }
}
