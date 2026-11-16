import StyleConstants from "../../common/constants/StyleConstants";

/**
 * 标题行的「有条件才挂」属性：`titleMaxLines` 不传时一次都不调用 `maxLines` 与 `textOverflow`。
 *
 * 与 `AppInput` 的描边同一手法（设计 D10）：写一个显式默认值就是换了一个来源，而盘上
 * 关于页的值文字本来没有这两句、开源地址会折两行；而列表行的标题有 `maxLines(1)` + 省略号。
 * 两种取值都要能表达，所以由调用方决定，组件不预设。
 */
class TitleLineModifier implements AttributeModifier<TextAttribute> {
    private maxLines: number | undefined = undefined;
    private color: ResourceColor | null = null;

    constructor(maxLines: number | undefined, color: ResourceColor | null) {
        this.maxLines = maxLines;
        this.color = color;
    }

    applyNormalAttribute(instance: TextAttribute): void {
        const lines: number | undefined = this.maxLines;
        if (lines !== undefined) {
            instance.maxLines(lines);
            instance.textOverflow({ overflow: TextOverflow.Ellipsis });
        }

        // `titleColor` 为 null = 一次都不调用：颜色模式行的标题在盘上没有这一句，
        // 补一个 `font_primary` 会把灰字变成白字（实测截图对照确认）
        const color: ResourceColor | null = this.color;
        if (color !== null) {
            instance.fontColor(color);
        }
    }
}

/**
 * 设置项行（C1）：图标 + 文本 + 右侧插槽。
 *
 * ## 形态只有一种
 *
 * 图标与「标题 + 描述」成列、同一行，三者垂直居中——形态来自颜色模式行，本批把它推给全仓所有行
 * （本批 D2 / K2）。设置卡、数据管理卡、关于页、颜色模式行四类行同形，没有第二个样子可选，
 * 也没有能把它变回旧形态的开关。
 *
 * **带描述的行因此比描述独占一行的旧形态长高**（`MorePage` 设置卡 224 → 239 设备像素，约 +4.6vp）——
 * 用户 2026-11-16 已确认「变高正是我想要的效果」，不是代价。
 *
 * `descAbove`（关于页的「小字标签在上、值在下」）只决定标题与描述的顺序，不参与形态选择。
 *
 * ## 右侧插槽
 *
 * 「文字」槽 → 箭头槽 → 「控件」槽（尾随块），按这个顺序并列渲染；组件不做互斥判定：
 * `@BuilderParam` 传没传在组件侧读不出来（不传时是空构建），互斥由调用点保证。
 * 箭头槽本批有三个真实调用点（`MorePage` 三张子页面入口卡），取值就此定下；文字槽仍零实例。
 */
@ComponentV2
export struct SettingRow {
    @Param title: ResourceStr = '';
    @Param icon: Resource | null = null;
    @Param desc: ResourceStr | null = null;
    // 描述在标题列的上面（关于页：小字标签在上、值在下）。只换顺序，不换形态
    @Param descAbove: boolean = false;
    // 为 null = 标题不设字色（盘面颜色模式行的原形：该行本来没有 `fontColor` 这一句）
    @Param titleColor: ResourceColor | null = $r('sys.color.font_primary');
    // 字重：设置卡与颜色模式行是 Medium，关于页的值文字是 Normal（盘上无 fontWeight 一句）
    @Param titleWeight: FontWeight = FontWeight.Medium;
    // 标题与描述两行之间：盘上两行同为 0；关于页 `Column({ space: PADDING_TWO })` 传 2
    @Param lineSpace: number = 0;
    // 不传 = 一次都不调用 `maxLines` / `textOverflow`（关于页的地址要自由折行）
    @Param titleMaxLines: number | undefined = undefined;
    @Param trailingText: ResourceStr | null = null;
    // 子页面入口传 true：行右侧出现箭头。取值见 `trailingSlot()`
    @Param showArrow: boolean = false;
    // 整行是否带点击：`false` 时**不挂**回调——挂空回调会把整行变成点击目标，点击区域随之变大
    @Param interactive: boolean = true;
    @Event onTap: () => void | Promise<void> = () => {};

    @Builder
    emptyTrailing() {
    }

    @BuilderParam trailing: () => void = this.emptyTrailing;

