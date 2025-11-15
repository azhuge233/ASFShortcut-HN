import Logger from '../common/utils/Logger';
import { DB } from '../common/utils/DB';
import CommonConstants from '../common/constants/CommonConstants';
import StyleConstants from '../common/constants/StyleConstants';
import CommonUtils from '../common/utils/CommonUtils';

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
                Text($r("app.string.SettingsPage_Title"))
                    .fontSize(StyleConstants.SETTINGS_PAGE_TITLE_FONT_SIZE)
                    .fontWeight(FontWeight.Bold)
                    .margin({ top: StyleConstants.MARGIN_FORTY, bottom: StyleConstants.MARGIN_FORTY })

                Text($r("app.string.SettingsPage_Address_Label"))
                    .fontSize(StyleConstants.SETTINGS_PAGE_LABEL_FONT_SIZE)
                    .alignSelf(ItemAlign.Start)
                    .margin({ bottom: StyleConstants.MARGIN_TEN })

                TextInput({ text: this.address, placeholder: $r("app.string.SettingsPage_Address_Input_Placeholder") })
                    .width(StyleConstants.NINETY_PERCENT)
                    .height(StyleConstants.SETTINGS_PAGE_INPUT_HEIGHT)
                    .border({ width: StyleConstants.SETTINGS_PAGE_INPUT_BORDER_WIDTH, color: Color.Gray })
                    .borderRadius(StyleConstants.SETTINGS_PAGE_INPUT_BORDER_RADIUS)
                    .padding(StyleConstants.PADDING_TEN)
                    .onChange((value: string) => {
                        this.address = value;
                    })
                    .margin({ bottom: StyleConstants.MARGIN_THIRTY })

                Text($r("app.string.SettingsPage_Password_Label"))
                    .fontSize(StyleConstants.SETTINGS_PAGE_LABEL_FONT_SIZE)
                    .alignSelf(ItemAlign.Start)
                    .margin({ bottom: StyleConstants.MARGIN_TEN })

                TextInput({ text: this.asfPassword, placeholder: $r("app.string.SettingsPage_Password_Input_Placeholder") })
                    .type(InputType.Password)
                    .width(StyleConstants.NINETY_PERCENT)
                    .height(StyleConstants.SETTINGS_PAGE_INPUT_HEIGHT)
                    .border({ width: StyleConstants.SETTINGS_PAGE_INPUT_BORDER_WIDTH, color: Color.Gray })
                    .borderRadius(StyleConstants.SETTINGS_PAGE_INPUT_BORDER_RADIUS)
                    .padding(StyleConstants.PADDING_TEN)
                    .onChange((value: string) => {
                        this.asfPassword = value;
                    })
                    .margin({ bottom: StyleConstants.MARGIN_FIFTY })

                Button(this.isSaving ? $r("app.string.SettingsPage_Save_Button_Saving") : $r("app.string.SettingsPage_Save_Button_Label"), { type: ButtonType.Capsule })
                    .width(StyleConstants.EIGHTY_PERCENT)
                    .fontColor(Color.White)
                    .enabled(!this.isSaving && this.address.trim() !== '' && this.asfPassword.trim() !== '')
                    .onClick(async () => {
                        const saveSuccess = await this.saveSettings();
                        if (saveSuccess) {
                            CommonUtils.alert($r("app.string.SettingsPage_Save_Success"), this.promptAction);
                            this.pathStack?.pop("Submit pressed");
                        } else CommonUtils.alert($r("app.string.SettingsPage_Save_Failed"), this.promptAction);
                    })
            }
        }
        .width(StyleConstants.FULL_PERCENT)
        .height(StyleConstants.FULL_PERCENT)
        .onReady((context: NavDestinationContext) => {
            this.pathStack = context.pathStack;
        })
        .onBackPressed(() => {
            if(this.isSaving) {
                CommonUtils.alert($r("app.string.SettingsPage_Save_Button_Saving"), this.promptAction);
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