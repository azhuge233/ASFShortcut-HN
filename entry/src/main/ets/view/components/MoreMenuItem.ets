import StyleConstants from "../../common/constants/StyleConstants";

@ComponentV2
export struct MoreMenuItem {
    @Param menuText: Resource | string = "";
    @Param menuIcon: Resource | string = "";

    @Param doJob: () => void | Promise<void> = () => {};

    build() {
        Row() {
            Image(this.menuIcon)
                .width(StyleConstants.MORE_MENU_ITEM_ICON_SIZE)
                .height(StyleConstants.MORE_MENU_ITEM_ICON_SIZE)
                .margin(StyleConstants.MARGIN_TEN)

            Text(this.menuText)
                .fontSize(StyleConstants.MORE_MENU_ITEM_FONT_SIZE)
                .fontWeight(FontWeight.Medium)
                .align(Alignment.Center)
                .textAlign(TextAlign.Start)
                .height(StyleConstants.FIVE_PERCENT)
                .width(StyleConstants.EIGHTY_PERCENT)
        }
        .margin({
            top: StyleConstants.TWO_PERCENT,
            left: StyleConstants.ONE_PERCENT,
            right: StyleConstants.THREE_PERCENT,
            bottom: StyleConstants.TWO_PERCENT
        })
        .onClick(() => {
            this.doJob();
        })
    }
}