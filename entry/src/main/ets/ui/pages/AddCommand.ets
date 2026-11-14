import { HdsNavDestination, hdsMaterial } from '@kit.UIDesignKit';

import Logger from '../../common/utils/Logger';
import StyleConstants from '../../common/constants/StyleConstants';
import PageContext from '../common/PageContext';
import CommandListViewModel from '../../viewmodel/CommandListViewModel';
import { CommandEditViewModel, EditSaveOutcome } from '../../viewmodel/CommandEditViewModel';

@Builder
export function AddCommandBuilder() {
    AddCommand();
}

/**
 * 新增指令页（B3 重写）：只绑定 `CommandEditViewModel`。
 * 页面自留导航栈与提示；草稿、校验、保存与失败类别都在 VM 里（设计 §2.4.4 的 `AddCommand` 行）。
 */
@Entry
@ComponentV2
struct AddCommand {
    private LOG_TAG = '[pages/AddCommand]';

    // 路由参数到达前先占一个空 VM，`onReady` 拿到真正的列表 VM 后替换
    @Local viewModel: CommandEditViewModel = new CommandEditViewModel(new CommandListViewModel());

    private uiContext = this.getUIContext();
    private promptAction = this.uiContext.getPromptAction();

    pathStack: NavPathStack | undefined = undefined;

    private async saveCommand(): Promise<void> {
        const outcome: EditSaveOutcome = await this.viewModel.save();

        if (outcome.ok) {
            PageContext.alert($r("app.string.AddCommand_Add_Success"), this.promptAction);
            this.viewModel.startAdd();
            return;
        }

        if (outcome.failure === 'invalid') {
            PageContext.alert($r("app.string.AddCommand_Invalid_Input"), this.promptAction);
        } else if (outcome.failure === 'rejected') {
            PageContext.alert($r("app.string.AddCommand_Add_Failed_Try_Again"), this.promptAction);
        } else {
            Logger.error(this.LOG_TAG, `保存命令失败: ${outcome.failure}`);
            PageContext.alert($r("app.string.AddCommand_Add_Failed"), this.promptAction);
        }
    }

    build() {
        HdsNavDestination() {
            Scroll() {
                Column({ space: StyleConstants.ADD_COMMAND_COL_SPACE }) {
                    Blank()
                        .margin({ top: StyleConstants.MARGIN_TEN, bottom: StyleConstants.MARGIN_TEN })

                    // 名称输入
                    Text($r("app.string.AddCommand_Name_Label"))
                        .fontSize(StyleConstants.ADD_COMMAND_LABEL_FONT_SIZE)
                        .alignSelf(ItemAlign.Start)
                        .margin({ left: StyleConstants.MARGIN_TWENTY })
                    TextInput(
                        {
                            placeholder: $r("app.string.AddCommand_Name_Input_Placeholder"),
                            text: this.viewModel.nickname
                        }
                    )
                        .onChange(
                            (value: string) => {
                                this.viewModel.nickname = value;
                            }
                        )
                        .defaultFocus(true)
                        .margin({ left: StyleConstants.MARGIN_TWENTY, right: StyleConstants.MARGIN_TWENTY })
                        .padding(StyleConstants.PADDING_TEN)
                        .border({ width: StyleConstants.INPUT_BORDER_WIDTH, color: Color.Gray })

                    // 命令输入
                    Text($r("app.string.AddCommand_Command_Label"))
                        .fontSize(StyleConstants.ADD_COMMAND_LABEL_FONT_SIZE)
                        .alignSelf(ItemAlign.Start)
                        .margin({ left: StyleConstants.MARGIN_TWENTY, top: StyleConstants.MARGIN_TWENTY })
                    TextInput(
                        {
                            placeholder: $r("app.string.AddCommand_Command_Input_Placeholder"),
                            text: this.viewModel.command
                        }
                    )
                        .onChange(
                            (value: string) => {
                                this.viewModel.command = value;
                            }
                        )
                        .defaultFocus(false)
                        .margin({ left: StyleConstants.MARGIN_TWENTY, right: StyleConstants.MARGIN_TWENTY })
                        .padding(StyleConstants.PADDING_TEN)
                        .border({ width: StyleConstants.INPUT_BORDER_WIDTH, color: Color.Gray })

                    // 选项区域 - 使用 Toggle 组件
                    Column({ space: StyleConstants.ADD_COMMAND_OPTION_COL_SPACE }) {
                        Text($r("app.string.AddCommand_Options_Label"))
                            .fontSize(StyleConstants.ADD_COMMAND_LABEL_FONT_SIZE)
                            .alignSelf(ItemAlign.Start)
                            .margin({ bottom: StyleConstants.MARGIN_TEN })

                        // 需要输入账户的选项
                        Row({ space: StyleConstants.ADD_COMMAND_ROW_SPACE }) {
                            Toggle({ type: ToggleType.Checkbox, isOn: this.viewModel.accountRequired })
                                .onChange(
                                    (value: boolean) => {
                                        this.viewModel.accountRequired = value;
                                    }
                                )
                            Text($r("app.string.AddCommand_Needs_ASF_Account_Input_Label"))
                                .fontSize(StyleConstants.ADD_COMMAND_CHECK_LABEL_FONT_SIZE)
                        }
                        .justifyContent(FlexAlign.Start)
                        .width(StyleConstants.FULL_PERCENT)

                        // 需要输入 App ID 的选项
                        Row({ space: StyleConstants.ADD_COMMAND_ROW_SPACE }) {
                            Toggle({ type: ToggleType.Checkbox, isOn: this.viewModel.idRequired })
                                .onChange(
                                    (value: boolean) => {
                                        this.viewModel.idRequired = value;
                                    }
                                )
                            Text($r("app.string.AddCommand_Needs_ASF_ID_Input_Label"))
                                .fontSize(StyleConstants.ADD_COMMAND_CHECK_LABEL_FONT_SIZE)
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

                    // 按钮区域
                    Button($r("app.string.AddCommand_Add_Button_Label"))
                        .width(StyleConstants.SEVENTY_PERCENT)
                        .enabled(this.viewModel.canSave() && !this.viewModel.isSaving)
                        .margin({ top: StyleConstants.MARGIN_FORTY })
                        .onClick(
                            () => {
                                this.saveCommand();
                            }
                        )

                    // 占位空间
                    Blank()
                }
                .justifyContent(FlexAlign.Center)
                .padding(StyleConstants.PADDING_TWENTY)
            }
            .height(StyleConstants.FULL_PERCENT)
        }
        .titleBar({
            content: {
                title: {
                    mainTitle: $r("app.string.AddCommand_Title")
                }
            },
            style: {
                systemMaterialEffect: {
                    materialType: hdsMaterial.MaterialType.ADAPTIVE,
                    materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
                },
            },
            enableComponentSafeArea: true
        })
        .height(StyleConstants.FULL_PERCENT)
        .width(StyleConstants.FULL_PERCENT)
        .onReady((context: NavDestinationContext) => {
            this.pathStack = context.pathStack;
            // 路由参数带的是主列表的 VM：新增要落库并刷新列表与卡片，走的就是它
            const param: CommandListViewModel = context.pathInfo.param as CommandListViewModel;
            if (param instanceof CommandListViewModel) {
                this.viewModel = new CommandEditViewModel(param);
            } else {
                Logger.warn(this.LOG_TAG, `未收到列表 VM，保留占位实例`);
            }
            this.viewModel.startAdd();
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
