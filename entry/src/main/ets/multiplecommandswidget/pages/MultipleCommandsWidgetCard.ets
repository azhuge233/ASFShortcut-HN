import StyleConstants from '../../common/constants/StyleConstants';
import CommonConstants from '../../common/constants/CommonConstants'
import WidgetCommand from '../model/WidgetCommand';

let storage = new LocalStorage();

@Entry(storage)
@Component
struct MultipleCommandsWidgetCard {
    @LocalStorageProp('formID') private formID: string = '';
    @LocalStorageProp('isInitialized') private isInitialized: boolean = false;
    @LocalStorageProp('isRunning') private isRunning: boolean = false;

    @LocalStorageProp('commandList') private commandList: Array<WidgetCommand> = [];

    @LocalStorageProp('runResult') private runResult: string = '';

    private readonly ENTRY_ABILITY_NAME: string = 'EntryAbility';
    private readonly WIDGET_ENTRY_ABILITY_NAME: string = 'MultipleCommandsWidgetEntryAbility';

    private readonly FORM_EDIT_PAGE_ROUTE: string = 'pages/MultipleCommandsFormEdit';

    private sendMessageAction(action: string, data: number | string | null) {
        postCardAction(this, {
            action: CommonConstants.FORM_ACTION_MESSAGE,
            params: {
                formAction: action,
                data: data
            }
        });
    }

    aboutToAppear(): void {
        this.sendMessageAction(CommonConstants.FORM_MESSAGE_RESTORE, 'aboutToAppear()');
    }

    @Builder
    LoadingContent() {
        Column() {
            LoadingProgress()
                .height(StyleConstants.FIFTY_PERCENT)
                .width(StyleConstants.FIFTY_PERCENT)
                .color(Color.White)

            Text($r("app.string.Form_Running_Label"))
                .fontSize(StyleConstants.FORM_RUNNING_LABEL_FONT_SIZE)
                .fontColor(Color.White)

            Text($r("app.string.Form_Running_Cancel_Label"))
                .fontSize(StyleConstants.FORM_RUNNING_LABEL_FONT_SIZE)
                .fontColor(Color.White)
                .margin({
                    top: StyleConstants.MARGIN_FIVE
                })
        }
        .width(StyleConstants.FULL_PERCENT)
        .alignItems(HorizontalAlign.Center)
    }

