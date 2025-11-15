import { deviceInfo, BusinessError } from '@kit.BasicServicesKit';
import { promptAction } from '@kit.ArkUI';

import Logger from '../common/utils/Logger';
import CommandEntryListViewModel from '../viewmodel/CommandEntryListViewModel';
import { CommandEntryViewModel } from '../viewmodel/CommandEntryViewModel';

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

    clearInput() {
        this.newCommandViewModel.nickname = '';
        this.newCommandViewModel.command = '';
        this.newCommandViewModel.accountInputRequired = 0;
        this.newCommandViewModel.idInputRequired = 0;
    }

    async saveCommand() {
        if (!this.newCommandViewModel.nickname.trim() || !this.newCommandViewModel.command.trim()) {
            this.alert($r("app.string.AddCommand_Invalid_Input"));
            return;
        }

        try {
            const success = await this.listViewModel.addCommandEntry(this.newCommandViewModel.toCommandEntry());
            if (success) {
                this.alert($r("app.string.AddCommand_Add_Success"));
                this.clearInput();
            } else this.alert($r("app.string.AddCommand_Add_Failed_Try_Again"));
        } catch (err) {
            Logger.error(this.LOG_TAG, `保存命令失败: ${err}`);
            this.alert($r("app.string.AddCommand_Add_Failed"));
        }
    }

    build() {
        NavDestination() {
            Column({ space: 20 }) {
                Blank()
                    .margin({ top: 10, bottom: 10 })

                // 名称输入
                Text($r("app.string.AddCommand_Name_Label"))
                    .fontSize(18)
                    .alignSelf(ItemAlign.Start)
                    .margin({ left: 20 })
                TextInput({ placeholder: $r("app.string.AddCommand_Name_Input_Placeholder"), text: this.newCommandViewModel.nickname })
                    .onChange((value: string) => {
                        this.newCommandViewModel.nickname = value;
                    })
                    .margin({ left: 20, right: 20 })
                    .padding(10)
                    .border({ width: 1, color: Color.Gray })
                    .borderRadius(8)

                // 命令输入
                Text($r("app.string.AddCommand_Command_Label"))
                    .fontSize(18)
                    .alignSelf(ItemAlign.Start)
                    .margin({ left: 20, top: 20 })
                TextInput({ placeholder: $r("app.string.AddCommand_Command_Input_Placeholder"), text: this.newCommandViewModel.command })
                    .onChange((value: string) => {
                        this.newCommandViewModel.command = value;
                    })
                    .margin({ left: 20, right: 20 })
                    .padding(10)
                    .border({ width: 1, color: Color.Gray })
                    .borderRadius(8)

                // 选项区域 - 使用 Toggle 组件
                Column({ space: 15 }) {
                    Text($r("app.string.AddCommand_Options_Label"))
                        .fontSize(18)
                        .alignSelf(ItemAlign.Start)
                        .margin({ bottom: 10 })

                    // 需要输入账户的选项
                    Row({ space: 10 }) {
                        Toggle({ type: ToggleType.Checkbox, isOn: this.newCommandViewModel.accountRequired })
                            .onChange((value: boolean) => {
                                this.newCommandViewModel.accountRequired = value;
                            })
                        Text($r("app.string.AddCommand_Needs_ASF_Account_Input_Label"))
                            .fontSize(16)
                    }
                    .justifyContent(FlexAlign.Start)
                    .width('100%')

                    // 需要输入 App ID 的选项
                    Row({ space: 10 }) {
                        Toggle({ type: ToggleType.Checkbox, isOn: this.newCommandViewModel.idRequired })
                            .onChange((value: boolean) => {
                                this.newCommandViewModel.idRequired = value;
                            })
                        Text($r("app.string.AddCommand_Needs_ASF_ID_Input_Label"))
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

                // 按钮区域
                Button($r("app.string.AddCommand_Add_Button_Label"))
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
        .title($r("app.string.AddCommand_Title"))
        .height('100%')
        .width('100%')
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