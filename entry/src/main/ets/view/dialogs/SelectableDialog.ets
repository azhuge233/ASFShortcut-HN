import StyleConstants from "../../common/constants/StyleConstants";

@Builder
export function SelectableDialogBuilder() {
    SelectableDialog();
}

@ComponentV2
export struct SelectableDialog {
    pathStack: NavPathStack = new NavPathStack();

    @Local message: string = "";

    build() {
        NavDestination() {
            Column() {
                Text($r("app.string.Selectable_Dialog_Label"))
                    .fontWeight(FontWeight.Bold)
                    .alignSelf(ItemAlign.Start)
                    .fontSize(StyleConstants.DIALOG_TITLE_FONT_SIZE)
                    .textSelectable(TextSelectableMode.UNSELECTABLE)
                    .copyOption(CopyOptions.None)
                    .margin({
                        bottom: StyleConstants.FIVE_PERCENT
                    })

                Scroll() {
                    Text(this.message)
                        .textSelectable(TextSelectableMode.SELECTABLE_FOCUSABLE)
                        .copyOption(CopyOptions.LocalDevice)
                        .fontSize(StyleConstants.DIALOG_CONTENT_FONT_SIZE)
                }
                .constraintSize({
                    maxHeight: StyleConstants.EIGHTY_PERCENT
                })
                .width(StyleConstants.FULL_PERCENT)
                .margin({ top: StyleConstants.MARGIN_TEN, bottom: StyleConstants.MARGIN_TEN })
                .scrollable(ScrollDirection.Vertical)
                .scrollBar(BarState.Auto)
                .edgeEffect(EdgeEffect.Spring)

                Button($r("app.string.Dialog_Button_Label"))
                    .alignSelf(ItemAlign.Stretch)
                    .margin({
                        top: StyleConstants.FIVE_PERCENT
                    })
                    .onClick(() => {
                        this.pathStack.pop("Button pressed");
                    })
            }
            .padding(StyleConstants.PADDING_TWENTY)
            .width(StyleConstants.FULL_PERCENT)
        }
        .mode(NavDestinationMode.DIALOG)
        .backgroundColor($r("app.color.dialog_background_color"))
        .onBackPressed(() => {
            this.pathStack.pop("Back pressed");
            return true;
        })
        .onReady((context) => {
            this.pathStack = context.pathStack;
            this.message = context.pathInfo.param as string;
        });
    }
}