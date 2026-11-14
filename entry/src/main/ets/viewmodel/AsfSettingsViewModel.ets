import Logger from '../common/utils/Logger';
import CommonConstants from '../common/constants/CommonConstants';
import { SettingsRepository } from '../domain/repository/SettingsRepository';
import { AsfAddress } from '../domain/service/AsfAddress';
import { settingsRepository } from '../domain/service/DependencyWiring';

/**
 * ASF 设置页的 VM（设计 §2.4.2）。草稿两字段、保存中标记兼返回键守卫，动作只到 `SettingsRepository`。
 * 页面不再 import `SettingsDao`，也不再自己调 `AsfAddress.normalize`。
 */
@ObservedV2
export default class AsfSettingsViewModel {
    private LOG_TAG = '[AsfSettingsViewModel]';

    @Trace address: string = '';
    @Trace password: string = '';
    // 保存进行中，兼作返回键守卫
    @Trace isSaving: boolean = false;

    private settings: SettingsRepository;

    constructor(settings: SettingsRepository = settingsRepository()) {
        this.settings = settings;
    }

    /** 读两个键填草稿 */
    async load(): Promise<void> {
        this.address = await this.settings.get(CommonConstants.DB_KEY_HOST_INFO_ADDRESS);
        this.password = await this.settings.get(CommonConstants.DB_KEY_HOST_INFO_PASSWORD);
    }

    /** 两字段 `trim()` 均非空 */
    canSave(): boolean {
        return this.address.trim() !== '' && this.password.trim() !== '';
    }

    /** 地址经 `AsfAddress.normalize` 后与密码一起落盘；两个键任一失败即 false */
    async save(): Promise<boolean> {
        this.isSaving = true;

        try {
            const saved1: boolean = await this.settings.save(CommonConstants.DB_KEY_HOST_INFO_ADDRESS,
                AsfAddress.normalize(this.address));
            const saved2: boolean = await this.settings.save(CommonConstants.DB_KEY_HOST_INFO_PASSWORD,
                this.password);

            if (!saved1 || !saved2) Logger.warn(this.LOG_TAG, `save() 落盘失败, ${saved1}, ${saved2}`);
            return saved1 && saved2;
        } catch (err) {
            Logger.error(this.LOG_TAG, `save() 失败, ${err}`);
            return false;
        } finally {
            this.isSaving = false;
        }
    }
}
