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

    // 返回拼接 API endpoint 后的最终地址
    private getFinalAddress(address: string) {
        return `${CommonUtils.trimAddress(address)}${this.apiEndpoint}`;
    }

    // 发送请求
    private async sendRequest(address: string, password: string, command: string) {
        Logger.debug(this.LOG_TAG, 'sendRequest() 准备发送请求');
        Logger.debug(this.LOG_TAG, `sendRequest() 指令长度：${command.length}`);

        const httpRequest = http.createHttp();

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
            httpRequest.destroy();
        }
    }
};