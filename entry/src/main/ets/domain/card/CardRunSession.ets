// 卡片运行会话登记表（进程内单例）
// 按 formID 登记当前运行 token 与中断函数：仲裁“谁有权写终态”，回答“这张卡还有没有在跑会话”。
// 运行 Ability 是 multiton，同一应用的 UIAbility 实例共享进程，取消实例由此拿到运行实例登记的中断函数。
// ArkTS 单线程事件循环内，“判 finished + 置位”是一个原子段，无需额外锁。

export class RunToken {
    readonly formID: string;
    readonly seq: number;        // 全局递增，区分同一张卡的前后两次运行
    cancelled: boolean = false;
    finished: boolean = false;   // 终态已由本 token 写过
    abandoned: boolean = false;  // 实例已销毁，终态没有写

    constructor(formID: string, seq: number) {
        this.formID = formID;
        this.seq = seq;
    }
}

export enum RunCancelResult {
    CANCELLED = 'cancelled',     // 有在跑会话：已标记取消并调用中断函数
    ENDED = 'ended',             // 该会话终态已写过，调用方不写卡片
    NONE = 'none'                // 没有在跑会话：调用方写兜底终态
}

// 中断函数与它的 token 绑定，避免旧会话的中断函数影响新会话
class AbortHandler {
    readonly token: RunToken;
    readonly abort: () => void;

    constructor(token: RunToken, abort: () => void) {
        this.token = token;
        this.abort = abort;
    }
}

export class CardRunSession {
    private static instance: CardRunSession | null = null;

    private tokens: Map<string, RunToken> = new Map<string, RunToken>();
    private abortHandlers: Map<string, AbortHandler> = new Map<string, AbortHandler>();
    private seq: number = 0;

    private constructor() {}

    static getInstance(): CardRunSession {
        if (!CardRunSession.instance) CardRunSession.instance = new CardRunSession();
        return CardRunSession.instance;
    }

    // 建立会话：同一 formID 以最新 token 为准，旧 token 失去终态写入权
    begin(formID: string): RunToken {
        const token = new RunToken(formID, ++this.seq);

        this.tokens.set(formID, token);
        this.abortHandlers.delete(formID);

        return token;
    }

    // 运行实例登记中断函数；旧 token、已写终态或已弃置的 token 都不能覆盖当前会话的中断函数
    registerAbort(token: RunToken, abort: () => void): void {
        if (this.tokens.get(token.formID) !== token) return;
        if (token.finished || token.abandoned) return;

        this.abortHandlers.set(token.formID, new AbortHandler(token, abort));
    }

    // 取消：有在跑会话则标记取消并调中断函数；终态由运行实例用同一 token 写
    cancel(formID: string): RunCancelResult {
        const token = this.tokens.get(formID);

        if (!token || token.abandoned) return RunCancelResult.NONE;
        if (token.finished) return RunCancelResult.ENDED;

        token.cancelled = true;
        this.abortInFlight(token);

        return RunCancelResult.CANCELLED;
    }

    // 只调中断函数（超时路径用）；已结束或已弃置的会话没有在途请求
    // 中断函数自身负责把失败记入日志（ASF.cancel 内部已包 try/catch），这里不吞异常
    abortInFlight(token: RunToken): void {
        const handler = this.abortHandlers.get(token.formID);

        if (!handler || handler.token !== token) return;

        this.abortHandlers.delete(token.formID);
        handler.abort();
    }

    // 这张卡当前是否仍由该 token 在跑：未被替换、未写终态、未弃置、未取消
    // 运行路径用它当写卡片的闸门；被判 false 的 token 不得再写卡片
    isActive(token: RunToken): boolean {
        if (this.tokens.get(token.formID) !== token) return false;
        if (token.finished || token.abandoned || token.cancelled) return false;

        return true;
    }

    // 终态写入闸门：只有当前会话、未写过终态、未弃置的 token 才能抢到写入权
    tryFinish(token: RunToken): boolean {
        if (token.finished || token.abandoned) return false;
        if (this.tokens.get(token.formID) !== token) return false;

        token.finished = true;

        return true;
    }

    // 会话正常结束：清中断函数，会话留在登记表里作为“已结束会话”，直到下一次 begin 替换
    release(token: RunToken): void {
        token.finished = true;
        this.clearAbortHandler(token);
    }

    // 实例销毁且没有写过终态：会话弃置，此后取消按“无在跑会话”走兜底终态
    abandon(token: RunToken): void {
        token.abandoned = true;
        this.clearAbortHandler(token);
    }

    private clearAbortHandler(token: RunToken): void {
        const handler = this.abortHandlers.get(token.formID);

        if (handler && handler.token === token) this.abortHandlers.delete(token.formID);
    }
}
