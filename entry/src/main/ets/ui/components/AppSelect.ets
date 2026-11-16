import StyleConstants from "../../common/constants/StyleConstants";

/**
 * 设置行右侧的「控件」插槽实现（C1 / D1）：现在只有颜色模式行的原生 `Select` 一个实例。
 *
 * 单列成件而不是塞进 `SettingRow` 的分支：`SettingRow` 是通用行，内嵌一种具体控件的样式常量
 * 会让第二个控件来时又开一个分支（D1）。五个修饰符逐字取自改造前颜色模式行里那个 `Select`。
 */
@ComponentV2
export struct AppSelect {
    @Param options: ResourceStr[] = [];
    @Param selectedIndex: number = 0;
    @Event onSelect: (index: number) => void = () => {};

    private buildOptions(): SelectOption[] {
        const items: SelectOption[] = [];
        for (const option of this.options) {
            const item: SelectOption = { value: option };
            items.push(item);
        }
        return items;
    }

    /** 当前档的显示文字：下标越界时留空（与改造前颜色模式行同一条判据） */
    private currentLabel(): ResourceStr {
        return this.options.length > this.selectedIndex ? this.options[this.selectedIndex] : '';
    }

    build() {
        Select(this.buildOptions())
            .selected(this.selectedIndex)
            .value(this.currentLabel())
            .font({ size: StyleConstants.COLOR_MODE_ROW_SELECT_FONT_SIZE })
            .fontColor($r("sys.color.font_secondary"))
            // 限高：原生 `Select` 默认高约 40vp，会把该行撑得比同组其它行高一截（需求 U13 / 设计 §2.6 ⑥）。
            // 实测本属性在当前 SDK 上不生效（取值 32 后组件仍渲染 40vp），照搬是为了与改前逐句同形。
            .height(StyleConstants.COLOR_MODE_ROW_SELECT_HEIGHT)
            .margin({ left: StyleConstants.MARGIN_TEN })
            .onSelect((index: number) => {
                this.onSelect(index);
            })
    }
}
