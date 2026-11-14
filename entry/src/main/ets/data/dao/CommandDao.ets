import { relationalStore } from '@kit.ArkData';

import Logger from '../../common/utils/Logger';
import CommandEntry from '../../domain/model/CommandEntry';
import { CommandRepository } from '../../domain/repository/CommandRepository';
import {
    closeResultSet,
    Database,
    errorText,
    KEY_COMMAND_AIR,
    KEY_COMMAND_COMMAND,
    KEY_COMMAND_IIR,
    KEY_COMMAND_NICKNAME,
    KEY_COMMAND_ORDER_INDEX,
    KEY_ID,
    SQL_DELETE_TABLE_PREFIX,
    TN_COMMAND_ENTRIES
} from '../Database';

const LOG_TAG: string = '[CommandDao]';

/**
 * `COMMANDENTRIES` 表的全量存取。判断一律不在这里：删除先解绑、改条目是否解绑都在 `domain/service/CommandService`。
 * 写入方法在失败时抛错，由领域层决定「失败」怎么表现（设计 §2.2、§2.3）。
 */
export class CommandDao implements CommandRepository {
    private static instance: CommandDao | null = null;

    private db: Database = Database.getInstance();

    private constructor() {
    }

    public static getInstance(): CommandDao {
        if (!CommandDao.instance) CommandDao.instance = new CommandDao();
        return CommandDao.instance;
    }

    private readonly COLUMNS: string[] = [
        KEY_ID,
        KEY_COMMAND_NICKNAME,
        KEY_COMMAND_COMMAND,
        KEY_COMMAND_ORDER_INDEX,
        KEY_COMMAND_AIR,
        KEY_COMMAND_IIR
    ];

    async getByID(id: number): Promise<CommandEntry | null> {
        await this.db.waitForReady();

        const store = this.db.requireStore();

        const predicates = new relationalStore.RdbPredicates(TN_COMMAND_ENTRIES);
        predicates.equalTo(KEY_ID, id);

        let queryResult: relationalStore.ResultSet | null = null;
        try {
            queryResult = await store.query(predicates, this.COLUMNS);

            if (queryResult.goToNextRow()) {
                const entry = this.readEntry(queryResult);

                Logger.debug(LOG_TAG, `查询到 ${id}: ${JSON.stringify(entry)}`);

                return entry;
            }

            Logger.debug(LOG_TAG, `没有查询到 ID = ${id} 的结果`);
            return null;
        } catch (err) {
            Logger.error(LOG_TAG, `getByID 执行失败, ${errorText(err)}`);
            return null;
        } finally {
            closeResultSet(queryResult, LOG_TAG, 'getByID()');
        }
    }

    async list(): Promise<CommandEntry[]> {
        await this.db.waitForReady();

        const store = this.db.requireStore();

        const predicates = new relationalStore.RdbPredicates(TN_COMMAND_ENTRIES);

        let queryResult: relationalStore.ResultSet | null = null;
        try {
            queryResult = await store.query(predicates, this.COLUMNS);

            if (!queryResult) throw new Error("查询为空");

            Logger.debug(LOG_TAG, `查询结果，行数: ${queryResult.rowCount}, 列数: ${queryResult.columnCount}`);

            const commandEntries: Array<CommandEntry> = [];

            while (queryResult.goToNextRow()) {
                commandEntries.push(this.readEntry(queryResult));
            }

            commandEntries.sort((a, b) => a.orderIndex - b.orderIndex);

            Logger.debug(LOG_TAG, `指令列表长度: ${commandEntries.length}`);

            return commandEntries;
        } catch (err) {
            // 列表读失败要让上层看见：吞掉会显示成「没有指令」（设计 §2.11 第三条）
            throw new Error(`获取快捷指令列表失败, ${errorText(err)}`);
        } finally {
            closeResultSet(queryResult, LOG_TAG, 'list()');
        }
    }

    async insert(entry: CommandEntry): Promise<number> {
        await this.db.waitForReady();

        const store = this.db.requireStore();

        const valueBucket: relationalStore.ValuesBucket = {
            'NICKNAME': entry.nickname,
            'COMMAND': entry.command,
            'ORDERINDEX': entry.orderIndex,
            'AIR': entry.accountInputRequired,
            'IIR': entry.idInputRequired
        };

        Logger.debug(LOG_TAG,
            `Adding new command -
            Nickname: ${entry.nickname},
            Command: ${entry.command},
            OrderIndex: ${entry.orderIndex},
            AIR: ${entry.accountInputRequired},
            IIR: ${entry.idInputRequired}`
        );

        return store.insert(TN_COMMAND_ENTRIES, valueBucket);
    }

