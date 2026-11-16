import Logger from '../../common/utils/Logger';
import StyleConstants from '../../common/constants/StyleConstants';
import PageContext from '../common/PageContext';
import CommandListViewModel from '../../viewmodel/CommandListViewModel';
import { CommandEditViewModel, EditSaveOutcome } from '../../viewmodel/CommandEditViewModel';
import { CommandEntryViewModel } from '../../viewmodel/CommandEntryViewModel';
import { AppButton, AppButtonKind } from '../components/AppButton';
import { AppInput } from '../components/AppInput';
import { AppPage, PagePadding } from '../components/AppPage';

@Builder
export function EditPageBuilder() {
    EditPage();
}

/** 表单页形态：顶距 24，其余三边 20（S2 第 5 条；左右下与搬出前同值） */
const EDIT_PAGE_PADDING: PagePadding = {
    top: StyleConstants.FORM_PAGE_TOP_PADDING,
    right: StyleConstants.PADDING_TWENTY,
    bottom: StyleConstants.PADDING_TWENTY,
    left: StyleConstants.PADDING_TWENTY
};

/**
 * 编辑指令页（B3 重写）：只绑定 `CommandEditViewModel`。
 * 来源条目由路由参数给，`startEdit` 把草稿填进 VM；页面自留导航栈与提示（设计 §2.4.4 的 `EditPage` 行）。
 *
 * 骨架向添加页看齐（S2）：删掉首尾两个 `Blank()`、不再居中、补齐占满视口与起始对齐的三句——
 * 这三件都由 `AppScrollShell` 承担，本页不再自己拼列；上内边距读 `FORM_PAGE_TOP_PADDING`。
 */
@Entry
@ComponentV2
struct EditPage {
    private LOG_TAG = "[pages/EditPage]";

    @Local viewModel: CommandEditViewModel = new CommandEditViewModel(new CommandListViewModel());

    private uiContext = this.getUIContext();
    private promptAction = this.uiContext.getPromptAction();

    pathStack: NavPathStack | undefined = undefined;

    private async saveCommand(): Promise<void> {
        const outcome: EditSaveOutcome = await this.viewModel.save();

        // 成功路径（提示 + 关页）在 `onSaved` 里做，与 1.7.1 的「先提示、后返回」同一顺序
        if (outcome.ok) return;

        if (outcome.failure === 'invalid') {
            PageContext.alert($r("app.string.EditPage_Invalid_Input"), this.promptAction);
        } else if (outcome.failure === 'rejected') {
            PageContext.alert($r("app.string.EditPage_Update_Failed_Try_Again"), this.promptAction);
        } else {
            Logger.error(this.LOG_TAG, `更新命令失败: ${outcome.failure}`);
            PageContext.alert($r("app.string.EditPage_Update_Failed"), this.promptAction);
        }
    }

