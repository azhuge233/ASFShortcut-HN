import { http } from '@kit.NetworkKit';
import CommonUtils from './CommonUtils';

import Logger from './Logger';

export class ASF {
    private LOG_TAG = "[ASF]";

    private address = "";
    private asfPassword = "";

    private apiEndpoint = "/Api/Command";

    private ContentTypeJson = "application/json";
    private UserAgent = "ASF Shortcut HarmonyOS";

    // 设置全局服务器地址
    setAddress(address: string) {
        this.address = this.getFinalAddress(address);
        Logger.debug(this.LOG_TAG, `当前ASF地址: ${this.address}`);
    }

    // 设置全局 ASF 密码
    setASFPassword(asfPassword: string) {
        this.asfPassword = asfPassword;
        Logger.debug(this.LOG_TAG, `当前ASF密码: ${this.asfPassword}`);
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
        Logger.debug(this.LOG_TAG, `sendRequest() ASF 服务器地址：${address}`);
        Logger.debug(this.LOG_TAG, `sendRequest() ASF 密码：${password}`);
        Logger.debug(this.LOG_TAG, `sendRequest() ASF 指令：${command}`);

        const httpRequest = http.createHttp();

        // 设置指令参数和 ASF 密码请求头
        const requestOptions: http.HttpRequestOptions = {
            method: http.RequestMethod.POST,
            extraData: `{"Command":"${command}"}`,
            expectDataType: http.HttpDataType.STRING,
            usingCache: false,
            header: {
                "Content-Type": this.ContentTypeJson,
                "User-Agent": this.UserAgent,
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