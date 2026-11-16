import { ColorMode, ListLayout } from '../model/AppSettings';

/**
 * 应用设置的读写接口。data 层实现、VM 持有（设计 §2.4.1）。
 *
 * 只给 VM 需要的那几件事：读当前档、写一档并落盘。`AppSettings` 这个可观察对象本身
 * 由 `AppStorageV2` 承载（全应用同一份），不经过本接口。
 */
export interface AppSettingsRepository {
    /** 当前颜色模式；没存过时为 `FOLLOW_SYSTEM` */
    get(): Promise<ColorMode>;

    /** 写入一档并落盘；落盘失败返回 false */
    set(mode: ColorMode): Promise<boolean>;

    /**
     * 当前列表布局；没存过时为 `SINGLE`（设计 §2.1）。
     *
     * 实现不得抛错：读失败同样返回 `SINGLE`。`CommandListViewModel.init()` 在 try 之外 await 它，
     * 一条抛出会连同设置与列表一起跳过。
     */
    getLayout(): Promise<ListLayout>;

    /** 写入布局并落盘；落盘失败返回 false */
    setLayout(layout: ListLayout): Promise<boolean>;
}
