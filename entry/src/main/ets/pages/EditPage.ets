import StyleConstants from '../common/constants/StyleConstants';
import CommonUtils from '../common/utils/CommonUtils';
import Logger from '../common/utils/Logger';
import CommandEntryListViewModel from '../viewmodel/CommandEntryListViewModel';
import { CommandEntryViewModel } from '../viewmodel/CommandEntryViewModel';

@Builder
export function EditPageBuilder() {
    EditPage();
}

@Entry
@ComponentV2
struct EditPage {
    private LOG_TAG = "[pages/EditPage]";

    @Local updatingCommandEntry: CommandEntryViewModel = new CommandEntryViewModel();

    private uiContext = this.getUIContext();
    private promptAction = this.uiContext.getPromptAction();

    private listViewModel: CommandEntryListViewModel = new CommandEntryListViewModel();

    pathStack: NavPathStack | undefined = undefined;

    async saveCommand() {
        if (!this.updatingCommandEntry.nickname.trim() || !this.updatingCommandEntry.command.trim()) {
            CommonUtils.alert($r("app.string.EditPage_Invalid_Input"), this.promptAction);
            return;
        }

        try {
            const success = await this.listViewModel.updateCommandEntry(this.updatingCommandEntry.toCommandEntry());
            if (success) {
                CommonUtils.alert($r("app.string.EditPage_Update_Success"), this.promptAction);
                this.pathStack?.pop("Button pressed");
            } else CommonUtils.alert($r("app.string.EditPage_Update_Failed_Try_Again"), this.promptAction);
        } catch (err) {
            Logger.error(this.LOG_TAG, `更新命令失败: ${err}`);
            CommonUtils.alert($r("app.string.EditPage_Update_Failed"), this.promptAction);
        }
    }

    build() {
        NavDestination() {
            Column({ space: StyleConstants.EDIT_PAGE_BLANK_COL_SPACE }) {
                Blank()
                    .margin({ top: StyleConstants.MARGIN_TEN, bottom: StyleConstants.MARGIN_TEN })

                // 名称输入
                Text($r("app.string.EditPage_Name_Label"))
                    .fontSize(StyleConstants.EDIT_PAGE_LABEL_FONT_SIZE)
                    .alignSelf(ItemAlign.Start)
                    .margin({ left: StyleConstants.MARGIN_TWENTY })
                TextInput({ placeholder: $r("app.string.EditPage_Name_Input_Placeholder"), text: this.updatingCommandEntry.nickname })
                    .onChange((value: string) => {
                        this.updatingCommandEntry.nickname = value;
                    })
                    .margin({ left: StyleConstants.MARGIN_TWENTY, right: StyleConstants.MARGIN_TWENTY })
                    .padding(StyleConstants.PADDING_TEN)
                    .border({ width: StyleConstants.INPUT_BORDER_WIDTH, color: Color.Gray })
                    .borderRadius(StyleConstants.INPUT_BORDER_RADIUS)

                // 命令输入
                Text($r("app.string.EditPage_Command_Label"))
                    .fontSize(StyleConstants.EDIT_PAGE_LABEL_FONT_SIZE)
                    .alignSelf(ItemAlign.Start)
                    .margin({ left: StyleConstants.MARGIN_TWENTY, top: StyleConstants.MARGIN_TWENTY })
                TextInput({ placeholder: $r("app.string.EditPage_Command_Input_Placeholder"), text: this.updatingCommandEntry.command })
                    .onChange((value: string) => {
                        this.updatingCommandEntry.command = value;
                    })
                    .margin({ left: StyleConstants.MARGIN_TWENTY, right: StyleConstants.MARGIN_TWENTY })
                    .padding(StyleConstants.PADDING_TEN)
                    .border({ width: StyleConstants.INPUT_BORDER_WIDTH, color: Color.Gray })
                    .borderRadius(StyleConstants.INPUT_BORDER_RADIUS)

                // 选项区域 - 使用 Toggle 组件
                Column({ space: StyleConstants.EDIT_PAGE_OPTION_COL_SPACE }) {
                    Text($r("app.string.EditPage_Options_Label"))
                        .fontSize(StyleConstants.EDIT_PAGE_LABEL_FONT_SIZE)
                        .alignSelf(ItemAlign.Start)
                        .margin({ bottom: StyleConstants.MARGIN_TEN })

                    // 需要输入ASF账户的选项
                    Row({ space: StyleConstants.EDIT_PAGE_ROW_SPACE }) {
                        Toggle({ type: ToggleType.Checkbox, isOn: this.updatingCommandEntry.accountRequired })
                            .onChange((value: boolean) => {
                                this.updatingCommandEntry.accountRequired = value;
                            })
                        Text($r("app.string.EditPage_Needs_ASF_Account_Input_Label"))
                            .fontSize(StyleConstants.EDIT_PAGE_CHECK_LABEL_FONT_SIZE)
                    }
                    .justifyContent(FlexAlign.Start)
                    .width(StyleConstants.FULL_PERCENT)

                    // 需要输入 ASF App ID 的选项
                    Row({ space: StyleConstants.EDIT_PAGE_ROW_SPACE }) {
                        Toggle({ type: ToggleType.Checkbox, isOn: this.updatingCommandEntry.idRequired })
                            .onChange((value: boolean) => {
                                this.updatingCommandEntry.idRequired = value;
                            })
                        Text($r("app.string.EditPage_Needs_ASF_ID_Input_Label"))
                            .fontSize(StyleConstants.EDIT_PAGE_CHECK_LABEL_FONT_SIZE)
                    }
                    .justifyContent(FlexAlign.Start)
                    .width(StyleConstants.FULL_PERCENT)
                }
                .alignSelf(ItemAlign.Start)
                .margin({ left: StyleConstants.MARGIN_TWENTY, top: StyleConstants.MARGIN_TWENTY, right: StyleConstants.MARGIN_TWENTY })
                .padding(StyleConstants.PADDING_FIFTEEN)
                .border({ width: StyleConstants.INPUT_BORDER_WIDTH, color: Color.Gray })
                .borderRadius(StyleConstants.INPUT_BORDER_RADIUS)
                .width(StyleConstants.NINETY_PERCENT)

                // 按钮
                Button($r("app.string.EditPage_Save_Button_Label"))
                    .width(StyleConstants.SEVENTY_PERCENT)
                    .margin({ top: StyleConstants.MARGIN_FORTY })
                    .onClick(() => {
                        this.saveCommand();
                    })

                // 占位空间
                Blank()
            }
            .padding(StyleConstants.PADDING_TWENTY)
        }
        .title($r("app.string.EditPage_Title"))
        .height(StyleConstants.FULL_PERCENT)
        .width(StyleConstants.FULL_PERCENT)
        .onReady((context: NavDestinationContext) => {
            this.pathStack = context.pathStack;
            const param = this.pathStack.getParamByIndex(0) as Array<object>;
            this.listViewModel = param[0] as CommandEntryListViewModel;
            this.updatingCommandEntry = param[1] as CommandEntryViewModel;
        })
        .onBackPressed(() => {
            this.pathStack?.pop("Back pressed");
            return true;
        })
        .onAppear(() => {
            Logger.debug(this.LOG_TAG, "Loaded!");
        })
    }
}