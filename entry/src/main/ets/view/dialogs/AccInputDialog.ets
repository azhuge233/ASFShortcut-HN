@Builder
export function AccInputDialogBuilder() {
    AccInputDialog();
}

@ComponentV2
export struct AccInputDialog {
    pathStack: NavPathStack = new NavPathStack();

    @Local inputValue: string = "";

    build() {
        NavDestination() {
            Column() {
                Text(`输入 ASF 机器人名称`)
                    .fontWeight(FontWeight.Bold)
                    .alignSelf(ItemAlign.Start)
                    .fontSize(23)
                    .textSelectable(TextSelectableMode.UNSELECTABLE)
                    .copyOption(CopyOptions.None)
                    .margin({
                        top: '20%',
                        bottom: '10%'
                    })

                TextInput()
                    .width('100%')
                    .maxLines(1)
                    .margin({ top: 10, bottom: 10 })
                    .onChange((value: string) => {
                        this.inputValue = value;
                    })

                Button('OK')
                    .alignSelf(ItemAlign.Stretch)
                    .margin({
                        top: 20
                    })
                    .onClick(() => {
                        this.pathStack.pop(this.inputValue);
                    })
            }
            .padding(20)
            .width('100%')
        }
        .mode(NavDestinationMode.DIALOG)
        .backgroundColor("#000000")
        .onBackPressed(() => {
            this.pathStack.pop("");
            return true;
        })
        .onReady((context) => {
            this.pathStack = context.pathStack;
        });
    }
}