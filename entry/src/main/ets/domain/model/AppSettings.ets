/**
 * 颜色模式：领域枚举。
 *
 * 数值与落盘值一致（平台枚举 -1 / 0 / 1），因此旧数据可直接读，
 * `data/store/AppSettingsStore.ets` 做的只是同值映射。`domain/` 不得 import 平台能力 kit，
 * 平台枚举只出现在 `data/` 与 `ability/` 两处（设计 §1.5 规则 1、§2.9）。
 */
export enum ColorMode {
    FOLLOW_SYSTEM = -1,
    DARK = 0,
    LIGHT = 1
}

/**
 * 主列表布局：领域枚举。
 *
 * 数值即落盘值，落在 `ASFS_App_Preferences` 的新键 `ListLayout` 上；没存过时读回 `SINGLE`。
 * 键名与枚举同拼写只是巧合——前者是首选项的字符串键，后者是 TS 枚举，两者无耦合。
 */
export enum ListLayout {
    SINGLE = 0,
    DOUBLE = 1
}

@ObservedV2
export class AppSettings {
    @Trace colorMode: ColorMode;
    // 列表布局与颜色模式同一份可观察对象、同一条落盘路径（设计 §2.1 / §2.2）
    @Trace listLayout: ListLayout;

    constructor(colorMode: ColorMode, listLayout: ListLayout = ListLayout.SINGLE) {
        this.colorMode = colorMode;
        this.listLayout = listLayout;
    }
}
