import StyleConstants from '../../common/constants/StyleConstants';
import CommonConstants from '../../common/constants/CommonConstants'

let storage = new LocalStorage();

@Entry(storage)
@Component
struct ASFCommandWidgetCard {
    @LocalStorageProp('formID') private formID: string = '';
    @LocalStorageProp('isInitialized') private isInitialized: boolean = false;
    @LocalStorageProp('isRunning') private isRunning: boolean = false;

    @LocalStorageProp('shortcutID') private shortcutID: number | null = null;
    @LocalStorageProp('nickname') private nickname: string | null = null;
    @LocalStorageProp('command') private command: string | null = null;

    @LocalStorageProp('runResult') private runResult: string = '';

    private readonly ActionTypeRouter = 'router';
    private readonly ActionTypeCall = 'call';
    private readonly ActionTypeMessage = 'message';

    private readonly EntryAbilityName: string = 'EntryAbility';
    private readonly WidgetEntryAbilityName: string = 'ASFCommandWidgetEntryAbility';

    private readonly FormEditPageRoute: string = 'pages/FormEdit';

    /* 夺命连环 call
     * call time 次，对应 Ability 不做任何响应
     * 仅用于拉起对应 Ability 的进程
     * 如果 ASF 发送请求时没有 Ability 的进程，有概率谜之中断，进而卡死卡片 UI，卡死时运行一次其他卡片会恢复
     * 在 ASF 服务端响应慢、网络不稳定时更容易发生，因为 ASF 请求会占用更多时间
     * 在 Ability 中添加延时无法解决该问题
     *
    private bringAppUp(time: number) {
        for(let i = 0; i < time; i++) {
            postCardAction(this, {
                action: this.ActionTypeCall,
                abilityName: this.WidgetEntryAbilityName,
                params: {
                    method: CommonConstants.FormCall_Up,
                    count: i
                }
            });
        }
    }
    */

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
                // .color($r("app.color.form_font_color"))

            Text($r("app.string.Form_Running_Label"))
                .fontSize(StyleConstants.FORM_RUNNING_LABEL_FONT_SIZE)
                // .fontColor($r("app.color.form_font_color"))
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
                        })
                    }
                    .layoutWeight(1)
                    .height(StyleConstants.NINETY_PERCENT)
                    .width(StyleConstants.FULL_PERCENT)
                    .margin({
                        top: StyleConstants.MARGIN_TEN,
                        bottom: StyleConstants.MARGIN_FIVE,
                        right: StyleConstants.MARGIN_TEN
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
                    Text(this.nickname)
                        .fontWeight(FontWeight.Medium)
                        .fontColor(Color.White)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Clip })

                    Text(this.command)
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
            this.Logo();

            this.LoadingContent();
        }
        .height(StyleConstants.FULL_PERCENT)
        .width(StyleConstants.FULL_PERCENT)
        .onClick(() => {
            if(this.isRunning) {
                postCardAction(this, {
                    action: this.ActionTypeMessage,
                    params: {
                        formAction: CommonConstants.FormMessage_Update,
                        data: this.shortcutID
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
                    postCardAction(this, {
                        action: this.ActionTypeMessage,
                        params: {
                            formAction: CommonConstants.FormMessage_Update,
                            data: this.shortcutID
                        }
                    });
                } else if (this.isInitialized) { // 正常显示状态，执行指令
                    postCardAction(this, {
                        action: this.ActionTypeCall,
                        abilityName: this.WidgetEntryAbilityName,
                        params: {
                            method: CommonConstants.FormCall_Run,
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