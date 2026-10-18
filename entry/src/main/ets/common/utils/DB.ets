import { relationalStore } from '@kit.ArkData';
import { Context } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';

import Logger from '../utils/Logger';
import CommonConstants from '../constants/CommonConstants'
import CommandEntry from '../../model/CommandEntry';

export class DB {
    private LOG_TAG = '[DB]'

    private static instance: DB | null = null;

    private initPromise: Promise<void> | null = null;

    private rdbStore: relationalStore.RdbStore | undefined;

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
    private KEY_CommandEntries_OrderIndex = 'ORDERINDEX';
    private KEY_CommandEntries_AccountInputRequired = 'AIR';
    private KEY_CommandEntries_IDInputRequired = 'IIR';

    private SQL_CREATE_TABLE_HostInfo = `CREATE TABLE IF NOT EXISTS ${this.TN_HostInfo} (
        ID INTEGER PRIMARY KEY AUTOINCREMENT,
        ${this.KEY_HostInfo_KEY} TEXT NOT NULL UNIQUE,
        ${this.KEY_HostInfo_VALUE} TEXT NOT NULL
    )`;
    private SQL_CREATE_TABLE_CommandEntries = `CREATE TABLE IF NOT EXISTS ${this.TN_CommandEntries} (
        ID INTEGER PRIMARY KEY AUTOINCREMENT,
        ${this.KEY_CommandEntries_Nickname} TEXT NOT NULL,
        ${this.KEY_CommandEntries_Command} TEXT NOT NULL,
        ${this.KEY_CommandEntries_OrderIndex} INTEGER DEFAULT 0,
        ${this.KEY_CommandEntries_AccountInputRequired} INTEGER NOT NULL,
        ${this.KEY_CommandEntries_IDInputRequired} INTEGER NOT NULL
    )`;

    private SQL_DELETE_TABLE_Prefix = "DELETE FROM ";

    private constructor() { }

    public static getInstance(): DB {
        if (!DB.instance) DB.instance = new DB();
        return DB.instance;
    }

