import Logger from '../common/utils/Logger';
import StyleConstants from '../common/constants/StyleConstants';
import CommandEntryListViewModel from '../viewmodel/CommandEntryListViewModel';
import { DB } from '../common/utils/DB';
import { MoreMenuItem } from '../view/components/MoreMenuItem';
import CommonUtils from '../common/utils/CommonUtils';

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
                                onPop: (popInfo) => {
                                    CommonUtils.returnFromSubPage(popInfo);
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
                        menuIcon: $r("app.media.clean"),
                        doJob: async () => {
                            try {
                                this.promptAction.showDialog({
                                    title: $r("app.string.More_Clear_Confirm_Title"),
                                    message: $r("app.string.More_Clear_Confirm_Content"),
                                    buttons: [
                                        {
                                            text: $r("app.string.More_Clear_Confirm_Button_Confirm"),
                                            color: $r("app.color.more_clear_confirm_button_color")
                                        },
                                        {
                                            text: $r("app.string.More_Clear_Confirm_Button_Cancel"),
                                            color: $r("app.color.more_clear_confirm_button_color")
                                        }
                                    ]
                                }).then(async (result) => {
                                    if (result.index == 0) {
                                        const success = await this.listViewModel.clearCommandEntry();
                                        if (success) {
                                            CommonUtils.alert($r("app.string.More_Clear_Success"), this.promptAction);
                                            this.pathStack?.pop("Clear press");
                                        } else CommonUtils.alert($r("app.string.More_Clear_Failed_Try_Again"), this.promptAction);
                                    } else Logger.debug(this.LOG_TAG, "清除已取消");
                                });
                            } catch (err) {
                                Logger.error(this.LOG_TAG, `清除失败, ${err}`);
                                CommonUtils.alert($r("app.string.More_Clear_Failed"), this.promptAction);
                            }
                        }
                    })

                    MoreMenuItem({
                        menuText: $r("app.string.More_Help_Label"),
                        menuIcon: $r("app.media.info_circle")
                    })
                }
                .height(StyleConstants.FULL_PERCENT)
                .width(StyleConstants.FULL_PERCENT)
            }
            .title($r("app.string.More_Title"))
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