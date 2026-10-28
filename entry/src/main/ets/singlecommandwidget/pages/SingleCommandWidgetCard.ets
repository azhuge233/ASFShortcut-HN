import StyleConstants from '../../common/constants/StyleConstants';
import CommonConstants from '../../common/constants/CommonConstants'

let storage = new LocalStorage();

@Entry(storage)
@Component
struct SingleCommandWidgetCard {
    @LocalStorageProp('formID') private formID: string = '';
    @LocalStorageProp('isInitialized') private isInitialized: boolean = false;
    @LocalStorageProp('isRunning') private isRunning: boolean = false;

    @LocalStorageProp('shortcutID') private shortcutID: number | null = null;
    @LocalStorageProp('nickname') private nickname: string | null = null;
    @LocalStorageProp('command') private command: string | null = null;

    @LocalStorageProp('runResult') private runResult: string = '';

    private readonly ENTRY_ABILITY_NAME: string = 'EntryAbility';
    private readonly WIDGET_ENTRY_ABILITY_NAME: string = 'SingleCommandWidgetEntryAbility';

    private readonly FORM_EDIT_PAGE_ROUTE: string = 'pages/SingleCommandFormEdit';

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
    Logo() {
        Column() {
            Image($r("app.media.form_icon"))
                .objectFit(ImageFit.Auto)
        }
        .width(StyleConstants.THIRTY_PERCENT)
    }

    @Builder
    LoadingContent() {
        Column() {
            LoadingProgress()
                .height(StyleConstants.SIXTY_PERCENT)
                .width(StyleConstants.SIXTY_PERCENT)
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
        .width(StyleConstants.SEVENTY_PERCENT)
        .alignItems(HorizontalAlign.Center)
    }

    @Builder
    ShortcutOrResults() {
        Column() {
            if (this.runResult !== '') {
                Column() {
                    Blank()

                    List() {
                        ForEach(this.runResult.split(/\r?\n|\r|\n/g), (line: string) => {
                            ListItem() {
                                Text(line)
                                    .fontSize(StyleConstants.FORM_RESULT_CONTENT_FONT_SIZE)
                                    .fontColor($r("app.color.form_font_color"))
                                    .textAlign(TextAlign.Start)
                            }
                        }, (line: string, index: number) => index.toString())
                    }
                    .layoutWeight(1)
                    .height(StyleConstants.NINETY_PERCENT)
                    .width(StyleConstants.FULL_PERCENT)
                    .padding({
                        top: StyleConstants.PADDING_TEN,
                        bottom: StyleConstants.PADDING_FIVE,
                        right: StyleConstants.PADDING_EIGHT
                    })

                    Text($r("app.string.Form_Run_Complete_Label"))
                        .height(StyleConstants.TEN_PERCENT)
                        .width(StyleConstants.FULL_PERCENT)
                        .alignSelf(ItemAlign.End)
                        .textAlign(TextAlign.Center)
                        .fontSize(StyleConstants.FORM_RESULT_LABEL_FONT_SIZE)
                        .fontWeight(FontWeight.Medium)
                        .fontColor(Color.White)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Clip })
                        .margin({
                            bottom: StyleConstants.MARGIN_FIVE,
                            right: StyleConstants.MARGIN_TEN
                        })
                }
            } else {
                Column() {
                    Text(this.nickname ?? '')
                        .fontWeight(FontWeight.Medium)
                        .fontColor(Color.White)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Clip })

                    Text(this.command ?? '')
                        .fontColor(Color.Gray)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                }
            }
        }
        .width(StyleConstants.SEVENTY_PERCENT)
        .layoutWeight(1)
    }

    @Builder
    Init() {
        Row() {
            this.Logo();

            Column() {
                Text($r("app.string.Form_Unbound_Title"))
                    .fontWeight(FontWeight.Medium)
                    .fontColor(Color.White)
                    .margin({
                        right: StyleConstants.MARGIN_TEN
                    })
            }
            .width(StyleConstants.SEVENTY_PERCENT)
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
            this.Logo();

            this.LoadingContent();
        }
        .height(StyleConstants.FULL_PERCENT)
        .width(StyleConstants.FULL_PERCENT)
        .onClick(() => {
            if(this.isRunning) {
                // 运行态点击 = 取消：只带 formID，其余卡片数据由 Ability 从 PM 绑定取
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
            this.Logo();

            this.ShortcutOrResults();
        }
        .height(StyleConstants.FULL_PERCENT)
        .width(StyleConstants.FULL_PERCENT)
        .onClick(() => {
            if (!this.isRunning) {
                if(this.runResult !== '') { // 如果正在显示执行结果，恢复卡片显示
                    this.sendMessageAction(CommonConstants.FORM_MESSAGE_RESTORE, 'MainContent() Component');
                } else if (this.isInitialized) { // 正常显示状态，执行指令
                    postCardAction(this, {
                        action: CommonConstants.FORM_ACTION_CALL,
                        abilityName: this.WIDGET_ENTRY_ABILITY_NAME,
                        params: {
                            method: CommonConstants.FORM_CALL_RUN,
                            formID: this.formID,
                            shortcutID: this.shortcutID,
                            nickname: this.nickname,
                            command: this.command
                        }
                    });
                }
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