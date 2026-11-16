import { preferences } from '@kit.ArkData';
import { deviceInfo } from '@kit.BasicServicesKit';
import { ConfigurationConstant } from '@kit.AbilityKit';

import Logger from '../../common/utils/Logger';
import { toDomainColorMode, toPlatformColorMode } from '../../common/utils/ColorModeMapper';
import { AppSettings, ColorMode, ListLayout } from '../../domain/model/AppSettings';
import { AppSettingsRepository } from '../../domain/repository/AppSettingsRepository';

const LOG_TAG: string = '[AppSettingsStore]';

/*
 * `ASFS_App_Preferences` 的读写。落盘值仍是原枚举数值，旧数据可直接读。
 * 领域枚举 ↔ 平台枚举的映射表在 `common/utils/ColorModeMapper.ets`（B3 搬出本文件，供 ui 与 data 共用）。
 *
 * 列表布局另起一个键 `ListLayout`，仍存裸数值：既有 `AppSettings` 键存的是裸数值，
 * 把布局塞进同一个键就得改成对象形态，那是一次格式迁移；新键零迁移，颜色模式那条路径一行不动（设计 §2.1）。
 */

export class AppSettingsStore {
    private static instance: AppSettingsStore | null = null;

    private dataPreferences: preferences.Preferences | null = null;

    private readonly PREFERENCES_NAME = 'ASFS_App_Preferences';
    private readonly STORE_KEY = 'AppSettings';
    private readonly LAYOUT_KEY = 'ListLayout';

    private readonly isGSKVSupported = deviceInfo.sdkApiVersion >= 18 && preferences.isStorageTypeSupported(preferences.StorageType.GSKV);

    private constructor() {
    }

    public static getInstance(): AppSettingsStore {
        if (!AppSettingsStore.instance) AppSettingsStore.instance = new AppSettingsStore();
        return AppSettingsStore.instance;
    }

    init(context: Context): void {
        if (this.dataPreferences) return;

        try {
            let options: preferences.Options = {
                name: this.PREFERENCES_NAME,
                storageType: this.isGSKVSupported ? preferences.StorageType.GSKV : preferences.StorageType.XML
            };

            this.dataPreferences = preferences.getPreferencesSync(context, options);

            Logger.debug(LOG_TAG, `应用设置初始化完成`);
        } catch (err) {
            Logger.error(LOG_TAG, `应用设置初始化失败, ${err}`);
        }
    }

    async set(appSettings: AppSettings): Promise<boolean> {
        if (!this.checkReady()) return false;

        try {
            await this.dataPreferences?.put(this.STORE_KEY, toPlatformColorMode(appSettings.colorMode));
            if (!this.isGSKVSupported) await this.dataPreferences?.flush();
            return true;
        } catch (err) {
            Logger.error(LOG_TAG, `保存应用设置失败, ${err}`);
            return false;
        }
    }

    async get(): Promise<AppSettings | null> {
        if (!this.checkReady()) return null;

        try {
            const stored = await this.dataPreferences!.get(this.STORE_KEY,
                ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET) as Object;
            let mode: ColorMode | null = null;

            if (typeof stored === 'number') {
                mode = toDomainColorMode(stored as number);
            } else if (stored && typeof stored === 'object') {
                // 旧版本存过 { colorMode: number } 形态，读取时兼容
                const legacy = stored as Record<string, Object>;
                if (typeof legacy['colorMode'] === 'number') {
                    mode = toDomainColorMode(legacy['colorMode'] as number);
                }
            }

            if (mode !== null) return new AppSettings(mode);

            return null;
        } catch (err) {
            Logger.error(LOG_TAG, `获取应用设置失败, ${err}`);
            return null;
        }
    }

    private checkReady(): boolean {
        if (!this.dataPreferences) {
            Logger.error(LOG_TAG, `首选项未初始化`);
            return false;
        }
        return true;
    }

    /** 写列表布局：与 `set(appSettings)` 同形（GSKV 直写、XML 写后 flush），失败返回 false */
    async setLayout(layout: ListLayout): Promise<boolean> {
        if (!this.checkReady()) return false;

        try {
            await this.dataPreferences?.put(this.LAYOUT_KEY, layout as number);
            if (!this.isGSKVSupported) await this.dataPreferences?.flush();
            return true;
        } catch (err) {
            Logger.error(LOG_TAG, `保存列表布局失败, ${err}`);
            return false;
        }
    }

    /** 读列表布局：没存过时按单列；存过的值只有单 / 双两档，其余按单列读 */
    async getLayout(): Promise<ListLayout> {
        if (!this.checkReady()) return ListLayout.SINGLE;

        try {
            const stored = await this.dataPreferences!.get(this.LAYOUT_KEY,
                ListLayout.SINGLE as number) as Object;

            if (typeof stored === 'number' && (stored as number) === ListLayout.DOUBLE) return ListLayout.DOUBLE;
            return ListLayout.SINGLE;
        } catch (err) {
            Logger.error(LOG_TAG, `获取列表布局失败, ${err}`);
            return ListLayout.SINGLE;
        }
    }
}

/**
 * `AppSettingsRepository` 的 data 侧实现（设计 §2.4.1）。VM 只认这个接口，不认 Store。
 *
 * 单独立类而不让 `AppSettingsStore` 直接 implements，是因为接口的 `get()` / `set(mode)`
 * 与 Store 既有的 `get(): Promise<AppSettings | null>` / `set(appSettings)` 同名不同形；
 * 接口「只加不减」，既有签名不动（三个 Ability 仍在用），所以由本类做转发。
 * 布局两个方法同理转发，Store 侧与 `get` / `set` 同形。
 */
export class AppSettingsRepositoryImpl implements AppSettingsRepository {
    private store: AppSettingsStore = AppSettingsStore.getInstance();

    async get(): Promise<ColorMode> {
        const settings: AppSettings | null = await this.store.get();
        return settings ? settings.colorMode : ColorMode.FOLLOW_SYSTEM;
    }

    async set(mode: ColorMode): Promise<boolean> {
        return this.store.set(new AppSettings(mode));
    }

    async getLayout(): Promise<ListLayout> {
        return this.store.getLayout();
    }

    async setLayout(layout: ListLayout): Promise<boolean> {
        return this.store.setLayout(layout);
    }
}
