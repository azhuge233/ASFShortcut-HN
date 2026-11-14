import Logger from '../../common/utils/Logger';
import CommonConstants from '../../common/constants/CommonConstants';
import { releaseKeepAlive, requestKeepAlive } from '../../common/utils/KeepAlive';
import { Database } from '../../data/Database';
import { FormBindingStore } from '../../data/store/FormBindingStore';
import { CommandRepository } from '../repository/CommandRepository';
import { CommandSender } from '../repository/CommandSender';
import { SettingsRepository } from '../repository/SettingsRepository';
import { commandRepository, createCommandSender, settingsRepository } from '../service/DependencyWiring';
import { CardAdapter, CardRunRequest, CardTerminal } from './CardAdapter';
import { CardRunSession, RunCancelResult, RunToken } from './CardRunSession';

/**
 * 卡片运行编排（设计 §2.5、`docs/design/modules/card-run-session.md §2.6`）：
 * 运行 / 取消的步骤顺序、15 秒硬超时、短时任务、唯一终态写入点。
 *
 * 卡片类型差异在 `CardAdapter` 的两个实现里，会话仲裁在 `CardRunSession`；
 * 本类不含卡片字段形状、PM 键与数据类构造。
 *
 * 两个运行 Ability 各持一个实例（`multiton`：每个 `call` 一个新实例），
 * 生命周期钩子只做转发。
 */
export class CardRunPipeline {
    private readonly adapter: CardAdapter;
    private readonly logTag: string;

    private readonly session: CardRunSession;
    private readonly sender: CommandSender;
    private readonly commands: CommandRepository;
    private readonly settings: SettingsRepository;

    private readonly db: Database = Database.getInstance();
    private readonly bindings: FormBindingStore = FormBindingStore.getInstance();

    // 应用上下文由 ability 层注入：`domain/` 禁用 AbilityKit，只有入口环拿得到它
    private appContext: Context | null = null;

    private runToken: RunToken | null = null;   // 本实例发起的运行会话；取消实例不持有 token
    private timeoutID: number = -1;             // 15 秒硬超时计时器，-1 表示不在计时
    private delayRequestID: number = -1;        // 短时任务 requestId，-1 表示未申请

    constructor(adapter: CardAdapter, logTag: string,
                session: CardRunSession = CardRunSession.getInstance(),
                sender: CommandSender = createCommandSender(),
                commands: CommandRepository = commandRepository(),
                settings: SettingsRepository = settingsRepository()) {
        this.adapter = adapter;
        this.logTag = logTag;
        this.session = session;
        this.sender = sender;
        this.commands = commands;
        this.settings = settings;
    }

    /** ability 在 `onCreate` 里注入应用上下文（依赖初始化要用它） */
    attachContext(appContext: Context): void {
        this.appContext = appContext;
    }

    // 运行路径：早写运行态 → 15 秒硬超时 → 初始化 → 校正指令 → 刷运行态 → 发请求 → 写终态
    async run(params: Record<string, Object>): Promise<void> {
        const request: CardRunRequest | null = this.adapter.parseRunRequest(params);
        if (!request) return;

        const token: RunToken = this.session.begin(request.formID);
        this.runToken = token;

        // 读绑定期间可能已写终态：adapter 发起写入前用这个谓词再检一次
        request.isActive = (): boolean => this.isSessionLive(token);

        // F3：参数到手即写运行态，不读 DB / PM。写失败也要落到终态，
        // 否则会话既不 tryFinish 也不 abandon，卡片会停在运行态（15 秒计时还没起）
        try {
            await this.adapter.writeRunningEarly(request);
        } catch (err) {
            Logger.error(this.logTag, `run() 早写运行态失败, ${err}`);
            await this.finishRun(token, null);
            return;
        }

        // F2：15 秒硬超时，超时与失败走同一终态函数
        this.startRunTimeout(token);

        try {
            if (!this.isSessionLive(token)) return await this.finishRun(token, null);

            await this.initServices();
            if (!this.isSessionLive(token)) return await this.finishRun(token, null);

            await this.correctCommandFromDB(request);
            if (!this.isSessionLive(token)) return await this.finishRun(token, null);

            await this.adapter.refreshRunningFromBinding(request);
            if (!this.isSessionLive(token)) return await this.finishRun(token, null);

            this.session.registerAbort(token, () => this.sender.cancel());

            let payload: string | null = null;
            const sendResult = await this.sender.send(request.command);
            if (sendResult.ok) payload = sendResult.text;
            else Logger.error(this.logTag, `run() 指令执行失败, ${sendResult.error}`);

            await this.finishRun(token, payload);
        } catch (err) {
            Logger.error(this.logTag, `run() 错误, ${err}`);
            await this.finishRun(token, null);
        }
    }

    // 取消路径：有在跑会话只标记取消并中断请求；无在跑会话时写兜底终态
    async cancel(params: Record<string, Object>): Promise<void> {
        const formID: string = params['formID'] as string;

        if (!formID) {
            Logger.warn(this.logTag, `cancel() formID 为空，忽略本次取消`);
            return;
        }

        const result: RunCancelResult = this.session.cancel(formID);

        if (result === RunCancelResult.CANCELLED) {
            Logger.info(this.logTag, `cancel() 已标记取消并中断在途请求，终态由运行实例写: ${formID}`);
            return;
        }

        if (result === RunCancelResult.ENDED) {
            Logger.info(this.logTag, `cancel() 会话已写终态，不写卡片: ${formID}`);
            return;
        }

        Logger.info(this.logTag, `cancel() 无在跑会话，写兜底终态: ${formID}`);

        try {
            await this.initServices();
            await this.adapter.writeFallbackTerminal(formID);
        } catch (err) {
            Logger.error(this.logTag, `cancel() 写兜底终态错误, ${err}`);
        }
    }

