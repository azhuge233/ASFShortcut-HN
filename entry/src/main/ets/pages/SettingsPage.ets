import { promptAction } from '@kit.ArkUI';
import { deviceInfo, BusinessError } from '@kit.BasicServicesKit';

import Logger from '../common/utils/Logger';
import { DB } from '../common/utils/DB';
import CommonConstants from '../common/constants/CommonConstants';

@Builder
export function SettingsPageBuilder() {
    SettingsPage();
}

@Entry
@ComponentV2
struct SettingsPage {
    private LOG_TAG = "[pages/SettingsPage]";

    @Local address: string = '';
    @Local asfPassword: string = '';

    @Local isSaving: boolean = false;

    pathStack: NavPathStack | undefined = undefined;

    private db = DB.getInstance();

    private uiContext = this.getUIContext();
    private promptAction = this.uiContext.getPromptAction();

    aboutToAppear(): void {
        // 加载当前设置
        this.loadSettings();
    }

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

    async loadSettings(): Promise<void> {
        this.address = await this.db.getSetting(CommonConstants.DB_KEY_HostInfo_KEY_NAME_Address);
        this.asfPassword = await this.db.getSetting(CommonConstants.DB_KEY_HostInfo_KEY_NAME_Password);
    }

    async saveSettings(): Promise<boolean> {
        this.isSaving = true;

        const success1 = await this.db.saveSetting(CommonConstants.DB_KEY_HostInfo_KEY_NAME_Address, this.address);
        const success2 = await this.db.saveSetting(CommonConstants.DB_KEY_HostInfo_KEY_NAME_Password, this.asfPassword);

        this.isSaving = false;

        return success1 && success2;
    }

    build() {
        NavDestination() {
            Column() {
                Text('ASF设置')
                    .fontSize(24)
                    .fontWeight(FontWeight.Bold)
                    .margin({ top: 40, bottom: 40 })

                Text('服务器地址')
                    .fontSize(16)
                    .alignSelf(ItemAlign.Start)
                    .margin({ left: 20, bottom: 10 })

                TextInput({ text: this.address, placeholder: '输入ASF服务器地址' })
                    .width('90%')
                    .height(50)
                    .border({ width: 1, color: Color.Gray })
                    .borderRadius(8)
                    .padding(10)
                    .onChange((value: string) => {
                        this.address = value;
                    })
                    .margin({ bottom: 30 })

                Text('密码')
                    .fontSize(16)
                    .alignSelf(ItemAlign.Start)
                    .margin({ left: 20, bottom: 10 })

                TextInput({ text: this.asfPassword, placeholder: '输入密码' })
                    .type(InputType.Password)
                    .width('90%')
                    .height(50)
                    .border({ width: 1, color: Color.Gray })
                    .borderRadius(8)
                    .padding(10)
                    .onChange((value: string) => {
                        this.asfPassword = value;
                    })
                    .margin({ bottom: 50 })

                Button(this.isSaving ? '保存中...' : '保存设置', { type: ButtonType.Capsule })
                    .width('90%')
                    .height(50)
                    .fontColor(Color.White)
                    .enabled(!this.isSaving && this.address.trim() !== '' && this.asfPassword.trim() !== '')
                    .onClick(async () => {
                        const saveSuccess = await this.saveSettings();
                        if (saveSuccess) {
                            this.alert('设置更新成功');
                            this.pathStack?.pop("Submit pressed");
                        } else this.alert('保存失败，请重试');
                    })
            }
        }
        .width('100%')
        .height('100%')
        .onReady((context: NavDestinationContext) => {
            this.pathStack = context.pathStack;
        })
        .onBackPressed(() => {
            if(this.isSaving) {
                this.alert('Saving...');
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