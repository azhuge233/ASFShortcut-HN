import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { http } from '@kit.NetworkKit';
import { backgroundTaskManager } from '@kit.BackgroundTasksKit';

import CommonUtils from '../../common/utils/CommonUtils';
import Logger from '../../common/utils/Logger';
import { ASF } from '../../common/utils/ASF';
import { DB } from '../../common/utils/DB';
import { PM } from '../../common/utils/PM';
import { CardRunSession, RunCancelResult, RunToken } from '../../common/utils/CardRunSession';
import CommonConstants from '../../common/constants/CommonConstants';
import SingleCommandFormData from '../model/SingleCommandFormData';

export default class SingleCommandWidgetEntryAbility extends UIAbility {
    private LOG_TAG = "[SingleCommandWidgetEntryAbility]";

    private db = DB.getInstance();
    private pm = PM.getInstance();
    private asf = new ASF();

    private formID: string = '';
    private shortcutID: number = -1;
    private nickname: string = '';
    private command: string = '';

    private runToken: RunToken | null = null;   // 本实例发起的运行会话；取消实例不持有 token
    private timeoutID: number = -1;             // 15 秒硬超时计时器，-1 表示不在计时
    private delayRequestID: number = -1;        // 短时任务 requestId，-1 表示未申请

    // 如果UIAbility启动，在收到call事件后会触发onCreate生命周期回调
    onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
        Logger.debug(this.LOG_TAG, `onCreate()`);

        // Logger.warn(this.LOG_TAG, JSON.stringify(want));

