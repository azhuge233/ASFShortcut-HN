import { HdsNavDestination, hdsMaterial } from '@kit.UIDesignKit';

import Logger from '../../common/utils/Logger';
import StyleConstants from '../../common/constants/StyleConstants';
import PageContext from '../common/PageContext';
import AsfSettingsViewModel from '../../viewmodel/AsfSettingsViewModel';

@Builder
export function ASFSettingsPageBuilder() {
    ASFSettingsPage();
}

/**
 * ASF 设置页（B3 重写）：只绑定 `AsfSettingsViewModel`（设计 §2.4.4 的 `ASFSettingsPage` 行）。
 * 页面自留导航栈与提示；地址规范化、两个键的落盘与保存中标记都在 VM 里。
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

    build() {
        HdsNavDestination() {
            Scroll() {
                Column() {
                    Text($r("app.string.SettingsPage_Title"))
                        .fontSize(StyleConstants.SETTINGS_PAGE_TITLE_FONT_SIZE)
                        .fontWeight(FontWeight.Bold)
                        .margin({ top: StyleConstants.MARGIN_FORTY, bottom: StyleConstants.MARGIN_FORTY })

                    Text($r("app.string.SettingsPage_Address_Label"))
                        .fontSize(StyleConstants.SETTINGS_PAGE_LABEL_FONT_SIZE)
                        .alignSelf(ItemAlign.Start)
                        .margin({ bottom: StyleConstants.MARGIN_TEN })

                    TextInput(
                        {
                            text: this.viewModel.address,
                            placeholder: $r("app.string.SettingsPage_Address_Input_Placeholder")
                        }
                    )
                        .width(StyleConstants.NINETY_PERCENT)
                        .border({ width: StyleConstants.INPUT_BORDER_WIDTH, color: Color.Gray })
                        .padding(StyleConstants.PADDING_TEN)
                        .onChange(
                            (value: string) => {
                                this.viewModel.address = value;
                            }
                        )
                        .margin({ bottom: StyleConstants.MARGIN_THIRTY })

                    Text($r("app.string.SettingsPage_Password_Label"))
                        .fontSize(StyleConstants.SETTINGS_PAGE_LABEL_FONT_SIZE)
                        .alignSelf(ItemAlign.Start)
                        .margin({ bottom: StyleConstants.MARGIN_TEN })

                    TextInput(
                        {
                            text: this.viewModel.password,
                            placeholder: $r("app.string.SettingsPage_Password_Input_Placeholder")
                        }
                    )
                        .type(InputType.Password)
                        .width(StyleConstants.NINETY_PERCENT)
                        .border({ width: StyleConstants.INPUT_BORDER_WIDTH, color: Color.Gray })
                        .padding(StyleConstants.PADDING_TEN)
                        .onChange(
                            (value: string) => {
                                this.viewModel.password = value;
                            }
                        )
                        .margin({ bottom: StyleConstants.MARGIN_FIFTY })

                    Button(
                        this.viewModel.isSaving ? $r("app.string.SettingsPage_Save_Button_Saving") :
                            $r("app.string.SettingsPage_Save_Button_Label"), { type: ButtonType.Capsule }
                    )
                        .width(StyleConstants.EIGHTY_PERCENT)
                        .fontColor(Color.White)
                        .enabled(!this.viewModel.isSaving && this.viewModel.canSave())
                        .onClick(
                            async () => {
                                const saveSuccess = await this.viewModel.save();
                                if (saveSuccess) {
                                    PageContext.alert($r("app.string.SettingsPage_Save_Success"), this.promptAction);
                                    this.pathStack?.pop("Submit pressed");
                                } else PageContext.alert($r("app.string.SettingsPage_Save_Failed"), this.promptAction);
                            }
                        )
                }
            }
        }
        .titleBar({
            style: {
                systemMaterialEffect: {
                    materialType: hdsMaterial.MaterialType.ADAPTIVE,
                    materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
                }
            },
            enableComponentSafeArea: true
        })
        .width(StyleConstants.FULL_PERCENT)
        .height(StyleConstants.FULL_PERCENT)
        .onReady((context: NavDestinationContext) => {
            this.pathStack = context.pathStack;
        })
        .onBackPressed(() => {
            if (this.viewModel.isSaving) {
                PageContext.alert($r("app.string.SettingsPage_Save_Button_Saving"), this.promptAction);
                return true;
            }
            this.pathStack?.pop("Back pressed");
            return true;
        })
        .onAppear(() => {
            Logger.debug(this.LOG_TAG, "Loaded!");
        })
    }
}
