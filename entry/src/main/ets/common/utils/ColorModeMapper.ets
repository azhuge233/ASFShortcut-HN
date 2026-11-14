import { ConfigurationConstant } from '@kit.AbilityKit';

import { ColorMode } from '../../domain/model/AppSettings';

/**
 * 领域枚举 `ColorMode` ↔ 平台 `ConfigurationConstant.ColorMode` 的映射：全应用唯一一份。
 *
 * 落 `common/` 是因为 `ui/`（`MorePage` 要算当前胶囊与选择回调）与 `data/`（`AppSettingsStore` 落盘）
 * 两个方向都要用，而这两层互不 import（设计 §2.4.1）。`domain/` 仍然不碰平台枚举。
 * B3 之前这两个函数住在 `data/store/AppSettingsStore.ets`；搬走后调用方按本文件取，Store 也改成从这里取。
 */

/** 领域枚举 → 平台枚举 */
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
