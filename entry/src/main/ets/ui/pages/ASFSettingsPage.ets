import StyleConstants from '../../common/constants/StyleConstants';
import PageContext from '../common/PageContext';
import AsfSettingsViewModel from '../../viewmodel/AsfSettingsViewModel';
import { AppButton, AppButtonKind } from '../components/AppButton';
import { AppInput } from '../components/AppInput';
import { AppPage, PagePadding } from '../components/AppPage';

@Builder
export function ASFSettingsPageBuilder() {
    ASFSettingsPage();
}

/**
 * 表单页形态：顶距 24（首元素是标签文字，贴标题栏读作拥挤）；左右与添加指令页对齐取 20（本批 D3 / 设计 §2.5），
 * 下仍是页面内边距 16——需求只写「左右 16 → 20」，下边不改。
 */
const SETTINGS_PAGE_PADDING: PagePadding = {
    top: StyleConstants.FORM_PAGE_TOP_PADDING,
    right: StyleConstants.PADDING_TWENTY,
    bottom: StyleConstants.PAGE_PADDING,
    left: StyleConstants.PADDING_TWENTY
};

/**
 * ASF 设置页（B3 重写）：只绑定 `AsfSettingsViewModel`（设计 §2.4.4 的 `ASFSettingsPage` 行）。
 *
 * 页面自留导航栈与提示；地址规范化、两个键的落盘与保存中标记都在 VM 里。
 * 外壳、两个输入框、保存按钮全部来自组件（C2 / C3 / C5），本页只剩装配与那句「保存中拦返回」。
 */
@Entry
@ComponentV2
struct ASFSettingsPage {
    private LOG_TAG = "[pages/ASFSettingsPage]";

    @Local viewModel: AsfSettingsViewModel = new AsfSettingsViewModel();

    pathStack: NavPathStack | undefined = undefined;

    private uiContext = this.getUIContext();
    private promptAction = this.uiContext.getPromptAction();

    aboutToAppear(): void {
        // 加载当前设置
        this.viewModel.load();
    }

    /** 页面内容：两个标签 + 两个输入框 + 保存按钮；左右与添加指令页同形（本批 D3，设计 §2.5） */
    @LocalBuilder
    pageContent() {
        Text($r("app.string.SettingsPage_Address_Label"))
            .fontSize(StyleConstants.SETTINGS_PAGE_LABEL_FONT_SIZE)
            .alignSelf(ItemAlign.Start)
            // 标签左缘 = 输入框左缘 = 20 + 20，与添加页 / 编辑页同一条规则（批档 §1.11 裁甲）
            .margin({
                left: StyleConstants.MARGIN_TWENTY,
                bottom: StyleConstants.MARGIN_TEN
            })

        AppInput({
            text: this.viewModel.address,
            placeholder: $r("app.string.SettingsPage_Address_Input_Placeholder"),
            onChange: (value: string) => {
                this.viewModel.address = value;
            }
        })
            // 左右 20 与添加指令页同形：净宽 = 屏宽 − 20（页面）× 2 − 20（外边距）× 2 = 屏宽 − 80（设计 §2.5）
            .margin({
                left: StyleConstants.MARGIN_TWENTY,
                right: StyleConstants.MARGIN_TWENTY,
                bottom: StyleConstants.MARGIN_THIRTY
            })

        Text($r("app.string.SettingsPage_Password_Label"))
            .fontSize(StyleConstants.SETTINGS_PAGE_LABEL_FONT_SIZE)
            .alignSelf(ItemAlign.Start)
            // 同上：标签与输入框同一左缘（批档 §1.11 裁甲）
            .margin({
                left: StyleConstants.MARGIN_TWENTY,
                bottom: StyleConstants.MARGIN_TEN
            })

        AppInput({
            text: this.viewModel.password,
            placeholder: $r("app.string.SettingsPage_Password_Input_Placeholder"),
            password: true,
            onChange: (value: string) => {
                this.viewModel.password = value;
            }
        })
            .margin({
                left: StyleConstants.MARGIN_TWENTY,
                right: StyleConstants.MARGIN_TWENTY,
                bottom: StyleConstants.MARGIN_FIFTY
            })

        AppButton({
            label: this.viewModel.isSaving ? $r("app.string.SettingsPage_Save_Button_Saving") :
                $r("app.string.SettingsPage_Save_Button_Label"),
            kind: AppButtonKind.Primary,
            isEnabled: !this.viewModel.isSaving && this.viewModel.canSave(),
            onTap: async () => {
                const saveSuccess = await this.viewModel.save();
                if (saveSuccess) {
                    PageContext.alert($r("app.string.SettingsPage_Save_Success"), this.promptAction);
                    this.pathStack?.pop("Submit pressed");
                } else PageContext.alert($r("app.string.SettingsPage_Save_Failed"), this.promptAction);
            }
        })
            .width(StyleConstants.SEVENTY_PERCENT)
            // 宽度分两层：这句定外包层，`stretch` 不传（默认真）让内层填满它（设计 §2.7 / K4）
            // 本页内容列是起始对齐（`AppScrollShell` 的 `alignItems(HorizontalAlign.Start)`），
            // 70% 宽度不补这一句就贴左缘；「宽高与添加指令页对齐」= 70% 宽、居中（设计 §3 第 9 行）
            .alignSelf(ItemAlign.Center)
    }

    build() {
        // `@Entry` 的 build 根节点必须是容器组件，自定义组件不能当根，所以包一层占满视口的 `Column`
        Column() {
            AppPage({
                title: $r("app.string.SettingsPage_Title"),
                logTag: this.LOG_TAG,
                contentPadding: SETTINGS_PAGE_PADDING,
                content: this.pageContent,
                onReady: (context: NavDestinationContext) => {
                    this.pathStack = context.pathStack;
                },
                // 保存中拦返回：返回真 = 本页已消费，不给 `AppPage` 去 pop
                onBack: () => {
                    if (this.viewModel.isSaving) {
                        PageContext.alert($r("app.string.SettingsPage_Save_Button_Saving"), this.promptAction);
                        return true;
                    }
                    return false;
                }
            })
        }
        .width(StyleConstants.FULL_PERCENT)
        .height(StyleConstants.FULL_PERCENT)
    }
}
