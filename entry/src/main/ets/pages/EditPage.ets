import { promptAction } from '@kit.ArkUI';
import { deviceInfo, BusinessError } from '@kit.BasicServicesKit';

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

    alert(message: string | Resource) {
        if(deviceInfo.sdkApiVersion <= 17) {
            try {
                promptAction.showToast({
                    message: message
                });
            } catch (err) {
                Logger.error(this.LOG_TAG, `<alert API <= 17> error: ${err}`);
            }
        } else {
            this.promptAction.openToast({
                message: message
            }).catch((err: BusinessError) => {
                Logger.error(this.LOG_TAG, `<alert API > 17> error: ${err}`);
            });
        }
    }

    async saveCommand() {
        if (!this.updatingCommandEntry.nickname.trim() || !this.updatingCommandEntry.command.trim()) {
            this.alert($r("app.string.EditPage_Invalid_Input"));
            return;
        }

        try {
            const success = await this.listViewModel.updateCommandEntry(this.updatingCommandEntry.toCommandEntry());
            if (success) {
                this.alert($r("app.string.EditPage_Update_Success"));
                this.pathStack?.pop("Button pressed");
            } else this.alert($r("app.string.EditPage_Update_Failed_Try_Again"));
        } catch (err) {
            Logger.error(this.LOG_TAG, `更新命令失败: ${err}`);
            this.alert($r("app.string.EditPage_Update_Failed"));
        }
    }

    build() {
        NavDestination() {
            Column({ space: 20 }) {
                Blank()
                    .margin({ top: 10, bottom: 10 })

                // 名称输入
                Text($r("app.string.EditPage_Name_Label"))
                    .fontSize(18)
                    .alignSelf(ItemAlign.Start)
                    .margin({ left: 20 })
                TextInput({ placeholder: $r("app.string.EditPage_Name_Input_Placeholder"), text: this.updatingCommandEntry.nickname })
                    .onChange((value: string) => {
                        this.updatingCommandEntry.nickname = value;
                    })
                    .margin({ left: 20, right: 20 })
                    .padding(10)
                    .border({ width: 1, color: Color.Gray })
                    .borderRadius(8)

                // 命令输入
                Text($r("app.string.EditPage_Command_Label"))
                    .fontSize(18)
                    .alignSelf(ItemAlign.Start)
                    .margin({ left: 20, top: 20 })
                TextInput({ placeholder: $r("app.string.EditPage_Command_Input_Placeholder"), text: this.updatingCommandEntry.command })
                    .onChange((value: string) => {
                        this.updatingCommandEntry.command = value;
                    })
                    .margin({ left: 20, right: 20 })
                    .padding(10)
                    .border({ width: 1, color: Color.Gray })
                    .borderRadius(8)

                // 选项区域 - 使用 Toggle 组件
                Column({ space: 15 }) {
                    Text($r("app.string.EditPage_Options_Label"))
                        .fontSize(18)
                        .alignSelf(ItemAlign.Start)
                        .margin({ bottom: 10 })

                    // 需要输入ASF账户的选项
                    Row({ space: 10 }) {
                        Toggle({ type: ToggleType.Checkbox, isOn: this.updatingCommandEntry.accountRequired })
                            .onChange((value: boolean) => {
                                this.updatingCommandEntry.accountRequired = value;
                            })
                        Text($r("app.string.EditPage_Needs_ASF_Account_Input_Label"))
                            .fontSize(16)
                    }
                    .justifyContent(FlexAlign.Start)
                    .width('100%')

                    // 需要输入 ASF App ID 的选项
                    Row({ space: 10 }) {
                        Toggle({ type: ToggleType.Checkbox, isOn: this.updatingCommandEntry.idRequired })
                            .onChange((value: boolean) => {
                                this.updatingCommandEntry.idRequired = value;
                            })
                        Text($r("app.string.EditPage_Needs_ASF_ID_Input_Label"))
                            .fontSize(16)
                    }
                    .justifyContent(FlexAlign.Start)
                    .width('100%')
                }
                .alignSelf(ItemAlign.Start)
                .margin({ left: 20, top: 20, right: 20 })
                .padding(15)
                .border({ width: 1, color: Color.Gray })
                .borderRadius(8)
                .width('90%')

                // 按钮
                Button($r("app.string.EditPage_Save_Button_Label"))
                    .width('70%')
                    .margin({ top: 40 })
                    .onClick(() => {
                        this.saveCommand();
                    })

                // 占位空间
                Blank()
            }
            .padding(20)
        }
        .title($r("app.string.EditPage_Title"))
        .height('100%')
        .width('100%')
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