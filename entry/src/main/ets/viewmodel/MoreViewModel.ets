import Logger from '../common/utils/Logger';
import { AppSettings, ColorMode } from '../domain/model/AppSettings';
import { ExportJsonObject } from '../domain/model/JsonObjects';
import { AppSettingsRepository } from '../domain/repository/AppSettingsRepository';
import { CommandImportResult } from '../domain/service/CommandImportService';
import { BackupResult, CommandMutationResult, CommandService } from '../domain/service/CommandService';
import { appSettingsRepository } from '../domain/service/DependencyWiring';
import CommandListViewModel from './CommandListViewModel';

/** 失败类别（设计 §2.4.2）：`bindings` = 绑定未清理（X2），`reason` = 非法导入的可读原因，`error` = 抛错 */
export type MoreFailureKind = 'none' | 'bindings' | 'reason' | 'error';

/**
 * 更多页一次动作的结果（设计 §2.4.2）。`cancelled` 供「用户取消选文件 / 取消确认框」静默处理。
 */
export class MoreActionResult {
    ok: boolean = false;
    cancelled: boolean = false;
    failure: MoreFailureKind = 'none';
    reason: string = '';

    static succeed(): MoreActionResult {
        const result = new MoreActionResult();
        result.ok = true;
        return result;
    }

    static cancel(): MoreActionResult {
        const result = new MoreActionResult();
        result.cancelled = true;
        return result;
    }

    static fail(failure: MoreFailureKind, reason: string): MoreActionResult {
        const result = new MoreActionResult();
        result.failure = failure;
        result.reason = reason;
        return result;
    }
}

/**
 * 更多页的 VM（设计 §2.4.2）。
 *
 * 颜色模式：`AppStorageV2` 的 `AppSettings` 由页面 `AppStorageV2.connect` 后经 `attachSettings` 交过来，
 * 本类只写它并经 `AppSettingsRepository` 落盘；平台调用 `getApplicationContext().setColorMode` 由页面接着做
 * （§2.9 的三段分工：Ability 供 context、VM 发意图、data 只落盘）。
 *
 * 导出 / 导入：窗口上下文由页面按不透明 `Object` 传进来，逐层转到数据层的 `TransferFiles` 才还原
 * （§3.3 的调用链；规则 1 禁 `domain/` 与 `viewmodel/` import `@kit.AbilityKit`）。
 */
@ObservedV2
export default class MoreViewModel {
    private LOG_TAG = '[MoreViewModel]';

    @Trace versionName: string = '';
    @Trace versionCode: string = '';
    // 导入进行中，驱动遮罩
    @Trace isProcessing: boolean = false;

    // `AppStorageV2` 连接得到的可观察设置对象，全应用同一份（不在这里另存一份颜色模式）
    private settings: AppSettings | null = null;
    private appSettings: AppSettingsRepository;
    private commandService: CommandService;
    private list: CommandListViewModel;

    constructor(list: CommandListViewModel,
                appSettings: AppSettingsRepository = appSettingsRepository(),
                commandService: CommandService = new CommandService()) {
        this.list = list;
        this.appSettings = appSettings;
        this.commandService = commandService;
    }

    /** 当前领域颜色模式；读的是共享可观察对象的 `@Trace` 字段，不复制第二份 */
    get colorMode(): ColorMode {
        return this.settings ? this.settings.colorMode : ColorMode.FOLLOW_SYSTEM;
    }

    /** 接收 `AppStorageV2.connect` 得到的可观察设置对象 */
    attachSettings(settings: AppSettings): void {
        this.settings = settings;
    }

    /** 版本号由页面读 `bundleManager` 后交进来（平台调用不进 VM，§2.4.1） */
    setVersion(name: string, code: string): void {
        this.versionName = name;
        this.versionCode = code;
    }

    /** 选中即写共享设置并经仓库落盘；同值即返回。平台颜色模式由页面接着应用 */
    async selectColorMode(mode: ColorMode): Promise<void> {
        if (this.colorMode === mode) return;

        if (this.settings) this.settings.colorMode = mode;

        const saved: boolean = await this.appSettings.set(mode);
        if (!saved) Logger.warn(this.LOG_TAG, `selectColorMode() 落盘失败, ${mode}`);
    }

    /** 导出：领域层组 JSON 并存盘；用户取消保存位置不算失败 */
    async export(context: Object): Promise<MoreActionResult> {
        const result: BackupResult = await this.commandService.exportData(context);

        if (result.ok) return MoreActionResult.succeed();
        if (result.cancelled) {
            Logger.warn(this.LOG_TAG, `export() 导出取消`);
            return MoreActionResult.cancel();
        }

        // 到这里只剩失败：取消已单独处理
        return MoreActionResult.fail('error', result.reason);
    }

    /** 选文件 → 读 → 解析 → `CommandListViewModel.importData`；遮罩从选完文件之后才升起（1.7.1 同一时机） */
    async pickAndImport(context: Object): Promise<MoreActionResult> {
        let uris: string[] = [];

        try {
            uris = await this.commandService.pickBackupFile(context);
        } catch (err) {
            Logger.error(this.LOG_TAG, `pickAndImport() 选择文件失败, ${err}`);
            return MoreActionResult.fail('error', `${err}`);
        }

        if (uris.length === 0) {
            Logger.warn(this.LOG_TAG, `pickAndImport() 未选择文件`);
            return MoreActionResult.cancel();
        }

        this.isProcessing = true;

        try {
            const backup: ExportJsonObject = await this.commandService.readBackup(uris);
            const result: CommandImportResult = await this.list.importData(backup);

            if (result.ok) return MoreActionResult.succeed();

            // 导入成功但绑定没清掉：不能按成功报，界面提示重新绑定（X2）
            if (!result.bindingsCleared) return MoreActionResult.fail('bindings', result.reason);

            return MoreActionResult.fail('reason', result.reason);
        } catch (err) {
            Logger.error(this.LOG_TAG, `pickAndImport() 导入失败, ${err}`);
            return MoreActionResult.fail('error', `${err}`);
        } finally {
            this.isProcessing = false;
        }
    }

    /** 清空全部指令：走列表 VM，卡片刷新与列表重载都在那条路上 */
    async clearAll(): Promise<MoreActionResult> {
        const result: CommandMutationResult = await this.list.clearAllEntries();

        if (result.ok) return MoreActionResult.succeed();

        return MoreActionResult.fail(result.unbindFailed ? 'bindings' : 'error', result.reason);
    }
}
