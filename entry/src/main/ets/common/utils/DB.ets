import { relationalStore } from '@kit.ArkData';
import { Context } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';

import Logger from '../utils/Logger';
import CommonConstants from '../constants/CommonConstants'
import CommandEntry from '../../model/CommandEntry';

export class DB {
    private static instance: DB | null = null;

    private isInitialized: boolean = false; // 初始化标志
    private initPromise: Promise<void> | null = null;
    private resolveInit: (() => void) | null = null;

    private rdbStore: relationalStore.RdbStore | undefined;

    private LOG_TAG = '[DB]'

    private STORE_CONFIG: relationalStore.StoreConfig = {
        name: 'ASFShortcut.db',
        securityLevel: relationalStore.SecurityLevel.S1
    };

    private TN_HostInfo: string = 'HOSTINFO';
    private TN_CommandEntries: string = 'COMMANDENTRIES';

    private KEY_ID = 'ID';

    private KEY_HostInfo_KEY = 'KEY';
    private KEY_HostInfo_VALUE = 'VALUE';

    private KEY_CommandEntries_Nickname = 'NICKNAME';
    private KEY_CommandEntries_Command = 'COMMAND';
    private KEY_CommandEntries_AccountInputRequired = 'AIR';
    private KEY_CommandEntries_IdInputRequired = 'IIR';

    private SQL_CREATE_TABLE_HostInfo = `CREATE TABLE IF NOT EXISTS ${this.TN_HostInfo} (
        ID INTEGER PRIMARY KEY AUTOINCREMENT,
        ${this.KEY_HostInfo_KEY} TEXT NOT NULL UNIQUE,
        ${this.KEY_HostInfo_VALUE} TEXT NOT NULL
    )`;
    private SQL_CREATE_TABLE_CommandEntires = `CREATE TABLE IF NOT EXISTS ${this.TN_CommandEntries} (
        ID INTEGER PRIMARY KEY AUTOINCREMENT,
        ${this.KEY_CommandEntries_Nickname} TEXT NOT NULL,
        ${this.KEY_CommandEntries_Command} TEXT NOT NULL,
        ${this.KEY_CommandEntries_AccountInputRequired} INTEGER NOT NULL,
        ${this.KEY_CommandEntries_IdInputRequired} INTEGER NOT NULL
    )`;

    private SQL_DELETE_TABLE_Prefix = "DELETE FROM ";

    private constructor() { }

    public static getInstance(): DB {
        if (!DB.instance) DB.instance = new DB();
        return DB.instance;
    }

    public initDB(context: Context) {
        if (this.initPromise) return;

        this.initPromise = new Promise((resolve) => {
            this.resolveInit = resolve;

            // 异步初始化数据库
            relationalStore.getRdbStore(context, this.STORE_CONFIG).then((store) => {
                store.executeSync(this.SQL_CREATE_TABLE_HostInfo);
                store.executeSync(this.SQL_CREATE_TABLE_CommandEntires);

                this.rdbStore = store;
                this.isInitialized = true;
                resolve(); // 解析Promise表示初始化完成
            }).catch((err: BusinessError) => {
                Logger.error(this.LOG_TAG, `数据库初始化失败, ${err}`);
                resolve(); // 即使失败也要resolve，避免永久阻塞
            });
        });
    }

    public async waitForReady(): Promise<void> {
        if (!this.initPromise) throw new Error("数据库未初始化. 先调用 initDB()");
        await this.initPromise;
    }

