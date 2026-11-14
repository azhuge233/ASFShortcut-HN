import { http } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';

import Logger from '../../common/utils/Logger';
import { CommandSendResult, CommandSender } from '../../domain/repository/CommandSender';

const LOG_TAG: string = '[AsfClient]';

/**
 * HTTP 传输：请求头、超时（10000 / 3000 ms）、`JSON.stringify` 请求体、`destroy()` 释放全部照搬 1.7.1。
 * 日志不含地址、密码与指令内容。
 *
 * 响应 → 领域结果（设计 §2.3）：按响应码选响应体字段属传输层契约，不是业务规则；
 * 成功 / 失败 / 取消的判定仍在 `domain/`。响应体无法解析时按失败返回——与 1.7.1 一致
 * （旧实现在 `JSON.parse` 抛错时走失败分支）。
 */
export class AsfClient implements CommandSender {
    private address = '';
    private password = '';

    private apiEndpoint = '/Api/Command';

    private CONTENT_TYPE_JSON = 'application/json';
    private USER_AGENT = 'ASF Shortcut HarmonyOS';

    // 当前在途请求：request() 前登记，结束或取消时清空
    private currentRequest: http.HttpRequest | null = null;

    // 设置全局服务器地址
    setAddress(address: string): void {
        this.address = this.getFinalAddress(address);
        Logger.debug(LOG_TAG, 'ASF 地址已设置');
    }

    // 设置全局 ASF 密码
    setPassword(password: string): void {
        this.password = password;
        Logger.debug(LOG_TAG, 'ASF 密码已设置');
    }

    // 发送正常指令
    async send(command: string): Promise<CommandSendResult> {
        return this.sendRequest(this.address, this.password, command, 'send()');
    }

    // 发送测试指令：用当前实例的地址与密码，调用方按需新建实例
    async sendTest(command: string): Promise<CommandSendResult> {
        return this.sendRequest(this.address, this.password, command, 'sendTest()');
    }

    // 取消在途请求：销毁当前 HttpRequest；无在途请求时为空操作
    // 只由卡片运行路径调用，send / sendTest 的参数、超时与响应解析不受影响
    cancel(): void {
        const request = this.currentRequest;

        if (!request) {
            Logger.debug(LOG_TAG, `cancel() 无在途请求`);
            return;
        }

        this.currentRequest = null;
        try {
            request.destroy();
            Logger.info(LOG_TAG, `cancel() 已销毁在途请求`);
        } catch (err) {
            Logger.error(LOG_TAG, `cancel() 销毁在途请求失败, ${JSON.stringify(err)}`);
        }
    }

    // 返回拼接 API endpoint 后的最终地址
    // 去尾部 "/" 是 URL 拼接的传输层细节，不 import `domain/`（域侧的规范化在 `domain/service/AsfAddress.ets`）
    private getFinalAddress(address: string): string {
        return `${address.replace(/\/+$/, "")}${this.apiEndpoint}`;
    }

    private async sendRequest(address: string, password: string, command: string,
        caller: string): Promise<CommandSendResult> {
        Logger.debug(LOG_TAG, `${caller} 准备发送请求`);
        Logger.debug(LOG_TAG, `${caller} 指令长度：${command.length}`);

        const httpRequest = http.createHttp();
        this.currentRequest = httpRequest;

        const requestOptions: http.HttpRequestOptions = {
            method: http.RequestMethod.POST,
            extraData: JSON.stringify({ Command: command }),
            expectDataType: http.HttpDataType.STRING,
            usingCache: false,
            header: {
                "Content-Type": this.CONTENT_TYPE_JSON,
                "User-Agent": this.USER_AGENT,
                "Authentication": password
            },
            readTimeout: 10000,
            connectTimeout: 3000,
        };

        try {
            const response = await httpRequest.request(address, requestOptions);

            Logger.debug(LOG_TAG, `${caller} 响应代码：${response.responseCode}`);
            Logger.debug(LOG_TAG, `${caller} 响应结果：${response.result}`);

            try {
                return {
                    ok: true,
                    statusCode: response.responseCode as number,
                    text: this.pickText(response),
                    error: ''
                };
            } catch (parseErr) {
                Logger.error(LOG_TAG, `${caller} 响应解析失败, ${JSON.stringify(parseErr)}`);
                return {
                    ok: false,
                    statusCode: response.responseCode as number,
                    text: '',
                    error: this.errorMessage(parseErr)
                };
            }
        } catch (err) {
            Logger.error(LOG_TAG, `${caller} 发送请求失败, ${JSON.stringify(err)}`);
            return { ok: false, statusCode: 0, text: '', error: this.errorMessage(err) };
        } finally {
            // 取消路径可能已由 cancel() 销毁同一请求：这里只清自己登记的引用
            if (this.currentRequest === httpRequest) this.currentRequest = null;
            try {
                httpRequest.destroy();
            } catch (err) {
                Logger.warn(LOG_TAG, `${caller} 销毁请求失败, ${JSON.stringify(err)}`);
            }
        }
    }

    // 200 取 Result、否则取 Message；字段缺失时给空串（与 1.7.1 的 toastMessage 取值一致）
    private pickText(response: http.HttpResponse): string {
        const result: Record<string, string> = JSON.parse(response.result.toString());

        if (response.responseCode == 200) {
            const resultText = result['Result'];
            return typeof resultText === 'string' ? resultText : '';
        }

        const messageText = result['Message'];
        return typeof messageText === 'string' ? messageText : '';
    }

    // 与 1.7.1 的 `(err as Error).message` 同口径：界面上的「错误: …」不带错误码前缀
    private errorMessage(err: Object): string {
        const e = err as BusinessError;
        if (e && e.message) return e.message;
        return `${err}`;
    }
}