        // 直接通过 want 获取 call 事件参数
        if (want.parameters && want.parameters.params) {
            let params: Record<string, Object>;
            try {
                params = JSON.parse(want.parameters.params as string) as Record<string, Object>;
            } catch (err) {
                Logger.error(this.LOG_TAG, `onCreate() 参数解析失败, ${err}`);
                return;
            }

            const method = params['method'] as string;

            CommonUtils.vibrate(CommonConstants.VIBRATE_EFFECT_ID_HARD);

            if (method === CommonConstants.FORM_CALL_RUN) this.handleRunMethod(params).then();
            else if (method === CommonConstants.FORM_CALL_CANCEL) this.handleCancelMethod(params).then();
            else Logger.warn(this.LOG_TAG, `onCreate() 未知 method`);
        } else Logger.warn(this.LOG_TAG, `onCreate() want 为空`);
    }

    // 实例被销毁但进程可能仍存活：弃置会话，让后续取消按“无在跑会话”走兜底终态
    onDestroy(): void {
        Logger.debug(this.LOG_TAG, `onDestroy()`);

        const token = this.runToken;
        if (token && !token.finished) {
            CardRunSession.getInstance().abandon(token);
            Logger.warn(this.LOG_TAG, `onDestroy() 运行实例被销毁，弃置会话（未写终态）`);
        }

        this.runToken = null;
        this.clearRunTimeout();
        this.releaseKeepAlive();
    }

    // 退后台时申请短时任务，避免运行期间被后台策略提前回收；保活是尽力而为，失败不改变业务结果
    // 不用 isActive 当判据：已取消但终态未写的会话仍要保活，否则终态可能写不出去
    onBackground(): void {
        const token = this.runToken;

        if (!token || token.finished || token.abandoned) {
            Logger.debug(this.LOG_TAG, `onBackground() 无未结束的运行会话，不申请短时任务`);
            return;
        }

        if (this.delayRequestID !== -1) {
            Logger.debug(this.LOG_TAG, `onBackground() 短时任务已申请，跳过`);
            return;
        }

        try {
            const suspendInfo = backgroundTaskManager.requestSuspendDelay('卡片指令运行', () => {
                Logger.warn(this.LOG_TAG, `短时任务即将到期，运行仍由 15 秒硬超时兜底`);
            });
            this.delayRequestID = suspendInfo.requestId;

            if (suspendInfo.actualDelayTime < CommonConstants.FORM_RUN_TIMEOUT_MS) {
                Logger.warn(this.LOG_TAG, `短时任务额度 ${suspendInfo.actualDelayTime}ms 小于 15 秒，仍由硬超时兜底`);
            }
        } catch (err) {
            this.delayRequestID = -1;
            Logger.error(this.LOG_TAG, `onBackground() 申请短时任务失败，运行与终态不受影响, ${err}`);
        }
    }

    private async init() {
        this.db.init(this.context.getApplicationContext());
        this.pm.init(this.context.getApplicationContext());

        const asfAddr = await this.db.getSetting(CommonConstants.DB_KEY_HOST_INFO_ADDRESS);
        const asfPwd = await this.db.getSetting(CommonConstants.DB_KEY_HOST_INFO_PASSWORD);

        this.asf.setAddress(asfAddr);
        this.asf.setASFPassword(asfPwd);
    }

    // 运行路径：早写运行态 → 15 秒硬超时 → 初始化 → 发请求 → 写终态
    private async handleRunMethod(params: Record<string, Object>): Promise<void> {
        this.formID = params['formID'] as string;
        this.shortcutID = params['shortcutID'] as number;
        this.nickname = params['nickname'] as string;
        this.command = params['command'] as string;

        if (!this.formID) {
            Logger.warn(this.LOG_TAG, `handleRunMethod() formID 为空，忽略本次运行`);
            return;
        }

        const session = CardRunSession.getInstance();
        const token = session.begin(this.formID);
        this.runToken = token;

        Logger.debug(this.LOG_TAG, `handleRunMethod() 从 call 事件获得参数: ${this.formID}, ${this.shortcutID}, ${this.nickname}, ${this.command}`);

        // F3：参数到手即写运行态，不读 DB / PM
        await this.writeRunningState();

        // F2：15 秒硬超时，超时与失败走同一终态函数
        this.startRunTimeout(token);

        try {
            if (!this.isSessionLive(token)) return await this.finishRun(token, null);

            await this.init();
            if (!this.isSessionLive(token)) return await this.finishRun(token, null);

            // 从数据库更新待执行的指令
            // 防止执行时卡片UI没有及时更新
            // 对比卡片指令与数据库指令，不一致时使用数据库指令
            await this.updateCommandFromDB();
            if (!this.isSessionLive(token)) return await this.finishRun(token, null);

            // 向卡片发送正在运行参数
            await this.sendFormRunning(token);
            if (!this.isSessionLive(token)) return await this.finishRun(token, null);

            session.registerAbort(token, () => this.asf.cancel());

            let payload: string | null = null;
            try {
                const response = await this.asf.send(this.command);
                payload = this.handleResponse(response);
            } catch (err) {
                Logger.error(this.LOG_TAG, `handleRunMethod() 指令 ${this.command} 执行错误`);
                payload = null;
            }

            await this.finishRun(token, payload);
        } catch (err) {
            Logger.error(this.LOG_TAG, `handleRunMethod() 错误, ${err}`);
            await this.finishRun(token, null);
        }
    }

    // 取消路径：有在跑会话只标记取消并中断请求；无在跑会话时写兜底终态
    private async handleCancelMethod(params: Record<string, Object>): Promise<void> {
        const formID = params['formID'] as string;

        if (!formID) {
            Logger.warn(this.LOG_TAG, `handleCancelMethod() formID 为空，忽略本次取消`);
            return;
        }

        const result = CardRunSession.getInstance().cancel(formID);

        if (result === RunCancelResult.CANCELLED) {
            Logger.info(this.LOG_TAG, `handleCancelMethod() 已标记取消并中断在途请求，终态由运行实例写: ${formID}`);
            return;
        }

        if (result === RunCancelResult.ENDED) {
            Logger.info(this.LOG_TAG, `handleCancelMethod() 会话已写终态，不写卡片: ${formID}`);
            return;
        }

        Logger.info(this.LOG_TAG, `handleCancelMethod() 无在跑会话，写兜底终态: ${formID}`);
        await this.writeFallbackTerminal(formID);
    }

    // 兜底终态：会话已丢，真实结果未知，按失败写一次；不写成功，也不写“已取消”
    private async writeFallbackTerminal(formID: string): Promise<void> {
        try {
            await this.init();

            const formData = await this.pm.getFormDataByIDSingle(formID);
            if (!formData) {
                Logger.warn(this.LOG_TAG, `writeFallbackTerminal() 无 PM 绑定，不写卡片: ${formID}`);
                return;
            }

            formData.isRunning = false;
            formData.runResult = this.getRunFailedMessage();

            const formInfo = CommonUtils.createSingleCommandFormBindingData(formData);
            const written = await CommonUtils.updateFormWithRetry(formID, formInfo);

            Logger.info(this.LOG_TAG, `writeFallbackTerminal() 无在跑会话，写兜底终态${written ? '成功' : '失败'}: ${formID}`);
        } catch (err) {
            Logger.error(this.LOG_TAG, `writeFallbackTerminal() 错误, ${err}`);
        }
    }

    private async writeRunningState(): Promise<void> {
        const formData = new SingleCommandFormData(this.formID, true);

        formData.shortcutID = this.shortcutID;
        formData.nickname = this.nickname;
        formData.command = this.command;
        formData.isRunning = true;

        const formInfo = CommonUtils.createSingleCommandFormBindingData(formData);
        await CommonUtils.updateFormWithRetry(this.formID, formInfo);
    }

    private async getNewFormData(): Promise<SingleCommandFormData> {
        const formData = new SingleCommandFormData(this.formID, true);

        formData.shortcutID = this.shortcutID;
        formData.nickname = this.nickname;
        formData.command = this.command;

        try {
            const bound = await this.pm.getFormDataByIDSingle(this.formID);
            if (bound) formData.nickname = bound.nickname;
        } catch (err) {
            Logger.warn(this.LOG_TAG, `getNewFormData() 读取 PM 绑定失败，使用 call 参数, ${err}`);
        }

        return formData;
    }

    // 用 PM 绑定刷新昵称后写运行态；取绑定期间可能已写终态，此时不再把卡片写回运行态
    private async sendFormRunning(token: RunToken) {
        const formData = await this.getNewFormData();

        if (!this.isSessionLive(token)) return;

        formData.isRunning = true;

        const formInfo = CommonUtils.createSingleCommandFormBindingData(formData);
        await CommonUtils.updateFormWithRetry(this.formID, formInfo);
    }

    private async updateCommandFromDB(): Promise<void> {
        const commandEntry = await this.db.getCommandByID(this.shortcutID);
        if(commandEntry) {
            const dbCommand = commandEntry.command;
            if(dbCommand !== this.command) {
                Logger.warn(this.LOG_TAG, `DB 指令: ${dbCommand}, 卡片指令: ${this.command}, 不一致，使用 DB 指令`);
                this.command = dbCommand;
            }
        }
    }

    // 会话是否仍由本实例持有卡片写入权：已取消、已写终态、已弃置、已被新运行替换都不再写卡片
    private isSessionLive(token: RunToken): boolean {
        return CardRunSession.getInstance().isActive(token);
    }

    // 唯一的卡片终态写入：成功 / 失败 / 超时 / 取消都走这里，由 tryFinish 一次性仲裁
    private async finishRun(token: RunToken, payload: string | null): Promise<void> {
        const session = CardRunSession.getInstance();

        if (!session.tryFinish(token)) {
            Logger.debug(this.LOG_TAG, `finishRun() 非当前会话，丢弃结果: ${token.formID}, seq ${token.seq}`);
            // 不写卡片，但本实例占用的计时器与短时任务要归还，避免占用并发额度
            this.clearRunTimeout();
            this.releaseKeepAlive();
            return;
        }

        this.clearRunTimeout();

        let runResult: string;
        if (token.cancelled) runResult = this.getRunCancelledMessage();
        else if (payload === null) runResult = this.getRunFailedMessage();
        else runResult = payload;

        try {
            const formData = await this.getNewFormData();
            formData.runResult = runResult; // 显示执行结果
            formData.isRunning = false; // 取消卡片正在运行状态

            const formInfo = CommonUtils.createSingleCommandFormBindingData(formData);
            const written = await CommonUtils.updateFormWithRetry(token.formID, formInfo);

            if (written) Logger.debug(this.LOG_TAG, `finishRun() 已写终态: ${runResult}`);
            else Logger.error(this.LOG_TAG, `finishRun() 终态两次写入均失败，卡片停在运行态: ${token.formID}`);
        } catch (err) {
            Logger.error(this.LOG_TAG, `finishRun() 写卡片错误, ${err}`);
        } finally {
            session.release(token);
            this.releaseKeepAlive();
        }
    }

    private startRunTimeout(token: RunToken): void {
        this.clearRunTimeout();

        this.timeoutID = setTimeout(() => {
            this.timeoutID = -1;
            Logger.warn(this.LOG_TAG, `15 秒硬超时：中断在途请求并写失败终态`);
            CardRunSession.getInstance().abortInFlight(token);
            this.finishRun(token, null).then();
        }, CommonConstants.FORM_RUN_TIMEOUT_MS);
    }

    private clearRunTimeout(): void {
        if (this.timeoutID === -1) return;

        clearTimeout(this.timeoutID);
        this.timeoutID = -1;
    }

    private releaseKeepAlive(): void {
        if (this.delayRequestID === -1) return;

        try {
            backgroundTaskManager.cancelSuspendDelay(this.delayRequestID);
            Logger.debug(this.LOG_TAG, `releaseKeepAlive() 已释放短时任务`);
        } catch (err) {
            Logger.error(this.LOG_TAG, `releaseKeepAlive() 释放短时任务失败, ${err}`);
        }

        this.delayRequestID = -1;
    }

    private getRunFailedMessage(): string {
        try {
            return this.context.resourceManager.getStringSync($r("app.string.Form_Run_Failed_Message").id);
        } catch (err) {
            Logger.error(this.LOG_TAG, `getStringSync() 失败, ${err}`);
            return '执行失败';
        }
    }

    private getRunCancelledMessage(): string {
        try {
            return this.context.resourceManager.getStringSync($r("app.string.Form_Run_Cancelled_Message").id);
        } catch (err) {
            Logger.error(this.LOG_TAG, `getStringSync() 失败, ${err}`);
            return '已取消';
        }
    }

    private handleResponse(resp: http.HttpResponse | undefined): string {
        if (!resp) throw new Error(`空响应`);

        try {
            const result: Record<string, string> = JSON.parse(resp.result.toString());
            let toastMessage: string = '';

            if (resp.responseCode == 200) {
                const resultText = result['Result'];
                toastMessage = typeof resultText === 'string' ? resultText : '';
            } else {
                const messageText = result['Message'];
                toastMessage = typeof messageText === 'string' ? messageText : '';
            }

            return toastMessage;
        } catch (err) {
            Logger.error(this.LOG_TAG, `handleResponse() 错误`);
            throw err as Error;
        }
    }
}
