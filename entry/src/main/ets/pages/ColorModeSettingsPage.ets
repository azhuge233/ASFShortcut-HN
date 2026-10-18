import { common, ConfigurationConstant } from '@kit.AbilityKit';
import { hdsMaterial, HdsNavDestination } from '@kit.UIDesignKit';
import { AppStorageV2 } from '@kit.ArkUI';

import StyleConstants from '../common/constants/StyleConstants';
import { AppSettingsManager } from '../common/utils/AppSettingsManager';
import Logger from '../common/utils/Logger';
import { AppSettings } from '../model/AppSettings';
import CommonConstants from '../common/constants/CommonConstants';

export class ColorModeOption {
    label: Resource;
    mode: ConfigurationConstant.ColorMode;

    constructor(label: Resource, mode: ConfigurationConstant.ColorMode) {
        this.label = label;
        this.mode = mode;
    }
}

export const colorModeOptions: ColorModeOption[] = [
    new ColorModeOption($r("app.string.Color_Mode_System_Label"), ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET),
    new ColorModeOption($r("app.string.Color_Mode_Light_Label"), ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT),
    new ColorModeOption($r("app.string.Color_Mode_Dark_Label"), ConfigurationConstant.ColorMode.COLOR_MODE_DARK)
];

@Builder
export function ColorModeSettingsPageBuilder() {
    ColorModeSettingsPage();
}

@Entry
@ComponentV2
struct ColorModeSettingsPage {
    private LOG_TAG = "[pages/ColorModeSettingsPage]";

    @Local appSettings: AppSettings = AppStorageV2.connect(AppSettings, CommonConstants.APP_STORAGE_KEY_APP_SETTINGS,
        () => new AppSettings(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET))!;

    pathStack: NavPathStack | undefined = undefined;

    private uiContext = this.getUIContext();
    private context = this.uiContext.getHostContext() as common.UIAbilityContext;

    private aSM: AppSettingsManager = AppSettingsManager.getInstance();

    private async applyColorMode(mode: ConfigurationConstant.ColorMode) {
        if (this.appSettings.colorMode === mode) return;

        this.appSettings.colorMode = mode;
        await this.aSM.set(this.appSettings);

        try {
            this.context.getApplicationContext().setColorMode(mode);
            Logger.debug(this.LOG_TAG, `窗口颜色设置: ${mode}`);
        } catch (err) {
            Logger.error(this.LOG_TAG, `设置窗口颜色模式失败, ${err}`);
        }
    }

    @Builder
    MainContent() {
        Column() {
            ForEach(colorModeOptions, (item: ColorModeOption) => {
                Row() {
                    Text(item.label)
                        .fontColor($r("sys.color.font_primary"))
                        .layoutWeight(1)
                        .padding(StyleConstants.PADDING_FIFTEEN);

                    Radio({
                        value: item.mode.toString(),
                        group: 'colorMode'
                    })
                        .height(StyleConstants.COLOR_MODE_PAGE_RADIO_SIZE)
                        .width(StyleConstants.COLOR_MODE_PAGE_RADIO_SIZE)
                        .checked(item.mode === this.appSettings.colorMode)
                        .onChange(async (isChecked: boolean) => {
                            if (isChecked) await this.applyColorMode(item.mode);
                        })
                        .padding({
                            right: StyleConstants.PADDING_FIFTEEN
                        });
                }
                .width(StyleConstants.NINETY_PERCENT)
                .border({
                    width: { bottom: StyleConstants.COLOR_MODE_PAGE_BORDER_WIDTH },
                    color: $r("sys.color.font_tertiary")
                })
                .onClick(async () => {
                    await this.applyColorMode(item.mode);
                })
            }, (item: ColorModeOption) => item.mode.toString());
        }
        .width(StyleConstants.FULL_PERCENT)
        .padding({
            top: StyleConstants.PADDING_FIFTEEN
        });
    }

    build() {
        HdsNavDestination() {
            this.MainContent();
        }
        .titleBar({
            content: {
                title: {
                    mainTitle: $r("app.string.Color_Mode_Settings_Title")
                }
            },
            style: {
                systemMaterialEffect: {
                    materialType: hdsMaterial.MaterialType.ADAPTIVE,
                    materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
                }
            },
            enableComponentSafeArea: true
        })
        .height(StyleConstants.FULL_PERCENT)
        .width(StyleConstants.FULL_PERCENT)
        .backgroundColor($r("sys.color.background_primary"))
        .onReady((context: NavDestinationContext) => {
            this.pathStack = context.pathStack;
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