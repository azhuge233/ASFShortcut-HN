import { hdsMaterial, HdsNavDestination, ScrollEffectType } from "@kit.UIDesignKit";

import StyleConstants from "../../common/constants/StyleConstants";

/** 输入框对话框的标题外边距（盘上原值）；可选对话框传 `{ bottom: FIVE_PERCENT }` */
const DEFAULT_TITLE_MARGIN: Margin = {
    top: StyleConstants.TWENTY_PERCENT,
    bottom: StyleConstants.TEN_PERCENT
};

/**
 * 对话框壳（C7）：标题 + 内容插槽 + 底栏按钮 + 一条 `DIALOG` 形态的 `HdsNavDestination`。
 *
 * 三个路由对话框（`AccountInputDialog` / `IDInputDialog` / `SelectableDialog`）改造前是同一份壳体抄三遍，
 * 逐条差别只有四处：标题外边距、底栏按钮上外边距、确认 pop 的值、返回 pop 的值——全部由参数接住（R2）。
 *
 * **底栏按钮的主人是本件，且不经 `AppButton`**（D15 / M1）：三个对话框今天只设 `alignSelf(Stretch)`
 * 与上外边距，不设 `type`、不设字色；换成 `AppButton` 的 Primary 等于给它们补两句属性。
 *
 * `backResult` 与 `submitResult` 都不写死：四个 `pop` 串在盘上各不相同（`this.inputValue` / `""` /
 * `"Button pressed"` / `"Back pressed"`），写死任何一个都是行为变更。
 */
@ComponentV2
export struct AppDialog {
    @Param title: ResourceStr = '';
    @Param submitEnabled: boolean = true;
    @Param submitLabel: ResourceStr = $r('app.string.Dialog_Button_Label');
    @Param titleMargin: Margin = DEFAULT_TITLE_MARGIN;
    @Param submitTopMargin: Length = StyleConstants.MARGIN_TWENTY;
    @Param submitResult: Object = '';
    @Param backResult: Object = '';
    @Event prepare: (ctx: NavDestinationContext) => void = () => {};
    @BuilderParam content: () => void;

    private pathStack: NavPathStack = new NavPathStack();

    build() {
        HdsNavDestination() {
            Column() {
                Text(this.title)
                    .fontWeight(FontWeight.Bold)
                    .alignSelf(ItemAlign.Start)
                    .fontSize(StyleConstants.DIALOG_TITLE_FONT_SIZE)
                    .textSelectable(TextSelectableMode.UNSELECTABLE)
                    .copyOption(CopyOptions.None)
                    .margin(this.titleMargin)

                this.content()

                Button(this.submitLabel)
                    .alignSelf(ItemAlign.Stretch)
                    .enabled(this.submitEnabled)
                    .margin({ top: this.submitTopMargin })
                    .onClick(() => {
                        this.pathStack.pop(this.submitResult);
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
        .backgroundColor($r('app.color.dialog_background_color'))
        .onBackPressed(() => {
            this.pathStack.pop(this.backResult);
            return true;
        })
        .onReady((context: NavDestinationContext) => {
            this.pathStack = context.pathStack;
            // 需要读路由参数的调用方（本批只有 `SelectableDialog`）从这里拿 context
            this.prepare(context);
        })
    }
}
