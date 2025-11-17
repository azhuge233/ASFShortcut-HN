import { http } from '@kit.NetworkKit';

import Logger from './Logger';

export class ASF {
    private LOG_TAG = "[ASF]";

    private address = "";
    private asfPassword = "";

    private apiEndpoint = "/Api/Command";

    private ContentTypeJson = "application/json";
    private UserAgent = "ASF Shortcut HarmonyOS";
    private defaultDataCommand = '{"Command": ""}'

    private httpRequestOptions: http.HttpRequestOptions = {
        method: http.RequestMethod.POST, // 可选，默认为http.RequestMethod.GET。
        // 当使用POST请求时此字段用于传递请求体内容，具体格式与服务端协商确定。
        extraData: this.defaultDataCommand,
        expectDataType: http.HttpDataType.STRING, // 可选，指定返回数据的类型。
        usingCache: false, // 可选，默认为true。
        priority: 1, // 可选，默认为1。
        // 开发者根据自身业务需要添加header字段。
        header: {}, // 每次请求动态设置
        readTimeout: 30000, // 可选，默认为60000ms。
        connectTimeout: 30000, // 可选，默认为60000ms。
        usingProtocol: http.HttpProtocol.HTTP2, // 可选，协议类型默认值由系统自动指定。
        usingProxy: false, //可选，默认不使用网络代理，自API 10开始支持该属性。
    };

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
        return await this.sendRequest(this.address, this.asfPassword, command);
    }

    // 发送测试指令
    async sendTest(address: string, password: string, command: string): Promise<http.HttpResponse> {
        return await this.sendRequest(this.getFinalAddress(address), password, command);
    }

    // 删除地址末尾 '/'
    private trimAddress(address: string) {
        return address.slice(-1) == "/" ? address.slice(0, -1) : address;
    }

    // 返回拼接 API endpoint 后的最终地址
    private getFinalAddress(address: string) {
        return `${this.trimAddress(address)}${this.apiEndpoint}`;
    }

    // 发送请求前设置请求选项
    // 设置指令参数和 ASF 密码请求头
    private setHttpRequestOptions(password: string, command: string) {
        this.httpRequestOptions.extraData = `{"Command":"${command}"}`;
        this.httpRequestOptions.header = {
            "Content-Type": this.ContentTypeJson,
            "User-Agent": this.UserAgent,
            "Authentication": password
        }
    }

    // 发送请求
    private async sendRequest(address: string, password: string, command: string) {
        let httpRequest = http.createHttp();

        this.setHttpRequestOptions(password, command);

        try {
            Logger.debug(this.LOG_TAG, `ASF 服务器地址：${address}`);
            Logger.debug(this.LOG_TAG, `ASF 密码：${password}`);
            Logger.debug(this.LOG_TAG, `ASF 指令：${command}`);

            const response = await httpRequest.request(address, this.httpRequestOptions);

            Logger.debug(this.LOG_TAG, `响应代码：${response.responseCode}`);
            // Logger.debug(this.LOG_TAG, `Result Type: ${JSON.stringify(response.resultType)}`);
            // Logger.debug(this.LOG_TAG, `Header: ${JSON.stringify(response.header)}`);
            Logger.debug(this.LOG_TAG, `响应结果：${response.result}`);

            return response;
        } catch (err) {
            Logger.error(this.LOG_TAG, `发送请求失败, ${JSON.stringify(err)}`);
            throw err as Error;
        } finally {
            this.httpRequestOptions.extraData = this.defaultDataCommand;
            httpRequest.destroy();
        }
    }
};