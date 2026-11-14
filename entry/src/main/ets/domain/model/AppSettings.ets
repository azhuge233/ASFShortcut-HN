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

@ObservedV2
export class AppSettings {
    @Trace colorMode: ColorMode;

    constructor(colorMode: ColorMode) {
        this.colorMode = colorMode;
    }
}
