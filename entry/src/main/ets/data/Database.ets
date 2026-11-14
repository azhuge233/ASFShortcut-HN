import { relationalStore } from '@kit.ArkData';
import { Context } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';

import Logger from '../common/utils/Logger';

/*
 * 数据库句柄与 schema 常量。
 * 建表 SQL、表名、列名、S1 安全级别、ORDERINDEX 升序排序全部照搬 1.7.1（设计 §2.2 约束），
 * 只是库句柄、schema 常量与事务边界的落点；两张表的读写分别由 `data/dao/` 下的两个 DAO 承担。
 */

export const STORE_NAME: string = 'ASFShortcut.db';

export const TN_HOST_INFO: string = 'HOSTINFO';
export const TN_COMMAND_ENTRIES: string = 'COMMANDENTRIES';

export const KEY_ID: string = 'ID';

export const KEY_HOST_INFO_KEY: string = 'KEY';
export const KEY_HOST_INFO_VALUE: string = 'VALUE';

export const KEY_COMMAND_NICKNAME: string = 'NICKNAME';
export const KEY_COMMAND_COMMAND: string = 'COMMAND';
export const KEY_COMMAND_ORDER_INDEX: string = 'ORDERINDEX';
export const KEY_COMMAND_AIR: string = 'AIR';
export const KEY_COMMAND_IIR: string = 'IIR';

export const SQL_CREATE_TABLE_HOST_INFO: string = `CREATE TABLE IF NOT EXISTS ${TN_HOST_INFO} (
        ID INTEGER PRIMARY KEY AUTOINCREMENT,
        ${KEY_HOST_INFO_KEY} TEXT NOT NULL UNIQUE,
        ${KEY_HOST_INFO_VALUE} TEXT NOT NULL
    )`;

export const SQL_CREATE_TABLE_COMMAND_ENTRIES: string = `CREATE TABLE IF NOT EXISTS ${TN_COMMAND_ENTRIES} (
        ID INTEGER PRIMARY KEY AUTOINCREMENT,
        ${KEY_COMMAND_NICKNAME} TEXT NOT NULL,
        ${KEY_COMMAND_COMMAND} TEXT NOT NULL,
        ${KEY_COMMAND_ORDER_INDEX} INTEGER DEFAULT 0,
        ${KEY_COMMAND_AIR} INTEGER NOT NULL,
        ${KEY_COMMAND_IIR} INTEGER NOT NULL
    )`;

export const SQL_DELETE_TABLE_PREFIX: string = 'DELETE FROM ';

/**
 * 事务边界：句柄在数据层，发起在领域层（设计 §2.2 约束「事务边界仍在数据层实现、由领域层发起」）。
 * 两个 DAO 共用同一个 `Database` 单例，因此一个事务可以跨两张表。
 */
export interface TransactionBoundary {
    beginTransaction(): void;

    commitTransaction(): void;

    rollBackTransaction(): void;
}

export function errorText(err: Object): string {
    const e = err as BusinessError;
    if (e && e.message) return `${e.code}: ${e.message}`;
    return `${err}`;
}

export function closeResultSet(resultSet: relationalStore.ResultSet | null, logTag: string, caller: string): void {
    if (!resultSet) return;
    try {
        resultSet.close();
    } catch (err) {
        Logger.error(logTag, `${caller} 关闭查询结果集失败, ${errorText(err)}`);
    }
}

export class Database implements TransactionBoundary {
    private LOG_TAG: string = '[Database]';

    private static instance: Database | null = null;

    private initPromise: Promise<void> | null = null;

    private rdbStore: relationalStore.RdbStore | undefined;

    private STORE_CONFIG: relationalStore.StoreConfig = {
        name: STORE_NAME,
        securityLevel: relationalStore.SecurityLevel.S1
    };

    private constructor() {
    }

    public static getInstance(): Database {
        if (!Database.instance) Database.instance = new Database();
        return Database.instance;
    }

    public init(context: Context): void {
        if (this.initPromise) return;

        this.initPromise = new Promise((resolve) => {
            relationalStore.getRdbStore(context, this.STORE_CONFIG).then((store) => {
                store.executeSync(SQL_CREATE_TABLE_HOST_INFO);
                store.executeSync(SQL_CREATE_TABLE_COMMAND_ENTRIES);

                this.rdbStore = store;
                resolve();
            }).catch((err: BusinessError) => {
                Logger.error(this.LOG_TAG, `数据库初始化失败, ${err}`);
                this.initPromise = null; // 允许下次重试
                resolve(); // 即使失败也要 resolve，避免永久阻塞
            });
        });
    }

    public async waitForReady(): Promise<void> {
        if (!this.initPromise) throw new Error("数据库未初始化. 先调用 init()");
        await this.initPromise;
    }

    public hasStore(): boolean {
        return this.rdbStore !== undefined;
    }

    /** 取句柄；未初始化时抛错（与 1.7.1 各写入方法的判据一致） */
    public requireStore(): relationalStore.RdbStore {
        if (!this.rdbStore) throw new Error("数据库实例不存在");
        return this.rdbStore;
    }

    public beginTransaction(): void {
        this.requireStore().beginTransaction();
    }

    public commitTransaction(): void {
        this.requireStore().commit();
    }

    public rollBackTransaction(): void {
        this.requireStore().rollBack();
    }
}
