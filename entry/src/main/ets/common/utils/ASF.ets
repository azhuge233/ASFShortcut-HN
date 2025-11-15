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
        header: {},
        readTimeout: 60000, // 可选，默认为60000ms。
        connectTimeout: 60000, // 可选，默认为60000ms。
        usingProtocol: http.HttpProtocol.HTTP2, // 可选，协议类型默认值由系统自动指定。
        usingProxy: false, //可选，默认不使用网络代理，自API 10开始支持该属性。
    };

    setAddress(address: string) {
        if(address.slice(-1) == "/") this.address = `${address.slice(0, -1)}${this.apiEndpoint}`;
        else this.address = `${address}${this.apiEndpoint}`;
        Logger.debug(this.LOG_TAG, `当前ASF地址: ${this.address}`);
    }

    setASFPassword(asfPassword: string) {
        this.asfPassword = asfPassword;
        Logger.debug(this.LOG_TAG, `当前ASF密码: ${this.asfPassword}`);
    }

    async send(command: string): Promise<http.HttpResponse> {
        let httpRequest = http.createHttp();

        this.httpRequestOptions.extraData = `{"Command":"${command}"}`;
        this.httpRequestOptions.header = {
            "Content-Type": this.ContentTypeJson,
            "User-Agent": this.UserAgent,
            "Authentication": this.asfPassword
        }

        try {
            Logger.debug(this.LOG_TAG, `发送指令: ${command}`);
            Logger.debug(this.LOG_TAG, `ASF 地址: ${this.address}`);
            Logger.debug(this.LOG_TAG, `ASF 密码: ${this.asfPassword}}`);

            const response = await httpRequest.request(this.address, this.httpRequestOptions);

            Logger.debug(this.LOG_TAG, `响应代码：${response.responseCode}`);
            // Logger.debug(this.LOG_TAG, `Result Type: ${JSON.stringify(response.resultType)}`);
            // Logger.debug(this.LOG_TAG, `Header: ${JSON.stringify(response.header)}`);
            Logger.debug(this.LOG_TAG, `响应结果：${response.result}`);

            return response;
        } catch (err) {
            Logger.error(this.LOG_TAG, `发送请求失败, ${err}`);
            throw new Error(`发送请求失败, ${JSON.stringify(err)}`);
        } finally {
            this.httpRequestOptions.extraData = this.defaultDataCommand;
            httpRequest.destroy();
        }
    }
};