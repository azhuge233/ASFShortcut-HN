import Logger from '../../common/utils/Logger';
import MultipleCommandsFormData from '../model/MultipleCommandsFormData';
import WidgetCommand from '../model/WidgetCommand';
import { CardPublisher } from '../repository/CardPublisher';
import { FormBindingRepository } from '../repository/FormBindingRepository';
import { cardPublisher, formBindingRepository } from '../service/DependencyWiring';
import { CardAdapter, CardKind, CardRunRequest, CardTerminal } from './CardAdapter';

/**
 * 多指令卡的卡片类型差异（设计 §2.5）：参数解析（含 `commandList` 的数组 / JSON 串两种形态）、
 * `MultipleCommandsFormData` 组装、绑定读取、终态文案。
 * 写入统一经 `CardPublisher.publishWithRetry`——运行路径的既有行为是失败重试一次。
 */
export class MultipleCardAdapter implements CardAdapter {
    readonly kind: CardKind = 'multiple';

    private readonly logTag: string = '[MultipleCardAdapter]';

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
        request.command = params['command'] as string;
        request.commandList = this.parseCommandList(params['commandList']);
        this.request = request;

        Logger.debug(this.logTag,
            `parseRunRequest() 从 call 事件获得参数: ${request.formID}, ${request.shortcutID}, ${request.command}, ${request.commandList}`);

        return request;
    }

    // F3：参数到手即写运行态，不读 DB / PM
    async writeRunningEarly(req: CardRunRequest): Promise<void> {
        const formData = new MultipleCommandsFormData(req.formID, true);

        formData.commandList = req.commandList;
        formData.isRunning = true;

        await this.publisher.publishWithRetry(req.formID, formData);
    }

    // 用绑定刷新 commandList 后写运行态；取绑定期间可能已写终态，写入前再检一次
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
            const formData = await this.bindings.getMultiple(formID);

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

    // `commandList` 可能是数组，也可能是 JSON 串（卡片 side 两种形态都出现过）
    private parseCommandList(raw: Object): Array<WidgetCommand> {
        if (Array.isArray(raw)) return raw as Array<WidgetCommand>;

        if (typeof raw === 'string') {
            try {
                const parsed = JSON.parse(raw) as Array<WidgetCommand>;
                return Array.isArray(parsed) ? parsed : [];
            } catch (err) {
                Logger.warn(this.logTag, `parseCommandList() commandList 解析失败, ${err}`);
                return [];
            }
        }

        return [];
    }

    // 以 call 参数为底，绑定存在时用绑定里的 commandList 覆盖（与重构前 `getNewFormData` 同口径）
    private async getNewFormData(formID: string,
                                 request: CardRunRequest | null): Promise<MultipleCommandsFormData> {
        const formData = new MultipleCommandsFormData(formID, true);
        const fallbackCommandList: Array<WidgetCommand> = request ? request.commandList : [];

        try {
            const bound = await this.bindings.getMultiple(formID);
            formData.commandList = bound ? bound.commandList : fallbackCommandList;
        } catch (err) {
            Logger.warn(this.logTag, `getNewFormData() 读取绑定失败，使用 call 参数, ${err}`);
            formData.commandList = fallbackCommandList;
        }

        return formData;
    }
}