    /** 页面内容：两个标签 + 两个输入框 + 选项区 + 保存按钮，外边距逐句照搬盘面 */
    @LocalBuilder
    pageContent() {
        // 名称输入
        Text($r("app.string.EditPage_Name_Label"))
            .fontSize(StyleConstants.EDIT_PAGE_LABEL_FONT_SIZE)
            .alignSelf(ItemAlign.Start)
            .margin({ left: StyleConstants.MARGIN_TWENTY })

        AppInput({
            placeholder: $r("app.string.EditPage_Name_Input_Placeholder"),
            text: this.viewModel.nickname,
            onChange: (value: string) => {
                this.viewModel.nickname = value;
            }
        })
            .margin({ left: StyleConstants.MARGIN_TWENTY, right: StyleConstants.MARGIN_TWENTY })

        // 命令输入
        Text($r("app.string.EditPage_Command_Label"))
            .fontSize(StyleConstants.EDIT_PAGE_LABEL_FONT_SIZE)
            .alignSelf(ItemAlign.Start)
            .margin({ left: StyleConstants.MARGIN_TWENTY, top: StyleConstants.MARGIN_TWENTY })

        AppInput({
            placeholder: $r("app.string.EditPage_Command_Input_Placeholder"),
            text: this.viewModel.command,
            onChange: (value: string) => {
                this.viewModel.command = value;
            }
        })
            .margin({ left: StyleConstants.MARGIN_TWENTY, right: StyleConstants.MARGIN_TWENTY })

        // 选项区域 - 使用 Toggle 组件
        Column({ space: StyleConstants.EDIT_PAGE_OPTION_COL_SPACE }) {
            Text($r("app.string.EditPage_Options_Label"))
                .fontSize(StyleConstants.EDIT_PAGE_LABEL_FONT_SIZE)
                .alignSelf(ItemAlign.Start)
                .margin({ bottom: StyleConstants.MARGIN_TEN })

            // 需要输入ASF账户的选项
            Row({ space: StyleConstants.EDIT_PAGE_ROW_SPACE }) {
                Toggle({ type: ToggleType.Checkbox, isOn: this.viewModel.accountRequired })
                    .onChange(
                        (value: boolean) => {
                            this.viewModel.accountRequired = value;
                        }
                    )
                Text($r("app.string.EditPage_Needs_ASF_Account_Input_Label"))
                    .fontSize(StyleConstants.EDIT_PAGE_CHECK_LABEL_FONT_SIZE)
            }
            .justifyContent(FlexAlign.Start)
            .width(StyleConstants.FULL_PERCENT)

            // 需要输入 ASF App ID 的选项
            Row({ space: StyleConstants.EDIT_PAGE_ROW_SPACE }) {
                Toggle({ type: ToggleType.Checkbox, isOn: this.viewModel.idRequired })
                    .onChange(
                        (value: boolean) => {
                            this.viewModel.idRequired = value;
                        }
                    )
                Text($r("app.string.EditPage_Needs_ASF_ID_Input_Label"))
                    .fontSize(StyleConstants.EDIT_PAGE_CHECK_LABEL_FONT_SIZE)
            }
            .justifyContent(FlexAlign.Start)
            .width(StyleConstants.FULL_PERCENT)
        }
        .alignSelf(ItemAlign.Start)
        .margin(
            {
                left: StyleConstants.MARGIN_TWENTY,
                top: StyleConstants.MARGIN_TWENTY,
                right: StyleConstants.MARGIN_TWENTY
            }
        )
        .padding(StyleConstants.PADDING_FIFTEEN)
        .border({ width: StyleConstants.INPUT_BORDER_WIDTH, color: Color.Gray })
        .borderRadius(StyleConstants.INPUT_BORDER_RADIUS)

        // 按钮：次态（`Button(label)` 原样），宽度与上边距仍由本页给
        AppButton({
            label: $r("app.string.EditPage_Save_Button_Label"),
            kind: AppButtonKind.Secondary,
            isEnabled: !this.viewModel.isSaving,
            onTap: () => {
                this.saveCommand();
            }
        })
            .width(StyleConstants.SEVENTY_PERCENT)
            // 按钮自己居中：S2 的骨架向添加页看齐，`AppScrollShell` 的列是起始对齐，
            // 不补这一句 70% 宽度的按钮就贴到左缘（实测左缘 236→66 设备像素，横移 52vp）——
            // 而 S2 那一条自己写明「其余不动」，横向这次移动不在它放行的范围内，所以按钮保持原居中
            .alignSelf(ItemAlign.Center)
            .margin({ top: StyleConstants.MARGIN_FORTY })
    }

    build() {
        // `@Entry` 的 build 根节点必须是容器组件，自定义组件不能当根，所以包一层占满视口的 `Column`
        Column() {
            AppPage({
                title: $r("app.string.EditPage_Title"),
                logTag: this.LOG_TAG,
                contentPadding: EDIT_PAGE_PADDING,
                columnSpace: StyleConstants.EDIT_PAGE_BLANK_COL_SPACE,
                content: this.pageContent,
                onReady: (context: NavDestinationContext) => {
                    this.pathStack = context.pathStack;

                    // 参数 = [列表 VM, 来源条目]：更新经列表 VM 走，卡片刷新与列表重载都在那条路上
                    const params: Array<object> = context.pathInfo.param as Array<object>;
                    if (params.length > 1 && params[0] instanceof CommandListViewModel &&
                        params[1] instanceof CommandEntryViewModel) {
                        this.viewModel = new CommandEditViewModel(params[0]);
                        this.viewModel.startEdit(params[1]);
                        this.viewModel.onSaved = () => {
                            PageContext.alert($r("app.string.EditPage_Update_Success"), this.promptAction);
                            this.pathStack?.pop("Button pressed");
                        };
                    } else {
                        Logger.warn(this.LOG_TAG, `路由参数不完整，保留空草稿`);
                    }
                }
            })
        }
        .width(StyleConstants.FULL_PERCENT)
        .height(StyleConstants.FULL_PERCENT)
    }
}
