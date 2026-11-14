/**
 * 服务器地址的规范化（与 1.7.1 的去尾斜杠口径一致）。
 *
 * 落 `domain/service/` 而不是 `common/`：去尾斜杠是「地址怎样算可用」的业务口径，
 * 保存设置时由页面调用。
 * `data/network/AsfClient.ets` 不 import 本文件——它自己做的是 URL 拼接时的同一步替换，属传输层细节（设计 §3.3）。
 *
 * 「设置是否完整」的判定在 `SettingsDao.areComplete()`（地址与密码都非空）：那是数据层的整行判断，
 * `data/` 不得 import `domain/service/`，所以本文件只留规范化一条规则。
 */
export class AsfAddress {
    /** 去掉地址末尾的 '/'（保留原实现的正则口径） */
    static normalize(address: string): string {
        return address.replace(/\/+$/, "");
    }
}
