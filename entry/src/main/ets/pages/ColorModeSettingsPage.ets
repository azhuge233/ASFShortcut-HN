import { common, ConfigurationConstant } from '@kit.AbilityKit';
import { hdsMaterial, HdsNavDestination } from '@kit.UIDesignKit';
import { AppStorageV2 } from '@kit.ArkUI';

import StyleConstants from '../common/constants/StyleConstants';
import { AppSettingsManager } from '../common/utils/AppSettingsManager';
import Logger from '../common/utils/Logger';
import { AppSettings } from '../model/AppSettings';
import CommonConstants from '../common/constants/CommonConstants';

export const colorModeOptions: Map<string | Resource, ConfigurationConstant.ColorMode> = new Map([
    [$r("app.string.Color_Mode_System_Label"), ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET],
    [$r("app.string.Color_Mode_Light_Label"), ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT],
    [$r("app.string.Color_Mode_Dark_Label"), ConfigurationConstant.ColorMode.COLOR_MODE_DARK]
]);

@Builder
export function ColorModeSettingsPageBuilder() {
    ColorModeSettingsPage();
}

@Entry
@ComponentV2
struct ColorModeSettingsPage {
    private LOG_TAG = "[pages/ColorModeSettingsPage]";

    @Local appSettings: AppSettings = AppStorageV2.connect(AppSettings, CommonConstants.AppStorage_KEY_AppSettings)!;

    pathStack: NavPathStack | undefined = undefined;

    private uiContext = this.getUIContext();
    private context = this.uiContext.getHostContext() as common.UIAbilityContext;

    private aSM: AppSettingsManager = AppSettingsManager.getInstance();

    @Builder
    MainContent() {
        Column() {
            ForEach(Array.from(colorModeOptions.keys()), (item: Resource) => {
                Row() {
                    Text(item)
                        .fontColor($r("sys.color.font_primary"))
                        .layoutWeight(1)
                        .padding(StyleConstants.PADDING_FIFTEEN);

                    Radio({
                        value: colorModeOptions.get(item)!.toString(),
                        group: 'colorMode'
                    })
                        .height(StyleConstants.COLOR_MODE_PAGE_RADIO_SIZE)
                        .width(StyleConstants.COLOR_MODE_PAGE_RADIO_SIZE)
                        .checked(colorModeOptions.get(item) === this.appSettings.colorMode)
                        .onChange(async (isChecked: boolean) => {
                            if (isChecked) {
                                const selectedColorMode = colorModeOptions.get(item)!;
                                this.appSettings!.colorMode = selectedColorMode;
                                await this.aSM!.set(this.appSettings!);
                                try {
                                    this.context.getApplicationContext().setColorMode(selectedColorMode);
                                    Logger.debug(this.LOG_TAG, `窗口颜色设置: ${this.appSettings.colorMode}`);
                                } catch (err) {
                                    Logger.error(this.LOG_TAG, `设置窗口颜色模式失败, ${err}`);
                                }
                            }
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
                .onClick(() => {
                    this.appSettings.colorMode = colorModeOptions.get(item)!;
                })
            });
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
        .withTheme({
            enableThemeColorMode: true
        })
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