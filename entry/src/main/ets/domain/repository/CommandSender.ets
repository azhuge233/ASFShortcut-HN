/**
 * 一次指令发送的结果：HTTP 响应对象不进入 `domain/`（设计 §2.3「响应 → 领域结果」）。
 *
 * 字段口径：`ok` = 拿到响应且响应体可解析；`statusCode` = 响应码，没拿到响应时为 0；
 * `text` = 200 取 `Result`、否则取 `Message`，失败或该字段缺失时为空串；`error` = 失败原因，成功为空串。
 * 「响应体不可解析也算失败」是为了与 1.7.1 一致：旧实现在 `JSON.parse` 抛错时按失败写终态，
 * 若这里判成功，卡片会从「执行失败」变成显示空文本——那是第七项行为变更，不在本批授权内。
 */
export interface CommandSendResult {
    ok: boolean;
    statusCode: number;
    text: string;
    error: string;
}

export interface CommandSender {
    setAddress(address: string): void;

    setPassword(password: string): void;

    send(command: string): Promise<CommandSendResult>;

    /** 用当前实例的地址与密码发送一次测试指令 */
    sendTest(command: string): Promise<CommandSendResult>;

    cancel(): void;
}
