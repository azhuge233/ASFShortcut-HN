import Logger from '../common/utils/Logger';
import CommandEntryListViewModel from '../viewmodel/CommandEntryListViewModel';
import { CommandEntryViewModel } from '../viewmodel/CommandEntryViewModel';
import StyleConstants from '../common/constants/StyleConstants';
import CommonUtils from '../common/utils/CommonUtils';

@Builder
export function AddCommandBuilder() {
    AddCommand();
}

@Entry
@ComponentV2
struct AddCommand {
    private LOG_TAG = '[pages/AddCommand]';

    @Local newCommandViewModel: CommandEntryViewModel = new CommandEntryViewModel();

    private uiContext = this.getUIContext();
    private promptAction = this.uiContext.getPromptAction();

    private listViewModel: CommandEntryListViewModel = new CommandEntryListViewModel();

    pathStack: NavPathStack | undefined = undefined;

    clearInput() {
        this.newCommandViewModel.nickname = '';
        this.newCommandViewModel.command = '';
        this.newCommandViewModel.accountInputRequired = 0;
        this.newCommandViewModel.idInputRequired = 0;
    }

    async saveCommand() {
        if (!this.newCommandViewModel.nickname.trim() || !this.newCommandViewModel.command.trim()) {
            CommonUtils.alert($r("app.string.AddCommand_Invalid_Input"), this.promptAction);
            return;
        }

        try {
            const success = await this.listViewModel.addCommandEntry(this.newCommandViewModel.toCommandEntry());
            if (success) {
                CommonUtils.alert($r("app.string.AddCommand_Add_Success"), this.promptAction);
                this.clearInput();
            } else CommonUtils.alert($r("app.string.AddCommand_Add_Failed_Try_Again"), this.promptAction);
        } catch (err) {
            Logger.error(this.LOG_TAG, `保存命令失败: ${err}`);
            CommonUtils.alert($r("app.string.AddCommand_Add_Failed"), this.promptAction);
        }
    }

    build() {
        NavDestination() {
            Column({ space: StyleConstants.ADD_COMMAND_COL_SPACE }) {
                Blank()
                    .margin({ top: StyleConstants.MARGIN_TEN, bottom: StyleConstants.MARGIN_TEN })

                // 名称输入
                Text($r("app.string.AddCommand_Name_Label"))
                    .fontSize(StyleConstants.ADD_COMMAND_LABEL_FONT_SIZE)
                    .alignSelf(ItemAlign.Start)
                    .margin({ left: StyleConstants.MARGIN_TWENTY })
                TextInput({ placeholder: $r("app.string.AddCommand_Name_Input_Placeholder"), text: this.newCommandViewModel.nickname })
                    .onChange((value: string) => {
                        this.newCommandViewModel.nickname = value;
                    })
                    .defaultFocus(true)
                    .margin({ left: StyleConstants.MARGIN_TWENTY, right: StyleConstants.MARGIN_TWENTY })
                    .padding(StyleConstants.PADDING_TEN)
                    .border({ width: StyleConstants.INPUT_BORDER_WIDTH, color: Color.Gray })
                    .borderRadius(StyleConstants.INPUT_BORDER_RADIUS)

                // 命令输入
                Text($r("app.string.AddCommand_Command_Label"))
                    .fontSize(StyleConstants.ADD_COMMAND_LABEL_FONT_SIZE)
                    .alignSelf(ItemAlign.Start)
                    .margin({ left: StyleConstants.MARGIN_TWENTY, top: StyleConstants.MARGIN_TWENTY })
                TextInput({ placeholder: $r("app.string.AddCommand_Command_Input_Placeholder"), text: this.newCommandViewModel.command })
                    .onChange((value: string) => {
                        this.newCommandViewModel.command = value;
                    })
                    .defaultFocus(false)
                    .margin({ left: StyleConstants.MARGIN_TWENTY, right: StyleConstants.MARGIN_TWENTY })
                    .padding(StyleConstants.PADDING_TEN)
                    .border({ width: StyleConstants.INPUT_BORDER_WIDTH, color: Color.Gray })
                    .borderRadius(StyleConstants.INPUT_BORDER_RADIUS)

                // 选项区域 - 使用 Toggle 组件
                Column({ space: StyleConstants.ADD_COMMAND_OPTION_COL_SPACE }) {
                    Text($r("app.string.AddCommand_Options_Label"))
                        .fontSize(StyleConstants.ADD_COMMAND_LABEL_FONT_SIZE)
                        .alignSelf(ItemAlign.Start)
                        .margin({ bottom: StyleConstants.MARGIN_TEN })

                    // 需要输入账户的选项
                    Row({ space: StyleConstants.ADD_COMMAND_ROW_SPACE }) {
                        Toggle({ type: ToggleType.Checkbox, isOn: this.newCommandViewModel.accountRequired })
                            .onChange((value: boolean) => {
                                this.newCommandViewModel.accountRequired = value;
                            })
                        Text($r("app.string.AddCommand_Needs_ASF_Account_Input_Label"))
                            .fontSize(StyleConstants.ADD_COMMAND_CHECK_LABEL_FONT_SIZE)
                    }
                    .justifyContent(FlexAlign.Start)
                    .width(StyleConstants.FULL_PERCENT)

                    // 需要输入 App ID 的选项
                    Row({ space: StyleConstants.ADD_COMMAND_ROW_SPACE }) {
                        Toggle({ type: ToggleType.Checkbox, isOn: this.newCommandViewModel.idRequired })
                            .onChange((value: boolean) => {
                                this.newCommandViewModel.idRequired = value;
                            })
                        Text($r("app.string.AddCommand_Needs_ASF_ID_Input_Label"))
                            .fontSize(StyleConstants.ADD_COMMAND_CHECK_LABEL_FONT_SIZE)
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

                // 按钮区域
                Button($r("app.string.AddCommand_Add_Button_Label"))
                    .width(StyleConstants.SEVENTY_PERCENT)
                    .enabled(this.newCommandViewModel.nickname.trim() !== "" && this.newCommandViewModel.command.trim() !== "")
                    .margin({ top: StyleConstants.MARGIN_FORTY })
                    .onClick(() => {
                        this.saveCommand();
                    })

                // 占位空间
                Blank()
            }
            .padding(StyleConstants.PADDING_TWENTY)
        }
        .title($r("app.string.AddCommand_Title"))
        .height(StyleConstants.FULL_PERCENT)
        .width(StyleConstants.FULL_PERCENT)
        .onReady((context: NavDestinationContext) => {
            this.pathStack = context.pathStack;
            this.listViewModel = context.pathInfo.param as CommandEntryListViewModel;
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