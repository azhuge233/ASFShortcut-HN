import { preferences } from '@kit.ArkData';
import { deviceInfo } from '@kit.BasicServicesKit';
import { ConfigurationConstant } from '@kit.AbilityKit';

import Logger from '../../common/utils/Logger';
import { AppSettings, ColorMode } from '../../domain/model/AppSettings';

const LOG_TAG: string = '[AppSettingsStore]';

/*
 * `ASFS_App_Preferences` 的读写。
 * 这里也是「领域枚举 `ColorMode` ↔ 平台 `ConfigurationConstant.ColorMode`」映射表的落点之一
 * （另一处是 `ability/` 调 `setColorMode` 的地方，设计 §1.5、§2.9）；落盘值仍是原枚举数值，旧数据可直接读。
 */

/** 领域枚举 → 平台枚举。`MorePage` 与本文件之外的调用方都走这一个函数，映射表不复制第二份 */
export function toPlatformColorMode(mode: ColorMode): ConfigurationConstant.ColorMode {
    switch (mode) {
        case ColorMode.DARK:
            return ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
        case ColorMode.LIGHT:
            return ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;
        default:
            return ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;
    }
}

/** 落盘数值（或平台枚举）→ 领域枚举；不认识的值返回 null（调用方按「未设置」处理） */
export function toDomainColorMode(value: number): ColorMode | null {
    switch (value) {
        case ConfigurationConstant.ColorMode.COLOR_MODE_DARK:
            return ColorMode.DARK;
        case ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT:
            return ColorMode.LIGHT;
        case ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET:
            return ColorMode.FOLLOW_SYSTEM;
        default:
            return null;
    }
}

export class AppSettingsStore {
    private static instance: AppSettingsStore | null = null;

    private dataPreferences: preferences.Preferences | null = null;

    private readonly PREFERENCES_NAME = 'ASFS_App_Preferences';
    private readonly STORE_KEY = 'AppSettings';

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
}
