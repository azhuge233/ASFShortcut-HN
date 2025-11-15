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

    alert(message: string) {
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
            // 显示错误提示
            this.alert('名称和命令不能为空');
            return;
        }

        try {
            const success = await this.listViewModel.updateCommandEntry(this.updatingCommandEntry.toCommandEntry());
            if (success) {
                this.alert('命令更新成功');
                this.pathStack?.pop("Button pressed");
            } else this.alert('更新失败，请重试');
        } catch (err) {
            Logger.error(this.LOG_TAG, `更新命令失败: ${err}`);
            this.alert('更新失败');
        }
    }

    build() {
        NavDestination() {
            Column({ space: 20 }) {
                Blank()
                    .margin({ top: 10, bottom: 10 })

                // 名称输入
                Text('名称:')
                    .fontSize(18)
                    .alignSelf(ItemAlign.Start)
                    .margin({ left: 20 })
                TextInput({ placeholder: '输入命令名称', text: this.updatingCommandEntry.nickname })
                    .onChange((value: string) => {
                        this.updatingCommandEntry.nickname = value;
                    })
                    .margin({ left: 20, right: 20 })
                    .padding(10)
                    .border({ width: 1, color: Color.Gray })
                    .borderRadius(8)

                // 命令输入
                Text('命令:')
                    .fontSize(18)
                    .alignSelf(ItemAlign.Start)
                    .margin({ left: 20, top: 20 })
                TextInput({ placeholder: '输入ASF命令', text: this.updatingCommandEntry.command })
                    .onChange((value: string) => {
                        this.updatingCommandEntry.command = value;
                    })
                    .margin({ left: 20, right: 20 })
                    .padding(10)
                    .border({ width: 1, color: Color.Gray })
                    .borderRadius(8)

                // 选项区域 - 使用 Toggle 组件
                Column({ space: 15 }) {
                    Text('选项设置:')
                        .fontSize(18)
                        .alignSelf(ItemAlign.Start)
                        .margin({ bottom: 10 })

                    // 需要输入账户的选项
                    Row({ space: 10 }) {
                        Toggle({ type: ToggleType.Checkbox, isOn: this.updatingCommandEntry.accountRequired })
                            .onChange((value: boolean) => {
                                this.updatingCommandEntry.accountRequired = value;
                            })
                        Text('需要输入ASF账户')
                            .fontSize(16)
                    }
                    .justifyContent(FlexAlign.Start)
                    .width('100%')

                    // 需要输入 App ID 的选项
                    Row({ space: 10 }) {
                        Toggle({ type: ToggleType.Checkbox, isOn: this.updatingCommandEntry.idRequired })
                            .onChange((value: boolean) => {
                                this.updatingCommandEntry.idRequired = value;
                            })
                        Text('需要输入ASF App/Sub/Def ID')
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
                Button('保存')
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
        .title("编辑")
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