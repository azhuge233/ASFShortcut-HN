import { relationalStore } from '@kit.ArkData';

import Logger from '../../common/utils/Logger';
import CommonConstants from '../../common/constants/CommonConstants';
import { SettingsRepository } from '../../domain/repository/SettingsRepository';
import {
    closeResultSet,
    Database,
    errorText,
    KEY_HOST_INFO_KEY,
    KEY_HOST_INFO_VALUE,
    KEY_ID,
    SQL_DELETE_TABLE_PREFIX,
    TN_HOST_INFO
} from '../Database';

const LOG_TAG: string = '[SettingsDao]';

/**
 * `HOSTINFO` 表的存取（地址与密码）。只做存取，不做判断（设计 §2.2、§2.3）。
 */
export class SettingsDao implements SettingsRepository {
    private static instance: SettingsDao | null = null;

    private db: Database = Database.getInstance();

    private constructor() {
    }

    public static getInstance(): SettingsDao {
        if (!SettingsDao.instance) SettingsDao.instance = new SettingsDao();
        return SettingsDao.instance;
    }

    async get(key: string): Promise<string> {
        await this.db.waitForReady();

        const defaultValue: string = '';

        if (!this.db.hasStore()) {
            Logger.error(LOG_TAG, "数据库实例不存在");
            return defaultValue;
        }

        const store = this.db.requireStore();

        let resultSet: relationalStore.ResultSet | null = null;
        try {
            const predicates = new relationalStore.RdbPredicates(TN_HOST_INFO);
            predicates.equalTo(KEY_HOST_INFO_KEY, key);

            resultSet = await store.query(predicates, [KEY_HOST_INFO_VALUE]);
            let value = defaultValue;

            if (resultSet.rowCount > 0 && resultSet.goToFirstRow()) {
                value = resultSet.getString(resultSet.getColumnIndex(KEY_HOST_INFO_VALUE));
            }

            return value;
        } catch (err) {
            Logger.error(LOG_TAG, `无法获取 ${key} 设置信息, ${errorText(err)}`);
            return defaultValue;
        } finally {
            closeResultSet(resultSet, LOG_TAG, 'get()');
        }
    }

    async save(key: string, value: string): Promise<boolean> {
        await this.db.waitForReady();

        if (!this.db.hasStore()) {
            Logger.error(LOG_TAG, "数据库实例不存在");
            return false;
        }

        const store = this.db.requireStore();

        try {
            const predicates = new relationalStore.RdbPredicates(TN_HOST_INFO);
            predicates.equalTo(KEY_HOST_INFO_KEY, key);

            let resultSet: relationalStore.ResultSet | null = null;
            try {
                resultSet = await store.query(predicates, [KEY_ID]);
                const exists = resultSet.rowCount > 0;

                if (exists) {
                    const valueBucket: relationalStore.ValuesBucket = {
                        'VALUE': value
                    };
                    await store.update(valueBucket, predicates);
                } else {
                    const valueBucket: relationalStore.ValuesBucket = {
                        'KEY': key,
                        'VALUE': value
                    };
                    await store.insert(TN_HOST_INFO, valueBucket);
                }
            } finally {
                closeResultSet(resultSet, LOG_TAG, 'save()');
            }

            Logger.info(LOG_TAG, `设置已保存: ${key}`);
            return true;
        } catch (err) {
            Logger.error(LOG_TAG, `无法保存设置 ${key}: ${errorText(err)}`);
            return false;
        }
    }

    async areComplete(): Promise<boolean> {
        const address = await this.get(CommonConstants.DB_KEY_HOST_INFO_ADDRESS);
        const password = await this.get(CommonConstants.DB_KEY_HOST_INFO_PASSWORD);

        return address.trim() !== '' && password.trim() !== '';
    }

    async replaceAll(entries: Array<[string, string]>): Promise<boolean> {
        await this.db.waitForReady();

        const store = this.db.requireStore();

        try {
            // 事务由调用方组织（导入要与指令表同事务）
            await store.executeSql(`${SQL_DELETE_TABLE_PREFIX}${TN_HOST_INFO}`);

            for (const entry of entries) {
                const valueBucket: relationalStore.ValuesBucket = {
                    'KEY': entry[0],
                    'VALUE': entry[1]
                };
                await store.insert(TN_HOST_INFO, valueBucket);
            }

            Logger.info(LOG_TAG, `设置表已整体替换，共 ${entries.length} 条`);
            return true;
        } catch (err) {
            Logger.error(LOG_TAG, `设置表整体替换失败, ${errorText(err)}`);
            return false;
        }
    }
}
