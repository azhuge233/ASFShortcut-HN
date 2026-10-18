import { preferences } from '@kit.ArkData';
import { deviceInfo } from '@kit.BasicServicesKit';
import { ConfigurationConstant } from '@kit.AbilityKit';

import Logger from '../utils/Logger';
import { AppSettings } from '../../model/AppSettings';

export class AppSettingsManager {
    private LOG_TAG = "[AppSettingsManager]";

    private static instance: AppSettingsManager | null = null;

    private dataPreferences: preferences.Preferences | null = null;

    private readonly PREFERENCES_NAME = 'ASFS_App_Preferences';
    private readonly STORE_KEY = 'AppSettings';

    private readonly isGSKVSupported = deviceInfo.sdkApiVersion >= 18 && preferences.isStorageTypeSupported(preferences.StorageType.GSKV);

    private constructor() {}

    public static getInstance(): AppSettingsManager {
        if (!AppSettingsManager.instance) AppSettingsManager.instance = new AppSettingsManager();
        return AppSettingsManager.instance;
    }

    init(context: Context) {
        try {
            let options: preferences.Options = {
                name: this.PREFERENCES_NAME,
                storageType: this.isGSKVSupported ? preferences.StorageType.GSKV : preferences.StorageType.XML
            }

            this.dataPreferences = preferences.getPreferencesSync(context, options);

            Logger.debug(this.LOG_TAG, `应用设置初始化完成`);
        } catch (err) {
            Logger.error(this.LOG_TAG, `应用设置初始化失败, ${err}`);
        }
    }

    async set(appSettings: AppSettings): Promise<boolean> {
        if(!this.checkReady()) return false;

        try {
            await this.dataPreferences?.put(this.STORE_KEY, appSettings.colorMode);
            if(!this.isGSKVSupported) await this.dataPreferences?.flush();
            return true;
        } catch (err) {
            Logger.error(this.LOG_TAG, `保存应用设置失败, ${err}`);
            return false;
        }
    }

    async get(): Promise<AppSettings | null> {
        if(!this.checkReady()) return null;

        try {
            const stored = await this.dataPreferences!.get(this.STORE_KEY, ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET) as Object;
            let mode: ConfigurationConstant.ColorMode | null = null;

            if (typeof stored === 'number') {
                mode = stored as ConfigurationConstant.ColorMode;
            } else if (stored && typeof stored === 'object') {
                const legacy = stored as Record<string, Object>;
                if (typeof legacy['colorMode'] === 'number') {
                    mode = legacy['colorMode'] as ConfigurationConstant.ColorMode;
                }
            }

            if (mode !== null && (mode === ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET ||
                mode === ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT ||
                mode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK)) {
                return new AppSettings(mode);
            }

            return null;
        } catch (err) {
            Logger.error(this.LOG_TAG, `获取应用设置失败, ${err}`);
            return null;
        }
    }

    private checkReady(): boolean {
        if (!this.dataPreferences) {
            Logger.error(this.LOG_TAG, `首选项未初始化`);
            return false;
        }
        return true;
    }
}