    async saveSetting(key: string, value: string): Promise<boolean> {
        await this.waitForReady();

        if (!this.rdbStore) {
            Logger.error(this.LOG_TAG, "数据库实例不存在");
            return false;
        }

        try {
            const predicates = new relationalStore.RdbPredicates(this.TN_HostInfo);
            predicates.equalTo(this.KEY_HostInfo_KEY, key);

            const resultSet = await this.rdbStore.query(predicates, [this.KEY_ID]);
            const exists = resultSet.rowCount > 0;
            resultSet.close();

            if (exists) {
                const valueBucket: relationalStore.ValuesBucket = {
                    'VALUE': value
                };
                await this.rdbStore.update(valueBucket, predicates);
            } else {
                const valueBucket: relationalStore.ValuesBucket = {
                    'KEY': key,
                    'VALUE': value
                };
                await this.rdbStore.insert(this.TN_HostInfo, valueBucket);
            }

            Logger.info(this.LOG_TAG, `设置已保存: ${key} = ${value}`);
            return true;
        } catch (err) {
            Logger.error(this.LOG_TAG, `无法保存设置 ${key} = ${value}: ${err}`);
            return false;
        }
    }

    async getSetting(key: string, defaultValue: string = ''): Promise<string> {
        await this.waitForReady();

        if (!this.rdbStore) {
            Logger.error(this.LOG_TAG, "数据库实例不存在");
            return defaultValue;
        }

        try {
            const predicates = new relationalStore.RdbPredicates(this.TN_HostInfo);
            predicates.equalTo(this.KEY_HostInfo_KEY, key);

            const resultSet = await this.rdbStore.query(predicates, [this.KEY_HostInfo_VALUE]);
            let value = defaultValue;

            if (resultSet.rowCount > 0 && resultSet.goToFirstRow()) {
                value = resultSet.getString(resultSet.getColumnIndex(this.KEY_HostInfo_VALUE));
            }

            resultSet.close();
            return value;
        } catch (err) {
            Logger.error(this.LOG_TAG, `无法获取 ${key} 设置信息, ${err}`);
            return defaultValue;
        }
    }

    async areSettingsComplete(): Promise<boolean> {
        const address = await this.getSetting(CommonConstants.DB_KEY_HostInfo_KEY_NAME_Address);
        const password = await this.getSetting(CommonConstants.DB_KEY_HostInfo_KEY_NAME_Password);

        return address.trim() !== '' && password.trim() !== '';
    }

    // debug 方法
    async getAllSettings(): Promise<Map<string, string>> {
        const settings = new Map<string, string>();

        if (!this.rdbStore) {
            Logger.error(this.LOG_TAG, "数据库实例不存在");
            return settings;
        }

        try {
            const predicates = new relationalStore.RdbPredicates(this.TN_HostInfo);
            const resultSet = await this.rdbStore.query(predicates, [this.KEY_HostInfo_KEY, this.KEY_HostInfo_VALUE]);

            if (resultSet.rowCount > 0) {
                while (resultSet.goToNextRow()) {
                    const key = resultSet.getString(resultSet.getColumnIndex(this.KEY_HostInfo_KEY));
                    const value = resultSet.getString(resultSet.getColumnIndex(this.KEY_HostInfo_VALUE));
                    settings.set(key, value);
                }
            }

            resultSet.close();
            return settings;
        } catch (err) {
            Logger.error(this.LOG_TAG, `无法获取全部设置信息, ${err}`);
            return settings;
        }
    }

    private async clearTable(tableName: string) {
        await this.waitForReady();

        if (!this.rdbStore) throw new Error("数据库实例不存在");

        const sql = `${this.SQL_DELETE_TABLE_Prefix}${tableName}`;

        try {
            await this.rdbStore.executeSql(sql);
            Logger.info(this.LOG_TAG, `成功清除表内数据, 表名称: ${tableName}`);
        } catch (err) {
            Logger.error(this.LOG_TAG, `清除表: ${tableName} 数据失败, code: ${err.code}, message: ${err.message}`);
            throw new Error(`清除表: ${tableName} 数据失败`);
        }
    }

    // debug 方法
    async clearTableSettings() {
        await this.clearTable(this.TN_HostInfo);
    }

    async clearTableCommandEntries() {
        await this.clearTable(this.TN_CommandEntries);
    }

