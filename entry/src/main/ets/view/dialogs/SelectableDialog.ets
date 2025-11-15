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
                Text("Result")
                    .fontWeight(FontWeight.Bold)
                    .alignSelf(ItemAlign.Start)
                    .fontSize(23)
                    .textSelectable(TextSelectableMode.UNSELECTABLE)
                    .copyOption(CopyOptions.None)
                    .margin({
                        bottom: '5%'
                    })

                Scroll() {
                    Text(this.message)
                        .textSelectable(TextSelectableMode.SELECTABLE_FOCUSABLE)
                        .copyOption(CopyOptions.LocalDevice)
                        .fontSize(18)
                }
                .constraintSize({
                    maxHeight: '80%'
                })
                .width('100%')
                .margin({ top: 10, bottom: 10 })
                .scrollable(ScrollDirection.Vertical)
                .scrollBar(BarState.Auto)
                .edgeEffect(EdgeEffect.Spring)

                Button('OK')
                    .alignSelf(ItemAlign.Stretch)
                    .margin({
                        top: '5%'
                    })
                    .onClick(() => {
                        this.pathStack.pop("Button pressed");
                    })
            }
            .padding(20)
            .width('100%')
        }
        .mode(NavDestinationMode.DIALOG)
        .backgroundColor("#000000")
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