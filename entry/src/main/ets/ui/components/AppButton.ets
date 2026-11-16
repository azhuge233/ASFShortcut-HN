import StyleConstants from "../../common/constants/StyleConstants";

/**
 * 按钮两态（C3 / D6）：**不造 Danger 态**——危险语义在本项目落在设置项行上
 * （`SettingRow` 的 `titleColor`），按钮上没有实例。
 */
export enum AppButtonKind {
    Primary,
    Secondary
}

/**
 * 「有条件才挂」的两句走 `AttributeModifier`（与 `AppInput` 的圆角同一手法，D10）：
 * 次态不设 `fontColor`、`stretch: false` 时不设 `width`，都是一次都不调用，而不是写一个等价默认值。
 */
class AppButtonFrameModifier implements AttributeModifier<ButtonAttribute> {
    private kind: AppButtonKind;
    private stretch: boolean;

    constructor(kind: AppButtonKind, stretch: boolean) {
        this.kind = kind;
        this.stretch = stretch;
    }

    applyNormalAttribute(instance: ButtonAttribute): void {
        if (this.kind === AppButtonKind.Primary) {
            instance.fontColor(Color.White);
        }
        if (this.stretch) {
            instance.width(StyleConstants.FULL_PERCENT);
        }
    }
}

/**
 * 页面级按钮（C3）：两态，取值全部来自盘面现值。
 *
 * - 主态 = `ASFSettingsPage` 的保存按钮：`{ type: Capsule }` + 满宽 + 白字；
 * - 次态 = `AddCommandForm` / `EditPage` 的按钮：`Button(label)` 原样，不设 type、不设字色、不设宽度。
 *
 * `type` 只在构造参数里有，属性链设不了它，所以按态给 options：次态收一个空对象，
 * 平台默认形态才是盘上原形（本机 API 23 起 `Button(label)` 的默认是 `ROUNDED_RECTANGLE`，
 * 写死 `Capsule` 会把次态按钮改圆角）。
 */
@ComponentV2
export struct AppButton {
    @Param label: ResourceStr = '';
    @Param kind: AppButtonKind = AppButtonKind.Primary;
    // 不叫 `enabled`：那是通用属性名，自定义组件上同名会与基类的 `enabled(value: boolean)` 冲突（编译期报错）
    @Param isEnabled: boolean = true;
    @Param stretch: boolean = true;      // 占满宽度（表单主按钮 / 对话框底栏）；否则按内容
    @Event onTap: () => void = () => {};

    private buttonOptions(): ButtonOptions {
        return this.kind === AppButtonKind.Primary ? { type: ButtonType.Capsule } : {};
    }

    build() {
        Button(this.label, this.buttonOptions())
            .attributeModifier(new AppButtonFrameModifier(this.kind, this.stretch))
            .enabled(this.isEnabled)
            .onClick(() => {
                this.onTap();
            })
    }
}