    @Builder
    ShortcutOrResults() {
        Column() {
            if (this.runResult !== '') {
                Column() {
                    List() {
                        ForEach(this.runResult.split(/\r?\n|\r|\n/g), (line: string) => {
                            ListItem() {
                                Text(line)
                                    .fontSize(StyleConstants.FORM_RESULT_CONTENT_FONT_SIZE)
                                    .fontColor($r("app.color.form_font_color"))
                                    .textAlign(TextAlign.Start)
                            }
                            .padding({
                                left: StyleConstants.MARGIN_FIVE,
                                right: StyleConstants.MARGIN_FIVE
                            })
                        }, (line: string, index: number) => index.toString())
                    }
                    .layoutWeight(1)
                    .height(StyleConstants.NINETY_PERCENT)
                    .width(StyleConstants.FULL_PERCENT)
                    .padding({
                        top: StyleConstants.PADDING_TEN,
                        bottom: StyleConstants.PADDING_FIVE,
                        left: StyleConstants.PADDING_TEN,
                        right: StyleConstants.PADDING_TEN
                    })

                    Text($r("app.string.Form_Run_Complete_Label"))
                        .height(StyleConstants.TEN_PERCENT)
                        .width(StyleConstants.FULL_PERCENT)
                        .textAlign(TextAlign.Center)
                        .fontSize(StyleConstants.FORM_RESULT_LABEL_FONT_SIZE)
                        .fontWeight(FontWeight.Medium)
                        .fontColor(Color.White)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Clip })
                }
                .height(StyleConstants.FULL_PERCENT)
                .width(StyleConstants.FULL_PERCENT)
            } else {
                Column() {
                    List() {
                        ForEach(this.commandList ?? [], (item: WidgetCommand) => {
                            ListItem() {
                                Column() {
                                    Text(item.nickname)
                                        .fontWeight(FontWeight.Medium)
                                        .fontColor(Color.White)
                                        .maxLines(1)
                                        .textOverflow({ overflow: TextOverflow.Clip })

                                    Text(item.command)
                                        .fontColor(Color.Gray)
                                        .maxLines(1)
                                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                                }
                                .padding({
                                    left: StyleConstants.PADDING_FIVE,
                                    right: StyleConstants.PADDING_FIVE
                                })
                            }
                            .height(StyleConstants.FORM_LIST_ITEM_HEIGHT)
                            .width(StyleConstants.NINETY_PERCENT)
                            .borderRadius(StyleConstants.FORM_LIST_ITEM_BORDER_RADIUS)
                            .backgroundColor($r("app.color.form_command_background"))
                            .margin({
                                top: StyleConstants.MARGIN_FIVE,
                                bottom: StyleConstants.MARGIN_FIVE
                            })
                            .onClick(() => {
                                if (this.isInitialized) {
                                    postCardAction(this, {
                                        action: CommonConstants.FORM_ACTION_CALL,
                                        abilityName: this.WIDGET_ENTRY_ABILITY_NAME,
                                        params: {
                                            method: CommonConstants.FORM_CALL_RUN,
                                            formID: this.formID,
                                            shortcutID: item.id,
                                            command: item.command,
                                            commandList: this.commandList
                                        }
                                    });
                                }
                            })
                        }, (item: WidgetCommand) => item.id.toString())
                    }
                    .lanes(2)
                    .layoutWeight(1)
                    .alignListItem(ListItemAlign.Center)
                    .height(StyleConstants.FULL_PERCENT)
                    .width(StyleConstants.FULL_PERCENT)
                    .padding({
                        top: StyleConstants.PADDING_FIVE,
                        bottom: StyleConstants.PADDING_FIVE,
                        left: StyleConstants.PADDING_FIVE,
                        right: StyleConstants.PADDING_FIVE
                    })
                }
                .height(StyleConstants.FULL_PERCENT)
                .width(StyleConstants.FULL_PERCENT)
            }
        }
        .width(StyleConstants.SEVENTY_PERCENT)
        .layoutWeight(1)
    }

    @Builder
    Init() {
        Row() {
            Text($r("app.string.Form_Unbound_Title"))
                .fontWeight(FontWeight.Medium)
                .fontColor(Color.White)
                .textAlign(TextAlign.Center)
                .height(StyleConstants.FULL_PERCENT)
                .width(StyleConstants.FULL_PERCENT)
        }
        .height(StyleConstants.FULL_PERCENT)
        .width(StyleConstants.FULL_PERCENT)
        .onAppear(() => {
            this.sendMessageAction(CommonConstants.FORM_MESSAGE_RESTORE, 'Init() Component');
        })
        .onClick(() => {
            postCardAction(this, {
                action: CommonConstants.FORM_ACTION_ROUTER,
                abilityName: this.ENTRY_ABILITY_NAME,
                params: {
                    targetPage: this.FORM_EDIT_PAGE_ROUTE,
                    formID: this.formID
                }
            });
        })
    }

    @Builder
    RunningContent() {
        Row() {
            this.LoadingContent();
        }
        .height(StyleConstants.FULL_PERCENT)
        .width(StyleConstants.FULL_PERCENT)
        .onClick(() => {
            // 运行态点击 = 取消：只带 formID，其余卡片数据由 Ability 从 PM 绑定取
            if(this.isRunning) {
                postCardAction(this, {
                    action: CommonConstants.FORM_ACTION_CALL,
                    abilityName: this.WIDGET_ENTRY_ABILITY_NAME,
                    params: {
                        method: CommonConstants.FORM_CALL_CANCEL,
                        formID: this.formID
                    }
                });
            }
        })
    }

    @Builder
    MainContent() {
        Row() {
            this.ShortcutOrResults();
        }
        .height(StyleConstants.FULL_PERCENT)
        .width(StyleConstants.FULL_PERCENT)
        .onClick(() => {
            if(!this.isRunning && this.runResult !== '') {
                this.sendMessageAction(CommonConstants.FORM_MESSAGE_RESTORE, 'MainContent() Component');
            }
        })
    }

    build() {
        RelativeContainer() {
            if (!this.isInitialized) this.Init();
            else if(this.isRunning) this.RunningContent();
            else this.MainContent();
        }
        .height(StyleConstants.FULL_PERCENT)
        .width(StyleConstants.FULL_PERCENT)
        .backgroundColor($r('app.color.form_background'))
    }
}