import { ConfigurationConstant } from '@kit.AbilityKit';

import StyleConstants from '../../common/constants/StyleConstants';

export class ColorModeOption {
    label: Resource;
    mode: ConfigurationConstant.ColorMode;

    constructor(label: Resource, mode: ConfigurationConstant.ColorMode) {
        this.label = label;
        this.mode = mode;
    }
}

// 三档顺序即 `Select` 菜单顺序，`selected` 用的就是这个数组的下标。
export const colorModeOptions: ColorModeOption[] = [
    new ColorModeOption($r("app.string.Color_Mode_System_Label"), ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET),
    new ColorModeOption($r("app.string.Color_Mode_Light_Label"), ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT),
    new ColorModeOption($r("app.string.Color_Mode_Dark_Label"), ConfigurationConstant.ColorMode.COLOR_MODE_DARK)
];

/**
 * 颜色模式行：行解剖照 `MoreMenuItem`（图标 + 标题 + 描述），右侧加原生 `Select` 胶囊。
 *
 * 只做展示与事件：当前档与三档选项由调用方给，选择通过 `onSelectMode` 抛回去。
 * 不持有 `AppStorageV2` 连接、不碰 `AppSettingsManager`、不调 `setColorMode`——写设置与改应用颜色是调用方的事。
 *
 * 下拉由原生 `Select` 自己弹出，不自绘；`Select` 没有可编程展开的 API，所以可点区域是胶囊自身（行本身不加点击）。
 */
@ComponentV2
export struct ColorModeRow {
    @Require @Param icon: ResourceStr;
    @Require @Param label: ResourceStr;
    @Require @Param desc: ResourceStr;
    @Param options: ColorModeOption[] = colorModeOptions;
    @Param currentMode: ConfigurationConstant.ColorMode = ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;

    @Event onSelectMode: (mode: ConfigurationConstant.ColorMode) => void = () => {
    };

    private buildSelectOptions(): Array<SelectOption> {
        const selectOptions: Array<SelectOption> = [];
        for (const option of this.options) {
            const selectOption: SelectOption = { value: option.label };
            selectOptions.push(selectOption);
        }
        return selectOptions;
    }

    private currentIndex(): number {
        for (let index = 0; index < this.options.length; index++) {
            if (this.options[index].mode === this.currentMode) return index;
        }
        return 0;
    }

    private currentLabel(): ResourceStr {
        const index = this.currentIndex();
        return this.options.length > index ? this.options[index].label : '';
    }

    build() {
        Row() {
            Image(this.icon)
                .width(StyleConstants.MORE_MENU_ITEM_ICON_SIZE)
                .height(StyleConstants.MORE_MENU_ITEM_ICON_SIZE)
                .margin(StyleConstants.MARGIN_TEN)

            Column() {
                Text(this.label)
                    .fontSize(StyleConstants.COLOR_MODE_ROW_LABEL_FONT_SIZE)
                    .fontWeight(FontWeight.Medium)
                    .textAlign(TextAlign.Start)
                    .width(StyleConstants.FULL_PERCENT)

                Text(this.desc)
                    .fontColor($r("sys.color.font_tertiary"))
                    .fontSize(StyleConstants.MORE_MENU_ITEM_DESC_FONT_SIZE)
                    .fontWeight(FontWeight.Normal)
                    .textAlign(TextAlign.Start)
                    .width(StyleConstants.FULL_PERCENT)
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)

            Select(this.buildSelectOptions())
                .selected(this.currentIndex())
                .value(this.currentLabel())
                .font({ size: StyleConstants.COLOR_MODE_ROW_SELECT_FONT_SIZE })
                .fontColor($r("sys.color.font_secondary"))
                .margin({ left: StyleConstants.MARGIN_TEN })
                .onSelect((index: number) => {
                    this.onSelectMode(this.options[index].mode);
                })
        }
        .width(StyleConstants.FULL_PERCENT)
        .constraintSize({ minHeight: StyleConstants.COLOR_MODE_ROW_MIN_HEIGHT })
        // 左右 20vp：同组 `MoreMenuItem` 行是内容宽度、被 Column 居中（实测左缘 45px 处），加它自身的 5vp 内距，
        // 本行的图标与标签因此与上一行左缘对齐，胶囊右缘落在分隔线右端。
        // 该值是在当前视口下量出来的，邻居行的左缘随视口宽度变；彻底的做法是让同组行共用一个容器定义水平缘线，
        // 随页面重写一并做。
        .padding({
            top: StyleConstants.PADDING_FIVE,
            left: StyleConstants.PADDING_TWENTY,
            right: StyleConstants.PADDING_TWENTY,
            bottom: StyleConstants.PADDING_FIVE
        })
    }
}
