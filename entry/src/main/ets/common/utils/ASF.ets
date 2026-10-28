import { http } from '@kit.NetworkKit';
import CommonUtils from './CommonUtils';

import Logger from './Logger';

export class ASF {
    private LOG_TAG = "[ASF]";

    private address = "";
    private asfPassword = "";

    private apiEndpoint = "/Api/Command";

    private CONTENT_TYPE_JSON = "application/json";
    private USER_AGENT = "ASF Shortcut HarmonyOS";

    // 当前在途请求：request() 前登记，结束或取消时清空
    private currentRequest: http.HttpRequest | null = null;

    // 设置全局服务器地址
    setAddress(address: string) {
        this.address = this.getFinalAddress(address);
        Logger.debug(this.LOG_TAG, 'ASF 地址已设置');
    }

    // 设置全局 ASF 密码
    setASFPassword(asfPassword: string) {
        this.asfPassword = asfPassword;
        Logger.debug(this.LOG_TAG, 'ASF 密码已设置');
    }

    // 发送正常指令
    async send(command: string): Promise<http.HttpResponse> {
        try {
            const result = await this.sendRequest(this.address, this.asfPassword, command);
            return result;
        } catch (err) {
            Logger.error(this.LOG_TAG, `send() 错误, ${JSON.stringify(err)}`);
            throw err as Error;
        }
    }

    // 发送测试指令
    async sendTest(address: string, password: string, command: string): Promise<http.HttpResponse> {
        try {
            const result = await this.sendRequest(this.getFinalAddress(address), password, command);
            return result
        } catch (err) {
            Logger.error(this.LOG_TAG, `sendTest() 错误, ${JSON.stringify(err)}`);
            throw err as Error;
        }
    }

    // 取消在途请求：销毁当前 HttpRequest；无在途请求时为空操作
    // 只由卡片运行路径调用，send / sendTest 的参数、超时与响应解析不受影响
    cancel(): void {
        const request = this.currentRequest;

        if (!request) {
            Logger.debug(this.LOG_TAG, `cancel() 无在途请求`);
            return;
        }

        this.currentRequest = null;
        try {
            request.destroy();
            Logger.info(this.LOG_TAG, `cancel() 已销毁在途请求`);
        } catch (err) {
            Logger.error(this.LOG_TAG, `cancel() 销毁在途请求失败, ${JSON.stringify(err)}`);
        }
    }

    // 返回拼接 API endpoint 后的最终地址
    private getFinalAddress(address: string) {
        return `${CommonUtils.trimAddress(address)}${this.apiEndpoint}`;
    }

    // 发送请求
    private async sendRequest(address: string, password: string, command: string) {
        Logger.debug(this.LOG_TAG, 'sendRequest() 准备发送请求');
        Logger.debug(this.LOG_TAG, `sendRequest() 指令长度：${command.length}`);

        const httpRequest = http.createHttp();
        this.currentRequest = httpRequest;

        // 设置指令参数和 ASF 密码请求头
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

            Logger.debug(this.LOG_TAG, `sendRequest() 响应代码：${response.responseCode}`);
            Logger.debug(this.LOG_TAG, `sendRequest() 响应结果：${response.result}`);

            return response;
        } catch (err) {
            Logger.error(this.LOG_TAG, `sendRequest() 发送请求失败, ${JSON.stringify(err)}`);
            throw err as Error;
        } finally {
            // 取消路径可能已由 cancel() 销毁同一请求：这里只清自己登记的引用
            if (this.currentRequest === httpRequest) this.currentRequest = null;
            try {
                httpRequest.destroy();
            } catch (err) {
                Logger.warn(this.LOG_TAG, `sendRequest() 销毁请求失败, ${JSON.stringify(err)}`);
            }
        }
    }
};