    async getCommandList() {
        await this.waitForReady();

        if (!this.rdbStore) throw new Error("数据库实例不存在");

        const predicates = new relationalStore.RdbPredicates(this.TN_CommandEntries);

        const queryResult = await this.rdbStore.query(predicates, [
            this.KEY_ID,
            this.KEY_CommandEntries_Nickname,
            this.KEY_CommandEntries_Command,
            this.KEY_CommandEntries_AccountInputRequired,
            this.KEY_CommandEntries_IdInputRequired
        ]);

        if(queryResult === undefined) throw new Error("查询为空");

        Logger.debug(this.LOG_TAG, `查询结果，行数: ${queryResult.rowCount}, 列数: ${queryResult.columnCount}`)

        try {
            const commandEntries: Array<CommandEntry> = [];

            while (queryResult.goToNextRow()) {
                const id = queryResult.getLong(queryResult.getColumnIndex(this.KEY_ID));
                const nickname = queryResult.getString(queryResult.getColumnIndex(this.KEY_CommandEntries_Nickname));
                const command = queryResult.getString(queryResult.getColumnIndex(this.KEY_CommandEntries_Command));
                const accountInputRequired =
                    queryResult.getLong(queryResult.getColumnIndex(this.KEY_CommandEntries_AccountInputRequired));
                const idInputRequired =
                    queryResult.getLong(queryResult.getColumnIndex(this.KEY_CommandEntries_IdInputRequired));

                commandEntries.push(new CommandEntry(
                    id, nickname, command, accountInputRequired, idInputRequired
                ));
            }

            Logger.debug(this.LOG_TAG, `指令列表长度: ${commandEntries.length}`);

            return commandEntries;
        } catch (err) {
            throw new Error(`获取快捷指令列表失败, ${err}`);
        } finally {
            queryResult.close();
        }
    }

    async addCommandEntry(commandEntry: CommandEntry) {
        await this.waitForReady();

        if (!this.rdbStore) throw new Error("数据库实例不存在");

        try {
            const valueBucket: relationalStore.ValuesBucket = {
                "NICKNAME": commandEntry.nickname,
                "COMMAND": commandEntry.command,
                "AIR": commandEntry.accountInputRequired,
                "IIR": commandEntry.idInputRequired
            };

            Logger.debug(this.LOG_TAG,
                `Adding new command -
                Nickname: ${commandEntry.nickname},
                Command: ${commandEntry.command},
                AIR: ${commandEntry.accountInputRequired},
                IIR: ${commandEntry.idInputRequired}`
            );

            const result = await this.rdbStore.insert(this.TN_CommandEntries, valueBucket);

            return result;
        } catch (err) {
            throw new Error(err);
        }
    }

    async updateCommandEntry(commandEntry: CommandEntry) {
        await this.waitForReady();

        if (!this.rdbStore) throw new Error("数据库实例不存在");

        Logger.debug(this.LOG_TAG, `更新指令 -
            ID: ${commandEntry.id},
            Nickname: ${commandEntry.nickname},
            Command: ${commandEntry.command},
            AIR: ${commandEntry.accountInputRequired},
            IIR: ${commandEntry.idInputRequired}`
        );

        try {
            let predicates = new relationalStore.RdbPredicates(this.TN_CommandEntries);
            predicates.equalTo(this.KEY_ID, commandEntry.id);

            const valueBucket: relationalStore.ValuesBucket = {
                "NICKNAME": commandEntry.nickname,
                "COMMAND": commandEntry.command,
                "AIR": commandEntry.accountInputRequired,
                "IIR": commandEntry.idInputRequired
            };

            const result = await this.rdbStore.update(valueBucket, predicates);

            return result;
        } catch (err) {
            throw new Error(err);
        }
    }

    async deleteCommandEntryByID(commandEntry: CommandEntry) {
        await this.waitForReady();

        if (!this.rdbStore) throw new Error("数据库实例不存在");

        const id = commandEntry.id;

        Logger.debug(this.LOG_TAG, `删除指令, ID: ${id}`);

        let predicates = new relationalStore.RdbPredicates(this.TN_CommandEntries);
        predicates.equalTo(this.KEY_ID, id);

        try {
            const result = await this.rdbStore.delete(predicates);

            return result;
        } catch (err) {
            throw new Error(err);
        }
    }
}