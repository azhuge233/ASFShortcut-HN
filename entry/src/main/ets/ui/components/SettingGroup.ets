import { AppCard } from "./AppCard";
import { SettingRow } from "./SettingRow";

/** 一条设置项：字段名取值，可选字段不传即取默认值；新增一项只写一个对象字面量（设计 §2.4） */
export interface SettingEntry {
    title: ResourceStr;
    icon?: Resource;                     // 无图标行（关于页）不传
    desc?: ResourceStr;
    descAbove?: boolean;                 // 关于页的「小字标签在上、值在下」
    titleColor?: ResourceColor;
    showArrow?: boolean;                 // 子页面入口传 true：行右侧出现箭头（本批 D5）；默认 false
    onTap?: () => void | Promise<void>;
}

/**
 * 分组卡 + N 行同形条目（C1 / C4）：收改造前三处「一张卡 + 若干行」的装配
 * （设置页两张、数据管理页一张普通卡与一张危险色单行卡）——前两处的代码逐字相同。
 *
 * 入口只有 `entries` 一个，**不开插槽**（D13）：带控件插槽的行与 `descAbove` 的行都进不了数据数组，
 * 那两处（颜色模式组、关于页的卡）在页内用 `AppCard` + `SettingRow` 装配。
 *
 * 数据行的标题单行 + 省略号（`titleMaxLines: 1`）；行内形态全仓只有一种，由 `SettingRow` 给（本批 D2）。
 */
@ComponentV2
export struct SettingGroup {
    @Param entries: SettingEntry[] = [];

    build() {
        AppCard() {
            ForEach(this.entries, (entry: SettingEntry) => {
                SettingRow({
                    title: entry.title,
                    icon: entry.icon ?? null,
                    desc: entry.desc ?? null,
                    descAbove: entry.descAbove ?? false,
                    titleColor: entry.titleColor ?? $r('sys.color.font_primary'),
                    showArrow: entry.showArrow ?? false,
                    titleMaxLines: 1,
                    onTap: entry.onTap ?? (() => {
                    })
                })
            }, (entry: SettingEntry, index: number) => index.toString())
        }
    }
}
