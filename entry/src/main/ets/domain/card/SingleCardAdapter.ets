import Logger from '../../common/utils/Logger';
import SingleCommandFormData from '../model/SingleCommandFormData';
import { CardPublisher } from '../repository/CardPublisher';
import { FormBindingRepository } from '../repository/FormBindingRepository';
import { cardPublisher, formBindingRepository } from '../service/DependencyWiring';
import { CardAdapter, CardKind, CardRunRequest, CardTerminal } from './CardAdapter';

/**
 * 单指令卡的卡片类型差异（设计 §2.5）：参数解析、`SingleCommandFormData` 组装、
 * 绑定读取、终态文案。写入统一经 `CardPublisher.publishWithRetry`——
 * 运行路径的既有行为是失败重试一次（`docs/design/modules/card-run-session.md §2.6`）。
 */
export class SingleCardAdapter implements CardAdapter {
    readonly kind: CardKind = 'single';

    private readonly logTag: string = '[SingleCardAdapter]';

    // 终态文案由 ability 层解析后传入（`domain/` 不读资源，设计 §1.5 规则 1）
    private readonly cancelledText: string;
    private readonly failedText: string;

    private readonly bindings: FormBindingRepository;
    private readonly publisher: CardPublisher;

    // 本实例解析出的运行参数：终态重建时绑定缺失用它兜底（模块档 §2.6 `finishRun`）
    private request: CardRunRequest | null = null;

    constructor(cancelledText: string, failedText: string,
                bindings: FormBindingRepository = formBindingRepository(),
                publisher: CardPublisher = cardPublisher()) {
        this.cancelledText = cancelledText;
        this.failedText = failedText;
        this.bindings = bindings;
        this.publisher = publisher;
    }

    parseRunRequest(params: Record<string, Object>): CardRunRequest | null {
        const formID: string = params['formID'] as string;

        if (!formID) {
            Logger.warn(this.logTag, `parseRunRequest() formID 为空，忽略本次运行`);
            return null;
        }

        const request = new CardRunRequest(formID);
        request.shortcutID = params['shortcutID'] as number;
        request.nickname = params['nickname'] as string;
        request.command = params['command'] as string;
        this.request = request;

        Logger.debug(this.logTag,
            `parseRunRequest() 从 call 事件获得参数: ${request.formID}, ${request.shortcutID}, ${request.nickname}, ${request.command}`);

        return request;
    }

    // F3：参数到手即写运行态，不读 DB / PM
    async writeRunningEarly(req: CardRunRequest): Promise<void> {
        const formData = new SingleCommandFormData(req.formID, true);

        formData.shortcutID = req.shortcutID;
        formData.nickname = req.nickname;
        formData.command = req.command;
        formData.isRunning = true;

        await this.publisher.publishWithRetry(req.formID, formData);
    }

    // 用绑定刷新昵称后写运行态；取绑定期间可能已写终态，写入前再检一次
    async refreshRunningFromBinding(req: CardRunRequest): Promise<void> {
        const formData = await this.getNewFormData(req.formID, req);

        if (!req.isActive()) {
            Logger.debug(this.logTag, `refreshRunningFromBinding() 会话已不活，不再写运行态: ${req.formID}`);
            return;
        }

        formData.isRunning = true;

        await this.publisher.publishWithRetry(req.formID, formData);
    }

    async writeTerminal(formID: string, outcome: CardTerminal): Promise<boolean> {
        const formData = await this.getNewFormData(formID, this.request);
        const runResult: string = outcome.text(this.cancelledText, this.failedText);

        formData.runResult = runResult; // 显示终态
        formData.isRunning = false;

        const written: boolean = await this.publisher.publishWithRetry(formID, formData);
        if (written) Logger.debug(this.logTag, `writeTerminal() 已写终态: ${runResult}`);

        return written;
    }

    // 兜底终态：会话已丢、真实结果未知；用户做的是取消，写「已取消」而不是失败
    async writeFallbackTerminal(formID: string): Promise<void> {
        try {
            const formData = await this.bindings.getSingle(formID);

            if (!formData) {
                Logger.warn(this.logTag, `writeFallbackTerminal() 无绑定，不写卡片: ${formID}`);
                return;
            }

            formData.isRunning = false;
            formData.runResult = this.cancelledText;

            const written = await this.publisher.publishWithRetry(formID, formData);

            Logger.info(this.logTag, `writeFallbackTerminal() 无在跑会话，写兜底终态${written ? '成功' : '失败'}: ${formID}`);
        } catch (err) {
            Logger.error(this.logTag, `writeFallbackTerminal() 错误, ${err}`);
        }
    }

    // 以 call 参数为底，绑定存在时用绑定里的昵称覆盖（与重构前 `getNewFormData` 同口径）
    private async getNewFormData(formID: string, request: CardRunRequest | null): Promise<SingleCommandFormData> {
        const formData = new SingleCommandFormData(formID, true);

        if (request) {
            formData.shortcutID = request.shortcutID;
            formData.nickname = request.nickname;
            formData.command = request.command;
        }

        try {
            const bound = await this.bindings.getSingle(formID);
            if (bound) formData.nickname = bound.nickname;
        } catch (err) {
            Logger.warn(this.logTag, `getNewFormData() 读取绑定失败，使用 call 参数, ${err}`);
        }

        return formData;
    }
}
