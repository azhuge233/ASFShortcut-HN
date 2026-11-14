import { ColorMode } from '../model/AppSettings';

/**
 * 应用设置（颜色模式）的读写接口。data 层实现、VM 持有（设计 §2.4.1）。
 *
 * 只给 VM 需要的那两件事：读当前档、写一档并落盘。`AppSettings` 这个可观察对象本身
 * 由 `AppStorageV2` 承载（全应用同一份），不经过本接口。
 */
export interface AppSettingsRepository {
    /** 当前颜色模式；没存过时为 `FOLLOW_SYSTEM` */
    get(): Promise<ColorMode>;

    /** 写入一档并落盘；落盘失败返回 false */
    set(mode: ColorMode): Promise<boolean>;
}
