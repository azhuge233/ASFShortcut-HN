import StyleConstants from "../../common/constants/StyleConstants";

@ComponentV2
export struct MoreMenuItem {
    @Param menuTitleText: Resource | string = "";
    @Param menuDescText: Resource | string | null = null;
    @Param menuIcon: Resource | string = "";

    @Param doJob: () => void | Promise<void> = () => {};

    build() {
        Row() {
            Image(this.menuIcon)
                .width(StyleConstants.MORE_MENU_ITEM_ICON_SIZE)
                .height(StyleConstants.MORE_MENU_ITEM_ICON_SIZE)
                .margin(StyleConstants.MARGIN_TEN)

            Column() {
                Text(this.menuTitleText)
                    .fontSize(StyleConstants.MORE_MENU_ITEM_FONT_SIZE)
                    .fontWeight(FontWeight.Medium)
                    .align(Alignment.Center)
                    .textAlign(TextAlign.Start)
                    // .height(StyleConstants.FIVE_PERCENT)
                    .width(StyleConstants.EIGHTY_PERCENT)

                if (this.menuDescText) {
                    Text(this.menuDescText)
                        .fontColor($r("sys.color.font_tertiary"))
                        .fontSize(StyleConstants.MORE_MENU_ITEM_DESC_FONT_SIZE)
                        .fontWeight(FontWeight.Normal)
                        .align(Alignment.Center)
                        .textAlign(TextAlign.Start)
                        // .height(StyleConstants.FIVE_PERCENT)
                        .width(StyleConstants.EIGHTY_PERCENT)
                }
            }
        }
        .padding({
            top: StyleConstants.PADDING_FIVE,
            left: StyleConstants.PADDING_FIVE,
            right: StyleConstants.PADDING_FIVE,
            bottom: StyleConstants.PADDING_FIVE
        })
        .onClick(() => {
            this.doJob();
        })
    }
}