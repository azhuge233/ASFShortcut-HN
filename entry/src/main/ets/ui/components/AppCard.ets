import StyleConstants from "../../common/constants/StyleConstants";

/**
 * 分组卡容器（C4）：页面底之上的一张卡，只负责卡面。
 *
 * 六个修饰符逐字取自改造前的五处分组卡：设置页两张、数据管理页两张、关于页一张。
 *
 * 上下内边距**不自带**，由每行承担（`ROW_VERTICAL_PADDING`，批 3 §2.6 ② 的判定）：
 * 卡片自带上下内边距会让首尾行比组内其余行多出一截。
 */
@ComponentV2
export struct AppCard {
    @BuilderParam content: () => void;

    build() {
        Column() {
            this.content()
        }
        .width(StyleConstants.FULL_PERCENT)
        .backgroundColor($r("sys.color.comp_background_primary"))
        .border({ width: StyleConstants.CARD_BORDER_WIDTH, color: $r("sys.color.comp_divider") })
        .borderRadius(StyleConstants.CARD_RADIUS)
        .padding({ left: StyleConstants.CARD_PADDING, right: StyleConstants.CARD_PADDING })
        .clip(true)
    }
}
