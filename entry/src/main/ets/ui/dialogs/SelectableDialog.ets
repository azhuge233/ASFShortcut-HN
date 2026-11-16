import StyleConstants from "../../common/constants/StyleConstants";
import { AppDialog } from "../components/AppDialog";

@Builder
export function SelectableDialogBuilder() {
    SelectableDialog();
}

/**
 * 可选文字对话框（C7）：命令执行结果，可选中复制，内容超高自己滚。
 *
 * 壳体（标题 + 内容插槽 + 底栏 + `DIALOG` 形态的 `HdsNavDestination`）来自 `AppDialog`，本件只剩内容与四个参数：
 * 标题外面距只留 `bottom: FIVE_PERCENT`、底栏按钮上外面距 `FIVE_PERCENT`、确认 pop `"Button pressed"`、
 * 返回 pop `"Back pressed"`——四个值都是盘上原样（R2：不许写死成别的）。
 */
@ComponentV2
export struct SelectableDialog {
    @Local commandNickname: string = "";
    @Local message: string = "";

    @LocalBuilder
    dialogContent() {
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
    }

    build() {
        AppDialog({
            title: $r("app.string.Selectable_Dialog_Label", this.commandNickname),
            titleMargin: { bottom: StyleConstants.FIVE_PERCENT },
            submitTopMargin: StyleConstants.FIVE_PERCENT,
            submitResult: 'Button pressed',
            backResult: 'Back pressed',
            content: this.dialogContent,
            prepare: (context: NavDestinationContext) => {
                // 路由参数是 [昵称, 内容] 两个串，读法照旧
                const params = context.pathInfo.param as string[];
                this.commandNickname = params[0];
                this.message = params[1];
            }
        })
    }
}
