import StyleConstants from '../../common/constants/StyleConstants';
import CommonConstants from '../../common/constants/CommonConstants'
import WidgetCommand from '../model/WidgetCommand';

let storage = new LocalStorage();

@Entry(storage)
@Component
struct SingleCommandWidgetCard {
    @LocalStorageProp('formID') private formID: string = '';
    @LocalStorageProp('isInitialized') private isInitialized: boolean = false;
    @LocalStorageProp('isRunning') private isRunning: boolean = false;

    @LocalStorageProp('commandList') private commandList: Array<WidgetCommand> = [];

    @LocalStorageProp('runResult') private runResult: string = '';

    private readonly ActionTypeRouter = 'router';
    private readonly ActionTypeCall = 'call';
    private readonly ActionTypeMessage = 'message';

    private readonly EntryAbilityName: string = 'EntryAbility';
    private readonly WidgetEntryAbilityName: string = 'MultipleCommandsWidgetEntryAbility';

    private readonly FormEditPageRoute: string = 'pages/MultipleCommandsFormEdit';

    private sendMessageAction(action: string, data: number | string | null) {
        postCardAction(this, {
            action: this.ActionTypeMessage,
            params: {
                formAction: action,
                data: data
            }
        });
    }

    aboutToAppear(): void {
        this.sendMessageAction(CommonConstants.FormMessage_Restore, 'aboutToAppear()');
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
                        })
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
                        ForEach(this.commandList, (item: WidgetCommand) => {
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
                                        action: this.ActionTypeCall,
                                        abilityName: this.WidgetEntryAbilityName,
                                        params: {
                                            method: CommonConstants.FormCall_Run,
                                            formID: this.formID,
                                            shortcutID: item.id,
                                            command: item.command,
                                            commandList: this.commandList
                                        }
                                    });
                                }
                            })
                        })
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
            this.sendMessageAction(CommonConstants.FormMessage_Restore, 'Init() Component');
        })
        .onClick(() => {
            postCardAction(this, {
                action: this.ActionTypeRouter,
                abilityName: this.EntryAbilityName,
                params: {
                    targetPage: this.FormEditPageRoute,
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
            // 如果正在显示执行结果，恢复卡片显示
            if(this.isRunning) this.sendMessageAction(CommonConstants.FormMessage_Restore, 'RunningContent() Component');
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
                this.sendMessageAction(CommonConstants.FormMessage_Restore, 'MainContent() Component');
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