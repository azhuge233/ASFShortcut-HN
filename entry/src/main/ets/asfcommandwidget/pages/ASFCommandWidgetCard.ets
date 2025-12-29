import StyleConstants from '../../common/constants/StyleConstants';
import Logger from '../../common/utils/Logger';
import CommonConstants from '../../common/constants/CommonConstants'

let storage = new LocalStorage();

@Entry(storage)
@Component
struct ASFCommandWidgetCard {
    private LOG_TAG = '[ASFCommandWidgetCard]';

    @LocalStorageProp('formID') private formID: string = '';
    @LocalStorageProp('formDimensions') private formDimensions: number = 1;
    @LocalStorageProp('isInitialized') private isInitialized: boolean = false;

    @LocalStorageProp('shortcutID') private shortcutID: number | null = null;
    @LocalStorageProp('nickname') private nickname: string | null = null;
    @LocalStorageProp('command') private command: string | null = null;

    @State isRunning: boolean = false;

    private readonly ActionTypeRouter = 'router';
    private readonly ActionTypeCall = 'call';
    private readonly ActionTypeMessage = 'message';

    private readonly EntryAbilityName: string = 'EntryAbility';

    private readonly FormEditPageRoute: string = 'pages/FormEdit';

    @Builder
    Init() {
        Row() {
            Column() {
                Text($r("app.string.Form_Unbound_Title"))
                    .fontWeight(FontWeight.Medium)
                    .fontColor(Color.White)
            }
            .width(StyleConstants.FULL_PERCENT)
        }
        .height(StyleConstants.FULL_PERCENT)
        .width(StyleConstants.FULL_PERCENT)
        .onClick(() => {
            postCardAction(this, {
                action: this.ActionTypeRouter,
                abilityName: this.EntryAbilityName,
                params: {
                    targetPage: this.FormEditPageRoute,
                    formID: this.formID,
                    dimensions: this.formDimensions
                }
            });
        })
    }

    @Builder
    MainContent() {
        Row() {
            Column() {
                Image($r("app.media.form_icon"))
                    .objectFit(ImageFit.Auto)
                    .layoutWeight(1)
            }
            .width(StyleConstants.THIRTY_PERCENT)

            Column() {
                Text(this.nickname)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(Color.White)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Clip })

                Text(this.command)
                    .maxLines(1)
                    .fontColor(Color.Gray)
                    .textOverflow({ overflow: TextOverflow.Clip })
            }
            .width(StyleConstants.SEVENTY_PERCENT)
        }
        .height(StyleConstants.FULL_PERCENT)
        .onClick(() => {
            postCardAction(this, {
                action: this.ActionTypeMessage,
                params: {
                    formAction: CommonConstants.FormMessage_Update,
                    data: this.shortcutID
                }
            });

            if(this.isInitialized) {
                postCardAction(this, {
                    action: this.ActionTypeMessage,
                    params: {
                        formAction: CommonConstants.FormMessage_Run,
                        data: this.command
                    }
                });
            }
        })
    }

    build() {
        RelativeContainer() {
            if(!this.isInitialized) this.Init();
            else this.MainContent();
        }
        .height(StyleConstants.FULL_PERCENT)
        .width(StyleConstants.FULL_PERCENT)
        .backgroundColor($r('app.color.form_background'))
        .onAppear(() => {
            Logger.debug(this.LOG_TAG, 'Loaded!');
        })
    }
}