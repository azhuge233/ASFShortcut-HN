import WidgetCommand from '../model/WidgetCommand';

/**
 * 卡片类型差异的接口（设计 §2.5）：`call` 参数解析、卡片数据组装、绑定读取、终态文案归属。
 * 会话仲裁、超时、重试策略都不在这里。
 *
 * 两个实现各服务一种卡片（`SingleCardAdapter` / `MultipleCardAdapter`）；运行编排在
 * `CardRunPipeline`，本接口只回答「这张卡片怎么读、怎么写」。
 */

export type CardKind = 'single' | 'multiple';

/** 一次运行的入参：pipeline 只读 `formID`，其余字段由各自的 adapter 消费 */
export class CardRunRequest {
    readonly formID: string;

    shortcutID: number = -1;
    nickname: string = '';
    command: string = '';
    commandList: Array<WidgetCommand> = [];

    /**
     * 写入前的会话活性复检（`docs/design/modules/card-run-session.md §2.6` 末段）：
     * 读绑定期间可能已写终态，发起写入前再检一次。
     * 由 `CardRunPipeline` 在 `begin` 之后注入；未注入时恒为 true（单测与纯解析场景）。
     */
    isActive: () => boolean = () => true;

    constructor(formID: string) {
        this.formID = formID;
    }
}

/** 一次运行的结局：取消 / 失败 / 成功（成功带结果文本） */
export class CardTerminal {
    readonly cancelled: boolean;
    readonly payload: string | null;

    private constructor(cancelled: boolean, payload: string | null) {
        this.cancelled = cancelled;
        this.payload = payload;
    }

    /**
     * 结局判定（`docs/design/modules/card-run-session.md §2.6`）：
     * `cancelled` 优先，其次 `payload === null` 判失败，否则成功。
     */
    static of(cancelled: boolean, payload: string | null): CardTerminal {
        return new CardTerminal(cancelled, payload);
    }

    /** 终态文案；两个文案键由 adapter 从 ability 层拿到（`domain/` 不读资源） */
    text(cancelledText: string, failedText: string): string {
        if (this.cancelled) return cancelledText;
        if (this.payload === null) return failedText;
        return this.payload;
    }
}

export interface CardAdapter {
    /** 卡片类型，用于日志与两分支等价性核对 */
    readonly kind: CardKind;

    /**
     * 解析 `call` 参数；`formID` 缺失时返回 null（本次运行忽略）。
     *
     * 前提：一个 adapter 实例只服务一次运行——两个运行 Ability 是 `multiton`，
     * 每次 `call` 至少拉起一个新实例、新 adapter，所以「本次请求」可以存在实例字段里。
     */
    parseRunRequest(params: Record<string, Object>): CardRunRequest | null;

    /** 早写运行态（不读 DB / PM，设计 F3） */
    writeRunningEarly(req: CardRunRequest): Promise<void>;

    /** 用绑定刷新卡片字段后重写运行态；写入前用 `req.isActive()` 复检 */
    refreshRunningFromBinding(req: CardRunRequest): Promise<void>;

    /** 写一次终态，返回是否写入成功 */
    writeTerminal(formID: string, outcome: CardTerminal): Promise<boolean>;

    /** 无在跑会话时的兜底终态（取消路径专用）；绑定缺失则只记日志、不写卡片 */
    writeFallbackTerminal(formID: string): Promise<void>;
}
