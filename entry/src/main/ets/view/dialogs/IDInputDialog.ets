import { hdsMaterial, HdsNavDestination, ScrollEffectType } from "@kit.UIDesignKit";

import StyleConstants from "../../common/constants/StyleConstants";

@Builder
export function IDInputDialogBuilder() {
    IDInputDialog();
}

@ComponentV2
export struct IDInputDialog {
    pathStack: NavPathStack = new NavPathStack();

    @Local inputValue: string = "";

    build() {
        HdsNavDestination() {
            Column() {
                Text($r("app.string.ID_Input_Dialog_Label"))
                    .fontWeight(FontWeight.Bold)
                    .alignSelf(ItemAlign.Start)
                    .fontSize(StyleConstants.DIALOG_TITLE_FONT_SIZE)
                    .textSelectable(TextSelectableMode.UNSELECTABLE)
                    .copyOption(CopyOptions.None)
                    .margin({
                        top: StyleConstants.TWENTY_PERCENT,
                        bottom: StyleConstants.TEN_PERCENT
                    })

                TextInput()
                    .width(StyleConstants.FULL_PERCENT)
                    .maxLines(1)
                    .margin({ top: StyleConstants.MARGIN_TEN, bottom: StyleConstants.MARGIN_TEN })
                    .onChange((value: string) => {
                        this.inputValue = value;
                    })

                Button($r("app.string.Dialog_Button_Label"))
                    .alignSelf(ItemAlign.Stretch)
                    .enabled(this.inputValue.trim() !== "")
                    .margin({
                        top: StyleConstants.MARGIN_TWENTY
                    })
                    .onClick(() => {
                        this.pathStack.pop(this.inputValue);
                    })
            }
            .padding(StyleConstants.PADDING_TWENTY)
            .width(StyleConstants.FULL_PERCENT)
        }
        .titleBar({
            style: {
                scrollEffectOpts: {
                    // 设置滚动特效
                    enableScrollEffect: true,
                    scrollEffectType: ScrollEffectType.GRADIENT_BLUR,
                },
                systemMaterialEffect: {
                    // 设置沉浸光感
                    materialType: hdsMaterial.MaterialType.ADAPTIVE,
                    materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
                },
            },
            enableComponentSafeArea: true // 启用标题栏占位
        })
        .mode(NavDestinationMode.DIALOG)
        .backgroundColor($r("app.color.dialog_background_color"))
        .onBackPressed(() => {
            this.pathStack.pop("");
            return true;
        })
        .onReady((context) => {
            this.pathStack = context.pathStack;
        });
    }
}