    public init(context: Context) {
        if (this.initPromise) return;

        this.initPromise = new Promise((resolve) => {
            // 异步初始化数据库
            relationalStore.getRdbStore(context, this.STORE_CONFIG).then((store) => {
                store.executeSync(this.SQL_CREATE_TABLE_HostInfo);
                store.executeSync(this.SQL_CREATE_TABLE_CommandEntries);

                this.rdbStore = store;
                resolve(); // 解析Promise表示初始化完成
            }).catch((err: BusinessError) => {
                Logger.error(this.LOG_TAG, `数据库初始化失败, ${err}`);
                this.initPromise = null; // 允许下次重试
                resolve(); // 即使失败也要resolve，避免永久阻塞
            });
        });
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

            let resultSet: relationalStore.ResultSet | null = null;
            try {
                resultSet = await this.rdbStore.query(predicates, [this.KEY_ID]);
                const exists = resultSet.rowCount > 0;

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
            } finally {
                this.closeResultSet(resultSet, 'saveSetting()');
            }

            Logger.info(this.LOG_TAG, `设置已保存: ${key}`);
            return true;
        } catch (err) {
            Logger.error(this.LOG_TAG, `无法保存设置 ${key}: ${this.errorText(err)}`);
            return false;
        }
    }

    async getSetting(key: string, defaultValue: string = ''): Promise<string> {
        await this.waitForReady();

        if (!this.rdbStore) {
            Logger.error(this.LOG_TAG, "数据库实例不存在");
            return defaultValue;
        }

        let resultSet: relationalStore.ResultSet | null = null;
        try {
            const predicates = new relationalStore.RdbPredicates(this.TN_HostInfo);
            predicates.equalTo(this.KEY_HostInfo_KEY, key);

            resultSet = await this.rdbStore.query(predicates, [this.KEY_HostInfo_VALUE]);
            let value = defaultValue;

            if (resultSet.rowCount > 0 && resultSet.goToFirstRow()) {
                value = resultSet.getString(resultSet.getColumnIndex(this.KEY_HostInfo_VALUE));
            }

            return value;
        } catch (err) {
            Logger.error(this.LOG_TAG, `无法获取 ${key} 设置信息, ${this.errorText(err)}`);
            return defaultValue;
        } finally {
            this.closeResultSet(resultSet, 'getSetting()');
        }
    }

    async areSettingsComplete(): Promise<boolean> {
        const address = await this.getSetting(CommonConstants.DB_KEY_HOST_INFO_ADDRESS);
        const password = await this.getSetting(CommonConstants.DB_KEY_HOST_INFO_PASSWORD);

        return address.trim() !== '' && password.trim() !== '';
    }


    private async clearTable(tableName: string) {
        await this.waitForReady();

        if (!this.rdbStore) throw new Error("数据库实例不存在");

        const sql = `${this.SQL_DELETE_TABLE_Prefix}${tableName}`;

        try {
            await this.rdbStore.executeSql(sql);
            Logger.info(this.LOG_TAG, `成功清除表内数据, 表名称: ${tableName}`);
        } catch (err) {
            Logger.error(this.LOG_TAG, `清除表: ${tableName} 数据失败, ${this.errorText(err)}`);
            throw new Error(`清除表: ${tableName} 数据失败`);
        }
    }

    async clearTableCommandEntries() {
        await this.clearTable(this.TN_CommandEntries);
    }

    async importData(address: string, password: string, entries: Array<CommandEntry>): Promise<boolean> {
        await this.waitForReady();

        if (!this.rdbStore) {
            Logger.error(this.LOG_TAG, "数据库实例不存在，无法导入");
            return false;
        }

        try {
            this.rdbStore.beginTransaction();
            await this.rdbStore.executeSql(`${this.SQL_DELETE_TABLE_Prefix}${this.TN_HostInfo}`);
            await this.rdbStore.executeSql(`${this.SQL_DELETE_TABLE_Prefix}${this.TN_CommandEntries}`);

            const addressBucket: relationalStore.ValuesBucket = {
                'KEY': CommonConstants.DB_KEY_HOST_INFO_ADDRESS,
                'VALUE': address
            };
            const passwordBucket: relationalStore.ValuesBucket = {
                'KEY': CommonConstants.DB_KEY_HOST_INFO_PASSWORD,
                'VALUE': password
            };
            await this.rdbStore.insert(this.TN_HostInfo, addressBucket);
            await this.rdbStore.insert(this.TN_HostInfo, passwordBucket);

            for (const entry of entries) {
                const valueBucket: relationalStore.ValuesBucket = {
                    'NICKNAME': entry.nickname,
                    'COMMAND': entry.command,
                    'ORDERINDEX': entry.orderIndex,
                    'AIR': entry.accountInputRequired,
                    'IIR': entry.idInputRequired
                };
                await this.rdbStore.insert(this.TN_CommandEntries, valueBucket);
            }

            this.rdbStore.commit();
            return true;
        } catch (err) {
            if (this.rdbStore) {
                try {
                    this.rdbStore.rollBack();
                } catch (rollbackErr) {
                    Logger.error(this.LOG_TAG, `导入失败后回滚异常, ${this.errorText(rollbackErr)}`);
                }
            }
            Logger.error(this.LOG_TAG, `导入数据失败, ${this.errorText(err)}`);
            return false;
        }
    }

    async getCommandByID(queryID: number): Promise<CommandEntry | null> {
        await this.waitForReady();

        if (!this.rdbStore) throw new Error("数据库实例不存在");

        const predicates = new relationalStore.RdbPredicates(this.TN_CommandEntries);
        predicates.equalTo(this.KEY_ID, queryID);

        let queryResult: relationalStore.ResultSet | null = null;
        try {
            queryResult = await this.rdbStore.query(predicates, [
                this.KEY_ID,
                this.KEY_CommandEntries_Nickname,
                this.KEY_CommandEntries_Command,
                this.KEY_CommandEntries_OrderIndex,
                this.KEY_CommandEntries_AccountInputRequired,
                this.KEY_CommandEntries_IDInputRequired
            ]);

            if(queryResult.goToNextRow()) {
                const id = queryResult.getLong(queryResult.getColumnIndex(this.KEY_ID));
                const nickname = queryResult.getString(queryResult.getColumnIndex(this.KEY_CommandEntries_Nickname));
                const command = queryResult.getString(queryResult.getColumnIndex(this.KEY_CommandEntries_Command));
                const orderIndex = queryResult.getLong(queryResult.getColumnIndex(this.KEY_CommandEntries_OrderIndex));
                const accountInputRequired =
                    queryResult.getLong(queryResult.getColumnIndex(this.KEY_CommandEntries_AccountInputRequired));
                const idInputRequired =
                    queryResult.getLong(queryResult.getColumnIndex(this.KEY_CommandEntries_IDInputRequired));

                const commandEntry = new CommandEntry(id, nickname, command, orderIndex, accountInputRequired, idInputRequired);

                Logger.debug(this.LOG_TAG, `查询到 ${queryID}: ${JSON.stringify(commandEntry)}`);

                return commandEntry;
            }

            Logger.debug(this.LOG_TAG, `没有查询到 ID = ${queryID} 的结果`)
            return null;
        } catch (err) {
            Logger.error(this.LOG_TAG, `getCommandByID 执行失败, ${this.errorText(err)}`);
            return null;
        } finally {
            this.closeResultSet(queryResult, 'getCommandByID()');
        }
    }

    async getCommandList(): Promise<Array<CommandEntry>> {
        await this.waitForReady();

        if (!this.rdbStore) throw new Error("数据库实例不存在");

        const predicates = new relationalStore.RdbPredicates(this.TN_CommandEntries);

        let queryResult: relationalStore.ResultSet | null = null;
        try {
            queryResult = await this.rdbStore.query(predicates, [
                this.KEY_ID,
                this.KEY_CommandEntries_Nickname,
                this.KEY_CommandEntries_Command,
                this.KEY_CommandEntries_OrderIndex,
                this.KEY_CommandEntries_AccountInputRequired,
                this.KEY_CommandEntries_IDInputRequired
            ]);

            if(!queryResult) throw new Error("查询为空");

            Logger.debug(this.LOG_TAG, `查询结果，行数: ${queryResult.rowCount}, 列数: ${queryResult.columnCount}`)

            const commandEntries: Array<CommandEntry> = [];

            while (queryResult.goToNextRow()) {
                const id = queryResult.getLong(queryResult.getColumnIndex(this.KEY_ID));
                const nickname = queryResult.getString(queryResult.getColumnIndex(this.KEY_CommandEntries_Nickname));
                const command = queryResult.getString(queryResult.getColumnIndex(this.KEY_CommandEntries_Command));
                const orderIndex = queryResult.getLong(queryResult.getColumnIndex(this.KEY_CommandEntries_OrderIndex));
                const accountInputRequired =
                    queryResult.getLong(queryResult.getColumnIndex(this.KEY_CommandEntries_AccountInputRequired));
                const idInputRequired =
                    queryResult.getLong(queryResult.getColumnIndex(this.KEY_CommandEntries_IDInputRequired));

                commandEntries.push(new CommandEntry(
                    id, nickname, command, orderIndex, accountInputRequired, idInputRequired
                ));
            }

            commandEntries.sort((a, b) => a.orderIndex - b.orderIndex);

            Logger.debug(this.LOG_TAG, `指令列表长度: ${commandEntries.length}`);

            return commandEntries;
        } catch (err) {
            throw new Error(`获取快捷指令列表失败, ${this.errorText(err)}`);
        } finally {
            this.closeResultSet(queryResult, 'getCommandList()');
        }
    }

    async addCommandEntry(commandEntry: CommandEntry) {
        await this.waitForReady();

        if (!this.rdbStore) throw new Error("数据库实例不存在");

        try {
            const valueBucket: relationalStore.ValuesBucket = {
                "NICKNAME": commandEntry.nickname,
                "COMMAND": commandEntry.command,
                "ORDERINDEX": commandEntry.orderIndex,
                "AIR": commandEntry.accountInputRequired,
                "IIR": commandEntry.idInputRequired
            };

            Logger.debug(this.LOG_TAG,
                `Adding new command -
                Nickname: ${commandEntry.nickname},
                Command: ${commandEntry.command},
                OrderIndex: ${commandEntry.orderIndex},
                AIR: ${commandEntry.accountInputRequired},
                IIR: ${commandEntry.idInputRequired}`
            );

            const result = await this.rdbStore.insert(this.TN_CommandEntries, valueBucket);

            return result;
        } catch (err) {
            throw err as Error;
        }
    }

    async updateCommandEntry(commandEntry: CommandEntry) {
        await this.waitForReady();

        if (!this.rdbStore) throw new Error("数据库实例不存在");

        Logger.debug(this.LOG_TAG, `更新指令 -
            ID: ${commandEntry.id},
            Nickname: ${commandEntry.nickname},
            Command: ${commandEntry.command},
            OrderIndex: ${commandEntry.orderIndex},
            AIR: ${commandEntry.accountInputRequired},
            IIR: ${commandEntry.idInputRequired}`
        );

        try {
            let predicates = new relationalStore.RdbPredicates(this.TN_CommandEntries);
            predicates.equalTo(this.KEY_ID, commandEntry.id);

            const valueBucket: relationalStore.ValuesBucket = {
                "NICKNAME": commandEntry.nickname,
                "COMMAND": commandEntry.command,
                "ORDERINDEX": commandEntry.orderIndex,
                "AIR": commandEntry.accountInputRequired,
                "IIR": commandEntry.idInputRequired
            };

            const result = await this.rdbStore.update(valueBucket, predicates);

            return result;
        } catch (err) {
            throw err as Error;
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
            throw err as Error;
        }
    }

    async batchUpdateOrderIndices(orderUpdates: Array<Array<number>>): Promise<boolean> {
        await this.waitForReady();

        if (!this.rdbStore) {
            Logger.error(this.LOG_TAG, "数据库实例不存在，无法更新排序");
            return false;
        }

        try {
            // 开始事务
            this.rdbStore.beginTransaction();

            for (const update of orderUpdates) {
                const id = update[0];
                const orderIndex = update[1];

                const predicates = new relationalStore.RdbPredicates(this.TN_CommandEntries);
                predicates.equalTo(this.KEY_ID, id);

                const valueBucket: relationalStore.ValuesBucket = {
                    "ORDERINDEX": orderIndex // 只更新排序字段
                };

                await this.rdbStore.update(valueBucket, predicates);
                // Logger.debug(this.LOG_TAG, `已更新条目 ID：${id} 的排序索引为：${orderIndex}`);
            }

            // 提交事务
            this.rdbStore.commit();
            Logger.info(this.LOG_TAG, `批量排序更新成功，共处理 ${orderUpdates.length} 个条目。`);
            return true;
        } catch (err) {
            // 回滚事务
            if (this.rdbStore) {
                try {
                    this.rdbStore.rollBack();
                } catch (rollbackErr) {
                    Logger.error(this.LOG_TAG, `批量更新排序索引回滚失败, ${this.errorText(rollbackErr)}`);
                }
            }
            Logger.error(this.LOG_TAG, `批量更新排序索引失败，已回滚: ${this.errorText(err)}`);
            return false;
        }
    }

    private errorText(err: Object): string {
        const e = err as BusinessError;
        if (e && e.message) return `${e.code}: ${e.message}`;
        return `${err}`;
    }

    private closeResultSet(resultSet: relationalStore.ResultSet | null, caller: string) {
        if (!resultSet) return;
        try {
            resultSet.close();
        } catch (err) {
            Logger.error(this.LOG_TAG, `${caller} 关闭查询结果集失败, ${this.errorText(err)}`);
        }
    }

    private async waitForReady(): Promise<void> {
        if (!this.initPromise) throw new Error("数据库未初始化. 先调用 init()");
        await this.initPromise;
    }
}