    @Builder
    titleLine() {
        Text(this.title)
            .fontSize(StyleConstants.MORE_MENU_ITEM_FONT_SIZE)
            .fontWeight(this.titleWeight)
            .textAlign(TextAlign.Start)
            .width(StyleConstants.FULL_PERCENT)
            .attributeModifier(new TitleLineModifier(this.titleMaxLines, this.titleColor))
    }

    @Builder
    descLine() {
        if (this.desc !== null) {
            Text(this.desc)
                .fontColor($r("sys.color.font_tertiary"))
                .fontSize(StyleConstants.MORE_MENU_ITEM_DESC_FONT_SIZE)
                .fontWeight(FontWeight.Normal)
                .textAlign(TextAlign.Start)
                .width(StyleConstants.FULL_PERCENT)
        }
    }

    @Builder
    iconGlyph() {
        if (this.icon !== null) {
            SymbolGlyph(this.icon)
                .fontSize(StyleConstants.MORE_MENU_ITEM_ICON_SIZE)
                .fontColor([$r("sys.color.font_primary")])
                // 固定盒宽：标题起点不再随字形宽度漂（需求 U12 / 设计 §2.6 ③）
                .width(StyleConstants.MORE_MENU_ITEM_ICON_BOX_SIZE)
        }
    }

    @Builder
    trailingSlot() {
        // 「文字」插槽（盘面零实例，取值待定，D12）：次级文字档
        if (this.trailingText !== null) {
            Text(this.trailingText)
                .fontSize(StyleConstants.COLOR_MODE_ROW_SELECT_FONT_SIZE)
                .fontColor($r("sys.color.font_secondary"))
                .maxLines(1)
        }

        // 「箭头」插槽：子页面入口的形态。三句取值由本批的三个调用点定下（本批 D5）
        if (this.showArrow) {
            SymbolGlyph($r("sys.symbol.chevron_right"))
                .fontSize(StyleConstants.COLOR_MODE_ROW_SELECT_FONT_SIZE)
                .fontColor([$r("sys.color.font_secondary")])
        }

        // 「控件」插槽：不传时是空构建，占位为零
        this.trailing()
    }

    /** 全仓唯一行形态：图标与「标题 + 描述」成列、同一行（形态来自颜色模式行） */
    @Builder
    columnContent() {
        Row() {
            this.iconGlyph()

            Column({ space: this.lineSpace }) {
                if (this.descAbove) {
                    // 关于页的「小字标签在上、值在下」：字号档与其它行相同而顺序相反（D2）
                    this.descLine()
                    this.titleLine()
                } else {
                    this.titleLine()
                    this.descLine()
                }
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
            // 文字列左缘 = 盒宽 + 12，与改造前列表的标题、描述同一算式
            .margin({ left: this.icon !== null ? StyleConstants.PADDING_TWELVE : 0 })

            this.trailingSlot()
        }
        .width(StyleConstants.FULL_PERCENT)
        // 不设交叉轴对齐：`Row` 默认垂直居中，正是盘面颜色模式行的形态。
        // 本批把这一形态推给全仓所有行（D2）：图标与文字同一行、垂直居中，不再有基线对齐的那种行
    }

    build() {
        // 分支写在最外层：`interactive` 为假时**一个回调都不挂**，整行不是点击目标（颜色模式行今天就是这样）
        // 两分支只差 `.onClick`：上下内边距、宽度若改，两处同改——否则同一行就有了两种形态
        if (this.interactive) {
            Column() {
                this.columnContent()
            }
            .width(StyleConstants.FULL_PERCENT)
            .alignItems(HorizontalAlign.Start)
            // 上下内边距由每行承担，卡片不自带（设计 §2.5 ②）；左右由卡片内边距给
            .padding({
                top: StyleConstants.ROW_VERTICAL_PADDING,
                bottom: StyleConstants.ROW_VERTICAL_PADDING
            })
            .onClick(() => {
                this.onTap();
            })
        } else {
            Column() {
                this.columnContent()
            }
            .width(StyleConstants.FULL_PERCENT)
            .alignItems(HorizontalAlign.Start)
            .padding({
                top: StyleConstants.ROW_VERTICAL_PADDING,
                bottom: StyleConstants.ROW_VERTICAL_PADDING
            })
        }
    }
}