    async update(entry: CommandEntry): Promise<boolean> {
        await this.db.waitForReady();

        const store = this.db.requireStore();

        Logger.debug(LOG_TAG, `更新指令 -
            ID: ${entry.id},
            Nickname: ${entry.nickname},
            Command: ${entry.command},
            OrderIndex: ${entry.orderIndex},
            AIR: ${entry.accountInputRequired},
            IIR: ${entry.idInputRequired}`
        );

        const predicates = new relationalStore.RdbPredicates(TN_COMMAND_ENTRIES);
        predicates.equalTo(KEY_ID, entry.id);

        const valueBucket: relationalStore.ValuesBucket = {
            'NICKNAME': entry.nickname,
            'COMMAND': entry.command,
            'ORDERINDEX': entry.orderIndex,
            'AIR': entry.accountInputRequired,
            'IIR': entry.idInputRequired
        };

        // 与 1.7.1 一致：不检查受影响行数，写入未抛错即算成功
        await store.update(valueBucket, predicates);
        return true;
    }

    async deleteByID(id: number): Promise<boolean> {
        await this.db.waitForReady();

        const store = this.db.requireStore();

        Logger.debug(LOG_TAG, `删除指令, ID: ${id}`);

        const predicates = new relationalStore.RdbPredicates(TN_COMMAND_ENTRIES);
        predicates.equalTo(KEY_ID, id);

        await store.delete(predicates);
        return true;
    }

    async batchUpdateOrderIndices(entries: CommandEntry[]): Promise<boolean> {
        await this.db.waitForReady();

        const store = this.db.requireStore();

        try {
            store.beginTransaction();

            for (const entry of entries) {
                const predicates = new relationalStore.RdbPredicates(TN_COMMAND_ENTRIES);
                predicates.equalTo(KEY_ID, entry.id);

                const valueBucket: relationalStore.ValuesBucket = {
                    'ORDERINDEX': entry.orderIndex
                };

                await store.update(valueBucket, predicates);
            }

            store.commit();
            Logger.info(LOG_TAG, `批量排序更新成功，共处理 ${entries.length} 个条目。`);
            return true;
        } catch (err) {
            try {
                store.rollBack();
            } catch (rollbackErr) {
                Logger.error(LOG_TAG, `批量更新排序索引回滚失败, ${errorText(rollbackErr)}`);
            }
            Logger.error(LOG_TAG, `批量更新排序索引失败，已回滚: ${errorText(err)}`);
            return false;
        }
    }

    async replaceAll(entries: CommandEntry[]): Promise<boolean> {
        await this.db.waitForReady();

        const store = this.db.requireStore();

        try {
            // 事务由调用方组织（导入要与设置表同事务）；本方法自开事务会把整表替换拆成两次提交
            await store.executeSql(`${SQL_DELETE_TABLE_PREFIX}${TN_COMMAND_ENTRIES}`);

            for (const entry of entries) {
                const valueBucket: relationalStore.ValuesBucket = {
                    'NICKNAME': entry.nickname,
                    'COMMAND': entry.command,
                    'ORDERINDEX': entry.orderIndex,
                    'AIR': entry.accountInputRequired,
                    'IIR': entry.idInputRequired
                };
                await store.insert(TN_COMMAND_ENTRIES, valueBucket);
            }

            Logger.info(LOG_TAG, `指令表已整体替换，共 ${entries.length} 条`);
            return true;
        } catch (err) {
            Logger.error(LOG_TAG, `指令表整体替换失败, ${errorText(err)}`);
            return false;
        }
    }

    private readEntry(queryResult: relationalStore.ResultSet): CommandEntry {
        const id = queryResult.getLong(queryResult.getColumnIndex(KEY_ID));
        const nickname = queryResult.getString(queryResult.getColumnIndex(KEY_COMMAND_NICKNAME));
        const command = queryResult.getString(queryResult.getColumnIndex(KEY_COMMAND_COMMAND));
        const orderIndex = queryResult.getLong(queryResult.getColumnIndex(KEY_COMMAND_ORDER_INDEX));
        const accountInputRequired = queryResult.getLong(queryResult.getColumnIndex(KEY_COMMAND_AIR));
        const idInputRequired = queryResult.getLong(queryResult.getColumnIndex(KEY_COMMAND_IIR));

        return new CommandEntry(id, nickname, command, orderIndex, accountInputRequired, idInputRequired);
    }
}
