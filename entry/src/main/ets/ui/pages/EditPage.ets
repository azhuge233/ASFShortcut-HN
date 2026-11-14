import { HdsNavDestination, hdsMaterial } from '@kit.UIDesignKit';

import Logger from '../../common/utils/Logger';
import StyleConstants from '../../common/constants/StyleConstants';
import PageContext from '../common/PageContext';
import CommandListViewModel from '../../viewmodel/CommandListViewModel';
import { CommandEditViewModel, EditSaveOutcome } from '../../viewmodel/CommandEditViewModel';
import { CommandEntryViewModel } from '../../viewmodel/CommandEntryViewModel';

@Builder
export function EditPageBuilder() {
    EditPage();
}

/**
 * 编辑指令页（B3 重写）：只绑定 `CommandEditViewModel`。
 * 来源条目由路由参数给，`startEdit` 把草稿填进 VM；页面自留导航栈与提示（设计 §2.4.4 的 `EditPage` 行）。
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

    build() {
        HdsNavDestination() {
            Scroll() {
                Column({ space: StyleConstants.EDIT_PAGE_BLANK_COL_SPACE }) {
                    Blank()
                        .margin({ top: StyleConstants.MARGIN_TEN, bottom: StyleConstants.MARGIN_TEN })

                    // 名称输入
                    Text($r("app.string.EditPage_Name_Label"))
                        .fontSize(StyleConstants.EDIT_PAGE_LABEL_FONT_SIZE)
                        .alignSelf(ItemAlign.Start)
                        .margin({ left: StyleConstants.MARGIN_TWENTY })
                    TextInput(
                        {
                            placeholder: $r("app.string.EditPage_Name_Input_Placeholder"),
                            text: this.viewModel.nickname
                        }
                    )
                        .onChange(
                            (value: string) => {
                                this.viewModel.nickname = value;
                            }
                        )
                        .margin({ left: StyleConstants.MARGIN_TWENTY, right: StyleConstants.MARGIN_TWENTY })
                        .padding(StyleConstants.PADDING_TEN)
                        .border({ width: StyleConstants.INPUT_BORDER_WIDTH, color: Color.Gray })

                    // 命令输入
                    Text($r("app.string.EditPage_Command_Label"))
                        .fontSize(StyleConstants.EDIT_PAGE_LABEL_FONT_SIZE)
                        .alignSelf(ItemAlign.Start)
                        .margin({ left: StyleConstants.MARGIN_TWENTY, top: StyleConstants.MARGIN_TWENTY })
                    TextInput(
                        {
                            placeholder: $r("app.string.EditPage_Command_Input_Placeholder"),
                            text: this.viewModel.command
                        }
                    )
                        .onChange(
                            (value: string) => {
                                this.viewModel.command = value;
                            }
                        )
                        .margin({ left: StyleConstants.MARGIN_TWENTY, right: StyleConstants.MARGIN_TWENTY })
                        .padding(StyleConstants.PADDING_TEN)
                        .border({ width: StyleConstants.INPUT_BORDER_WIDTH, color: Color.Gray })

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

                    // 按钮
                    Button($r("app.string.EditPage_Save_Button_Label"))
                        .width(StyleConstants.SEVENTY_PERCENT)
                        .enabled(!this.viewModel.isSaving)
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
                    mainTitle: $r("app.string.EditPage_Title")
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
