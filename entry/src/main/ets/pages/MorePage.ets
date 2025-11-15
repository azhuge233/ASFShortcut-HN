import { deviceInfo, BusinessError } from '@kit.BasicServicesKit';
import { promptAction } from '@kit.ArkUI';

import Logger from '../common/utils/Logger';
import StyleConstants from '../common/constants/StyleConstants';
import CommandEntryListViewModel from '../viewmodel/CommandEntryListViewModel';
import { DB } from '../common/utils/DB';
import { MoreMenuItem } from '../view/components/MoreMenuItem';

@Builder
export function MorePageBuilder() {
    MorePage();
}

@Entry
@ComponentV2
struct MorePage {
    private LOG_TAG = '[pages/More]';

    @Local private isProcessing: boolean = false;

    private uiContext = this.getUIContext();
    private promptAction = this.uiContext.getPromptAction();

    pathStack: NavPathStack | undefined = undefined;

    private db = DB.getInstance();

    private listViewModel: CommandEntryListViewModel = new CommandEntryListViewModel();

    alert(message: string | Resource) {
        if(deviceInfo.sdkApiVersion <= 17) {
            try {
                promptAction.showToast({
                    message: message
                });
            } catch (err) {
                Logger.error(this.LOG_TAG, `<alert API <= 17> 错误, ${err}`);
            }
        } else {
            this.promptAction.openToast({
                message: message
            }).catch((err: BusinessError) => {
                Logger.error(this.LOG_TAG, `<alert API > 17> 错误, ${err}`);
            });
        }
    }

    // 从 NavDestination 由 pop() 返回时
    // 显示回调 popInfo
    async returnFromSubPage(popInfo: PopInfo): Promise<void> {
        Logger.debug(this.LOG_TAG,
            `从 [${popInfo.info.name}] 页面返回, 携带参数: ${JSON.stringify(popInfo.result)}`);
    }

    // 导入时显示
    // 阻止用户操作
    @Builder
    LoadingContent() {
        Stack() {
            Column()
                .width(StyleConstants.FULL_PERCENT)
                .height(StyleConstants.FULL_PERCENT)
                .backgroundColor($r("app.color.transparent"))
                .blur(StyleConstants.BLUE_LEVEL)
                .onClick(() => {})

            Column() {
                Progress({ value: 0, total: 100, type: ProgressType.Ring })
                    .width(StyleConstants.PROGRESS_WIDTH)
                    .color(Color.Blue)
                    .style({
                        strokeWidth: StyleConstants.PROGRESS_STROKE_WIDTH,
                        status: ProgressStatus.LOADING
                    })

                Text($r("app.string.Index_processing"))
                    .margin({ top: StyleConstants.MARGIN_TWENTY })
                    .fontSize(StyleConstants.PROGRESS_TEXT_FONT_SIZE)
            }
            .width(StyleConstants.FULL_PERCENT)
            .height(StyleConstants.FULL_PERCENT)
            .justifyContent(FlexAlign.Center)
            .onClick(() => {
            })
        }
        .onClick(() => {
        })
        .onAppear(() => {
            Logger.debug(this.LOG_TAG, "Blocking stack loaded!");
        })
    }

    build() {
        Stack() {
            NavDestination() {
                Column() {
                    MoreMenuItem({
                        menuText: $r("app.string.More_Settings_Label"),
                        menuIcon: $r("app.media.gearshape"),
                        doJob: () => {
                            this.pathStack?.pushPath({
                                name: "SettingsPage",
                                onPop: async (popInfo) => {
                                    await this.returnFromSubPage(popInfo);
                                }
                            });
                        }
                    })

                    MoreMenuItem({
                        menuText: $r("app.string.More_Export_Label"),
                        menuIcon: $r("app.media.arrow_up_circle")
                    })

                    MoreMenuItem({
                        menuText: $r("app.string.More_Import_Label"),
                        menuIcon: $r("app.media.arrow_down_circle")
                    })

                    MoreMenuItem({
                        menuText: $r("app.string.More_Clear_Label"),
                        menuIcon: $r("app.media.clean")
                    })

                    MoreMenuItem({
                        menuText: $r("app.string.More_Help_Label"),
                        menuIcon: $r("app.media.info_circle")
                    })
                }
                .height(StyleConstants.FULL_PERCENT)
                .width(StyleConstants.FULL_PERCENT)
            }
            .title("更多功能")
            .height(StyleConstants.FULL_PERCENT)
            .width(StyleConstants.FULL_PERCENT)
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

            if (this.isProcessing) {
                this.LoadingContent();
            }
        }
    }
}