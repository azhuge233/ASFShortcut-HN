import StyleConstants from "../../common/constants/StyleConstants";

/**
 * 输入框的「有条件才挂」属性全走 `AttributeModifier`（D10）：两个判定，各自为假时**一次都不调用**。
 *
 * - `bordered` 为假时**描边与内边距都不调用**——两个输入框对话框的盘上原形只设宽度与 `maxLines`，
 *   给它们补一句描边就是给画面加东西；
 * - `password` 为假时不调用 `type`（默认就是 `Normal`）。
 *
 * 圆角不在这里：组件内没有任何圆角调用，十一个框面统一取平台默认（本批 D1），
 * 也就没有「传一个值就换一个样子」的路。
 */
class AppInputFrameModifier implements AttributeModifier<TextInputAttribute> {
    private bordered: boolean;
    private password: boolean;

    constructor(bordered: boolean, password: boolean) {
        this.bordered = bordered;
        this.password = password;
    }

    applyNormalAttribute(instance: TextInputAttribute): void {
        if (this.bordered) {
            instance.border({ width: StyleConstants.INPUT_BORDER_WIDTH, color: Color.Gray });
            instance.padding(StyleConstants.PADDING_TEN);
        }

        if (this.password) {
            instance.type(InputType.Password);
        }
    }
}

/**
 * 输入框（C2）：描边 + 内边距 + 密码眼睛，一处收十一个框面。
 *
 * **只有一种形态**：圆角走平台默认，也就是添加指令页今天的形态；没有任何参数能把它变回第二个样子
 * （本批 D1 / K1——需求写的是「组件只有一种形态，没有可传的参数」）。
 *
 * 外边距不进组件（D9）：十一个框面的外边距由各页版式决定（表单页与测试页左右各 20；两个对话框只给上下各 10，由对话框自己给），
 * 塞进来就要开一个「外边距模式」参数，而那是版式不是控件。调用点在 `AppInput` 上挂 `.margin(...)`。
 */
@ComponentV2
export struct AppInput {
    @Param text: string = '';
    @Param placeholder: ResourceStr = '';
    @Param password: boolean = false;
    @Param maxLines: number = 1;
    @Param bordered: boolean = true;                 // 假 = 描边与内边距都不调用（对话框的原形）
    @Event onChange: (value: string) => void = () => {};

    build() {
        TextInput({ text: this.text, placeholder: this.placeholder })
            .width(StyleConstants.FULL_PERCENT)
            .maxLines(this.maxLines)
            .attributeModifier(new AppInputFrameModifier(this.bordered, this.password))
            .onChange((value: string) => {
                this.onChange(value);
            })
    }
}
