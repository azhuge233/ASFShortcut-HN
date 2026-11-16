import StyleConstants from "../../common/constants/StyleConstants";
import { AppDialog } from "../components/AppDialog";
import { AppInput } from "../components/AppInput";

/**
 * 输入框对话框的唯一一份实现（C7 / D8）：两个路由对话框逐行 `diff` 只差函数名、结构体名与一个字符串键。
 *
 * `AccountInputDialog` 与 `IDInputDialog` 保留为登记薄壳（路由表按 `pageSourceFile` + `buildFunction`
 * 两个名字登记，删文件就要改 `route_map.json`），实现全在这里。
 *
 * 行为逐条不变：`inputValue.trim() !== ''` 才可用、确认 `pop(inputValue)`、返回键 `pop("")`。
 * 输入框的 10vp 上下外边距由本件在内容插槽里给（`AppInput` 不带外边距，D9）；
 * `bordered: false` 表盘上原形——这两个对话框的输入框只设宽度与 `maxLines`，没有描边与内边距。
 */
@ComponentV2
export struct TextInputDialog {
    @Param title: ResourceStr = '';

    @Local inputValue: string = '';

    @LocalBuilder
    inputContent() {
        AppInput({
            text: this.inputValue,
            bordered: false,
            onChange: (value: string) => {
                this.inputValue = value;
            }
        })
            .margin({ top: StyleConstants.MARGIN_TEN, bottom: StyleConstants.MARGIN_TEN })
    }

    build() {
        AppDialog({
            title: this.title,
            // 可用态由本件按盘上同一算式给（`inputValue.trim() !== ''`）
            submitEnabled: this.inputValue.trim() !== '',
            submitResult: this.inputValue,
            backResult: '',
            content: this.inputContent
        })
    }
}