    // 退后台时申请短时任务，避免运行期间被后台策略提前回收；保活是尽力而为，失败不改变业务结果
    // 判据照 `docs/design/modules/card-run-session.md §2.7`：没有当前 token，或 isActive 为假
    // （已 finished / abandoned / cancelled）就不申请
    onBackground(): void {
        const token = this.runToken;

        if (!token || !this.session.isActive(token)) {
            Logger.debug(this.logTag, `onBackground() 无未结束的运行会话，不申请短时任务`);
            return;
        }

        if (this.delayRequestID !== -1) {
            Logger.debug(this.logTag, `onBackground() 短时任务已申请，跳过`);
            return;
        }

        // 封装内部吃掉异常并返回 -1：保活失败不改变业务结果，硬超时兜底
        this.delayRequestID = requestKeepAlive('卡片指令运行', CommonConstants.FORM_RUN_TIMEOUT_MS, () => {
            Logger.warn(this.logTag, `短时任务即将到期，运行仍由 15 秒硬超时兜底`);
        });
    }

    // 实例被销毁但进程可能仍存活：弃置会话，让后续取消按“无在跑会话”走兜底终态
    onDestroy(): void {
        const token = this.runToken;

        if (token && !token.finished) {
            this.session.abandon(token);
            Logger.warn(this.logTag, `onDestroy() 运行实例被销毁，弃置会话（未写终态）`);
        }

        this.runToken = null;
        this.clearRunTimeout();
        this.releaseKeepAliveRequest();
    }

    /** 单测观察点：15 秒计时是否在跑（`false` = 已归还） */
    isTimingOut(): boolean {
        return this.timeoutID !== -1;
    }

    /** 单测观察点：短时任务是否已申请（`false` = 已归还） */
    hasKeepAlive(): boolean {
        return this.delayRequestID !== -1;
    }

    /**
     * 唯一的卡片终态写入：成功 / 失败 / 超时 / 取消都走这里，由 `tryFinish` 一次性仲裁。
     * 也由超时回调调用，因此是公开方法；单测据此断言「晚到结果不写卡片」（用例 U12）。
     */
    async finishRun(token: RunToken, payload: string | null): Promise<void> {
        if (!this.session.tryFinish(token)) {
            Logger.debug(this.logTag, `finishRun() 非当前会话，丢弃结果: ${token.formID}, seq ${token.seq}`);
            // 不写卡片，但本实例占用的计时器与短时任务要归还，避免占用并发额度
            this.clearRunTimeout();
            this.releaseKeepAliveRequest();
            return;
        }

        this.clearRunTimeout();

        try {
            const written: boolean = await this.adapter.writeTerminal(token.formID, CardTerminal.of(token.cancelled, payload));

            if (!written) Logger.error(this.logTag, `finishRun() 终态两次写入均失败，卡片停在运行态: ${token.formID}`);
        } catch (err) {
            Logger.error(this.logTag, `finishRun() 写卡片错误, ${err}`);
        } finally {
            this.session.release(token);
            this.releaseKeepAliveRequest();
        }
    }

    // 初始化数据依赖：数据库、首选项、ASF 地址与密码
    private async initServices(): Promise<void> {
        const appContext = this.appContext;

        if (!appContext) throw new Error('应用上下文未注入，无法初始化数据依赖');

        this.db.init(appContext);
        this.bindings.init(appContext);

        const asfAddr: string = await this.settings.get(CommonConstants.DB_KEY_HOST_INFO_ADDRESS);
        const asfPwd: string = await this.settings.get(CommonConstants.DB_KEY_HOST_INFO_PASSWORD);

        this.sender.setAddress(asfAddr);
        this.sender.setPassword(asfPwd);
    }

    // 对比卡片指令与数据库指令，不一致时使用数据库指令（防止执行时卡片 UI 没有及时更新）
    private async correctCommandFromDB(request: CardRunRequest): Promise<void> {
        const entry = await this.commands.getByID(request.shortcutID);
        if (!entry) return;

        const dbCommand: string = entry.command;
        if (dbCommand === request.command) return;

        Logger.warn(this.logTag, `DB 指令: ${dbCommand}, 卡片指令: ${request.command}, 不一致，使用 DB 指令`);
        request.command = dbCommand;
    }

    // 会话是否仍由本实例持有卡片写入权：已取消、已写终态、已弃置、已被新运行替换都不再写卡片
    private isSessionLive(token: RunToken): boolean {
        return this.session.isActive(token);
    }

    private startRunTimeout(token: RunToken): void {
        this.clearRunTimeout();

        this.timeoutID = setTimeout(() => {
            this.timeoutID = -1;
            Logger.warn(this.logTag, `15 秒硬超时：中断在途请求并写失败终态`);
            this.session.abortInFlight(token);
            this.finishRun(token, null).then();
        }, CommonConstants.FORM_RUN_TIMEOUT_MS);
    }

    private clearRunTimeout(): void {
        if (this.timeoutID === -1) return;

        clearTimeout(this.timeoutID);
        this.timeoutID = -1;
    }

    private releaseKeepAliveRequest(): void {
        if (this.delayRequestID === -1) return;

        releaseKeepAlive(this.delayRequestID);
        Logger.debug(this.logTag, `releaseKeepAliveRequest() 已释放短时任务`);

        this.delayRequestID = -1;
    }
}
