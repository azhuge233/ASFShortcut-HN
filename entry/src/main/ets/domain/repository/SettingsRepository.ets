/**
 * 服务器设置（`HOSTINFO`）的存取接口。data 层实现、领域层持有（设计 §2.2、§2.3）。
 */
export interface SettingsRepository {
    get(key: string): Promise<string>;

    save(key: string, value: string): Promise<boolean>;

    areComplete(): Promise<boolean>;

    /** 整表替换：导入事务体用；事务边界由调用方组织 */
    replaceAll(entries: Array<[string, string]>): Promise<boolean>;
}
